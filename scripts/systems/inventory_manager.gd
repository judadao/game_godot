extends RefCounted

const DEFAULT_DATA_PATH := "res://data/equipment.json"
const SAVE_SCHEMA_VERSION := 3
const VALID_SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]
const VALID_QUALITIES: Array[StringName] = [&"common", &"rare", &"exceptional"]
const VALID_MATERIAL_TIERS: Array[StringName] = [&"normal", &"elite", &"boss"]
const MAX_EQUIPMENT_LEVEL := 15
const IMPLEMENTED_EFFECT_LEVEL_CAP := 3
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")

var _loaded := false
var _resource_ids: Array[StringName] = []
var _resources: Dictionary = {}
var _equipment_catalog: Array[Dictionary] = []
var _equipment_by_id: Dictionary = {}
var _owned_equipment: Dictionary = {}
var _equipment_counts: Dictionary = {}
var _equipment_levels: Dictionary = {}
var _owned_blueprints: Dictionary = {}
var _owned_tools: Dictionary = {}
var _sale_slot: Dictionary = {}
var _progression_unlocks: Dictionary = {}
var _equipped: Dictionary = {
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


func add_resource(resource_id: StringName, amount: int) -> bool:
	var key := String(resource_id)
	if not _resources.has(key) or amount <= 0:
		return false
	_resources[key] = int(_resources[key]) + amount
	return true


func set_resource_amount(resource_id: StringName, amount: int) -> bool:
	var key := String(resource_id)
	if not _resources.has(key) or amount < 0:
		return false
	_resources[key] = amount
	return true


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
		_resources[resource_id] = int(_resources[resource_id]) - int(cost[resource_variant])
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


func get_equipment_sale_value(item_id: StringName) -> int:
	var item := get_equipment(item_id)
	return maxi(0, int(item.get("base_sale_value", 0)))


func has_equipment(item_id: StringName) -> bool:
	return _owned_equipment.has(String(item_id))


func get_equipment_count(item_id: StringName) -> int:
	return int(_equipment_counts.get(String(item_id), 0))


func add_equipment_count(item_id: StringName, quantity: int) -> bool:
	var key := String(item_id)
	if not _equipment_by_id.has(key) or quantity <= 0:
		return false
	_equipment_counts[key] = get_equipment_count(item_id) + quantity
	_owned_equipment[key] = true
	if not _equipment_levels.has(key):
		_equipment_levels[key] = 1
	return true


func remove_equipment_count(item_id: StringName, quantity: int) -> bool:
	var key := String(item_id)
	var current := get_equipment_count(item_id)
	if quantity <= 0 or current < quantity:
		return false
	var remaining := current - quantity
	for slot in VALID_SLOTS:
		if StringName(_equipped.get(String(slot), StringName())) == item_id and remaining <= 0:
			return false
	if remaining > 0:
		_equipment_counts[key] = remaining
		return true
	_equipment_counts.erase(key)
	_owned_equipment.erase(key)
	_equipment_levels.erase(key)
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
	return true


func unequip(slot: StringName) -> bool:
	if not VALID_SLOTS.has(slot):
		return false
	var key := String(slot)
	if StringName(_equipped.get(key, StringName())).is_empty():
		return false
	_equipped[key] = StringName()
	return true


func get_equipped(slot: StringName) -> StringName:
	if not VALID_SLOTS.has(slot):
		return StringName()
	return StringName(_equipped.get(String(slot), StringName()))


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
		for effect_variant in effects:
			var effect_id := String(effect_variant)
			totals[effect_id] = float(totals.get(effect_id, 0.0)) + float(effects[effect_variant]) * level_multiplier
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
		for key_variant in ability:
			var key := String(key_variant)
			var value: Variant = ability[key_variant]
			if value is int or value is float:
				totals[key] = float(totals.get(key, 0.0)) + float(value)
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


func get_sale_slot() -> Dictionary:
	return _sale_slot.duplicate(true)


func list_equipment_for_sale(
	item_id: StringName,
	quantity: int,
	unit_price: int
) -> bool:
	if not _sale_slot.is_empty() or quantity <= 0 or unit_price <= 0:
		return false
	if not remove_equipment_count(item_id, quantity):
		return false
	_sale_slot = {
		"item_id": String(item_id),
		"quantity": quantity,
		"unit_price": unit_price,
	}
	return true


func resolve_sale() -> Dictionary:
	if _sale_slot.is_empty():
		return {}
	var quantity := int(_sale_slot.get("quantity", 0))
	var unit_price := int(_sale_slot.get("unit_price", 0))
	var gold := quantity * unit_price
	if gold <= 0 or not add_resource(&"gold", gold):
		return {}
	var result := _sale_slot.duplicate(true)
	result["gold"] = gold
	_sale_slot.clear()
	return result


func cancel_sale() -> bool:
	if _sale_slot.is_empty():
		return false
	var item_id := StringName(_sale_slot.get("item_id", ""))
	var quantity := int(_sale_slot.get("quantity", 0))
	if not add_equipment_count(item_id, quantity):
		return false
	_sale_slot.clear()
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"resources": _resources.duplicate(true),
		"owned_equipment": _sorted_string_keys(_owned_equipment),
		"equipment_counts": _equipment_counts.duplicate(true),
		"equipment_levels": _equipment_levels.duplicate(true),
		"equipped": _equipped.duplicate(true),
		"owned_blueprints": get_owned_blueprints(),
		"owned_tools": get_owned_tools(),
		"sale_slot": _sale_slot.duplicate(true),
	}


