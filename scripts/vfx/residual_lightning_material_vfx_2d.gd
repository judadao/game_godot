class_name ResidualLightningMaterialVFX2D
extends Node2D

const SURFACE_ARCS_PER_TARGET := 2
const CURRENT_HOPS_PER_TARGET := 5.0

@onready var charge_sparks: GPUParticles2D = $ChargeSparks

var _tier_rank := 1
var _palette: Array[Color] = [Color.WHITE, Color("63d7ff"), Color("765cff")]
var _parameters: Dictionary = {}
var _target_positions: Array[Vector2] = []
var _progress := 0.0
var _active_target_index := 0
var _last_active_target_index := -1
var _configured := false
var _target_position_provider := Callable()
var _spark_emitter_pool: Array[GPUParticles2D] = []
var _spark_emitter_cursor := 0
var _particle_trigger_count := 0


func _ready() -> void:
	clear()


func configure(
	source_sprites: Array,
	tier_rank: int,
	palette_values: Array,
	parameters: Dictionary,
	target_positions: Array = []
) -> void:
	clear()
	_tier_rank = clampi(tier_rank, 1, 3)
	_palette = _resolve_palette(palette_values)
	_parameters = parameters.duplicate(true)
	for sprite_variant in source_sprites:
		if sprite_variant is Sprite2D:
			(sprite_variant as Sprite2D).visible = false
	for position_variant in target_positions:
		if position_variant is Vector2:
			_target_positions.append(position_variant)
	if _target_positions.is_empty():
		_target_positions = _fallback_target_positions()
	_configure_charge_sparks()
	_configured = true
	visible = true
	set_progress(0.0)


func clear() -> void:
	_configured = false
	visible = false
	_progress = 0.0
	_active_target_index = 0
	_last_active_target_index = -1
	_target_positions.clear()
	_target_position_provider = Callable()
	_spark_emitter_cursor = 0
	_particle_trigger_count = 0
	for emitter in _spark_emitter_pool:
		if not is_instance_valid(emitter):
			continue
		emitter.emitting = false
		if emitter != charge_sparks:
			remove_child(emitter)
			emitter.free()
	_spark_emitter_pool.clear()
	queue_redraw()


func set_target_position_provider(provider: Callable) -> void:
	_target_position_provider = provider
	_refresh_target_positions()


func set_progress(value: float) -> void:
	if not _configured:
		return
	_progress = clampf(value, 0.0, 1.0)
	_refresh_target_positions()
	var hop_count := maxi(1, _target_positions.size())
	_active_target_index = posmod(
		floori(_progress * float(hop_count) * CURRENT_HOPS_PER_TARGET),
		hop_count
	)
	if _active_target_index != _last_active_target_index:
		_trigger_charge_sparks(_active_target_index)
		_last_active_target_index = _active_target_index
	queue_redraw()


func get_active_layer_count() -> int:
	return 5 if _configured else 0


func get_debug_state() -> Dictionary:
	return {
		"visual_family": "lightning",
		"tier_rank": _tier_rank,
		"progress": _progress,
		"layer_count": get_active_layer_count(),
		"material_layer_count": 5,
		"procedural_material": true,
		"blessing_mutable": true,
		"target_marker_count": _target_positions.size(),
		"surface_arc_count": _target_positions.size() * SURFACE_ARCS_PER_TARGET + (1 if not _target_positions.is_empty() else 0),
		"active_target_index": _active_target_index,
		"target_positions": _target_positions.duplicate(),
		"spark_emitter_pool_size": _spark_emitter_pool.size(),
		"particle_trigger_count": _particle_trigger_count,
		"motion_model": "target_surface_current",
		"visible_route_line_count": 0,
		"final_strike_owned_by_gameplay_event": true,
		"rhythm_beats": [
			"mark_ionization", "surface_crawl", "conductive_jump", "residual_flicker",
		],
		"parameters": _parameters.duplicate(true),
	}


