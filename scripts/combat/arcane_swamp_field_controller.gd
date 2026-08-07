class_name ArcaneSwampFieldController
extends Node2D

signal pulse_hit(target: Node, world_position: Vector2, damage: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

var _target_provider := Callable()
var _duration := 3.0
var _remaining := 0.0
var _radius := 260.0
var _tick_interval := 0.32
var _tick_remaining := 0.05
var _damage_per_tick := 1
var _target_limit := 10
var _tier_rank := 1
var _entangled_refs: Array[WeakRef] = []
var _pulse_count := 0
var _pulse_hit_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(center: Vector2, target_provider: Callable, profile: Dictionary) -> bool:
	if not target_provider.is_valid():
		return false
	global_position = center
	_target_provider = target_provider
	_duration = maxf(0.2, float(profile.get("duration", 3.0)))
	_remaining = _duration
	_radius = maxf(48.0, float(profile.get("radius", 260.0)))
	_tick_interval = maxf(0.08, float(profile.get("tick_interval", 0.32)))
	_tick_remaining = minf(0.05, _tick_interval)
	_damage_per_tick = maxi(1, int(profile.get("damage_per_tick", 1)))
	_target_limit = maxi(10, int(profile.get("target_limit", 10)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_pulse_count = 0
	_pulse_hit_count = 0
	_capture_targets()
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _remaining <= 0.0:
		return
	var safe_delta := maxf(0.0, delta)
	_hold_entangled_targets()
	_remaining = maxf(0.0, _remaining - safe_delta)
	_tick_remaining -= safe_delta
	while _tick_remaining <= 0.0 and _remaining > 0.0:
		_resolve_pulse()
		_tick_remaining += _tick_interval
	if _remaining <= 0.0:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"field_type": "arcane_swamp_entanglement",
		"duration_seconds": _duration,
		"remaining_seconds": _remaining,
		"radius": _radius,
		"tick_interval": _tick_interval,
		"damage_per_tick": _damage_per_tick,
		"target_limit": _target_limit,
		"tier_rank": _tier_rank,
		"entangled_count": _valid_entangled_targets().size(),
		"pulse_count": _pulse_count,
		"pulse_hit_count": _pulse_hit_count,
	}


func _capture_targets() -> void:
	_entangled_refs.clear()
	if not _target_provider.is_valid():
		return
	var targets_variant: Variant = _target_provider.call()
	if not targets_variant is Array:
		return
	var candidates: Array[Node2D] = []
	for target_variant in targets_variant as Array:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var target := target_variant as Node2D
		if ATTACK_GEOMETRY.radial_contains(global_position, ATTACK_GEOMETRY.target_center(target), ATTACK_GEOMETRY.target_radius(target), _radius):
			candidates.append(target)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	for index in mini(_target_limit, candidates.size()):
		var target := candidates[index]
		_entangled_refs.append(weakref(target))
		if target.has_method("apply_status"):
			target.call("apply_status", "arcane_swamp_entangled", {
				"duration": _duration,
				"movement_multiplier": 0.0,
				"tier_rank": _tier_rank,
			})


func _valid_entangled_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for target_ref in _entangled_refs:
		var target := target_ref.get_ref() as Node2D
		if target != null and is_instance_valid(target):
			targets.append(target)
	return targets


func _hold_entangled_targets() -> void:
	for target in _valid_entangled_targets():
		if target is CharacterBody2D:
			(target as CharacterBody2D).velocity = Vector2.ZERO
		elif target.has_method("apply_movement_lock"):
			target.call("apply_movement_lock", _tick_interval)


func _resolve_pulse() -> void:
	_pulse_count += 1
	var emitted := 0
	for target in _valid_entangled_targets():
		var dealt := 0
		if target.has_method("take_hit"):
			dealt = int(target.call("take_hit", _damage_per_tick, global_position, 0.0))
		elif target.has_method("take_damage"):
			dealt = int(target.call("take_damage", _damage_per_tick))
		if dealt <= 0:
			continue
		_pulse_hit_count += 1
		if emitted < 5:
			pulse_hit.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)
			emitted += 1
