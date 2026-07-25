class_name ComboManager
extends RefCounted

const COMBO_RULES: Array[Dictionary] = [
	{"id": "ember_chain", "name": "Ember Chain", "description": "Play two Fire cards.", "pattern": ["tag:fire", "tag:fire"]},
	{"id": "blade_dance", "name": "Blade Dance", "description": "Play three Strike cards.", "pattern": ["tag:strike", "tag:strike", "tag:strike"]},
	{"id": "bulwark", "name": "Bulwark", "description": "Play two Defense cards.", "pattern": ["type:defense", "type:defense"]},
	{"id": "storm_step", "name": "Storm Step", "description": "Play Mobility then Attack.", "pattern": ["tag:mobility", "type:attack"]},
	{"id": "arcane_cycle", "name": "Arcane Cycle", "description": "Play Status, Skill, then Power.", "pattern": ["type:status", "type:skill", "type:power"]},
]

var _history: Array[Dictionary] = []
var _triggered_rule_ids: Dictionary = {}


func record_card(card: Dictionary) -> Array[Dictionary]:
	if card.is_empty():
		return []
	_history.append(card.duplicate(true))
	if _history.size() > 3:
		_history.pop_front()
	var triggered: Array[Dictionary] = []
	for rule in COMBO_RULES:
		var rule_id := String(rule["id"])
		if not _triggered_rule_ids.has(rule_id) and _matches(rule["pattern"] as Array):
			_triggered_rule_ids[rule_id] = true
			triggered.append(rule.duplicate(true))
	return triggered


func get_rules() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule in COMBO_RULES:
		result.append(rule.duplicate(true))
	return result


func reset() -> void:
	_history.clear()
	_triggered_rule_ids.clear()


func _matches(pattern: Array) -> bool:
	if _history.size() < pattern.size():
		return false
	var offset := _history.size() - pattern.size()
	for index in pattern.size():
		var card := _history[offset + index]
		var token := String(pattern[index])
		var separator := token.find(":")
		if separator <= 0:
			return false
		var field := token.left(separator)
		var expected := token.substr(separator + 1)
		if field == "type":
			if String(card.get("type", "")) != expected:
				return false
		elif field == "tag":
			var tags := card.get("combo_tags", card.get("tags", [])) as Array
			if not tags.has(expected):
				return false
		else:
			return false
	return true
