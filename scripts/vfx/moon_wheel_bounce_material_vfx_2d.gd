class_name MoonWheelBounceMaterialVFX2D
extends Node2D

const ENERGY_SHADER := preload("res://shaders/vfx/moon_wheel_energy.gdshader")
const RHYTHM_BEATS := [
	"materialize", "accelerate", "wall_contact", "rebound_release", "residual_dissolve",
]
const ANTICIPATION_END := 0.12
const FLIGHT_END := 0.90
const ARENA_TOP := -196.0
const ARENA_BOTTOM := -18.0
const AFTERIMAGE_DISTANCES := [22.0, 44.0]
const AFTERIMAGE_SAMPLE_STEP := 0.00075
const MAX_AFTERIMAGE_SEARCH_STEPS := 96

@onready var contact_motes: GPUParticles2D = $ContactMotes

var _sprites: Array[Sprite2D] = []
var _aura_sprites: Array[Sprite2D] = []
var _bloom_sprites: Array[Sprite2D] = []
var _afterimage_sprites: Array[Sprite2D] = []
var _base_scales: Array[float] = []
var _tier_rank := 1
var _wheel_count := 5
var _round_trip_count := 1
var _range := 420.0
var _progress := 0.0
var _palette: Array[Color] = [Color.WHITE, Color("a8c9ff"), Color("7162d8")]
var _flash_positions: Array[Vector2] = []
var _flash_velocities: Array[Vector2] = []
var _flash_strengths: Array[float] = []
var _contact_mote_pool: Array[GPUParticles2D] = []
var _previous_horizontal_segments: Array[int] = []
var _previous_progress := 0.0
var _particle_trigger_count := 0


func _ready() -> void:
	clear()


func configure(source_sprites: Array, tier_rank: int, palette_values: Array, parameters: Dictionary) -> void:
	clear()
	_tier_rank = clampi(tier_rank, 1, 3)
	_wheel_count = maxi(5, int(parameters.get("wheel_count", [5, 8, 12][_tier_rank - 1])))
	_round_trip_count = maxi(1, int(parameters.get("round_trip_count", [1, 2, 3][_tier_rank - 1])))
	_range = maxf(160.0, float(parameters.get("radius", [420.0, 470.0, 540.0][_tier_rank - 1])))
	_palette = _resolve_palette(palette_values)
	for sprite_variant in source_sprites:
		if not sprite_variant is Sprite2D:
			continue
		var sprite := sprite_variant as Sprite2D
		sprite.visible = true
		sprite.modulate = Color(_palette[0], 0.0)
		_sprites.append(sprite)
		_base_scales.append(float(sprite.get_meta("base_scale", absf(sprite.scale.x))))
	_build_material_layers()
	_configure_contact_motes()
	visible = true
	set_progress(0.0)


func clear() -> void:
	visible = false
	_progress = 0.0
	_flash_positions.clear()
	_flash_velocities.clear()
	_flash_strengths.clear()
	_previous_horizontal_segments.clear()
	_previous_progress = 0.0
	_particle_trigger_count = 0
	for sprite in _aura_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	for sprite in _afterimage_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	for sprite in _bloom_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_aura_sprites.clear()
	_bloom_sprites.clear()
	_afterimage_sprites.clear()
	_sprites.clear()
	_base_scales.clear()
	for emitter in _contact_mote_pool:
		if not is_instance_valid(emitter):
			continue
		emitter.emitting = false
		if emitter != contact_motes:
			emitter.queue_free()
	_contact_mote_pool.clear()
	queue_redraw()


func set_progress(value: float) -> void:
	if _sprites.is_empty():
		return
	_progress = clampf(value, 0.0, 1.0)
	_flash_positions.clear()
	_flash_velocities.clear()
	_flash_strengths.clear()
	var timeline_moved_forward := _progress >= _previous_progress
	for index in _sprites.size():
		_update_wheel(index)
		var flash_strength := _boundary_flash_strength(index, _progress)
		if flash_strength > 0.12:
			_flash_positions.append(_wheel_position(index, _progress))
			_flash_velocities.append(_wheel_velocity(index, _progress))
			_flash_strengths.append(flash_strength)
		var horizontal_segment := _horizontal_bounce_segment(index, _progress)
		if index >= _previous_horizontal_segments.size():
			_previous_horizontal_segments.append(horizontal_segment)
		elif timeline_moved_forward and horizontal_segment != _previous_horizontal_segments[index]:
			_trigger_contact_motes(index)
			_previous_horizontal_segments[index] = horizontal_segment
	_previous_progress = _progress
	queue_redraw()


