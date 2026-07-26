class_name EvolutionManager
extends RefCounted

const DEFAULT_RECIPES_PATH := "res://data/evolutions.json"

var _card_database: RefCounted
var _recipes: Array[Dictionary] = []


func _init(card_database: RefCounted = null) -> void:
	_card_database = card_database


func load_recipes(path: String = DEFAULT_RECIPES_PATH) -> bool:
	_recipes.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var raw_recipes: Variant = (parsed as Dictionary).get("fusions", [])
	if not raw_recipes is Array:
		return false
	var seen_ids := {}
	for raw_recipe in raw_recipes:
		if not raw_recipe is Dictionary:
			_recipes.clear()
			return false
		var recipe := (raw_recipe as Dictionary).duplicate(true)
		if not _is_valid_recipe(recipe, seen_ids):
			_recipes.clear()
			return false
		seen_ids[String(recipe["id"])] = true
		_recipes.append(recipe)
	return not _recipes.is_empty()


func get_all_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe in _recipes:
		result.append(recipe.duplicate(true))
	return result


func find_available(owned_instances: Variant, _legacy_passives: Array = []) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if not owned_instances is Array:
		return available
	var eligible_by_card_id: Dictionary = {}
	for raw_instance in owned_instances:
		if not raw_instance is Dictionary:
			continue
		var instance := raw_instance as Dictionary
		var card_id := String(instance.get("card_id", ""))
		var instance_id := int(instance.get("instance_id", 0))
		if card_id.is_empty() or instance_id <= 0:
			continue
		if int(instance.get("level", 0)) < 3:
			continue
		if not eligible_by_card_id.has(card_id):
			eligible_by_card_id[card_id] = []
		(eligible_by_card_id[card_id] as Array).append(instance_id)
	for recipe in _recipes:
		var materials := recipe["material_card_ids"] as Array
		var first_id := String(materials[0])
		var second_id := String(materials[1])
		if not eligible_by_card_id.has(first_id) or not eligible_by_card_id.has(second_id):
			continue
		for first_instance_id in eligible_by_card_id[first_id] as Array:
			for second_instance_id in eligible_by_card_id[second_id] as Array:
				var candidate := recipe.duplicate(true)
				candidate["material_instance_ids"] = [
					int(first_instance_id),
					int(second_instance_id),
				]
				available.append(candidate)
	return available


func _is_valid_recipe(recipe: Dictionary, seen_ids: Dictionary) -> bool:
	for field in ["id", "name", "material_card_ids", "required_level", "result_card_id"]:
		if not recipe.has(field):
			return false
	var recipe_id := String(recipe["id"])
	if not recipe["material_card_ids"] is Array:
		return false
	var materials := recipe["material_card_ids"] as Array
	if (
		recipe_id.is_empty()
		or seen_ids.has(recipe_id)
		or int(recipe["required_level"]) != 3
		or materials.size() != 2
		or String(materials[0]).is_empty()
		or String(materials[1]).is_empty()
		or String(materials[0]) == String(materials[1])
	):
		return false
	if _card_database == null:
		return true
	return (
		bool(_card_database.call("has_card", String(materials[0])))
		and bool(_card_database.call("has_card", String(materials[1])))
		and bool(_card_database.call("has_card", String(recipe["result_card_id"])))
	)
