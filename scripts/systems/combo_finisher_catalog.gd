class_name ComboFinisherCatalog
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/combo_finishers.json"
const FORMULA_LENGTH := 3

var _recipes: Dictionary = {}
var _ordered_ids: Array[String] = []


func load_catalog(path: String = DEFAULT_DATA_PATH) -> bool:
	_recipes.clear()
	_ordered_ids.clear()
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var recipes_variant: Variant = (parsed as Dictionary).get("recipes", [])
	if not recipes_variant is Array:
		return false
	for recipe_variant in recipes_variant:
		if not recipe_variant is Dictionary:
			return false
		var recipe := (recipe_variant as Dictionary).duplicate(true)
		var recipe_id := String(recipe.get("id", "")).strip_edges()
		var sequence_variant: Variant = recipe.get("sequence", [])
		if (
			recipe_id.is_empty()
			or _recipes.has(recipe_id)
			or not sequence_variant is Array
			or (sequence_variant as Array).size() != FORMULA_LENGTH
		):
			_recipes.clear()
			_ordered_ids.clear()
			return false
		var sequence: Array[String] = []
		for skill_id_variant in sequence_variant as Array:
			var skill_id := String(skill_id_variant).strip_edges()
			if skill_id.is_empty():
				return false
			sequence.append(skill_id)
		recipe["sequence"] = sequence
		var required_variant: Variant = recipe.get("required_skills", sequence)
		var required: Array[String] = []
		if required_variant is Array:
			for skill_id_variant in required_variant as Array:
				var skill_id := String(skill_id_variant).strip_edges()
				if not skill_id.is_empty() and not required.has(skill_id):
					required.append(skill_id)
		recipe["required_skills"] = required
		_recipes[recipe_id] = recipe
		_ordered_ids.append(recipe_id)
	return not _recipes.is_empty()


func match_sequence(sequence: Array) -> Dictionary:
	if sequence.size() != FORMULA_LENGTH:
		return {}
	var normalized: Array[String] = []
	for skill_id_variant in sequence:
		normalized.append(String(skill_id_variant))
	for recipe_id in _ordered_ids:
		var recipe := _recipes[recipe_id] as Dictionary
		if recipe.get("sequence", []) as Array == normalized:
			return recipe.duplicate(true)
	return {}


func get_recipe(recipe_id: String) -> Dictionary:
	return (
		(_recipes[recipe_id] as Dictionary).duplicate(true)
		if _recipes.has(recipe_id)
		else {}
	)


func get_all_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id in _ordered_ids:
		result.append((_recipes[recipe_id] as Dictionary).duplicate(true))
	return result