func get_active_layer_count() -> int:
	if not visible:
		return 0
	return _sprites.size() + _aura_sprites.size() + _bloom_sprites.size() + _afterimage_sprites.size() + 2


func get_debug_state() -> Dictionary:
	return {
		"series_id": "moon_wheel",
		"wheel_count": _wheel_count,
		"round_trip_count": _round_trip_count,
		"layer_count": get_active_layer_count(),
		"material_layer_count": 6,
		"per_wheel_glow_layer_count": 2,
		"following_glow_count": _aura_sprites.size() + _bloom_sprites.size(),
		"particle_emitter_pool_size": _contact_mote_pool.size(),
		"particle_trigger_count": _particle_trigger_count,
		"afterimage_world_distances": AFTERIMAGE_DISTANCES.duplicate(),
		"blessing_mutable": true,
		"progress": _progress,
		"motion_model": "bounded_pinball_reflection",
		"rhythm_beats": RHYTHM_BEATS.duplicate(),
		"active_rebound_flash_count": _flash_positions.size(),
		"visible_trajectory_line_count": 0,
		"opposing_launch_directions": true,
		"vertical_reflection_bands": 3 + _tier_rank,
	}


func _draw() -> void:
	for index in _flash_positions.size():
		_draw_rebound_contact(
			_flash_positions[index],
			_flash_velocities[index],
			_flash_strengths[index]
		)


func _build_material_layers() -> void:
	var bloom_texture := _make_bloom_texture()
	for index in _sprites.size():
		var source := _sprites[index]
		var bloom := Sprite2D.new()
		bloom.name = "MoonBloom%02d" % index
		bloom.texture = bloom_texture
		bloom.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bloom.z_index = -5
		bloom.use_parent_material = true
		add_child(bloom)
		_bloom_sprites.append(bloom)
		var aura := _make_energy_copy(source, "MoonAura%02d" % index, -2, 0.56, 1.20, float(index) * 0.13)
		add_child(aura)
		_aura_sprites.append(aura)
		for echo_index in AFTERIMAGE_DISTANCES.size():
			var echo := _make_energy_copy(
				source,
				"MoonEcho%02d_%d" % [index, echo_index],
				-3 - echo_index,
				0.24 - float(echo_index) * 0.07,
				1.06 + float(echo_index) * 0.04,
				0.31 + float(index) * 0.11 + float(echo_index) * 0.19
			)
			add_child(echo)
			_afterimage_sprites.append(echo)


func _make_energy_copy(
	source: Sprite2D,
	node_name: String,
	layer_z: int,
	alpha: float,
	scale_multiplier: float,
	phase: float
) -> Sprite2D:
	var copy := Sprite2D.new()
	copy.name = node_name
	copy.texture = source.texture
	copy.texture_filter = source.texture_filter
	copy.z_index = layer_z
	copy.set_meta("base_alpha", alpha)
	copy.set_meta("scale_multiplier", scale_multiplier)
	var material := ShaderMaterial.new()
	material.shader = ENERGY_SHADER
	material.set_shader_parameter("core_tint", _palette[0])
	material.set_shader_parameter("energy_tint", _palette[1])
	material.set_shader_parameter("shadow_tint", _palette[2])
	material.set_shader_parameter("energy_phase", phase)
	copy.material = material
	return copy


