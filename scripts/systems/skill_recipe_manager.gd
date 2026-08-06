class_name SkillRecipeManager
extends RefCounted

## Compatibility class name retained for callers. Schema 2 is a series catalog;
## the retired attack-count/sequence recipe engine is intentionally dormant.

const CURRENT_SCHEMA_VERSION := 2
const CATALOG_KIND := "skill_series"
const TIER_ORDER := ["basic", "advanced", "master"]
const DEFAULT_MEMORY_CAPACITIES: Array[int] = [10, 14, 18, 24, 30]
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")
const COMBO_FINISHER_CATALOG_SCRIPT := preload("res://scripts/systems/combo_finisher_catalog.gd")
const TIER_COMBO_LENGTHS := {"basic": 3, "advanced": 4, "master": 6}

var _series_by_id: Dictionary = {}
var _ordered_series: Array[Dictionary] = []
var _skills_by_id: Dictionary = {}
var _ordered_skills: Array[Dictionary] = []
var _retired_skill_ids: Array[String] = []
var _legacy_vfx_by_skill: Dictionary = {}
var _tier_labels: Dictionary = {}
var _active_ids: Array[String] = []
var _element_taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()
var _combo_finisher_catalog: RefCounted = COMBO_FINISHER_CATALOG_SCRIPT.new()


func load_catalog(path: String) -> bool:
	_clear_catalog()
	if not bool(_combo_finisher_catalog.call("load_catalog")):
		push_error("Legacy Combo effect catalog must load before formal skill routes.")
		return false
	if not FileAccess.file_exists(path):
		push_error("Skill series catalog not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Skill series catalog could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Skill series catalog root must be a dictionary: %s" % path)
		return false
	var catalog := parsed as Dictionary
	if int(catalog.get("schema_version", 0)) != CURRENT_SCHEMA_VERSION:
		push_error("Skill series catalog schema must be %d: %s" % [CURRENT_SCHEMA_VERSION, path])
		return false
	if String(catalog.get("catalog_kind", "")) != CATALOG_KIND:
		push_error("Skill series catalog kind must be '%s': %s" % [CATALOG_KIND, path])
		return false
	if not _validate_tier_contract(catalog):
		return false
	if not _parse_retired_ids(catalog.get("retired_skill_ids", null)):
		return false
	if not _parse_legacy_vfx_map(catalog.get("legacy_vfx_map", null)):
		return false
	var series_value: Variant = catalog.get("series", null)
	if not series_value is Array or (series_value as Array).is_empty():
		push_error("Skill series catalog must contain a non-empty series array: %s" % path)
		return false
	for series_variant in series_value as Array:
		if not series_variant is Dictionary:
			push_error("Skill series entries must be dictionaries: %s" % path)
			_clear_catalog()
			return false
		var series_entry := (series_variant as Dictionary).duplicate(true)
		if not _validate_and_store_series(series_entry):
			_clear_catalog()
			return false
	if _legacy_vfx_by_skill.size() != _ordered_skills.size():
		push_error("Every new skill must preserve exactly one legacy recipe compatibility ID.")
		_clear_catalog()
		return false
	return not _ordered_series.is_empty() and not _ordered_skills.is_empty()


func get_all_series() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for series_entry in _ordered_series:
		result.append(series_entry.duplicate(true))
	return result


func get_all_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill in _ordered_skills:
		result.append(skill.duplicate(true))
	return result


func get_series(series_id: String) -> Dictionary:
	return (_series_by_id.get(series_id, {}) as Dictionary).duplicate(true)


func get_skill(skill_id: String) -> Dictionary:
	return (_skills_by_id.get(skill_id, {}) as Dictionary).duplicate(true)


func has_skill(skill_id: String) -> bool:
	return _skills_by_id.has(skill_id)


func get_retired_skill_ids() -> Array[String]:
	return _retired_skill_ids.duplicate()


func get_tier_label(tier_id: String) -> String:
	return String(_tier_labels.get(tier_id, tier_id))


func get_legacy_vfx_id(skill_id: String) -> String:
	return String(_legacy_vfx_by_skill.get(skill_id, ""))


func configure_loadout(learned_ids: Array, active_ids: Array, _memory_capacity: int) -> bool:
	var learned_lookup: Dictionary = {}
	for value in learned_ids:
		var skill_id := String(value)
		if not _skills_by_id.has(skill_id) or learned_lookup.has(skill_id):
			return false
		learned_lookup[skill_id] = true
	var normalized_active: Array[String] = []
	for value in active_ids:
		var skill_id := String(value)
		if not learned_lookup.has(skill_id):
			return false
		if not normalized_active.has(skill_id):
			normalized_active.append(skill_id)
	_active_ids = normalized_active
	return true


