extends RefCounted

const DEFAULT_DATA_PATH := "res://data/equipment.json"
const SAVE_SCHEMA_VERSION := 6
const VALID_SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]
const VALID_QUALITIES: Array[StringName] = [&"common", &"rare", &"exceptional", &"legendary"]
const VALID_MATERIAL_TIERS: Array[StringName] = [&"normal", &"elite", &"boss"]
const VALID_BLUEPRINT_SCHOOLS: Array[StringName] = [
	&"balanced",
	&"keen_edge",
	&"efficient_form",
	&"merchant_signature",
	&"elemental_resonance",
]
const QUALITY_MULTIPLIERS := {
	&"common": 1.0,
	&"rare": 1.25,
	&"exceptional": 1.60,
	&"legendary": 2.40,
}
const RESOURCE_SALE_VALUES := {
	&"autumn_wood": 2,
	&"stone": 3,
	&"magic_shard": 6,
	&"autumn_core": 12,
}
const MAX_EQUIPMENT_LEVEL := 15
const IMPLEMENTED_EFFECT_LEVEL_CAP := 3
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")

var _loaded := false
var _resource_ids: Array[StringName] = []
var _resources: Dictionary = {}
var _resource_quality_counts: Dictionary = {}
var _equipment_catalog: Array[Dictionary] = []
var _equipment_by_id: Dictionary = {}
var _owned_equipment: Dictionary = {}
var _equipment_counts: Dictionary = {}
var _equipment_quality_counts: Dictionary = {}
var _equipment_levels: Dictionary = {}
var _blueprint_proficiency: Dictionary = {}
var _owned_blueprints: Dictionary = {}
var _owned_tools: Dictionary = {}
var _sale_slots: Array[Dictionary] = [{}]
var _progression_unlocks: Dictionary = {}
var _equipped: Dictionary = {
	"weapon": StringName(),
	"armor": StringName(),
	"accessory": StringName(),
}
var _equipped_quality: Dictionary = {
	"weapon": StringName(),
	"armor": StringName(),
	"accessory": StringName(),
}
var _element_taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()


func _init(data_path: String = DEFAULT_DATA_PATH) -> void:
	_load_data(data_path)


func is_loaded() -> bool:
	return _loaded


func get_resource_ids() -> Array[StringName]:
	return _resource_ids.duplicate()


func get_resources() -> Dictionary:
	return _resources.duplicate(true)


func get_resource_amount(resource_id: StringName) -> int:
	return int(_resources.get(String(resource_id), 0))


func add_resource(
	resource_id: StringName,
	amount: int,
	quality: StringName = &"common"
) -> bool:
	var key := String(resource_id)
	if not _resources.has(key) or amount <= 0 or not VALID_QUALITIES.has(quality):
		return false
	if resource_id == &"gold" and quality != &"common":
		return false
	_resources[key] = int(_resources[key]) + amount
	if resource_id != &"gold":
		_ensure_resource_quality_buckets(resource_id)
		var quality_counts := _resource_quality_counts[key] as Dictionary
		quality_counts[String(quality)] = int(quality_counts.get(String(quality), 0)) + amount
	return true


func set_resource_amount(resource_id: StringName, amount: int) -> bool:
	var key := String(resource_id)
	if not _resources.has(key) or amount < 0:
		return false
	_resources[key] = amount
	if resource_id != &"gold":
		_ensure_resource_quality_buckets(resource_id)
		var quality_counts := _resource_quality_counts[key] as Dictionary
		for quality in VALID_QUALITIES:
			quality_counts[String(quality)] = amount if quality == &"common" else 0
	return true


func get_resource_quality_amount(resource_id: StringName, quality: StringName) -> int:
	if resource_id == &"gold" or not VALID_QUALITIES.has(quality):
		return 0
	var quality_counts := _resource_quality_counts.get(String(resource_id), {}) as Dictionary
	return int(quality_counts.get(String(quality), 0))


func get_resource_quality_counts(resource_id: StringName) -> Dictionary:
	return (
		_resource_quality_counts.get(String(resource_id), {}) as Dictionary
	).duplicate(true)


func get_resource_sale_value(resource_id: StringName, quality: StringName) -> int:
	if not RESOURCE_SALE_VALUES.has(resource_id) or not VALID_QUALITIES.has(quality):
		return 0
	return maxi(1, roundi(
		float(RESOURCE_SALE_VALUES[resource_id]) * float(QUALITY_MULTIPLIERS[quality])
	))