func _draw() -> void:
	if not _configured:
		return
	for target_index in _target_positions.size():
		var is_active := target_index == _active_target_index
		var previous_index := posmod(_active_target_index - 1, _target_positions.size())
		var is_afterglow := target_index == previous_index
		_draw_target_charge(_target_positions[target_index], target_index, is_active, is_afterglow)


func _draw_target_charge(
	center: Vector2,
	target_index: int,
	is_active: bool,
	is_afterglow: bool
) -> void:
	var flicker_step := floori(_progress * 96.0)
	var pulse := 0.70 + 0.30 * sin(_progress * TAU * 21.0 + float(target_index) * 1.73)
	var strength := 1.0 if is_active else (0.52 if is_afterglow else 0.24)
	strength *= pulse
	var arc_count := SURFACE_ARCS_PER_TARGET + (1 if is_active else 0)
	for arc_index in arc_count:
		var points := _surface_arc_points(center, target_index, arc_index, flicker_step)
		draw_polyline(points, Color(_palette[2], 0.13 * strength), 11.0 + float(_tier_rank), false)
		draw_polyline(points, Color(_palette[1], 0.62 * strength), 4.2, false)
		draw_polyline(points, Color(_palette[0], 0.94 * strength), 1.35, false)
		if is_active:
			_draw_surface_branch(points, target_index, arc_index, flicker_step, strength)
	var corona_radius := 25.0 + float(_tier_rank) * 3.0
	for fragment_index in 3:
		var phase := _progress * 8.0 + float(target_index) * 0.63 + float(fragment_index) * 2.0
		var start_angle := fposmod(phase, TAU)
		draw_arc(
			center,
			corona_radius + float(fragment_index) * 5.0,
			start_angle,
			start_angle + 0.46 + float(fragment_index) * 0.08,
			7,
			Color(_palette[1], strength * (0.34 - float(fragment_index) * 0.06)),
			2.3 - float(fragment_index) * 0.35
		)
	if is_active:
		var flash := 0.55 + 0.45 * sin(_progress * TAU * 34.0)
		draw_circle(center, 7.0 + flash * 4.0, Color(_palette[0], 0.36 * flash))
		draw_circle(center, 18.0 + flash * 6.0, Color(_palette[1], 0.10 * flash))