func get_active_ids() -> Array[String]:
	return _active_ids.duplicate()


func match_active_combo_routes(sequence: Array) -> Array[Dictionary]:
	var normalized: Array[String] = []
	for value in sequence:
		normalized.append(String(value))
	var matches: Array[Dictionary] = []
	for skill_id in _active_ids:
		var skill := _skills_by_id.get(skill_id, {}) as Dictionary
		for route_variant in skill.get("combo_routes", []) as Array:
			if not route_variant is Array:
				continue
			var route := route_variant as Array
			if route.size() <= normalized.size() and route == normalized.slice(normalized.size() - route.size()):
				matches.append(skill.duplicate(true))
				break
	return matches


func get_recipe(skill_id: String) -> Dictionary:
	return get_skill(skill_id)


func record_card(_card: Dictionary) -> Array[Dictionary]:
	# Schema 2 defines no attack-count or card-sequence activation rules.
	return []


func tick(_delta: float) -> void:
	pass


func reset_runtime() -> void:
	pass


func get_progress(_skill_id: String) -> int:
	return 0


func get_cooldown_remaining(_skill_id: String) -> float:
	return 0.0


func get_memory_capacity_for_library_level(level: int) -> int:
	return DEFAULT_MEMORY_CAPACITIES[clampi(level, 0, DEFAULT_MEMORY_CAPACITIES.size() - 1)]


func _clear_catalog() -> void:
	_series_by_id.clear()
	_ordered_series.clear()
	_skills_by_id.clear()
	_ordered_skills.clear()
	_retired_skill_ids.clear()
	_legacy_vfx_by_skill.clear()
	_tier_labels.clear()
	_active_ids.clear()


func _validate_tier_contract(catalog: Dictionary) -> bool:
	var tier_order_value: Variant = catalog.get("tier_order", null)
	if not tier_order_value is Array:
		push_error("Skill series catalog tier_order must be an array.")
		return false
	var actual_order: Array[String] = []
	for value in tier_order_value as Array:
		actual_order.append(String(value))
	if actual_order != TIER_ORDER:
		push_error("Skill series tiers must be basic, advanced, master in order.")
		return false
	var labels_value: Variant = catalog.get("tier_labels", null)
	if not labels_value is Dictionary:
		push_error("Skill series catalog tier_labels must be a dictionary.")
		return false
	for tier_id in TIER_ORDER:
		var label := String((labels_value as Dictionary).get(tier_id, "")).strip_edges()
		if label.is_empty():
			push_error("Skill series tier label is missing: %s" % tier_id)
			return false
		_tier_labels[tier_id] = label
	return true


func _parse_retired_ids(value: Variant) -> bool:
	if not value is Array:
		push_error("Skill series catalog retired_skill_ids must be an array.")
		return false
	for id_variant in value as Array:
		var skill_id := String(id_variant).strip_edges()
		if skill_id.is_empty() or _retired_skill_ids.has(skill_id):
			push_error("Retired skill IDs must be non-empty and unique: %s" % skill_id)
			return false
		_retired_skill_ids.append(skill_id)
	return true


func _parse_legacy_vfx_map(value: Variant) -> bool:
	if not value is Dictionary or (value as Dictionary).is_empty():
		push_error("Skill series catalog legacy_vfx_map must be a non-empty dictionary.")
		return false
	for skill_id_variant in (value as Dictionary).keys():
		var skill_id := String(skill_id_variant).strip_edges()
		var profile_id := String((value as Dictionary)[skill_id_variant]).strip_edges()
		if skill_id.is_empty() or profile_id.is_empty():
			push_error("Temporary legacy VFX mappings require non-empty skill and profile IDs.")
			return false
		_legacy_vfx_by_skill[skill_id] = profile_id
	return true


