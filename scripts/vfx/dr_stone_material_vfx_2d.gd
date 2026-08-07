class_name DrStoneMaterialVFX2D
extends Node2D

const LAYER_IDS := ["stone_core", "levitation_runes", "thruster_debris", "shot_trails", "impact_bursts", "crash_sequence"]

var _core_sprites: Array[Sprite2D] = []
var _runes: Array[Line2D] = []
var _shot_trails: Array[Line2D] = []
var _palette: Array[Color] = [Color("fff0c5"), Color("c3935f"), Color("5e4b43")]
var _tier := 1
var _drone_count := 3
var _duration := 5.0
var _progress := 0.0
var _refill_generation := 0


func configure(core_sprites: Array, tier_rank: int, palette: Array, parameters: Dictionary) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_drone_count = maxi(3, int(parameters.get("drone_count", [3, 6, 10][_tier - 1])))
	_duration = maxf(0.5, float(parameters.get("duration_seconds", [5.0, 7.0, 9.0][_tier - 1])))
	if palette.size() >= 3:
		_palette.assign([palette[0] as Color, palette[1] as Color, palette[2] as Color])
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			_core_sprites.append(core_variant as Sprite2D)
	for index in _core_sprites.size():
		_build_rune(index)
		_build_shot_trail(index)
	_refill_generation = 1
	visible = true
	set_progress(0.0)
	return not _core_sprites.is_empty()


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_runes.clear()
	_shot_trails.clear()
	_progress = 0.0
	_refill_generation = 0
	visible = false


func refill() -> int:
	_refill_generation += 1
	set_progress(0.0)
	return _core_sprites.size()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var reveal := smoothstep(0.0, 0.10, _progress)
	var crash := smoothstep(0.82, 1.0, _progress)
	for index in _core_sprites.size():
		var core := _core_sprites[index]
		var position_value := _drone_position(index)
		position_value.y += sin(_progress * TAU * 5.0 + index) * 7.0
		position_value.y += crash * crash * (110.0 + float(index % 3) * 35.0)
		position_value.x += crash * sin(index * 2.1) * 44.0
		core.position = position_value
		core.rotation = sin(_progress * TAU * 2.2 + index) * 0.12 + crash * (index % 2 * 2 - 1) * 2.4
		core.modulate.a = reveal * (1.0 - smoothstep(0.94, 1.0, _progress))
		core.visible = core.modulate.a > 0.01
		var rune := _runes[index]
		rune.position = position_value
		rune.rotation = _progress * TAU * (0.7 if index % 2 else -0.7)
		rune.modulate.a = reveal * (1.0 - crash)
		var trail := _shot_trails[index]
		trail.position = position_value
		var fire_pulse := maxf(0.0, sin((_progress * _duration / maxf(0.18, 0.68 - _tier * 0.10) + float(index) / _core_sprites.size()) * TAU))
		trail.modulate.a = reveal * fire_pulse * (1.0 - crash)
	queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "blessing_mutable_stone_drone_squad",
		"layer_ids": LAYER_IDS.duplicate(),
		"blessing_mutable": true,
		"mutable_channels": ["stone_material", "projectile_shape", "shot_trajectory", "impact_primitive", "crash_residue"],
		"tier_rank": _tier,
		"drone_count": _drone_count,
		"duration_seconds": _duration,
		"real_visual_layer_count": 2 + _core_sprites.size() + _runes.size() + _shot_trails.size(),
		"refill_generation": _refill_generation,
	}


func get_active_layer_count() -> int:
	return 2 + _core_sprites.size() + _runes.size() + _shot_trails.size()


func _draw() -> void:
	var crash := smoothstep(0.82, 1.0, _progress)
	for index in _core_sprites.size():
		var position_value := _core_sprites[index].position
		var thrust_alpha := (1.0 - crash) * (0.45 + sin(_progress * TAU * 8.0 + index) * 0.25)
		draw_line(position_value + Vector2(-5, 14), position_value + Vector2(-8, 30), Color(_palette[1], thrust_alpha), 4.0)
		draw_line(position_value + Vector2(5, 14), position_value + Vector2(8, 30), Color(_palette[0], thrust_alpha), 3.0)
		if crash > 0.0:
			for debris_index in 3:
				var debris := position_value + Vector2((debris_index - 1) * 9.0, -crash * 28.0 - debris_index * 8.0)
				draw_circle(debris, 3.0 + debris_index, Color(_palette[1], 1.0 - crash))


func _drone_position(index: int) -> Vector2:
	var row := index % 2
	var columns := ceili(float(_core_sprites.size()) / 2.0)
	var column := index / 2
	return Vector2((float(column) - float(columns - 1) * 0.5) * 58.0, -92.0 - row * 52.0)


func _build_rune(index: int) -> void:
	var rune := Line2D.new()
	rune.name = "LevitationRune%02d" % index
	rune.closed = true
	rune.width = 2.5
	rune.default_color = Color(_palette[0], 0.72)
	var points := PackedVector2Array()
	for point_index in 8:
		points.append(Vector2.from_angle(TAU * float(point_index) / 8.0) * 24.0)
	rune.points = points
	add_child(rune)
	_runes.append(rune)


func _build_shot_trail(index: int) -> void:
	var trail := Line2D.new()
	trail.name = "ShotTrail%02d" % index
	trail.width = 5.0
	trail.default_color = _palette[0]
	trail.points = PackedVector2Array([Vector2(12, 0), Vector2(72 + _tier * 12, 6 + float(index % 3) * 8.0)])
	add_child(trail)
	_shot_trails.append(trail)
