class_name BlackHoleMaterialVFX2D
extends Node2D

const VOID_RING_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/black_hole__void_ring.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")
const LAYER_IDS := ["singularity_core", "accretion_rings", "inward_particles", "gravity_lens", "collapse_burst"]

var _main_ring: Sprite2D
var _streams: Array[GPUParticles2D] = []
var _tier := 1
var _radius := 180.0
var _duration := 2.4
var _progress := 0.0
var _collapse_burst_progress := 0.0


func configure(source_sprites: Array, tier_rank: int, palette: Array, parameters: Dictionary) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_radius = maxf(48.0, float(parameters.get("radius", [180.0, 240.0, 320.0][_tier - 1])))
	_duration = maxf(0.2, float(parameters.get("duration_seconds", [2.4, 3.0, 3.6][_tier - 1])))
	for source in source_sprites:
		if source is Sprite2D:
			(source as Sprite2D).visible = false
	_main_ring = Sprite2D.new()
	_main_ring.name = "VoidRingMainBody"
	_main_ring.texture = VOID_RING_TEXTURE
	_main_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ring_material := ShaderMaterial.new()
	ring_material.shader = EDGE_SHADER
	_main_ring.material = ring_material
	_main_ring.z_index = 4
	add_child(_main_ring)
	var resolved_palette := [Color("fff7ff"), Color("9a6cff"), Color("160b2d")]
	if palette.size() >= 3:
		resolved_palette = [palette[0] as Color, palette[1] as Color, palette[2] as Color]
	_build_inward_streams(maxi(3, int(parameters.get("particle_stream_count", [3, 5, 8][_tier - 1]))), resolved_palette)
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_main_ring = null
	_streams.clear()
	_progress = 0.0
	_collapse_burst_progress = 0.0
	visible = false


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_collapse_burst_progress = smoothstep(0.84, 1.0, _progress)
	var reveal := smoothstep(0.0, 0.14, _progress)
	var collapse := smoothstep(0.72, 0.91, _progress)
	if _main_ring != null:
		var base_scale := _radius * 1.16 / float(VOID_RING_TEXTURE.get_width())
		var pulse := 0.94 + sin(_progress * TAU * 3.4) * 0.08
		var scale_value := base_scale * reveal * pulse * lerpf(1.0, 0.58, collapse)
		_main_ring.scale = Vector2.ONE * scale_value
		_main_ring.rotation = _progress * TAU * (0.72 + float(_tier) * 0.12)
		_main_ring.modulate.a = reveal * (1.0 - _collapse_burst_progress * 0.58)
	for stream in _streams:
		stream.emitting = _progress > 0.05 and _progress < 0.94
		stream.modulate.a = reveal * 0.34


func get_debug_state() -> Dictionary:
	return {
		"renderer": "layered_black_hole",
		"layer_ids": LAYER_IDS.duplicate(),
		"tier_rank": _tier,
		"radius": _radius,
		"duration_seconds": _duration,
		"main_texture": VOID_RING_TEXTURE.resource_path,
		"main_sprite_count": 1 if _main_ring != null else 0,
		"visible_line_count": 0,
		"rotates_and_pulses": true,
		"accretion_ring_count": 1,
		"inward_particle_stream_count": _streams.size(),
		"real_visual_layer_count": get_active_layer_count(),
		"collapse_burst_progress": _collapse_burst_progress,
		"uses_distortion_shader": false,
	}


func get_active_layer_count() -> int:
	return (1 if _main_ring != null else 0) + _streams.size()


func _build_inward_streams(count: int, palette: Array) -> void:
	for index in count:
		var stream := GPUParticles2D.new()
		stream.name = "InwardMatter%02d" % index
		stream.amount = 8 + _tier * 3
		stream.lifetime = 0.85 + float(index % 3) * 0.12
		stream.randomness = 0.55
		stream.visibility_rect = Rect2(Vector2.ONE * -_radius, Vector2.ONE * _radius * 2.0)
		stream.position = Vector2.from_angle(TAU * float(index) / float(count)) * _radius * 0.62
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
		gradient.colors = PackedColorArray([Color(palette[0] as Color, 0.34), Color(palette[1] as Color, 0.18), Color(palette[1] as Color, 0.0)])
		var texture := GradientTexture2D.new()
		texture.width = 24
		texture.height = 24
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.gradient = gradient
		stream.texture = texture
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(-stream.position.normalized().x, -stream.position.normalized().y, 0.0)
		process.spread = 22.0
		process.initial_velocity_min = _radius * 0.42
		process.initial_velocity_max = _radius * 0.72
		process.gravity = Vector3.ZERO
		process.scale_min = 0.10
		process.scale_max = 0.28
		stream.process_material = process
		add_child(stream)
		_streams.append(stream)
