class_name SkillRecipeManager
extends RefCounted

const DEFAULT_MEMORY_CAPACITIES: Array[int] = [10, 14, 18, 24, 30]

var _recipes: Dictionary = {}
var _memory_capacities: Array[int] = DEFAULT_MEMORY_CAPACITIES.duplicate()
var _learned: Dictionary = {}
var _active_ids: Array[String] = []
var _runtime: Dictionary = {}


func load_catalog(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Skill catalog not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Skill catalog could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Skill catalog root must be a dictionary: %s" % path)
		return false
	var catalog := parsed as Dictionary
	var incoming_skills: Variant = catalog.get("skills", [])
	if not incoming_skills is Array:
		push_error("Skill catalog skills must be an array: %s" % path)
		return false
	var validated: Dictionary = {}
	for value in incoming_skills:
		if not value is Dictionary:
			push_error("Skill catalog entries must be dictionaries.")
			return false
		var recipe := (value as Dictionary).duplicate(true)
		if not _is_valid_recipe(recipe):
			return false
		var skill_id := String(recipe["id"])
		if validated.has(skill_id):
			push_error("Duplicate skill id: %s" % skill_id)
			return false
		validated[skill_id] = recipe
	var capacities := _parse_capacities(catalog.get("memory_capacity_by_library_level", []))
	if capacities.is_empty():
		return false
	_recipes = validated
	_memory_capacities = capacities
	reset_runtime()
	return true


func configure_loadout(learned_ids: Array, active_ids: Array, memory_capacity: int) -> bool:
	if memory_capacity < 0:
		return false
	var learned_lookup: Dictionary = {}
	for value in learned_ids:
		var skill_id := String(value)
		if not _recipes.has(skill_id):
			return false
		learned_lookup[skill_id] = true
	var normalized_active: Array[String] = []
	var memory_used := 0
	for value in active_ids:
		var skill_id := String(value)
		if not learned_lookup.has(skill_id) or normalized_active.has(skill_id):
			return false
		memory_used += int((_recipes[skill_id] as Dictionary).get("memory_cost", 0))
		if memory_used > memory_capacity:
			return false
		normalized_active.append(skill_id)
	_learned = learned_lookup
	_active_ids = normalized_active
	reset_runtime()
	return true


func record_card(card: Dictionary) -> Array[Dictionary]:
	var is_attack := _is_positive_damage_attack(card)
	var card_id := String(card.get("id", card.get("card_id", "")))
	var triggered: Array[Dictionary] = []
	for skill_id in _active_ids:
		var recipe := _recipes[skill_id] as Dictionary
		var state := _state_for(skill_id)
		if float(state.get("cooldown_remaining", 0.0)) > 0.0:
			continue
		var did_trigger := false
		match String(recipe.get("match_mode", "")):
			"count":
				if not is_attack:
					continue
				var next_count := int(state.get("progress", 0)) + 1
				state["progress"] = next_count
				state["window_remaining"] = float(recipe.get("window_seconds", 8.0))
				did_trigger = next_count >= int(recipe.get("attack_count", 0))
			"sequence":
				if not is_attack:
					_reset_progress(state)
					continue
				var sequence := recipe.get("sequence", []) as Array
				var progress := int(state.get("progress", 0))
				if progress < sequence.size() and card_id == String(sequence[progress]):
					progress += 1
				else:
					progress = 1 if not sequence.is_empty() and card_id == String(sequence[0]) else 0
				state["progress"] = progress
				state["window_remaining"] = float(recipe.get("window_seconds", 8.0)) if progress > 0 else 0.0
				did_trigger = progress >= sequence.size()
		if did_trigger:
			_reset_progress(state)
			state["cooldown_remaining"] = float(recipe.get("cooldown_seconds", 0.0))
			triggered.append(recipe.duplicate(true))
	return triggered


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	for skill_id in _active_ids:
		var state := _state_for(skill_id)
		state["cooldown_remaining"] = maxf(0.0, float(state.get("cooldown_remaining", 0.0)) - delta)
		var window_remaining := maxf(0.0, float(state.get("window_remaining", 0.0)) - delta)
		state["window_remaining"] = window_remaining
		if window_remaining <= 0.0 and int(state.get("progress", 0)) > 0:
			state["progress"] = 0


func reset_runtime() -> void:
	_runtime.clear()
	for skill_id in _active_ids:
		_runtime[skill_id] = _new_runtime_state()


func get_progress(skill_id: String) -> int:
	if not _runtime.has(skill_id):
		return 0
	return int((_runtime[skill_id] as Dictionary).get("progress", 0))


func get_cooldown_remaining(skill_id: String) -> float:
	if not _runtime.has(skill_id):
		return 0.0
	return float((_runtime[skill_id] as Dictionary).get("cooldown_remaining", 0.0))


func get_memory_capacity_for_library_level(level: int) -> int:
	if _memory_capacities.is_empty():
		return 0
	return _memory_capacities[clampi(level, 0, _memory_capacities.size() - 1)]


func get_recipe(skill_id: String) -> Dictionary:
	if not _recipes.has(skill_id):
		return {}
	return (_recipes[skill_id] as Dictionary).duplicate(true)


func get_active_ids() -> Array[String]:
	return _active_ids.duplicate()


func _state_for(skill_id: String) -> Dictionary:
	if not _runtime.has(skill_id):
		_runtime[skill_id] = _new_runtime_state()
	return _runtime[skill_id] as Dictionary


func _new_runtime_state() -> Dictionary:
	return {
		"progress": 0,
		"window_remaining": 0.0,
		"cooldown_remaining": 0.0,
	}


func _reset_progress(state: Dictionary) -> void:
	state["progress"] = 0
	state["window_remaining"] = 0.0


func _is_positive_damage_attack(card: Dictionary) -> bool:
	if String(card.get("type", "")) != "attack":
		return false
	var effect_variant: Variant = card.get("effect", {})
	if not effect_variant is Dictionary:
		return false
	var effect := effect_variant as Dictionary
	return float(effect.get("damage", effect.get("amount", 0.0))) > 0.0


func _parse_capacities(value: Variant) -> Array[int]:
	if not value is Array or (value as Array).is_empty():
		push_error("Skill catalog must define memory capacities.")
		return []
	var result: Array[int] = []
	for capacity_value in value as Array:
		var capacity := int(capacity_value)
		if capacity <= 0 or (not result.is_empty() and capacity < result[-1]):
			push_error("Skill memory capacities must be positive and non-decreasing.")
			return []
		result.append(capacity)
	return result


func _is_valid_recipe(recipe: Dictionary) -> bool:
	var skill_id := String(recipe.get("id", ""))
	var mode := String(recipe.get("match_mode", ""))
	if skill_id.is_empty() or String(recipe.get("name", "")).is_empty():
		push_error("Skill recipes require id and name.")
		return false
	if int(recipe.get("memory_cost", 0)) <= 0:
		push_error("Skill recipe %s requires positive memory cost." % skill_id)
		return false
	if float(recipe.get("window_seconds", 0.0)) <= 0.0 or float(recipe.get("cooldown_seconds", -1.0)) < 0.0:
		push_error("Skill recipe %s has invalid timing." % skill_id)
		return false
	if mode == "count":
		if int(recipe.get("attack_count", 0)) <= 0:
			push_error("Count skill %s requires a positive attack count." % skill_id)
			return false
	elif mode == "sequence":
		var sequence_variant: Variant = recipe.get("sequence", [])
		if not sequence_variant is Array or (sequence_variant as Array).is_empty():
			push_error("Sequence skill %s requires card ids." % skill_id)
			return false
		for card_id in sequence_variant as Array:
			if String(card_id).is_empty():
				push_error("Sequence skill %s contains an empty card id." % skill_id)
				return false
	else:
		push_error("Skill recipe %s has unsupported match mode." % skill_id)
		return false
	return recipe.get("effect", {}) is Dictionary
