extends Node2D

## Storyboard-driven 2.5D Finisher presentation.
##
## One authored twelve-frame sprite sequence is the semantic object authority
## for each motion family. Complete material plates stay hidden; sourced
## particles and chromatic light never replace the name-bound object.

const STAGE_ANTICIPATION := &"anticipation"
const STAGE_EXECUTION := &"execution"
const STAGE_IMPACT := &"impact"
const STAGE_AFTERGLOW := &"afterglow"

const MATERIAL_LAYER_NAMES: Array[StringName] = [
	&"EnvironmentSurface",
	&"SemanticUnderlay",
	&"MotionEcho",
	&"SemanticBody",
	&"SemanticEdge",
	&"ImpactSurface",
	&"PhysicalResidue",
]
const PARTICLE_LAYER_NAMES: Array[StringName] = [
	&"SourceFragments",
	&"ContactFragments",
	&"ResidueFragments",
]
const AUTHORED_OBJECT_LAYER_COUNT := 3
const BASE_VISUAL_LAYER_COUNT := 6
const MAX_BLESSING_OVERLAY_PASSES := 3
const DEFAULT_DIAMETER := 430.0
const MATERIAL_SHADER := preload("res://shaders/combat/finisher_semantic_material.gdshader")
const SEMANTIC_PIECE_SCRIPT := preload("res://scripts/combat/finisher_semantic_piece.gd")
const AUTHORED_SEQUENCE_PATHS := {
	"forged_ribs": "res://assets/generated/vfx/finisher_parts_v4/blade_forge_sequence.png",
	"horizon_reversal": "res://assets/generated/vfx/finisher_parts_v4/horizon_reversal_sequence.png",
	"rain_downpour": "res://assets/generated/vfx/finisher_parts_v4/blade_rain_sequence.png",
	"lunar_descent": "res://assets/generated/vfx/finisher_parts_v4/moon_descent_sequence.png",
	"boundary_feather_return": "res://assets/generated/vfx/finisher_parts_v4/boundary_feather_sequence.png",
	"mountain_release": "res://assets/generated/vfx/finisher_parts_v4/stone_mountain_sequence.png",
	"stone_orbit_counter": "res://assets/generated/vfx/finisher_parts_v4/stone_orbit_counter_sequence.png",
	"bone_machine": "res://assets/generated/vfx/finisher_parts_v4/bone_forge_sequence.png",
	"wind_lanes": "res://assets/generated/vfx/finisher_parts_v4/wind_lane_sequence.png",
	"breath_condense": "res://assets/generated/vfx/finisher_parts_v4/breath_condense_sequence.png",
	"wellspring_overflow": "res://assets/generated/vfx/finisher_parts_v4/water_resource_sequence.png",
	"guard_replay": "res://assets/generated/vfx/finisher_parts_v4/shield_counter_sequence.png",
	"fire_spiral": "res://assets/generated/vfx/finisher_parts_v4/fire_flow_sequence.png",
	"ice_chain": "res://assets/generated/vfx/finisher_parts_v4/ice_ground_sequence.png",
	"lightning_nodes": "res://assets/generated/vfx/finisher_parts_v4/lightning_prison_sequence.png",
	"poison_bloom": "res://assets/generated/vfx/finisher_parts_v4/poison_orchid_sequence.png",
	"leaf_shell_relay": "res://assets/generated/vfx/finisher_parts_v4/sunbearing_dawn_sequence.png",
	"spirit_procession": "res://assets/generated/vfx/finisher_parts_v4/spirit_lifeline_sequence.png",
	"root_intercept": "res://assets/generated/vfx/finisher_parts_v4/root_intercept_sequence.png",
	"garden_growth": "res://assets/generated/vfx/finisher_parts_v4/plant_growth_sequence.png",
	"feather_cadence": "res://assets/generated/vfx/finisher_parts_v4/feather_cadence_sequence.png",
	"hinged_feather_return": "res://assets/generated/vfx/finisher_parts_v4/feather_blade_return_sequence.png",
	"mirror_return": "res://assets/generated/vfx/finisher_parts_v4/mirror_return_sequence.png",
	"stream_collection": "res://assets/generated/vfx/finisher_parts_v4/stream_collection_sequence.png",
	"elemental_clash": "res://assets/generated/vfx/finisher_parts_v4/elemental_clash_sequence.png",
	"wheel_machine": "res://assets/generated/vfx/finisher_parts_v4/wheel_blade_sequence.png",
	"ice_fire_bloom": "res://assets/generated/vfx/finisher_parts_v4/ice_fire_bloom_sequence.png",
	"garden_canopy": "res://assets/generated/vfx/finisher_parts_v4/garden_canopy_sequence.png",
	"lifeline_return": "res://assets/generated/vfx/finisher_parts_v4/lifeline_return_sequence.png",
	"shield_exchange": "res://assets/generated/vfx/finisher_parts_v4/shield_exchange_sequence.png",
	"orbit_launch": "res://assets/generated/vfx/finisher_parts_v4/moon_wind_sequence.png",
	"marker_chain": "res://assets/generated/vfx/finisher_parts_v4/root_marker_chain_sequence.png",
}
const AUTHORED_FRAME_PLAYBACK_MAPS := {
	# Three source cels draw the offscreen return joint as a literal vertical
	# hinge. Preserve the radial out-and-return identity while using the adjacent
	# open-air feather poses, so the turn no longer reads as a visible wall.
	"boundary_feather_return": [0, 1, 2, 3, 4, 5, 5, 8, 8, 9, 11, 11],
	# The source cel at index 9 adds a separate vertical target slab. The shield
	# itself is the contact authority, so hold its launch until the fragments take
	# over instead of introducing an unrelated wall.
	"shield_exchange": [0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 10, 11],
	# The last two source cels contain a literal stone wall. Resolve the crest in
	# open water, then return to the grounded pool for the afterglow.
	"stream_collection": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 0],
}
const BLESSING_ELEMENT_STYLES := {
	"fire": {
		"particle_source": "flame_tongue",
		"light_color": "#ff5a24",
		"secondary_color": "#ffd86a",
		"direction": Vector2(0.18, -1.0),
	},
	"ice": {
		"particle_source": "faceted_ice_shard",
		"light_color": "#70dfff",
		"secondary_color": "#e8fbff",
		"direction": Vector2(1.0, -0.16),
	},
	"lightning": {
		"particle_source": "forked_lightning_splinter",
		"light_color": "#b990ff",
		"secondary_color": "#fff18a",
		"direction": Vector2(0.08, 1.0),
	},
	"poison": {
		"particle_source": "three_lobed_toxin_spore",
		"light_color": "#9bec4b",
		"secondary_color": "#d55cff",
		"direction": Vector2(0.86, -0.5),
	},
	"wind": {
		"particle_source": "cut_wind_leaf",
		"light_color": "#75f3cf",
		"secondary_color": "#e4fff6",
		"direction": Vector2(1.0, -0.08),
	},
	"dark": {
		"particle_source": "void_crescent_mote",
		"light_color": "#9b6cff",
		"secondary_color": "#ff79cc",
		"direction": Vector2(-0.46, 0.18),
	},
	"normal": {
		"particle_source": "four_point_prism",
		"light_color": "#ffe69a",
		"secondary_color": "#ffffff",
		"direction": Vector2(0.72, -0.42),
	},
}

var _profile: Dictionary = {}
var _profile_id := ""
var _material_path := ""
var _storyboard_path := ""
var _semantic_object := ""
var _orientation := "forward"
var _particle_flow := "forward"
var _particle_axis := Vector2.RIGHT
var _cadence := "cinematic_three_beat"
var _beat_pattern: Array[float] = []
var _palette: Array[Color] = []
var _accent_colors: Array[Color] = []
var _material_texture: Texture2D
var _material_layers: Dictionary = {}
var _particle_layers: Dictionary = {}
var _blessing_overlay_root: Node2D
var _blessing_overlays: Array[Dictionary] = []
var _blessing_overlay_passes: Array[Dictionary] = []
var _blessing_particles_fired: Dictionary = {}
var _piece_root: Node2D
var _semantic_pieces: Array[Sprite2D] = []
var _semantic_shapes: Array[Node2D] = []
var _piece_specs: Array[Dictionary] = []
var _piece_base_positions: Array[Vector2] = []
var _choreography_family := "blade_volley"
var _piece_motion_signature := "staggered_blade_release"
var _piece_motion_kind := "blade_volley"
var _choreography: Dictionary = {}
var _base_material_scale := 1.0
var _piece_shape_scale := 1.0
var _source_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _light_energy := 1.0
var _light_motif := ""
var _progress := 0.0
var _stage_name: StringName = STAGE_ANTICIPATION
var _configured := false
var _source_particles_fired := false
var _contact_particles_fired := false
var _residue_particles_fired := false
var _evolution_level := 1
var _buff_stacks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_layers()
	reset()


