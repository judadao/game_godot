class_name DivineGiftManager
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/divine_gifts.json"
const MAX_LEVEL := 3
const EVOLVED_MAX_LEVEL := 3
const MAX_OWNED_GIFTS := 3
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")

var _catalog: Dictionary = {}
var _inventory: Dictionary = {}
var _acquisition_order: Array[String] = []
var _next_evolution_id := 1
var _primary_gift_id := ""
var _ascended_base_ids: Dictionary = {}
var _completed_fusions: Dictionary = {}
var _element_taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()


func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> bool:
	_catalog.clear()
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var gifts_variant: Variant = (parsed as Dictionary).get("gifts", [])
	if not gifts_variant is Array:
		return false
	for gift_variant in gifts_variant:
		if not gift_variant is Dictionary:
			_catalog.clear()
			return false
		var gift := (gift_variant as Dictionary).duplicate(true)
		var gift_id := String(gift.get("id", "")).strip_edges()
		var element := String(
			_element_taxonomy.call("normalize", String(gift.get("element", "")))
		)
		var levels_variant: Variant = gift.get("effects_by_level", [])
		if (
			gift_id.is_empty()
			or _catalog.has(gift_id)
			or not bool(_element_taxonomy.call("is_valid", element))
			or not levels_variant is Array
			or (levels_variant as Array).size() != MAX_LEVEL
		):
			_catalog.clear()
			return false
		gift["element"] = element
		_catalog[gift_id] = gift
	return not _catalog.is_empty()


func reset_run() -> void:
	_inventory.clear()
	_acquisition_order.clear()
	_next_evolution_id = 1
	_primary_gift_id = ""
	_ascended_base_ids.clear()
	_completed_fusions.clear()


func has_gift(gift_id: String) -> bool:
	return _inventory.has(gift_id)


func get_gift(gift_id: String) -> Dictionary:
	return (
		(_inventory[gift_id] as Dictionary).duplicate(true)
		if _inventory.has(gift_id)
		else {}
	)


func get_inventory() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for gift_id in _ordered_gift_ids():
		result.append((_inventory[gift_id] as Dictionary).duplicate(true))
	return result


func add_or_upgrade(gift_id: String) -> bool:
	if _inventory.has(gift_id):
		var owned := _inventory[gift_id] as Dictionary
		if String(owned.get("kind", "")) == "evolved":
			return _upgrade_evolved(gift_id)
	if not _catalog.has(gift_id) or _ascended_base_ids.has(gift_id):
		return false
	if _inventory.has(gift_id):
		var current := _inventory[gift_id] as Dictionary
		var level := int(current.get("level", 1))
		if level >= MAX_LEVEL:
			return false
		current["level"] = level + 1
		current["effects"] = _effects_for_level(gift_id, level + 1)
		_inventory[gift_id] = current
		_primary_gift_id = gift_id
		return true
	if _inventory.size() >= MAX_OWNED_GIFTS:
		return false
	var definition := _catalog[gift_id] as Dictionary
	_inventory[gift_id] = {
		"id": gift_id,
		"name": String(definition.get("name", gift_id)),
		"description": String(definition.get("description", "")),
		"icon": String(definition.get("icon", "✦")),
		"prefix": String(definition.get("prefix", "")),
		"element": String(definition.get("element", "")),
		"elements": [String(definition.get("element", "normal"))],
		"finisher_mutations": (
			definition.get("finisher_mutations", {}) as Dictionary
		).duplicate(true),
		"level": 1,
		"max_level": MAX_LEVEL,
		"kind": "base",
		"effects": _effects_for_level(gift_id, 1),
	}
	_acquisition_order.append(gift_id)
	_primary_gift_id = gift_id
	return true


