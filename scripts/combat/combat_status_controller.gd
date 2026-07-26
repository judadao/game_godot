class_name CombatStatusController
extends Node

signal statuses_changed(snapshot: Dictionary)
signal regeneration_pulsed(source_id: StringName, restored: int)

const MAX_DAMAGE_REDUCTION := 0.60

var _armor_by_source: Dictionary = {}
var _reduction_by_source: Dictionary = {}
var _retaliation_by_source: Dictionary = {}
var _regeneration_by_source: Dictionary = {}
var _lifesteal_by_source: Dictionary = {}


func apply_armor(source_id: StringName, tier: int, duration: float) -> void:
	_set_timed_status(_armor_by_source, source_id, {
		"tier": maxi(0, tier),
		"remaining": maxf(0.0, duration),
	})


func apply_reduction(source_id: StringName, ratio: float, duration: float) -> void:
	_set_timed_status(_reduction_by_source, source_id, {
		"ratio": clampf(ratio, 0.0, MAX_DAMAGE_REDUCTION),
		"remaining": maxf(0.0, duration),
	})


func apply_retaliation(source_id: StringName, amount: int, ratio: float, duration: float) -> void:
	_set_timed_status(_retaliation_by_source, source_id, {
		"amount": maxi(0, amount),
		"ratio": maxf(0.0, ratio),
		"remaining": maxf(0.0, duration),
	})


func apply_regeneration(source_id: StringName, amount: int, interval: float, duration: float) -> void:
	var pulse_interval := maxf(0.01, interval)
	_set_timed_status(_regeneration_by_source, source_id, {
		"amount": maxi(0, amount),
		"interval": pulse_interval,
		"pulse_remaining": pulse_interval,
		"remaining": maxf(0.0, duration),
	})


func apply_lifesteal(source_id: StringName, ratio: float, duration: float) -> void:
	_set_timed_status(_lifesteal_by_source, source_id, {
		"ratio": maxf(0.0, ratio),
		"remaining": maxf(0.0, duration),
	})


func apply_effect(source_id: StringName, kind: String, effect: Dictionary) -> bool:
	var duration := maxf(0.0, float(effect.get("duration", effect.get("seconds", 0.0))))
	match kind:
		"armor", "super_armor":
			apply_armor(source_id, int(effect.get("tier", effect.get("armor_tier", 1))), duration)
		"reduction", "damage_reduction":
			apply_reduction(source_id, float(effect.get("ratio", effect.get("damage_reduction", 0.0))), duration)
		"retaliation":
			apply_retaliation(
				source_id,
				int(effect.get("amount", effect.get("retaliation_damage", 0))),
				float(effect.get("ratio", effect.get("retaliation_ratio", 0.0))),
				duration
			)
		"regeneration":
			apply_regeneration(
				source_id,
				int(effect.get("amount", effect.get("heal", 0))),
				float(effect.get("interval", effect.get("pulse_interval", 1.0))),
				duration
			)
		"lifesteal":
			apply_lifesteal(source_id, float(effect.get("ratio", effect.get("lifesteal_ratio", 0.0))), duration)
		"fortress":
			apply_armor(source_id, int(effect.get("tier", 2)), duration)
			apply_reduction(source_id, float(effect.get("ratio", 0.0)), duration)
		"counterguard":
			apply_reduction(source_id, float(effect.get("ratio", 0.0)), duration)
			apply_retaliation(
				source_id,
				int(effect.get("retaliation_damage", effect.get("amount", 0))),
				float(effect.get("retaliation_ratio", 0.0)),
				duration
			)
		_:
			return false
	return true


func resolve_incoming_damage(raw_damage: int, unblockable: bool = false) -> Dictionary:
	var incoming := maxi(0, raw_damage)
	var reduction := 0.0 if unblockable else get_damage_reduction()
	var armor_tier := 0 if unblockable else get_strongest_armor_tier()
	var applied := int(ceil(float(incoming) * (1.0 - reduction)))
	if incoming > 0:
		applied = maxi(1, applied)
	return {
		"damage": applied,
		"reduction": reduction,
		"armor_tier": armor_tier,
		"prevents_knockback": armor_tier > 0,
		"retaliation_damage": _get_retaliation_damage(applied),
	}