func _surface_arc_points(
	center: Vector2,
	target_index: int,
	arc_index: int,
	flicker_step: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var seed := target_index * 131 + arc_index * 43 + flicker_step * 17
	var start_angle := fposmod(float(seed) * 0.173, TAU)
	var sweep := 0.82 + float((seed >> 2) % 5) * 0.11
	var radius_x := 20.0 + float((target_index + arc_index) % 4) * 4.0
	var radius_y := 34.0 + float((target_index * 2 + arc_index) % 4) * 5.0
	for point_index in 7:
		var ratio := float(point_index) / 6.0
		var angle := start_angle + sweep * ratio
		var jitter := _signed_hash(seed + point_index * 29) * (4.0 + float(_tier_rank)) * sin(ratio * PI)
		var radial := Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		var normal := radial.normalized()
		points.append(center + radial + normal * jitter)
	return points


func _draw_surface_branch(
	points: PackedVector2Array,
	target_index: int,
	arc_index: int,
	flicker_step: int,
	strength: float
) -> void:
	if points.size() < 5:
		return
	var anchor_index := 2 + posmod(target_index + arc_index + flicker_step, 3)
	var anchor := points[anchor_index]
	var tangent := (points[anchor_index + 1] - points[anchor_index - 1]).normalized()
	var side := -1.0 if posmod(target_index + arc_index + flicker_step, 2) == 0 else 1.0
	var branch_end := anchor + tangent.orthogonal() * side * (13.0 + float(arc_index) * 4.0)
	var branch := PackedVector2Array([
		anchor,
		anchor.lerp(branch_end, 0.48) + tangent * 4.0,
		branch_end,
	])
	draw_polyline(branch, Color(_palette[1], 0.48 * strength), 3.0, false)
	draw_polyline(branch, Color(_palette[0], 0.82 * strength), 1.0, false)


func _configure_charge_sparks() -> void:
	_spark_emitter_pool.clear()
	var duration_seconds := maxf(0.2, float(_parameters.get("duration_seconds", 1.6)))
	var hop_interval := duration_seconds / (float(maxi(1, _target_positions.size())) * CURRENT_HOPS_PER_TARGET)
	var pool_size := clampi(ceili(0.22 / maxf(0.001, hop_interval)) + 1, 2, 16)
	for emitter_index in pool_size:
		var emitter := charge_sparks if emitter_index == 0 else GPUParticles2D.new()
		if emitter_index > 0:
			emitter.name = "ChargeSparks%02d" % emitter_index
			emitter.z_index = charge_sparks.z_index
			emitter.visibility_rect = charge_sparks.visibility_rect
			emitter.use_parent_material = true
			add_child(emitter)
		_configure_spark_emitter(emitter)
		_spark_emitter_pool.append(emitter)


func _configure_spark_emitter(emitter: GPUParticles2D) -> void:
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 22.0 + float(_tier_rank) * 4.0
	particle_material.direction = Vector3(0.0, -1.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 52.0
	particle_material.initial_velocity_max = 138.0 + float(_tier_rank) * 18.0
	particle_material.gravity = Vector3(0.0, 42.0, 0.0)
	particle_material.damping_min = 8.0
	particle_material.damping_max = 26.0
	particle_material.scale_min = 1.4
	particle_material.scale_max = 3.6 + float(_tier_rank) * 0.5
	particle_material.color_ramp = _make_spark_ramp()
	emitter.process_material = particle_material
	emitter.amount = 12 + _tier_rank * 5
	emitter.lifetime = 0.22
	emitter.one_shot = true
	emitter.explosiveness = 0.96
	emitter.randomness = 0.34
	emitter.local_coords = false
	emitter.visibility_rect = Rect2(-700.0, -360.0, 1400.0, 620.0)
	emitter.texture = _make_spark_texture()
	emitter.emitting = false


func _trigger_charge_sparks(target_index: int) -> void:
	if _spark_emitter_pool.is_empty() or target_index < 0 or target_index >= _target_positions.size():
		return
	var emitter := _spark_emitter_pool[_spark_emitter_cursor % _spark_emitter_pool.size()]
	_spark_emitter_cursor += 1
	emitter.position = _target_positions[target_index]
	emitter.restart()
	emitter.emitting = true
	_particle_trigger_count += 1


func _refresh_target_positions() -> void:
	if not _target_position_provider.is_valid():
		return
	var provided: Variant = _target_position_provider.call()
	if not provided is Array:
		return
	var refreshed: Array[Vector2] = []
	var limit := maxi(1, int(_parameters.get("target_limit", 10)))
	for position_variant in provided as Array:
		if position_variant is Vector2:
			refreshed.append(position_variant)
		if refreshed.size() >= limit:
			break
	_target_positions = refreshed


func _fallback_target_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var count := 4 + _tier_rank * 2
	for index in count:
		var ratio := float(index) / float(maxi(1, count - 1))
		positions.append(Vector2(lerpf(-260.0, 260.0, ratio), -42.0 - sin(ratio * PI) * 58.0))
	return positions


func _signed_hash(value: int) -> float:
	var hashed := sin(float(value) * 12.9898 + 78.233) * 43758.5453
	return fposmod(hashed, 1.0) * 2.0 - 1.0


func _make_spark_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 1.0])
	gradient.colors = PackedColorArray([
		Color(_palette[0], 1.0), Color(_palette[1], 0.88), Color(_palette[2], 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 8
	texture.height = 20
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.gradient = gradient
	return texture


func _make_spark_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([
		Color(_palette[0], 1.0), Color(_palette[1], 0.78), Color(_palette[2], 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _resolve_palette(values: Array) -> Array[Color]:
	var result: Array[Color] = []
	for value in values:
		if value is Color:
			result.append(value)
		else:
			result.append(Color(String(value)))
	while result.size() < 3:
		result.append([Color.WHITE, Color("63d7ff"), Color("765cff")][result.size()])
	return result.slice(0, 3)
