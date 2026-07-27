class_name AutoAttackFeedback
extends Node2D

signal finished

const TRAVEL_DURATION := 0.16
const IMPACT_DURATION := 0.34

@onready var damage_label: Label = $DamageLabel
@onready var combo_label: Label = $ComboLabel

var _target_offset := Vector2.ZERO
var _travel_progress := 0.0
var _impact_progress := 0.0
var _accent := Color(1.0, 0.56, 0.18, 1.0)
var _attack_size_multiplier := 1.0
var _visual_colors: Array[Color] = []
var _stack_count := 0
var _lifesteal := false
var _direction_index := 0
var _direction_count := 1
var _projectile_index := 0
var _projectiles_per_direction := 1


func play(
	origin: Vector2,
	target_position: Vector2,
	damage: int,
	combo_count: int,
	combo_damage_bonus: int = 0,
	critical: bool = false,
	projectile_speed_multiplier: float = 1.0,
	attack_size_multiplier: float = 1.0,
	visual_profile: Dictionary = {}
) -> void:
	global_position = origin
	_target_offset = target_position - origin
	_stack_count = maxi(0, int(visual_profile.get("stack_count", 0)))
	_lifesteal = bool(visual_profile.get("lifesteal", false))
	_direction_count = maxi(1, int(visual_profile.get("direction_count", 1)))
	_direction_index = clampi(
		int(visual_profile.get("direction_index", 0)),
		0,
		_direction_count - 1
	)
	_projectiles_per_direction = maxi(
		1,
		int(visual_profile.get("projectiles_per_direction", 1))
	)
	_projectile_index = clampi(
		int(visual_profile.get("projectile_index", 0)),
		0,
		_projectiles_per_direction - 1
	)
	_visual_colors = _colors_for_elements(visual_profile.get("elements", []) as Array)
	_accent = _blended_accent(_visual_colors, _accent_for_combo(combo_count))
	_attack_size_multiplier = clampf(
		attack_size_multiplier * (1.0 + minf(10.0, float(_stack_count)) * 0.035),
		1.0,
		3.0
	)
	damage_label.text = "%s%d" % ["CRIT  -" if critical else "-", maxi(0, damage)]
	damage_label.add_theme_color_override("font_color", _accent)
	combo_label.text = (
		"COMBO ×%d   POWER +%d" % [combo_count, maxi(0, combo_damage_bonus)]
		if combo_count > 0
		else "AUTO ATTACK"
	)
	combo_label.add_theme_color_override("font_color", _accent.lightened(0.18))
	damage_label.position = _target_offset + Vector2(-42.0, -82.0)
	combo_label.position = _target_offset + Vector2(-70.0, -58.0)
	damage_label.visible = false
	combo_label.visible = false
	queue_redraw()

	var travel_tween := create_tween()
	travel_tween.set_trans(Tween.TRANS_QUAD)
	travel_tween.set_ease(Tween.EASE_OUT)
	travel_tween.tween_method(
		_set_travel_progress,
		0.0,
		1.0,
		TRAVEL_DURATION / maxf(0.25, projectile_speed_multiplier)
	)
	travel_tween.tween_callback(_show_impact)
	travel_tween.tween_method(_set_impact_progress, 0.0, 1.0, IMPACT_DURATION)
	travel_tween.tween_callback(_finish)


func get_combo_text() -> String:
	return combo_label.text if combo_label != null else ""


func get_damage_text() -> String:
	return damage_label.text if damage_label != null else ""


func get_visual_layer_count() -> int:
	return _visual_colors.size() + (1 if _lifesteal else 0)


func get_attack_scale() -> float:
	return _attack_size_multiplier


func get_direction_count() -> int:
	return _direction_count


