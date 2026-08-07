class_name BlackHoleMaterialVFX2D
extends Node2D

const CORE_SHADER := preload("res://shaders/vfx/black_hole_core.gdshader")
const LAYER_IDS := ["singularity_core", "accretion_rings", "inward_particles", "gravity_lens", "collapse_burst"]

var _core_sprites: Array[Sprite2D] = []
var _rings: Array[Line2D] = []
var _streams: Array[GPUParticles2D] = []
var _palette: Array[Color] = [Color("fff7ff"), Color("9a6cff"), Color("160b2d")]
var _tier := 1
var _radius := 180.0
var _duration := 2.4
var _progress := 0.0
var _collapse_burst_progress := 0.0


func configure(core_sprites: Array, tier_rank: int, palette: Array, parameters: Dictionary) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_radius = maxf(48.0, float(parameters.get("radius", [180.0, 240.0, 320.0][_tier - 1])))
	_duration = maxf(0.2, float(parameters.get("duration_seconds", [2.4, 3.0, 3.6][_tier - 1])))
	if palette.size() >= 3:
		_palette.assign([palette[0] as Color, palette[1] as Color, palette[2] as Color])
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			var core := core_variant as Sprite2D
			core.visible = false
			_core_sprites.append(core)
	_build_accretion_rings(maxi(2, int(parameters.get("accretion_ring_count", [2, 3, 5][_tier - 1]))))
	_build_inward_streams(maxi(3, int(parameters.get("particle_stream_count", [3, 5, 8][_tier - 1]))))
	var shader_material := ShaderMaterial.new()
	shader_material.shader = CORE_SHADER
	shader_material.set_shader_parameter("inner_color", _palette[2])
	shader_material.set_shader_parameter("rim_color", _palette[1])
	shader_material.set_shader_parameter("flow_speed", 1.1 + _tier * 0.25)
	shader_material.set_shader_parameter("distortion_strength", 0.16 + _tier * 0.05)
	material = shader_material
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_rings.clear()
	_streams.clear()
	_progress = 0.0
	_collapse_burst_progress = 0.0
	visible = false
	material = null


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_collapse_burst_progress = smoothstep(0.84, 1.0, _progress)
	var reveal := smoothstep(0.0, 0.12, _progress)
	var compression := smoothstep(0.72, 0.90, _progress)
	for index in _rings.size():
		var ring := _rings[index]
		ring.rotation = _progress * TAU * (1.4 + index * 0.28) * (-1.0 if index % 2 else 1.0)
		ring.scale = Vector2.ONE * lerpf(0.72, 1.0 - compression * 0.42, reveal)
		ring.modulate.a = reveal * (1.0 - _collapse_burst_progress * 0.75)
	for stream in _streams:
		stream.emitting = _progress > 0.05 and _progress < 0.94
		stream.modulate.a = reveal
	queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "layered_black_hole",
		"layer_ids": LAYER_IDS.duplicate(),
		"tier_rank": _tier,
		"radius": _radius,
		"duration_seconds": _duration,
		"accretion_ring_count": _rings.size(),
		"inward_particle_stream_count": _streams.size(),
		"real_visual_layer_count": 3 + _rings.size() + _streams.size(),
		"collapse_burst_progress": _collapse_burst_progress,
		"uses_distortion_shader": material is ShaderMaterial,
		"distortion_shader": CORE_SHADER.resource_path,
	}


func get_active_layer_count() -> int:
	return 3 + _rings.size() + _streams.size()


func _draw() -> void:
	var reveal := smoothstep(0.0, 0.12, _progress)
	var core_radius := _radius * (0.14 + _tier * 0.012) * reveal
	draw_circle(Vector2.ZERO, core_radius * 1.9, Color(_palette[1], 0.11 * reveal))
	draw_circle(Vector2.ZERO, core_radius, Color(_palette[2], reveal))
	draw_arc(Vector2.ZERO, _radius * 0.56, 0.0, TAU, 96, Color(_palette[0], 0.24 * reveal), 3.0 + _tier)
	if _collapse_burst_progress > 0.0:
		var burst_radius := _radius * lerpf(0.12, 1.04, _collapse_burst_progress)
		draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 96, Color(_palette[0], 1.0 - _collapse_burst_progress), 12.0 * (1.0 - _collapse_burst_progress) + 2.0)


func _build_accretion_rings(count: int) -> void:
	for index in count:
		var ring := Line2D.new()
		ring.name = "AccretionRing%02d" % index
		ring.closed = true
		ring.width = 3.0 + float(index % 2) * 2.0
		ring.default_color = Color(_palette[index % 2], 0.78)
		ring.z_index = index - count / 2
		var points := PackedVector2Array()
		var ring_radius := _radius * (0.24 + float(index) * 0.07)
		for point_index in 64:
			var angle := TAU * float(point_index) / 64.0
			var wobble := 1.0 + sin(angle * (3.0 + index) + index) * 0.05
			points.append(Vector2(cos(angle) * ring_radius * wobble, sin(angle) * ring_radius * 0.42 * wobble))
		ring.points = points
		add_child(ring)
		_rings.append(ring)


func _build_inward_streams(count: int) -> void:
	for index in count:
		var stream := GPUParticles2D.new()
		stream.name = "InwardMatter%02d" % index
		stream.amount = 8 + _tier * 3
		stream.lifetime = 0.85 + float(index % 3) * 0.12
		stream.randomness = 0.55
		stream.visibility_rect = Rect2(Vector2.ONE * -_radius, Vector2.ONE * _radius * 2.0)
		stream.position = Vector2.from_angle(TAU * float(index) / float(count)) * _radius * 0.62
		stream.texture = _particle_texture()
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(-stream.position.normalized().x, -stream.position.normalized().y, 0.0)
		process.spread = 22.0
		process.initial_velocity_min = _radius * 0.42
		process.initial_velocity_max = _radius * 0.72
		process.gravity = Vector3.ZERO
		process.scale_min = 0.45
		process.scale_max = 1.2
		stream.process_material = process
		add_child(stream)
		_streams.append(stream)


func _particle_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([_palette[0], Color(_palette[1], 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 5
	texture.height = 18
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.gradient = gradient
	return texture
