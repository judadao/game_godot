class_name FeatherHaloDamageController
extends Node

signal contact_hit(target: Node, world_position: Vector2, damage: int)

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

var _caster: Node2D
var _target_provider := Callable()
var _duration := 0.0
var _remaining := 0.0
var _radius := 176.0
var _tick_interval := 0.18
var _tick_remaining := 0.05
var _damage_per_tick := 1
var _knockback := 105.0
var _feather_count := 3
var _center_offset := Vector2(0.0, -54.0)
var _tick_count := 0
var _hit_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(caster: Node2D, target_provider: Callable, profile: Dictionary) -> bool:
	if caster == null or not target_provider.is_valid():
		return false
	_caster = caster
	_target_provider = target_provider
	_duration = maxf(0.1, float(profile.get("duration", 4.8)))
	_remaining = _duration
	_radius = maxf(32.0, float(profile.get("radius", 176.0)))
	_tick_interval = maxf(0.08, float(profile.get("tick_interval", 0.18)))
	_tick_remaining = minf(_tick_remaining, 0.05)
	_damage_per_tick = maxi(1, int(profile.get("damage_per_tick", 1)))
	_knockback = maxf(0.0, float(profile.get("knockback", 105.0)))
	_feather_count = maxi(1, int(profile.get("feather_count", 3)))
	_center_offset = profile.get("center_offset", Vector2(0.0, -54.0)) as Vector2
	set_process(true)
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _remaining <= 0.0 or _caster == null or not is_instance_valid(_caster):
		return
	var safe_delta := maxf(0.0, delta)
	_remaining = maxf(0.0, _remaining - safe_delta)
	_tick_remaining -= safe_delta
	while _tick_remaining <= 0.0 and _remaining > 0.0:
		_resolve_contact_tick()
		_tick_remaining += _tick_interval
	if _remaining <= 0.0:
		set_process(false)


func get_debug_state() -> Dictionary:
	return {
		"attack_mode": "orbit_contact",
		"duration_seconds": _duration,
		"remaining_seconds": _remaining,
		"radius": _radius,
		"tick_interval": _tick_interval,
		"damage_per_tick": _damage_per_tick,
		"knockback": _knockback,
		"feather_count": _feather_count,
		"center_offset": _center_offset,
		"tick_count": _tick_count,
		"hit_count": _hit_count,
	}


func _resolve_contact_tick() -> void:
	if not _target_provider.is_valid():
		return
	_tick_count += 1
	var field_center := _caster.global_position + _center_offset
	var targets_variant: Variant = _target_provider.call()
	if not targets_variant is Array:
		return
	var emitted_contacts := 0
	for target_variant in targets_variant as Array:
		if not target_variant is Node2D:
			continue
		var target := target_variant as Node2D
		if not is_instance_valid(target):
			continue
		if not ATTACK_GEOMETRY.radial_contains(
			field_center,
			ATTACK_GEOMETRY.target_center(target),
			ATTACK_GEOMETRY.target_radius(target),
			_radius
		):
			continue
		var dealt := 0
		if target.has_method("take_hit"):
			dealt = int(target.call(
				"take_hit", _damage_per_tick, field_center, _knockback
			))
		elif target.has_method("take_damage"):
			dealt = int(target.call("take_damage", _damage_per_tick))
		if dealt <= 0:
			continue
		_hit_count += 1
		if emitted_contacts < 3:
			contact_hit.emit(target, ATTACK_GEOMETRY.target_center(target), dealt)
			emitted_contacts += 1
