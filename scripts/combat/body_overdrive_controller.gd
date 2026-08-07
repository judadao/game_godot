class_name BodyOverdriveController
extends Node

signal completed()

var _caster: Node
var _duration := 3.5
var _remaining := 0.0
var _move_speed_multiplier := 1.35
var _attack_speed_multiplier := 1.25
var _afterimage_count := 3
var _tier_rank := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node, profile: Dictionary) -> bool:
	if caster == null:
		return false
	_caster = caster
	_duration = maxf(0.2, float(profile.get("duration", 3.5)))
	_remaining = _duration
	_move_speed_multiplier = maxf(1.0, float(profile.get("move_speed_multiplier", 1.35)))
	_attack_speed_multiplier = maxf(1.0, float(profile.get("attack_speed_multiplier", 1.25)))
	_afterimage_count = maxi(1, int(profile.get("afterimage_count", 3)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	if caster.has_method("apply_temporary_move_speed"):
		caster.call("apply_temporary_move_speed", _move_speed_multiplier, _duration)
	if caster.has_method("apply_temporary_attack_speed"):
		caster.call("apply_temporary_attack_speed", _attack_speed_multiplier, _duration)
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - maxf(0.0, delta))
	if _remaining <= 0.0:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"buff_type": "body_overdrive_afterimage",
		"duration_seconds": _duration,
		"remaining_seconds": _remaining,
		"move_speed_multiplier": _move_speed_multiplier,
		"attack_speed_multiplier": _attack_speed_multiplier,
		"afterimage_count": _afterimage_count,
		"tier_rank": _tier_rank,
	}
