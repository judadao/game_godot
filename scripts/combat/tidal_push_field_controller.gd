class_name TidalPushFieldController
extends Node

signal wave_pulse(target: Node, world_position: Vector2, damage: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const MAX_USEFUL_PUSH_DISTANCE := 140.0

var _caster: Node2D
var _target_provider := Callable()
var _duration := 1.2
var _remaining := 0.0
var _radius := 260.0
var _tick_interval := 0.24
var _tick_remaining := 0.0
var _push_distance := 60.0
var _damage_per_tick := 1
var _tier_rank := 1
var _pulse_count := 0
var _applied_push_distance := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	_duration = maxf(0.2, float(profile.get("duration", 1.2)))
	_remaining = _duration
	_radius = maxf(96.0, float(profile.get("radius", 260.0)))
	_tick_interval = maxf(0.08, float(profile.get("tick_interval", 0.24)))
	_tick_remaining = 0.0
	_push_distance = clampf(float(profile.get("push_distance", 60.0)), 0.0, MAX_USEFUL_PUSH_DISTANCE)
	_damage_per_tick = maxi(1, int(profile.get("damage_per_tick", 1)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_pulse_count = 0
	_applied_push_distance = 0.0
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _remaining <= 0.0:
		return
	var safe_delta := maxf(0.0, delta)
	var active_delta := minf(safe_delta, _remaining)
	_tick_remaining -= active_delta
	while _tick_remaining <= 0.0:
		_resolve_pulse()
		_tick_remaining += _tick_interval
	_remaining = maxf(0.0, _remaining - safe_delta)
	if _remaining <= 0.0:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"field_type": "damaging_tidal_push",
		"duration_seconds": _duration,
		"remaining_seconds": _remaining,
		"radius": _radius,
		"push_distance": _push_distance,
		"applied_push_distance": _applied_push_distance,
		"pulse_count": _pulse_count,
		"tier_rank": _tier_rank,
	}


func _resolve_pulse() -> void:
	_pulse_count += 1
	var pulse_total := maxi(1, ceili(_duration / _tick_interval))
	var push_step := _push_distance / float(pulse_total)
	for target in _targets_in_radius():
		var direction := signf(target.global_position.x - _caster.global_position.x)
		if direction == 0.0:
			direction = 1.0
		target.global_position.x += direction * push_step
		var dealt := _deal_damage(target)
		if dealt > 0:
			wave_pulse.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)
	_applied_push_distance = minf(_push_distance, _applied_push_distance + push_step)


func _targets_in_radius() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var variant: Variant = _target_provider.call() if _target_provider.is_valid() else []
	if not variant is Array:
		return result
	for target_variant in variant as Array:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var target := target_variant as Node2D
		if _caster.global_position.distance_to(ATTACK_GEOMETRY.target_center(target)) <= _radius:
			result.append(target)
	return result


func _deal_damage(target: Node2D) -> int:
	if target.has_method("take_hit"):
		return int(target.call("take_hit", _damage_per_tick, _caster.global_position, 0.0))
	if target.has_method("take_damage"):
		return int(target.call("take_damage", _damage_per_tick))
	return 0