func _update_wheel(index: int) -> void:
	var sprite := _sprites[index]
	var position_value := _wheel_position(index, _progress)
	var velocity := _wheel_velocity(index, _progress)
	var appearance := _appearance_alpha(index)
	var flash_strength := _boundary_flash_strength(index, _progress)
	var base_scale := _base_scales[index]
	var compression := Vector2(
		1.0 - flash_strength * 0.13,
		1.0 + flash_strength * 0.18
	)
	sprite.position = position_value
	sprite.rotation = _wheel_rotation(index, velocity)
	sprite.scale = Vector2.ONE * base_scale * (0.78 + appearance * 0.22) * compression
	sprite.modulate = Color(_palette[0], appearance)
	_update_bloom_sprite(_bloom_sprites[index], sprite, base_scale, appearance, flash_strength)
	_update_energy_sprite(_aura_sprites[index], position_value, sprite.rotation, base_scale, appearance, flash_strength)
	for echo_index in AFTERIMAGE_DISTANCES.size():
		var echo := _afterimage_sprites[index * AFTERIMAGE_DISTANCES.size() + echo_index]
		var echo_sample := _afterimage_sample(index, _progress, AFTERIMAGE_DISTANCES[echo_index])
		var echo_timeline: float = echo_sample.timeline
		var echo_position: Vector2 = echo_sample.position
		var echo_velocity := _wheel_velocity(index, echo_timeline)
		var echo_alpha := appearance * float(echo.get_meta("base_alpha", 0.2)) * (1.0 - flash_strength * 0.35)
		echo.position = echo_position
		echo.rotation = _wheel_rotation(index, echo_velocity)
		echo.scale = Vector2.ONE * base_scale * float(echo.get_meta("scale_multiplier", 1.0))
		echo.modulate = Color(_palette[1], 1.0)
		_update_energy_material(echo, echo_alpha, flash_strength)


func _update_bloom_sprite(
	bloom: Sprite2D,
	source: Sprite2D,
	base_scale: float,
	appearance: float,
	flash_strength: float
) -> void:
	bloom.position = source.position
	var displayed_size := 144.0
	if source.texture != null:
		var texture_size := source.texture.get_size()
		displayed_size = maxf(texture_size.x, texture_size.y) * base_scale
	var bloom_scale := displayed_size / 96.0 * (1.38 + flash_strength * 0.18)
	bloom.scale = Vector2.ONE * bloom_scale
	bloom.modulate = Color(_palette[1], appearance * (0.28 + flash_strength * 0.24))


func _update_energy_sprite(
	sprite: Sprite2D,
	position_value: Vector2,
	rotation_value: float,
	base_scale: float,
	appearance: float,
	flash_strength: float
) -> void:
	sprite.position = position_value
	sprite.rotation = rotation_value
	sprite.scale = Vector2.ONE * base_scale * float(sprite.get_meta("scale_multiplier", 1.0)) * (1.0 + flash_strength * 0.14)
	var alpha := appearance * float(sprite.get_meta("base_alpha", 0.5))
	# Alpha belongs to the material so the CanvasItem modulation does not square
	# faint aura/afterimage values and erase the short material echoes.
	sprite.modulate = Color(_palette[1], 1.0)
	_update_energy_material(sprite, alpha, flash_strength)


func _update_energy_material(sprite: Sprite2D, alpha: float, flash_strength: float) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("timeline", _progress)
	material.set_shader_parameter("intensity", 0.86 + float(_tier_rank) * 0.16 + flash_strength * 0.72)
	material.set_shader_parameter("dissolve_progress", smoothstep(FLIGHT_END, 1.0, _progress))
	material.set_shader_parameter("layer_alpha", alpha)


func _wheel_position(index: int, timeline: float) -> Vector2:
	var spawn_position := _spawn_position(index)
	if timeline <= ANTICIPATION_END:
		var materialize := smoothstep(0.0, ANTICIPATION_END, timeline)
		return spawn_position.lerp(_flight_position(index, 0.0), materialize)
	return _flight_position(index, _flight_progress(index, timeline))


func _flight_position(index: int, flight: float) -> Vector2:
	var horizontal_cycles := flight * float(_round_trip_count)
	var horizontal_wave := _triangle_wave(horizontal_cycles)
	if index % 2 == 1:
		horizontal_wave = 1.0 - horizontal_wave
	var x := lerpf(-_range, _range, horizontal_wave)
	var vertical_rate := float(3 + index % (3 + _tier_rank)) * 0.5
	var vertical_cycles := flight * float(_round_trip_count) * vertical_rate + float(index) * 0.173
	var y := lerpf(ARENA_TOP, ARENA_BOTTOM, _triangle_wave(vertical_cycles))
	return Vector2(x, y)


