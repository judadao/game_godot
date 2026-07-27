class_name MetaState
extends RefCounted

const SCHEMA_VERSION := 7
const RESOURCE_IDS := ["gold", "autumn_wood", "stone", "magic_shard", "autumn_core"]
const RETIRED_CARD_IDS := ["quickstep"]
const EXPANDED_COMBO_CARD_IDS := [
	"sweeping_reach",
	"quickened_cadence",
	"crushing_momentum",
	"keen_focus_combo",
	"storm_charge",
]
var resources := {
	"gold": 0,
	"autumn_wood": 0,
	"stone": 0,
	"magic_shard": 0,
	"autumn_core": 0,
}
var village_level := 1
var building_levels := {
	"mayor": 1,
	"blacksmith": 1,
	"mage_tower": 1,
	"guild": 1,
	"shop": 1,
}
var unlocked_cards: Array[String] = [
	"ember_bolt", "cleave", "guard", "iron_skin",
	"dash_strike", "healing_light", "frost_bind", "energy_surge",
	"renewal", "blood_pact_combo", "verdant_renewal",
	"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
	"sweeping_reach", "quickened_cadence", "crushing_momentum",
	"keen_focus_combo", "storm_charge",
]
var selected_deck: Array[String] = [
	"guard", "guard", "iron_skin", "healing_light", "renewal",
	"blood_pact_combo", "verdant_renewal",
	"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
	"sweeping_reach", "quickened_cadence", "crushing_momentum",
	"keen_focus_combo", "storm_charge",
]
var auto_attack_card_id := "ember_bolt"
var permanent_card_levels: Dictionary = {}
var selected_card_instances: Array[CardInstance] = []
var equipment := {"weapon": "", "armor": "", "accessory": ""}
var equipment_levels: Dictionary = {}
var unlocked_combos: Array[String] = []
var unlocked_evolutions: Array[String] = []
var learned_skill_ids: Array[String] = ["iron_momentum"]
var active_skill_ids: Array[String] = ["iron_momentum"]
var boss_defeated := false
var dash_upgrade_unlocked := false
var shortcuts: Dictionary = {}
var settings := {"master_volume": 1.0, "camera_shake": 0.65}
var inventory_state: Dictionary = {}
var town_state: Dictionary = {}
var _last_migration_report: Dictionary = {}


func _init() -> void:
	_migrate_legacy_selected_deck(selected_deck, permanent_card_levels)


func add_resource(resource_id: String, amount: int) -> bool:
	if not resources.has(resource_id) or amount < 0:
		return false
	resources[resource_id] = int(resources[resource_id]) + amount
	return true


func can_afford(costs: Dictionary) -> bool:
	for resource_id in costs:
		if int(resources.get(String(resource_id), 0)) < int(costs[resource_id]):
			return false
	return true


func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for resource_id in costs:
		resources[String(resource_id)] = int(resources.get(String(resource_id), 0)) - int(costs[resource_id])
	return true


func apply_run_summary(summary: Dictionary) -> void:
	add_resource("gold", maxi(0, int(summary.get("gold", 0))))
	var materials: Variant = summary.get("materials", {})
	if materials is Dictionary:
		for resource_id in materials:
			add_resource(String(resource_id), maxi(0, int(materials[resource_id])))
	if bool(summary.get("boss_defeated", false)):
		boss_defeated = true


func to_dict() -> Dictionary:
	_synchronize_selected_card_instances()
	return {
		"schema_version": SCHEMA_VERSION,
		"resources": resources.duplicate(true),
		"village_level": village_level,
		"building_levels": building_levels.duplicate(true),
		"unlocked_cards": unlocked_cards.duplicate(),
		"selected_deck": selected_deck.duplicate(),
		"selected_card_instances": get_selected_card_payloads(),
		"auto_attack_card_id": auto_attack_card_id,
		"equipment": equipment.duplicate(true),
		"equipment_levels": equipment_levels.duplicate(true),
		"unlocked_combos": unlocked_combos.duplicate(),
		"unlocked_evolutions": unlocked_evolutions.duplicate(),
		"learned_skill_ids": learned_skill_ids.duplicate(),
		"active_skill_ids": active_skill_ids.duplicate(),
		"boss_defeated": boss_defeated,
		"dash_upgrade_unlocked": dash_upgrade_unlocked,
		"shortcuts": shortcuts.duplicate(true),
		"settings": settings.duplicate(true),
		"inventory_state": inventory_state.duplicate(true),
		"town_state": town_state.duplicate(true),
	}


