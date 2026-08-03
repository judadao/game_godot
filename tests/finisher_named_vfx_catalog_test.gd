extends SceneTree

const FINISHER_DATA_PATH := "res://data/combo_finishers.json"
const CATALOG_SCRIPT_PATH := "res://scripts/systems/named_skill_vfx_catalog.gd"
const VFX_SCENE_PATH := "res://scenes/combat/vfx/NamedSkillVFX.tscn"
const EXPECTED_FINISHER_COUNT := 32
const MINIMUM_BASE_VISUAL_LAYERS := 6
const MINIMUM_CHOREOGRAPHY_FAMILY_COUNT := 6
const MINIMUM_CHOREOGRAPHY_SIGNATURE_COUNT := 12
const MINIMUM_SEMANTIC_PIECE_COUNT := 3
const MINIMUM_VISIBLE_AUTHORED_OBJECTS := 1
const MINIMUM_AUTHORED_SEQUENCE_FRAME_COUNT := 12
const AUTHORED_SEQUENCE_SAFE_MARGIN := 20
const REQUIRED_CHOREOGRAPHY_FIELDS := [
	"family",
	"spawn_primitives",
	"piece_count",
	"formation",
	"paths",
	"impact",
	"residue",
]
const RUNTIME_PHASES := [
	{"name": "anticipation", "progress": 0.12},
	{"name": "travel", "progress": 0.40},
	{"name": "contact", "progress": 0.68},
	{"name": "afterglow", "progress": 0.88},
]
const LEGACY_PART_NAMES := [&"Charge", &"Attack", &"Trail", &"Impact", &"Debris"]
const REQUIRED_RUNTIME_METHODS := [
	&"play",
	&"debug_set_progress",
	&"is_active",
	&"get_profile_id",
	&"get_stage_name",
	&"get_geometry_identity",
	&"get_particle_identity",
	&"get_light_identity",
	&"get_base_visual_layer_count",
	&"get_total_visual_layer_count",
	&"get_finisher_debug_state",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var recipes := _load_finisher_recipes()
	_expect(
		recipes.size() == EXPECTED_FINISHER_COUNT,
		"The authoritative combo catalog must retain all %d finishers; found %d."
		% [EXPECTED_FINISHER_COUNT, recipes.size()]
	)
	var catalog_script := load(CATALOG_SCRIPT_PATH)
	var vfx_scene := load(VFX_SCENE_PATH) as PackedScene
	_expect(catalog_script != null, "Finishers need the named VFX catalog authority.")
	_expect(vfx_scene != null, "Finishers need the reusable NamedSkillVFX scene.")
	if recipes.is_empty() or catalog_script == null or vfx_scene == null:
		_finish()
		return

	var catalog: RefCounted = catalog_script.new()
	var catalog_loaded := bool(catalog.call("load_catalog"))
	_expect(catalog_loaded, "The complete named VFX catalog must validate and load.")
	if not catalog_loaded:
		_finish()
		return
	var visual_signatures: Dictionary = {}
	var material_paths: Dictionary = {}
	var choreography_families: Dictionary = {}
	var choreography_signatures: Dictionary = {}
	for recipe_variant in recipes:
		var recipe := recipe_variant as Dictionary
		var finisher_id := String(recipe.get("id", ""))
		_expect(not finisher_id.is_empty(), "Every combo finisher needs a stable id.")
		if finisher_id.is_empty():
			continue
		var has_profile := bool(catalog.call("has_profile", finisher_id))
		_expect(has_profile, "Missing named VFX profile for combo finisher: %s." % finisher_id)
		if not has_profile:
			continue
		var profile := catalog.call("get_profile", finisher_id) as Dictionary
		_validate_profile_matches_recipe(recipe, profile)
		_register_choreography_contract(
			finisher_id,
			profile.get("choreography", {}) as Dictionary,
			choreography_families,
			choreography_signatures
		)
		var material_path := String(profile.get("material_path", ""))
		_expect(
			not material_path.is_empty() and not material_paths.has(material_path),
			"%s must have an exclusive material plate instead of reusing %s."
			% [finisher_id, String(material_paths.get(material_path, "another finisher"))]
		)
		if not material_path.is_empty():
			material_paths[material_path] = finisher_id
		var signature := _visual_signature(profile)
		_expect(
			not signature.is_empty() and not visual_signatures.has(signature),
			"%s must keep an original geometry/particle/light identity instead of duplicating %s."
			% [finisher_id, String(visual_signatures.get(signature, "another finisher"))]
		)
		if not signature.is_empty():
			visual_signatures[signature] = finisher_id
		await _validate_runtime_playback(vfx_scene, finisher_id, profile)

	_expect(
		visual_signatures.size() == EXPECTED_FINISHER_COUNT,
		"All %d finishers need complete, distinguishable visual identities; found %d."
		% [EXPECTED_FINISHER_COUNT, visual_signatures.size()]
	)
	_expect(
		choreography_families.size() >= MINIMUM_CHOREOGRAPHY_FAMILY_COUNT,
		"The 32 finishers need at least %d real choreography families; found %d."
		% [MINIMUM_CHOREOGRAPHY_FAMILY_COUNT, choreography_families.size()]
	)
	_expect(
		choreography_signatures.size() >= MINIMUM_CHOREOGRAPHY_SIGNATURE_COUNT,
		"Spawn, path, contact, and residue contracts need at least %d distinct signatures; found %d."
		% [MINIMUM_CHOREOGRAPHY_SIGNATURE_COUNT, choreography_signatures.size()]
	)
	_finish()


func _load_finisher_recipes() -> Array:
	_expect(FileAccess.file_exists(FINISHER_DATA_PATH), "Combo finisher data must exist.")
	if not FileAccess.file_exists(FINISHER_DATA_PATH):
		return []
	var file := FileAccess.open(FINISHER_DATA_PATH, FileAccess.READ)
	_expect(file != null, "Combo finisher data must be readable.")
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "Combo finisher data must parse to a Dictionary.")
	if not parsed is Dictionary:
		return []
	var recipes_variant: Variant = (parsed as Dictionary).get("recipes", null)
	_expect(recipes_variant is Array, "Combo finisher data must expose a recipes array.")
	return recipes_variant as Array if recipes_variant is Array else []


