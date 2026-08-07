class_name LayeredVFXPrimitive2D
extends Node2D

signal started(effect_id: StringName)
signal finished(effect_id: StringName)

const CIRCLE_SEGMENTS := 32
const MAX_PARTICLES := 160
const MIN_LIFETIME := 0.05
const VFX_CATALOG := preload("res://scripts/vfx/vfx_primitive_catalog.gd")
const CONTACT_RHYTHM_BEATS := [
	"contact_flash", "shape_expansion", "secondary_debris", "residual_fade",
]
const ONE_SHOT_LAYER_PHASE_OFFSETS := [0.0, 0.02, 0.08, 0.16, 0.10]

@export var effect_id: StringName = &"fire_loop"
@export var primary_color := Color.WHITE
@export var secondary_color := Color(1.0, 0.42, 0.08, 1.0)
@export_range(0.1, 3.0, 0.05) var intensity := 1.0
@export_range(0.05, 5.0, 0.01) var effect_lifetime := 0.8
@export_range(0.1, 4.0, 0.05) var effect_scale := 1.0
@export_range(0.0, 8.0, 0.05) var speed := 1.0
@export var direction := Vector2.RIGHT
@export_range(1, MAX_PARTICLES, 1) var particle_amount := 32
@export_range(0.0, 1.0, 0.01) var noise_amount := 0.42
@export_range(0.0, 4.0, 0.05) var glow_strength := 1.0
@export var one_shot := false
@export var auto_play := true
@export var auto_free := false

var _profile: Dictionary = {}
var _layer_names: Array[StringName] = []
var _line_layers: Array[Line2D] = []
var _particle_layers: Array[GPUParticles2D] = []
var _motion: StringName = &"loop"
var _bounds := Vector2(192.0, 192.0)
var _time := 0.0
var _active := false
var _rng := RandomNumberGenerator.new()


func configure_runtime(parameters: Dictionary) -> void:
	primary_color = parameters.get("primary_color", primary_color) as Color
	secondary_color = parameters.get("secondary_color", secondary_color) as Color
	intensity = clampf(float(parameters.get("intensity", intensity)), 0.1, 3.0)
	effect_scale = clampf(float(parameters.get("effect_scale", effect_scale)), 0.1, 4.0)
	effect_lifetime = clampf(float(parameters.get("effect_lifetime", effect_lifetime)), MIN_LIFETIME, 5.0)
	noise_amount = clampf(float(parameters.get("noise_amount", noise_amount)), 0.0, 1.0)
	glow_strength = clampf(float(parameters.get("glow_strength", glow_strength)), 0.0, 4.0)
	particle_amount = clampi(int(parameters.get("particle_amount", particle_amount)), 1, MAX_PARTICLES)
	if parameters.has("one_shot"):
		one_shot = bool(parameters.get("one_shot"))
	if parameters.has("auto_free"):
		auto_free = bool(parameters.get("auto_free"))
	if is_node_ready():
		_configure_layers()


func _ready() -> void:
	_configure_profile()
	_cache_layers()
	_configure_layers()
	set_process(false)
	if auto_play:
		play()


func play(origin: Variant = null, target: Variant = null) -> void:
	if origin is Vector2:
		global_position = origin
	if target is Vector2:
		var target_direction: Vector2 = (target as Vector2) - global_position
		if not target_direction.is_zero_approx():
			direction = target_direction.normalized()
	_time = 0.0
	_active = true
	visible = true
	set_process(true)
	for index in _line_layers.size():
		_sync_shader_material(_line_layers[index], index)
	for particle_layer in _particle_layers:
		_configure_particle_layer(particle_layer)
		particle_layer.restart()
		particle_layer.emitting = true
	_update_visuals(0.0)
	started.emit(effect_id)


func stop() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	for particle_layer in _particle_layers:
		particle_layer.emitting = false
	finished.emit(effect_id)
	if auto_free:
		queue_free()


func is_active() -> bool:
	return _active


func get_layer_names() -> Array[StringName]:
	return _layer_names.duplicate()


func get_layer_roles() -> Dictionary:
	var roles := {}
	for index in _layer_names.size():
		roles[_layer_names[index]] = [&"glow", &"body", &"secondary", &"detail", &"particles"][mini(index, 4)]
	return roles


func get_particle_budget() -> int:
	return particle_amount * _particle_layers.size()


func get_visual_bounds() -> Rect2:
	var scaled_bounds := _bounds * effect_scale
	return Rect2(-scaled_bounds * 0.5, scaled_bounds)


