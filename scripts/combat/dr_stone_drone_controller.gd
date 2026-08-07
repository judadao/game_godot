class_name DrStoneDroneController
extends Node

signal shot_fired(drone_index: int, origin: Vector2, target: Node, target_position: Vector2)
signal drone_crashed(drone_index: int, world_position: Vector2)

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

var _caster: Node2D
var _target_provider := Callable()
var _remaining: Array[float] = []
var _duration := 5.0
var _attack_interval := 0.65
var _attack_remaining := 0.12
var _attack_range := 300.0
var _damage_per_shot := 1
var _tier_rank := 1
var _refill_generation := 0
var _shot_count := 0
var _crashed_drone_count := 0
var _next_drone_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	_duration = maxf(0.5, float(profile.get("duration", 5.0)))
	_attack_interval = maxf(0.08, float(profile.get("attack_interval", 0.65)))
	_attack_remaining = minf(_attack_remaining, 0.12)
	_attack_range = maxf(96.0, float(profile.get("attack_range", 300.0)))
	_damage_per_shot = maxi(1, int(profile.get("damage_per_shot", 1)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	var desired_count := maxi(3, int(profile.get("drone_count", 3)))
	while _remaining.size() < desired_count:
		_remaining.append(0.0)
	for index in desired_count:
		_remaining[index] = _duration - float(index) * minf(0.12, _duration * 0.02)
	for index in range(desired_count, _remaining.size()):
		_remaining[index] = 0.0
	_refill_generation += 1
	_crashed_drone_count = 0
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster):
		return
	var safe_delta := maxf(0.0, delta)
	for index in _remaining.size():
		var before := _remaining[index]
		_remaining[index] = maxf(0.0, before - safe_delta)
		if before > 0.0 and _remaining[index] <= 0.0:
			_crashed_drone_count += 1
			drone_crashed.emit(index, _drone_world_position(index))
	_attack_remaining -= safe_delta
	while _attack_remaining <= 0.0 and _active_drone_count() > 0:
		_resolve_shot()
		_attack_remaining += _attack_interval
	if _active_drone_count() == 0:
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"squad_type": "persistent_stone_drone_squad",
		"drone_count": _remaining.size(),
		"active_drone_count": _active_drone_count(),
		"crashed_drone_count": _crashed_drone_count,
		"duration_seconds": _duration,
		"attack_interval": _attack_interval,
		"attack_range": _attack_range,
		"damage_per_shot": _damage_per_shot,
		"tier_rank": _tier_rank,
		"refill_generation": _refill_generation,
		"shot_count": _shot_count,
	}


func _active_drone_count() -> int:
	var count := 0
	for remaining in _remaining:
		if remaining > 0.0:
			count += 1
	return count


func _resolve_shot() -> void:
	var target := _nearest_target()
	if target == null:
		return
	var drone_index := _next_active_drone_index()
	if drone_index < 0:
		return
	var origin := _drone_world_position(drone_index)
	var dealt := 0
	if target.has_method("take_hit"):
		dealt = int(target.call("take_hit", _damage_per_shot, origin, 45.0))
	elif target.has_method("take_damage"):
		dealt = int(target.call("take_damage", _damage_per_shot))
	if dealt <= 0:
		return
	_shot_count += 1
	shot_fired.emit(drone_index, origin, target, ATTACK_GEOMETRY.target_center(target))


func _nearest_target() -> Node2D:
	if not _target_provider.is_valid():
		return null
	var targets_variant: Variant = _target_provider.call()
	if not targets_variant is Array:
		return null
	var nearest: Node2D
	var nearest_distance := _attack_range * _attack_range
	for target_variant in targets_variant as Array:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var target := target_variant as Node2D
		var distance := _caster.global_position.distance_squared_to(ATTACK_GEOMETRY.target_center(target))
		if distance <= nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _next_active_drone_index() -> int:
	for offset in _remaining.size():
		var index := (_next_drone_index + offset) % _remaining.size()
		if _remaining[index] > 0.0:
			_next_drone_index = (index + 1) % _remaining.size()
			return index
	return -1


func _drone_world_position(index: int) -> Vector2:
	var count := maxi(1, _remaining.size())
	var angle := TAU * float(index) / float(count)
	var local_offset := Vector2(cos(angle) * (90.0 + count * 3.0), -92.0 + sin(angle) * 34.0)
	return _caster.global_position + local_offset
