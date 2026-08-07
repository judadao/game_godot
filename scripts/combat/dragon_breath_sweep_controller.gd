class_name DragonBreathSweepController
extends Node2D

signal sweep_started(sweep_index: int, from_left: bool)
signal rain_emitter_fired(emitter_index: int, world_position: Vector2)
signal impact(target: Node, world_position: Vector2, damage: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")

var _caster: Node2D
var _target_provider := Callable()
var _side_sweep_count := 1
var _side_sweep_duration := 0.9
var _rain_emitter_count := 0
var _rain_duration := 0.0
var _range := 460.0
var _damage_per_sweep := 1
var _damage_per_rain_hit := 1
var _tier_rank := 1
var _elapsed := 0.0
var _total_duration := 0.9
var _resolved_side_sweeps := 0
var _resolved_rain_emitters := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	global_position = caster.global_position
	_side_sweep_count = clampi(int(profile.get("side_sweep_count", 1)), 1, 2)
	_side_sweep_duration = maxf(0.2, float(profile.get("side_sweep_duration", 0.9)))
	_rain_emitter_count = maxi(0, int(profile.get("rain_emitter_count", 0)))
	_rain_duration = maxf(0.0, float(profile.get("rain_duration", 0.0)))
	_range = maxf(96.0, float(profile.get("range", 460.0)))
	_damage_per_sweep = maxi(1, int(profile.get("damage_per_sweep", 1)))
	_damage_per_rain_hit = maxi(1, int(profile.get("damage_per_rain_hit", 1)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_elapsed = 0.0
	_resolved_side_sweeps = 0
	_resolved_rain_emitters = 0
	_total_duration = _side_sweep_duration + _rain_duration
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _elapsed >= _total_duration or _caster == null or not is_instance_valid(_caster):
		return
	_elapsed = minf(_total_duration, _elapsed + maxf(0.0, delta))
	while _resolved_side_sweeps < _side_sweep_count and _elapsed >= _side_sweep_duration:
		_resolve_side_sweep(_resolved_side_sweeps)
		_resolved_side_sweeps += 1
	var rain_elapsed := maxf(0.0, _elapsed - _side_sweep_duration)
	if _rain_emitter_count > 0 and _rain_duration > 0.0:
		var expected_emitters := mini(_rain_emitter_count, floori(rain_elapsed / _rain_duration * float(_rain_emitter_count)))
		if rain_elapsed >= _rain_duration:
			expected_emitters = _rain_emitter_count
		while _resolved_rain_emitters < expected_emitters:
			_resolve_rain_emitter(_resolved_rain_emitters)
			_resolved_rain_emitters += 1
	if _elapsed >= _total_duration:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"attack_type": "dragon_breath_sweep",
		"side_sweep_count": _side_sweep_count,
		"side_sweep_duration": _side_sweep_duration,
		"rain_emitter_count": _rain_emitter_count,
		"rain_duration": _rain_duration,
		"range": _range,
		"tier_rank": _tier_rank,
		"resolved_side_sweeps": _resolved_side_sweeps,
		"resolved_rain_emitters": _resolved_rain_emitters,
	}


func _targets_in_range() -> Array[Node2D]:
	var resolved: Array[Node2D] = []
	if not _target_provider.is_valid():
		return resolved
	var targets_variant: Variant = _target_provider.call()
	if not targets_variant is Array:
		return resolved
	for target_variant in targets_variant as Array:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var target := target_variant as Node2D
		if _caster.global_position.distance_to(ATTACK_GEOMETRY.target_center(target)) <= _range:
			resolved.append(target)
	return resolved


func _resolve_side_sweep(sweep_index: int) -> void:
	var from_left := sweep_index % 2 == 0
	sweep_started.emit(sweep_index, from_left)
	for target in _targets_in_range():
		_apply_damage(target, _damage_per_sweep, 110.0)


func _resolve_rain_emitter(emitter_index: int) -> void:
	var ratio := (float(emitter_index) + 0.5) / float(maxi(1, _rain_emitter_count))
	var position_x := lerpf(-_range, _range, ratio)
	var emitter_position := _caster.global_position + Vector2(position_x, -250.0)
	rain_emitter_fired.emit(emitter_index, emitter_position)
	var targets := _targets_in_range()
	if targets.is_empty():
		return
	var target := targets[emitter_index % targets.size()]
	_apply_damage(target, _damage_per_rain_hit, 35.0)


func _apply_damage(target: Node2D, amount: int, knockback: float) -> void:
	var dealt := TARGET_ADAPTER.deal_damage(
		target, amount, _caster.global_position, knockback
	)
	if dealt > 0:
		impact.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)