func configure(profile: Dictionary) -> bool:
	if profile.is_empty():
		push_error("Finisher material core requires a non-empty profile.")
		return false
	_ensure_layers()
	_profile = profile.duplicate(true)
	_profile_id = String(profile.get("id", ""))
	_material_path = String(
		profile.get(
			"material_path",
			"res://assets/generated/vfx/finishers_v2/%s_material.png" % _profile_id
		)
	)
	_storyboard_path = String(profile.get("storyboard_path", ""))
	_semantic_object = String(profile.get("semantic_object", _profile_id))
	if not ResourceLoader.exists(_material_path, "Texture2D"):
		push_error("Finisher semantic material does not exist: %s" % _material_path)
		_configured = false
		return false
	_material_texture = load(_material_path) as Texture2D
	if _material_texture == null:
		push_error("Finisher semantic material failed to load: %s" % _material_path)
		_configured = false
		return false
	var geometry_identity := profile.get("geometry_identity", {}) as Dictionary
	var particle_identity := profile.get("particle_identity", {}) as Dictionary
	var light_identity := profile.get("light_identity", {}) as Dictionary
	_orientation = String(geometry_identity.get("orientation", "forward"))
	_particle_flow = String(particle_identity.get("flow", "forward"))
	_particle_axis = _resolve_particle_axis(_particle_flow)
	_source_position = _vector_from_profile("source")
	_target_position = _vector_from_profile("target")
	_light_energy = clampf(float(light_identity.get("energy", 1.0)), 0.65, 1.65)
	_light_motif = String(light_identity.get("motif", ""))
	_cadence = String(profile.get("cadence", "cinematic_three_beat"))
	_choreography = (profile.get("choreography", {}) as Dictionary).duplicate(true)
	_choreography_family = _resolve_choreography_family(profile)
	_piece_motion_kind = _resolve_piece_motion_kind(_choreography_family)
	_piece_motion_signature = _resolve_piece_motion_signature(profile)
	_beat_pattern = _resolve_beat_pattern(profile.get("beat_pattern", []))
	_palette = _resolve_palette(profile)
	_accent_colors = _resolve_accents(profile)
	_blessing_overlays = _resolve_runtime_blessing_overlays(profile)
	_profile["runtime_blessing_overlays"] = _blessing_overlays.duplicate(true)
	_evolution_level = clampi(int(profile.get("runtime_evolution_level", 1)), 1, 3)
	_buff_stacks = maxi(0, int(profile.get("runtime_buff_stacks", 0)))
	var diameter := clampf(float(profile.get("material_diameter", DEFAULT_DIAMETER)), 280.0, 620.0)
	var texture_size := _material_texture.get_size()
	_base_material_scale = diameter / maxf(1.0, maxf(texture_size.x, texture_size.y))
	_piece_shape_scale = diameter / DEFAULT_DIAMETER
	for layer_name in MATERIAL_LAYER_NAMES:
		var sprite := _material_layers[layer_name] as Sprite2D
		sprite.texture = _material_texture
		sprite.scale = Vector2.ONE * _base_material_scale
		(sprite.material as ShaderMaterial).set_shader_parameter("semantic_texture", _material_texture)
	if not _rebuild_semantic_pieces(profile):
		_configured = false
		return false
	_configure_particles(particle_identity, diameter)
	_rebuild_blessing_overlay_passes(diameter)
	_configured = true
	reset()
	return true


func set_progress(value: float) -> void:
	if not _configured:
		return
	var previous := _progress
	_progress = clampf(value, 0.0, 1.0)
	_stage_name = _resolve_stage(_progress)
	_apply_storyboard_choreography()
	_apply_particle_choreography(previous)
	_apply_blessing_overlay_choreography(previous)


func reset() -> void:
	_progress = 0.0
	_stage_name = STAGE_ANTICIPATION
	_source_particles_fired = false
	_contact_particles_fired = false
	_residue_particles_fired = false
	_blessing_particles_fired.clear()
	for layer_name in MATERIAL_LAYER_NAMES:
		var sprite := _material_layers.get(layer_name) as Sprite2D
		if sprite == null:
			continue
		sprite.visible = false
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		sprite.modulate = Color.WHITE
		_set_shader_state(sprite, 0.0, 0.0, 0.0, 0.0, Vector2.RIGHT, Color.WHITE, false, 1.0)
	for particle_name in PARTICLE_LAYER_NAMES:
		var particles := _particle_layers.get(particle_name) as CPUParticles2D
		if particles == null:
			continue
		particles.emitting = false
		particles.modulate.a = 0.0
	for overlay_index in _blessing_overlay_passes.size():
		var overlay_pass := _blessing_overlay_passes[overlay_index]
		var overlay_root := overlay_pass.get("root") as Node2D
		var overlay_particles := overlay_pass.get("particles") as CPUParticles2D
		var overlay_light := overlay_pass.get("light") as PointLight2D
		if overlay_root != null:
			overlay_root.visible = false
		if overlay_particles != null:
			overlay_particles.emitting = false
			overlay_particles.modulate.a = 0.0
		if overlay_light != null:
			overlay_light.energy = 0.0
		_blessing_particles_fired[overlay_index] = false
	for piece in _semantic_pieces:
		piece.visible = false
		piece.position = Vector2.ZERO
		piece.rotation = 0.0
		piece.scale = Vector2.ONE * _base_material_scale
		piece.modulate = Color.WHITE
		_set_shader_state(piece, 0.0, 0.0, 0.0, 0.0, Vector2.RIGHT, Color.WHITE, false, 1.0)
	for shape in _semantic_shapes:
		shape.visible = false
		shape.position = Vector2.ZERO
		shape.rotation = 0.0
		shape.scale = Vector2.ONE * _piece_shape_scale
		shape.modulate = Color.WHITE
		shape.call("set_sequence_progress", 0.0)


func get_debug_state() -> Dictionary:
	var visible_material_layers := 0
	for layer_name in MATERIAL_LAYER_NAMES:
		var sprite := _material_layers.get(layer_name) as Sprite2D
		if sprite != null and sprite.visible:
			visible_material_layers += 1
	var sequence_state: Dictionary = {}
	if not _semantic_shapes.is_empty() and _semantic_shapes[0].has_method("get_debug_state"):
		sequence_state = _semantic_shapes[0].call("get_debug_state") as Dictionary
	return {
		"profile_id": _profile_id,
		"presentation_mode": "2_5d",
		"material_path": _material_path,
		"storyboard_path": _storyboard_path,
		"semantic_object": _semantic_object,
		"stage": String(_stage_name),
		"progress": _progress,
		"material_layer_count": MATERIAL_LAYER_NAMES.size(),
		"particle_layer_count": PARTICLE_LAYER_NAMES.size(),
		"blessing_overlay_count": _blessing_overlay_passes.size(),
		"blessing_overlay_limit": MAX_BLESSING_OVERLAY_PASSES,
		"blessing_overlay_ids": _blessing_overlay_ids(),
		"blessing_overlay_passes": _blessing_overlay_debug_passes(),
		"authored_object_layer_count": AUTHORED_OBJECT_LAYER_COUNT,
		"visible_material_layers": visible_material_layers,
		"meaningful_semantic_geometry": true,
		"decorative_line_geometry": false,
		"icon_echo": false,
		"legacy_atlas_visible": false,
		"orientation": _orientation,
		"particle_flow": _particle_flow,
		"applied_particle_axis": _particle_axis,
		"light_energy": _light_energy,
		"light_motif": _light_motif,
		"cadence": _cadence,
		"beat_pattern": _beat_pattern.duplicate(),
		"choreography_family": _choreography_family,
		"piece_count": _piece_specs.size(),
		"visible_piece_count": _visible_piece_count(),
		"piece_motion_signature": _piece_motion_signature,
		"authored_sequence_path": String(sequence_state.get("sequence_path", "")),
		"authored_frame_count": int(sequence_state.get("authored_frame_count", 0)),
		"authored_frame_index": int(sequence_state.get("frame_index", -1)),
		"authored_timeline_frame_index": int(sequence_state.get("timeline_frame_index", -1)),
		"authored_grid_columns": int(sequence_state.get("grid_columns", 0)),
		"authored_grid_rows": int(sequence_state.get("grid_rows", 0)),
		"ground_anchor_ratio": float(sequence_state.get("ground_anchor_ratio", 0.0)),
		"y_registration_enabled": bool(sequence_state.get("y_registration_enabled", false)),
		"frame_row_registration_offsets": sequence_state.get("frame_row_registration_offsets", []),
		"row_baselines": sequence_state.get("row_baselines", []),
		"registered_row_baselines": sequence_state.get("registered_row_baselines", []),
		"current_frame_registration_offset_y": float(sequence_state.get("current_frame_registration_offset_y", 0.0)),
		"authored_playback_map": sequence_state.get("playback_map", []),
		"authored_source_position": sequence_state.get("source_position", Vector2(999.0, 999.0)),
		"authored_source_rotation": float(sequence_state.get("source_rotation", 999.0)),
		"authored_frame_animation": bool(sequence_state.get("authored_frame_animation", false)),
		"crossfade_slideshow": bool(sequence_state.get("crossfade_slideshow", true)),
		"texture_filter_uses_mipmaps": bool(sequence_state.get("texture_filter_uses_mipmaps", true)),
		"atlas_edge_inset": float(sequence_state.get("atlas_edge_inset", 0.0)),
		"sprite_part_sequence": true,
		"procedural_flat_object": false,
		"full_plate_travel": false,
		"phase_signature": _phase_signature(),
	}


func get_layer_count() -> int:
	return BASE_VISUAL_LAYER_COUNT


func get_active_layer_count() -> int:
	return get_total_visual_layer_count() if _configured else 0


func get_base_visual_layer_count() -> int:
	return BASE_VISUAL_LAYER_COUNT


func get_total_visual_layer_count() -> int:
	return BASE_VISUAL_LAYER_COUNT + _blessing_overlay_passes.size() * 2


func get_particle_layer_count() -> int:
	return PARTICLE_LAYER_NAMES.size() + _blessing_overlay_passes.size()


func get_stage_name() -> StringName:
	return _stage_name


