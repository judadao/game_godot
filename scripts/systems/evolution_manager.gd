class_name EvolutionManager
extends RefCounted

const DEFAULT_RECIPES_PATH := "res://data/evolutions.json"
const GENERIC_FUSION_RESULT_ID := "ascendant_combo"

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
	var raw_recipes: Variant = (parsed as Dictionary).get("fusion_recipes", [])
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


func find_available_fusions(card_instances: Array) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for instance_variant in card_instances:
		var instance := _instance_projection(instance_variant)
		if (
			instance.is_empty()
			or int(instance.get("level", 0)) != 3
			or bool(instance.get("fixed", false))
			or bool(instance.get("growth_locked", false))
		):
			continue
		eligible.append(instance)
	var available: Array[Dictionary] = []
	var claimed_pairs: Dictionary = {}
	for recipe in _recipes:
		for left in eligible:
			if String(left.get("card_id", "")) != String(recipe["left_card_id"]):
				continue
			for right in eligible:
				if (
					String(right.get("card_id", "")) != String(recipe["right_card_id"])
					or String(left.get("instance_id", "")) == String(right.get("instance_id", ""))
				):
					continue
				var fusion := recipe.duplicate(true)
				fusion["recipe_id"] = String(recipe["id"])
				fusion["left_instance_id"] = String(left["instance_id"])
				fusion["right_instance_id"] = String(right["instance_id"])
				available.append(fusion)
				claimed_pairs[_pair_key(
					String(left["instance_id"]),
					String(right["instance_id"])
				)] = true
	for left_index in eligible.size():
		for right_index in range(left_index + 1, eligible.size()):
			var left := eligible[left_index]
			var right := eligible[right_index]
			var pair_key := _pair_key(
				String(left["instance_id"]),
				String(right["instance_id"])
			)
			if claimed_pairs.has(pair_key):
				continue
			available.append({
				"id": "synthesize_%s" % pair_key,
				"recipe_id": "synthesize_%s" % pair_key,
				"name": "Ascendant Combo",
				"left_card_id": String(left["card_id"]),
				"right_card_id": String(right["card_id"]),
				"result_card_id": GENERIC_FUSION_RESULT_ID,
				"left_instance_id": String(left["instance_id"]),
				"right_instance_id": String(right["instance_id"]),
				"generic": true,
			})
	return available


func _pair_key(left_id: String, right_id: String) -> String:
	var ids := [left_id, right_id]
	ids.sort()
	return "%s_%s" % [ids[0], ids[1]]


func _is_valid_recipe(recipe: Dictionary, seen_ids: Dictionary) -> bool:
	for field in ["id", "name", "left_card_id", "right_card_id", "result_card_id"]:
		if not recipe.has(field):
			return false
	var recipe_id := String(recipe["id"])
	if (
		recipe_id.is_empty()
		or seen_ids.has(recipe_id)
		or String(recipe["left_card_id"]).is_empty()
		or String(recipe["right_card_id"]).is_empty()
		or String(recipe["result_card_id"]).is_empty()
	):
		return false
	if _card_database == null:
		return true
	return (
		bool(_card_database.call("has_card", String(recipe["left_card_id"])))
		and bool(_card_database.call("has_card", String(recipe["right_card_id"])))
		and bool(_card_database.call("has_card", String(recipe["result_card_id"])))
	)


func _instance_projection(value: Variant) -> Dictionary:
	if value is Dictionary:
		var data := (value as Dictionary).duplicate(true)
		data["fixed"] = bool(data.get("fixed", false))
		data["growth_locked"] = bool(data.get("growth_locked", false))
		return data
	if value is Object:
		var object := value as Object
		return {
			"instance_id": String(object.get("instance_id")),
			"card_id": String(object.get("card_id")),
			"level": int(object.get("level")),
			"fixed": bool(object.call("is_fixed")) if object.has_method("is_fixed") else false,
			"growth_locked": (
				bool(object.call("is_growth_locked"))
				if object.has_method("is_growth_locked")
				else false
			),
		}
	return {}
