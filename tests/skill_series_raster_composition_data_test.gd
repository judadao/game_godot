extends SceneTree

const MAPPING_PATH := "res://data/skill_series_raster_composition.json"
const EXPECTED_SERIES := [
	"sword_rain", "moon_wheel", "feather", "thorn", "dr_stone",
	"black_hole", "fire", "lightning", "water_flow", "arcane_swamp",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
const EXPECTED_ELEMENTS := [
	"dark", "fire", "ice", "light", "lightning", "poison", "water", "wind",
]
const EXPECTED_PHASES := ["anticipation", "travel", "contact", "residual"]

var _failures := 0
var _isolated_components: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var document := JSON.parse_string(FileAccess.get_file_as_string(MAPPING_PATH)) as Dictionary
	_expect(not document.is_empty(), "Raster composition mapping must parse.")
	if document.is_empty():
		_finish()
		return
	_expect(int(document.get("schema_version", 0)) == 1, "Raster mapping schema must be versioned.")
	_expect(String(document.get("status", "")) == "runtime_wired", "Composition authority must report its runtime adapter status.")
	_expect((document.get("phase_order", []) as Array) == EXPECTED_PHASES, "Four VFX phases must remain ordered.")
	var rules := document.get("composition_rules", {}) as Dictionary
	_expect(not bool(rules.get("whole_sheet_translation", true)), "Whole-sheet translation must be forbidden.")
	_expect(bool(rules.get("crop_before_transform", false)), "Every material must crop before transform.")
	_expect(bool(rules.get("prefer_isolated_component_asset", false)), "Overlapping source bboxes require isolated component textures.")
	var isolated_policy := document.get("isolated_component_assets", {}) as Dictionary
	var manifest_path := String(isolated_policy.get("authority", ""))
	var isolated_manifest := JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) as Dictionary
	_expect(not isolated_manifest.is_empty(), "Isolated component manifest must parse.")
	_expect(String(isolated_manifest.get("generator", "")) == "res://tools/build_skill_series_raster_components.py", "Isolated assets need a reproducible generator.")
	for record_value in isolated_manifest.get("components", []) as Array:
		var record := record_value as Dictionary
		var key := "%s:%s:%s" % [record.get("category", ""), record.get("entry_id", ""), record.get("component_id", "")]
		_isolated_components[key] = record

	var series_entries := document.get("series", []) as Array
	var overlay_entries := document.get("blessing_overlays", []) as Array
	_expect(_ids(series_entries) == EXPECTED_SERIES, "Mapping must cover all 13 series exactly once and in catalog order.")
	_expect(_ids(overlay_entries) == EXPECTED_ELEMENTS, "Mapping must cover all eight Blessing overlays exactly once.")
	var profile_document := JSON.parse_string(FileAccess.get_file_as_string("res://data/skill_series_vfx.json")) as Dictionary
	var profile_paths: Dictionary = {}
	for profile_value in profile_document.get("profiles", []) as Array:
		var profile := profile_value as Dictionary
		profile_paths[String(profile.get("id", ""))] = String(profile.get("material_asset_path", ""))
	var mutation_script := load("res://scripts/vfx/blessing_vfx_mutation_catalog.gd") as Script
	_expect(mutation_script != null, "Blessing mapping needs the production mutation catalog.")
	for entry in series_entries:
		var series_entry := entry as Dictionary
		_expect(
			String(series_entry.get("asset_path", "")) == String(profile_paths.get(series_entry.get("id", ""), "")),
			"%s crop mapping must follow its catalog material path." % series_entry.get("id", "")
		)
		_validate_entry(series_entry, false)
	for entry in overlay_entries:
		var overlay_entry := entry as Dictionary
		if mutation_script != null:
			var mutation := mutation_script.call("get_mutation", overlay_entry.get("id", "")) as Dictionary
			_expect(
				String(overlay_entry.get("asset_path", "")) == String(mutation.get("overlay_asset_path", "")),
				"%s crop mapping must follow its mutation catalog overlay path." % overlay_entry.get("id", "")
			)
		_validate_entry(overlay_entry, true)
	_finish()


func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String((entry as Dictionary).get("id", "")))
	return result