func _ensure_layers() -> void:
	if not _material_layers.is_empty():
		return
	for index in MATERIAL_LAYER_NAMES.size():
		var layer_name := MATERIAL_LAYER_NAMES[index]
		var sprite := Sprite2D.new()
		sprite.name = layer_name
		sprite.z_index = index - 4
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var shader_material := ShaderMaterial.new()
		shader_material.shader = MATERIAL_SHADER
		sprite.material = shader_material
		sprite.visible = false
		sprite.modulate.a = 0.0
		add_child(sprite)
		_material_layers[layer_name] = sprite
	for index in PARTICLE_LAYER_NAMES.size():
		var particle_name := PARTICLE_LAYER_NAMES[index]
		var particles := CPUParticles2D.new()
		particles.name = particle_name
		particles.z_index = index - 1
		particles.one_shot = true
		particles.emitting = false
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particles.material = additive
		add_child(particles)
		_particle_layers[particle_name] = particles
	_piece_root = Node2D.new()
	_piece_root.name = &"SemanticPieces"
	_piece_root.z_index = 1
	add_child(_piece_root)
	_blessing_overlay_root = Node2D.new()
	_blessing_overlay_root.name = &"BlessingOverlays"
	_blessing_overlay_root.z_index = 7
	add_child(_blessing_overlay_root)


func _resolve_runtime_blessing_overlays(profile: Dictionary) -> Array[Dictionary]:
	var overlay_values: Variant = profile.get("runtime_blessing_overlays", null)
	if (
		not overlay_values is Array
		and get_parent() != null
		and get_parent().has_meta("finisher_blessing_overlays")
	):
		overlay_values = get_parent().get_meta("finisher_blessing_overlays")
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	if not overlay_values is Array:
		return result
	for overlay_variant in overlay_values as Array:
		if not overlay_variant is Dictionary:
			continue
		var overlay := (overlay_variant as Dictionary).duplicate(true)
		var gift_id := String(overlay.get("id", "")).strip_edges()
		if gift_id.is_empty() or seen_ids.has(gift_id):
			continue
		var elements: Array[String] = []
		for element_variant in overlay.get(
			"elements",
			[overlay.get("element", "normal")]
		) as Array:
			var element := _normalize_blessing_element(String(element_variant))
			if not elements.has(element):
				elements.append(element)
		if elements.is_empty():
			elements.append("normal")
		overlay["id"] = gift_id
		overlay["elements"] = elements
		overlay["element"] = elements[0]
		overlay["kind"] = String(overlay.get("kind", "base"))
		overlay["evolved"] = bool(
			overlay.get("evolved", String(overlay["kind"]) == "evolved")
		)
		overlay["level"] = clampi(int(overlay.get("level", 1)), 1, 3)
		result.append(overlay)
		seen_ids[gift_id] = true
		if result.size() >= MAX_BLESSING_OVERLAY_PASSES:
			break
	return result


func _rebuild_blessing_overlay_passes(diameter: float) -> void:
	if _blessing_overlay_root == null:
		return
	for child in _blessing_overlay_root.get_children():
		_blessing_overlay_root.remove_child(child)
		child.free()
	_blessing_overlay_passes.clear()
	_blessing_particles_fired.clear()
	for overlay_index in _blessing_overlays.size():
		var overlay := _blessing_overlays[overlay_index]
		var style := _blessing_style(overlay)
		var pass_root := Node2D.new()
		pass_root.name = "BlessingPass%02d_%s" % [
			overlay_index + 1,
			String(overlay.get("id", "gift")),
		]
		pass_root.z_index = overlay_index
		_blessing_overlay_root.add_child(pass_root)

		var particles := CPUParticles2D.new()
		particles.name = &"SourceParticles"
		particles.one_shot = true
		particles.emitting = false
		particles.local_coords = false
		particles.amount = 7 + int(overlay.get("level", 1)) * 3 + (4 if bool(overlay.get("evolved", false)) else 0)
		particles.lifetime = 0.58 + float(overlay.get("level", 1)) * 0.1
		particles.explosiveness = 0.88
		particles.randomness = 0.28
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(diameter * 0.032, diameter * 0.012)
		particles.direction = style.get("direction", Vector2.RIGHT) as Vector2
		particles.spread = 18.0 + float(overlay_index) * 6.0
		particles.gravity = _blessing_particle_gravity(String(overlay.get("element", "normal")), diameter)
		particles.initial_velocity_min = diameter * (0.12 + float(overlay_index) * 0.018)
		particles.initial_velocity_max = diameter * (0.28 + float(overlay.get("level", 1)) * 0.025)
		particles.scale_amount_min = 0.42
		particles.scale_amount_max = 0.82 + float(overlay.get("level", 1)) * 0.08
		var primary_color := Color(String(style.get("light_color", "#ffffff")))
		var secondary_color := Color(String(style.get("secondary_color", "#ffffff")))
		particles.color_ramp = _particle_color_ramp(primary_color, secondary_color)
		particles.texture = _blessing_particle_texture(
			String(style.get("particle_source", "four_point_prism")),
			primary_color,
			secondary_color
		)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particles.material = additive
		pass_root.add_child(particles)

		var colored_light := PointLight2D.new()
		colored_light.name = &"SourceLight"
		colored_light.color = primary_color
		colored_light.energy = 0.0
		colored_light.texture = _blessing_light_texture(primary_color, secondary_color)
		colored_light.texture_scale = 1.5 + float(overlay.get("level", 1)) * 0.22
		colored_light.blend_mode = Light2D.BLEND_MODE_ADD
		colored_light.shadow_enabled = false
		pass_root.add_child(colored_light)

		var source_position := _blessing_source_position(
			String(overlay.get("element", "normal")),
			overlay_index,
			diameter
		)
		particles.position = source_position
		colored_light.position = source_position
		pass_root.set_meta("gift_id", String(overlay.get("id", "")))
		pass_root.set_meta("particle_source", String(style.get("particle_source", "")))
		pass_root.set_meta("light_color", primary_color.to_html(false))
		_blessing_overlay_passes.append({
			"root": pass_root,
			"particles": particles,
			"light": colored_light,
			"gift_id": String(overlay.get("id", "")),
			"kind": String(overlay.get("kind", "base")),
			"evolved": bool(overlay.get("evolved", false)),
			"level": int(overlay.get("level", 1)),
			"elements": (overlay.get("elements", []) as Array).duplicate(),
			"components": (overlay.get("components", []) as Array).duplicate(),
			"particle_source": String(style.get("particle_source", "")),
			"light_color": primary_color.to_html(false),
			"secondary_light_color": secondary_color.to_html(false),
			"source_position": source_position,
			"base_light_energy": 0.42 + float(overlay.get("level", 1)) * 0.16 + (0.22 if bool(overlay.get("evolved", false)) else 0.0),
		})
		_blessing_particles_fired[overlay_index] = false


func _apply_blessing_overlay_choreography(previous: float) -> void:
	for overlay_index in _blessing_overlay_passes.size():
		var overlay_pass := _blessing_overlay_passes[overlay_index]
		var pass_root := overlay_pass.get("root") as Node2D
		var particles := overlay_pass.get("particles") as CPUParticles2D
		var colored_light := overlay_pass.get("light") as PointLight2D
		if pass_root == null or particles == null or colored_light == null:
			continue
		var source_position := overlay_pass.get("source_position", Vector2.ZERO) as Vector2
		var source_time := 0.08 + float(overlay_index) * 0.055
		var arrival_time := 0.48 + float(overlay_index) * 0.035
		var travel := smoothstep(source_time, arrival_time, _progress)
		var source_presence := _window(
			maxf(0.0, source_time - 0.05),
			source_time,
			0.56 + float(overlay_index) * 0.025,
			0.76 + float(overlay_index) * 0.018
		)
		var contact_light := _window(0.5, 0.62, 0.77, 0.9)
		var afterglow := _window(0.76, 0.82, 0.94, 1.0)
		pass_root.visible = source_presence > 0.002 or contact_light > 0.002 or afterglow > 0.002
		particles.position = source_position.lerp(Vector2.ZERO, travel)
		particles.modulate.a = source_presence * (0.72 + float(overlay_index) * 0.08)
		colored_light.position = source_position.lerp(Vector2.ZERO, smoothstep(source_time, 0.66, _progress))
		colored_light.energy = float(overlay_pass.get("base_light_energy", 0.6)) * (
			source_presence * 0.48 + contact_light + afterglow * 0.26
		)
		if (
			not bool(_blessing_particles_fired.get(overlay_index, false))
			and previous < source_time
			and _progress >= source_time
		):
			_blessing_particles_fired[overlay_index] = true
			particles.restart()
			particles.emitting = true


func _blessing_style(overlay: Dictionary) -> Dictionary:
	var element := _normalize_blessing_element(String(overlay.get("element", "normal")))
	var style := (BLESSING_ELEMENT_STYLES.get(
		element,
		BLESSING_ELEMENT_STYLES["normal"]
	) as Dictionary).duplicate(true)
	if bool(overlay.get("evolved", false)):
		style["particle_source"] = "evolved_fusion_prism"
		var accent_color := String(overlay.get("accent_color", ""))
		if Color.html_is_valid(accent_color):
			style["light_color"] = accent_color
		var elements := overlay.get("elements", []) as Array
		if elements.size() > 1:
			var secondary_style := BLESSING_ELEMENT_STYLES.get(
				_normalize_blessing_element(String(elements[1])),
				BLESSING_ELEMENT_STYLES["normal"]
			) as Dictionary
			style["secondary_color"] = String(secondary_style.get("light_color", "#ffffff"))
	return style


