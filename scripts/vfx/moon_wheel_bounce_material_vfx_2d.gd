class_name MoonWheelBounceMaterialVFX2D
extends Node2D

@onready var outer_trail: Line2D = $OuterTrail
@onready var inner_trail: Line2D = $InnerTrail
@onready var rebound_flash: Line2D = $ReboundFlash

var _sprites: Array[Sprite2D] = []
var _tier_rank := 1
var _wheel_count := 5
var _round_trip_count := 1
var _range := 420.0
var _progress := 0.0
var _palette: Array[Color] = [Color.WHITE, Color("a8c9ff"), Color("7162d8")]


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
		if sprite_variant is Sprite2D:
			var sprite := sprite_variant as Sprite2D
			sprite.visible = true
			sprite.modulate = _palette[sprite.get_index() % _palette.size()]
			_sprites.append(sprite)
	outer_trail.default_color = Color(_palette[1], 0.55)
	inner_trail.default_color = Color(_palette[0], 0.88)
	rebound_flash.default_color = Color(_palette[2], 0.72)
	visible = true
	set_progress(0.0)


func clear() -> void:
	visible = false
	_sprites.clear()
	for line in [outer_trail, inner_trail, rebound_flash]:
		if line != null:
			line.clear_points()


func set_progress(value: float) -> void:
	if _sprites.is_empty():
		return
	_progress = clampf(value, 0.0, 1.0)
	var travel := (1.0 - cos(_progress * TAU * float(_round_trip_count))) * 0.5
	var direction := 1.0 if sin(_progress * TAU * float(_round_trip_count)) >= 0.0 else -1.0
	for index in _sprites.size():
		var lane := float(index) - float(_sprites.size() - 1) * 0.5
		var stagger := fposmod(travel + float(index % 3) * 0.045, 1.0)
		var sprite := _sprites[index]
		sprite.position = Vector2(lerpf(-_range, _range, stagger), -64.0 + lane * 18.0 + sin(stagger * PI) * (-52.0 - absf(lane) * 4.0))
		sprite.rotation += direction * (0.26 + _tier_rank * 0.08)
		sprite.modulate.a = minf(1.0, _progress * 8.0) * (1.0 - smoothstep(0.92, 1.0, _progress))
	var arc := _arc_points(_range, -62.0, 32)
	outer_trail.points = PackedVector2Array(arc)
	inner_trail.points = PackedVector2Array(_arc_points(_range * 0.92, -54.0, 28))
	var edge_x := lerpf(-_range, _range, travel)
	rebound_flash.points = PackedVector2Array([Vector2(edge_x, -150), Vector2(edge_x, 18)])
	rebound_flash.modulate.a = pow(absf(cos(_progress * TAU * float(_round_trip_count))), 10.0)


func get_active_layer_count() -> int:
	return _sprites.size() + 3 if visible else 0


func get_debug_state() -> Dictionary:
	return {
		"series_id": "moon_wheel", "wheel_count": _wheel_count,
		"round_trip_count": _round_trip_count, "layer_count": get_active_layer_count(),
		"blessing_mutable": true, "progress": _progress,
	}


func _arc_points(radius: float, y: float, segments: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in segments + 1:
		var ratio := float(index) / float(segments)
		result.append(Vector2(lerpf(-radius, radius, ratio), y - sin(ratio * PI) * 88.0))
	return result


func _resolve_palette(values: Array) -> Array[Color]:
	var result: Array[Color] = []
	for value in values:
		result.append(value if value is Color else Color(String(value)))
	while result.size() < 3:
		result.append(_palette[result.size()])
	return result.slice(0, 3)