func _draw() -> void:
	if _travel_progress < 1.0:
		var tip := _travel_point(_travel_progress)
		var tail := _travel_point(maxf(0.0, _travel_progress - 0.24))
		draw_line(tail, tip, Color(_accent, 0.46), 8.0 * _attack_size_multiplier, true)
		draw_line(tail, tip, _accent, 3.0 * _attack_size_multiplier, true)
		var normal := _target_offset.normalized().orthogonal()
		for layer_index in _visual_colors.size():
			var layer_offset := (
				float(layer_index) - float(_visual_colors.size() - 1) * 0.5
			) * 4.0 * _attack_size_multiplier
			var layer_color := _visual_colors[layer_index]
			draw_line(
				tail + normal * layer_offset,
				tip + normal * layer_offset,
				Color(layer_color, 0.82),
				maxf(1.5, 2.4 * _attack_size_multiplier),
				true
			)
		draw_circle(tip, 7.0 * _attack_size_multiplier, _accent)
		draw_circle(tip, 3.0 * _attack_size_multiplier, Color.WHITE)
		var mote_count := mini(10, _stack_count)
		for mote_index in mote_count:
			var angle := TAU * float(mote_index) / float(maxi(1, mote_count)) + _travel_progress * TAU
			var mote_position := tip + Vector2.from_angle(angle) * (9.0 + 2.0 * _attack_size_multiplier)
			draw_circle(mote_position, 1.5 + 0.25 * _attack_size_multiplier, _accent.lightened(0.2))
	if _impact_progress > 0.0:
		var alpha := 1.0 - _impact_progress
		var radius := lerpf(8.0, 34.0, _impact_progress) * _attack_size_multiplier
		draw_arc(
			_target_offset,
			radius,
			0.0,
			TAU,
			24,
			Color(_accent, alpha),
			lerpf(6.0, 1.0, _impact_progress),
			true
		)
		draw_circle(
			_target_offset,
			lerpf(12.0, 3.0, _impact_progress),
			Color(1.0, 1.0, 1.0, alpha * 0.78)
		)
		for layer_index in _visual_colors.size():
			draw_arc(
				_target_offset,
				radius + float(layer_index + 1) * 5.0,
				0.0,
				TAU,
				24,
				Color(_visual_colors[layer_index], alpha * 0.78),
				2.0,
				true
			)
		if _lifesteal:
			draw_arc(
				_target_offset,
				radius * 0.72,
				0.0,
				TAU,
				20,
				Color(0.95, 0.12, 0.32, alpha),
				3.0,
				true
			)


func _travel_point(progress: float) -> Vector2:
	if _target_offset.is_zero_approx():
		return Vector2.ZERO.lerp(_target_offset, progress)
	var normal := _target_offset.normalized().orthogonal()
	var direction_center := float(_direction_count - 1) * 0.5
	var projectile_center := float(_projectiles_per_direction - 1) * 0.5
	var direction_bend := (float(_direction_index) - direction_center) * 42.0
	var projectile_lane := (float(_projectile_index) - projectile_center) * 8.0
	var bend := direction_bend + projectile_lane
	if is_zero_approx(bend):
		return Vector2.ZERO.lerp(_target_offset, progress)
	var control := _target_offset * 0.45 + normal * bend
	var remaining := 1.0 - progress
	return (
		2.0 * remaining * progress * control
		+ progress * progress * _target_offset
	)


func _set_travel_progress(value: float) -> void:
	_travel_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_impact_progress(value: float) -> void:
	_impact_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _show_impact() -> void:
	damage_label.visible = true
	combo_label.visible = true
	var label_tween := create_tween().set_parallel(true)
	label_tween.tween_property(damage_label, "position:y", damage_label.position.y - 24.0, IMPACT_DURATION)
	label_tween.tween_property(combo_label, "position:y", combo_label.position.y - 18.0, IMPACT_DURATION)
	label_tween.tween_property(damage_label, "modulate:a", 0.0, IMPACT_DURATION).set_delay(0.12)
	label_tween.tween_property(combo_label, "modulate:a", 0.0, IMPACT_DURATION).set_delay(0.12)


func _finish() -> void:
	finished.emit()
	queue_free()


func _accent_for_combo(combo_count: int) -> Color:
	if combo_count >= 9:
		return Color(0.82, 0.38, 1.0, 1.0)
	if combo_count >= 6:
		return Color(0.38, 1.0, 0.58, 1.0)
	if combo_count >= 3:
		return Color(1.0, 0.82, 0.20, 1.0)
	return Color(1.0, 0.56, 0.18, 1.0)


func _colors_for_elements(elements: Array) -> Array[Color]:
	var colors: Array[Color] = []
	for element_variant in elements:
		var color := Color.WHITE
		match String(element_variant):
			"flame":
				color = Color(1.0, 0.25, 0.06, 1.0)
			"frost":
				color = Color(0.20, 0.86, 1.0, 1.0)
			"storm":
				color = Color(0.82, 0.54, 1.0, 1.0)
			"venom":
				color = Color(0.34, 1.0, 0.24, 1.0)
			_:
				continue
		colors.append(color)
	return colors


func _blended_accent(colors: Array[Color], fallback: Color) -> Color:
	if colors.is_empty():
		return fallback
	var blended := colors[0]
	for index in range(1, colors.size()):
		blended = blended.lerp(colors[index], 0.38)
	return blended.lightened(minf(0.22, float(_stack_count) * 0.012))
