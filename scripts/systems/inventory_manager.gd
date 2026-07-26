extends RefCounted

const DEFAULT_DATA_PATH := "res://data/equipment.json"
const VALID_SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]

var _loaded := false
var _resource_ids: Array[StringName] = []
var _resources: Dictionary = {}
var _equipment_catalog: Array[Dictionary] = []
var _equipment_by_id: Dictionary = {}
var _owned_equipment: Dictionary = {}
var _equipment_levels: Dictionary = {}
var _progression_unlocks: Dictionary = {}
var _equipped: Dictionary = {
	"weapon": StringName(),
	"armor": StringName(),
	"accessory": StringName(),
}


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


func add_resources(resources: Dictionary) -> bool:
	if resources.is_empty():
		return false
	for resource_id in resources:
		var key := String(resource_id)
		if not _resources.has(key) or not _is_positive_whole_number(resources[resource_id]):
			return false
	for resource_id in resources:
		var key := String(resource_id)
		_resources[key] = int(_resources[key]) + int(resources[resource_id])
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
	_owned_equipment[key] = true
	_equipment_levels[key] = 1
	return true


func purchase_equipment(item_id: StringName) -> bool:
	var item := get_equipment(item_id)
	if item.is_empty() or has_equipment(item_id):
		return false
	var cost := item.get("purchase_cost", {}) as Dictionary
	if cost.is_empty() or not spend_resources(cost):
		return false
	return add_equipment(item_id)


func has_equipment(item_id: StringName) -> bool:
	return _owned_equipment.has(String(item_id))


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


func get_effect_totals() -> Dictionary:
	var totals: Dictionary = {}
	for slot in VALID_SLOTS:
		var item_id := get_equipped(slot)
		if item_id.is_empty():
			continue
		var item := _equipment_by_id.get(String(item_id), {}) as Dictionary
		var effects := item.get("effects", {}) as Dictionary
		var level_multiplier := 1.0 + 0.5 * float(get_equipment_level(item_id) - 1)
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


func get_equipment_upgrade_cost(item_id: StringName) -> Dictionary:
	var level := get_equipment_level(item_id)
	if level <= 0 or level >= 3:
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
	var item := _equipment_by_id.get(key, {}) as Dictionary
	if not _meets_upgrade_requirement(item):
		return false
	var cost := get_equipment_upgrade_cost(item_id)
	if cost.is_empty() or not spend_resources(cost):
		return false
	_equipment_levels[key] = int(_equipment_levels[key]) + 1
	return true


func set_progression_unlocks(unlocks: Dictionary) -> void:
	_progression_unlocks = unlocks.duplicate(true)


func to_dict() -> Dictionary:
	return {
		"resources": _resources.duplicate(true),
		"owned_equipment": _owned_equipment.keys(),
		"equipment_levels": _equipment_levels.duplicate(true),
		"equipped": _equipped.duplicate(true),
	}


func apply_dict(data: Dictionary) -> void:
	var saved_resources: Variant = data.get("resources", {})
	if saved_resources is Dictionary:
		for resource_id in _resource_ids:
			var key := String(resource_id)
			if saved_resources.has(key):
				_resources[key] = maxi(0, int(saved_resources[key]))
	_owned_equipment.clear()
	_equipment_levels.clear()
	var owned: Variant = data.get("owned_equipment", [])
	if owned is Array:
		for item_id_variant in owned:
			var item_id := String(item_id_variant)
			if _equipment_by_id.has(item_id):
				_owned_equipment[item_id] = true
				_equipment_levels[item_id] = 1
	var saved_levels: Variant = data.get("equipment_levels", {})
	if saved_levels is Dictionary:
		for item_id in _owned_equipment:
			_equipment_levels[item_id] = clampi(int(saved_levels.get(item_id, 1)), 1, 3)
	var saved_equipped: Variant = data.get("equipped", {})
	if saved_equipped is Dictionary:
		for slot in VALID_SLOTS:
			var item_id := StringName(saved_equipped.get(String(slot), StringName()))
			if item_id.is_empty():
				_equipped[String(slot)] = StringName()
			elif _owned_equipment.has(String(item_id)) and StringName((_equipment_by_id[String(item_id)] as Dictionary).get("slot", "")) == slot:
				_equipped[String(slot)] = item_id


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
		var purchase_cost := item.get("purchase_cost", {}) as Dictionary
		if item_id.is_empty() or _equipment_by_id.has(item_id):
			return
		if not VALID_SLOTS.has(slot) or effects.is_empty() or purchase_cost.is_empty():
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
