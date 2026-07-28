class_name ForgeCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/forge_catalog.json"
const EQUIPMENT_PATH := "res://data/equipment.json"
const CARDS_PATH := "res://data/cards.json"
const VALID_SHOPS: Array[StringName] = [
	&"material_store",
	&"sword_soul_shop",
	&"equipment_blueprint_shop",
]
const VALID_PRODUCT_KINDS: Array[StringName] = [&"resource", &"tool", &"blueprint"]
const VALID_RESULT_KINDS: Array[StringName] = [&"equipment", &"sword_soul"]

var _loaded := false
var _offers: Array[Dictionary] = []
var _offers_by_id: Dictionary = {}
var _recipes: Array[Dictionary] = []
var _recipes_by_id: Dictionary = {}


func _init(catalog_path: String = DEFAULT_CATALOG_PATH) -> void:
	_load_catalog(catalog_path)


func is_loaded() -> bool:
	return _loaded


func get_all_offers() -> Array[Dictionary]:
	return _offers.duplicate(true)


func get_offer(offer_id: StringName) -> Dictionary:
	var offer: Dictionary = _offers_by_id.get(String(offer_id), {})
	return offer.duplicate(true)


func get_shop_offers(shop_id: StringName, flame_tier: int) -> Array[Dictionary]:
	if not VALID_SHOPS.has(shop_id) or flame_tier < 0:
		return []
	var result: Array[Dictionary] = []
	for offer in _offers:
		if StringName(offer.get("shop_id", "")) != shop_id:
			continue
		if int(offer.get("required_flame_tier", 0)) > flame_tier:
			continue
		result.append(offer.duplicate(true))
	return result


func is_offer_unlocked(offer_id: StringName, flame_tier: int) -> bool:
	var offer := get_offer(offer_id)
	return (
		not offer.is_empty()
		and flame_tier >= 0
		and int(offer.get("required_flame_tier", 0)) <= flame_tier
	)


func get_all_recipes() -> Array[Dictionary]:
	return _recipes.duplicate(true)


func get_recipe(recipe_id: StringName) -> Dictionary:
	var recipe: Dictionary = _recipes_by_id.get(String(recipe_id), {})
	return recipe.duplicate(true)


func get_recipes_for_blacksmith_level(level: int) -> Array[Dictionary]:
	if level < 0:
		return []
	var result: Array[Dictionary] = []
	for recipe in _recipes:
		if int(recipe.get("required_blacksmith_level", 1)) <= level:
			result.append(recipe.duplicate(true))
	return result


