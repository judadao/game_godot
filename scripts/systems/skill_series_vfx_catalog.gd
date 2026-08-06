class_name SkillSeriesVFXCatalog
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/skill_series_vfx.json"
const CURRENT_SCHEMA_VERSION := 1
const TIER_IDS := ["basic", "advanced", "master"]

var _profiles: Dictionary = {}
var _ordered_profiles: Array[Dictionary] = []
var _series_by_legacy_recipe: Dictionary = {}


func load_catalog(path: String = DEFAULT_DATA_PATH) -> bool:
	_profiles.clear()
	_ordered_profiles.clear()
	_series_by_legacy_recipe.clear()
	if not FileAccess.file_exists(path):
		push_error("Skill-series VFX catalog not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Skill-series VFX catalog could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Skill-series VFX catalog root must be a dictionary: %s" % path)
		return false
	var catalog := parsed as Dictionary
	if int(catalog.get("schema_version", 0)) != CURRENT_SCHEMA_VERSION:
		push_error("Skill-series VFX schema must be %d: %s" % [CURRENT_SCHEMA_VERSION, path])
		return false
	var profiles_value: Variant = catalog.get("profiles", null)
	if not profiles_value is Array or (profiles_value as Array).is_empty():
		push_error("Skill-series VFX catalog needs a non-empty profiles array: %s" % path)
		return false
	for profile_variant in profiles_value as Array:
		if not profile_variant is Dictionary:
			push_error("Skill-series VFX profile entries must be dictionaries: %s" % path)
			_clear()
			return false
		var profile := (profile_variant as Dictionary).duplicate(true)
		if not _validate_profile(profile):
			_clear()
			return false
		var series_id := String(profile["id"])
		_profiles[series_id] = profile
		_ordered_profiles.append(profile)
		for recipe_variant in profile.get("legacy_recipe_ids", []) as Array:
			var recipe_id := String(recipe_variant).strip_edges()
			if recipe_id.is_empty() or _series_by_legacy_recipe.has(recipe_id):
				push_error("Legacy VFX recipe must map to one series only: %s" % recipe_id)
				_clear()
				return false
			_series_by_legacy_recipe[recipe_id] = series_id
	return true


func has_profile(series_id: String) -> bool:
	return _profiles.has(series_id)


func get_profile(series_id: String) -> Dictionary:
	return (
		(_profiles[series_id] as Dictionary).duplicate(true)
		if _profiles.has(series_id)
		else {}
	)


func get_all_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in _ordered_profiles:
		result.append(profile.duplicate(true))
	return result


func get_series_for_legacy_recipe(recipe_id: String) -> String:
	return String(_series_by_legacy_recipe.get(recipe_id, ""))


func get_tier_profile(series_id: String, tier_rank: int) -> Dictionary:
	var profile := get_profile(series_id)
	if profile.is_empty():
		return {}
	var tiers := profile.get("tiers", []) as Array
	var index := clampi(tier_rank, 1, tiers.size()) - 1
	return (tiers[index] as Dictionary).duplicate(true) if index >= 0 else {}


func _validate_profile(profile: Dictionary) -> bool:
	var series_id := String(profile.get("id", "")).strip_edges()
	var asset_path := String(profile.get("asset_path", "")).strip_edges()
	if series_id.is_empty() or _profiles.has(series_id):
		push_error("Skill-series VFX needs a unique profile id: %s" % series_id)
		return false
	if String(profile.get("object_name", "")).strip_edges().is_empty():
		push_error("Skill-series VFX needs a concrete main-object name: %s" % series_id)
		return false
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path, "Texture2D"):
		push_error("Skill-series VFX main object is missing: %s -> %s" % [series_id, asset_path])
		return false
	if String(profile.get("motion_family", "")).strip_edges().is_empty():
		push_error("Skill-series VFX needs a motion family: %s" % series_id)
		return false
	if not _validate_vector(profile.get("source", null)) or not _validate_vector(profile.get("target", null)):
		push_error("Skill-series VFX needs source and target vectors: %s" % series_id)
		return false
	var tiers_value: Variant = profile.get("tiers", null)
	if not tiers_value is Array or (tiers_value as Array).size() != TIER_IDS.size():
		push_error("Skill-series VFX needs exactly three formation tiers: %s" % series_id)
		return false
	var previous_count := 0
	var gate_network := String(profile.get("gameplay_family", "")) == "sword_aura_gate_network"
	var launches_object := bool(profile.get("launches_object", false))
	if launches_object and float(profile.get("minimum_render_size", 0.0)) < 112.0:
		push_error("Launched skill-series objects must remain readable: %s" % series_id)
		return false
	for tier_index in TIER_IDS.size():
		var tier_variant: Variant = (tiers_value as Array)[tier_index]
		if not tier_variant is Dictionary:
			return false
		var tier := tier_variant as Dictionary
		var object_count := int(tier.get("object_count", 0))
		var path_count := int(tier.get("path_count", 0))
		var direction_count := int(tier.get("direction_count", 0))
		if (
			String(tier.get("tier", "")) != TIER_IDS[tier_index]
			or object_count <= previous_count
			or path_count <= 0
			or direction_count <= 0
		):
			push_error("Skill-series VFX tier growth is invalid: %s[%d]" % [series_id, tier_index])
			return false
		if gate_network:
			var expected_nodes: int = [2, 4, 6][tier_index]
			if int(tier.get("node_count", 0)) != expected_nodes or object_count != expected_nodes:
				push_error("Sword-aura gate tiers must use 2/4/6 nodes: %s[%d]" % [series_id, tier_index])
				return false
			continue
		if launches_object:
			var minimum_paths := 5 if tier_index == 2 else 3
			if object_count < 3 or path_count < minimum_paths or direction_count < minimum_paths:
				push_error("Launched skill-series VFX must start at three paths and grow to five: %s[%d]" % [series_id, tier_index])
				return false
		elif tier_index == 0 and (object_count != 1 or path_count != 1 or direction_count != 1):
			push_error("Non-projectile basic skill-series VFX must use its authored single formation: %s" % series_id)
			return false
		elif tier_index == 1 and (path_count != 1 or direction_count != 1):
			push_error("Non-projectile advanced skill-series VFX must preserve its authored formation: %s" % series_id)
			return false
		elif tier_index == 2 and (path_count < 3 or direction_count < 3):
			push_error("Master skill-series VFX must use multiple paths and directions: %s" % series_id)
			return false
		previous_count = object_count
	return true


func _validate_vector(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2


func _clear() -> void:
	_profiles.clear()
	_ordered_profiles.clear()
	_series_by_legacy_recipe.clear()