func get_reward_choices(maximum: int = 3) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var has_open_slot := _inventory.size() < MAX_OWNED_GIFTS
	for gift_id_variant in _catalog:
		var gift_id := String(gift_id_variant)
		if _ascended_base_ids.has(gift_id):
			continue
		var definition := _catalog[gift_id] as Dictionary
		var current_level := int(
			(_inventory.get(gift_id, {}) as Dictionary).get("level", 0)
		)
		if current_level >= MAX_LEVEL or (current_level == 0 and not has_open_slot):
			continue
		var current_effects: Dictionary = (
			_effects_for_level(gift_id, current_level)
			if current_level > 0
			else {}
		)
		choices.append({
			"gift_id": gift_id,
			"name": String(definition.get("name", gift_id)),
			"description": String(definition.get("description", "")),
			"icon": String(definition.get("icon", "✦")),
			"element": String(definition.get("element", "normal")),
			"current_effects": current_effects,
			"next_effects": _effects_for_level(gift_id, current_level + 1),
			"finisher_mutations": (
				definition.get("finisher_mutations", {}) as Dictionary
			).duplicate(true),
			"level": current_level,
			"next_level": current_level + 1,
			"action": "divine_gift",
			"kind": "base",
		})
	for gift_id_variant in _inventory:
		var gift_id := String(gift_id_variant)
		var evolved := _inventory[gift_id] as Dictionary
		if (
			String(evolved.get("kind", "")) != "evolved"
			or int(evolved.get("level", 0)) >= int(evolved.get("max_level", 0))
		):
			continue
		var evolved_level := int(evolved.get("level", 1))
		var inherited_effects := evolved.get("inherited_effects", {}) as Dictionary
		var inherited_mutations := evolved.get("inherited_mutations", {}) as Dictionary
		choices.append({
			"gift_id": gift_id,
			"name": String(evolved.get("name", gift_id)),
			"description": String(evolved.get("description", "")),
			"icon": String(evolved.get("icon", "✺")),
			"element": String(evolved.get("element", "normal")),
			"elements": (evolved.get("elements", []) as Array).duplicate(),
			"current_effects": (
				evolved.get("effects", {}) as Dictionary
			).duplicate(true),
			"next_effects": _evolved_effects(
				inherited_effects,
				evolved_level + 1
			),
			"finisher_mutations": _evolved_mutations(
				inherited_mutations,
				evolved_level + 1
			),
			"accent_color": String(evolved.get("accent_color", "#f05cff")),
			"level": evolved_level,
			"next_level": evolved_level + 1,
			"action": "divine_gift",
			"kind": "evolved",
		})
	choices.shuffle()
	return choices.slice(0, mini(maxi(0, maximum), choices.size()))


func get_fusion_choices() -> Array[Dictionary]:
	var maximum_ids: Array[String] = []
	for gift_id_variant in _inventory:
		var gift := _inventory[gift_id_variant] as Dictionary
		if String(gift.get("kind", "")) == "base" and int(gift.get("level", 0)) >= MAX_LEVEL:
			maximum_ids.append(String(gift_id_variant))
	var choices: Array[Dictionary] = []
	for left_index in maximum_ids.size():
		for right_index in range(left_index + 1, maximum_ids.size()):
			var left_id := maximum_ids[left_index]
			var right_id := maximum_ids[right_index]
			var left := _inventory[left_id] as Dictionary
			var right := _inventory[right_id] as Dictionary
			var identity := _evolved_identity(_canonical_gift_elements(left, right))
			choices.append({
				"action": "divine_fusion",
				"left_gift_id": left_id,
				"right_gift_id": right_id,
				"name": String(identity["name"]),
				"description": (
					"融合「%s」與「%s」，保留兩者核心效果並獲得新的昇華能力。"
					% [String(left.get("name", left_id)), String(right.get("name", right_id))]
				),
				"accent_color": String(identity["accent_color"]),
				"kind": "evolved",
			})
	return choices


func fuse_max_level(left_id: String, right_id: String) -> Dictionary:
	if left_id == right_id or not _inventory.has(left_id) or not _inventory.has(right_id):
		return {}
	var left := _inventory[left_id] as Dictionary
	var right := _inventory[right_id] as Dictionary
	if (
		String(left.get("kind", "")) != "base"
		or String(right.get("kind", "")) != "base"
		or int(left.get("level", 0)) < MAX_LEVEL
		or int(right.get("level", 0)) < MAX_LEVEL
	):
		return {}
	var fusion_key := _fusion_key(left_id, right_id)
	if _completed_fusions.has(fusion_key):
		return {}
	var inherited_effects := _merge_effects([
		left.get("effects", {}) as Dictionary,
		right.get("effects", {}) as Dictionary,
	])
	var inherited_mutations := _merge_mutations([
		left.get("finisher_mutations", {}) as Dictionary,
		right.get("finisher_mutations", {}) as Dictionary,
	])
	var evolution_id := "evolved_%03d_%s_%s" % [
		_next_evolution_id,
		left_id,
		right_id,
	]
	_next_evolution_id += 1
	var evolved_elements := _canonical_gift_elements(left, right)
	var primary_element := (
		String(evolved_elements[0])
		if not evolved_elements.is_empty()
		else "normal"
	)
	var identity := _evolved_identity(evolved_elements)
	var evolved := {
		"id": evolution_id,
		"name": String(identity["name"]),
		"base_name": String(identity["name"]),
		"description": (
			"保留兩項神賜的部分效果，並在每次昇華升級時解鎖新能力。"
		),
		"icon": "✺",
		"prefix": _evolved_prefix(left, right),
		"accent_color": String(identity["accent_color"]),
		"element": primary_element,
		"elements": evolved_elements,
		"finisher_mutations": _evolved_mutations(inherited_mutations, 1),
		"inherited_mutations": inherited_mutations,
		"level": 1,
		"max_level": EVOLVED_MAX_LEVEL,
		"kind": "evolved",
		"components": [left_id, right_id],
		"inherited_effects": inherited_effects,
		"effects": _evolved_effects(inherited_effects, 1),
	}
	_inventory.erase(left_id)
	_inventory.erase(right_id)
	_acquisition_order.erase(left_id)
	_acquisition_order.erase(right_id)
	_inventory[evolution_id] = evolved
	_acquisition_order.append(evolution_id)
	_ascended_base_ids[left_id] = true
	_ascended_base_ids[right_id] = true
	_completed_fusions[fusion_key] = true
	_primary_gift_id = evolution_id
	return evolved.duplicate(true)