func _load_catalog(catalog_path: String) -> void:
	var equipment_ids := _load_ids(EQUIPMENT_PATH, "equipment")
	var card_ids := _load_ids(CARDS_PATH, "cards")
	if equipment_ids.is_empty() or card_ids.is_empty():
		push_error("Forge catalog dependencies failed to load.")
		return
	if not FileAccess.file_exists(catalog_path):
		push_error("Forge catalog not found: %s" % catalog_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not parsed is Dictionary:
		push_error("Forge catalog root must be a dictionary: %s" % catalog_path)
		return
	var data := parsed as Dictionary
	if int(data.get("schema_version", 0)) != 1:
		push_error("Unsupported forge catalog schema: %s" % data.get("schema_version", 0))
		return
	var offers: Variant = data.get("offers", [])
	var recipes: Variant = data.get("recipes", [])
	if not offers is Array or (offers as Array).is_empty():
		push_error("Forge catalog offers must be a non-empty array.")
		return
	if not recipes is Array or (recipes as Array).is_empty():
		push_error("Forge catalog recipes must be a non-empty array.")
		return
	for offer_variant in offers:
		if not offer_variant is Dictionary:
			push_error("Forge catalog offer must be a dictionary.")
			return
		var offer := (offer_variant as Dictionary).duplicate(true)
		if not _validate_offer(offer, equipment_ids, card_ids):
			return
		var offer_id := String(offer.get("id", ""))
		_offers.append(offer)
		_offers_by_id[offer_id] = offer
	for recipe_variant in recipes:
		if not recipe_variant is Dictionary:
			push_error("Forge catalog recipe must be a dictionary.")
			return
		var recipe := (recipe_variant as Dictionary).duplicate(true)
		if not _validate_recipe(recipe, equipment_ids, card_ids):
			return
		var recipe_id := String(recipe.get("id", ""))
		_recipes.append(recipe)
		_recipes_by_id[recipe_id] = recipe
	_loaded = true


func _validate_offer(
	offer: Dictionary,
	equipment_ids: Dictionary,
	card_ids: Dictionary
) -> bool:
	var offer_id := String(offer.get("id", ""))
	var shop_id := StringName(offer.get("shop_id", ""))
	var product_kind := StringName(offer.get("product_kind", ""))
	var product_id := String(offer.get("product_id", ""))
	var icon_path := String(offer.get("icon_path", ""))
	if offer_id.is_empty() or _offers_by_id.has(offer_id):
		push_error("Forge offer ID is empty or duplicated: %s" % offer_id)
		return false
	if not VALID_SHOPS.has(shop_id) or not VALID_PRODUCT_KINDS.has(product_kind):
		push_error("Forge offer has invalid shop or product kind: %s" % offer_id)
		return false
	if String(offer.get("name", "")).is_empty() or product_id.is_empty():
		push_error("Forge offer is missing display or product identity: %s" % offer_id)
		return false
	if not _is_positive_integer(offer.get("quantity")) or not _is_positive_integer(offer.get("price")):
		push_error("Forge offer quantity and price must be positive: %s" % offer_id)
		return false
	if not _is_non_negative_integer(offer.get("required_flame_tier")):
		push_error("Forge offer flame tier must be non-negative: %s" % offer_id)
		return false
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		push_error("Forge offer icon does not exist: %s" % icon_path)
		return false
	if product_kind == &"resource":
		if not ["autumn_wood", "stone", "magic_shard", "autumn_core"].has(product_id):
			push_error("Forge material offer references an invalid resource: %s" % product_id)
			return false
	elif product_kind == &"blueprint":
		var target_kind := StringName(offer.get("target_kind", ""))
		var target_id := String(offer.get("target_id", ""))
		if not VALID_RESULT_KINDS.has(target_kind):
			push_error("Blueprint offer has invalid target kind: %s" % offer_id)
			return false
		if target_kind == &"equipment" and not equipment_ids.has(target_id):
			push_error("Blueprint references unknown equipment: %s" % target_id)
			return false
		if target_kind == &"sword_soul" and not card_ids.has(target_id):
			push_error("Blueprint references unknown sword soul: %s" % target_id)
			return false
	return true


func _validate_recipe(
	recipe: Dictionary,
	equipment_ids: Dictionary,
	card_ids: Dictionary
) -> bool:
	var recipe_id := String(recipe.get("id", ""))
	var blueprint_id := String(recipe.get("blueprint_id", ""))
	var result_kind := StringName(recipe.get("result_kind", ""))
	var result_id := String(recipe.get("result_id", ""))
	if recipe_id.is_empty() or _recipes_by_id.has(recipe_id):
		push_error("Forge recipe ID is empty or duplicated: %s" % recipe_id)
		return false
	if blueprint_id.is_empty() or not _blueprint_exists(blueprint_id, result_kind, result_id):
		push_error("Forge recipe has no matching blueprint offer: %s" % recipe_id)
		return false
	if not VALID_RESULT_KINDS.has(result_kind):
		push_error("Forge recipe has invalid result kind: %s" % recipe_id)
		return false
	if result_kind == &"equipment" and not equipment_ids.has(result_id):
		push_error("Forge recipe references unknown equipment: %s" % result_id)
		return false
	if result_kind == &"sword_soul" and not card_ids.has(result_id):
		push_error("Forge recipe references unknown sword soul: %s" % result_id)
		return false
	if not _is_positive_integer(recipe.get("required_blacksmith_level")):
		push_error("Forge recipe requires a positive blacksmith level: %s" % recipe_id)
		return false
	var cost: Variant = recipe.get("cost", {})
	if not cost is Dictionary or (cost as Dictionary).is_empty():
		push_error("Forge recipe cost must be a non-empty dictionary: %s" % recipe_id)
		return false
	for resource_variant in (cost as Dictionary):
		if not ["autumn_wood", "stone", "magic_shard", "autumn_core"].has(String(resource_variant)):
			push_error("Forge recipe uses an invalid resource: %s" % resource_variant)
			return false
		if not _is_positive_integer((cost as Dictionary)[resource_variant]):
			push_error("Forge recipe resource costs must be positive: %s" % recipe_id)
			return false
	var required_tools: Variant = recipe.get("required_tools", [])
	if not required_tools is Array or (required_tools as Array).is_empty():
		push_error("Forge recipe must require at least one tool: %s" % recipe_id)
		return false
	for tool_variant in required_tools:
		if not _tool_exists(String(tool_variant)):
			push_error("Forge recipe references unknown tool: %s" % tool_variant)
			return false
	return true


func _blueprint_exists(blueprint_id: String, result_kind: StringName, result_id: String) -> bool:
	for offer in _offers:
		if String(offer.get("product_id", "")) != blueprint_id:
			continue
		return (
			StringName(offer.get("target_kind", "")) == result_kind
			and String(offer.get("target_id", "")) == result_id
		)
	return false


func _tool_exists(tool_id: String) -> bool:
	for offer in _offers:
		if (
			StringName(offer.get("product_kind", "")) == &"tool"
			and String(offer.get("product_id", "")) == tool_id
		):
			return true
	return false


func _load_ids(path: String, root_field: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var entries: Variant = (parsed as Dictionary).get(root_field, [])
	if not entries is Array:
		return {}
	var result: Dictionary = {}
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			return {}
		var entry_id := String((entry_variant as Dictionary).get("id", ""))
		if entry_id.is_empty() or result.has(entry_id):
			return {}
		result[entry_id] = true
	return result


func _is_positive_integer(value: Variant) -> bool:
	return _is_non_negative_integer(value) and int(value) > 0


func _is_non_negative_integer(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return number >= 0.0 and is_equal_approx(number, floorf(number))