func _validate_entry(entry: Dictionary, is_overlay: bool) -> void:
	var entry_id := String(entry.get("id", ""))
	var asset_path := String(entry.get("asset_path", ""))
	_expect(ResourceLoader.exists(asset_path, "Texture2D"), "%s asset must load: %s" % [entry_id, asset_path])
	var texture := load(asset_path) as Texture2D
	var image := texture.get_image() if texture != null else Image.new()
	_expect(not image.is_empty(), "%s texture must decode." % entry_id)
	if image.is_empty():
		return
	_expect(image.get_size() == Vector2i(1254, 1254), "%s mapping assumes the reviewed 1254-square source." % entry_id)
	var alpha_bounds := entry.get("native_alpha_bounds", []) as Array
	_expect(alpha_bounds.size() == 4, "%s needs recorded native alpha bounds." % entry_id)

	var components := entry.get("components", []) as Array
	var component_ids: Dictionary = {}
	_expect(components.size() >= 3, "%s needs at least charge, travel, and contact crops." % entry_id)
	for component_value in components:
		var component := component_value as Dictionary
		var component_id := String(component.get("id", ""))
		_expect(not component_id.is_empty() and not component_ids.has(component_id), "%s component ids must be unique." % entry_id)
		component_ids[component_id] = true
		var category := "blessing" if is_overlay else "base"
		var isolated_key := "%s:%s:%s" % [category, entry_id, component_id]
		var isolated := _isolated_components.get(isolated_key, {}) as Dictionary
		var isolated_path := String(isolated.get("asset_path", ""))
		_expect(not isolated.is_empty(), "%s/%s needs one alpha-isolated manifest entry." % [entry_id, component_id])
		_expect(String(component.get("asset_path", "")) == isolated_path, "%s/%s must directly reference its isolated texture." % [entry_id, component_id])
		_expect(ResourceLoader.exists(isolated_path, "Texture2D"), "%s/%s isolated texture must load." % [entry_id, component_id])
		if FileAccess.file_exists(isolated_path):
			_expect(FileAccess.get_sha256(isolated_path) == String(isolated.get("asset_sha256", "")), "%s/%s isolated hash must match its manifest." % [entry_id, component_id])
		var isolated_size := isolated.get("isolated_size", []) as Array
		_expect(isolated_size.size() == 2 and int(isolated_size[0]) > 0 and int(isolated_size[1]) > 0, "%s/%s needs a trimmed isolated size." % [entry_id, component_id])
		var asset_region := component.get("asset_region", []) as Array
		_expect(
			asset_region.size() == 4
				and int(asset_region[0]) == 0
				and int(asset_region[1]) == 0
				and int(asset_region[2]) == int(isolated_size[0])
				and int(asset_region[3]) == int(isolated_size[1]),
			"%s/%s asset region must cover exactly the trimmed isolated texture." % [entry_id, component_id]
		)
		var region_values := component.get("region", []) as Array
		_expect(region_values.size() == 4, "%s/%s needs [x,y,width,height]." % [entry_id, component_id])
		if region_values.size() != 4:
			continue
		var region := Rect2i(int(region_values[0]), int(region_values[1]), int(region_values[2]), int(region_values[3]))
		_expect(region.position.x >= 0 and region.position.y >= 0 and region.end.x <= 1254 and region.end.y <= 1254, "%s/%s crop must stay inside the sheet." % [entry_id, component_id])
		_expect(region.size.x < 1254 and region.size.y < 1254, "%s/%s must never be a full sheet." % [entry_id, component_id])
		_expect(_has_visible_alpha(image, region), "%s/%s crop must contain authored alpha." % [entry_id, component_id])

	var stages := entry.get("stages", []) as Array
	var phases: Array = []
	for stage_value in stages:
		var stage := stage_value as Dictionary
		phases.append(String(stage.get("phase", "")))
		var layers := stage.get("layers", []) as Array
		_expect(not layers.is_empty(), "%s/%s needs at least one component layer." % [entry_id, phases[-1]])
		for layer_value in layers:
			var layer := layer_value as Dictionary
			var component_id := String(layer.get("component", ""))
			_expect(component_ids.has(component_id), "%s/%s references a declared crop." % [entry_id, component_id])
			_expect((layer.get("offset", []) as Array).size() == 2, "%s/%s needs a local position offset." % [entry_id, component_id])
			_expect((layer.get("scale", []) as Array).size() == 2, "%s/%s needs explicit scale." % [entry_id, component_id])
			_expect(String(layer.get("blend", "")) in ["mix", "add"], "%s/%s needs a supported blend mode." % [entry_id, component_id])
			_expect(String(layer.get("tint", "")) == "#FFFFFF", "%s/%s must preserve its reviewed palette." % [entry_id, component_id])
			_expect(float(layer.get("delay_seconds", -1.0)) >= 0.0 and float(layer.get("lifetime_seconds", 0.0)) > 0.0, "%s/%s needs valid timing." % [entry_id, component_id])
			var stack := layer.get("stack", {}) as Dictionary
			var counts := stack.get("count_by_tier", {}) as Dictionary
			_expect(counts.has_all(["basic", "advanced", "master"]), "%s/%s needs three tier counts." % [entry_id, component_id])
			_expect(float(stack.get("overlap_ratio", -1.0)) >= 0.0 and float(stack.get("overlap_ratio", 2.0)) <= 1.0, "%s/%s overlap must be normalized." % [entry_id, component_id])
	_expect(phases == EXPECTED_PHASES, "%s must map anticipation -> travel -> contact -> residual." % entry_id)
	_expect((stages[2] as Dictionary).get("layers", []).size() >= 2, "%s contact must locally compose at least two crops." % entry_id)
	if is_overlay:
		_expect(not String(entry.get("shape", "")).is_empty(), "%s overlay needs its catalog shape semantics." % entry_id)


func _has_visible_alpha(image: Image, region: Rect2i) -> bool:
	for y in range(region.position.y, region.end.y, 8):
		for x in range(region.position.x, region.end.x, 8):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false


func _finish() -> void:
	if _failures == 0:
		print("PASS: 13 series and eight Blessing plates have crop-first four-phase composition data")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