func get_damage_reduction() -> float:
	var total := 0.0
	for data in _reduction_by_source.values():
		total += float((data as Dictionary).get("ratio", 0.0))
	return clampf(total, 0.0, MAX_DAMAGE_REDUCTION)


func get_strongest_armor_tier() -> int:
	var tier := 0
	for data in _armor_by_source.values():
		tier = maxi(tier, int((data as Dictionary).get("tier", 0)))
	return tier


func restore_from_damage(damage_dealt: int) -> int:
	if damage_dealt <= 0:
		return 0
	var ratio := 0.0
	for data in _lifesteal_by_source.values():
		ratio += float((data as Dictionary).get("ratio", 0.0))
	return _restore_health(int(round(float(damage_dealt) * ratio)))


func tick(delta: float, paused: bool = false) -> void:
	if paused or delta <= 0.0:
		return
	_tick_regeneration(delta)
	_tick_timed_statuses(_armor_by_source, delta)
	_tick_timed_statuses(_reduction_by_source, delta)
	_tick_timed_statuses(_retaliation_by_source, delta)
	_tick_timed_statuses(_lifesteal_by_source, delta)
	_emit_statuses_changed()


func get_status_snapshot() -> Dictionary:
	return {
		"armor_tier": get_strongest_armor_tier(),
		"damage_reduction": get_damage_reduction(),
		"armor_sources": _armor_by_source.duplicate(true),
		"reduction_sources": _reduction_by_source.duplicate(true),
		"retaliation_sources": _retaliation_by_source.duplicate(true),
		"regeneration_sources": _regeneration_by_source.duplicate(true),
		"lifesteal_sources": _lifesteal_by_source.duplicate(true),
	}


func _set_timed_status(statuses: Dictionary, source_id: StringName, data: Dictionary) -> void:
	if source_id.is_empty() or float(data.get("remaining", 0.0)) <= 0.0:
		return
	statuses[source_id] = data
	_emit_statuses_changed()


func _tick_regeneration(delta: float) -> void:
	for source_id in _regeneration_by_source.keys():
		var data := _regeneration_by_source[source_id] as Dictionary
		var active_delta := minf(delta, float(data.get("remaining", 0.0)))
		var interval := float(data.get("interval", 1.0))
		var pulse_remaining := float(data.get("pulse_remaining", interval)) - active_delta
		while pulse_remaining <= 0.0:
			var restored := _restore_health(int(data.get("amount", 0)))
			regeneration_pulsed.emit(StringName(source_id), restored)
			pulse_remaining += interval
		data["pulse_remaining"] = pulse_remaining
		data["remaining"] = float(data.get("remaining", 0.0)) - delta
		if float(data["remaining"]) <= 0.0:
			_regeneration_by_source.erase(source_id)


func _tick_timed_statuses(statuses: Dictionary, delta: float) -> void:
	for source_id in statuses.keys():
		var data := statuses[source_id] as Dictionary
		data["remaining"] = float(data.get("remaining", 0.0)) - delta
		if float(data["remaining"]) <= 0.0:
			statuses.erase(source_id)


func _get_retaliation_damage(damage_taken: int) -> int:
	if damage_taken <= 0:
		return 0
	var retaliation := 0
	for data in _retaliation_by_source.values():
		var status := data as Dictionary
		retaliation += int(status.get("amount", 0))
		retaliation += int(round(float(damage_taken) * float(status.get("ratio", 0.0))))
	return retaliation


func _restore_health(amount: int) -> int:
	var owner := get_parent()
	if amount <= 0 or owner == null or not owner.has_method("restore_health"):
		return 0
	return int(owner.call("restore_health", amount))


func _emit_statuses_changed() -> void:
	statuses_changed.emit(get_status_snapshot())