func can_afford(cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	for resource_variant in cost:
		var resource_id := String(resource_variant)
		var amount_variant: Variant = cost[resource_variant]
		if not _resources.has(resource_id) or not _is_positive_whole_number(amount_variant):
			return false
		if int(_resources[resource_id]) < int(amount_variant):
			return false
	return true


func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource_variant in cost:
		var resource_id := String(resource_variant)
		var amount := int(cost[resource_variant])
		_resources[resource_id] = int(_resources[resource_id]) - amount
		if resource_id != "gold":
			_consume_resource_quality(StringName(resource_id), amount)
	return true


func can_afford_quality_resources(
	cost: Dictionary,
	quality: StringName
) -> bool:
	if cost.is_empty() or not VALID_QUALITIES.has(quality):
		return false
	for resource_variant in cost:
		var resource_id := StringName(resource_variant)
		var amount := int(cost[resource_variant])
		if amount <= 0:
			return false
		if resource_id == &"gold":
			if get_resource_amount(resource_id) < amount:
				return false
		elif get_resource_quality_amount(resource_id, quality) < amount:
			return false
	return true


func spend_quality_resources(
	cost: Dictionary,
	quality: StringName
) -> bool:
	if not can_afford_quality_resources(cost, quality):
		return false
	for resource_variant in cost:
		var resource_id := StringName(resource_variant)
		var amount := int(cost[resource_variant])
		_resources[String(resource_id)] = get_resource_amount(resource_id) - amount
		if resource_id == &"gold":
			continue
		var quality_counts := _resource_quality_counts[
			String(resource_id)
		] as Dictionary
		quality_counts[String(quality)] = int(
			quality_counts.get(String(quality), 0)
		) - amount
	return true


func get_equipment_catalog() -> Array[Dictionary]:
	return _equipment_catalog.duplicate(true)


func get_equipment_for_slot(slot: StringName) -> Array[Dictionary]:
	if not VALID_SLOTS.has(slot):
		return []
	var result: Array[Dictionary] = []
	for item in _equipment_catalog:
		if StringName(item.get("slot", "")) == slot:
			result.append(item.duplicate(true))
	return result


func get_equipment(item_id: StringName) -> Dictionary:
	var item: Dictionary = _equipment_by_id.get(String(item_id), {})
	return item.duplicate(true)


func add_equipment(item_id: StringName) -> bool:
	var key := String(item_id)
	if not _equipment_by_id.has(key) or _owned_equipment.has(key):
		return false
	return add_equipment_count(item_id, 1)


func purchase_equipment(item_id: StringName) -> bool:
	var item := get_equipment(item_id)
	if item.is_empty() or not bool(item.get("direct_purchase", false)):
		return false
	var cost := item.get("purchase_cost", {}) as Dictionary
	if cost.size() != 1 or not cost.has("gold") or not spend_resources(cost):
		return false
	if add_equipment_count(item_id, 1):
		return true
	add_resource(&"gold", int(cost.get("gold", 0)))
	return false


func get_equipment_sale_value(
	item_id: StringName,
	quality: StringName = StringName()
) -> int:
	var item := get_equipment(item_id)
	if item.is_empty():
		return 0
	var catalog_quality := StringName(item.get("quality", "common"))
	var target_quality := catalog_quality if quality.is_empty() else quality
	if not VALID_QUALITIES.has(target_quality):
		return 0
	var catalog_multiplier := float(QUALITY_MULTIPLIERS.get(catalog_quality, 1.0))
	var target_multiplier := float(QUALITY_MULTIPLIERS.get(target_quality, 1.0))
	return maxi(1, roundi(
		float(item.get("base_sale_value", 0)) * target_multiplier / catalog_multiplier
	))


func has_equipment(item_id: StringName) -> bool:
	return _owned_equipment.has(String(item_id))


func get_equipment_count(item_id: StringName) -> int:
	return int(_equipment_counts.get(String(item_id), 0))


func add_equipment_count(
	item_id: StringName,
	quantity: int,
	quality: StringName = StringName()
) -> bool:
	var key := String(item_id)
	if not _equipment_by_id.has(key) or quantity <= 0:
		return false
	var resolved_quality := quality
	if resolved_quality.is_empty():
		resolved_quality = StringName((_equipment_by_id[key] as Dictionary).get("quality", "common"))
	if not VALID_QUALITIES.has(resolved_quality):
		return false
	_equipment_counts[key] = get_equipment_count(item_id) + quantity
	_ensure_equipment_quality_buckets(item_id)
	var quality_counts := _equipment_quality_counts[key] as Dictionary
	quality_counts[String(resolved_quality)] = int(
		quality_counts.get(String(resolved_quality), 0)
	) + quantity
	_owned_equipment[key] = true
	if not _equipment_levels.has(key):
		_equipment_levels[key] = 1
	for slot in VALID_SLOTS:
		if StringName(_equipped.get(String(slot), StringName())) != item_id:
			continue
		var equipped_quality := get_equipped_quality(slot)
		if VALID_QUALITIES.find(resolved_quality) > VALID_QUALITIES.find(equipped_quality):
			_equipped_quality[String(slot)] = resolved_quality
	return true


func remove_equipment_count(
	item_id: StringName,
	quantity: int,
	quality: StringName = StringName()
) -> bool:
	var key := String(item_id)
	var current := get_equipment_count(item_id)
	if quantity <= 0 or current < quantity:
		return false
	var resolved_quality := quality
	if resolved_quality.is_empty():
		resolved_quality = get_highest_equipment_quality(item_id)
	if get_equipment_quality_count(item_id, resolved_quality) < quantity:
		return false
	var remaining := current - quantity
	for slot in VALID_SLOTS:
		if StringName(_equipped.get(String(slot), StringName())) != item_id:
			continue
		if remaining <= 0:
			return false
		if (
			get_equipped_quality(slot) == resolved_quality
			and get_equipment_quality_count(item_id, resolved_quality) <= quantity
		):
			return false
	if remaining > 0:
		_equipment_counts[key] = remaining
		var quality_counts := _equipment_quality_counts[key] as Dictionary
		quality_counts[String(resolved_quality)] = int(
			quality_counts.get(String(resolved_quality), 0)
		) - quantity
		return true
	_equipment_counts.erase(key)
	_equipment_quality_counts.erase(key)
	_owned_equipment.erase(key)
	_equipment_levels.erase(key)
	return true


func get_equipment_quality_count(item_id: StringName, quality: StringName) -> int:
	if not VALID_QUALITIES.has(quality):
		return 0
	var quality_counts := _equipment_quality_counts.get(String(item_id), {}) as Dictionary
	return int(quality_counts.get(String(quality), 0))


func get_equipment_quality_counts(item_id: StringName) -> Dictionary:
	return (
		_equipment_quality_counts.get(String(item_id), {}) as Dictionary
	).duplicate(true)


func get_highest_equipment_quality(item_id: StringName) -> StringName:
	for index in range(VALID_QUALITIES.size() - 1, -1, -1):
		var quality := VALID_QUALITIES[index]
		if get_equipment_quality_count(item_id, quality) > 0:
			return quality
	return StringName()


func get_blueprint_proficiency(blueprint_id: StringName) -> Dictionary:
	var key := String(blueprint_id)
	var state := _blueprint_proficiency.get(key, {}) as Dictionary
	if state.is_empty():
		return {"craft_count": 0, "level": 0, "awakened": false, "school": "balanced"}
	return state.duplicate(true)


func record_blueprint_craft(blueprint_id: StringName, quantity: int = 1) -> Dictionary:
	var key := String(blueprint_id)
	if key.is_empty() or quantity <= 0 or not _owned_blueprints.has(key):
		return {}
	var state := get_blueprint_proficiency(blueprint_id)
	var previous_awakened := bool(state.get("awakened", false))
	var school := StringName(state.get("school", "balanced"))
	var craft_count := int(state.get("craft_count", 0)) + quantity
	var level := mini(5, craft_count)
	state = {
		"craft_count": craft_count,
		"level": level,
		"awakened": level >= 5,
		"awakened_now": level >= 5 and not previous_awakened,
		"school": String(school),
	}
	_blueprint_proficiency[key] = {
		"craft_count": craft_count,
		"level": level,
		"awakened": level >= 5,
		"school": String(school),
	}
	return state


func set_blueprint_school(blueprint_id: StringName, school: StringName) -> bool:
	var key := String(blueprint_id)
	if not VALID_BLUEPRINT_SCHOOLS.has(school) or not _owned_blueprints.has(key):
		return false
	var state := get_blueprint_proficiency(blueprint_id)
	if not bool(state.get("awakened", false)):
		return false
	state.erase("awakened_now")
	state["school"] = String(school)
	_blueprint_proficiency[key] = state
	return true


func owns_blueprint(blueprint_id: StringName) -> bool:
	return _owned_blueprints.has(String(blueprint_id))


func grant_blueprint(blueprint_id: StringName) -> bool:
	var key := String(blueprint_id)
	if key.is_empty() or _owned_blueprints.has(key):
		return false
	_owned_blueprints[key] = true
	return true


func get_owned_blueprints() -> Array[String]:
	return _sorted_string_keys(_owned_blueprints)


func owns_tool(tool_id: StringName) -> bool:
	return _owned_tools.has(String(tool_id))


func grant_tool(tool_id: StringName) -> bool:
	var key := String(tool_id)
	if key.is_empty() or _owned_tools.has(key):
		return false
	_owned_tools[key] = true
	return true


func get_owned_tools() -> Array[String]:
	return _sorted_string_keys(_owned_tools)


func equip(item_id: StringName) -> bool:
	var key := String(item_id)
	if not _owned_equipment.has(key) or not _equipment_by_id.has(key):
		return false
	var item := _equipment_by_id[key] as Dictionary
	var slot := StringName(item.get("slot", ""))
	if not VALID_SLOTS.has(slot):
		return false
	_equipped[String(slot)] = item_id
	_equipped_quality[String(slot)] = get_highest_equipment_quality(item_id)
	return true


func unequip(slot: StringName) -> bool:
	if not VALID_SLOTS.has(slot):
		return false
	var key := String(slot)
	if StringName(_equipped.get(key, StringName())).is_empty():
		return false
	_equipped[key] = StringName()
	_equipped_quality[key] = StringName()
	return true


func get_equipped(slot: StringName) -> StringName:
	if not VALID_SLOTS.has(slot):
		return StringName()
	return StringName(_equipped.get(String(slot), StringName()))


func get_equipped_quality(slot: StringName) -> StringName:
	if not VALID_SLOTS.has(slot):
		return StringName()
	return StringName(_equipped_quality.get(String(slot), StringName()))


func get_equipped_weapon_element() -> String:
	var weapon_id := get_equipped(&"weapon")
	if weapon_id.is_empty():
		return "normal"
	var weapon := _equipment_by_id.get(String(weapon_id), {}) as Dictionary
	return String(weapon.get("primal_element", "normal"))


func get_effect_totals() -> Dictionary:
	var totals: Dictionary = {}
	for slot in VALID_SLOTS:
		var item_id := get_equipped(slot)
		if item_id.is_empty():
			continue
		var item := _equipment_by_id.get(String(item_id), {}) as Dictionary
		var effects := item.get("effects", {}) as Dictionary
		var implemented_level := mini(
			get_equipment_level(item_id),
			get_implemented_effect_level_cap(item_id)
		)
		var level_multiplier := 1.0 + 0.5 * float(implemented_level - 1)
		var catalog_quality := StringName(item.get("quality", "common"))
		var equipped_quality := get_equipped_quality(slot)
		var quality_multiplier := (
			float(QUALITY_MULTIPLIERS.get(equipped_quality, 1.0))
			/ float(QUALITY_MULTIPLIERS.get(catalog_quality, 1.0))
		)
		for effect_variant in effects:
			var effect_id := String(effect_variant)
			totals[effect_id] = (
				float(totals.get(effect_id, 0.0))
				+ float(effects[effect_variant]) * level_multiplier * quality_multiplier
			)
			if is_equal_approx(float(totals[effect_id]), roundf(float(totals[effect_id]))):
				totals[effect_id] = int(roundf(float(totals[effect_id])))
	return totals


func get_special_ability_totals() -> Dictionary:
	var totals: Dictionary = {}
	for slot in VALID_SLOTS:
		var item_id := get_equipped(slot)
		if item_id.is_empty():
			continue
		var item := _equipment_by_id.get(String(item_id), {}) as Dictionary
		if not _meets_upgrade_requirement(item):
			continue
		var ability := item.get("special_ability", {}) as Dictionary
		var catalog_quality := StringName(item.get("quality", "common"))
		var equipped_quality := get_equipped_quality(slot)
		var quality_multiplier := (
			float(QUALITY_MULTIPLIERS.get(equipped_quality, 1.0))
			/ float(QUALITY_MULTIPLIERS.get(catalog_quality, 1.0))
		)
		for key_variant in ability:
			var key := String(key_variant)
			var value: Variant = ability[key_variant]
			if value is int or value is float:
				totals[key] = (
					float(totals.get(key, 0.0)) + float(value) * quality_multiplier
				)
	return totals


func get_equipment_level(item_id: StringName) -> int:
	return int(_equipment_levels.get(String(item_id), 0))


func get_max_equipment_level() -> int:
	return MAX_EQUIPMENT_LEVEL


func get_implemented_effect_level_cap(item_id: StringName = StringName()) -> int:
	if item_id.is_empty():
		return IMPLEMENTED_EFFECT_LEVEL_CAP
	var item := _equipment_by_id.get(String(item_id), {}) as Dictionary
	return clampi(
		int(item.get("implemented_effect_level_cap", IMPLEMENTED_EFFECT_LEVEL_CAP)),
		1,
		MAX_EQUIPMENT_LEVEL
	)


func get_equipment_upgrade_cost(item_id: StringName) -> Dictionary:
	var level := get_equipment_level(item_id)
	if level <= 0 or level >= MAX_EQUIPMENT_LEVEL:
		return {}
	# OB only defines exact per-level runtime costs through Lv.3. Later milestone
	# recipes remain unavailable until their theme-material authorities exist.
	if level >= IMPLEMENTED_EFFECT_LEVEL_CAP:
		return {}
	return {
		"gold": 25 * level,
		"autumn_wood": 5 * level,
		"magic_shard": 2 * level,
	}


func upgrade_equipment(item_id: StringName) -> bool:
	var key := String(item_id)
	if not _owned_equipment.has(key):
		return false
	var cost := get_equipment_upgrade_cost(item_id)
	if cost.is_empty() or not spend_resources(cost):
		return false
	_equipment_levels[key] = int(_equipment_levels[key]) + 1
	return true


func set_progression_unlocks(unlocks: Dictionary) -> void:
	_progression_unlocks = unlocks.duplicate(true)


func set_sale_slot_capacity(capacity: int) -> void:
	var resolved_capacity := maxi(1, capacity)
	while _sale_slots.size() < resolved_capacity:
		_sale_slots.append({})
	while _sale_slots.size() > resolved_capacity and (
		_sale_slots[_sale_slots.size() - 1] as Dictionary
	).is_empty():
		_sale_slots.pop_back()


func get_sale_slot_capacity() -> int:
	return _sale_slots.size()


func get_sale_slot(slot_index: int = 0) -> Dictionary:
	if slot_index < 0 or slot_index >= _sale_slots.size():
		return {}
	return (_sale_slots[slot_index] as Dictionary).duplicate(true)


func get_sale_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _sale_slots:
		result.append(slot.duplicate(true))
	return result


func list_equipment_for_sale(
	item_id: StringName,
	quantity: int,
	unit_price: int,
	quality: StringName = StringName(),
	metadata: Dictionary = {},
	slot_index: int = 0
) -> bool:
	if not _sale_slot_available(slot_index) or quantity <= 0 or unit_price <= 0:
		return false
	var resolved_quality := quality
	if resolved_quality.is_empty():
		resolved_quality = get_highest_equipment_quality(item_id)
	if not remove_equipment_count(item_id, quantity, resolved_quality):
		return false
	_sale_slots[slot_index] = {
		"item_kind": "equipment",
		"item_id": String(item_id),
		"quality": String(resolved_quality),
		"quantity": quantity,
		"unit_price": unit_price,
	}
	_apply_sale_metadata(slot_index, metadata)
	return true


func list_resource_for_sale(
	resource_id: StringName,
	quantity: int,
	unit_price: int,
	quality: StringName = &"common",
	metadata: Dictionary = {},
	slot_index: int = 0
) -> bool:
	if (
		not _sale_slot_available(slot_index)
		or resource_id == &"gold"
		or quantity <= 0
		or unit_price <= 0
		or get_resource_quality_amount(resource_id, quality) < quantity
	):
		return false
	_resources[String(resource_id)] = get_resource_amount(resource_id) - quantity
	var quality_counts := _resource_quality_counts[String(resource_id)] as Dictionary
	quality_counts[String(quality)] = int(quality_counts.get(String(quality), 0)) - quantity
	_sale_slots[slot_index] = {
		"item_kind": "resource",
		"item_id": String(resource_id),
		"quality": String(quality),
		"quantity": quantity,
		"unit_price": unit_price,
	}
	_apply_sale_metadata(slot_index, metadata)
	return true


func resolve_sale(slot_index: int = 0) -> Dictionary:
	if not _sale_slot_occupied(slot_index):
		return {}
	var slot := _sale_slots[slot_index] as Dictionary
	var quantity := int(slot.get("quantity", 0))
	var unit_price := int(slot.get("unit_price", 0))
	var gold := quantity * unit_price
	if gold <= 0 or not add_resource(&"gold", gold):
		return {}
	var result := slot.duplicate(true)
	result["shelf_index"] = slot_index
	result["gold"] = gold
	_sale_slots[slot_index] = {}
	return result


func mark_sale_declined(slot_index: int = 0) -> bool:
	if not _sale_slot_occupied(slot_index):
		return false
	(_sale_slots[slot_index] as Dictionary)["customer_state"] = "declined"
	return true


func cancel_sale(slot_index: int = 0) -> bool:
	if not _sale_slot_occupied(slot_index):
		return false
	var slot := _sale_slots[slot_index] as Dictionary
	var item_id := StringName(slot.get("item_id", ""))
	var item_kind := StringName(slot.get("item_kind", "equipment"))
	var quality := StringName(slot.get("quality", "common"))
	var quantity := int(slot.get("quantity", 0))
	var restored := (
		add_resource(item_id, quantity, quality)
		if item_kind == &"resource"
		else add_equipment_count(item_id, quantity, quality)
	)
	if not restored:
		return false
	_sale_slots[slot_index] = {}
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"resources": _resources.duplicate(true),
		"resource_quality_counts": _resource_quality_counts.duplicate(true),
		"owned_equipment": _sorted_string_keys(_owned_equipment),
		"equipment_counts": _equipment_counts.duplicate(true),
		"equipment_quality_counts": _equipment_quality_counts.duplicate(true),
		"equipment_levels": _equipment_levels.duplicate(true),
		"equipped": _equipped.duplicate(true),
		"equipped_quality": _equipped_quality.duplicate(true),
		"owned_blueprints": get_owned_blueprints(),
		"blueprint_proficiency": _blueprint_proficiency.duplicate(true),
		"owned_tools": get_owned_tools(),
		"sale_slots": get_sale_slots(),
	}


