class_name ResidualLightningController
extends Node

signal chain_hit(from_position: Vector2, target: Node, target_position: Vector2)
signal final_strike(target: Node, target_position: Vector2)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")

var _caster: Node2D
var _target_provider := Callable()
var _marked_target_limit := 10
var _residual_duration := 1.8
var _chain_interval := 0.16
var _residual_damage := 1
var _final_strike_damage := 1
var _tier_rank := 1
var _remaining := 0.0
var _chain_remaining := 0.0
var _marked_refs: Array[WeakRef] = []
var _chain_index := 0
var _chain_hit_count := 0
var _final_strike_count := 0
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	_marked_target_limit = maxi(1, int(profile.get("marked_target_limit", 10)))
	_residual_duration = maxf(0.2, float(profile.get("residual_duration", 1.8)))
	_chain_interval = maxf(0.06, float(profile.get("chain_interval", 0.16)))
	_residual_damage = maxi(1, int(profile.get("residual_damage", 1)))
	_final_strike_damage = maxi(1, int(profile.get("final_strike_damage", 1)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_remaining = _residual_duration
	_chain_remaining = 0.0
	_chain_index = 0
	_chain_hit_count = 0
	_final_strike_count = 0
	_finished = false
	_capture_marks()
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _finished:
		return
	var safe_delta := maxf(0.0, delta)
	_remaining -= safe_delta
	_chain_remaining -= safe_delta
	while _chain_remaining <= 0.0 and _remaining > 0.0 and not _valid_marked_targets().is_empty():
		_resolve_chain_hit()
		_chain_remaining += _chain_interval
	if _remaining <= 0.0:
		_resolve_final_strikes()
		_finished = true
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"attack_type": "residual_chain_sky_strike",
		"marked_target_limit": _marked_target_limit,
		"marked_target_count": _valid_marked_targets().size(),
		"residual_duration": _residual_duration,
		"chain_interval": _chain_interval,
		"residual_damage": _residual_damage,
		"final_strike_damage": _final_strike_damage,
		"chain_hit_count": _chain_hit_count,
		"final_strike_count": _final_strike_count,
		"tier_rank": _tier_rank,
	}


func _capture_marks() -> void:
	_marked_refs.clear()
	var targets := _provider_targets()
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return _caster.global_position.distance_squared_to(a.global_position) < _caster.global_position.distance_squared_to(b.global_position)
	)
	for index in mini(_marked_target_limit, targets.size()):
		var target := targets[index]
		target.set_meta(&"residual_lightning", _residual_duration)
		_marked_refs.append(weakref(target))


func _provider_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var variant: Variant = _target_provider.call() if _target_provider.is_valid() else []
	if not variant is Array:
		return result
	for target_variant in variant as Array:
		if target_variant is Node2D and is_instance_valid(target_variant):
			result.append(target_variant as Node2D)
	return result


func _valid_marked_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for target_ref in _marked_refs:
		var target := target_ref.get_ref() as Node2D
		if target != null and is_instance_valid(target):
			result.append(target)
	return result


func _resolve_chain_hit() -> void:
	var targets := _valid_marked_targets()
	if targets.is_empty():
		return
	var target := targets[_chain_index % targets.size()]
	var from_position := _caster.global_position if _chain_index == 0 else ATTACK_GEOMETRY.target_center(targets[(_chain_index - 1 + targets.size()) % targets.size()])
	if _deal_damage(target, _residual_damage, from_position) > 0:
		_chain_hit_count += 1
		chain_hit.emit(from_position, target, ATTACK_GEOMETRY.target_center(target))
	_chain_index += 1


func _resolve_final_strikes() -> void:
	for target in _valid_marked_targets():
		if _deal_damage(target, _final_strike_damage, target.global_position + Vector2(0, -300)) > 0:
			_final_strike_count += 1
			final_strike.emit(target, ATTACK_GEOMETRY.target_center(target))
		target.remove_meta(&"residual_lightning")


func _deal_damage(target: Node2D, amount: int, source: Vector2) -> int:
	return TARGET_ADAPTER.deal_damage(target, amount, source, 40.0)
