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


func play(
	origin: Vector2,
	target_position: Vector2,
	damage: int,
	combo_count: int,
	combo_damage_bonus: int = 0,
	critical: bool = false,
	projectile_speed_multiplier: float = 1.0,
	attack_size_multiplier: float = 1.0
) -> void:
	global_position = origin
	_target_offset = target_position - origin
	_accent = _accent_for_combo(combo_count)
	_attack_size_multiplier = clampf(attack_size_multiplier, 1.0, 2.5)
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


func _draw() -> void:
	if _travel_progress < 1.0:
		var tip := Vector2.ZERO.lerp(_target_offset, _travel_progress)
		var tail := Vector2.ZERO.lerp(_target_offset, maxf(0.0, _travel_progress - 0.24))
		draw_line(tail, tip, Color(_accent, 0.46), 8.0 * _attack_size_multiplier, true)
		draw_line(tail, tip, _accent, 3.0 * _attack_size_multiplier, true)
		draw_circle(tip, 7.0 * _attack_size_multiplier, _accent)
		draw_circle(tip, 3.0 * _attack_size_multiplier, Color.WHITE)
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
