class_name FirePillarMaterialVFX2D
extends Node2D

const PILLAR_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/fire__fire_pillar.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")

var _pillars: Array[Dictionary] = []
var _tier_rank := 1
var _pillar_count := 5
var _segments_per_pillar := 3
var _radius := 320.0


func configure(source_sprites: Array, tier_rank: int, _palette: Array, parameters: Dictionary, target_positions: Array = []) -> bool:
	clear()
	_tier_rank = clampi(tier_rank, 1, 3)
	_pillar_count = maxi(5, int(parameters.get("pillar_count", [5, 10, 20][_tier_rank - 1])))
	_segments_per_pillar = 2 + _tier_rank
	_radius = maxf(160.0, float(parameters.get("radius", [320.0, 390.0, 480.0][_tier_rank - 1])))
	for source in source_sprites:
		if source is Sprite2D:
			(source as Sprite2D).visible = false
	for pillar_index in _pillar_count:
		_build_pillar(pillar_index, _pillar_base(pillar_index, target_positions))
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_pillars.clear()
	visible = false


func set_progress(value: float) -> void:
	var progress := clampf(value, 0.0, 1.0)
	var decay := smoothstep(0.88, 1.0, progress)
	for pillar_index in _pillars.size():
		var pillar := _pillars[pillar_index]
		var root := pillar.get("root") as Node2D
		var base := pillar.get("base") as Vector2
		var size := pillar.get("size") as Vector2
		var target_scale := pillar.get("target_scale") as Vector2
		var stagger := float(pillar_index) / float(maxi(1, _pillars.size())) * 0.52
		var rise := smoothstep(0.02 + stagger, 0.16 + stagger, progress)
		var pulse := 0.96 + sin(progress * TAU * 8.5 + float(pillar_index)) * 0.04
		var current_scale := target_scale * Vector2(pulse, lerpf(0.08, pulse, rise))
		root.scale = current_scale
		root.position = base - Vector2(0.0, size.y * current_scale.y * 0.5)
		root.modulate = Color(1.0, 1.0, 1.0, rise * (1.0 - decay))
		root.visible = root.modulate.a > 0.015


func get_active_layer_count() -> int:
	return _pillars.size()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "continuous_fire_pillar_sprite",
		"visual_family": "fire",
		"tier_rank": _tier_rank,
		"pillar_count": _pillar_count,
		"segments_per_pillar": _segments_per_pillar,
		"pillar_sprite_count": _pillars.size(),
		"pillar_texture": PILLAR_TEXTURE.resource_path,
		"vertical_body_extension": float(_segments_per_pillar - 1) * 180.0,
		"continuous_nine_patch_body": true,
		"line_layer_count": 0,
		"blessing_mutable": true,
		"layer_count": get_active_layer_count(),
	}


func _build_pillar(index: int, base: Vector2) -> void:
	var root := Node2D.new()
	root.name = "ContinuousFirePillar%02d" % (index + 1)
	root.z_index = 4 + index % 3
	add_child(root)
	var rect := NinePatchRect.new()
	rect.name = "TiledFirePillarBody"
	rect.texture = PILLAR_TEXTURE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.patch_margin_left = 185
	rect.patch_margin_top = 150
	rect.patch_margin_right = 185
	rect.patch_margin_bottom = 225
	rect.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	rect.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	rect.draw_center = true
	var size := Vector2(661.0, 661.0 + float(_segments_per_pillar - 1) * 180.0)
	rect.size = size
	rect.position = -size * 0.5
	rect.material = _edge_material()
	root.add_child(rect)
	var scale_value := 0.14 + float(_tier_rank - 1) * 0.012
	var target_scale := Vector2(scale_value, scale_value)
	root.scale = target_scale
	root.position = base - Vector2(0.0, size.y * target_scale.y * 0.5)
	root.visible = false
	_pillars.append({
		"root": root,
		"base": base,
		"size": size,
		"target_scale": target_scale,
	})


func _pillar_base(index: int, target_positions: Array) -> Vector2:
	if not target_positions.is_empty():
		var candidate: Variant = target_positions[index % target_positions.size()]
		if candidate is Vector2:
			return candidate as Vector2
	var ratio := (float(index) + 0.5) / float(_pillar_count)
	return Vector2(lerpf(-_radius, _radius, ratio) + sin(float(index) * 4.17) * 24.0, 0.0)


func _edge_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = EDGE_SHADER
	return result