func _validate_profile_matches_recipe(recipe: Dictionary, profile: Dictionary) -> void:
	var finisher_id := String(recipe.get("id", ""))
	var icon_path := String(recipe.get("icon_path", ""))
	_expect(String(profile.get("kind", "")) == "finisher", "%s must resolve as a finisher profile." % finisher_id)
	_expect(
		String(profile.get("presentation_mode", "")) == "2_5d",
		"%s must use the shared pure-CanvasItem 2.5D presentation contract." % finisher_id
	)
	_expect(
		String(profile.get("display_name", "")) == String(recipe.get("name", "")),
		"%s VFX display name must match its combo recipe name." % finisher_id
	)
	_expect(
		String(profile.get("icon_path", "")) == icon_path,
		"%s VFX must bind the exact icon used by its combo recipe." % finisher_id
	)
	_expect(
		String(profile.get("role", "")) == String(recipe.get("role", "")),
		"%s VFX role must match its combo recipe role." % finisher_id
	)
	_expect(not icon_path.is_empty() and FileAccess.file_exists(icon_path), "%s finisher icon must exist." % finisher_id)
	var material_path := String(profile.get("material_path", ""))
	var storyboard_path := String(profile.get("storyboard_path", ""))
	_expect(
		not material_path.is_empty() and FileAccess.file_exists(material_path),
		"%s needs one authored semantic material plate." % finisher_id
	)
	if not material_path.is_empty() and FileAccess.file_exists(material_path):
		_validate_material_structure(finisher_id, material_path)
	_expect(
		not storyboard_path.is_empty() and FileAccess.file_exists(storyboard_path),
		"%s needs a detailed choreography storyboard authority." % finisher_id
	)
	_expect(
		not String(profile.get("semantic_object", "")).strip_edges().is_empty(),
		"%s needs a named concrete object before layering effects." % finisher_id
	)
	_validate_choreography_profile(finisher_id, profile.get("choreography", {}) as Dictionary)

	var geometry_identity := profile.get("geometry_identity", {}) as Dictionary
	var particle_identity := profile.get("particle_identity", {}) as Dictionary
	var light_identity := profile.get("light_identity", {}) as Dictionary
	_expect(
		_has_motif(geometry_identity) and _has_palette(geometry_identity),
		"%s needs an authored geometry motif and multi-color palette." % finisher_id
	)
	_expect(
		_has_motif(particle_identity)
			and int(particle_identity.get("count", 0)) > 0
			and int(particle_identity.get("count", 0)) <= 256,
		"%s needs a named particle motif and a positive bounded particle count." % finisher_id
	)
	_expect(
		_has_motif(light_identity)
			and _has_palette(light_identity)
			and float(light_identity.get("energy", 0.0)) > 0.0,
		"%s needs a cinematic light motif, palette, and positive energy." % finisher_id
	)


