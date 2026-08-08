class_name SkillSeriesVFXCatalog
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/skill_series_vfx.json"
const CURRENT_SCHEMA_VERSION := 1
const TIER_IDS := ["basic", "advanced", "master"]

var _profiles: Dictionary = {}
var _ordered_profiles: Array[Dictionary] = []
var _series_by_legacy_recipe: Dictionary = {}
var _material_runtime: Dictionary = {}


func load_catalog(path: String = DEFAULT_DATA_PATH) -> bool:
	_profiles.clear()
	_ordered_profiles.clear()
	_series_by_legacy_recipe.clear()
	_material_runtime.clear()
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
	var runtime_value: Variant = catalog.get("material_runtime", null)
	if not runtime_value is Dictionary or not _validate_material_runtime(runtime_value as Dictionary):
		push_error("Skill-series VFX catalog needs a valid material runtime contract: %s" % path)
		return false
	_material_runtime = (runtime_value as Dictionary).duplicate(true)
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
		profile["material_runtime"] = _material_runtime.duplicate(true)
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
	var material_asset_path := String(profile.get("material_asset_path", "")).strip_edges()
	var procedural_core := bool(profile.get("procedural_core", false))
	if series_id.is_empty() or _profiles.has(series_id):
		push_error("Skill-series VFX needs a unique profile id: %s" % series_id)
		return false
	if String(profile.get("object_name", "")).strip_edges().is_empty():
		push_error("Skill-series VFX needs a concrete main-object name: %s" % series_id)
		return false
	if not procedural_core and (asset_path.is_empty() or not ResourceLoader.exists(asset_path, "Texture2D")):
		push_error("Skill-series VFX main object is missing: %s -> %s" % [series_id, asset_path])
		return false
	if material_asset_path.is_empty() or not ResourceLoader.exists(material_asset_path, "Texture2D"):
		push_error("Skill-series VFX material source is missing: %s -> %s" % [series_id, material_asset_path])
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
	var previous_feather_duration := 0.0
	var specialized_non_projectile := series_id in [
		"moon_wheel", "thorn", "black_hole", "arcane_swamp", "fire", "lightning",
		"water_flow", "dragon_breath", "dawn_vitality",
		"shared_branch_vitality",
	]
	var launches_object := bool(profile.get("launches_object", false))
	if series_id == "feather" and not _validate_feather_halo(profile):
		return false
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
		if series_id == "feather":
			var halo_duration := float(tier.get("halo_duration_seconds", 0.0))
			if halo_duration <= previous_feather_duration:
				push_error("Feather halo duration must grow with its tier: %d" % tier_index)
				return false
			previous_feather_duration = halo_duration
		if (
			String(tier.get("tier", "")) != TIER_IDS[tier_index]
			or object_count <= previous_count
			or path_count <= 0
			or direction_count <= 0
		):
			push_error("Skill-series VFX tier growth is invalid: %s[%d]" % [series_id, tier_index])
			return false
		if specialized_non_projectile:
			if float(tier.get("duration_seconds", 0.0)) <= 0.0:
				push_error("Specialized VFX tiers need a finite duration: %s[%d]" % [series_id, tier_index])
				return false
			if tier.has("radius") and float(tier.get("radius", 0.0)) <= 0.0:
				push_error("Specialized VFX radius must be positive: %s[%d]" % [series_id, tier_index])
				return false
			previous_count = object_count
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


func _validate_feather_halo(profile: Dictionary) -> bool:
	var lifetime := float(profile.get("halo_lifetime_seconds", 0.0))
	var fade := float(profile.get("halo_fade_seconds", 0.0))
	var dissolve := float(profile.get("halo_feather_dissolve_seconds", 0.0))
	var stagger := float(profile.get("halo_summon_stagger_seconds", 0.0))
	var speed := float(profile.get("halo_orbit_speed", 0.0))
	var basic := float(profile.get("halo_basic_radius", 0.0))
	var advanced := float(profile.get("halo_advanced_radius", 0.0))
	var master := float(profile.get("halo_master_radius", 0.0))
	if (
		lifetime <= 0.0
		or fade <= 0.0
		or fade > lifetime
		or dissolve <= 0.0
		or dissolve > fade
		or stagger <= 0.0
		or speed <= 0.0
		or basic < 48.0
		or advanced <= basic
		or master <= advanced
	):
		push_error("Feather halo parameters must define valid timing and increasing radii.")
		return false
	return true


func _validate_vector(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2


func _validate_material_runtime(runtime: Dictionary) -> bool:
	var roles := ["contact", "travel", "residual"]
	var regions_value: Variant = runtime.get("regions", null)
	if not regions_value is Dictionary:
		return false
	var regions := regions_value as Dictionary
	if regions.size() != roles.size():
		return false
	for role in roles:
		var region_value: Variant = regions.get(role, null)
		if not region_value is Array or (region_value as Array).size() != 4:
			return false
		var region := region_value as Array
		var x := float(region[0])
		var y := float(region[1])
		var width := float(region[2])
		var height := float(region[3])
		if x < 0.0 or y < 0.0 or width <= 0.0 or height <= 0.0 or x + width > 1.0 or y + height > 1.0 or width >= 1.0 or height >= 1.0:
			return false
	var maximum := int(runtime.get("max_instances", 0))
	if maximum < 7 or maximum > 24:
		return false
	var counts_value: Variant = runtime.get("tier_instance_counts", null)
	if not counts_value is Dictionary:
		return false
	var counts := counts_value as Dictionary
	for tier_id in TIER_IDS:
		var tier_value: Variant = counts.get(tier_id, null)
		if not tier_value is Dictionary:
			return false
		var tier_counts := tier_value as Dictionary
		var total := 0
		for role in roles:
			var count := int(tier_counts.get(role, 0))
			if count <= 0:
				return false
			total += count
		if total > maximum:
			return false
	for key in ["contact_window", "travel_window", "residual_window"]:
		var window_value: Variant = runtime.get(key, null)
		if not window_value is Array or (window_value as Array).size() != 2:
			return false
		var window := window_value as Array
		if float(window[0]) < 0.0 or float(window[1]) > 1.0 or float(window[0]) >= float(window[1]):
			return false
	if float(runtime.get("travel_stagger", 0.0)) <= 0.0 or float(runtime.get("residual_stagger", 0.0)) <= 0.0:
		return false
	var extents := runtime.get("target_extents", {}) as Dictionary
	var blends := runtime.get("blend_modes", {}) as Dictionary
	for role in roles:
		if float(extents.get(role, 0.0)) <= 0.0 or not ["mix", "add"].has(String(blends.get(role, ""))):
			return false
	return true


func _clear() -> void:
	_profiles.clear()
	_ordered_profiles.clear()
	_series_by_legacy_recipe.clear()
	_material_runtime.clear()
