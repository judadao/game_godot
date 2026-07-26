class_name SkillRecipeManager
extends RefCounted

signal skill_triggered(skill_id: StringName, effect: Dictionary)
signal skill_discovered(skill_id: StringName)

const DEFAULT_CATALOG_PATH := "res://data/skills.json"
const STARTING_MEMORY_CAPACITY := 10

var _loaded := false
var _skills_by_id: Dictionary = {}
var _attack_card_ids: Dictionary = {}
var _learned_skills: Dictionary = {}
var _active_skill_ids: Array[StringName] = []
var _trackers: Dictionary = {}
var _cooldowns: Dictionary = {}
var _memory_capacity := STARTING_MEMORY_CAPACITY


func _init(data_path: String = DEFAULT_CATALOG_PATH) -> void:
	_load_catalog(data_path)


func is_loaded() -> bool:
	return _loaded


func get_all_skills() -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill_id in _skills_by_id:
		skills.append((_skills_by_id[skill_id] as Dictionary).duplicate(true))
	return skills


func is_learned(skill_id: StringName) -> bool:
	return _learned_skills.has(String(skill_id))


func learn_skill(skill_id: StringName) -> bool:
	var key := String(skill_id)
	if not _skills_by_id.has(key) or _learned_skills.has(key):
		return false
	_learned_skills[key] = true
	return true


func discover_skill(skill_id: StringName) -> bool:
	var key := String(skill_id)
	var skill := _skills_by_id.get(key, {}) as Dictionary
	if skill.is_empty() or not bool(skill.get("hidden", false)) or not learn_skill(skill_id):
		return false
	skill_discovered.emit(skill_id)
	return true


func get_active_skill_ids() -> Array[StringName]:
	return _active_skill_ids.duplicate()


func get_memory_capacity() -> int:
	return _memory_capacity


func get_memory_used() -> int:
	var used := 0
	for skill_id in _active_skill_ids:
		used += int((_skills_by_id.get(String(skill_id), {}) as Dictionary).get("memory_cost", 0))
	return used


func set_memory_capacity(capacity: int) -> bool:
	if capacity < 0 or get_memory_used() > capacity:
		return false
	_memory_capacity = capacity
	return true


func set_active_loadout(skill_ids: Array, is_safe_area: bool) -> bool:
	if not is_safe_area:
		return false
	var proposed: Array[StringName] = []
	var used := 0
	for raw_skill_id in skill_ids:
		var skill_id := StringName(String(raw_skill_id))
		var key := String(skill_id)
		var skill := _skills_by_id.get(key, {}) as Dictionary
		if skill_id.is_empty() or proposed.has(skill_id) or not _learned_skills.has(key) or skill.is_empty():
			return false
		used += int(skill.get("memory_cost", 0))
		if used > _memory_capacity:
			return false
		proposed.append(skill_id)
	_active_skill_ids = proposed
	_trackers.clear()
	return true


func record_successful_attack(card_id: StringName, now_seconds: float) -> Array[StringName]:
	var key := String(card_id)
	if not _attack_card_ids.has(key):
		return []
	var triggered: Array[StringName] = []
	for skill_id in _tracked_skill_ids():
		var skill := _skills_by_id[String(skill_id)] as Dictionary
		var completed := _record_attack_for_skill(skill_id, skill, card_id, now_seconds)
		if not completed:
			continue
		if bool(skill.get("hidden", false)) and not is_learned(skill_id):
			discover_skill(skill_id)
			continue
		if not _active_skill_ids.has(skill_id) or float(_cooldowns.get(String(skill_id), 0.0)) > 0.0:
			continue
		_trigger_skill(skill_id, skill)
		triggered.append(skill_id)
	return triggered


func record_played_non_attack() -> void:
	for skill_id in _tracked_skill_ids():
		var skill := _skills_by_id[String(skill_id)] as Dictionary
		var recipe := skill.get("recipe", {}) as Dictionary
		if String(recipe.get("kind", "")) == "exact":
			_trackers[String(skill_id)] = {"index": 0}


func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)


func to_dict() -> Dictionary:
	return {
		"learned_skill_ids": _learned_skills.keys(),
		"active_skill_ids": _active_skill_ids.duplicate(),
	}


func apply_dict(data: Dictionary, is_safe_area: bool = true) -> void:
	_learned_skills.clear()
	_active_skill_ids.clear()
	_trackers.clear()
	var saved_learned: Variant = data.get("learned_skill_ids", [])
	if saved_learned is Array:
		for raw_skill_id in saved_learned:
			var key := String(raw_skill_id)
			if _skills_by_id.has(key):
				_learned_skills[key] = true
	var saved_active: Variant = data.get("active_skill_ids", [])
	if saved_active is Array:
		set_active_loadout(saved_active, is_safe_area)