func _validate_runtime_playback(
	vfx_scene: PackedScene,
	finisher_id: String,
	profile: Dictionary
) -> void:
	var effect := vfx_scene.instantiate()
	root.add_child(effect)
	await process_frame
	var has_runtime_contract := true
	for method_name in REQUIRED_RUNTIME_METHODS:
		if not effect.has_method(method_name):
			has_runtime_contract = false
			_expect(false, "NamedSkillVFX must expose %s for %s playback diagnostics." % [method_name, finisher_id])
	if not has_runtime_contract:
		effect.queue_free()
		await process_frame
		return

	effect.set("auto_free", false)
	effect.call("play", finisher_id, 1, 1.0, true, 2, 3)
	_expect(bool(effect.call("is_active")), "%s must enter an active playback state." % finisher_id)
	_expect(String(effect.call("get_profile_id")) == finisher_id, "%s playback must retain its exact identity." % finisher_id)
	_expect(
		StringName(effect.call("get_stage_name")) == &"anticipation",
		"%s must begin with a readable anticipation stage." % finisher_id
	)
	_expect(
		(effect.call("get_geometry_identity") as Dictionary) == (profile.get("geometry_identity", {}) as Dictionary),
		"%s runtime geometry must come from its resolved profile." % finisher_id
	)
	_expect(
		(effect.call("get_particle_identity") as Dictionary) == (profile.get("particle_identity", {}) as Dictionary),
		"%s runtime particles must come from its resolved profile." % finisher_id
	)
	_expect(
		(effect.call("get_light_identity") as Dictionary) == (profile.get("light_identity", {}) as Dictionary),
		"%s runtime lighting must come from its resolved profile." % finisher_id
	)
	var base_layer_count := int(effect.call("get_base_visual_layer_count"))
	var total_layer_count := int(effect.call("get_total_visual_layer_count"))
	_expect(
		base_layer_count >= MINIMUM_BASE_VISUAL_LAYERS,
		"%s needs at least %d layers for semantic construction, depth, contact, residue, and sourced fragments."
		% [finisher_id, MINIMUM_BASE_VISUAL_LAYERS]
	)
	_expect(
		total_layer_count >= base_layer_count,
		"%s total visual layers must include every base layer." % finisher_id
	)
	var debug_state := effect.call("get_finisher_debug_state") as Dictionary
	_expect(String(debug_state.get("presentation_mode", "")) == "2_5d", "%s must report pure 2.5D playback." % finisher_id)
	_expect(bool(debug_state.get("meaningful_semantic_geometry", false)), "%s contours must construct its named object." % finisher_id)
	_expect(not bool(debug_state.get("decorative_line_geometry", true)), "%s must not use decorative line geometry." % finisher_id)
	_expect(not bool(debug_state.get("icon_echo", true)), "%s must not paste its icon into the move." % finisher_id)
	_expect(bool(debug_state.get("sprite_part_sequence", false)), "%s must use an authored sprite-part sequence." % finisher_id)
	_expect(not bool(debug_state.get("procedural_flat_object", true)), "%s must not use flat runtime-drawn object silhouettes." % finisher_id)
	_expect(
		int(debug_state.get("authored_frame_count", 0)) >= MINIMUM_AUTHORED_SEQUENCE_FRAME_COUNT,
		"%s must expose at least twelve authored micro-poses, not a six-image slideshow." % finisher_id
	)
	_expect(
		bool(debug_state.get("authored_frame_animation", false))
			and not bool(debug_state.get("crossfade_slideshow", true)),
		"%s must play distinct authored drawings instead of cross-fading still photographs." % finisher_id
	)
	_expect(
		not bool(debug_state.get("texture_filter_uses_mipmaps", true)),
		"%s atlas playback must not mip-sample black cel gutters into the animation." % finisher_id
	)
	_expect(
		float(debug_state.get("atlas_edge_inset", 0.0)) >= 6.0,
		"%s atlas playback must crop registration guides outside every runtime cel." % finisher_id
	)
	_expect(
		int(debug_state.get("authored_object_layer_count", 0)) >= 3,
		"%s needs a frame body plus tight and wide chromatic light layers." % finisher_id
	)
	_expect(
		int(debug_state.get("visible_material_layers", -1)) == 0,
		"%s must not stack the old complete material plate behind its authored action." % finisher_id
	)
	_expect(
		is_equal_approx(float(debug_state.get("ground_anchor_ratio", 0.0)), 0.82),
		"%s must use the shared horizontal ground-contact anchor." % finisher_id
	)
	_expect(
		(debug_state.get("authored_source_position", Vector2(999.0, 999.0)) as Vector2).is_equal_approx(Vector2.ZERO)
			and is_zero_approx(float(debug_state.get("authored_source_rotation", 999.0))),
		"%s must preserve an unrotated authored camera instead of manufacturing a diagonal lane." % finisher_id
	)
	_expect(
		is_zero_approx((debug_state.get("runtime_target_offset", Vector2(0.0, -999.0)) as Vector2).y),
		"%s authored contact baseline must sit on the map ground instead of retaining the legacy atlas Y lift." % finisher_id
	)
	_validate_authored_sequence(
		finisher_id,
		String(debug_state.get("authored_sequence_path", "")),
		int(debug_state.get("authored_grid_columns", 0)),
		int(debug_state.get("authored_grid_rows", 0))
	)
	_expect(not bool(debug_state.get("legacy_atlas_visible", true)), "%s must keep legacy atlas parts hidden." % finisher_id)
	_expect(int(debug_state.get("legacy_accent_count", -1)) == 0, "%s must not build icon-derived accent layers." % finisher_id)
	_expect((debug_state.get("applied_particle_axis", Vector2.ZERO) as Vector2).length_squared() > 0.5, "%s particle flow must resolve to an applied direction." % finisher_id)
	_expect(
		is_equal_approx(float(debug_state.get("light_energy", 0.0)), float((profile.get("light_identity", {}) as Dictionary).get("energy", 0.0))),
		"%s runtime light energy must come from its authored light identity." % finisher_id
	)
	_expect(
		String(debug_state.get("light_motif", "")) == String((profile.get("light_identity", {}) as Dictionary).get("motif", "")),
		"%s runtime must retain its named light response." % finisher_id
	)
	for part_name in LEGACY_PART_NAMES:
		var legacy_sprite := effect.get_node_or_null(NodePath(String(part_name))) as Sprite2D
		_expect(
			legacy_sprite != null and (not legacy_sprite.visible or legacy_sprite.modulate.a <= 0.002),
			"%s must physically hide legacy part %s." % [finisher_id, part_name]
		)
	_expect(
		String(debug_state.get("semantic_object", "")) == String(profile.get("semantic_object", "")),
		"%s runtime must retain the storyboard's concrete semantic object." % finisher_id
	)
	_validate_runtime_choreography(effect, finisher_id, profile)
	effect.queue_free()
	await process_frame


