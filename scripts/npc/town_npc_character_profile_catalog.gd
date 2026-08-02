class_name TownNPCCharacterProfileCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/town_npc_character_profiles.json"
const SCHEMA_VERSION := 1
const ROOT_KEYS := [&"schema_version", &"profiles"]
const PROFILE_KEYS := [
	&"id", &"ambient_actions", &"day_periods", &"logical_partner_interactions",
]
const DAY_PERIOD_KEYS := [
	&"id", &"start_progress", &"end_progress", &"locations", &"activities",
	&"minimum_stay_seconds",
]
const PARTNER_RULE_KEYS := [&"partner_id", &"interaction_ids"]

var _schema_version := 0
var _profiles: Array[Dictionary] = []
var _profiles_by_id: Dictionary = {}
var _last_validation_errors := PackedStringArray()


func load_catalog(path := DEFAULT_CATALOG_PATH) -> bool:
	_clear()
	if not FileAccess.file_exists(path):
		push_error("Town NPC character profile catalog does not exist: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Town NPC character profile catalog cannot be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Town NPC character profile catalog must contain a JSON object: %s" % path)
		return false
	_last_validation_errors = validate_catalog_data(parsed as Dictionary)
	if not _last_validation_errors.is_empty():
		push_error(
			"Town NPC character profile catalog failed validation (%s):\n%s"
			% [path, "\n".join(_last_validation_errors)]
		)
		return false
	_schema_version = int((parsed as Dictionary)["schema_version"])
	for profile_variant in (parsed as Dictionary)["profiles"] as Array:
		var profile := (profile_variant as Dictionary).duplicate(true)
		_profiles.append(profile)
		_profiles_by_id[StringName(profile["id"])] = profile
	_profiles.sort_custom(_sort_by_id)
	return true


func get_schema_version() -> int:
	return _schema_version


func get_all_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in _profiles:
		result.append(profile.duplicate(true))
	return result


func get_profile(character_id: StringName) -> Dictionary:
	if not _profiles_by_id.has(character_id):
		return {}
	return (_profiles_by_id[character_id] as Dictionary).duplicate(true)


func get_period_profile(character_id: StringName, day_progress: float) -> Dictionary:
	if not _profiles_by_id.has(character_id):
		return {}
	var normalized_progress := clampf(day_progress, 0.0, 0.999999)
	var profile := _profiles_by_id[character_id] as Dictionary
	for period_variant in profile["day_periods"] as Array:
		var period := period_variant as Dictionary
		if (
			normalized_progress >= float(period["start_progress"])
			and normalized_progress < float(period["end_progress"])
		):
			return period.duplicate(true)
	return {}


func get_ambient_actions(character_id: StringName) -> Array:
	if not _profiles_by_id.has(character_id):
		return []
	var profile := _profiles_by_id[character_id] as Dictionary
	return (profile["ambient_actions"] as Array).duplicate(true)


func get_allowed_interactions(character_id: StringName, partner_id: StringName) -> Array:
	if not _profiles_by_id.has(character_id):
		return []
	var profile := _profiles_by_id[character_id] as Dictionary
	for rule_variant in profile["logical_partner_interactions"] as Array:
		var rule := rule_variant as Dictionary
		if StringName(rule["partner_id"]) == partner_id:
			return (rule["interaction_ids"] as Array).duplicate(true)
	return []


func is_interaction_allowed(
	character_id: StringName,
	partner_id: StringName,
	interaction_id: StringName
) -> bool:
	return get_allowed_interactions(character_id, partner_id).has(String(interaction_id))


func get_last_validation_errors() -> PackedStringArray:
	return _last_validation_errors.duplicate()