func _upgrade_evolved(gift_id: String) -> bool:
	var evolved := _inventory.get(gift_id, {}) as Dictionary
	var level := int(evolved.get("level", 1))
	if String(evolved.get("kind", "")) != "evolved" or level >= EVOLVED_MAX_LEVEL:
		return false
	level += 1
	evolved["level"] = level
	evolved["name"] = _evolved_level_name(
		String(evolved.get("base_name", evolved.get("name", gift_id))),
		level
	)
	evolved["effects"] = _evolved_effects(
		evolved.get("inherited_effects", {}) as Dictionary,
		level
	)
	evolved["finisher_mutations"] = _evolved_mutations(
		evolved.get("inherited_mutations", {}) as Dictionary,
		level
	)
	_inventory[gift_id] = evolved
	_primary_gift_id = gift_id
	return true


func _evolved_effects(inherited: Dictionary, level: int) -> Dictionary:
	var retained := _scale_effects(inherited, [0.8, 1.0, 1.2][clampi(level - 1, 0, 2)])
	retained["combo_stack_bonus"] = int(retained.get("combo_stack_bonus", 0)) + level
	retained["finisher_element_damage"] = (
		int(retained.get("finisher_element_damage", 0)) + level * 3
	)
	retained["finisher_size_multiplier"] = (
		float(retained.get("finisher_size_multiplier", 1.0))
		* (1.0 + 0.1 * float(level))
	)
	if level >= 2:
		retained["combo_ap_refund"] = float(retained.get("combo_ap_refund", 0.0)) + 0.1
	if level >= 3:
		retained["finisher_echoes"] = int(retained.get("finisher_echoes", 0)) + 1
	return retained


func _scale_effects(effects: Dictionary, scale: float) -> Dictionary:
	var result: Dictionary = {}
	for key_variant in effects:
		var key := String(key_variant)
		var value: Variant = effects[key_variant]
		if value is bool:
			result[key] = value
		elif value is int:
			result[key] = roundi(float(value) * scale)
		elif value is float:
			result[key] = (
				1.0 + (float(value) - 1.0) * scale
				if key.ends_with("_multiplier")
				else float(value) * scale
			)
	return result


func _evolved_mutations(inherited: Dictionary, level: int) -> Dictionary:
	var result := inherited.duplicate(true)
	result["final_burst"] = true
	if level >= 2:
		result["chain_lightning"] = true
	if level >= 3:
		result["death_spread"] = true
		result["finisher_echoes"] = maxi(
			int(result.get("finisher_echoes", 0)),
			2
		)
	return result


func _evolved_level_name(base_name: String, level: int) -> String:
	match level:
		2:
			return "覺醒・%s" % base_name
		3:
			return "超越・%s" % base_name
		_:
			return base_name


func _evolved_identity(elements: Array[String]) -> Dictionary:
	var sorted := elements.duplicate()
	sorted.sort()
	var key := "+".join(sorted)
	match key:
		"fire+lightning":
			return {
				"name": "天火雷劫",
				"accent_color": "#ff6a24",
			}
		"dark+ice":
			return {
				"name": "永劫冰淵",
				"accent_color": "#8b7cff",
			}
		"poison+wind":
			return {
				"name": "枯天風暴",
				"accent_color": "#55e68a",
			}
		_:
			return {
				"name": "萬象神化",
				"accent_color": "#f05cff",
			}