func apply_dict(data: Dictionary) -> void:
	var saved_resources: Variant = data.get("resources", {})
	if saved_resources is Dictionary:
		for resource_id in _resource_ids:
			var key := String(resource_id)
			if saved_resources.has(key):
				_resources[key] = maxi(0, int(saved_resources[key]))
	_owned_equipment.clear()
	_equipment_counts.clear()
	_equipment_levels.clear()
	var saved_counts: Variant = data.get("equipment_counts", {})
	if saved_counts is Dictionary and not (saved_counts as Dictionary).is_empty():
		for item_id_variant in saved_counts:
			var item_id := String(item_id_variant)
			var count := maxi(0, int((saved_counts as Dictionary)[item_id_variant]))
			if _equipment_by_id.has(item_id) and count > 0:
				_equipment_counts[item_id] = count
				_owned_equipment[item_id] = true
				_equipment_levels[item_id] = 1
	else:
		var owned: Variant = data.get("owned_equipment", [])
		if owned is Array:
			for item_id_variant in owned:
				var item_id := String(item_id_variant)
				if _equipment_by_id.has(item_id):
					_equipment_counts[item_id] = 1
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
	if saved_equipped is Dictionary:
		for slot in VALID_SLOTS:
			var item_id := StringName(saved_equipped.get(String(slot), StringName()))
			if item_id.is_empty():
				_equipped[String(slot)] = StringName()
			elif _owned_equipment.has(String(item_id)) and StringName((_equipment_by_id[String(item_id)] as Dictionary).get("slot", "")) == slot:
				_equipped[String(slot)] = item_id
	_owned_blueprints = _string_array_to_set(data.get("owned_blueprints", []))
	_owned_tools = _string_array_to_set(data.get("owned_tools", []))
	_sale_slot.clear()
	var saved_sale_slot: Variant = data.get("sale_slot", {})
	if saved_sale_slot is Dictionary:
		var item_id := String((saved_sale_slot as Dictionary).get("item_id", ""))
		var quantity := int((saved_sale_slot as Dictionary).get("quantity", 0))
		var unit_price := int((saved_sale_slot as Dictionary).get("unit_price", 0))
		if _equipment_by_id.has(item_id) and quantity > 0 and unit_price > 0:
			_sale_slot = {
				"item_id": item_id,
				"quantity": quantity,
				"unit_price": unit_price,
			}


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