func apply_dict(data: Dictionary) -> void:
	var saved_resources: Variant = data.get("resources", {})
	if saved_resources is Dictionary:
		for resource_id in _resource_ids:
			var key := String(resource_id)
			if saved_resources.has(key):
				_resources[key] = maxi(0, int(saved_resources[key]))
	_restore_resource_quality_counts(data.get("resource_quality_counts", {}))
	_owned_equipment.clear()
	_equipment_counts.clear()
	_equipment_quality_counts.clear()
	_equipment_levels.clear()
	var saved_counts: Variant = data.get("equipment_counts", {})
	if saved_counts is Dictionary and not (saved_counts as Dictionary).is_empty():
		for item_id_variant in saved_counts:
			var item_id := String(item_id_variant)
			var count := maxi(0, int((saved_counts as Dictionary)[item_id_variant]))
			if _equipment_by_id.has(item_id) and count > 0:
				_equipment_counts[item_id] = count
				_restore_equipment_quality_count(item_id, count, data.get("equipment_quality_counts", {}))
				_owned_equipment[item_id] = true
				_equipment_levels[item_id] = 1
	else:
		var owned: Variant = data.get("owned_equipment", [])
		if owned is Array:
			for item_id_variant in owned:
				var item_id := String(item_id_variant)
				if _equipment_by_id.has(item_id):
					_equipment_counts[item_id] = 1
					_restore_equipment_quality_count(item_id, 1, {})
					_owned_equipment[item_id] = true
					_equipment_levels[item_id] = 1
	var saved_levels: Variant = data.get("equipment_levels", {})
	if saved_levels is Dictionary:
		for item_id in _owned_equipment:
			_equipment_levels[item_id] = clampi(
				int(saved_levels.get(item_id, 1)),
				1,
				MAX_EQUIPMENT_LEVEL
			)
	var saved_equipped: Variant = data.get("equipped", {})
	for slot in VALID_SLOTS:
		_equipped[String(slot)] = StringName()
		_equipped_quality[String(slot)] = StringName()
	if saved_equipped is Dictionary:
		for slot in VALID_SLOTS:
			var item_id := StringName(saved_equipped.get(String(slot), StringName()))
			if item_id.is_empty():
				_equipped[String(slot)] = StringName()
			elif _owned_equipment.has(String(item_id)) and StringName((_equipment_by_id[String(item_id)] as Dictionary).get("slot", "")) == slot:
				_equipped[String(slot)] = item_id
				var saved_equipped_quality := data.get("equipped_quality", {}) as Dictionary
				var quality := StringName(saved_equipped_quality.get(String(slot), ""))
				_equipped_quality[String(slot)] = (
					quality
					if get_equipment_quality_count(item_id, quality) > 0
					else get_highest_equipment_quality(item_id)
				)
	_owned_blueprints = _string_array_to_set(data.get("owned_blueprints", []))
	_restore_blueprint_proficiency(data.get("blueprint_proficiency", {}))
	_owned_tools = _string_array_to_set(data.get("owned_tools", []))
	_sale_slots = []
	var saved_sale_slots: Variant = data.get("sale_slots", [])
	if saved_sale_slots is Array and not (saved_sale_slots as Array).is_empty():
		for saved_slot_variant in saved_sale_slots:
			_sale_slots.append(_validated_sale_slot(saved_slot_variant))
	else:
		_sale_slots.append(_validated_sale_slot(data.get("sale_slot", {})))
	if _sale_slots.is_empty():
		_sale_slots.append({})


