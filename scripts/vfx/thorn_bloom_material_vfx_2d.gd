class_name ThornBloomMaterialVFX2D
extends Node2D

const VINE_SEGMENT_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_bloom.png")
const TERMINAL_FLOWER_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_seed.png")
const SCATTER_PROJECTILE_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_run.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")
const LAYER_IDS := ["ground_cracks", "thorn_tendrils", "bloom_sequence", "spike_barrage", "petal_decay"]

var _core_sprites: Array[Sprite2D] = []
var _vines: Array[Dictionary] = []
var _palette: Array[Color] = [Color("f5ffc2"), Color("7fd05e"), Color("6b285f")]
var _tier := 1
var _thorn_count := 3
var _segments_per_vine := 5
var _projectiles_per_vine := 8
var _radius := 180.0
var _duration := 2.4
var _segment_stride := 15.0
var _segment_scale := Vector2(0.061, 0.086)
var _root_offset_y := 0.0
var _flower_offset_from_last_segment := 11.0
var _progress := 0.0
var _active_vine_segment_count := 0
var _active_terminal_flower_count := 0
var _active_scatter_projectile_count := 0


func configure(core_sprites: Array, tier_rank: int, palette: Array, parameters: Dictionary) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_thorn_count = maxi(3, int(parameters.get("thorn_count", [3, 6, 10][_tier - 1])))
	_segments_per_vine = maxi(5, int(parameters.get("segments_per_vine", [5, 7, 9][_tier - 1])))
	_projectiles_per_vine = maxi(1, int(parameters.get("projectiles_per_vine", [8, 14, 20][_tier - 1])))
	_radius = maxf(48.0, float(parameters.get("radius", [180.0, 240.0, 310.0][_tier - 1])))
	_duration = maxf(0.2, float(parameters.get("duration_seconds", [2.4, 3.0, 3.8][_tier - 1])))
	_segment_stride = 14.0 + float(_tier)
	_segment_scale = Vector2(0.058 + float(_tier) * 0.003, 0.082 + float(_tier) * 0.004)
	_flower_offset_from_last_segment = _segment_stride * 0.72
	if palette.size() >= 3:
		_palette.assign([palette[0] as Color, palette[1] as Color, palette[2] as Color])
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			var core := core_variant as Sprite2D
			core.visible = false
			_core_sprites.append(core)
	for index in _thorn_count:
		_build_vine(index)
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_vines.clear()
	_progress = 0.0
	_reset_active_counts()
	visible = false


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_reset_active_counts()
	var decay := smoothstep(0.86, 1.0, _progress)
	for vine_index in _vines.size():
		var vine := _vines[vine_index]
		var vine_stagger := float(vine_index) / maxf(1.0, float(_vines.size() - 1)) * 0.075
		var segments := vine.get("segments", []) as Array
		for segment_index in segments.size():
			var segment := segments[segment_index] as Sprite2D
			var growth_start := 0.02 + vine_stagger + float(segment_index) * 0.036
			var growth := smoothstep(growth_start, growth_start + 0.105, _progress)
			segment.visible = growth > 0.01
			segment.modulate = Color(1.0, 1.0, 1.0, growth * (1.0 - decay))
			segment.scale = (segment.get_meta("target_scale", Vector2.ONE) as Vector2) * Vector2(
				lerpf(0.68, 1.0, growth),
				lerpf(0.12, 1.0, growth)
			)
			if segment.visible:
				_active_vine_segment_count += 1
		var flower := vine.get("flower") as Sprite2D
		var bloom_start := 0.285 + vine_stagger
		var bloom := smoothstep(bloom_start, bloom_start + 0.115, _progress)
		flower.visible = bloom > 0.01
		flower.modulate = Color(1.0, 1.0, 1.0, bloom * (1.0 - decay))
		var bloom_pop := 1.0 + sin(bloom * PI) * 0.14
		flower.scale = (vine.get("flower_scale", Vector2.ONE) as Vector2) * lerpf(0.14, bloom_pop, bloom)
		flower.rotation = float(vine.get("sway", 0.0)) * 0.32 + sin(_progress * TAU * 2.0 + vine_index) * 0.025
		if flower.visible:
			_active_terminal_flower_count += 1
		_update_vine_projectiles(vine, vine_index, decay)
	queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "thorn_emerge_bloom_barrage",
		"layer_ids": LAYER_IDS.duplicate(),
		"tier_rank": _tier,
		"thorn_count": _thorn_count,
		"segments_per_vine": _segments_per_vine,
		"vine_segment_count": _thorn_count * _segments_per_vine,
		"terminal_flower_count": _thorn_count,
		"projectiles_per_vine": _projectiles_per_vine,
		"scatter_projectile_count": _thorn_count * _projectiles_per_vine,
		"active_vine_segment_count": _active_vine_segment_count,
		"active_terminal_flower_count": _active_terminal_flower_count,
		"active_scatter_projectile_count": _active_scatter_projectile_count,
		"radius": _radius,
		"duration_seconds": _duration,
		"segment_stride": _segment_stride,
		"nominal_segment_height": float(VINE_SEGMENT_TEXTURE.get_height()) * _segment_scale.y,
		"root_offset_y": _root_offset_y,
		"flower_offset_from_last_segment": _flower_offset_from_last_segment,
		"real_visual_layer_count": get_active_layer_count(),
		"vine_segment_texture": VINE_SEGMENT_TEXTURE.resource_path,
		"terminal_flower_texture": TERMINAL_FLOWER_TEXTURE.resource_path,
		"terminal_flower_scale": 0.120 + float(_tier) * 0.008,
		"scatter_projectile_texture": SCATTER_PROJECTILE_TEXTURE.resource_path,
	}