func _validate_choreography_profile(finisher_id: String, choreography: Dictionary) -> void:
	_expect(not choreography.is_empty(), "%s needs an authored multi-part choreography profile." % finisher_id)
	if choreography.is_empty():
		return
	for field in REQUIRED_CHOREOGRAPHY_FIELDS:
		_expect(choreography.has(field), "%s choreography is missing '%s'." % [finisher_id, field])
	var family := String(choreography.get("family", "")).strip_edges()
	var spawn_primitives := choreography.get("spawn_primitives", []) as Array
	var piece_count := choreography.get("piece_count", {}) as Dictionary
	var formation := String(choreography.get("formation", "")).strip_edges()
	var paths := choreography.get("paths", []) as Array
	var impact := String(choreography.get("impact", "")).strip_edges()
	var residue := String(choreography.get("residue", "")).strip_edges()
	_expect(not family.is_empty(), "%s choreography needs a stable family." % finisher_id)
	_expect(spawn_primitives.size() >= 2, "%s must construct from at least two semantic primitive types." % finisher_id)
	_expect(
		_total_authored_piece_count(piece_count) >= MINIMUM_SEMANTIC_PIECE_COUNT,
		"%s must animate at least %d authored semantic pieces instead of one complete plate."
		% [finisher_id, MINIMUM_SEMANTIC_PIECE_COUNT]
	)
	_expect(not formation.is_empty(), "%s needs a concrete formation action." % finisher_id)
	_expect(paths.size() >= 2, "%s needs a continuous multi-beat travel path." % finisher_id)
	_expect(not impact.is_empty(), "%s needs a physical contact deformation." % finisher_id)
	_expect(not residue.is_empty(), "%s needs a concrete residue state." % finisher_id)