func _wheel_velocity(index: int, timeline: float) -> Vector2:
	var before := _wheel_position(index, maxf(0.0, timeline - 0.0015))
	var after := _wheel_position(index, minf(1.0, timeline + 0.0015))
	return (after - before).normalized()


func _afterimage_sample(index: int, timeline: float, world_distance: float) -> Dictionary:
	# Walk backwards over the authored pinball path instead of estimating speed
	# across the current frame. At a reflection apex, a centered velocity sample
	# cancels to almost zero and would fling the echo far away from its Moon Wheel.
	var cursor := timeline
	var newer_position := _wheel_position(index, cursor)
	var remaining_distance := world_distance
	for _step in MAX_AFTERIMAGE_SEARCH_STEPS:
		if cursor <= 0.0 or remaining_distance <= 0.0:
			break
		var older_timeline := maxf(0.0, cursor - AFTERIMAGE_SAMPLE_STEP)
		var older_position := _wheel_position(index, older_timeline)
		var segment_distance := newer_position.distance_to(older_position)
		if segment_distance >= remaining_distance and segment_distance > 0.0001:
			var interpolation := remaining_distance / segment_distance
			return {
				"timeline": lerpf(cursor, older_timeline, interpolation),
				"position": newer_position.lerp(older_position, interpolation),
			}
		remaining_distance -= segment_distance
		cursor = older_timeline
		newer_position = older_position
	return {
		"timeline": cursor,
		"position": newer_position,
	}


func _wheel_rotation(index: int, velocity: Vector2) -> float:
	var spin_direction := -1.0 if index % 2 == 0 else 1.0
	var spin := _flight_progress(index, _progress) * TAU * (2.0 + float(_tier_rank)) * spin_direction
	return spin + velocity.angle() * 0.16


func _flight_progress(index: int, timeline: float) -> float:
	var normalized := clampf((timeline - ANTICIPATION_END) / (FLIGHT_END - ANTICIPATION_END), 0.0, 1.0)
	var launch_delay := float(index % 4) * 0.012
	return clampf((normalized - launch_delay) / maxf(0.01, 1.0 - launch_delay), 0.0, 1.0)


func _spawn_position(index: int) -> Vector2:
	var angle := TAU * float(index) / float(maxi(1, _sprites.size())) - PI * 0.5
	return Vector2(cos(angle) * (38.0 + _tier_rank * 5.0), -82.0 + sin(angle) * 28.0)


func _triangle_wave(cycles: float) -> float:
	var phase := fposmod(cycles, 1.0)
	return 1.0 - absf(phase * 2.0 - 1.0)


func _appearance_alpha(index: int) -> float:
	var reveal_start := float(index % 5) * 0.012
	var reveal := smoothstep(reveal_start, reveal_start + 0.075, _progress)
	var fade := 1.0 - smoothstep(FLIGHT_END, 1.0, _progress)
	return reveal * fade


func _boundary_flash_strength(index: int, timeline: float) -> float:
	if timeline <= ANTICIPATION_END or timeline >= 0.97:
		return 0.0
	var flight := _flight_progress(index, timeline)
	var horizontal_contact := pow(absf(cos(flight * float(_round_trip_count) * TAU)), 28.0)
	var vertical_rate := float(3 + index % (3 + _tier_rank)) * 0.5
	var vertical_cycles := flight * float(_round_trip_count) * vertical_rate + float(index) * 0.173
	var vertical_contact := pow(absf(cos(vertical_cycles * TAU)), 34.0)
	return clampf(maxf(horizontal_contact, vertical_contact), 0.0, 1.0) * _appearance_alpha(index)


func _horizontal_bounce_segment(index: int, timeline: float) -> int:
	var flight := _flight_progress(index, timeline)
	return floori(flight * float(_round_trip_count) * 2.0 + 0.0001)


