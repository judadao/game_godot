class_name GrowthChoiceQueue
extends RefCounted

signal queue_changed(pending_count: int)
signal choice_resolved(resolution: Dictionary)

const FALLBACK_REWARDS: Array[Dictionary] = [
	{"gold": 75},
	{"autumn_wood": 12, "stone": 8},
	{"magic_shard": 4},
]
const MAX_EXPERIENCE_CHOICES := 5

var _entries: Array[Dictionary] = []
var _next_event_id := 1


func enqueue_wave_blessing(cards: Array[Dictionary]) -> bool:
	if cards.is_empty():
		return false
	var event_id := _claim_event_id()
	var choices: Array[Dictionary] = []
	for index in cards.size():
		var card := cards[index]
		var card_id := String(card.get("card_id", card.get("id", "")))
		if card_id.is_empty():
			continue
		choices.append({
			"choice_id": "wave:%d:%d:%s" % [event_id, index, card_id],
			"action": "new_card",
			"card_id": card_id,
			"name": String(card.get("name", card_id)),
			"description": String(card.get("description", "")),
			"type": String(card.get("type", "")),
			"cost": int(card.get("cost", 0)),
			"icon_path": String(card.get("icon_path", "")),
			"card_color": String(card.get("card_color", "")),
		})
	if choices.is_empty():
		return false
	_entries.append(_make_entry(event_id, "wave", choices))
	queue_changed.emit(_entries.size())
	return true


func enqueue_experience_growth(upgrades: Array[Dictionary], fusions: Array[Dictionary]) -> bool:
	var event_id := _claim_event_id()
	var choices: Array[Dictionary] = []
	var seen_choice_ids: Dictionary = {}
	var upgrade_choices: Array[Dictionary] = []
	for upgrade in upgrades:
		var instance_id := String(upgrade.get("instance_id", ""))
		if instance_id.is_empty() or int(upgrade.get("level", 0)) >= 3:
			continue
		_append_unique_choice(upgrade_choices, seen_choice_ids, {
			"choice_id": "exp:%d:upgrade:%s" % [event_id, instance_id],
			"action": "upgrade",
			"instance_id": instance_id,
			"card_id": String(upgrade.get("card_id", "")),
			"name": String(upgrade.get("name", "")),
			"level": int(upgrade.get("level", 1)),
			"type": String(upgrade.get("type", "")),
			"cost": int(upgrade.get("cost", 0)),
			"icon_path": String(upgrade.get("icon_path", "")),
			"card_color": String(upgrade.get("card_color", "")),
			"description": String(upgrade.get("description", "")),
			"upgrade_description": String(upgrade.get("upgrade_description", "")),
		})
	upgrade_choices.shuffle()
	for choice in upgrade_choices.slice(
		0,
		mini(MAX_EXPERIENCE_CHOICES, upgrade_choices.size())
	):
		choices.append(choice)
	if choices.is_empty():
		choices = _fusion_choices(event_id, fusions)
	if choices.is_empty():
		for index in FALLBACK_REWARDS.size():
			choices.append({
				"choice_id": "exp:%d:fallback:%d" % [event_id, index],
				"action": "fallback",
				"reward": FALLBACK_REWARDS[index].duplicate(true),
			})
	_entries.append(_make_entry(event_id, "experience", choices))
	queue_changed.emit(_entries.size())
	return true


func enqueue_optional_fusions(fusions: Array[Dictionary]) -> bool:
	var event_id := _claim_event_id()
	var choices := _fusion_choices(event_id, fusions)
	if choices.is_empty():
		return false
	_entries.append(_make_entry(event_id, "fusion_followup", choices))
	queue_changed.emit(_entries.size())
	return true


func peek() -> Dictionary:
	if _entries.is_empty():
		return {}
	return _entries[0].duplicate(true)


func resolve(choice_id: String) -> Dictionary:
	if _entries.is_empty() or choice_id.is_empty():
		return {}
	var entry := _entries[0]
	for choice_variant in entry.get("choices", []) as Array:
		var choice := choice_variant as Dictionary
		if String(choice.get("choice_id", "")) != choice_id:
			continue
		var resolution := choice.duplicate(true)
		resolution["event_id"] = int(entry.get("event_id", 0))
		resolution["source"] = String(entry.get("source", ""))
		_entries.pop_front()
		choice_resolved.emit(resolution.duplicate(true))
		queue_changed.emit(_entries.size())
		return resolution
	return {}


func skip_wave_reward() -> Dictionary:
	if _entries.is_empty():
		return {}
	var entry := _entries[0]
	if String(entry.get("source", "")) != "wave":
		return {}
	var resolution := {
		"action": "skip",
		"event_id": int(entry.get("event_id", 0)),
		"source": "wave",
	}
	_entries.pop_front()
	choice_resolved.emit(resolution.duplicate(true))
	queue_changed.emit(_entries.size())
	return resolution


func skip_optional_reward() -> Dictionary:
	if _entries.is_empty():
		return {}
	var entry := _entries[0]
	var source := String(entry.get("source", ""))
	if source not in ["wave", "fusion_followup"]:
		return {}
	var resolution := {
		"action": "skip",
		"event_id": int(entry.get("event_id", 0)),
		"source": source,
	}
	_entries.pop_front()
	choice_resolved.emit(resolution.duplicate(true))
	queue_changed.emit(_entries.size())
	return resolution


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	queue_changed.emit(0)


func _claim_event_id() -> int:
	var event_id := _next_event_id
	_next_event_id += 1
	return event_id


func _make_entry(event_id: int, source: String, choices: Array[Dictionary]) -> Dictionary:
	return {
		"event_id": event_id,
		"source": source,
		"choices": choices,
	}


func _append_unique_choice(
	choices: Array[Dictionary],
	seen_choice_ids: Dictionary,
	choice: Dictionary
) -> void:
	var choice_id := String(choice.get("choice_id", ""))
	if choice_id.is_empty() or seen_choice_ids.has(choice_id):
		return
	seen_choice_ids[choice_id] = true
	choices.append(choice)


func _fusion_choices(event_id: int, fusions: Array[Dictionary]) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var seen_choice_ids: Dictionary = {}
	for fusion in fusions:
		if choices.size() >= MAX_EXPERIENCE_CHOICES:
			break
		var left_id := String(fusion.get("left_instance_id", ""))
		var right_id := String(fusion.get("right_instance_id", ""))
		var result_id := String(fusion.get("result_card_id", ""))
		if left_id.is_empty() or right_id.is_empty() or left_id == right_id or result_id.is_empty():
			continue
		_append_unique_choice(choices, seen_choice_ids, {
			"choice_id": "fusion:%d:%s:%s:%s" % [event_id, left_id, right_id, result_id],
			"action": "fusion",
			"recipe_id": String(fusion.get("recipe_id", result_id)),
			"left_instance_id": left_id,
			"right_instance_id": right_id,
			"left_card_id": String(fusion.get("left_card_id", "")),
			"right_card_id": String(fusion.get("right_card_id", "")),
			"left_name": String(fusion.get("left_name", "")),
			"right_name": String(fusion.get("right_name", "")),
			"result_card_id": result_id,
			"result_name": String(fusion.get("result_name", fusion.get("name", ""))),
			"type": String(fusion.get("type", "combo")),
			"cost": int(fusion.get("cost", 0)),
			"icon_path": String(fusion.get("icon_path", "")),
			"card_color": String(fusion.get("card_color", "")),
			"description": String(fusion.get("description", "")),
		})
	return choices