func _register_choreography_contract(
	finisher_id: String,
	choreography: Dictionary,
	families: Dictionary,
	signatures: Dictionary
) -> void:
	if choreography.is_empty():
		return
	var family := String(choreography.get("family", "")).strip_edges()
	var signature := _choreography_signature(choreography)
	if family.is_empty() or signature.is_empty():
		return
	families[family] = true
	_expect(
		not signatures.has(signature) or String(signatures[signature]) == family,
		"%s choreography family '%s' duplicates the same spawn/path/contact/residue contract as family '%s'."
		% [finisher_id, family, String(signatures.get(signature, ""))]
	)
	if not signatures.has(signature):
		signatures[signature] = family


func _choreography_signature(choreography: Dictionary) -> String:
	if choreography.is_empty():
		return ""
	return JSON.stringify([
		choreography.get("spawn_primitives", []),
		choreography.get("piece_count", {}),
		String(choreography.get("formation", "")),
		choreography.get("paths", []),
		String(choreography.get("impact", "")),
		String(choreography.get("residue", "")),
	])


func _total_authored_piece_count(piece_count: Dictionary) -> int:
	var total := 0
	for count_variant in piece_count.values():
		if count_variant is int or count_variant is float:
			total += maxi(0, int(count_variant))
	return total


func _validate_runtime_choreography(effect: Node, finisher_id: String, profile: Dictionary) -> void:
	var choreography := profile.get("choreography", {}) as Dictionary
	if choreography.is_empty():
		return
	var expected_family := String(choreography.get("family", ""))
	var phase_signatures: Dictionary = {}
	var authored_frame_indices: Dictionary = {}
	var maximum_visible_pieces := 0
	var spatial_offsets: Array[Vector2] = []
	var spatial_mode := ""
	for phase_variant in RUNTIME_PHASES:
		var phase := phase_variant as Dictionary
		effect.call("debug_set_progress", float(phase.get("progress", 0.0)))
		var state := effect.call("get_finisher_debug_state") as Dictionary
		var phase_name := String(phase.get("name", "phase"))
		_expect(
			String(state.get("choreography_family", "")) == expected_family,
			"%s %s runtime must retain choreography family '%s'."
			% [finisher_id, phase_name, expected_family]
		)
		_expect(
			int(state.get("piece_count", 0)) >= MINIMUM_SEMANTIC_PIECE_COUNT,
			"%s %s must be assembled from multiple independently animated semantic pieces."
			% [finisher_id, phase_name]
		)
		maximum_visible_pieces = maxi(maximum_visible_pieces, int(state.get("visible_piece_count", 0)))
		spatial_offsets.append(state.get("runtime_target_offset", Vector2(0.0, -999.0)) as Vector2)
		spatial_mode = String(state.get("spatial_mode", ""))
		authored_frame_indices[int(state.get("authored_frame_index", -1))] = true
		_expect(
			not String(state.get("piece_motion_signature", "")).strip_edges().is_empty(),
			"%s %s needs a named piece-motion signature." % [finisher_id, phase_name]
		)
		_expect(
			not bool(state.get("full_plate_travel", true)),
			"%s %s must not move one intact semantic material plate through the attack."
			% [finisher_id, phase_name]
		)
		var phase_signature := String(state.get("phase_signature", "")).strip_edges()
		_expect(
			not phase_signature.is_empty(),
			"%s %s must expose a deterministic semantic-piece phase signature."
			% [finisher_id, phase_name]
		)
		_expect(
			phase_signature.is_empty() or not phase_signatures.has(phase_signature),
			"%s %s repeats the same semantic-piece state as %s; the move must advance continuously."
			% [finisher_id, phase_name, String(phase_signatures.get(phase_signature, "another phase"))]
		)
		if not phase_signature.is_empty():
			phase_signatures[phase_signature] = phase_name
	_expect(
		maximum_visible_pieces >= MINIMUM_VISIBLE_AUTHORED_OBJECTS,
		"%s must visibly present its authored animated object during playback."
		% finisher_id
	)
	_expect(
		authored_frame_indices.size() >= RUNTIME_PHASES.size(),
		"%s must advance through distinct painted object poses across all review phases." % finisher_id
	)
	_expect(
		phase_signatures.size() == RUNTIME_PHASES.size(),
		"%s must expose distinct anticipation, travel, contact, and afterglow piece states."
		% finisher_id
	)
	var geometry_identity := profile.get("geometry_identity", {}) as Dictionary
	var orientation := String(geometry_identity.get("orientation", "forward"))
	var role := String(profile.get("role", "offense"))
	var expects_directional := (
		orientation in ["forward", "horizontal"]
		or (role == "offense" and orientation == "inward")
	)
	_expect(
		spatial_offsets.all(func(offset: Vector2) -> bool: return is_zero_approx(offset.y)),
		"%s spatial choreography must remain horizontal on the map ground." % finisher_id
	)
	if expects_directional:
		_expect(
			spatial_mode == "directional_forward"
				and spatial_offsets.size() == RUNTIME_PHASES.size()
				and spatial_offsets[-1].x - spatial_offsets[0].x >= 120.0,
			"%s is directional and must advance a readable horizontal distance." % finisher_id
		)
	else:
		_expect(
			spatial_mode == "player_centered"
				and spatial_offsets.all(func(offset: Vector2) -> bool: return offset.is_equal_approx(Vector2.ZERO)),
			"%s is non-directional and must remain around the player." % finisher_id
		)