func get_motion_family() -> StringName:
	return _motion


func get_quality_state() -> Dictionary:
	return {
		"rhythm_beats": CONTACT_RHYTHM_BEATS.duplicate(),
		"layer_phase_offsets": (
			ONE_SHOT_LAYER_PHASE_OFFSETS.duplicate()
			if one_shot
			else [0.0, 0.07, 0.14, 0.21, 0.11]
		),
		"visual_layer_count": _layer_names.size(),
		"directional_shape": _motion in [&"slash", &"trail", &"stream", &"bolt"],
		"shape_family": _motion,
		"material_layer_count": _shader_material_count(),
		"particle_layer_count": _particle_layers.size(),
	}


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta * speed
	var progress := fposmod(_time / maxf(effect_lifetime, MIN_LIFETIME), 1.0)
	if one_shot:
		progress = clampf(_time / maxf(effect_lifetime, MIN_LIFETIME), 0.0, 1.0)
	_update_visuals(progress)
	if one_shot and _time >= effect_lifetime:
		stop()


func _configure_profile() -> void:
	_profile = VFX_CATALOG.get_profile(effect_id)
	if _profile.is_empty():
		push_error("Unknown VFX primitive profile: %s" % effect_id)
		return
	primary_color = _profile.get("primary", primary_color) as Color
	secondary_color = _profile.get("secondary", secondary_color) as Color
	effect_lifetime = float(_profile.get("lifetime", effect_lifetime))
	particle_amount = int(_profile.get("amount", particle_amount))
	one_shot = bool(_profile.get("one_shot", one_shot))
	_motion = StringName(_profile.get("motion", &"loop"))
	_bounds = _profile.get("bounds", _bounds) as Vector2
	var raw_layers := _profile.get("layers", []) as Array
	for layer_name in raw_layers:
		_layer_names.append(StringName(layer_name))
	_rng.seed = effect_id.hash()


func _cache_layers() -> void:
	for layer_name in _layer_names:
		var layer := get_node_or_null(NodePath(String(layer_name)))
		if layer is Line2D:
			_line_layers.append(layer as Line2D)
		elif layer is GPUParticles2D:
			_particle_layers.append(layer as GPUParticles2D)


func _configure_layers() -> void:
	var accent: Color = _profile.get("accent", secondary_color.darkened(0.35)) as Color
	var colors := [primary_color, secondary_color, accent, primary_color.lerp(secondary_color, 0.5)]
	for index in _line_layers.size():
		var line := _line_layers[index]
		line.width = maxf(1.0, (12.0 - float(index) * 2.25) * effect_scale)
		line.default_color = colors[mini(index, colors.size() - 1)]
		line.antialiased = false
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		if line.material is ShaderMaterial:
			line.material = (line.material as ShaderMaterial).duplicate(true)
		if index == 0:
			line.width *= 2.1 * maxf(glow_strength, 0.1)
			line.default_color.a = 0.16 + 0.14 * clampf(glow_strength, 0.0, 2.0)
		_sync_shader_material(line, index)
	for particle_layer in _particle_layers:
		_configure_particle_layer(particle_layer)


func _sync_shader_material(line: Line2D, layer_index: int) -> void:
	var shader_material := line.material as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return
	var accent: Color = _profile.get("accent", secondary_color.darkened(0.35)) as Color
	var available := {}
	for uniform_data in shader_material.shader.get_shader_uniform_list():
		available[StringName(uniform_data.get("name", ""))] = true
	var values := {
		&"inner_color": primary_color,
		&"outer_color": secondary_color,
		&"edge_color": accent,
		&"core_color": primary_color,
		&"glow_color": Color(secondary_color, clampf(0.22 + glow_strength * 0.18, 0.0, 1.0)),
		&"deep_color": accent,
		&"body_color": secondary_color,
		&"highlight_color": primary_color,
		&"acid_color": primary_color,
		&"rot_color": accent,
		&"speed": speed,
		&"intensity": intensity,
		&"turbulence": noise_amount,
		&"variation": noise_amount * 0.28,
		&"distortion": noise_amount * 0.055,
		&"distortion_strength": noise_amount * 0.045,
		&"corrosion": clampf(0.18 + noise_amount * 0.54 + float(layer_index) * 0.03, 0.0, 0.92),
	}
	for uniform_name in values:
		if available.has(uniform_name):
			shader_material.set_shader_parameter(uniform_name, values[uniform_name])


