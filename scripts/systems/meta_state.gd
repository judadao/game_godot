class_name MetaState
extends RefCounted

const SCHEMA_VERSION := 3
const RESOURCE_IDS := ["gold", "autumn_wood", "stone", "magic_shard", "autumn_core"]
const FIXED_CARD_IDS: Array[String] = ["ember_bolt", "quickstep"]

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
	"ember_bolt", "cleave", "guard", "iron_skin", "quickstep",
	"dash_strike", "healing_light", "frost_bind", "energy_surge",
	"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
]
var selected_deck: Array[String] = [
	"ember_bolt", "quickstep", "cleave", "cleave",
	"guard", "guard", "cleave", "dash_strike",
	"healing_light", "frost_bind", "energy_surge", "iron_skin",
	"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
]
var permanent_card_levels: Dictionary = {}
var selected_card_instances: Array[Dictionary] = []
var learned_skills: Array[String] = []
var skill_loadout: Array[String] = []
var equipment := {"weapon": "", "armor": "", "accessory": ""}
var equipment_levels: Dictionary = {}
var unlocked_combos: Array[String] = []
var unlocked_evolutions: Array[String] = []
var boss_defeated := false
var dash_upgrade_unlocked := false
var shortcuts: Dictionary = {}
var settings := {"master_volume": 1.0, "camera_shake": 0.65}
var inventory_state: Dictionary = {}
var town_state: Dictionary = {}


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
		"selected_card_instances": selected_card_instances.duplicate(true),
		"learned_skills": learned_skills.duplicate(),
		"skill_loadout": skill_loadout.duplicate(),
		"equipment": equipment.duplicate(true),
		"equipment_levels": equipment_levels.duplicate(true),
		"unlocked_combos": unlocked_combos.duplicate(),
		"unlocked_evolutions": unlocked_evolutions.duplicate(),
		"boss_defeated": boss_defeated,
		"dash_upgrade_unlocked": dash_upgrade_unlocked,
		"shortcuts": shortcuts.duplicate(true),
		"settings": settings.duplicate(true),
		"inventory_state": inventory_state.duplicate(true),
		"town_state": town_state.duplicate(true),
	}


func apply_dict(data: Dictionary) -> void:
	var incoming_resources: Variant = data.get("resources", {})
	if incoming_resources is Dictionary:
		for resource_id in RESOURCE_IDS:
			resources[resource_id] = maxi(0, int(incoming_resources.get(resource_id, resources[resource_id])))
	village_level = clampi(int(data.get("village_level", village_level)), 1, 3)
	building_levels = _safe_integer_dictionary(data.get("building_levels"), building_levels)
	unlocked_cards = _safe_string_array(data.get("unlocked_cards"), unlocked_cards)
	var legacy_selected_deck := _safe_string_array(data.get("selected_deck"), selected_deck)
	var legacy_levels := _safe_dictionary(data.get("permanent_card_levels"), {})
	var incoming_instances := _safe_card_instance_array(data.get("selected_card_instances"))
	if incoming_instances.is_empty():
		_migrate_legacy_selected_deck(legacy_selected_deck, legacy_levels)
	else:
		selected_card_instances = incoming_instances
		selected_deck = _card_ids_from_instances(selected_card_instances)
	permanent_card_levels.clear()
	learned_skills = _safe_string_array(data.get("learned_skills"), learned_skills)
	skill_loadout = _safe_string_array(data.get("skill_loadout"), skill_loadout)
	equipment = _safe_dictionary(data.get("equipment"), equipment)
	equipment_levels = _safe_dictionary(data.get("equipment_levels"), equipment_levels)
	unlocked_combos = _safe_string_array(data.get("unlocked_combos"), unlocked_combos)
	unlocked_evolutions = _safe_string_array(data.get("unlocked_evolutions"), unlocked_evolutions)
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
	for fixed_id in FIXED_CARD_IDS:
		if valid_lookup.has(fixed_id):
			normalized.append(fixed_id)
	for card_id in selected_deck:
		if normalized.size() >= 16:
			break
		if valid_lookup.has(card_id) and not FIXED_CARD_IDS.has(card_id):
			normalized.append(card_id)
	selected_deck = normalized
	_migrate_legacy_selected_deck(selected_deck, {})
	return selected_deck.duplicate()


func _safe_dictionary(value: Variant, fallback: Dictionary) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else fallback.duplicate(true)


func _safe_integer_dictionary(value: Variant, fallback: Dictionary) -> Dictionary:
	if not value is Dictionary:
		return fallback.duplicate(true)
	var result: Dictionary = {}
	for key in (value as Dictionary).keys():
		result[key] = int((value as Dictionary)[key])
	return result


func _safe_string_array(value: Variant, fallback: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
		return result
	return fallback.duplicate()


func _safe_card_instance_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for raw_instance in value:
		if not raw_instance is Dictionary:
			return []
		var parsed: Variant = CardInstance.from_dict(raw_instance as Dictionary)
		if parsed == null:
			return []
		result.append(parsed.call("to_dict") as Dictionary)
	return result


func _migrate_legacy_selected_deck(legacy_deck: Array[String], legacy_levels: Dictionary) -> void:
	selected_card_instances.clear()
	var instance_id := 1
	for card_id in legacy_deck:
		var level := 1 if FIXED_CARD_IDS.has(card_id) else clampi(int(legacy_levels.get(card_id, 1)), 1, 3)
		selected_card_instances.append(
			CardInstance.new(card_id, level, instance_id).to_dict()
		)
		instance_id += 1
	selected_deck = _card_ids_from_instances(selected_card_instances)


func _synchronize_selected_card_instances() -> void:
	if selected_deck != _card_ids_from_instances(selected_card_instances):
		_migrate_legacy_selected_deck(selected_deck, {})


func _card_ids_from_instances(instances: Array[Dictionary]) -> Array[String]:
	var card_ids: Array[String] = []
	for instance in instances:
		card_ids.append(String(instance.get("card_id", "")))
	return card_ids
