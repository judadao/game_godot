class_name ThornBloomFieldController
extends Node2D

signal volley_fired(origin: Vector2, target_positions: Array[Vector2])
signal completed()

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")

var _target_provider := Callable()
var _duration := 2.4
var _elapsed := 0.0
var _radius := 180.0
var _emerge_duration := 0.45
var _bloom_delay := 0.70
var _volley_interval := 0.42
var _next_volley_time := 1.15
var _thorn_count := 3
var _spikes_per_volley := 3
var _damage_per_spike := 1
var _knockback := 35.0
var _tier_rank := 1
var _volley_count := 0
var _spike_hit_count := 0
var _completed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(center: Vector2, target_provider: Callable, profile: Dictionary) -> bool:
	if not target_provider.is_valid():
		return false
	global_position = center
	_target_provider = target_provider
	_duration = maxf(0.2, float(profile.get("duration", 2.4)))
	_elapsed = 0.0
	_radius = maxf(48.0, float(profile.get("radius", 180.0)))
	_emerge_duration = maxf(0.05, float(profile.get("emerge_duration", 0.45)))
	_bloom_delay = maxf(0.05, float(profile.get("bloom_delay", 0.70)))
	_volley_interval = maxf(0.08, float(profile.get("volley_interval", 0.42)))
	_next_volley_time = _emerge_duration + _bloom_delay
	_thorn_count = maxi(1, int(profile.get("thorn_count", 3)))
	_spikes_per_volley = maxi(1, int(profile.get("spikes_per_volley", _thorn_count)))
	_damage_per_spike = maxi(1, int(profile.get("damage_per_spike", 1)))
	_knockback = maxf(0.0, float(profile.get("knockback", 35.0)))
	_tier_rank = clampi(int(profile.get("tier_rank", 1)), 1, 3)
	_volley_count = 0
	_spike_hit_count = 0
	_completed = false
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _completed:
		return
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	while _elapsed >= _next_volley_time and _next_volley_time < _duration:
		_resolve_volley()
		_next_volley_time += _volley_interval
	if _elapsed >= _duration:
		_completed = true
		completed.emit()
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"field_type": "blooming_thorn_barrage",
		"duration_seconds": _duration,
		"elapsed_seconds": _elapsed,
		"radius": _radius,
		"emerge_duration": _emerge_duration,
		"bloom_delay": _bloom_delay,
		"volley_interval": _volley_interval,
		"thorn_count": _thorn_count,
		"spikes_per_volley": _spikes_per_volley,
		"damage_per_spike": _damage_per_spike,
		"tier_rank": _tier_rank,
		"volley_count": _volley_count,
		"spike_hit_count": _spike_hit_count,
		"completed": _completed,
	}


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
		if ATTACK_GEOMETRY.radial_contains(global_position, ATTACK_GEOMETRY.target_center(target), ATTACK_GEOMETRY.target_radius(target), _radius):
			result.append(target)
	result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return result


func _resolve_volley() -> void:
	_volley_count += 1
	var targets := _targets_inside()
	if targets.is_empty():
		return
	var target_positions: Array[Vector2] = []
	for spike_index in _spikes_per_volley:
		var target := targets[spike_index % targets.size()]
		var dealt := TARGET_ADAPTER.deal_damage(
			target, _damage_per_spike, global_position, _knockback
		)
		if dealt > 0:
			_spike_hit_count += 1
			target_positions.append(ATTACK_GEOMETRY.target_center(target))
	volley_fired.emit(global_position, target_positions)
