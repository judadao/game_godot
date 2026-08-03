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


func enqueue_experience_blessings(rewards: Array[Dictionary]) -> bool:
	var event_id := _claim_event_id()
	var choices := _divine_gift_choices(event_id, rewards, "level")
	if choices.is_empty():
		choices = _fallback_choices(event_id)
	_entries.append(_make_entry(event_id, "experience", choices))
	queue_changed.emit(_entries.size())
	return true


func enqueue_combat_blessing_reward(
	source: String,
	upgrades: Array[Dictionary],
	fusions: Array[Dictionary]
) -> bool:
	var normalized_source := source.to_lower()
	if normalized_source not in ["elite", "boss"]:
		return false
	var event_id := _claim_event_id()
	var choices := _divine_gift_choices(event_id, upgrades, normalized_source)
	for fusion_choice in _divine_fusion_choices(event_id, fusions, normalized_source):
		if choices.size() >= MAX_EXPERIENCE_CHOICES:
			break
		choices.append(fusion_choice)
	if choices.is_empty():
		return false
	_entries.append(_make_entry(event_id, normalized_source, choices))
	queue_changed.emit(_entries.size())
	return true


func enqueue_divine_gifts(
	rewards: Array[Dictionary],
	fusions: Array[Dictionary]
) -> bool:
	var event_id := _claim_event_id()
	var choices := _divine_gift_choices(event_id, rewards, "divine")
	for fusion_choice in _divine_fusion_choices(event_id, fusions, "divine"):
		if choices.size() >= MAX_EXPERIENCE_CHOICES:
			break
		choices.append(fusion_choice)
	if choices.is_empty():
		return false
	_entries.append(_make_entry(event_id, "divine", choices))
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
	if source not in ["wave", "divine"]:
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


func _divine_gift_choices(
	event_id: int,
	rewards: Array[Dictionary],
	prefix: String
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for reward in rewards:
		if choices.size() >= MAX_EXPERIENCE_CHOICES:
			break
		var gift_id := String(reward.get("gift_id", ""))
		if gift_id.is_empty():
			continue
		choices.append({
			"choice_id": "%s:%d:gift:%s" % [prefix, event_id, gift_id],
			"action": "divine_gift",
			"gift_id": gift_id,
			"name": String(reward.get("name", gift_id)),
			"description": String(reward.get("description", "")),
			"icon": String(reward.get("icon", "✦")),
			"element": String(reward.get("element", "normal")),
			"elements": (reward.get("elements", []) as Array).duplicate(),
			"current_effects": (reward.get("current_effects", {}) as Dictionary).duplicate(true),
			"next_effects": (reward.get("next_effects", {}) as Dictionary).duplicate(true),
			"finisher_mutations": (reward.get("finisher_mutations", {}) as Dictionary).duplicate(true),
			"level": int(reward.get("level", 0)),
			"next_level": int(reward.get("next_level", 1)),
			"type": "divine",
			"kind": String(reward.get("kind", "base")),
			"accent_color": String(reward.get("accent_color", "")),
			"card_color": (
				"prismatic"
				if String(reward.get("kind", "base")) == "evolved"
				else "gold"
			),
		})
	return choices


func _divine_fusion_choices(
	event_id: int,
	fusions: Array[Dictionary],
	prefix: String
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for fusion in fusions:
		var left_id := String(fusion.get("left_gift_id", ""))
		var right_id := String(fusion.get("right_gift_id", ""))
		if left_id.is_empty() or right_id.is_empty() or left_id == right_id:
			continue
		choices.append({
			"choice_id": "%s:%d:fusion:%s:%s" % [prefix, event_id, left_id, right_id],
			"action": "divine_fusion",
			"left_gift_id": left_id,
			"right_gift_id": right_id,
			"name": String(fusion.get("name", "神賜昇華")),
			"description": String(fusion.get("description", "")),
			"type": "divine",
			"kind": String(fusion.get("kind", "evolved")),
			"accent_color": String(fusion.get("accent_color", "#f05cff")),
			"card_color": "prismatic",
		})
	return choices


func _fallback_choices(event_id: int) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for index in FALLBACK_REWARDS.size():
		choices.append({
			"choice_id": "exp:%d:fallback:%d" % [event_id, index],
			"action": "fallback",
			"reward": FALLBACK_REWARDS[index].duplicate(true),
		})
	return choices