func _configure_particle_layer(particles: GPUParticles2D) -> void:
	particles.amount = clampi(particle_amount, 1, MAX_PARTICLES)
	particles.lifetime = maxf(effect_lifetime * (0.72 if one_shot else 1.15), MIN_LIFETIME)
	particles.one_shot = one_shot
	particles.explosiveness = 0.88 if one_shot else 0.12
	particles.randomness = 0.46
	particles.visibility_rect = get_visual_bounds().grow(64.0)
	particles.local_coords = true
	particles.draw_order = GPUParticles2D.DRAW_ORDER_LIFETIME
	particles.texture = _make_particle_texture()
	var process := ParticleProcessMaterial.new()
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var velocity := _particle_velocity()
	process.direction = Vector3(safe_direction.x, safe_direction.y, 0.0)
	process.spread = _particle_spread()
	process.gravity = Vector3(0.0, _particle_gravity(), 0.0)
	process.initial_velocity_min = velocity * 0.45
	process.initial_velocity_max = velocity
	process.angular_velocity_min = -120.0
	process.angular_velocity_max = 120.0
	process.scale_min = 0.35 * effect_scale
	process.scale_max = 1.0 * effect_scale
	process.damping_min = 4.0
	process.damping_max = 18.0
	process.color_ramp = _make_color_ramp()
	particles.process_material = process


func _update_visuals(progress: float) -> void:
	var tangent := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var normal := Vector2(-tangent.y, tangent.x)
	for index in _line_layers.size():
		var line := _line_layers[index]
		var layer_progress := _line_phase_progress(line, index, progress)
		var points := _build_motion_points(layer_progress)
		var offset_strength := float(index) * 3.0 * (0.5 + noise_amount)
		var offset_points := PackedVector2Array()
		for point_index in points.size():
			var envelope := sin(PI * float(point_index) / maxf(1.0, float(points.size() - 1)))
			var offset := normal * offset_strength * envelope * sin(_time * (2.3 + index * 0.35) + point_index * 1.73 + index)
			offset_points.append(points[point_index] + offset)
		line.points = offset_points
		var alpha := _layer_alpha(line, index, layer_progress)
		line.modulate = Color(1.0, 1.0, 1.0, alpha)
		line.scale = Vector2.ONE * effect_scale * _layer_shape_scale(line, layer_progress)


func _build_motion_points(progress: float) -> PackedVector2Array:
	match _motion:
		&"loop", &"cloud", &"mist", &"bubble":
			return _build_loop_points(progress)
		&"burst", &"impact", &"splash", &"shatter":
			return _build_burst_points(progress)
		&"arc", &"wave":
			return _build_arc_points(progress)
		&"bolt":
			return _build_bolt_points(progress)
		&"trail", &"stream", &"shard", &"slash":
			return _build_stream_points(progress)
	return _build_stream_points(progress)


