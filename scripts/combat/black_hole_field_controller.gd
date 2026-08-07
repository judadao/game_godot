class_name BlackHoleFieldController
extends Node2D

signal tick_hit(target: Node, world_position: Vector2, damage: int)
signal detonated(world_position: Vector2, hit_count: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")

var _target_provider := Callable()
var _duration := 2.4
var _remaining := 0.0
var _radius := 180.0
var _tick_interval := 0.24
var _tick_remaining := 0.05
var _damage_per_tick := 1
var _burst_damage := 1
var _pull_strength := 90.0
var _burst_knockback := 80.0
var _tier_rank := 1
var _tick_count := 0
var _tick_hit_count := 0
var _burst_hit_count := 0
var _detonated := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(center: Vector2, target_provider: Callable, profile: Dictionary) -> bool:
	if not target_provider.is_valid():
		return false
	global_position = center
	_target_provider = target_provider
	_duration = maxf(0.1, float(profile.get("duration", 2.4)))
	_remaining = _duration
	_radius = maxf(48.0, float(profile.get("radius", 180.0)))
	_tick_interval = maxf(0.08, float(profile.get("tick_interval", 0.24)))
	_tick_remaining = minf(_tick_interval, 0.05)
	_damage_per_tick = maxi(1, int(profile.get("damage_per_tick", 1)))
	_burst_damage = maxi(_damage_per_tick, int(profile.get("burst_damage", 1)))
	_pull_strength = maxf(0.0, float(profile.get("pull_strength", 90.0)))
	_burst_knockback = maxf(0.0, float(profile.get("burst_knockback", 80.0)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_tick_count = 0
	_tick_hit_count = 0
	_burst_hit_count = 0
	_detonated = false
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _remaining <= 0.0 or _detonated:
		return
	var safe_delta := maxf(0.0, delta)
	_apply_pull()
	_remaining = maxf(0.0, _remaining - safe_delta)
	_tick_remaining -= safe_delta
	while _tick_remaining <= 0.0 and _remaining > 0.0:
		_resolve_damage_tick()
		_tick_remaining += _tick_interval
	if _remaining <= 0.0:
		_resolve_detonation()


func get_debug_state() -> Dictionary:
	return {
		"field_type": "singularity_pull_detonation",
		"duration_seconds": _duration,
		"remaining_seconds": _remaining,
		"radius": _radius,
		"tick_interval": _tick_interval,
		"damage_per_tick": _damage_per_tick,
		"burst_damage": _burst_damage,
		"pull_strength": _pull_strength,
		"tier_rank": _tier_rank,
		"tick_count": _tick_count,
		"tick_hit_count": _tick_hit_count,
		"burst_hit_count": _burst_hit_count,
		"detonated": _detonated,
	}


static func resolve_cast_center(caster: Node2D, targets: Array, placement_range: float = 320.0) -> Vector2:
	if caster == null:
		return Vector2.ZERO
	var center := caster.global_position
	var nearest_distance := INF
	for target_variant in targets:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var target := target_variant as Node2D
		var target_center := ATTACK_GEOMETRY.target_center(target)
		var distance := caster.global_position.distance_squared_to(target_center)
		if distance < nearest_distance:
			nearest_distance = distance
			center = target_center
	var displacement := center - caster.global_position
	var safe_range := maxf(48.0, placement_range)
	if displacement.length() > safe_range:
		center = caster.global_position + displacement.normalized() * safe_range
	return center


func _targets_inside() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not _target_provider.is_valid():
		return result
	var targets_variant: Variant = _target_provider.call()
	if not targets_variant is Array:
		return result
	for target_variant in targets_variant as Array:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var target := target_variant as Node2D
		if ATTACK_GEOMETRY.radial_contains(
			global_position,
			ATTACK_GEOMETRY.target_center(target),
			ATTACK_GEOMETRY.target_radius(target),
			_radius
		):
			result.append(target)
	return result


func _apply_pull() -> void:
	for target in _targets_inside():
		var displacement := global_position - ATTACK_GEOMETRY.target_center(target)
		if displacement.length_squared() <= 4.0:
			continue
		if target is CharacterBody2D:
			(target as CharacterBody2D).velocity = displacement.normalized() * _pull_strength
		elif target.has_method("apply_external_pull"):
			target.call("apply_external_pull", global_position, _pull_strength, _tick_interval)


func _resolve_damage_tick() -> void:
	_tick_count += 1
	var emitted := 0
	for target in _targets_inside():
		var dealt := _damage_target(target, _damage_per_tick, 0.0)
		if dealt <= 0:
			continue
		_tick_hit_count += 1
		if emitted < 4:
			tick_hit.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)
			emitted += 1


func _resolve_detonation() -> void:
	if _detonated:
		return
	_detonated = true
	for target in _targets_inside():
		if _damage_target(target, _burst_damage, _burst_knockback) > 0:
			_burst_hit_count += 1
	detonated.emit(global_position, _burst_hit_count)
	completed.emit()
	set_process(false)


func _damage_target(target: Node2D, amount: int, knockback: float) -> int:
	return TARGET_ADAPTER.deal_damage(target, amount, global_position, knockback)