func get_active_layer_count() -> int:
	return 3 + _thorn_count * (_segments_per_vine + 1 + _projectiles_per_vine)


func _draw() -> void:
	var reveal := smoothstep(0.0, 0.13, _progress)
	var decay := smoothstep(0.86, 1.0, _progress)
	for vine in _vines:
		var base := vine.get("base", Vector2.ZERO) as Vector2
		var side := -1.0 if int(vine.get("index", 0)) % 2 == 0 else 1.0
		draw_polyline(
			PackedVector2Array([
				base + Vector2(-30.0 * side, 2.0),
				base + Vector2(-8.0 * side, -2.0),
				base + Vector2(22.0 * side, 3.0),
			]),
			Color(_palette[2], 0.58 * reveal * (1.0 - decay)),
			3.0
		)
	if decay > 0.0:
		for index in _thorn_count * 2:
			var angle := float(index) * 2.399
			var position := Vector2.from_angle(angle) * _radius * 0.42 + Vector2(0.0, decay * 34.0)
			draw_circle(position, 3.0 + float(index % 2), Color(_palette[1], 1.0 - decay))


func _build_vine(index: int) -> void:
	var vine_root := Node2D.new()
	vine_root.name = "ThornVine%02d" % (index + 1)
	add_child(vine_root)
	var base := _vine_base(index)
	var sway := sin(float(index) * 1.73) * 0.18
	var direction := Vector2(sway, -1.0).normalized()
	var segments: Array[Sprite2D] = []
	for segment_index in _segments_per_vine:
		var segment := Sprite2D.new()
		segment.name = "BloomSegment%02d" % (segment_index + 1)
		segment.texture = VINE_SEGMENT_TEXTURE
		segment.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		segment.material = _edge_material()
		var branch_offset := Vector2(
			sin(float(index) * 1.31 + float(segment_index) * 1.77) * (3.0 + segment_index * 0.7),
			0.0
		)
		segment.position = base + direction * _segment_stride * float(segment_index) + branch_offset
		segment.rotation = sway * (0.20 + float(segment_index) * 0.08) + sin(float(index + segment_index) * 1.19) * 0.055
		var segment_variation := 0.94 + float((index * 3 + segment_index * 5) % 7) * 0.018
		var target_scale := _segment_scale * segment_variation * (1.0 - float(segment_index) * 0.022)
		segment.scale = target_scale
		segment.set_meta("target_scale", target_scale)
		segment.flip_h = (index + segment_index) % 2 == 1
		segment.z_index = 4 + int(base.y / 20.0) + segment_index
		segment.visible = false
		vine_root.add_child(segment)
		segments.append(segment)
	var flower_position := base + direction * (
		_segment_stride * float(_segments_per_vine - 1)
		+ _flower_offset_from_last_segment
	)
	var flower := Sprite2D.new()
	flower.name = "TerminalFlower"
	flower.texture = TERMINAL_FLOWER_TEXTURE
	flower.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flower.material = _edge_material()
	flower.position = flower_position
	flower.z_index = 12 + int(base.y / 20.0)
	flower.visible = false
	vine_root.add_child(flower)
	var projectiles: Array[Dictionary] = []
	for projectile_index in _projectiles_per_vine:
		var projectile := Sprite2D.new()
		projectile.name = "ScatterThorn%02d" % (projectile_index + 1)
		projectile.texture = SCATTER_PROJECTILE_TEXTURE
		projectile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		projectile.material = _edge_material()
		projectile.z_index = 20 + index % 3
		projectile.visible = false
		vine_root.add_child(projectile)
		var ratio := float(projectile_index) / maxf(1.0, float(_projectiles_per_vine - 1))
		var vine_ratio := float(index) / maxf(1.0, float(_thorn_count - 1))
		var vine_aim := lerpf(-PI * 0.88, -PI * 0.12, vine_ratio)
		var fan_offset := lerpf(-PI * 0.13, PI * 0.13, ratio)
		var angle := clampf(
			vine_aim + fan_offset + sin(float(index) * 1.37 + float(projectile_index) * 1.91) * 0.035,
			-PI * 0.96,
			-PI * 0.04
		)
		var distance := _radius * (0.92 + float(projectile_index % 4) * 0.13) + 170.0
		var delay_slot := (projectile_index * 7 + index * 13) % _projectiles_per_vine
		projectiles.append({
			"sprite": projectile,
			"origin": flower_position,
			"target": flower_position + Vector2.from_angle(angle) * distance,
			"rotation": angle,
			"delay": float(delay_slot) / float(_projectiles_per_vine) * 0.34,
		})
	_vines.append({
		"index": index,
		"base": base,
		"sway": sway,
		"segments": segments,
		"flower": flower,
		"flower_scale": Vector2.ONE * (0.120 + float(_tier) * 0.008),
		"projectiles": projectiles,
	})