func apply_dict(data: Dictionary) -> void:
	var incoming_schema := int(data.get("schema_version", 0))
	_last_migration_report = _empty_migration_report(incoming_schema)
	var incoming_resources: Variant = data.get("resources", {})
	if incoming_resources is Dictionary:
		for resource_id in RESOURCE_IDS:
			resources[resource_id] = maxi(0, int(incoming_resources.get(resource_id, resources[resource_id])))
	village_level = clampi(int(data.get("village_level", village_level)), 1, 3)
	building_levels = _safe_integer_dictionary(data.get("building_levels"), building_levels)
	unlocked_cards = _safe_string_array(data.get("unlocked_cards"), unlocked_cards)
	if incoming_schema < 7:
		for card_id in EXPANDED_COMBO_CARD_IDS:
			if not unlocked_cards.has(card_id):
				unlocked_cards.append(card_id)
				_last_migration_report["expanded_combo_cards_unlocked"] = int(
					_last_migration_report.get("expanded_combo_cards_unlocked", 0)
				) + 1
	var legacy_selected_deck := _safe_string_array(data.get("selected_deck"), selected_deck)
	var legacy_levels := _safe_dictionary(data.get("permanent_card_levels"), {})
	if data.get("selected_card_instances") is Array:
		selected_card_instances = _restore_card_instances(
			data.get("selected_card_instances") as Array
		)
		if selected_card_instances.is_empty() and not legacy_selected_deck.is_empty():
			_migrate_legacy_selected_deck(legacy_selected_deck, legacy_levels)
		else:
			selected_deck = get_selected_card_ids()
	else:
		_migrate_legacy_selected_deck(legacy_selected_deck, legacy_levels)
	_retire_removed_cards()
	permanent_card_levels.clear()
	auto_attack_card_id = String(data.get("auto_attack_card_id", auto_attack_card_id)).strip_edges()
	if RETIRED_CARD_IDS.has(auto_attack_card_id):
		auto_attack_card_id = "ember_bolt"
	equipment = _safe_dictionary(data.get("equipment"), equipment)
	equipment_levels = _safe_integer_dictionary(data.get("equipment_levels"), equipment_levels)
	unlocked_combos = _safe_string_array(data.get("unlocked_combos"), unlocked_combos)
	unlocked_evolutions = _safe_string_array(data.get("unlocked_evolutions"), unlocked_evolutions)
	learned_skill_ids = _safe_unique_string_array(
		data.get("learned_skill_ids"),
		["iron_momentum"]
	)
	active_skill_ids = _safe_unique_string_array(
		data.get("active_skill_ids"),
		["iron_momentum"]
	)
	active_skill_ids = active_skill_ids.filter(
		func(skill_id: String) -> bool: return learned_skill_ids.has(skill_id)
	)
	if not learned_skill_ids.has("iron_momentum"):
		learned_skill_ids.push_front("iron_momentum")
	if active_skill_ids.is_empty():
		active_skill_ids.append("iron_momentum")
	boss_defeated = bool(data.get("boss_defeated", boss_defeated))
	dash_upgrade_unlocked = bool(data.get("dash_upgrade_unlocked", boss_defeated))
	shortcuts = _safe_dictionary(data.get("shortcuts"), shortcuts)
	settings = _safe_dictionary(data.get("settings"), settings)
	inventory_state = _safe_dictionary(data.get("inventory_state"), inventory_state)
	town_state = _safe_dictionary(data.get("town_state"), town_state)


