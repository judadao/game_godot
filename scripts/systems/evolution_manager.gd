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
	var raw_recipes: Variant = (parsed as Dictionary).get("evolutions", [])
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


func find_available(levels: Dictionary, passives: Array) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for recipe in _recipes:
		var base_card_id := String(recipe["base_card_id"])
		if int(levels.get(base_card_id, 0)) < int(recipe["required_level"]):
			continue
		var has_every_passive := true
		for passive in recipe["required_passives"]:
			if not passives.has(String(passive)):
				has_every_passive = false
				break
		if has_every_passive:
			available.append(recipe.duplicate(true))
	return available


func _is_valid_recipe(recipe: Dictionary, seen_ids: Dictionary) -> bool:
	for field in ["id", "name", "base_card_id", "required_level", "required_passives", "result_card_id"]:
		if not recipe.has(field):
			return false
	var recipe_id := String(recipe["id"])
	if recipe_id.is_empty() or seen_ids.has(recipe_id) or int(recipe["required_level"]) < 1:
		return false
	if not recipe["required_passives"] is Array or (recipe["required_passives"] as Array).is_empty():
		return false
	if _card_database == null:
		return true
	return (
		bool(_card_database.call("has_card", String(recipe["base_card_id"])))
		and bool(_card_database.call("has_card", String(recipe["result_card_id"])))
	)
