class_name GrowthChoiceQueue
extends RefCounted

signal queue_changed(queue_count: int)
signal current_changed(entry: Dictionary)
signal action_confirmed(entry: Dictionary, action: Dictionary)

const WAVE_BLESSING_SOURCE := "wave_blessing"
const EXP_LEVEL_SOURCE := "exp_level"
const WAVE_BLESSING_PAGE := "new_card"
const EXP_LEVEL_PAGES := ["upgrade", "fusion", "reward"]

var _entries: Array[Dictionary] = []


func enqueue(raw_entry: Dictionary) -> bool:
	var entry := _normalize_entry(raw_entry)
	if entry.is_empty():
		return false
	var was_empty := _entries.is_empty()
	_entries.append(entry)
	queue_changed.emit(_entries.size())
	if was_empty:
		current_changed.emit(peek())
	return true


func get_queue_count() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func peek() -> Dictionary:
	if _entries.is_empty():
		return {}
	return (_entries[0] as Dictionary).duplicate(true)


func get_current() -> Dictionary:
	return peek()


func confirm(raw_action: Variant, requested_page: Variant = null) -> bool:
	if _entries.is_empty():
		return false
	var action := _normalize_action(raw_action, requested_page)
	if action.is_empty():
		return false
	var entry := _entries[0] as Dictionary
	var page := String(action.get("page", ""))
	if not (entry.get("allowed_pages", []) as Array).has(page):
		return false
	_entries.remove_at(0)
	queue_changed.emit(_entries.size())
	current_changed.emit(peek())
	action_confirmed.emit(entry.duplicate(true), action.duplicate(true))
	return true


func close() -> bool:
	return false


func _normalize_entry(raw_entry: Dictionary) -> Dictionary:
	for field in ["source", "allowed_pages", "payload"]:
		if not raw_entry.has(field):
			return {}
	if not raw_entry["allowed_pages"] is Array or not raw_entry["payload"] is Dictionary:
		return {}
	var source := String(raw_entry["source"]).strip_edges().to_lower()
	var allowed_pages := _normalize_pages(raw_entry["allowed_pages"] as Array)
	if allowed_pages.is_empty():
		return {}
	if source == WAVE_BLESSING_SOURCE:
		if allowed_pages != [WAVE_BLESSING_PAGE]:
			return {}
	elif source == EXP_LEVEL_SOURCE:
		for page in allowed_pages:
			if not EXP_LEVEL_PAGES.has(page):
				return {}
		if allowed_pages.has("reward") and allowed_pages.size() != 1:
			return {}
	else:
		return {}
	return {
		"source": source,
		"allowed_pages": allowed_pages,
		"payload": (raw_entry["payload"] as Dictionary).duplicate(true),
	}


func _normalize_pages(raw_pages: Array) -> Array[String]:
	var pages: Array[String] = []
	for raw_page in raw_pages:
		if not raw_page is String and not raw_page is StringName:
			return []
		var page := String(raw_page).strip_edges().to_lower()
		if page.is_empty() or pages.has(page):
			return []
		pages.append(page)
	return pages


func _normalize_action(raw_action: Variant, requested_page: Variant) -> Dictionary:
	var action: Dictionary = {}
	if raw_action is Dictionary:
		action = (raw_action as Dictionary).duplicate(true)
	elif raw_action is String or raw_action is StringName:
		action["kind"] = String(raw_action)
		action["page"] = requested_page if requested_page != null else raw_action
	else:
		return {}
	var page := String(action.get("page", "")).strip_edges().to_lower()
	var kind := String(action.get("kind", "")).strip_edges().to_lower()
	if page.is_empty() or kind.is_empty() or page != kind:
		return {}
	action["page"] = page
	action["kind"] = kind
	return action