func normalize_selected_deck(valid_ids: Array[String]) -> Array[String]:
	var valid_lookup: Dictionary = {}
	for card_id in valid_ids:
		valid_lookup[card_id] = true
	var normalized: Array[String] = []
	for card_id in get_selected_card_ids():
		if normalized.size() >= 16:
			break
		if valid_lookup.has(card_id):
			normalized.append(card_id)
	_reconcile_selected_card_instances(normalized)
	return selected_deck.duplicate()


func set_selected_deck(card_ids: Array[String]) -> void:
	_reconcile_selected_card_instances(card_ids)


func get_selected_card_ids() -> Array[String]:
	var result: Array[String] = []
	for instance in selected_card_instances:
		result.append(instance.card_id)
	return result


func get_selected_card_payloads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in selected_card_instances:
		result.append(instance.to_dict())
	return result


func get_card_instance(instance_id: String) -> CardInstance:
	for instance in selected_card_instances:
		if instance.instance_id == instance_id:
			return instance
	return null


func upgrade_card_instance(instance_id: String) -> bool:
	var instance := get_card_instance(instance_id)
	if instance == null or instance.level >= CardInstance.MAX_LEVEL:
		return false
	instance.level += 1
	return true


func add_card_instance(card_id: String, level: int = CardInstance.MIN_LEVEL) -> CardInstance:
	if card_id.is_empty():
		return null
	var instance := CardInstance.new(card_id, level)
	selected_card_instances.append(instance)
	selected_deck.append(card_id)
	return instance


func remove_card_instances(instance_ids: Array[String]) -> bool:
	if instance_ids.is_empty():
		return false
	var wanted: Dictionary = {}
	for instance_id in instance_ids:
		if instance_id.is_empty() or wanted.has(instance_id):
			return false
		var instance := get_card_instance(instance_id)
		if instance == null:
			return false
		wanted[instance_id] = true
	var retained: Array[CardInstance] = []
	for instance in selected_card_instances:
		if not wanted.has(instance.instance_id):
			retained.append(instance)
	selected_card_instances = retained
	selected_deck = get_selected_card_ids()
	return true


func get_last_migration_report() -> Dictionary:
	return _last_migration_report.duplicate(true)


func _safe_dictionary(value: Variant, fallback: Dictionary) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else fallback.duplicate(true)


func _safe_integer_dictionary(value: Variant, fallback: Dictionary) -> Dictionary:
	if not (value is Dictionary):
		return fallback.duplicate(true)
	var result: Dictionary = {}
	for key in (value as Dictionary).keys():
		result[key] = int((value as Dictionary)[key])
	return result


