class_name HealingZoneController
extends Node2D

signal healing_pulse(amount: int, world_position: Vector2)
signal completed()

var _caster: Node2D
var _duration := 4.0
var _remaining := 0.0
var _radius := 150.0
var _pulse_interval := 0.75
var _pulse_remaining := 0.0
var _heal_per_pulse := 5
var _tier_rank := 1
var _pulse_count := 0
var _total_restored := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position = Vector2.ZERO
	set_process(false)


func configure(caster: Node2D, profile: Dictionary) -> bool:
	if caster == null:
		return false
	_caster = caster
	position = Vector2.ZERO
	_duration = maxf(0.5, float(profile.get("duration", 4.0)))
	_remaining = _duration
	_radius = maxf(48.0, float(profile.get("radius", 150.0)))
	_pulse_interval = maxf(0.1, float(profile.get("pulse_interval", 0.75)))
	_pulse_remaining = 0.0
	_heal_per_pulse = maxi(1, int(profile.get("heal_per_pulse", 5)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_pulse_count = 0
	_total_restored = 0
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _remaining <= 0.0 or _caster == null or not is_instance_valid(_caster):
		return
	var safe_delta := maxf(0.0, delta)
	var active_delta := minf(safe_delta, _remaining)
	_pulse_remaining -= active_delta
	while _pulse_remaining <= 0.0:
		_resolve_healing_pulse()
		_pulse_remaining += _pulse_interval
	_remaining = maxf(0.0, _remaining - safe_delta)
	if _remaining <= 0.0:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"field_type": "player_healing_zone",
		"duration_seconds": _duration,
		"remaining_seconds": _remaining,
		"radius": _radius,
		"pulse_interval": _pulse_interval,
		"heal_per_pulse": _heal_per_pulse,
		"tier_rank": _tier_rank,
		"pulse_count": _pulse_count,
		"total_restored": _total_restored,
	}


func _resolve_healing_pulse() -> void:
	_pulse_count += 1
	var restored := 0
	if _caster.has_method("restore_health"):
		restored = int(_caster.call("restore_health", _heal_per_pulse))
	_total_restored += restored
	healing_pulse.emit(restored, _caster.global_position)