func _has_motif(identity: Dictionary) -> bool:
	return not String(identity.get("motif", "")).strip_edges().is_empty()


func _validate_authored_sequence(finisher_id: String, sequence_path: String, columns: int, rows: int) -> void:
	_expect(
		not sequence_path.is_empty() and FileAccess.file_exists(sequence_path),
		"%s needs an integrated authored sprite sequence." % finisher_id
	)
	if sequence_path.is_empty() or not FileAccess.file_exists(sequence_path):
		return
	var texture := load(sequence_path) as Texture2D
	_expect(texture != null, "%s authored sprite sequence must load through Godot." % finisher_id)
	if texture == null:
		return
	# Source-art guardrails must inspect the current workspace PNG directly.
	# `Texture2D.get_image()` can still represent the prior imported cache while
	# an artist is replacing the source atlas, which makes edge failures stale.
	var image := Image.load_from_file(ProjectSettings.globalize_path(sequence_path))
	_expect(not image.is_empty(), "%s authored source PNG must decode as current pixels." % finisher_id)
	if image.is_empty():
		return
	_expect(
		image.get_width() >= 1200
			and image.get_height() >= 1000
			and columns == 4
			and rows == 3,
		"%s authored sequence must preserve a native-detail 4x3 frame layout."
		% finisher_id
	)
	_validate_sequence_cell_safe_margins(finisher_id, image, columns, rows)


