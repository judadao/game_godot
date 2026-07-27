class_name EnemyAttackFeedback
extends Node2D

var _pattern: StringName = &"jab"
var _reach := 60.0
var _direction := 1.0
var _telegraph_visible := false
var _impact_visible := false
var _pulse_elapsed := 0.0
var _impact_progress := 0.0
var _target_offset := Vector2.ZERO


func _process(delta: float) -> void:
	if not _telegraph_visible:
		return
	_pulse_elapsed += delta
	queue_redraw()


func show_telegraph(
	pattern: StringName,
	duration: float,
	reach: float,
	direction: float,
	target_offset: Vector2 = Vector2.ZERO
) -> void:
	_pattern = pattern
	_reach = maxf(32.0, reach)
	_direction = -1.0 if direction < 0.0 else 1.0
	_target_offset = target_offset
	_telegraph_visible = true
	_impact_visible = false
	_impact_progress = 0.0
	_pulse_elapsed = 0.0
	modulate.a = 1.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.52, maxf(0.05, duration * 0.45))
	tween.tween_property(self, "modulate:a", 1.0, maxf(0.05, duration * 0.45))


func show_impact(pattern: StringName, reach: float, direction: float) -> void:
	_pattern = pattern
	_reach = maxf(32.0, reach)
	_direction = -1.0 if direction < 0.0 else 1.0
	_telegraph_visible = false
	_impact_visible = true
	_impact_progress = 0.0
	modulate.a = 1.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_impact_progress, 0.0, 1.0, 0.22)
	tween.tween_callback(_hide_impact)


func cancel() -> void:
	_telegraph_visible = false
	_impact_visible = false
	queue_redraw()


func is_telegraph_visible() -> bool:
	return _telegraph_visible


func is_impact_visible() -> bool:
	return _impact_visible


func _draw() -> void:
	var end_x := _reach * _direction
	var half_height := 24.0
	match _pattern:
		&"thorn_volley":
			half_height = 13.0
		&"shockwave":
			half_height = 34.0
		&"cleave":
			half_height = 42.0
	var warning_polygon := PackedVector2Array([
		Vector2(0.0, -half_height),
		Vector2(end_x, -half_height),
		Vector2(end_x, half_height),
		Vector2(0.0, half_height),
	])
	if _telegraph_visible:
		var pulse := 0.16 + (sin(_pulse_elapsed * 24.0) + 1.0) * 0.07
		if _pattern == &"falling_acorns":
			for offset_x in [-70.0, 0.0, 70.0]:
				var center := _target_offset + Vector2(offset_x, 0.0)
				draw_circle(center, 34.0, Color(1.0, 0.14, 0.04, pulse))
				draw_arc(center, 34.0, 0.0, TAU, 24, Color(1.0, 0.78, 0.20, 0.95), 3.0, true)
				draw_line(center + Vector2(0.0, -180.0), center, Color(1.0, 0.42, 0.08, 0.72), 3.0, true)
			return
		if _pattern == &"ember_burst":
			draw_circle(Vector2.ZERO, _reach, Color(1.0, 0.08, 0.02, pulse * 0.72))
			draw_arc(Vector2.ZERO, _reach, 0.0, TAU, 40, Color(1.0, 0.48, 0.08, 0.96), 4.0, true)
			return
		draw_colored_polygon(warning_polygon, Color(1.0, 0.10, 0.04, pulse))
		draw_polyline(
			PackedVector2Array([
				Vector2(0.0, -half_height),
				Vector2(end_x, -half_height),
				Vector2(end_x, half_height),
				Vector2(0.0, half_height),
			]),
			Color(1.0, 0.28, 0.10, 0.92),
			3.0,
			true
		)
		draw_line(
			Vector2(end_x, -half_height),
			Vector2(end_x, half_height),
			Color(1.0, 0.88, 0.42, 1.0),
			4.0,
			true
		)
	elif _impact_visible:
		var alpha := 1.0 - _impact_progress
		draw_colored_polygon(warning_polygon, Color(1.0, 0.30, 0.05, alpha * 0.34))
		draw_line(
			Vector2.ZERO,
			Vector2(end_x, 0.0),
			Color(1.0, 0.88, 0.48, alpha),
			lerpf(12.0, 2.0, _impact_progress),
			true
		)
		draw_arc(
			Vector2(end_x, 0.0),
			lerpf(8.0, 42.0, _impact_progress),
			0.0,
			TAU,
			24,
			Color(1.0, 0.34, 0.08, alpha),
			lerpf(6.0, 1.0, _impact_progress),
			true
		)


func _set_impact_progress(value: float) -> void:
	_impact_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _hide_impact() -> void:
	_impact_visible = false
	queue_redraw()