func _update_vine_projectiles(vine: Dictionary, vine_index: int, decay: float) -> void:
	var barrage := (_progress - 0.50) / 0.34
	for projectile_data_variant in vine.get("projectiles", []) as Array:
		var projectile_data := projectile_data_variant as Dictionary
		var projectile := projectile_data.get("sprite") as Sprite2D
		var local_progress := (barrage - float(projectile_data.get("delay", 0.0))) / 0.20
		if local_progress <= 0.0 or local_progress >= 1.0 or decay >= 0.99:
			projectile.visible = false
			continue
		var travel := 1.0 - pow(1.0 - local_progress, 2.35)
		var origin := projectile_data.get("origin", Vector2.ZERO) as Vector2
		var target := projectile_data.get("target", Vector2.ZERO) as Vector2
		projectile.position = origin.lerp(target, travel)
		projectile.rotation = float(projectile_data.get("rotation", 0.0))
		projectile.scale = Vector2(0.046, 0.056) * (1.0 + sin(local_progress * PI) * 0.18)
		projectile.modulate = Color(1.0, 1.0, 1.0, sin(local_progress * PI) * (1.0 - decay))
		projectile.visible = projectile.modulate.a > 0.02
		if projectile.visible:
			_active_scatter_projectile_count += 1


func _vine_base(index: int) -> Vector2:
	var horizontal_ratio := (
		0.0
		if _thorn_count <= 1
		else float(index) / float(_thorn_count - 1) - 0.5
	)
	return Vector2(
		horizontal_ratio * _radius * 2.10,
		_root_offset_y
	)


func _reset_active_counts() -> void:
	_active_vine_segment_count = 0
	_active_terminal_flower_count = 0
	_active_scatter_projectile_count = 0


func _edge_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = EDGE_SHADER
	return result