func _load_data(data_path: String) -> void:
	if not FileAccess.file_exists(data_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	var resource_order: Array = data.get("resource_order", [])
	var starting_resources := data.get("starting_resources", {}) as Dictionary
	var equipment: Array = data.get("equipment", [])
	if resource_order.is_empty() or starting_resources.is_empty() or equipment.is_empty():
		return

	for resource_variant in resource_order:
		var resource_id := StringName(String(resource_variant))
		var key := String(resource_id)
		if resource_id.is_empty() or not starting_resources.has(key):
			return
		var amount_variant: Variant = starting_resources[key]
		if not _is_non_negative_whole_number(amount_variant):
			return
		_resource_ids.append(resource_id)
		_resources[key] = int(amount_variant)
		if resource_id != &"gold":
			_ensure_resource_quality_buckets(resource_id)
			var quality_counts := _resource_quality_counts[key] as Dictionary
			quality_counts["common"] = int(amount_variant)

	for item_variant in equipment:
		if not item_variant is Dictionary:
			return
		var item := (item_variant as Dictionary).duplicate(true)
		var item_id := String(item.get("id", ""))
		var slot := StringName(item.get("slot", ""))
		var effects := item.get("effects", {}) as Dictionary
		var direct_purchase := bool(item.get("direct_purchase", false))
		var purchase_cost := item.get("purchase_cost", {}) as Dictionary
		var quality := StringName(item.get("quality", ""))
		var material_tier := StringName(item.get("material_tier", ""))
		var base_sale_value: Variant = item.get("base_sale_value", 0)
		if item_id.is_empty() or _equipment_by_id.has(item_id):
			return
		if (
			not VALID_SLOTS.has(slot)
			or effects.is_empty()
			or not VALID_QUALITIES.has(quality)
			or not VALID_MATERIAL_TIERS.has(material_tier)
			or not _is_positive_whole_number(base_sale_value)
		):
			return
		if direct_purchase and (purchase_cost.size() != 1 or not purchase_cost.has("gold")):
			return
		if (
			slot == &"weapon"
			and not bool(
				_element_taxonomy.call(
					"is_valid",
					String(item.get("primal_element", ""))
				)
			)
		):
			return
		for cost_value in purchase_cost.values():
			if not _is_positive_whole_number(cost_value):
				return
		for effect_value in effects.values():
			if not effect_value is int and not effect_value is float:
				return
		_equipment_catalog.append(item)
		_equipment_by_id[item_id] = item
	_loaded = true


func _is_positive_whole_number(value: Variant) -> bool:
	return _is_non_negative_whole_number(value) and int(value) > 0


func _is_non_negative_whole_number(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return number >= 0.0 and is_equal_approx(number, floorf(number))


func _meets_upgrade_requirement(item: Dictionary) -> bool:
	var requirement := String(item.get("upgrade_requirement", ""))
	return requirement.is_empty() or bool(_progression_unlocks.get(requirement, false))


func _ensure_resource_quality_buckets(resource_id: StringName) -> void:
	var key := String(resource_id)
	if not _resource_quality_counts.has(key):
		_resource_quality_counts[key] = {}
	var quality_counts := _resource_quality_counts[key] as Dictionary
	for quality in VALID_QUALITIES:
		if not quality_counts.has(String(quality)):
			quality_counts[String(quality)] = 0


func _ensure_equipment_quality_buckets(item_id: StringName) -> void:
	var key := String(item_id)
	if not _equipment_quality_counts.has(key):
		_equipment_quality_counts[key] = {}
	var quality_counts := _equipment_quality_counts[key] as Dictionary
	for quality in VALID_QUALITIES:
		if not quality_counts.has(String(quality)):
			quality_counts[String(quality)] = 0


func _consume_resource_quality(resource_id: StringName, amount: int) -> void:
	_ensure_resource_quality_buckets(resource_id)
	var remaining := amount
	var quality_counts := _resource_quality_counts[String(resource_id)] as Dictionary
	for quality in VALID_QUALITIES:
		if remaining <= 0:
			break
		var available := int(quality_counts.get(String(quality), 0))
		var consumed := mini(available, remaining)
		quality_counts[String(quality)] = available - consumed
		remaining -= consumed


func _restore_resource_quality_counts(saved_variant: Variant) -> void:
	var saved := saved_variant as Dictionary if saved_variant is Dictionary else {}
	for resource_id in _resource_ids:
		if resource_id == &"gold":
			continue
		_ensure_resource_quality_buckets(resource_id)
		var key := String(resource_id)
		var source := saved.get(key, {}) as Dictionary
		var quality_counts := _resource_quality_counts[key] as Dictionary
		var assigned := 0
		for quality in VALID_QUALITIES:
			var amount := maxi(0, int(source.get(String(quality), 0)))
			quality_counts[String(quality)] = amount
			assigned += amount
		if source.is_empty() or assigned != int(_resources.get(key, 0)):
			for quality in VALID_QUALITIES:
				quality_counts[String(quality)] = (
					int(_resources.get(key, 0)) if quality == &"common" else 0
				)


func _restore_equipment_quality_count(
	item_id: String,
	total_count: int,
	saved_variant: Variant
) -> void:
	_ensure_equipment_quality_buckets(StringName(item_id))
	var saved := saved_variant as Dictionary if saved_variant is Dictionary else {}
	var source := saved.get(item_id, {}) as Dictionary
	var quality_counts := _equipment_quality_counts[item_id] as Dictionary
	var assigned := 0
	for quality in VALID_QUALITIES:
		var amount := maxi(0, int(source.get(String(quality), 0)))
		quality_counts[String(quality)] = amount
		assigned += amount
	if source.is_empty() or assigned != total_count:
		var catalog_quality := StringName(
			(_equipment_by_id[item_id] as Dictionary).get("quality", "common")
		)
		for quality in VALID_QUALITIES:
			quality_counts[String(quality)] = total_count if quality == catalog_quality else 0


func _restore_blueprint_proficiency(saved_variant: Variant) -> void:
	_blueprint_proficiency.clear()
	if not saved_variant is Dictionary:
		return
	for blueprint_variant in saved_variant:
		var blueprint_id := String(blueprint_variant)
		if not _owned_blueprints.has(blueprint_id):
			continue
		var saved_state := (saved_variant as Dictionary).get(blueprint_id, {}) as Dictionary
		var craft_count := maxi(0, int(saved_state.get("craft_count", 0)))
		var level := clampi(int(saved_state.get("level", mini(5, craft_count))), 0, 5)
		var school := StringName(saved_state.get("school", "balanced"))
		if not VALID_BLUEPRINT_SCHOOLS.has(school):
			school = &"balanced"
		_blueprint_proficiency[blueprint_id] = {
			"craft_count": craft_count,
			"level": level,
			"awakened": level >= 5 and bool(saved_state.get("awakened", true)),
			"school": String(school),
		}


func _apply_sale_metadata(slot_index: int, metadata: Dictionary) -> void:
	if not _sale_slot_occupied(slot_index):
		return
	var slot := _sale_slots[slot_index] as Dictionary
	for key in [
		"base_unit_price",
		"price_strategy",
		"price_multiplier",
		"sale_chance",
		"rumor_id",
		"rumor_title",
		"customer_id",
		"customer_name",
		"customer_state",
		"rumor_multiplier",
	]:
		if metadata.has(key):
			slot[key] = metadata[key]


func _sale_slot_available(slot_index: int) -> bool:
	return (
		slot_index >= 0
		and slot_index < _sale_slots.size()
		and (_sale_slots[slot_index] as Dictionary).is_empty()
	)


func _sale_slot_occupied(slot_index: int) -> bool:
	return (
		slot_index >= 0
		and slot_index < _sale_slots.size()
		and not (_sale_slots[slot_index] as Dictionary).is_empty()
	)


func _validated_sale_slot(saved_variant: Variant) -> Dictionary:
	if not saved_variant is Dictionary:
		return {}
	var saved := saved_variant as Dictionary
	var item_id := String(saved.get("item_id", ""))
	var item_kind := StringName(saved.get("item_kind", "equipment"))
	var quality := StringName(saved.get("quality", ""))
	var quantity := int(saved.get("quantity", 0))
	var unit_price := int(saved.get("unit_price", 0))
	if quality.is_empty() and _equipment_by_id.has(item_id):
		quality = StringName(
			(_equipment_by_id[item_id] as Dictionary).get("quality", "common")
		)
	var valid_item := (
		item_kind == &"equipment" and _equipment_by_id.has(item_id)
		or item_kind == &"resource" and RESOURCE_SALE_VALUES.has(StringName(item_id))
	)
	if not valid_item or not VALID_QUALITIES.has(quality) or quantity <= 0 or unit_price <= 0:
		return {}
	var result := {
		"item_kind": String(item_kind),
		"item_id": item_id,
		"quality": String(quality),
		"quantity": quantity,
		"unit_price": unit_price,
	}
	for key in [
		"base_unit_price", "price_strategy", "price_multiplier", "sale_chance",
		"rumor_id", "rumor_title", "customer_id", "customer_name",
		"customer_state", "rumor_multiplier",
	]:
		if saved.has(key):
			result[key] = saved[key]
	return result


func _sorted_string_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant in source:
		result.append(String(key_variant))
	result.sort()
	return result


func _string_array_to_set(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Array:
		return result
	for entry_variant in value:
		var entry := String(entry_variant)
		if not entry.is_empty():
			result[entry] = true
	return result
