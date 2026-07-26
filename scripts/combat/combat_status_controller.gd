class_name CombatStatusController
extends Node

signal statuses_changed(projection: Array)
signal retaliation_requested(source: Node, amount: int)

const MAX_DAMAGE_REDUCTION := 0.60

var _statuses: Dictionary = {}
var _timers_paused := false


func _process(delta: float) -> void:
	advance(delta)


func set_timers_paused(is_paused: bool) -> void:
	_timers_paused = is_paused


func are_timers_paused() -> bool:
	return _timers_paused


func advance(delta: float) -> void:
	if _timers_paused or delta <= 0.0:
		return
	var changed := false
	for key in _statuses.keys():
		var status := _statuses[key] as Dictionary
		var remaining := maxf(0.0, float(status.get("remaining_seconds", 0.0)) - delta)
		status["remaining_seconds"] = remaining
		if String(status.get("status_id", "")) == "regeneration":
			_tick_regeneration(status, delta)
		if remaining <= 0.0:
			_statuses.erase(key)
		changed = true
	if changed or not _statuses.is_empty():
		statuses_changed.emit(get_status_projection())


func apply_super_armor(source_id: String, tier: int, duration: float, display_name: String) -> void:
	_apply_status("super_armor", source_id, display_name, duration, {
		"tier": clampi(tier, 1, 2),
	})


func apply_damage_reduction(
	source_id: String,
	ratio: float,
	duration: float,
	display_name: String
) -> void:
	_apply_status("damage_reduction", source_id, display_name, duration, {
		"ratio": clampf(ratio, 0.0, MAX_DAMAGE_REDUCTION),
	})


func apply_lifesteal(source_id: String, ratio: float, duration: float, display_name: String) -> void:
	_apply_status("lifesteal", source_id, display_name, duration, {
		"ratio": clampf(ratio, 0.0, 1.0),
	})


func apply_retaliation(source_id: String, amount: int, duration: float, display_name: String) -> void:
	_apply_status("retaliation", source_id, display_name, duration, {
		"amount": maxi(0, amount),
	})


func apply_regeneration(
	source_id: String,
	amount: int,
	pulses: int,
	interval: float,
	display_name: String
) -> void:
	var safe_interval := maxf(0.05, interval)
	var safe_pulses := maxi(1, pulses)
	_apply_status("regeneration", source_id, display_name, safe_interval * float(safe_pulses), {
		"amount": maxi(0, amount),
		"pulses_remaining": safe_pulses,
		"tick_interval": safe_interval,
		"tick_remaining": safe_interval,
	})


func apply_effect(source_id: String, display_name: String, effect: Dictionary) -> bool:
	var applied := false
	var raw_statuses: Variant = effect.get("statuses", [])
	if raw_statuses is Array:
		for raw_status in raw_statuses:
			if raw_status is Dictionary:
				applied = _apply_effect_status(source_id, display_name, raw_status as Dictionary) or applied
	if String(effect.get("kind", "")) in ["combat_status", "regeneration", "healing_pulses"]:
		applied = _apply_effect_status(source_id, display_name, effect) or applied
	return applied


func get_damage_reduction() -> float:
	var total := 0.0
	for status in _statuses.values():
		var entry := status as Dictionary
		if String(entry.get("status_id", "")) == "damage_reduction":
			total += float(entry.get("ratio", 0.0))
	return minf(total, MAX_DAMAGE_REDUCTION)


func get_super_armor_tier() -> int:
	var strongest := 0
	for status in _statuses.values():
		var entry := status as Dictionary
		if String(entry.get("status_id", "")) == "super_armor":
			strongest = maxi(strongest, int(entry.get("tier", 0)))
	return strongest


func get_lifesteal_ratio() -> float:
	var strongest := 0.0
	for status in _statuses.values():
		var entry := status as Dictionary
		if String(entry.get("status_id", "")) == "lifesteal":
			strongest = maxf(strongest, float(entry.get("ratio", 0.0)))
	return strongest


func get_retaliation_damage() -> int:
	var strongest := 0
	for status in _statuses.values():
		var entry := status as Dictionary
		if String(entry.get("status_id", "")) == "retaliation":
			strongest = maxi(strongest, int(entry.get("amount", 0)))
	return strongest


func get_status_projection() -> Array[Dictionary]:
	var projection: Array[Dictionary] = []
	for status in _statuses.values():
		var entry := (status as Dictionary).duplicate(true)
		projection.append(entry)
	projection.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("source_id", "")) < String(b.get("source_id", ""))
	)
	return projection


func clear_all() -> void:
	if _statuses.is_empty():
		return
	_statuses.clear()
	statuses_changed.emit([])


func _apply_effect_status(source_id: String, display_name: String, status: Dictionary) -> bool:
	var status_id := String(status.get("status_id", status.get("kind", "")))
	var duration := float(status.get("duration", status.get("combo_duration", 0.0)))
	match status_id:
		"super_armor":
			apply_super_armor(source_id, int(status.get("tier", 1)), duration, display_name)
		"damage_reduction":
			apply_damage_reduction(source_id, float(status.get("ratio", 0.0)), duration, display_name)
		"lifesteal":
			apply_lifesteal(source_id, float(status.get("ratio", status.get("lifesteal_ratio", 0.0))), duration, display_name)
		"retaliation":
			apply_retaliation(source_id, int(status.get("amount", 0)), duration, display_name)
		"regeneration", "healing_pulses":
			apply_regeneration(
				source_id,
				int(status.get("amount", status.get("heal", 0))),
				int(status.get("pulses", 1)),
				float(status.get("interval", 1.0)),
				display_name
			)
		_:
			return false
	return true


func _apply_status(
	status_id: String,
	source_id: String,
	display_name: String,
	duration: float,
	values: Dictionary
) -> void:
	if source_id.is_empty() or duration <= 0.0:
		return
	var key := "%s::%s" % [status_id, source_id]
	var existing := _statuses.get(key, {}) as Dictionary
	var merged := values.duplicate(true)
	if not existing.is_empty():
		if values.has("ratio"):
			merged["ratio"] = maxf(float(existing.get("ratio", 0.0)), float(values["ratio"]))
		if values.has("tier"):
			merged["tier"] = maxi(int(existing.get("tier", 0)), int(values["tier"]))
		if values.has("amount") and status_id == "retaliation":
			merged["amount"] = maxi(int(existing.get("amount", 0)), int(values["amount"]))
	merged["status_id"] = status_id
	merged["source_id"] = source_id
	merged["name"] = display_name if not display_name.is_empty() else source_id.capitalize()
	merged["remaining_seconds"] = duration
	_statuses[key] = merged
	statuses_changed.emit(get_status_projection())


func _tick_regeneration(status: Dictionary, delta: float) -> void:
	var pulses_remaining := int(status.get("pulses_remaining", 0))
	if pulses_remaining <= 0:
		return
	var tick_remaining := float(status.get("tick_remaining", 0.0)) - delta
	var interval := maxf(0.05, float(status.get("tick_interval", 1.0)))
	while tick_remaining <= 0.0 and pulses_remaining > 0:
		var target := get_parent()
		if target != null and target.has_method("restore_health"):
			target.call("restore_health", int(status.get("amount", 0)))
		pulses_remaining -= 1
		tick_remaining += interval
	status["pulses_remaining"] = pulses_remaining
	status["tick_remaining"] = tick_remaining