func _tracked_skill_ids() -> Array[StringName]:
	var result := _active_skill_ids.duplicate()
	for key in _skills_by_id:
		var skill := _skills_by_id[key] as Dictionary
		if bool(skill.get("hidden", false)) and not _learned_skills.has(key):
			result.append(StringName(key))
	return result


func _record_attack_for_skill(skill_id: StringName, skill: Dictionary, card_id: StringName, now_seconds: float) -> bool:
	var recipe := skill.get("recipe", {}) as Dictionary
	var kind := String(recipe.get("kind", ""))
	var key := String(skill_id)
	var tracker := _trackers.get(key, {}) as Dictionary
	if kind == "count":
		var allowed_ids := recipe.get("attack_ids", []) as Array
		if not allowed_ids.has(String(card_id)):
			return false
		var last_at := float(tracker.get("last_at", -1.0))
		if last_at >= 0.0 and now_seconds - last_at > float(recipe.get("window_seconds", 0.0)):
			tracker = {}
		tracker["count"] = int(tracker.get("count", 0)) + 1
		tracker["last_at"] = now_seconds
		_trackers[key] = tracker
		if int(tracker["count"]) < int(recipe.get("required_count", 0)):
			return false
		_trackers[key] = {}
		return true
	if kind == "exact":
		var steps := recipe.get("steps", []) as Array
		var index := int(tracker.get("index", 0))
		if index < steps.size() and String(steps[index]) == String(card_id):
			index += 1
		else:
			index = 1 if not steps.is_empty() and String(steps[0]) == String(card_id) else 0
		_trackers[key] = {"index": index}
		if index < steps.size():
			return false
		_trackers[key] = {"index": 0}
		return true
	return false


func _trigger_skill(skill_id: StringName, skill: Dictionary) -> void:
	_cooldowns[String(skill_id)] = float(skill.get("cooldown_seconds", 0.0))
	skill_triggered.emit(skill_id, (skill.get("effect", {}) as Dictionary).duplicate(true))


func _load_catalog(data_path: String) -> void:
	_clear()
	var attack_card_ids := _read_attack_card_ids()
	if attack_card_ids.is_empty() or not FileAccess.file_exists(data_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		return
	var raw_skills: Variant = (parsed as Dictionary).get("skills", [])
	if not raw_skills is Array or raw_skills.is_empty():
		return
	_attack_card_ids = attack_card_ids
	for raw_skill in raw_skills:
		if not raw_skill is Dictionary:
			_clear()
			return
		var skill := (raw_skill as Dictionary).duplicate(true)
		if not _is_valid_skill(skill):
			_clear()
			return
		_skills_by_id[String(skill["id"])] = skill
	_loaded = true


func _read_attack_card_ids() -> Dictionary:
	var card_database_script := load("res://scripts/systems/card_database.gd")
	if card_database_script == null:
		return {}
	var database: RefCounted = card_database_script.new()
	if not bool(database.call("load_catalog")):
		return {}
	var ids: Dictionary = {}
	for raw_card in database.call("get_all_cards") as Array:
		var card := raw_card as Dictionary
		if String(card.get("type", "")).to_lower() == "attack":
			ids[String(card.get("id", ""))] = true
	return ids


func _is_valid_skill(skill: Dictionary) -> bool:
	for field in ["id", "name", "memory_cost", "hidden", "recipe", "effect", "cooldown_seconds"]:
		if not skill.has(field):
			return false
	var skill_id := String(skill["id"]).strip_edges()
	if skill_id.is_empty() or _skills_by_id.has(skill_id) or int(skill["memory_cost"]) <= 0:
		return false
	if not skill["hidden"] is bool or not skill["recipe"] is Dictionary or not skill["effect"] is Dictionary:
		return false
	if (skill["effect"] as Dictionary).is_empty() or float(skill["cooldown_seconds"]) < 0.0:
		return false
	var recipe := skill["recipe"] as Dictionary
	var kind := String(recipe.get("kind", ""))
	if kind == "count":
		var attack_ids: Variant = recipe.get("attack_ids", [])
		if not attack_ids is Array or attack_ids.is_empty() or int(recipe.get("required_count", 0)) <= 0 or float(recipe.get("window_seconds", 0.0)) <= 0.0:
			return false
		return _has_only_attack_ids(attack_ids as Array)
	if kind == "exact":
		var steps: Variant = recipe.get("steps", [])
		return steps is Array and not (steps as Array).is_empty() and _has_only_attack_ids(steps as Array)
	return false


func _has_only_attack_ids(card_ids: Array) -> bool:
	for raw_card_id in card_ids:
		var card_id := String(raw_card_id)
		if card_id.is_empty() or not _attack_card_ids.has(card_id):
			return false
	return true


func _clear() -> void:
	_loaded = false
	_skills_by_id.clear()
	_attack_card_ids.clear()
	_learned_skills.clear()
	_active_skill_ids.clear()
	_trackers.clear()
	_cooldowns.clear()