func _build_loop_points(progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius_x := _bounds.x * 0.25
	var radius_y := _bounds.y * 0.25
	for segment in CIRCLE_SEGMENTS + 1:
		var angle := TAU * float(segment) / float(CIRCLE_SEGMENTS)
		var noise := sin(angle * 5.0 + _time * 2.0) * radius_x * 0.08 * noise_amount
		points.append(Vector2(cos(angle) * (radius_x + noise), sin(angle) * (radius_y + noise * 0.45)))
	return points


func _build_burst_points(progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var eased := ease(progress, 0.36)
	var radius := lerpf(8.0, minf(_bounds.x, _bounds.y) * 0.42, eased)
	for segment in CIRCLE_SEGMENTS + 1:
		var angle := TAU * float(segment) / float(CIRCLE_SEGMENTS)
		var jag := 1.0 + sin(float(segment) * 3.71 + _time * 6.0) * 0.13 * noise_amount
		points.append(Vector2.from_angle(angle) * radius * jag)
	return points


func _build_arc_points(progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var reveal := 1.0 if not one_shot else minf(1.0, progress * 2.4)
	for segment in 25:
		var ratio := float(segment) / 24.0
		if ratio > reveal:
			break
		var angle := lerpf(-PI * 0.82, PI * 0.18, ratio)
		var radius := _bounds.y * 0.44
		points.append(Vector2(cos(angle) * _bounds.x * 0.42, sin(angle) * radius + _bounds.y * 0.12))
	return points


func _build_bolt_points(progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var normal := Vector2(-safe_direction.y, safe_direction.x)
	var reveal := minf(1.0, progress * 5.0)
	for segment in 25:
		var ratio := float(segment) / 24.0
		if ratio > reveal:
			break
		var jitter := sin(float(segment) * 12.9898 + floor(_time / 0.045) * 7.23) * _bounds.y * 0.13 * noise_amount
		points.append(safe_direction * _bounds.x * (ratio - 0.5) + normal * jitter * sin(PI * ratio))
	return points


func _build_stream_points(progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var normal := Vector2(-safe_direction.y, safe_direction.x)
	var reveal := 1.0 if not one_shot else minf(1.0, progress * 3.2)
	for segment in 29:
		var ratio := float(segment) / 28.0
		if ratio > reveal:
			break
		var wave := sin(ratio * TAU * 1.45 - _time * 4.0) * _bounds.y * 0.13 * noise_amount
		points.append(safe_direction * _bounds.x * (ratio - 0.5) + normal * wave * sin(PI * ratio))
	return points


func _line_phase_progress(line: Line2D, index: int, progress: float) -> float:
	if not one_shot:
		return progress
	var offset := float(ONE_SHOT_LAYER_PHASE_OFFSETS[mini(index, ONE_SHOT_LAYER_PHASE_OFFSETS.size() - 1)])
	var name_key := String(line.name).to_lower()
	if "flash" in name_key or "core" in name_key or "mainbolt" in name_key:
		offset = 0.0
	elif "smoke" in name_key or "mist" in name_key or "corrosion" in name_key or "trail" in name_key:
		offset = 0.16
	return clampf((progress - offset) / maxf(0.01, 1.0 - offset), 0.0, 1.0)


func _layer_shape_scale(line: Line2D, progress: float) -> float:
	if not one_shot:
		return 1.0
	var name_key := String(line.name).to_lower()
	if "flash" in name_key or "core" in name_key or "mainbolt" in name_key:
		return lerpf(0.44, 1.08, minf(1.0, progress * 4.8))
	if "smoke" in name_key or "mist" in name_key or "corrosion" in name_key or "trail" in name_key:
		return lerpf(0.82, 1.28, ease(progress, 0.45))
	return lerpf(0.68, 1.18, ease(progress, 0.52))


func _layer_alpha(line: Line2D, index: int, progress: float) -> float:
	var base_alpha: float = float([0.58, 1.0, 0.82, 0.68][mini(index, 3)]) * intensity
	if not one_shot:
		return clampf(base_alpha * (0.88 + sin(_time * 3.0 + index) * 0.12), 0.0, 1.0)
	var name_key := String(line.name).to_lower()
	var envelope := smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.70, 1.0, progress))
	if "flash" in name_key or "core" in name_key or "mainbolt" in name_key:
		envelope = smoothstep(0.0, 0.025, progress) * (1.0 - smoothstep(0.20, 0.48, progress))
	elif "smoke" in name_key or "mist" in name_key or "corrosion" in name_key or "trail" in name_key:
		envelope = smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.74, 1.0, progress))
	return clampf(base_alpha * envelope, 0.0, 1.0)


func _shader_material_count() -> int:
	var count := 0
	for line in _line_layers:
		if line.material is ShaderMaterial:
			count += 1
	return count


func _make_particle_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.32, 1.0])
	gradient.colors = PackedColorArray([primary_color, secondary_color, Color(secondary_color, 0.0)])
	var texture_2d := GradientTexture2D.new()
	texture_2d.width = 4
	texture_2d.height = 12
	texture_2d.fill_from = Vector2(0.5, 0.0)
	texture_2d.fill_to = Vector2(0.5, 1.0)
	texture_2d.gradient = gradient
	return texture_2d


func _make_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([primary_color, secondary_color, Color(secondary_color, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _particle_velocity() -> float:
	match _motion:
		&"burst", &"impact", &"splash", &"shatter":
			return 180.0 * intensity
		&"stream", &"trail", &"bolt", &"shard", &"slash":
			return 120.0 * intensity
	return 48.0 * intensity


func _particle_spread() -> float:
	return 180.0 if _motion in [&"burst", &"impact", &"shatter"] else 52.0


func _particle_gravity() -> float:
	if effect_id.begins_with("water_") or effect_id.begins_with("poison_"):
		return 145.0
	if effect_id.begins_with("fire_"):
		return -64.0
	return 18.0