func _validate_and_store_series(series_entry: Dictionary) -> bool:
	var series_id := String(series_entry.get("id", "")).strip_edges()
	var series_name := String(series_entry.get("name", "")).strip_edges()
	if series_id.is_empty() or series_name.is_empty() or _series_by_id.has(series_id):
		push_error("Skill series requires a unique id and name: %s" % series_id)
		return false
	if not _validate_non_empty_strings(series_entry.get("identity_elements", null), 1):
		push_error("Skill series identity_elements are invalid: %s" % series_id)
		return false
	var combat_elements: Variant = series_entry.get("combat_elements", null)
	if not _validate_non_empty_strings(combat_elements, 1):
		push_error("Skill series combat_elements are invalid: %s" % series_id)
		return false
	for element_variant in combat_elements as Array:
		if not bool(_element_taxonomy.call("is_valid", String(element_variant))):
			push_error("Skill series has an invalid canonical element: %s -> %s" % [series_id, element_variant])
			return false
	if String(series_entry.get("series_positioning", "")).strip_edges().is_empty():
		push_error("Skill series needs a positioning statement: %s" % series_id)
		return false
	var skills_value: Variant = series_entry.get("skills", null)
	if not skills_value is Array or (skills_value as Array).size() != TIER_ORDER.size():
		push_error("Skill series must contain exactly three skills: %s" % series_id)
		return false
	var normalized_skills: Array[Dictionary] = []
	for tier_index in TIER_ORDER.size():
		var skill_variant: Variant = (skills_value as Array)[tier_index]
		if not skill_variant is Dictionary:
			push_error("Skill entries must be dictionaries: %s[%d]" % [series_id, tier_index])
			return false
		var skill := (skill_variant as Dictionary).duplicate(true)
		if not _validate_skill(skill, series_id, tier_index):
			return false
		skill["series_id"] = series_id
		skill["series_name"] = series_name
		skill["series_vfx_id"] = series_id
		skill["series_identity_elements"] = (series_entry.get("identity_elements", []) as Array).duplicate()
		skill["combat_elements"] = (series_entry.get("combat_elements", []) as Array).duplicate()
		_skills_by_id[String(skill["id"])] = skill
		_ordered_skills.append(skill)
		normalized_skills.append(skill)
	series_entry["skills"] = normalized_skills
	_series_by_id[series_id] = series_entry
	_ordered_series.append(series_entry)
	return true


func _validate_skill(skill: Dictionary, series_id: String, tier_index: int) -> bool:
	var skill_id := String(skill.get("id", "")).strip_edges()
	var skill_name := String(skill.get("name", "")).strip_edges()
	if (
		skill_id.is_empty()
		or skill_name.is_empty()
		or _skills_by_id.has(skill_id)
		or _retired_skill_ids.has(skill_id)
	):
		push_error("Skill requires a unique non-retired id and name: %s" % skill_id)
		return false
	if String(skill.get("tier", "")) != TIER_ORDER[tier_index]:
		push_error("Skill tier order is invalid: %s" % skill_id)
		return false
	if int(skill.get("tier_rank", 0)) != tier_index + 1:
		push_error("Skill tier rank is invalid: %s" % skill_id)
		return false
	for field in ["positioning", "description"]:
		if String(skill.get(field, "")).strip_edges().is_empty():
			push_error("Skill %s is missing %s." % [skill_id, field])
			return false
	if not _validate_non_empty_strings(skill.get("animation_beats", null), 3):
		push_error("Skill animation beats must contain at least three steps: %s" % skill_id)
		return false
	if not _legacy_vfx_by_skill.has(skill_id):
		push_error("Skill has no legacy recipe compatibility mapping: %s" % skill_id)
		return false
	skill["legacy_vfx_id"] = String(_legacy_vfx_by_skill[skill_id])
	var legacy_recipe := _combo_finisher_catalog.call(
		"get_recipe",
		String(skill["legacy_vfx_id"])
	) as Dictionary
	if legacy_recipe.is_empty():
		push_error("Skill Combo compatibility recipe is missing: %s" % skill_id)
		return false
	var route_seed := legacy_recipe.get("sequence", []) as Array
	var route_length := int(TIER_COMBO_LENGTHS.get(String(skill["tier"]), 0))
	skill["combo_routes"] = _build_combo_routes(route_seed, route_length)
	if (skill["combo_routes"] as Array).is_empty():
		push_error("Skill Combo routes could not be built: %s" % skill_id)
		return false
	var icon_path := String(skill.get("icon_path", "")).strip_edges()
	if not icon_path.is_empty() and not ResourceLoader.exists(icon_path):
		push_error("Skill icon does not exist: %s -> %s" % [skill_id, icon_path])
		return false
	return true


func _build_combo_routes(seed: Array, route_length: int) -> Array[Array]:
	if seed.is_empty() or route_length <= 0:
		return []
	var routes: Array[Array] = []
	var reversed_seed := seed.duplicate()
	reversed_seed.reverse()
	for source_variant in [seed, reversed_seed]:
		var source := source_variant as Array
		var route: Array[String] = []
		for index in route_length:
			route.append(String(source[index % source.size()]))
		if not routes.has(route):
			routes.append(route)
	return routes


func _validate_non_empty_strings(value: Variant, minimum_size: int) -> bool:
	if not value is Array or (value as Array).size() < minimum_size:
		return false
	var seen: Dictionary = {}
	for item_variant in value as Array:
		var item := String(item_variant).strip_edges()
		if item.is_empty() or seen.has(item):
			return false
		seen[item] = true
	return true
