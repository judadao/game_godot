extends SceneTree

const EXPECTED_SERIES := [
	"sword_rain", "moon_wheel", "feather", "thorn", "dr_stone",
	"black_hole", "fire", "lightning", "water_flow", "arcane_swamp",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
const EXPECTED_ELEMENTS := [
	"dark", "fire", "ice", "light", "lightning", "poison", "water", "wind",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var recipe_script := load("res://scripts/vfx/skill_vfx_recipe_catalog.gd") as Script
	var mutation_script := load("res://scripts/vfx/blessing_vfx_mutation_catalog.gd") as Script
	var material_scene := load("res://scenes/vfx/skills/SkillSeriesRasterMaterialVFX2D.tscn") as PackedScene
	var composer_scene := load("res://scenes/vfx/SkillVFXComposer2D.tscn") as PackedScene
	_expect(recipe_script != null, "Raster material assets need the production recipe catalog.")
	_expect(mutation_script != null, "Raster Blessing variants need the production mutation catalog.")
	_expect(material_scene != null, "Skill-series raster materials need one reusable presentation scene.")
	_expect(composer_scene != null, "Production Skill VFX composer must own the raster presentation layer.")
	if recipe_script == null or mutation_script == null or material_scene == null or composer_scene == null:
		_finish()
		return

	var catalog := recipe_script.new() as RefCounted
	_expect(bool(catalog.call("load_catalog")), "Skill-series raster material recipes must validate.")
	var material_paths: Dictionary = {}
	var composition_signatures: Dictionary = {}
	for series_id in EXPECTED_SERIES:
		var recipe := catalog.call("get_recipe", series_id) as Dictionary
		var material_path := String(recipe.get("material_asset_path", ""))
		_expect(not material_path.is_empty(), "%s needs a referenced refined material asset." % series_id)
		_expect(ResourceLoader.exists(material_path, "Texture2D"), "%s material must load: %s" % [series_id, material_path])
		_expect(not material_paths.has(material_path), "%s must not silently reuse another series material." % series_id)
		material_paths[material_path] = true
		_validate_transparent_texture(material_path, "%s material" % series_id)
		var composition := recipe.get("material_composition", {}) as Dictionary
		_expect(String(composition.get("id", "")) == series_id, "%s needs its own runtime composition id." % series_id)
		var composition_signature := _validate_composition(composition, series_id)
		_expect(not composition_signature.is_empty() and not composition_signatures.has(composition_signature), "%s needs at least one distinct placement/stack composition." % series_id)
		composition_signatures[composition_signature] = true
	_expect(material_paths.size() == EXPECTED_SERIES.size(), "All 13 series need distinct material sources.")
	_expect(composition_signatures.size() == EXPECTED_SERIES.size(), "All 13 series need distinct four-phase composition mappings.")

	var element_paths: Dictionary = {}
	var elements := mutation_script.call("get_elements") as Array
	_expect(elements == EXPECTED_ELEMENTS, "Blessing mutation elements must remain canonical and ordered.")
	for element in EXPECTED_ELEMENTS:
		var mutation := mutation_script.call("get_mutation", element) as Dictionary
		var overlay_path := String(mutation.get("overlay_asset_path", ""))
		_expect(not overlay_path.is_empty(), "%s needs one compositable Blessing material." % element)
		_expect(ResourceLoader.exists(overlay_path, "Texture2D"), "%s overlay must load: %s" % [element, overlay_path])
		_expect(not element_paths.has(overlay_path), "%s must use a distinct element overlay." % element)
		element_paths[overlay_path] = true
		_validate_transparent_texture(overlay_path, "%s overlay" % element)
		_validate_overlay_regions(overlay_path, "%s overlay" % element)
	_expect(element_paths.size() == EXPECTED_ELEMENTS.size(), "All eight elements need distinct overlay sources.")

	var material := material_scene.instantiate() as Node2D
	root.add_child(material)
	await process_frame
	for series_id in EXPECTED_SERIES:
		var matrix_recipe := catalog.call("get_recipe", series_id) as Dictionary
		for tier_rank in range(1, 4):
			for overlay_case in [[], [{"id": "matrix_fire", "element": "fire", "level": 2}]]:
				_expect(bool(material.call("configure", matrix_recipe, tier_rank, overlay_case)), "%s T%d mapped runtime matrix must configure." % [series_id, tier_rank])
				material.call("set_progress", 0.60, Vector2.ZERO, Vector2(240.0, 0.0), 0.55, [Vector2(90.0, -20.0), Vector2(170.0, 8.0)])
				var matrix_state := material.call("get_debug_state") as Dictionary
				_expect(String(matrix_state.get("composition_id", "")) == series_id, "%s T%d must retain its own composition mapping." % [series_id, tier_rank])
				_expect(int(matrix_state.get("active_layer_count", 0)) <= int(matrix_state.get("max_instance_count", -1)), "%s T%d must obey the instance cap." % [series_id, tier_rank])
				_expect((matrix_state.get("component_role_counts", {}) as Dictionary).has_all(["anticipation", "travel", "contact", "residual"]), "%s T%d must retain all four mapped stages." % [series_id, tier_rank])
				_expect(_all_runtime_sources_isolated(matrix_state), "%s T%d must use only isolated component assets." % [series_id, tier_rank])
				material.call("clear")
				var cleared_state := material.call("get_debug_state") as Dictionary
				_expect(int(cleared_state.get("active_layer_count", -1)) == 0 and not material.visible, "%s T%d clear must release every mapped instance." % [series_id, tier_rank])
	var recipe := catalog.call("get_recipe", "moon_wheel") as Dictionary
	var runtime_contract := recipe.get("material_runtime", {}) as Dictionary
	_expect(not runtime_contract.is_empty(), "Raster recipes need a catalog-backed contact/travel/residual runtime contract.")
	_expect(
		(runtime_contract.get("regions", {}) as Dictionary).keys().all(
			func(role: Variant) -> bool: return String(role) in ["contact", "travel", "residual"]
		),
		"Raster runtime regions must expose only the three composable component roles."
	)
	var signatures: Dictionary = {}
	for element in EXPECTED_ELEMENTS:
		_expect(bool(material.call("configure", recipe, 3, [{"id": "%s_test" % element, "element": element, "level": 2}])), "Production raster material must accept %s." % element)
		material.call("set_progress", 0.62, Vector2.ZERO, Vector2(260.0, 0.0), 0.55)
		var state := material.call("get_debug_state") as Dictionary
		var signature := String(state.get("variant_signature", ""))
		_expect(bool(state.get("presentation_only", false)), "Raster materials must remain presentation-only.")
		_expect((state.get("resolved_elements", []) as Array) == [element], "%s must resolve to its own material overlay." % element)
		_expect(not bool(state.get("uses_full_sheet", true)), "%s must never expose a whole multi-object material plate." % element)
		_expect(_all_runtime_sources_isolated(state), "%s base and overlay sprites must use isolated component assets." % element)
		_expect(String(state.get("composition_id", "")) == "moon_wheel", "%s must use the selected series composition instead of the global fallback." % element)
		_expect(int(state.get("active_layer_count", 0)) >= 7, "%s must stack cropped base and Blessing components across all mapped phases." % element)
		_expect(int(state.get("active_layer_count", 0)) <= int(state.get("max_instance_count", -1)), "%s runtime instances must obey the catalog guard." % element)
		var role_counts := state.get("component_role_counts", {}) as Dictionary
		_expect(int(role_counts.get("anticipation", 0)) >= 1, "%s must preserve the mapped anticipation phase." % element)
		_expect(int(role_counts.get("contact", 0)) >= 2, "%s needs layered contact crops at one point." % element)
		_expect(int(role_counts.get("travel", 0)) >= 3, "%s needs repeated staggered travel crops along the lane." % element)
		_expect(int(role_counts.get("residual", 0)) >= 2, "%s needs delayed residual crops." % element)
		_validate_runtime_atlas_sprites(material, "%s runtime" % element)
		_expect(not signature.is_empty() and not signatures.has(signature), "%s needs a deterministic unique variant signature." % element)
		signatures[signature] = true
	material.call("set_progress", 0.28, Vector2.ZERO, Vector2(260.0, 0.0), 0.55)
	var travel_state := material.call("get_debug_state") as Dictionary
	var travel_positions := travel_state.get("visible_travel_positions", []) as Array
	_expect(travel_positions.size() >= 2, "Travel material must form a continuous staggered lane rather than one moving plate.")
	if travel_positions.size() >= 2:
		_expect((travel_positions[0] as Vector2).distance_to(travel_positions[1] as Vector2) >= 18.0, "Travel instances must occupy distinct lane positions.")
	material.call("set_progress", 0.72, Vector2.ZERO, Vector2(260.0, 0.0), 0.55)
	var residual_state := material.call("get_debug_state") as Dictionary
	_expect(int(residual_state.get("visible_residual_count", 0)) >= 1, "Residual material must appear after contact and fade independently.")

	_expect(bool(material.call("configure", recipe, 3, [{"id": "fusion_test", "elements": ["fire", "lightning"], "level": 3}])), "Evolved Blessings must configure as one Gift overlay.")
	var fusion_state := material.call("get_debug_state") as Dictionary
	_expect(int(fusion_state.get("blessing_overlay_count", 0)) == 1, "One evolved Gift must remain one Blessing overlay.")
	_expect((fusion_state.get("resolved_elements", []) as Array) == ["fire", "lightning"], "Both evolved Blessing elements must participate in raster composition.")
	_expect((fusion_state.get("overlay_asset_paths", []) as Array).size() == 2, "A two-element evolved Blessing needs both material assets.")
	_expect(int((fusion_state.get("component_role_counts", {}) as Dictionary).get("travel", 0)) >= 4, "A two-element evolved Blessing must retain continuous travel stacking within the cap.")
	_expect(bool(material.call("configure", recipe, 3, [{"id": "gift_fire", "element": "fire", "level": 2}, {"id": "gift_lightning", "element": "lightning", "level": 2}])), "Two independent Gift dictionaries must configure within one global reserve.")
	var independent_gift_state := material.call("get_debug_state") as Dictionary
	_expect(int(independent_gift_state.get("blessing_overlay_count", 0)) == 2, "Two independent Gifts must both retain a mapped overlay allocation.")
	_expect((independent_gift_state.get("resolved_elements", []) as Array) == ["fire", "lightning"], "Independent Gifts must not let the first element consume the second element's cap reserve.")
	var base_timing_states: Array[Dictionary] = []
	for timing_overlays in [[], [{"id": "timing_fire", "element": "fire", "level": 1}], [{"id": "timing_fire", "element": "fire", "level": 1}, {"id": "timing_lightning", "element": "lightning", "level": 1}]]:
		_expect(bool(material.call("configure", recipe, 3, timing_overlays)), "Base timing stability setup must configure.")
		material.call("set_progress", 0.30, Vector2.ZERO, Vector2(260.0, 0.0), 0.55)
		base_timing_states.append(material.call("get_debug_state") as Dictionary)
	for timing_index in range(1, base_timing_states.size()):
		var baseline_state := base_timing_states[0]
		var compared_state := base_timing_states[timing_index]
		_expect(is_equal_approx(float((baseline_state.get("source_phase_horizons", {}) as Dictionary).get("base:travel", 0.0)), float((compared_state.get("source_phase_horizons", {}) as Dictionary).get("base:travel", -1.0))), "Blessing count must not change the base travel horizon.")
		var baseline_positions := baseline_state.get("visible_base_travel_positions", []) as Array
		var compared_positions := compared_state.get("visible_base_travel_positions", []) as Array
		_expect(not baseline_positions.is_empty() and not compared_positions.is_empty() and (baseline_positions[0] as Vector2).distance_to(compared_positions[0] as Vector2) <= 0.01, "Blessing count must not shift the base travel cadence.")
	var fire_recipe := catalog.call("get_recipe", "fire") as Dictionary
	_expect(bool(material.call("configure", fire_recipe, 3, [])), "Mapped fire composition must configure for core-position routing.")
	var distinct_cores := [Vector2(72.0, -44.0), Vector2(132.0, -18.0), Vector2(204.0, 12.0)]
	material.call("set_progress", 0.30, Vector2.ZERO, Vector2.ZERO, 0.55, distinct_cores)
	var zero_lane_state := material.call("get_debug_state") as Dictionary
	var zero_lane_positions := zero_lane_state.get("visible_travel_positions", []) as Array
	_expect(_distinct_position_count(zero_lane_positions) >= 2, "source==target travel stacks must follow distinct core positions instead of collapsing at the origin.")
	material.call("set_progress", 0.60, Vector2.ZERO, Vector2.ZERO, 0.55, distinct_cores)
	var zero_contact_state := material.call("get_debug_state") as Dictionary
	var zero_contact_positions := zero_contact_state.get("visible_contact_positions", []) as Array
	_expect(_distinct_position_count(zero_contact_positions) >= 2, "source==target contact stacks must select distinct core landing positions.")
	var explicit_target_recipe := catalog.call("get_recipe", "sword_rain") as Dictionary
	_expect(bool(material.call("configure", explicit_target_recipe, 3, [])), "Explicit-target anchor test must configure.")
	material.call("set_progress", 0.16, Vector2.ZERO, Vector2(260.0, 12.0), 0.55, [Vector2(760.0, 420.0), Vector2(880.0, 460.0)])
	var target_state := material.call("get_debug_state") as Dictionary
	var target_snapshot := _first_snapshot(target_state.get("component_snapshots", []) as Array, "anticipation")
	_expect(not target_snapshot.is_empty() and (target_snapshot.get("position", Vector2.ZERO) as Vector2).distance_to(Vector2(260.0, 12.0)) < 120.0, "An explicit target anchor must not be overwritten by distant core positions.")
	var broken_recipe := recipe.duplicate(true)
	var broken_composition := (broken_recipe.get("material_composition", {}) as Dictionary).duplicate(true)
	var broken_components := (broken_composition.get("components", []) as Array).duplicate(true)
	var broken_component := (broken_components[0] as Dictionary).duplicate(true)
	broken_component["asset_path"] = "res://assets/generated/vfx/skill_materials/components/missing_component.png"
	broken_components[0] = broken_component
	broken_composition["components"] = broken_components
	broken_recipe["material_composition"] = broken_composition
	_expect(not bool(material.call("configure", broken_recipe, 3, [])), "A mapped composition with a missing isolated component must fail closed.")
	_expect(int((material.call("get_debug_state") as Dictionary).get("active_layer_count", -1)) == 0, "Missing isolated assets must not silently fall back to a plate crop.")
	material.queue_free()
	await process_frame

	var composer := composer_scene.instantiate() as Node2D
	root.add_child(composer)
	await process_frame
	_expect(bool(composer.call("configure", recipe, 3, [{"id": "fusion_test", "elements": ["fire", "lightning"], "level": 3}])), "Production composer must configure the raster material layer.")
	composer.call("set_progress", 0.62, Vector2.ZERO, Vector2(260.0, 0.0), [], 0.55)
	var composer_state := composer.call("get_debug_state") as Dictionary
	var raster_state := composer_state.get("raster_material", {}) as Dictionary
	_expect(String(raster_state.get("recipe_id", "")) == "moon_wheel", "Production composer must route the active series recipe into raster materials.")
	_expect((raster_state.get("resolved_elements", []) as Array) == ["fire", "lightning"], "Production composer must preserve both evolved Blessing material layers.")
	_expect(int(composer_state.get("mutation_count", 0)) == 2, "Production composer must apply both evolved Blessing mutations.")
	composer.queue_free()
	await process_frame
	_finish()


func _validate_transparent_texture(path: String, label: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return
	var texture := load(path) as Texture2D
	var image := texture.get_image() if texture != null else Image.new()
	_expect(not image.is_empty(), "%s must decode." % label)
	if image.is_empty():
		return
	_expect(image.get_width() >= 512 and image.get_height() >= 512, "%s must preserve native-detail review resolution." % label)
	_expect(image.detect_alpha() != Image.ALPHA_NONE, "%s must preserve true alpha." % label)
	for corner in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
		_expect(image.get_pixelv(corner).a <= 0.02, "%s needs transparent corner padding." % label)


func _validate_overlay_regions(path: String, label: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return
	var texture := load(path) as Texture2D
	var image := texture.get_image() if texture != null else Image.new()
	if image.is_empty():
		return
	var size := Vector2i(image.get_width(), image.get_height())
	var regions := [
		Rect2i(0, 0, int(size.x * 0.48), int(size.y * 0.48)),
		Rect2i(int(size.x * 0.36), int(size.y * 0.28), int(size.x * 0.64), int(size.y * 0.34)),
		Rect2i(int(size.x * 0.46), int(size.y * 0.56), int(size.x * 0.54), int(size.y * 0.44)),
	]
	for region_index in regions.size():
		var visible_samples := 0
		var region := regions[region_index] as Rect2i
		for y in range(region.position.y, mini(region.end.y, size.y), 4):
			for x in range(region.position.x, mini(region.end.x, size.x), 4):
				if image.get_pixel(x, y).a > 0.05:
					visible_samples += 1
		_expect(visible_samples >= 120, "%s region %d needs an authored charge/travel/impact component." % [label, region_index])


func _validate_runtime_atlas_sprites(material: Node2D, label: String) -> void:
	var atlas_count := 0
	var full_sheet_count := 0
	for candidate in material.find_children("*", "Sprite2D", true, false):
		var sprite := candidate as Sprite2D
		if sprite.texture == null:
			continue
		if sprite.texture is AtlasTexture:
			atlas_count += 1
			var atlas := sprite.texture as AtlasTexture
			var atlas_size := atlas.atlas.get_size() if atlas.atlas != null else Vector2.ZERO
			var source_kind := String(sprite.get_meta("material_source_kind", "plate_crop"))
			var source_path := String(sprite.get_meta("material_source_path", ""))
			if source_kind == "isolated_component":
				_expect(atlas.atlas != null and source_path.contains("/skill_materials/components/"), "%s isolated sprites must report their component source path." % label)
				_expect(atlas.region.size.x <= atlas_size.x and atlas.region.size.y <= atlas_size.y, "%s isolated component atlas must stay inside its derived texture." % label)
			else:
				_expect(
					atlas.atlas != null
						and atlas.region.size.x < atlas_size.x
						and atlas.region.size.y < atlas_size.y,
					"%s plate fallback crops must be strictly smaller than their multi-object source." % label
				)
		else:
			full_sheet_count += 1
	_expect(full_sheet_count == 0, "%s must not attach any full-sheet Texture2D to a Sprite2D." % label)
	_expect(atlas_count >= 7, "%s needs multiple independently cropped component sprites." % label)


func _validate_composition(composition: Dictionary, label: String) -> String:
	if composition.is_empty():
		return ""
	var component_ids: Dictionary = {}
	for component_variant in composition.get("components", []) as Array:
		if not component_variant is Dictionary:
			continue
		var component := component_variant as Dictionary
		var component_id := String(component.get("id", ""))
		var region := component.get("region", []) as Array
		_expect(not component_id.is_empty() and region.size() == 4, "%s components need id and source crop provenance." % label)
		if region.size() == 4:
			_expect(float(region[2]) > 0.0 and float(region[3]) > 0.0 and float(region[2]) < 1254.0 and float(region[3]) < 1254.0, "%s component crops must be smaller than the source plate." % label)
		component_ids[component_id] = true
	var phases: Array[String] = []
	var placement_stack_pairs: Array[String] = []
	for stage_variant in composition.get("stages", []) as Array:
		if not stage_variant is Dictionary:
			continue
		var stage := stage_variant as Dictionary
		var phase := String(stage.get("phase", ""))
		phases.append(phase)
		for layer_variant in stage.get("layers", []) as Array:
			if not layer_variant is Dictionary:
				continue
			var layer := layer_variant as Dictionary
			_expect(component_ids.has(String(layer.get("component", ""))), "%s stage layers must reference one mapped component." % label)
			placement_stack_pairs.append("%s:%s" % [String(layer.get("placement", "")), String((layer.get("stack", {}) as Dictionary).get("mode", ""))])
	_expect(phases == ["anticipation", "travel", "contact", "residual"], "%s must map all four runtime phases in order." % label)
	return "|".join(PackedStringArray(placement_stack_pairs))


func _distinct_position_count(values: Array) -> int:
	var distinct: Array[Vector2] = []
	for value in values:
		if not value is Vector2:
			continue
		var position := value as Vector2
		if distinct.all(func(existing: Vector2) -> bool: return existing.distance_to(position) >= 4.0):
			distinct.append(position)
	return distinct.size()


func _all_runtime_sources_isolated(state: Dictionary) -> bool:
	var regions := state.get("atlas_regions", []) as Array
	if regions.is_empty():
		return false
	for region_variant in regions:
		if not region_variant is Dictionary:
			return false
		var region := region_variant as Dictionary
		if String(region.get("source_kind", "")) != "isolated_component":
			return false
		if not String(region.get("source_path", "")).contains("/skill_materials/components/"):
			return false
	return true


func _first_visible_snapshot(snapshots: Array, role: String) -> Dictionary:
	for snapshot_variant in snapshots:
		if not snapshot_variant is Dictionary:
			continue
		var snapshot := snapshot_variant as Dictionary
		if String(snapshot.get("role", "")) == role and float(snapshot.get("alpha", 0.0)) > 0.02:
			return snapshot
	return {}


func _first_snapshot(snapshots: Array, role: String) -> Dictionary:
	for snapshot_variant in snapshots:
		if not snapshot_variant is Dictionary:
			continue
		var snapshot := snapshot_variant as Dictionary
		if String(snapshot.get("role", "")) == role:
			return snapshot
	return {}


func _finish() -> void:
	if _failures == 0:
		print("PASS: 13 refined series materials compose all eight Blessing variants")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