func _blessing_source_position(element: String, index: int, diameter: float) -> Vector2:
	var scale_ratio := diameter / DEFAULT_DIAMETER
	var lane_offset := float(index - 1) * 34.0
	match _normalize_blessing_element(element):
		"fire": return Vector2(-138.0 + lane_offset, 92.0) * scale_ratio
		"ice": return Vector2(-184.0, 38.0 + lane_offset * 0.45) * scale_ratio
		"lightning": return Vector2(-72.0 + lane_offset, -162.0) * scale_ratio
		"poison": return Vector2(-154.0 + lane_offset, 104.0) * scale_ratio
		"wind": return Vector2(-192.0, -24.0 + lane_offset) * scale_ratio
		"dark": return Vector2(-124.0 + lane_offset, -92.0) * scale_ratio
		_: return Vector2(-148.0 + lane_offset, 54.0) * scale_ratio


func _blessing_particle_gravity(element: String, diameter: float) -> Vector2:
	match _normalize_blessing_element(element):
		"fire": return Vector2(0.0, -diameter * 0.08)
		"ice": return Vector2(0.0, diameter * 0.34)
		"lightning": return Vector2(0.0, diameter * 0.52)
		"poison": return Vector2(0.0, diameter * 0.2)
		"wind": return Vector2(0.0, -diameter * 0.04)
		"dark": return Vector2(0.0, diameter * 0.08)
		_: return Vector2(0.0, diameter * 0.16)