func validate_catalog_data(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_known_keys(data, ROOT_KEYS, "root", errors)
	if not data.has("schema_version") or not _is_integer_number(data["schema_version"]):
		errors.append("root.schema_version must be an integer.")
	elif int(data["schema_version"]) != SCHEMA_VERSION:
		errors.append("root.schema_version must be %d." % SCHEMA_VERSION)
	if not data.has("profiles") or not data["profiles"] is Array:
		errors.append("root.profiles must be an array.")
		return errors
	var profiles := data["profiles"] as Array
	if profiles.is_empty():
		errors.append("root.profiles must not be empty.")
	var seen_ids := {}
	for index in profiles.size():
		var context := "profiles[%d]" % index
		if not profiles[index] is Dictionary:
			errors.append("%s must be an object." % context)
			continue
		_validate_profile(profiles[index] as Dictionary, context, seen_ids, errors)
	return errors


func _validate_profile(
	profile: Dictionary,
	context: String,
	seen_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	_validate_known_keys(profile, PROFILE_KEYS, context, errors)
	var character_id := String(profile.get("id", ""))
	if not _is_lower_snake_case(character_id):
		errors.append("%s.id must be a non-empty lower_snake_case ID." % context)
	elif seen_ids.has(character_id):
		errors.append("%s.id duplicates '%s'." % [context, character_id])
	else:
		seen_ids[character_id] = true
	var ambient_actions_valid := _validate_string_array(
		profile.get("ambient_actions"), "%s.ambient_actions" % context, false, errors
	)
	if ambient_actions_valid:
		for action in profile["ambient_actions"] as Array:
			if not _is_lower_snake_case(String(action)):
				errors.append("%s.ambient_actions contains invalid action '%s'." % [context, action])
	_validate_day_periods(profile.get("day_periods"), profile.get("ambient_actions", []), context, errors)
	_validate_partner_rules(
		profile.get("logical_partner_interactions"), character_id, context, errors
	)


func _validate_day_periods(
	periods_variant: Variant,
	ambient_actions_variant: Variant,
	profile_context: String,
	errors: PackedStringArray
) -> void:
	if not periods_variant is Array or (periods_variant as Array).is_empty():
		errors.append("%s.day_periods must be a non-empty array." % profile_context)
		return
	var ambient_actions := ambient_actions_variant as Array if ambient_actions_variant is Array else []
	var periods := periods_variant as Array
	var seen_period_ids := {}
	var previous_end := 0.0
	for index in periods.size():
		var context := "%s.day_periods[%d]" % [profile_context, index]
		if not periods[index] is Dictionary:
			errors.append("%s must be an object." % context)
			continue
		var period := periods[index] as Dictionary
		_validate_known_keys(period, DAY_PERIOD_KEYS, context, errors)
		var period_id := String(period.get("id", ""))
		if not _is_lower_snake_case(period_id):
			errors.append("%s.id must be a non-empty lower_snake_case ID." % context)
		elif seen_period_ids.has(period_id):
			errors.append("%s.id duplicates '%s'." % [context, period_id])
		else:
			seen_period_ids[period_id] = true
		var start_progress := _number_or_negative(period.get("start_progress"))
		var end_progress := _number_or_negative(period.get("end_progress"))
		if start_progress < 0.0 or end_progress > 1.0 or start_progress >= end_progress:
			errors.append("%s must satisfy 0 <= start_progress < end_progress <= 1." % context)
		if not is_equal_approx(start_progress, previous_end):
			errors.append("%s.start_progress must equal the previous end_progress %.3f." % [context, previous_end])
		previous_end = end_progress
		var locations_valid := _validate_string_array(
			period.get("locations"), "%s.locations" % context, false, errors
		)
		if locations_valid:
			for location in period["locations"] as Array:
				if not _is_lower_snake_case(String(location)):
					errors.append("%s.locations contains invalid location '%s'." % [context, location])
		var activities_valid := _validate_string_array(
			period.get("activities"), "%s.activities" % context, false, errors
		)
		if activities_valid:
			for activity in period["activities"] as Array:
				if not ambient_actions.has(activity):
					errors.append("%s.activities references undeclared ambient action '%s'." % [context, activity])
		var minimum_stay := _number_or_negative(period.get("minimum_stay_seconds"))
		if minimum_stay < 2.0 or minimum_stay > 300.0:
			errors.append("%s.minimum_stay_seconds must be between 2 and 300." % context)
	if not is_equal_approx(previous_end, 1.0):
		errors.append("%s.day_periods must end at normalized progress 1.0." % profile_context)


func _validate_partner_rules(
	rules_variant: Variant,
	character_id: String,
	profile_context: String,
	errors: PackedStringArray
) -> void:
	if not rules_variant is Array or (rules_variant as Array).is_empty():
		errors.append("%s.logical_partner_interactions must be a non-empty array." % profile_context)
		return
	var seen_partners := {}
	for index in (rules_variant as Array).size():
		var context := "%s.logical_partner_interactions[%d]" % [profile_context, index]
		var rule_variant: Variant = (rules_variant as Array)[index]
		if not rule_variant is Dictionary:
			errors.append("%s must be an object." % context)
			continue
		var rule := rule_variant as Dictionary
		_validate_known_keys(rule, PARTNER_RULE_KEYS, context, errors)
		var partner_id := String(rule.get("partner_id", ""))
		if not _is_lower_snake_case(partner_id):
			errors.append("%s.partner_id must be a non-empty lower_snake_case ID." % context)
		elif partner_id == character_id:
			errors.append("%s.partner_id must not reference the same character." % context)
		elif seen_partners.has(partner_id):
			errors.append("%s.partner_id duplicates '%s'." % [context, partner_id])
		else:
			seen_partners[partner_id] = true
		var interactions_valid := _validate_string_array(
			rule.get("interaction_ids"), "%s.interaction_ids" % context, false, errors
		)
		if interactions_valid:
			for interaction_id in rule["interaction_ids"] as Array:
				if not _is_lower_snake_case(String(interaction_id)):
					errors.append("%s.interaction_ids contains invalid ID '%s'." % [context, interaction_id])


func _validate_string_array(
	value: Variant,
	context: String,
	allow_empty: bool,
	errors: PackedStringArray
) -> bool:
	if not value is Array:
		errors.append("%s must be an array." % context)
		return false
	var values := value as Array
	if values.is_empty() and not allow_empty:
		errors.append("%s must not be empty." % context)
	var seen := {}
	for item in values:
		if not item is String or String(item).is_empty():
			errors.append("%s must contain non-empty strings." % context)
			continue
		if seen.has(String(item)):
			errors.append("%s contains duplicate '%s'." % [context, item])
		else:
			seen[String(item)] = true
	return true


func _validate_known_keys(
	dictionary: Dictionary,
	allowed_keys: Array,
	context: String,
	errors: PackedStringArray
) -> void:
	for key in dictionary:
		if not allowed_keys.has(StringName(key)):
			errors.append("%s.%s is not part of the schema." % [context, key])


func _sort_by_id(left: Dictionary, right: Dictionary) -> bool:
	return String(left["id"]) < String(right["id"])


func _is_integer_number(value: Variant) -> bool:
	return (value is int) or (value is float and is_equal_approx(value, round(value)))


func _number_or_negative(value: Variant) -> float:
	return float(value) if value is int or value is float else -1.0


func _is_lower_snake_case(value: String) -> bool:
	if value.is_empty() or value.begins_with("_") or value.ends_with("_"):
		return false
	var previous_underscore := false
	for character in value:
		var code := character.unicode_at(0)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		var is_underscore := character == "_"
		if not is_lower_letter and not is_digit and not is_underscore:
			return false
		if is_underscore and previous_underscore:
			return false
		previous_underscore = is_underscore
	return true


func _clear() -> void:
	_schema_version = 0
	_profiles.clear()
	_profiles_by_id.clear()
	_last_validation_errors = PackedStringArray()
