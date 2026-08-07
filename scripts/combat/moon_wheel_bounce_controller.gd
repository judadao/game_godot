class_name MoonWheelBounceController
extends Node

signal pass_started(pass_index: int, returning: bool)
signal impact(target: Node, world_position: Vector2, damage: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")
const MAX_CONTACT_IMPACTS_PER_ADVANCE := 1

var _caster: Node2D
var _target_provider := Callable()
var _wheel_count := 5
var _round_trip_count := 1
var _duration := 1.4
var _range := 420.0
var _damage_per_contact := 1
var _tier_rank := 1
var _elapsed := 0.0
var _resolved_pass_count := 0
var _resolved_contact_count := 0
var _next_contact_event := 0
var _contact_schedule: Array[Dictionary] = []
var _started_passes: Dictionary = {}
var _resolved_hits_by_pass: Dictionary = {}
var _completed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	_wheel_count = maxi(5, int(profile.get("wheel_count", 5)))
	_round_trip_count = maxi(1, int(profile.get("round_trip_count", 1)))
	_duration = maxf(0.4, float(profile.get("duration", 1.4)))
	_range = maxf(120.0, float(profile.get("range", 420.0)))
	_damage_per_contact = maxi(1, int(profile.get("damage_per_contact", 1)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_elapsed = 0.0
	_resolved_pass_count = 0
	_resolved_contact_count = 0
	_next_contact_event = 0
	_started_passes.clear()
	_resolved_hits_by_pass.clear()
	_completed = false
	_build_contact_schedule()
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _completed:
		return
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var resolved_impacts_this_advance := 0
	while _next_contact_event < _contact_schedule.size():
		var event := _contact_schedule[_next_contact_event]
		if float(event.get("time", _duration)) > _elapsed:
			break
		var dealt_damage := _resolve_contact(event)
		_next_contact_event += 1
		if dealt_damage:
			resolved_impacts_this_advance += 1
			if resolved_impacts_this_advance >= MAX_CONTACT_IMPACTS_PER_ADVANCE:
				break
	if _elapsed >= _duration and _next_contact_event >= _contact_schedule.size():
		_completed = true
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"attack_type": "bouncing_moon_wheel_field",
		"wheel_count": _wheel_count,
		"round_trip_count": _round_trip_count,
		"resolved_pass_count": _resolved_pass_count,
		"resolved_contact_count": _resolved_contact_count,
		"duration_seconds": _duration,
		"range": _range,
		"tier_rank": _tier_rank,
		"contact_cadence": "staggered_rebound_volley",
		"scheduled_contact_count": _contact_schedule.size(),
		"pending_contact_count": _contact_schedule.size() - _next_contact_event,
		"max_contact_impacts_per_advance": MAX_CONTACT_IMPACTS_PER_ADVANCE,
		"completed": _completed,
	}


func _build_contact_schedule() -> void:
	_contact_schedule.clear()
	var total_passes := _round_trip_count * 2
	var flight_start := _duration * 0.12
	var flight_duration := _duration * 0.78
	var pass_span := flight_duration / float(total_passes)
	var contact_window := minf(pass_span * 0.28, 0.18)
	for pass_index in total_passes:
		var center_time := flight_start + pass_span * float(pass_index + 1)
		for contact_index in _wheel_count:
			var ratio := (
				0.5
				if _wheel_count <= 1
				else float(contact_index) / float(_wheel_count - 1)
			)
			_contact_schedule.append({
				"time": center_time + (ratio - 0.5) * contact_window,
				"pass_index": pass_index,
				"contact_index": contact_index,
			})


func _resolve_contact(event: Dictionary) -> bool:
	var pass_index := int(event.get("pass_index", 0))
	var returning := pass_index % 2 == 1
	if not _started_passes.has(pass_index):
		_started_passes[pass_index] = true
		_resolved_pass_count += 1
		pass_started.emit(pass_index, returning)
	var targets := _targets_in_range()
	if targets.is_empty():
		return false
	var contacts := maxi(1, mini(_wheel_count, targets.size() * 2))
	var resolved_for_pass := int(_resolved_hits_by_pass.get(pass_index, 0))
	if resolved_for_pass >= contacts:
		return false
	var target := targets[resolved_for_pass % targets.size()]
	var source := _caster.global_position + Vector2((-1.0 if returning else 1.0) * _range, -40.0)
	var dealt := _deal_damage(target, source)
	if dealt > 0:
		_resolved_hits_by_pass[pass_index] = resolved_for_pass + 1
		_resolved_contact_count += 1
		impact.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)
		return true
	return false


func _targets_in_range() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var variant: Variant = _target_provider.call() if _target_provider.is_valid() else []
	if not variant is Array:
		return result
	for target_variant in variant as Array:
		if target_variant is Node2D and is_instance_valid(target_variant):
			var target := target_variant as Node2D
			if _caster.global_position.distance_to(ATTACK_GEOMETRY.target_center(target)) <= _range:
				result.append(target)
	return result


func _deal_damage(target: Node2D, source: Vector2) -> int:
	return TARGET_ADAPTER.deal_damage(target, _damage_per_contact, source, 55.0)
