class_name ArcaneSwampMaterialVFX2D
extends Node2D

const LAYER_IDS := ["swamp_surface", "arcane_runes", "tentacle_body", "binding_coils", "damage_pulses"]

var _core_sprites: Array[Sprite2D] = []
var _tentacles: Array[Line2D] = []
var _runes: Array[Line2D] = []
var _palette: Array[Color] = [Color("d8ffad"), Color("5c9c69"), Color("34204f")]
var _tier := 1
var _target_limit := 10
var _radius := 260.0
var _duration := 3.0
var _progress := 0.0
var _target_positions: Array[Vector2] = []


func configure(core_sprites: Array, tier_rank: int, palette: Array, parameters: Dictionary, target_positions: Array[Vector2] = []) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_target_limit = maxi(10, int(parameters.get("target_limit", [10, 14, 20][_tier - 1])))
	_radius = maxf(48.0, float(parameters.get("radius", [260.0, 320.0, 390.0][_tier - 1])))
	_duration = maxf(0.2, float(parameters.get("duration_seconds", [3.0, 3.8, 4.8][_tier - 1])))
	if palette.size() >= 3:
		_palette.assign([palette[0] as Color, palette[1] as Color, palette[2] as Color])
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			var core := core_variant as Sprite2D
			core.visible = false
			_core_sprites.append(core)
	_target_positions = target_positions.duplicate()
	while _target_positions.size() < _target_limit:
		var index := _target_positions.size()
		var angle := TAU * float(index) / float(_target_limit)
		_target_positions.append(Vector2.from_angle(angle) * _radius * (0.34 + float(index % 3) * 0.14))
	if _target_positions.size() > _target_limit:
		_target_positions.resize(_target_limit)
	for index in _target_limit:
		_build_tentacle(index, _target_positions[index])
		_build_rune(index, _target_positions[index])
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_tentacles.clear()
	_runes.clear()
	_target_positions.clear()
	_progress = 0.0
	visible = false


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var reveal := smoothstep(0.0, 0.18, _progress)
	var bind := smoothstep(0.12, 0.32, _progress)
	var decay := smoothstep(0.86, 1.0, _progress)
	for index in _tentacles.size():
		var stagger := float(index % 5) * 0.018
		var local_bind := smoothstep(0.12 + stagger, 0.30 + stagger, _progress)
		var tentacle := _tentacles[index]
		tentacle.scale.y = local_bind
		tentacle.modulate.a = local_bind * (1.0 - decay)
		tentacle.rotation = sin(_progress * TAU * 3.0 + index) * 0.06
		var rune := _runes[index]
		rune.rotation = _progress * TAU * (-0.35 if index % 2 else 0.35)
		rune.modulate.a = reveal * (1.0 - decay)
	queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "blessing_mutable_arcane_swamp",
		"layer_ids": LAYER_IDS.duplicate(),
		"blessing_mutable": true,
		"mutable_channels": ["palette", "surface_material", "tentacle_density", "binding_pulse", "damage_impact"],
		"tier_rank": _tier,
		"target_limit": _target_limit,
		"radius": _radius,
		"duration_seconds": _duration,
		"real_visual_layer_count": 3 + _tentacles.size() + _runes.size(),
	}


func get_active_layer_count() -> int:
	return 3 + _tentacles.size() + _runes.size()


func _draw() -> void:
	var reveal := smoothstep(0.0, 0.18, _progress)
	var decay := smoothstep(0.86, 1.0, _progress)
	var alpha := reveal * (1.0 - decay)
	draw_circle(Vector2.ZERO, _radius * 0.72, Color(_palette[2], 0.22 * alpha))
	draw_arc(Vector2.ZERO, _radius * 0.70, 0.0, TAU, 96, Color(_palette[1], 0.46 * alpha), 8.0)
	var pulse := 0.55 + sin(_progress * TAU * 14.0) * 0.35
	for position_value in _target_positions:
		draw_arc(position_value, 22.0 + _tier * 3.0, 0.0, TAU, 24, Color(_palette[0], pulse * alpha), 4.0)
		draw_line(position_value + Vector2(-14, -10), position_value + Vector2(14, 10), Color(_palette[1], alpha), 3.0)


func _build_tentacle(index: int, target_position: Vector2) -> void:
	var tentacle := Line2D.new()
	tentacle.name = "BindingTentacle%02d" % index
	tentacle.width = 8.0 + _tier * 1.5
	tentacle.default_color = _palette[1].lerp(_palette[2], 0.38)
	tentacle.joint_mode = Line2D.LINE_JOINT_ROUND
	tentacle.position = target_position
	tentacle.points = PackedVector2Array([
		Vector2(0, 18), Vector2(-12, -4), Vector2(11, -26), Vector2(-8, -52), Vector2(5, -76),
	])
	add_child(tentacle)
	_tentacles.append(tentacle)


func _build_rune(index: int, target_position: Vector2) -> void:
	var rune := Line2D.new()
	rune.name = "BindingRune%02d" % index
	rune.closed = true
	rune.width = 2.5
	rune.default_color = Color(_palette[0], 0.72)
	rune.position = target_position
	var points := PackedVector2Array()
	for point_index in 8:
		points.append(Vector2.from_angle(TAU * float(point_index) / 8.0) * (25.0 + float(index % 3) * 2.0))
	rune.points = points
	add_child(rune)
	_runes.append(rune)