func _normalize_blessing_element(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	match normalized:
		"flame": return "fire"
		"frost": return "ice"
		"storm", "thunder": return "lightning"
		"venom": return "poison"
		"gale": return "wind"
		"void", "shadow": return "dark"
	return normalized if BLESSING_ELEMENT_STYLES.has(normalized) else "normal"


func _blessing_overlay_ids() -> Array[String]:
	var result: Array[String] = []
	for overlay in _blessing_overlays:
		result.append(String(overlay.get("id", "")))
	return result


func _blessing_overlay_debug_passes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for overlay_pass in _blessing_overlay_passes:
		var particles := overlay_pass.get("particles") as CPUParticles2D
		var colored_light := overlay_pass.get("light") as PointLight2D
		result.append({
			"gift_id": String(overlay_pass.get("gift_id", "")),
			"kind": String(overlay_pass.get("kind", "base")),
			"evolved": bool(overlay_pass.get("evolved", false)),
			"level": int(overlay_pass.get("level", 1)),
			"elements": (overlay_pass.get("elements", []) as Array).duplicate(),
			"components": (overlay_pass.get("components", []) as Array).duplicate(),
			"particle_source": String(overlay_pass.get("particle_source", "")),
			"light_color": String(overlay_pass.get("light_color", "")),
			"secondary_light_color": String(overlay_pass.get("secondary_light_color", "")),
			"source_position": overlay_pass.get("source_position", Vector2.ZERO),
			"has_source_particles": particles != null,
			"has_colored_light": colored_light != null,
			"particle_texture_assigned": particles != null and particles.texture != null,
			"particles_emitting": particles != null and particles.emitting,
			"current_light_energy": colored_light.energy if colored_light != null else 0.0,
			"generic_line_or_ring": false,
		})
	return result


func _apply_storyboard_choreography() -> void:
	var axis := _motion_axis()
	var travel_axis := axis if axis.length_squared() > 0.1 else Vector2.UP
	var beat := _beat_pulse(_progress)
	var contact := _range(0.58, 0.8)
	var evolution_gain := 1.0 + float(_evolution_level - 1) * 0.06 + minf(0.1, float(_buff_stacks) * 0.01)
	_apply_piece_choreography(travel_axis, evolution_gain, beat)

	# Complete material plates are design references, never runtime layers.  A
	# second contact plate changes the apparent ground plane and can read as a
	# diagonal lane or an unrelated second climax behind the authored object.
	for layer_name in MATERIAL_LAYER_NAMES:
		var sprite := _material_layers[layer_name] as Sprite2D
		sprite.visible = false
		sprite.modulate.a = 0.0


func _rebuild_semantic_pieces(profile: Dictionary) -> bool:
	for piece in _semantic_pieces:
		if is_instance_valid(piece):
			_piece_root.remove_child(piece)
			piece.free()
	_semantic_pieces.clear()
	for shape in _semantic_shapes:
		if is_instance_valid(shape):
			_piece_root.remove_child(shape)
			shape.free()
	_semantic_shapes.clear()
	_piece_specs.clear()
	_piece_base_positions.clear()
	_piece_specs = _resolve_piece_specs(profile)
	var sequence_path := _resolve_authored_sequence_path()
	if sequence_path.is_empty() or not ResourceLoader.exists(sequence_path, "Texture2D"):
		push_error("Finisher motion family has no authored sequence: %s (%s)" % [_piece_motion_kind, sequence_path])
		return false
	var grid := _resolve_authored_sequence_grid(sequence_path)
	var stabilize_y := _orientation not in ["descending", "rainy", "upward", "vertical"]
	var playback_map := AUTHORED_FRAME_PLAYBACK_MAPS.get(_piece_motion_kind, []) as Array
	var semantic_shape := SEMANTIC_PIECE_SCRIPT.new() as Node2D
	semantic_shape.name = "AuthoredFrameSequence"
	semantic_shape.z_index = 8
	_piece_root.add_child(semantic_shape)
	var configured := bool(semantic_shape.call(
		"configure",
		sequence_path,
		_semantic_object,
		absi(_profile_id.hash()),
		grid.x,
		grid.y,
		0.82,
		_light_energy,
		stabilize_y,
		playback_map
	))
	if not configured:
		_piece_root.remove_child(semantic_shape)
		semantic_shape.free()
		return false
	_semantic_shapes.append(semantic_shape)
	return true


func _resolve_piece_specs(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var authored_parts := profile.get("parts", []) as Array
	if not authored_parts.is_empty():
		for part_variant in authored_parts:
			var part := part_variant as Dictionary
			var rect_values := part.get("region", []) as Array
			if rect_values.size() != 4:
				continue
			result.append({
				"role": String(part.get("role", "semantic")),
				"region": Rect2(float(rect_values[0]), float(rect_values[1]), float(rect_values[2]), float(rect_values[3])),
			})
	if not result.is_empty():
		return result
	var roles: Array[String] = []
	var piece_counts := _choreography.get("piece_count", {}) as Dictionary
	for role_variant in piece_counts:
		var role := String(role_variant)
		for _piece_index in maxi(0, int(piece_counts[role_variant])):
			roles.append(role)
	if roles.is_empty():
		roles = ["body", "leading_edge", "contact", "residue", "hero_fragment", "echo"]
	var count := roles.size()
	var columns := maxi(2, ceili(sqrt(float(count))))
	var rows := maxi(2, ceili(float(count) / float(columns)))
	var usable := Vector2(0.88, 0.88)
	var cell_size := Vector2(usable.x / float(columns), usable.y / float(rows))
	for index in count:
		var column := index % columns
		var row := index / columns
		var position := Vector2(0.06, 0.06) + Vector2(float(column), float(row)) * cell_size
		var overlap := Vector2(0.014, 0.014)
		var region := Rect2(position - overlap, cell_size + overlap * 2.0)
		region.position.x = clampf(region.position.x, 0.0, 0.96)
		region.position.y = clampf(region.position.y, 0.0, 0.96)
		region.size.x = minf(region.size.x, 1.0 - region.position.x)
		region.size.y = minf(region.size.y, 1.0 - region.position.y)
		result.append({"role": roles[index], "region": region})
	return result


func _resolve_authored_sequence_path() -> String:
	return String(AUTHORED_SEQUENCE_PATHS.get(_piece_motion_kind, ""))


func _resolve_authored_sequence_grid(_sequence_path: String) -> Vector2i:
	return Vector2i(4, 3)


func _formation_target_position(index: int, count: int, role: String) -> Vector2:
	if index == 0:
		return Vector2.ZERO
	var ratio := float(index - 1) / maxf(1.0, float(count - 1))
	var angle := ratio * TAU - PI * 0.5
	var formation := String(_choreography.get("formation", "staggered_assembly")).to_lower()
	if "lane" in formation or "line" in formation:
		return Vector2(-145.0 + ratio * 290.0, 28.0 + float(index % 2) * 36.0)
	if "ground" in formation or "root" in formation or "basin" in formation:
		return Vector2(-150.0 + ratio * 300.0, 118.0 - sin(ratio * PI) * 52.0)
	if "column" in formation or "pillar" in role.to_lower():
		return Vector2(-130.0 + ratio * 260.0, 70.0 - float(index % 3) * 52.0)
	return Vector2.from_angle(angle) * (72.0 + float(index % 3) * 28.0)


func _apply_piece_choreography(_travel_axis: Vector2, evolution_gain: float, _beat: float) -> void:
	if _semantic_shapes.is_empty():
		return
	var semantic_shape := _semantic_shapes[0]
	semantic_shape.visible = _progress > 0.0 and _progress < 1.0
	semantic_shape.modulate.a = _window(0.0, 0.035, 0.96, 1.0)
	# The authored frames own direction, contact and elevation.  The node itself
	# stays locked to the target ground anchor: no whole-sheet rotation, diagonal
	# slide, or negative Y projection can push the painted floor below the map.
	semantic_shape.position = Vector2.ZERO
	semantic_shape.rotation = 0.0
	semantic_shape.scale = Vector2.ONE * _piece_shape_scale * evolution_gain
	semantic_shape.z_index = 8
	semantic_shape.call("set_sequence_progress", _progress)


func _piece_pose(index: int, order_ratio: float, build: float, impact: float, afterglow: float, base: Vector2, axis: Vector2, perpendicular: Vector2) -> Dictionary:
	var side := -1.0 if index % 2 == 0 else 1.0
	var family_phase := float(absi(_choreography_family.hash()) % 997) / 997.0
	var formation_scale := 0.86 + float(absi(String(_choreography.get("formation", "")).hash()) % 31) / 100.0
	var contact_scale := 0.82 + float(absi(String(_choreography.get("impact", "")).hash()) % 37) / 100.0
	var pose := {
		"position": base,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"alpha": 1.0,
		"dissolve": 0.7,
		"warp": 0.16,
		"reveal_axis": axis,
	}
	match _piece_motion_kind:
		"fire_spiral":
			var fire_role := String(_piece_specs[index].get("role", ""))
			var river_x := lerpf(-210.0, base.x, build)
			var river_y := 72.0 + sin((build * 1.8 + order_ratio) * PI * 2.0) * 48.0
			pose.position = Vector2(river_x, river_y).lerp(base, build * 0.62)
			pose.rotation = atan2(cos((build * 1.8 + order_ratio) * PI * 2.0), 1.0) * 0.42
			if "blade" in fire_role:
				pose.position = Vector2(18.0, 82.0).lerp(base + Vector2(0.0, -105.0 * impact), build)
				pose.rotation = lerpf(-0.65, -PI * 0.5, build)
				pose.scale = Vector2(lerpf(0.35, 0.82, build), lerpf(0.5, 1.55, build))
			else:
				pose.scale = Vector2(lerpf(0.48, 1.0, build), lerpf(0.32, 0.92, build))
			pose.position += Vector2(side * afterglow * (55.0 + order_ratio * 35.0), afterglow * 36.0)
			pose.warp = 0.46
		"ice_chain":
			var chain_offset := Vector2(-110.0 + order_ratio * 220.0, 150.0 + float(index % 3) * 28.0)
			pose.position = (base + chain_offset).lerp(base, build)
			pose.position += (base.normalized() if base.length_squared() > 1.0 else perpendicular * side) * impact * (24.0 + order_ratio * 38.0)
			pose.scale = Vector2(lerpf(0.48, 1.0, build), lerpf(0.08, 1.0, build))
			pose.rotation = side * (1.0 - build) * 0.16 + impact * side * 0.08
			pose.reveal_axis = Vector2.UP
		"ice_fire_bloom":
			var frost_role := String(_piece_specs[index].get("role", ""))
			if "fire" in frost_role:
				pose.position = Vector2(base.x * 0.25, 165.0).lerp(Vector2(base.x * 0.25, -55.0), build)
				pose.rotation = -PI * 0.5
				pose.scale = Vector2(lerpf(0.24, 0.74, build), lerpf(0.35, 1.55, build))
			else:
				var petal_direction := Vector2.from_angle(order_ratio * TAU - PI * 0.5)
				pose.position = petal_direction * lerpf(22.0, 96.0, build) + base * 0.35
				pose.position += petal_direction * impact * (30.0 + order_ratio * 28.0)
				pose.rotation = petal_direction.angle() + PI * 0.5
				pose.scale = Vector2(lerpf(0.12, 0.92, build), lerpf(0.2, 1.0, build))
			pose.reveal_axis = Vector2.UP
		"lightning_nodes", "marker_chain":
			var electric_role := String(_piece_specs[index].get("role", ""))
			if _piece_motion_kind == "lightning_nodes":
				var prison_direction := Vector2.from_angle(order_ratio * PI * 1.65 + PI * 0.68)
				pose.position = (prison_direction * 185.0 + Vector2(0.0, 95.0)).lerp(base, build)
				pose.scale = Vector2(lerpf(0.3, 1.0, build), lerpf(0.08, 1.25, build))
				if "spear" in electric_role:
					pose.position = Vector2(-180.0, -145.0).lerp(Vector2(90.0, 65.0), impact)
					pose.rotation = 0.72
					pose.scale = Vector2(1.25, 0.7)
				else:
					pose.position += prison_direction * impact * 20.0
			else:
				# Ground-root network grows outward first; only authored marker/spear
				# roles rise into the staggered vertical strikes.
				var network_direction := Vector2.from_angle(order_ratio * PI * 1.65 + PI * 0.68)
				pose.position = (Vector2.ZERO).lerp(base + network_direction * 48.0, build)
				pose.scale = Vector2(lerpf(0.08, 1.0, build), lerpf(0.28, 0.72, build))
				if "marker" in electric_role:
					pose.position += Vector2(sin(order_ratio * TAU) * 54.0, -sin(build * PI) * 88.0)
				if "spear" in electric_role:
					pose.position = base - Vector2(0.0, 210.0 * (1.0 - impact))
					pose.scale = Vector2(0.48, lerpf(0.2, 1.35, impact))
			pose.alpha = 0.72 + 0.28 * _beat_pulse(_progress)
			pose.warp = 0.34
			pose.reveal_axis = Vector2.DOWN
		"mountain_release", "stone_orbit_counter", "guard_replay", "mirror_return", "shield_exchange":
			var assembly_direction := base.normalized() if base.length_squared() > 4.0 else Vector2.from_angle(order_ratio * TAU)
			var spawn_distance := 125.0 + float(index % 3) * 24.0
			if _piece_motion_kind == "mountain_release":
				assembly_direction = Vector2(0.0, 1.0)
				spawn_distance = 130.0 + order_ratio * 80.0
			if _piece_motion_kind == "stone_orbit_counter":
				assembly_direction = Vector2.from_angle(order_ratio * TAU + build * 0.45)
			if _piece_motion_kind == "guard_replay":
				assembly_direction = Vector2(-1.0, -0.35 + order_ratio * 0.7).normalized()
			if _piece_motion_kind == "mirror_return":
				assembly_direction = Vector2.from_angle(float(index % 4) * PI * 0.5 + PI * 0.25)
			if _piece_motion_kind == "shield_exchange":
				assembly_direction = Vector2(side, 0.18).normalized()
			pose.position = (base + assembly_direction * spawn_distance).lerp(base, build)
			var release_direction := assembly_direction
			if _piece_motion_kind == "guard_replay" or _piece_motion_kind == "mirror_return":
				release_direction = -assembly_direction
			if _piece_motion_kind == "shield_exchange":
				release_direction = Vector2(side, -0.12)
			pose.position += release_direction * impact * (18.0 + float(index % 2) * 22.0) * contact_scale
			pose.rotation = side * (1.0 - build) * 0.55 - side * impact * (0.46 if _piece_motion_kind == "mirror_return" else 0.24)
			pose.scale = Vector2(lerpf(0.62, 1.0, build), lerpf(0.8, 1.0, build))
		"poison_bloom", "leaf_shell_relay", "root_intercept", "garden_growth", "garden_canopy", "lifeline_return":
			var root_position := Vector2(base.x * 0.35, 175.0 + absf(base.x) * 0.12)
			if _piece_motion_kind == "leaf_shell_relay":
				root_position = Vector2(-155.0 + order_ratio * 310.0, -170.0)
			if _piece_motion_kind == "root_intercept" or _piece_motion_kind == "lifeline_return":
				root_position = Vector2(-190.0 + order_ratio * 380.0, 145.0)
			if _piece_motion_kind == "garden_canopy":
				root_position = Vector2(side * 150.0, 155.0)
			if _piece_motion_kind == "poison_bloom":
				root_position = Vector2(0.0, 132.0)
			pose.position = root_position.lerp(base, build)
			pose.position += perpendicular * side * sin(build * PI) * 16.0
			if _piece_motion_kind == "poison_bloom":
				pose.position += Vector2(side * impact * 52.0, impact * 28.0)
			if _piece_motion_kind == "leaf_shell_relay":
				pose.position += Vector2(0.0, impact * 36.0)
			if _piece_motion_kind == "root_intercept":
				pose.position += Vector2(-side * impact * 46.0, -impact * 18.0)
			if _piece_motion_kind == "garden_growth":
				pose.position += Vector2(side * impact * 24.0, -impact * 36.0)
			if _piece_motion_kind == "garden_canopy":
				pose.position += Vector2(-side * impact * 28.0, -impact * 44.0)
			if _piece_motion_kind == "lifeline_return":
				pose.position += Vector2(-side * impact * 62.0, -impact * 12.0)
			pose.scale = Vector2(lerpf(0.32, 1.0, build), lerpf(0.04, 1.0, build))
			pose.rotation = side * (1.0 - build) * 0.18
			pose.reveal_axis = Vector2.UP
			pose.warp = 0.24
		"breath_condense", "wellspring_overflow", "stream_collection":
			var water_role := String(_piece_specs[index].get("role", ""))
			if _piece_motion_kind == "breath_condense":
				var helix_angle := build * TAU * 1.25 + order_ratio * TAU
				var helix_radius := lerpf(155.0, 24.0, build)
				pose.position = base * build + Vector2(cos(helix_angle) * helix_radius, sin(helix_angle) * helix_radius * 0.42)
				pose.rotation = helix_angle + PI * 0.5
				pose.scale = Vector2(lerpf(0.38, 0.82, build), lerpf(0.22, 1.0, build))
			elif _piece_motion_kind == "wellspring_overflow":
				pose.position = Vector2(base.x * 0.42, 155.0).lerp(base, build)
				if "shield" in water_role:
					pose.position += Vector2(side * impact * 72.0, -impact * 58.0)
					pose.scale = Vector2(lerpf(0.2, 1.45, impact), lerpf(0.4, 0.78, impact))
				else:
					pose.position += Vector2(0.0, -impact * 85.0)
					pose.scale = Vector2(lerpf(0.42, 0.86, build), lerpf(0.1, 1.3, build))
			else:
				var route_x := lerpf(-210.0, 185.0, build)
				var route_y := sin((build * 1.4 + order_ratio) * TAU) * (48.0 + float(index % 3) * 13.0)
				pose.position = Vector2(route_x, route_y).lerp(base, impact)
				pose.rotation = atan2(cos((build * 1.4 + order_ratio) * TAU), 1.0) * 0.35
				pose.scale = Vector2(lerpf(0.35, 1.05, build), lerpf(0.5, 0.88, build))
			pose.warp = 0.4
		"boundary_feather_return":
			var launch_direction := Vector2.from_angle(order_ratio * TAU - PI * 0.5)
			var outward := sin(build * PI) * (135.0 + float(index % 5) * 14.0)
			pose.position = base + launch_direction * outward
			pose.position = pose.position.lerp(base, impact * impact)
			pose.rotation = launch_direction.angle() + PI * 0.5 + (1.0 - impact) * side * 0.24
			pose.scale = Vector2.ONE * lerpf(0.55, 1.0, build)
		"feather_cadence":
			# Short, short, long: three primary lanes and their delayed echoes.
			var cadence_slot := index % 3
			var cadence_length: float = float([90.0, 112.0, 190.0][cadence_slot])
			var lane_offset := perpendicular * (-58.0 + float(cadence_slot) * 58.0)
			pose.position = (base - axis * cadence_length + lane_offset).lerp(base + axis * impact * cadence_length * 0.34, build)
			pose.rotation = axis.angle() + float(cadence_slot - 1) * 0.11
			pose.scale = Vector2(lerpf(0.48, 0.82 + float(cadence_slot) * 0.16, build), lerpf(0.66, 1.0, build))
		"hinged_feather_return":
			var semantic_role := String(_piece_specs[index].get("role", ""))
			if "plow" in semantic_role:
				pose.position = (base - axis * 230.0 + perpendicular * 80.0).lerp(base - axis * 28.0, build)
				pose.rotation = axis.angle() + 0.38 * (1.0 - build)
				pose.scale = Vector2.ONE * lerpf(0.72, 1.45, build)
			else:
				var hinge_direction := Vector2.from_angle(order_ratio * PI * 1.4 - PI * 0.7)
				pose.position = base + hinge_direction * sin(build * PI) * (160.0 + float(index % 4) * 16.0)
				pose.position = pose.position.lerp(base, impact * impact)
				pose.rotation = hinge_direction.angle() + PI * 0.5 + side * (1.0 - impact) * 0.58
				pose.scale = Vector2.ONE * lerpf(0.48, 0.94, build)
		"spirit_procession":
			var patrol_lane := index % 3
			var patrol_angle := build * TAU * 0.72 + float(patrol_lane) * TAU / 3.0
			var patrol_radius := 105.0 - float(patrol_lane) * 18.0
			pose.position = base + Vector2(cos(patrol_angle), sin(patrol_angle) * 0.48) * patrol_radius * (1.0 - impact)
			pose.position.y += impact * 52.0
			pose.rotation = patrol_angle + PI * 0.5
			pose.scale = Vector2.ONE * lerpf(0.38, 1.0, build) * lerpf(1.0, 1.18, impact)
		"wind_lanes", "orbit_launch":
			if _piece_motion_kind == "wind_lanes":
				var lane := perpendicular * (-90.0 + order_ratio * 180.0)
				pose.position = base - axis * (230.0 * (1.0 - build)) + lane * (1.0 - build) + axis * impact * 68.0
				pose.scale = Vector2(lerpf(0.16, 1.15, build), lerpf(0.82, lerpf(1.0, 0.18, impact), build))
				pose.rotation = side * 0.08 * (1.0 - build)
			else:
				var orbit_role := String(_piece_specs[index].get("role", ""))
				if "moon" in orbit_role:
					pose.position = Vector2.ZERO.lerp(axis * 155.0, impact)
					pose.rotation = lerpf(-0.4, axis.angle(), impact)
					pose.scale = Vector2.ONE * lerpf(0.45, 1.35, impact)
				else:
					var orbit_angle := order_ratio * TAU + build * TAU * 0.7
					pose.position = Vector2.from_angle(orbit_angle) * lerpf(65.0, 138.0, build)
					pose.position += axis * impact * 35.0
					pose.rotation = orbit_angle + PI * 0.5
					pose.scale = Vector2(lerpf(0.34, 0.9, build), lerpf(0.6, 1.0, build))
			pose.warp = 0.52
		"elemental_clash", "wheel_machine":
			if _piece_motion_kind == "elemental_clash":
				var clash_side := -1.0 if order_ratio < 0.5 else 1.0
				pose.position = (base + Vector2(clash_side * 185.0, -55.0 + order_ratio * 110.0)).lerp(base, build)
				pose.position += Vector2(clash_side * impact * 28.0, -impact * 8.0)
				pose.rotation = -clash_side * (1.0 - build) * 0.38
				pose.scale = Vector2(lerpf(0.34, 1.08, build), lerpf(0.58, 1.0, build))
			else:
				var wheel_role := String(_piece_specs[index].get("role", ""))
				var radius := 72.0 + float(index % 3) * 36.0
				var wheel_angle := order_ratio * TAU + build * TAU * (1.5 + float(index % 2) * 0.4)
				pose.position = Vector2.from_angle(wheel_angle) * radius - axis * (155.0 * (1.0 - build)) + axis * impact * 48.0
				pose.rotation = wheel_angle + PI * 0.5
				pose.scale = Vector2.ONE * (1.18 if "outer" in wheel_role else 0.82)
		"forged_ribs", "horizon_reversal", "rain_downpour", "lunar_descent", "bone_machine", "blade_volley":
			var source_lane := -axis * (190.0 + order_ratio * 95.0) + perpendicular * (-80.0 + order_ratio * 160.0)
			var forged_role := String(_piece_specs[index].get("role", ""))
			if _piece_motion_kind == "forged_ribs":
				var rib_slot := index % 3
				source_lane = Vector2(-190.0 - float(rib_slot) * 44.0, 76.0 - float(rib_slot) * 54.0)
				if "rib" in forged_role:
					pose.scale = Vector2.ONE * (0.62 + float(rib_slot) * 0.24)
			if _piece_motion_kind == "rain_downpour":
				source_lane = Vector2(-95.0 + order_ratio * 190.0, -220.0 - float(index % 4) * 28.0)
			if _piece_motion_kind == "lunar_descent":
				source_lane = Vector2(-30.0 + order_ratio * 60.0, -285.0 - float(index % 3) * 22.0)
			if _piece_motion_kind == "horizon_reversal":
				source_lane = Vector2(-230.0 + order_ratio * 60.0, perpendicular.y * 12.0)
			if _piece_motion_kind == "bone_machine":
				source_lane = Vector2.from_angle(order_ratio * PI + PI) * 140.0
			pose.position = (base + source_lane * formation_scale).lerp(base, build) + axis * impact * (26.0 + order_ratio * 34.0) * contact_scale
			pose.scale = Vector2(lerpf(0.38, 1.0, build), lerpf(0.72, 1.0, build))
			if _piece_motion_kind == "lunar_descent":
				pose.position += Vector2(side * impact * 34.0, impact * 58.0)
				pose.scale = Vector2.ONE * lerpf(0.48, 1.34 if "moon" in forged_role else 0.84, build)
			if _piece_motion_kind == "rain_downpour":
				pose.position.y += impact * 82.0
				pose.scale = Vector2(lerpf(0.32, 0.76, build), lerpf(0.18, 1.28, build))
			pose.rotation = side * (1.0 - build) * 0.32 + impact * side * 0.1
		_:
			pose.position = (base - axis * 170.0 + perpendicular * side * 70.0).lerp(base, build)
	# Residue direction is authored per family instead of sharing one universal
	# upward drift. The family phase also prevents related moves from tracing the
	# same curve when they share an archetype helper.
	var residue_axis := _residue_axis_for_motion(_piece_motion_kind, side, order_ratio)
	pose.position += residue_axis * afterglow * (10.0 + order_ratio * 22.0) * contact_scale
	pose.rotation = float(pose.rotation) + (family_phase - 0.5) * afterglow * 0.22
	return pose


func _residue_axis_for_motion(kind: String, side: float, order_ratio: float) -> Vector2:
	match kind:
		"fire_spiral": return Vector2(side * 0.82, 0.38).normalized()
		"ice_chain", "ice_fire_bloom": return Vector2(side * 0.36, 0.94).normalized()
		"rain_downpour", "lunar_descent": return Vector2(side * 0.2, 1.0).normalized()
		"boundary_feather_return", "hinged_feather_return": return Vector2.from_angle(order_ratio * TAU)
		"feather_cadence": return Vector2(0.92, 0.18 + side * 0.12).normalized()
		"lightning_nodes", "marker_chain": return Vector2(side * 0.18, -1.0).normalized()
		"mountain_release", "stone_orbit_counter": return Vector2(side, 0.22).normalized()
		"guard_replay", "mirror_return": return Vector2(-1.0, side * 0.24).normalized()
		"shield_exchange": return Vector2(side, 0.12).normalized()
		"poison_bloom", "leaf_shell_relay", "root_intercept", "garden_growth", "garden_canopy", "lifeline_return", "spirit_procession": return Vector2(side * 0.42, 0.9).normalized()
		"breath_condense", "wellspring_overflow", "stream_collection": return Vector2(side * 0.24, 0.97).normalized()
		"wind_lanes", "orbit_launch": return Vector2(0.96, side * 0.28).normalized()
		"elemental_clash", "wheel_machine": return Vector2(side, 0.08).normalized()
		_: return Vector2(0.92, side * 0.18).normalized()


func _resolve_choreography_family(profile: Dictionary) -> String:
	var choreography := profile.get("choreography", {}) as Dictionary
	var family := String(choreography.get("family", "")).strip_edges()
	if not family.is_empty():
		return family
	var geometry := profile.get("geometry_identity", {}) as Dictionary
	return String(geometry.get("choreography_family", geometry.get("motif", "blade_volley")))


func _resolve_piece_motion_kind(family: String) -> String:
	const EXACT_FAMILY_MOTIONS := {
		"forged_rib_acceleration": "forged_ribs",
		"horizon_shear_reversal": "horizon_reversal",
		"staggered_blade_downpour": "rain_downpour",
		"lunar_guillotine_descent": "lunar_descent",
		"feather_blade_boundary_return": "boundary_feather_return",
		"load_bearing_mountain_release": "mountain_release",
		"irregular_guard_orbit_counter": "stone_orbit_counter",
		"ribcage_to_knuckle_transformation": "bone_machine",
		"three_lane_delayed_shear": "wind_lanes",
		"reverse_flow_breath_core": "breath_condense",
		"basin_column_overflow_shield": "wellspring_overflow",
		"guardian_slab_recorded_replay": "guard_replay",
		"hunting_lava_river_cremation": "fire_spiral",
		"coffin_plate_chain_fracture": "ice_chain",
		"pillar_prison_to_rail_spear": "lightning_nodes",
		"poison_orchid_bidirectional_release": "poison_bloom",
		"sequential_dawn_heal_to_leaf_shell": "leaf_shell_relay",
		"three_spirit_patrol_returning_bloom": "spirit_procession",
		"living_root_lifeline_intercept": "root_intercept",
		"state_reading_garden_growth": "garden_growth",
		"short_short_long_feather_echo": "feather_cadence",
		"plow_launch_hinged_return": "hinged_feather_return",
		"four_panel_directional_mirror_return": "mirror_return",
		"wind_water_route_collection_overflow": "stream_collection",
		"sequential_material_state_exchange": "elemental_clash",
		"rolling_three_material_blade_machine": "wheel_machine",
		"ice_orchid_preserve_then_upcut": "ice_fire_bloom",
		"garden_arch_basin_canopy_growth": "garden_canopy",
		"three_lifeline_knot_targeted_return": "lifeline_return",
		"anchored_hinged_shield_force_exchange": "shield_exchange",
		"broken_orbit_track_center_launch": "orbit_launch",
		"root_network_marker_chain_strike": "marker_chain",
	}
	return String(EXACT_FAMILY_MOTIONS.get(family, "blade_volley"))


func _resolve_piece_motion_signature(profile: Dictionary) -> String:
	var choreography := profile.get("choreography", {}) as Dictionary
	var path_values := choreography.get("paths", []) as Array
	var paths: Array[String] = []
	for path_value in path_values:
		paths.append(String(path_value))
	return "%s|%s|%s|%s" % [
		String(choreography.get("family", _choreography_family)),
		String(choreography.get("formation", "staggered_assembly")),
		">".join(paths),
		String(choreography.get("impact", "direct_contact")),
	]


func _primitive_for_piece(index: int, role: String) -> String:
	var primitives := _choreography.get("spawn_primitives", []) as Array
	var authored := String(primitives[index % primitives.size()]) if not primitives.is_empty() else role
	var role_lower := role.to_lower()
	var lowered := (role + " " + authored).to_lower()
	if "spirit" in role_lower:
		return "spirit"
	if "mud" in role_lower:
		return "mud_bead"
	if "toxin" in role_lower or "poison_sac" in role_lower:
		return "toxin_sac"
	if "scar" in role_lower:
		return "scar"
	if "groove" in role_lower or "trench" in role_lower:
		return "ground_groove"
	if "fountain" in role_lower or "sap" in role_lower:
		return "fountain"
	if "seed" in role_lower:
		return "seed"
	if "trunk" in role_lower:
		return "trunk"
	if "feather" in lowered:
		return "feather"
	if "petal" in lowered or "orchid" in lowered or "bud" in lowered:
		return "petal"
	if "blade" in lowered or "cutter" in lowered or "wedge" in lowered or "spear" in lowered:
		return "flame_tongue" if _piece_motion_kind == "fire_spiral" else "blade"
	if "ice" in lowered or "frost" in lowered:
		return "ice_spike"
	if "fire" in lowered or "flame" in lowered or "molten" in lowered or "ember" in lowered:
		return "flame_tongue"
	if "lightning" in lowered or "plasma" in lowered or "electric" in lowered or "chain_arc" in lowered:
		return "lightning_pillar"
	if "mirror" in lowered:
		return "mirror_slab"
	if "shield" in lowered or "guard" in lowered or "slab" in lowered or "plate" in lowered or "clamp" in lowered:
		return "shield_slab"
	if "leaf" in lowered or "sepal" in lowered or "moss" in lowered:
		return "leaf"
	if "vine" in lowered or "stem" in lowered:
		return "vine"
	if "water" in lowered or "spring" in lowered or "silk" in lowered or "stream" in lowered or "fluid" in lowered or "sap" in lowered:
		return "water_ribbon"
	if "moon" in lowered or "lunar" in lowered:
		return "moon"
	if "rock" in lowered or "basalt" in lowered or "slate" in lowered or "stone" in lowered or "crust" in lowered:
		return "rock"
	if "bone" in lowered or "rib" in lowered or "sternum" in lowered:
		return "bone"
	if "root" in lowered or "branch" in lowered or "channel" in lowered or "tube" in lowered or "spine" in lowered or "ridge" in lowered or "trail" in lowered or "track" in lowered:
		return "tether"
	if "petal" in lowered or "orchid" in lowered or "bud" in lowered:
		return "petal"
	if "marker" in lowered or "crystal" in lowered or "node" in lowered or "pearl" in lowered or "core" in lowered:
		return "marker"
	if "puddle" in lowered or "wave" in lowered or "mist" in lowered or "fault" in lowered:
		return "ground_wave"
	return "blade"


func _phase_signature() -> String:
	var pose_parts: Array[String] = []
	for index in mini(4, _semantic_shapes.size()):
		var shape := _semantic_shapes[index]
		pose_parts.append("%d:%d:%d" % [
			roundi(shape.position.x / 8.0),
			roundi(shape.position.y / 8.0),
			roundi(shape.rotation * 12.0),
		])
	return "%s|%s|v%d|%s" % [
		_choreography_family,
		String(_stage_name),
		_visible_piece_count(),
		",".join(pose_parts),
	]


func _visible_piece_count() -> int:
	var count := 0
	for shape in _semantic_shapes:
		if shape.visible and shape.modulate.a > 0.002:
			count += 1
	return count


func _set_sprite_pose(sprite: Sprite2D, alpha: float, scale_multiplier: Vector2, offset: Vector2, rotation_value: float) -> void:
	sprite.visible = alpha > 0.002
	sprite.modulate.a = clampf(alpha, 0.0, 1.0)
	sprite.scale = Vector2.ONE * _base_material_scale * scale_multiplier
	sprite.position = offset
	sprite.rotation = rotation_value


func _set_shader_state(sprite: Sprite2D, reveal: float, dissolve: float, warp: float, energy: float, reveal_axis: Vector2, tint: Color, edge_only: bool, edge_width: float) -> void:
	var shader_material := sprite.material as ShaderMaterial
	shader_material.set_shader_parameter("reveal", clampf(reveal, 0.0, 1.0))
	shader_material.set_shader_parameter("dissolve", clampf(dissolve, 0.0, 1.0))
	shader_material.set_shader_parameter("warp", clampf(warp, 0.0, 1.0))
	shader_material.set_shader_parameter("energy", maxf(0.0, energy))
	shader_material.set_shader_parameter("reveal_axis", reveal_axis.normalized() if reveal_axis.length_squared() > 0.1 else Vector2.UP)
	shader_material.set_shader_parameter("tint", tint)
	shader_material.set_shader_parameter("edge_only", edge_only)
	shader_material.set_shader_parameter("edge_width", edge_width)
	shader_material.set_shader_parameter("phase", _progress * (4.0 + _cadence_frequency()))


func _configure_particles(identity: Dictionary, diameter: float) -> void:
	var authored_count := clampi(int(identity.get("count", 48)), 18, 96)
	var hero_count := clampi(int(identity.get("hero_count", 6)), 1, 14)
	var spread := clampf(float(identity.get("spread", 0.58)), 0.12, 0.82)
	var gravity_ratio := clampf(float(identity.get("gravity", 0.0)), -1.0, 1.0)
	var axis := _particle_axis
	_setup_particle_layer(_particle_layers[&"SourceFragments"], maxi(7, authored_count / 5), diameter, spread * 0.65, gravity_ratio, -axis if "inward" in _particle_flow else axis, 0.18, 0.46, _palette[1], Vector2i(8, 22))
	_setup_particle_layer(_particle_layers[&"ContactFragments"], hero_count, diameter, spread * 0.5, gravity_ratio, axis, 0.52, 0.92, _highlight_color(), Vector2i(10, 34))
	_setup_particle_layer(_particle_layers[&"ResidueFragments"], maxi(8, authored_count / 4), diameter, spread * 0.72, gravity_ratio, axis, 0.28, 0.62, _palette[0], Vector2i(8, 18))


func _setup_particle_layer(particles: CPUParticles2D, amount: int, diameter: float, spread: float, gravity_ratio: float, axis: Vector2, speed_min_ratio: float, speed_max_ratio: float, color: Color, texture_size: Vector2i) -> void:
	particles.amount = amount
	particles.lifetime = 0.82
	particles.explosiveness = 0.9
	particles.randomness = 0.46
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = diameter * 0.045
	particles.direction = axis
	particles.spread = spread * 90.0
	particles.gravity = Vector2(0.0, diameter * 0.3 * gravity_ratio)
	particles.initial_velocity_min = diameter * speed_min_ratio
	particles.initial_velocity_max = diameter * speed_max_ratio
	particles.scale_amount_min = 0.48
	particles.scale_amount_max = 1.1
	particles.color_ramp = _particle_color_ramp(color, _highlight_color())
	particles.texture = _particle_texture(color, texture_size)


func _apply_particle_choreography(previous: float) -> void:
	var source := _particle_layers[&"SourceFragments"] as CPUParticles2D
	source.modulate.a = _window(0.1, 0.18, 0.46, 0.62) * 0.42
	if not _source_particles_fired and _progress >= 0.15:
		_source_particles_fired = true
		source.restart()
		source.emitting = true
	if not _contact_particles_fired and _progress >= 0.6 and previous < 0.6:
		_contact_particles_fired = true
		var contact := _particle_layers[&"ContactFragments"] as CPUParticles2D
		contact.modulate.a = 0.76
		contact.restart()
		contact.emitting = true
	if not _residue_particles_fired and _progress >= 0.74 and previous < 0.74:
		_residue_particles_fired = true
		var residue := _particle_layers[&"ResidueFragments"] as CPUParticles2D
		residue.modulate.a = 0.46
		residue.restart()
		residue.emitting = true


func _motion_axis() -> Vector2:
	match _orientation:
		"descending", "rainy": return Vector2.DOWN
		"upward", "vertical": return Vector2.UP
		"horizontal": return Vector2.RIGHT
		"returning": return Vector2.LEFT
		"inward", "radial", "orbiting", "linked", "grounded": return Vector2.ZERO
		_: return Vector2.RIGHT


func _construction_start_offset(travel_axis: Vector2) -> Vector2:
	match _orientation:
		"forward", "horizontal":
			var authored_offset := _source_position - _target_position
			return authored_offset.limit_length(220.0) if authored_offset.length_squared() > 1.0 else -travel_axis * 150.0
		"descending", "rainy": return Vector2(0.0, -180.0)
		"upward", "vertical": return Vector2(0.0, 110.0)
		"returning": return -travel_axis * 84.0
		_: return -travel_axis * 42.0 if travel_axis.length_squared() > 0.1 else Vector2(0.0, 24.0)


func _resolve_particle_axis(flow: String) -> Vector2:
	var lowered := flow.to_lower()
	if "descending" in lowered or "vertical_strike" in lowered: return Vector2.DOWN
	if "upward" in lowered or "ascending" in lowered: return Vector2.UP
	if "return" in lowered or "reverse" in lowered: return Vector2.LEFT
	if "forward" in lowered or "rail" in lowered: return Vector2.RIGHT
	if "ground" in lowered: return Vector2(0.76, -0.28).normalized()
	var angle := float(absi((_profile_id + flow).hash()) % 360) * PI / 180.0
	return Vector2.from_angle(angle)


func _vector_from_profile(key: String) -> Vector2:
	var value := _profile.get(key, []) as Array
	if value.size() != 2:
		return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1]))


