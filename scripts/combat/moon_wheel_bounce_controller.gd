class_name MoonWheelBounceController
extends Node

signal pass_started(pass_index: int, returning: bool)
signal impact(target: Node, world_position: Vector2, damage: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

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
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _elapsed >= _duration:
		return
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var total_passes := _round_trip_count * 2
	var expected_passes := mini(total_passes, floori(_elapsed / _duration * float(total_passes)))
	if _elapsed >= _duration:
		expected_passes = total_passes
	while _resolved_pass_count < expected_passes:
		_resolve_pass(_resolved_pass_count)
		_resolved_pass_count += 1
	if _elapsed >= _duration:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"attack_type": "bouncing_moon_wheel_field",
		"wheel_count": _wheel_count,
		"round_trip_count": _round_trip_count,
		"resolved_pass_count": _resolved_pass_count,
		"duration_seconds": _duration,
		"range": _range,
		"tier_rank": _tier_rank,
	}


func _resolve_pass(pass_index: int) -> void:
	var returning := pass_index % 2 == 1
	pass_started.emit(pass_index, returning)
	var targets := _targets_in_range()
	if targets.is_empty():
		return
	var contacts := maxi(1, mini(_wheel_count, targets.size() * 2))
	for contact_index in contacts:
		var target := targets[contact_index % targets.size()]
		var source := _caster.global_position + Vector2((-1.0 if returning else 1.0) * _range, -40.0)
		var dealt := _deal_damage(target, source)
		if dealt > 0:
			impact.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)


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
	if target.has_method("take_hit"):
		return int(target.call("take_hit", _damage_per_contact, source, 55.0))
	if target.has_method("take_damage"):
		return int(target.call("take_damage", _damage_per_contact))
	return 0
