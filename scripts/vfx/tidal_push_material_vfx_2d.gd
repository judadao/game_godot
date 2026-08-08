class_name TidalPushMaterialVFX2D
extends Node2D

const WAVE_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/water_flow__tidal_curl.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")

var _waves: Array[Dictionary] = []
var _tier_rank := 1
var _radius := 250.0
var _start_scale := 0.13
var _end_scale := 0.18


func configure(source_sprites: Array, tier_rank: int, _palette: Array, parameters: Dictionary, _target_positions: Array = []) -> bool:
	clear()
	_tier_rank = clampi(tier_rank, 1, 3)
	_radius = maxf(120.0, float(parameters.get("radius", [250.0, 300.0, 340.0][_tier_rank - 1])))
	_start_scale = 0.12 + float(_tier_rank) * 0.012
	_end_scale = _start_scale + [0.02, 0.055, 0.12][_tier_rank - 1]
	var cleanup_material := _edge_material()
	for source in source_sprites:
		if source is Sprite2D:
			(source as Sprite2D).visible = false
	var waves_per_direction: int = [2, 3, 4][_tier_rank - 1]
	for direction in [-1, 1]:
		for wave_index in waves_per_direction:
			var sprite := Sprite2D.new()
			sprite.name = "TidalCurl%s%02d" % ["Left" if direction < 0 else "Right", wave_index + 1]
			sprite.texture = WAVE_TEXTURE
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.material = cleanup_material
			sprite.flip_h = direction < 0
			sprite.z_index = 3 + wave_index
			sprite.visible = false
			add_child(sprite)
			_waves.append({"sprite": sprite, "direction": direction, "delay": float(wave_index) * 0.12})
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_waves.clear()
	visible = false


func set_progress(value: float) -> void:
	var progress := clampf(value, 0.0, 1.0)
	for wave_data in _waves:
		var sprite := wave_data.get("sprite") as Sprite2D
		var local_progress := fposmod(progress * 1.7 - float(wave_data.get("delay", 0.0)), 1.0)
		var direction := int(wave_data.get("direction", 1))
		var travel := smoothstep(0.0, 1.0, local_progress)
		var scale_value := lerpf(_start_scale, _end_scale, travel)
		sprite.position = Vector2(float(direction) * lerpf(18.0, _radius, travel), -42.0 - sin(local_progress * PI) * 12.0)
		sprite.scale = Vector2(scale_value, scale_value)
		sprite.modulate = Color(1.0, 1.0, 1.0, sin(local_progress * PI))
		sprite.visible = sprite.modulate.a > 0.02


func get_active_layer_count() -> int:
	return _waves.size()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "outward_tidal_curl_sprite",
		"visual_family": "water_flow",
		"tier_rank": _tier_rank,
		"wave_texture": WAVE_TEXTURE.resource_path,
		"wave_sprite_count": _waves.size(),
		"directions": [-1, 1],
		"start_wave_scale": _start_scale,
		"end_wave_scale": _end_scale,
		"outward_radius": _radius,
		"line_layer_count": 0,
		"blessing_mutable": true,
		"layer_count": get_active_layer_count(),
	}


func _edge_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = EDGE_SHADER
	return result