func _canonical_gift_elements(left: Dictionary, right: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for gift in [left, right]:
		var candidates := gift.get("elements", [gift.get("element", "normal")]) as Array
		for candidate_variant in candidates:
			var element := String(
				_element_taxonomy.call("normalize", String(candidate_variant), "normal")
			)
			if not result.has(element):
				result.append(element)
	return result


func get_global_effects() -> Dictionary:
	var effects: Array[Dictionary] = []
	for gift_variant in _inventory.values():
		var gift := gift_variant as Dictionary
		effects.append(gift.get("effects", {}) as Dictionary)
	return _merge_effects(effects)


func set_primary_gift(gift_id: String) -> bool:
	if not _inventory.has(gift_id):
		return false
	_primary_gift_id = gift_id
	return true


func get_primary_gift() -> Dictionary:
	if _primary_gift_id.is_empty() or not _inventory.has(_primary_gift_id):
		return {}
	return (_inventory[_primary_gift_id] as Dictionary).duplicate(true)


func get_epithet_prefix() -> String:
	var prefix_stems: Array[String] = []
	for gift_id in _ordered_gift_ids():
		var prefix := String(
			(_inventory[gift_id] as Dictionary).get("prefix", "")
		).strip_edges()
		while prefix.ends_with("的"):
			prefix = prefix.left(prefix.length() - 1).strip_edges()
		if not prefix.is_empty():
			prefix_stems.append(prefix)
	return "" if prefix_stems.is_empty() else "%s的" % "・".join(prefix_stems)


func get_finisher_mutations() -> Dictionary:
	var mutation_sets: Array[Dictionary] = []
	for gift_variant in _inventory.values():
		var gift := gift_variant as Dictionary
		mutation_sets.append(
			gift.get("finisher_mutations", {}) as Dictionary
		)
	return _merge_mutations(mutation_sets)


func get_ascended_base_ids() -> Array[String]:
	var result: Array[String] = []
	for gift_id_variant in _ascended_base_ids:
		result.append(String(gift_id_variant))
	result.sort()
	return result


func _effects_for_level(gift_id: String, level: int) -> Dictionary:
	var definition := _catalog.get(gift_id, {}) as Dictionary
	var levels := definition.get("effects_by_level", []) as Array
	var index := clampi(level - 1, 0, levels.size() - 1)
	return (levels[index] as Dictionary).duplicate(true) if not levels.is_empty() else {}


func _merge_effects(effect_sets: Array[Dictionary]) -> Dictionary:
	var result := {
		"combo_effect_multiplier": 1.0,
		"finisher_damage_multiplier": 1.0,
		"finisher_size_multiplier": 1.0,
	}
	for effects in effect_sets:
		for effect_key_variant in effects:
			var effect_key := String(effect_key_variant)
			var value: Variant = effects[effect_key_variant]
			if effect_key.ends_with("_multiplier"):
				result[effect_key] = float(result.get(effect_key, 1.0)) * float(value)
			elif value is float:
				result[effect_key] = float(result.get(effect_key, 0.0)) + float(value)
			elif value is int:
				result[effect_key] = int(result.get(effect_key, 0)) + int(value)
			elif value is bool:
				result[effect_key] = bool(result.get(effect_key, false)) or bool(value)
	return result


func _merge_mutations(mutation_sets: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for mutations in mutation_sets:
		for key_variant in mutations:
			var key := String(key_variant)
			var value: Variant = mutations[key_variant]
			if value is bool:
				result[key] = bool(result.get(key, false)) or bool(value)
			elif value is int:
				result[key] = int(result.get(key, 0)) + int(value)
			elif value is float:
				if key.ends_with("_ratio") or key.ends_with("_multiplier"):
					result[key] = maxf(
						float(result.get(key, 0.0)),
						float(value)
					)
				else:
					result[key] = (
						float(result.get(key, 0.0)) + float(value)
					)
			else:
				result[key] = value
	return result


func _fusion_key(left_id: String, right_id: String) -> String:
	var ids: Array[String] = [left_id, right_id]
	ids.sort()
	return "%s+%s" % ids


func _ordered_gift_ids() -> Array[String]:
	var result: Array[String] = []
	for gift_id in _acquisition_order:
		if _inventory.has(gift_id) and not result.has(gift_id):
			result.append(gift_id)
	for gift_id_variant in _inventory:
		var gift_id := String(gift_id_variant)
		if not result.has(gift_id):
			result.append(gift_id)
	return result


func _evolved_prefix(left: Dictionary, right: Dictionary) -> String:
	var elements: Array[String] = [
		String(left.get("element", "")),
		String(right.get("element", "")),
	]
	elements.sort()
	if elements == ["dark", "ice"]:
		return "永劫冰獄的"
	if elements == ["fire", "lightning"]:
		return "天火雷劫的"
	if elements == ["poison", "wind"]:
		return "枯天風暴的"
	return "萬象神化的"