func _validate_sequence_cell_safe_margins(
	finisher_id: String,
	image: Image,
	columns: int,
	rows: int
) -> void:
	if columns <= 0 or rows <= 0:
		return
	var cell_width := floori(float(image.get_width()) / float(columns))
	var cell_height := floori(float(image.get_height()) / float(rows))
	for frame_index in columns * rows:
		var cell_x := (frame_index % columns) * cell_width
		var cell_y := floori(float(frame_index) / float(columns)) * cell_height
		var unsafe_pixels := 0
		for local_y in cell_height:
			for local_x in cell_width:
				if (
					local_x >= AUTHORED_SEQUENCE_SAFE_MARGIN
					and local_x < cell_width - AUTHORED_SEQUENCE_SAFE_MARGIN
					and local_y >= AUTHORED_SEQUENCE_SAFE_MARGIN
					and local_y < cell_height - AUTHORED_SEQUENCE_SAFE_MARGIN
				):
					continue
				var color := image.get_pixel(cell_x + local_x, cell_y + local_y)
				if maxf(color.r, maxf(color.g, color.b)) >= 0.03:
					unsafe_pixels += 1
		_expect(
			unsafe_pixels == 0,
			"%s authored frame %d must keep a pure-black %dpx safe margin; found %d bright edge pixels."
			% [finisher_id, frame_index + 1, AUTHORED_SEQUENCE_SAFE_MARGIN, unsafe_pixels]
		)


func _has_palette(identity: Dictionary) -> bool:
	var palette_variant: Variant = identity.get("palette", null)
	if not palette_variant is Array:
		return false
	var palette := palette_variant as Array
	if palette.size() < 2:
		return false
	for color_variant in palette:
		if String(color_variant).strip_edges().is_empty():
			return false
	return true


func _validate_material_structure(finisher_id: String, material_path: String) -> void:
	var texture := load(material_path) as Texture2D
	_expect(texture != null, "%s semantic material must load through Godot's import pipeline." % finisher_id)
	if texture == null:
		return
	var image := texture.get_image()
	_expect(not image.is_empty(), "%s semantic material must decode as an image." % finisher_id)
	if image.is_empty():
		return
	_expect(
		image.get_width() == image.get_height() and image.get_width() >= 1024,
		"%s semantic material must be a native-detail square plate." % finisher_id
	)
	var border_samples: Array[Vector2i] = []
	for coordinate in range(0, image.get_width(), 32):
		border_samples.append(Vector2i(coordinate, 0))
		border_samples.append(Vector2i(coordinate, image.get_height() - 1))
		border_samples.append(Vector2i(0, coordinate))
		border_samples.append(Vector2i(image.get_width() - 1, coordinate))
	for sample in border_samples:
		var color := image.get_pixelv(sample)
		_expect(
			maxf(color.r, maxf(color.g, color.b)) < 0.018,
			"%s semantic material needs pure-black additive padding." % finisher_id
		)
	var maximum_luminance := 0.0
	for y in range(0, image.get_height(), 32):
		for x in range(0, image.get_width(), 32):
			var color := image.get_pixel(x, y)
			maximum_luminance = maxf(maximum_luminance, maxf(color.r, maxf(color.g, color.b)))
	_expect(maximum_luminance >= 0.25, "%s semantic material needs a readable luminous object." % finisher_id)


func _visual_signature(profile: Dictionary) -> String:
	var geometry := profile.get("geometry_identity", {}) as Dictionary
	var particles := profile.get("particle_identity", {}) as Dictionary
	var lighting := profile.get("light_identity", {}) as Dictionary
	if geometry.is_empty() or particles.is_empty() or lighting.is_empty():
		return ""
	return JSON.stringify([geometry, particles, lighting])


func _finish() -> void:
	if _failures == 0:
		print("PASS: all 32 combo finishers resolve distinct geometry, particle, and light VFX identities")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