func _draw_rebound_contact(position_value: Vector2, velocity: Vector2, strength: float) -> void:
	var alpha := clampf(strength, 0.0, 1.0)
	var tangent := velocity.normalized()
	if tangent.is_zero_approx():
		tangent = Vector2.RIGHT
	var normal := tangent.orthogonal()
	var core_radius := 7.0 + float(_tier_rank) * 1.5
	draw_circle(position_value, core_radius * (1.0 + alpha * 0.35), Color(_palette[0], alpha * 0.92))
	var diamond := PackedVector2Array([
		position_value + tangent * (18.0 + alpha * 10.0),
		position_value + normal * (6.0 + alpha * 4.0),
		position_value - tangent * (18.0 + alpha * 10.0),
		position_value - normal * (6.0 + alpha * 4.0),
	])
	draw_colored_polygon(diamond, Color(_palette[1], alpha * 0.72))
	for shard_index in 4:
		var side := -1.0 if shard_index % 2 == 0 else 1.0
		var depth := 16.0 + float(shard_index / 2) * 11.0
		var center := position_value - tangent * depth + normal * side * (7.0 + float(shard_index) * 2.0)
		var shard := PackedVector2Array([
			center + tangent * 8.0,
			center + normal * side * 3.5,
			center - tangent * 5.0,
		])
		draw_colored_polygon(shard, Color(_palette[2 if shard_index > 1 else 1], alpha * (0.62 - float(shard_index) * 0.08)))


func _configure_contact_motes() -> void:
	_contact_mote_pool.clear()
	var pool_size := _wheel_count
	for emitter_index in pool_size:
		var emitter := contact_motes if emitter_index == 0 else GPUParticles2D.new()
		if emitter_index > 0:
			emitter.name = "ContactMotes%02d" % emitter_index
			emitter.z_index = contact_motes.z_index
			emitter.visibility_rect = contact_motes.visibility_rect
			emitter.use_parent_material = true
			add_child(emitter)
		_configure_contact_mote_emitter(emitter)
		_contact_mote_pool.append(emitter)


func _configure_contact_mote_emitter(emitter: GPUParticles2D) -> void:
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_material.direction = Vector3(1.0, 0.0, 0.0)
	particle_material.spread = 58.0
	particle_material.initial_velocity_min = 72.0
	particle_material.initial_velocity_max = 176.0 + float(_tier_rank) * 22.0
	particle_material.gravity = Vector3(0.0, 92.0, 0.0)
	particle_material.scale_min = 1.8
	particle_material.scale_max = 4.6 + float(_tier_rank)
	particle_material.color = _palette[1]
	emitter.process_material = particle_material
	emitter.amount = 12 + _tier_rank * 6
	emitter.lifetime = 0.32
	emitter.explosiveness = 0.94
	emitter.one_shot = true
	emitter.texture = _make_mote_texture()
	emitter.emitting = false


func _trigger_contact_motes(wheel_index: int) -> void:
	if _contact_mote_pool.is_empty():
		return
	var emitter := _contact_mote_pool[wheel_index % _contact_mote_pool.size()]
	emitter.position = _wheel_position(wheel_index, _progress)
	var velocity := _wheel_velocity(wheel_index, _progress)
	var particle_material := emitter.process_material as ParticleProcessMaterial
	if particle_material != null:
		particle_material.direction = Vector3(-velocity.x, -velocity.y, 0.0)
	emitter.restart()
	emitter.emitting = true
	_particle_trigger_count += 1


func _make_mote_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	gradient.colors = PackedColorArray([
		Color(_palette[0], 1.0), Color(_palette[1], 0.82), Color(_palette[2], 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 16
	texture.height = 16
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


func _make_bloom_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.56, 1.0])
	gradient.colors = PackedColorArray([
		Color(_palette[0], 0.92),
		Color(_palette[0], 0.58),
		Color(_palette[1], 0.24),
		Color(_palette[2], 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 96
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


func _resolve_palette(values: Array) -> Array[Color]:
	var result: Array[Color] = []
	for value in values:
		result.append(value if value is Color else Color(String(value)))
	while result.size() < 3:
		result.append(_palette[result.size()])
	return result.slice(0, 3)
