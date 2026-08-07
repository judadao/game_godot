class_name FirePillarFieldController
extends Node2D

signal pillar_warning(index: int, world_position: Vector2)
signal pillar_erupted(index: int, world_position: Vector2)
signal impact(target: Node, world_position: Vector2, damage: int)
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")

var _caster: Node2D
var _target_provider := Callable()
var _pillar_count := 5
var _field_radius := 360.0
var _eruption_interval := 0.18
var _damage_per_pillar := 1
var _tier_rank := 1
var _elapsed := 0.0
var _erupted_count := 0
var _positions: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	global_position = caster.global_position
	_pillar_count = maxi(5, int(profile.get("pillar_count", 5)))
	_field_radius = maxf(120.0, float(profile.get("field_radius", 360.0)))
	_eruption_interval = maxf(0.08, float(profile.get("eruption_interval", 0.18)))
	_damage_per_pillar = maxi(1, int(profile.get("damage_per_pillar", 1)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_rng.seed = int(profile.get("random_seed", Time.get_ticks_usec()))
	_elapsed = 0.0
	_erupted_count = 0
	_positions = _build_discontinuous_positions()
	for index in _positions.size():
		pillar_warning.emit(index, _positions[index])
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _erupted_count >= _pillar_count:
		return
	_elapsed += maxf(0.0, delta)
	while _erupted_count < _pillar_count and _elapsed >= _eruption_interval * float(_erupted_count + 1):
		_erupt(_erupted_count)
		_erupted_count += 1
	if _erupted_count >= _pillar_count:
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"field_type": "staggered_fire_pillars",
		"pillar_count": _pillar_count,
		"erupted_count": _erupted_count,
		"eruption_interval": _eruption_interval,
		"field_radius": _field_radius,
		"tier_rank": _tier_rank,
		"eruption_positions": _positions.duplicate(),
	}


func _build_discontinuous_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var targets := _valid_targets()
	for index in _pillar_count:
		var anchor := _caster.global_position
		if not targets.is_empty():
			anchor = ATTACK_GEOMETRY.target_center(targets[index % targets.size()])
		var lane := float(index % 5) - 2.0
		var jitter := Vector2(_rng.randf_range(-55.0, 55.0), _rng.randf_range(-8.0, 8.0))
		var candidate := anchor + Vector2(lane * 72.0, 0.0) + jitter
		var offset := candidate - _caster.global_position
		if offset.length() > _field_radius:
			candidate = _caster.global_position + offset.normalized() * _field_radius
		positions.append(candidate)
	return positions


func _valid_targets() -> Array[Node2D]:
	var resolved: Array[Node2D] = []
	var variant: Variant = _target_provider.call() if _target_provider.is_valid() else []
	if not variant is Array:
		return resolved
	for target_variant in variant as Array:
		if target_variant is Node2D and is_instance_valid(target_variant):
			resolved.append(target_variant as Node2D)
	return resolved


func _erupt(index: int) -> void:
	var world_position := _positions[index]
	pillar_erupted.emit(index, world_position)
	for target in _valid_targets():
		if world_position.distance_to(ATTACK_GEOMETRY.target_center(target)) > 112.0:
			continue
		var dealt := _deal_damage(target, world_position)
		if dealt > 0:
			impact.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)


func _deal_damage(target: Node2D, source: Vector2) -> int:
	return TARGET_ADAPTER.deal_damage(target, _damage_per_pillar, source, 75.0)