func _safe_string_array(value: Variant, fallback: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
		return result
	return fallback.duplicate()


func _safe_unique_string_array(value: Variant, fallback: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item in _safe_string_array(value, fallback):
		var normalized := item.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			result.append(normalized)
	return result


func _migrate_legacy_selected_deck(
		legacy_deck: Array[String],
		legacy_levels: Dictionary
	) -> void:
	selected_card_instances.clear()
	for index in legacy_deck.size():
		var card_id := legacy_deck[index].strip_edges()
		if card_id.is_empty():
			_last_migration_report["discarded_invalid_instances"] = int(
				_last_migration_report.get("discarded_invalid_instances", 0)
			) + 1
			continue
		var legacy_level := clampi(
			int(legacy_levels.get(card_id, CardInstance.MIN_LEVEL)),
			CardInstance.MIN_LEVEL,
			CardInstance.MAX_LEVEL
		)
		selected_card_instances.append(CardInstance.new(
			card_id,
			legacy_level,
			"legacy-%06d" % (index + 1)
		))
		_last_migration_report["migrated_instances"] = int(
			_last_migration_report.get("migrated_instances", 0)
		) + 1
	selected_deck = get_selected_card_ids()
	_last_migration_report["to_schema"] = SCHEMA_VERSION


func _restore_card_instances(raw_instances: Array) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	for index in raw_instances.size():
		if not (raw_instances[index] is Dictionary):
			_record_invalid_instance()
			continue
		var raw := raw_instances[index] as Dictionary
		var card_id := str(raw.get("card_id", "")).strip_edges()
		var instance_id := str(raw.get("instance_id", "")).strip_edges()
		var level := int(raw.get("level", CardInstance.MIN_LEVEL))
		if (
			card_id.is_empty()
			or level < CardInstance.MIN_LEVEL
			or level > CardInstance.MAX_LEVEL
		):
			_record_invalid_instance()
			continue
		if instance_id.is_empty() or seen_ids.has(instance_id):
			instance_id = _unique_repair_id(index + 1, seen_ids)
			_last_migration_report["duplicate_ids_repaired"] = int(
				_last_migration_report.get("duplicate_ids_repaired", 0)
			) + 1
		seen_ids[instance_id] = true
		result.append(CardInstance.new(card_id, level, instance_id))
	_last_migration_report["to_schema"] = SCHEMA_VERSION
	return result


func _retire_removed_cards() -> void:
	for retired_id in RETIRED_CARD_IDS:
		while unlocked_cards.has(retired_id):
			unlocked_cards.erase(retired_id)
	var retained: Array[CardInstance] = []
	for instance in selected_card_instances:
		if RETIRED_CARD_IDS.has(instance.card_id):
			_last_migration_report["retired_cards_removed"] = int(
				_last_migration_report.get("retired_cards_removed", 0)
			) + 1
			continue
		retained.append(instance)
	selected_card_instances = retained
	if selected_card_instances.is_empty():
		selected_card_instances.append(CardInstance.new(
			"ember_bolt",
			CardInstance.MIN_LEVEL,
			"migration-fallback-ember"
		))
		if not unlocked_cards.has("ember_bolt"):
			unlocked_cards.append("ember_bolt")
	selected_deck = get_selected_card_ids()


func _synchronize_selected_card_instances() -> void:
	if selected_deck != get_selected_card_ids():
		_reconcile_selected_card_instances(selected_deck)


func _reconcile_selected_card_instances(target_ids: Array[String]) -> void:
	var remaining := selected_card_instances.duplicate()
	var reconciled: Array[CardInstance] = []
	for card_id in target_ids:
		var matched_index := -1
		for index in remaining.size():
			if remaining[index].card_id == card_id:
				matched_index = index
				break
		if matched_index >= 0:
			var retained := remaining[matched_index] as CardInstance
			remaining.remove_at(matched_index)
			reconciled.append(retained)
		else:
			reconciled.append(CardInstance.new(card_id))
	selected_card_instances = reconciled
	selected_deck = get_selected_card_ids()


func _empty_migration_report(from_schema: int) -> Dictionary:
	return {
		"from_schema": from_schema,
		"to_schema": SCHEMA_VERSION,
		"migrated_instances": 0,
		"duplicate_ids_repaired": 0,
		"duplicate_fixed_cards_removed": 0,
		"fixed_levels_repaired": 0,
		"discarded_invalid_instances": 0,
		"expanded_combo_cards_unlocked": 0,
		"retired_cards_removed": 0,
	}


func _record_invalid_instance() -> void:
	_last_migration_report["discarded_invalid_instances"] = int(
		_last_migration_report.get("discarded_invalid_instances", 0)
	) + 1


func _record_duplicate_fixed_card() -> void:
	_last_migration_report["duplicate_fixed_cards_removed"] = int(
		_last_migration_report.get("duplicate_fixed_cards_removed", 0)
	) + 1


func _unique_repair_id(index: int, seen_ids: Dictionary) -> String:
	var candidate := "repair-%06d" % index
	var suffix := 2
	while seen_ids.has(candidate):
		candidate = "repair-%06d-%d" % [index, suffix]
		suffix += 1
	return candidate