func _resolve_stage(value: float) -> StringName:
	if value < 0.22: return STAGE_ANTICIPATION
	if value < 0.58: return STAGE_EXECUTION
	if value < 0.78: return STAGE_IMPACT
	return STAGE_AFTERGLOW


func _window(start: float, fade_in_end: float, fade_out_start: float, end: float) -> float:
	if _progress <= start or _progress >= end:
		return 0.0
	return smoothstep(start, fade_in_end, _progress) * (1.0 - smoothstep(fade_out_start, end, _progress))


func _range(start: float, end: float) -> float:
	return clampf((_progress - start) / maxf(0.001, end - start), 0.0, 1.0)


func _resolve_beat_pattern(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if value is Array:
		for beat in value as Array:
			result.append(clampf(float(beat), 0.0, 1.0))
	return result


func _beat_pulse(value: float) -> float:
	var pulse := 0.0
	for beat in _beat_pattern:
		pulse = maxf(pulse, 1.0 - smoothstep(0.0, 0.065, absf(value - beat)))
	return pulse


func _cadence_frequency() -> float:
	var lowered := _cadence.to_lower()
	if "rain" in lowered or "staccato" in lowered or "volley" in lowered: return 7.0
	if "hold" in lowered or "sustain" in lowered or "deep" in lowered: return 2.5
	return 4.0 + float(absi(_cadence.hash()) % 3)


func _resolve_palette(profile: Dictionary) -> Array[Color]:
	var values := ((profile.get("light_identity", {}) as Dictionary).get("palette", []) as Array)
	var defaults := [Color("86e7ff"), Color("6e78c9"), Color("fff8d4")]
	var result: Array[Color] = []
	for index in 3:
		result.append(_color_from_variant(values[index] if values.size() > index else defaults[index], defaults[index]))
	return result


func _resolve_accents(profile: Dictionary) -> Array[Color]:
	var result: Array[Color] = []
	for value in ((profile.get("light_identity", {}) as Dictionary).get("accent_palette", []) as Array):
		result.append(_color_from_variant(value, _palette[0]))
	return result


func _highlight_color() -> Color:
	return _accent_colors[0] if not _accent_colors.is_empty() else _palette[2]


func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color: return value as Color
	if value is String and Color.html_is_valid(String(value)): return Color(String(value))
	return fallback


func _blessing_particle_texture(
	particle_source: String,
	primary: Color,
	secondary: Color
) -> Texture2D:
	const TEXTURE_SIZE := 28
	var image := Image.create(
		TEXTURE_SIZE,
		TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var point := Vector2(
				(float(x) + 0.5) / float(TEXTURE_SIZE) * 2.0 - 1.0,
				(float(y) + 0.5) / float(TEXTURE_SIZE) * 2.0 - 1.0
			)
			var alpha := _blessing_shape_alpha(particle_source, point)
			if alpha <= 0.001:
				continue
			var color := primary.lerp(secondary, clampf((1.0 - point.y) * 0.42, 0.0, 0.82))
			color.a = alpha
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _blessing_shape_alpha(particle_source: String, point: Vector2) -> float:
	match particle_source:
		"flame_tongue":
			var flame_width := 0.16 + clampf((point.y + 0.88) * 0.34, 0.0, 0.55)
			var flame_distance := absf(point.x + sin(point.y * 4.2) * 0.11) / flame_width
			return clampf((1.0 - maxf(flame_distance, absf(point.y + 0.02) * 0.92)) * 5.0, 0.0, 1.0)
		"faceted_ice_shard":
			var shard_distance := absf(point.x) * 1.18 + absf(point.y + 0.05) * 0.72
			var shard_alpha := clampf((0.9 - shard_distance) * 7.0, 0.0, 1.0)
			if point.y > 0.35 and absf(point.x) > 0.28:
				shard_alpha *= 0.2
			return shard_alpha
		"forked_lightning_splinter":
			var trunk_distance := minf(
				_distance_to_segment(point, Vector2(-0.28, -0.92), Vector2(0.16, -0.25)),
				minf(
					_distance_to_segment(point, Vector2(0.16, -0.25), Vector2(-0.12, 0.02)),
					_distance_to_segment(point, Vector2(-0.12, 0.02), Vector2(0.34, 0.9))
				)
			)
			var fork_distance := _distance_to_segment(
				point,
				Vector2(0.02, 0.2),
				Vector2(-0.62, 0.64)
			)
			return clampf((0.15 - minf(trunk_distance, fork_distance)) * 9.0, 0.0, 1.0)
		"three_lobed_toxin_spore":
			var lobe_alpha := 0.0
			for center in [Vector2(-0.34, 0.22), Vector2(0.34, 0.22), Vector2(0.0, -0.34)]:
				lobe_alpha = maxf(lobe_alpha, clampf((0.46 - point.distance_to(center)) * 8.0, 0.0, 1.0))
			return lobe_alpha * clampf((0.98 - point.length() * 0.12), 0.0, 1.0)
		"cut_wind_leaf":
			var leaf_center := sin(point.x * PI) * 0.2
			var leaf_width := (1.0 - absf(point.x)) * 0.46
			return clampf((leaf_width - absf(point.y - leaf_center)) * 8.0, 0.0, 1.0)
		"void_crescent_mote":
			var outer := point.distance_to(Vector2(-0.08, 0.0))
			var inner := point.distance_to(Vector2(0.27, -0.04))
			return clampf((0.78 - outer) * 8.0, 0.0, 1.0) * clampf((inner - 0.54) * 10.0, 0.0, 1.0)
		"evolved_fusion_prism":
			var vertical_prism := absf(point.x) * 1.8 + absf(point.y) * 0.62
			var horizontal_prism := absf(point.x) * 0.62 + absf(point.y) * 1.8
			return clampf((0.86 - minf(vertical_prism, horizontal_prism)) * 6.0, 0.0, 1.0)
		_:
			var prism_distance := minf(
				absf(point.x) * 1.7 + absf(point.y) * 0.7,
				absf(point.x) * 0.7 + absf(point.y) * 1.7
			)
			return clampf((0.82 - prism_distance) * 6.0, 0.0, 1.0)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _blessing_light_texture(primary: Color, secondary: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.56, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.88),
		Color(secondary.r, secondary.g, secondary.b, 0.62),
		Color(primary.r, primary.g, primary.b, 0.24),
		Color(primary.r, primary.g, primary.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture


func _particle_color_ramp(color: Color, highlight: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		Color(highlight.r, highlight.g, highlight.b, 0.88),
		Color(color.r, color.g, color.b, 0.58),
		Color(color.r, color.g, color.b, 0.0),
	])
	return gradient


func _particle_texture(color: Color, size: Vector2i) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.94),
		Color(color.r, color.g, color.b, 0.84),
		Color(color.r, color.g, color.b, 0.34),
		Color(color.r, color.g, color.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = size.x
	texture.height = size.y
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
