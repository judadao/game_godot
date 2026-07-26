extends RefCounted

const DEFAULT_DATA_PATH := "res://data/town_upgrades.json"

var _loaded := false
var _inventory: RefCounted
var _buildings: Array[Dictionary] = []
var _building_by_id: Dictionary = {}
var _building_levels: Dictionary = {}
var _stages: Array[Dictionary] = []


func _init(
	inventory_manager: RefCounted = null,
	data_path: String = DEFAULT_DATA_PATH
) -> void:
	_inventory = inventory_manager
	_load_data(data_path)


func is_loaded() -> bool:
	return _loaded


func set_inventory(inventory_manager: RefCounted) -> void:
	_inventory = inventory_manager


func get_building_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for building in _buildings:
		result.append(StringName(building.get("id", "")))
	return result


func get_building_level(building_id: StringName) -> int:
	return int(_building_levels.get(String(building_id), 0))


func get_max_building_level(building_id: StringName) -> int:
	var building := _building_by_id.get(String(building_id), {}) as Dictionary
	return (building.get("upgrades", []) as Array).size()


func get_next_upgrade_cost(building_id: StringName) -> Dictionary:
	var building := _building_by_id.get(String(building_id), {}) as Dictionary
	if building.is_empty():
		return {}
	var current_level := get_building_level(building_id)
	var upgrades := building.get("upgrades", []) as Array
	if current_level < 0 or current_level >= upgrades.size():
		return {}
	var upgrade := upgrades[current_level] as Dictionary
	return (upgrade.get("cost", {}) as Dictionary).duplicate(true)


func can_upgrade_building(building_id: StringName) -> bool:
	if _inventory == null or not _building_by_id.has(String(building_id)):
		return false
	var cost := get_next_upgrade_cost(building_id)
	if cost.is_empty() or not _inventory.has_method("can_afford"):
		return false
	return bool(_inventory.call("can_afford", cost))


func upgrade_building(building_id: StringName) -> bool:
	if not can_upgrade_building(building_id):
		return false
	var cost := get_next_upgrade_cost(building_id)
	if not _inventory.has_method("spend_resources"):
		return false
	if not bool(_inventory.call("spend_resources", cost)):
		return false
	var key := String(building_id)
	_building_levels[key] = int(_building_levels[key]) + 1
	return true


func get_total_building_levels() -> int:
	var total := 0
	for level_variant in _building_levels.values():
		total += int(level_variant)
	return total


func get_village_stage() -> int:
	var stage_index := 0
	var total_levels := get_total_building_levels()
	for index in _stages.size():
		var stage := _stages[index]
		if total_levels >= int(stage.get("minimum_total_levels", 0)):
			stage_index = index
	return stage_index


func get_village_stage_id() -> StringName:
	if _stages.is_empty():
		return StringName()
	return StringName(_stages[get_village_stage()].get("id", ""))


func get_visual_projection() -> Dictionary:
	var projection: Dictionary = {}
	for stage in _stages:
		for flag_variant in stage.get("visual_flags", []) as Array:
			projection[String(flag_variant)] = false
	for building in _buildings:
		for upgrade_variant in building.get("upgrades", []) as Array:
			var upgrade := upgrade_variant as Dictionary
			projection[String(upgrade.get("visual_flag", ""))] = false

	var current_stage := get_village_stage()
	for stage_index in range(current_stage + 1):
		var stage := _stages[stage_index]
		for flag_variant in stage.get("visual_flags", []) as Array:
			projection[String(flag_variant)] = true

	for building in _buildings:
		var building_id := StringName(building.get("id", ""))
		var level := get_building_level(building_id)
		var upgrades := building.get("upgrades", []) as Array
		for upgrade_index in range(mini(level, upgrades.size())):
			var upgrade := upgrades[upgrade_index] as Dictionary
			projection[String(upgrade.get("visual_flag", ""))] = true
	return projection


func to_dict() -> Dictionary:
	return {"building_levels": _building_levels.duplicate(true)}


func apply_dict(data: Dictionary) -> void:
	var saved_levels: Variant = data.get("building_levels", {})
	if not saved_levels is Dictionary:
		return
	for building_id in _building_levels:
		_building_levels[building_id] = clampi(
			int(saved_levels.get(building_id, _building_levels[building_id])),
			0,
			get_max_building_level(StringName(building_id))
		)


func _load_data(data_path: String) -> void:
	if not FileAccess.file_exists(data_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	var buildings: Array = data.get("buildings", [])
	var stages: Array = data.get("village_stages", [])
	if buildings.is_empty() or stages.size() != 3:
		return

	for building_variant in buildings:
		if not building_variant is Dictionary:
			return
		var building := (building_variant as Dictionary).duplicate(true)
		var building_id := String(building.get("id", ""))
		var upgrades := building.get("upgrades", []) as Array
		if building_id.is_empty() or _building_by_id.has(building_id) or upgrades.is_empty():
			return
		for index in upgrades.size():
			var upgrade := upgrades[index] as Dictionary
			if int(upgrade.get("level", -1)) != index + 1:
				return
			if (upgrade.get("cost", {}) as Dictionary).is_empty():
				return
			if String(upgrade.get("visual_flag", "")).is_empty():
				return
		_buildings.append(building)
		_building_by_id[building_id] = building
		_building_levels[building_id] = 0

	var previous_threshold := -1
	for stage_variant in stages:
		if not stage_variant is Dictionary:
			return
		var stage := (stage_variant as Dictionary).duplicate(true)
		var stage_id := String(stage.get("id", ""))
		var threshold := int(stage.get("minimum_total_levels", -1))
		var flags := stage.get("visual_flags", []) as Array
		if stage_id.is_empty() or threshold <= previous_threshold or flags.is_empty():
			return
		_stages.append(stage)
		previous_threshold = threshold
	_loaded = true
