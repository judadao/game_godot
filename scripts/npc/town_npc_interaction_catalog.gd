class_name TownNPCInteractionCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/town_npc_interactions.json"
const SCHEMA_VERSION := 1
const SUPPORTED_ANIMATION_STATES: Array[StringName] = [
	&"idle", &"idle_look", &"idle_stretch", &"walk", &"sit", &"chat",
	&"greet", &"work", &"laugh", &"happy", &"sad", &"surprised", &"angry",
]
const SUPPORTED_ARCHETYPES: Array[StringName] = [
	&"calm", &"social", &"merchant", &"scholar", &"guard", &"resident",
	&"visitor", &"worker", &"spiritual",
]
const ROOT_KEYS := [&"schema_version", &"interactions"]
const INTERACTION_KEYS := [
	&"id", &"tags", &"participants", &"duration_seconds", &"social_distance",
	&"cooldown_seconds", &"weight", &"priority", &"visitor_allowed", &"bidirectional",
]
const PARTICIPANT_KEYS := [&"roles", &"archetypes", &"animation_sequence"]
const ANIMATION_STEP_KEYS := [&"state", &"seconds"]
const SOCIAL_DISTANCE_KEYS := [&"minimum", &"preferred", &"maximum"]

var _schema_version := 0
var _interactions: Array[Dictionary] = []
var _interactions_by_id: Dictionary = {}
var _last_validation_errors := PackedStringArray()


func load_catalog(path := DEFAULT_CATALOG_PATH) -> bool:
	_clear()
	if not FileAccess.file_exists(path):
		push_error("Town NPC interaction catalog does not exist: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Town NPC interaction catalog cannot be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Town NPC interaction catalog must contain a JSON object: %s" % path)
		return false
	_last_validation_errors = validate_catalog_data(parsed as Dictionary)
	if not _last_validation_errors.is_empty():
		push_error(
			"Town NPC interaction catalog failed validation (%s):\n%s"
			% [path, "\n".join(_last_validation_errors)]
		)
		return false
	_schema_version = int((parsed as Dictionary)["schema_version"])
	for interaction_variant in (parsed as Dictionary)["interactions"] as Array:
		var interaction := (interaction_variant as Dictionary).duplicate(true)
		_interactions.append(interaction)
		_interactions_by_id[StringName(interaction["id"])] = interaction
	_interactions.sort_custom(_sort_by_id)
	return true


func get_schema_version() -> int:
	return _schema_version


func get_all_interactions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for interaction in _interactions:
		result.append(interaction.duplicate(true))
	return result


func get_interaction(interaction_id: StringName) -> Dictionary:
	if not _interactions_by_id.has(interaction_id):
		return {}
	return (_interactions_by_id[interaction_id] as Dictionary).duplicate(true)


func get_candidates(
	actor_a_role: StringName,
	actor_a_archetype: StringName,
	actor_b_role: StringName,
	actor_b_archetype: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for interaction in _interactions:
		var resolved := _resolve_for_pair(
			interaction,
			actor_a_role,
			actor_a_archetype,
			actor_b_role,
			actor_b_archetype
		)
		if not resolved.is_empty():
			result.append(resolved)
	result.sort_custom(_sort_candidates)
	return result


func select_candidate(
	actor_a_role: StringName,
	actor_a_archetype: StringName,
	actor_b_role: StringName,
	actor_b_archetype: StringName,
	deterministic_roll: float,
	required_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var candidates := get_candidates(
		actor_a_role,
		actor_a_archetype,
		actor_b_role,
		actor_b_archetype
	)
	var eligible: Array[Dictionary] = []
	var total_weight := 0.0
	for candidate in candidates:
		if not _has_all_tags(candidate, required_tags):
			continue
		eligible.append(candidate)
		total_weight += float(candidate["weight"])
	if eligible.is_empty() or total_weight <= 0.0:
		return {}
	var threshold := clampf(deterministic_roll, 0.0, 0.999999) * total_weight
	for candidate in eligible:
		threshold -= float(candidate["weight"])
		if threshold < 0.0:
			return candidate.duplicate(true)
	return eligible.back().duplicate(true)


func is_pair_eligible(
	interaction_id: StringName,
	actor_a_role: StringName,
	actor_a_archetype: StringName,
	actor_b_role: StringName,
	actor_b_archetype: StringName
) -> bool:
	if not _interactions_by_id.has(interaction_id):
		return false
	return not _resolve_for_pair(
		_interactions_by_id[interaction_id] as Dictionary,
		actor_a_role,
		actor_a_archetype,
		actor_b_role,
		actor_b_archetype
	).is_empty()


func resolve_interaction(
	interaction_id: StringName,
	actor_a_role: StringName,
	actor_a_archetype: StringName,
	actor_b_role: StringName,
	actor_b_archetype: StringName
) -> Dictionary:
	if not _interactions_by_id.has(interaction_id):
		return {}
	return _resolve_for_pair(
		_interactions_by_id[interaction_id] as Dictionary,
		actor_a_role,
		actor_a_archetype,
		actor_b_role,
		actor_b_archetype
	)


func get_last_validation_errors() -> PackedStringArray:
	return _last_validation_errors.duplicate()


func validate_catalog_data(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_known_keys(data, ROOT_KEYS, "root", errors)
	if not data.has("schema_version") or not _is_integer_number(data["schema_version"]):
		errors.append("root.schema_version must be an integer.")
	elif int(data["schema_version"]) != SCHEMA_VERSION:
		errors.append("root.schema_version must be %d." % SCHEMA_VERSION)
	if not data.has("interactions") or not data["interactions"] is Array:
		errors.append("root.interactions must be an array.")
		return errors
	var interactions := data["interactions"] as Array
	if interactions.is_empty():
		errors.append("root.interactions must not be empty.")
	var seen_ids := {}
	for index in interactions.size():
		var context := "interactions[%d]" % index
		if not interactions[index] is Dictionary:
			errors.append("%s must be an object." % context)
			continue
		_validate_interaction(interactions[index] as Dictionary, context, seen_ids, errors)
	return errors


func _validate_interaction(
	interaction: Dictionary,
	context: String,
	seen_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	_validate_known_keys(interaction, INTERACTION_KEYS, context, errors)
	var interaction_id := String(interaction.get("id", ""))
	if not _is_lower_snake_case(interaction_id):
		errors.append("%s.id must be a non-empty lower_snake_case ID." % context)
	elif seen_ids.has(interaction_id):
		errors.append("%s.id duplicates '%s'." % [context, interaction_id])
	else:
		seen_ids[interaction_id] = true
	_validate_string_array(interaction.get("tags"), "%s.tags" % context, false, errors)
	var duration := _number_or_negative(interaction.get("duration_seconds"))
	if duration < 0.2 or duration > 30.0:
		errors.append("%s.duration_seconds must be between 0.2 and 30.0." % context)
	var participants_variant: Variant = interaction.get("participants")
	if not participants_variant is Array or (participants_variant as Array).size() != 2:
		errors.append("%s.participants must contain exactly two participants." % context)
	else:
		for participant_index in 2:
			_validate_participant(
				(participants_variant as Array)[participant_index],
				"%s.participants[%d]" % [context, participant_index],
				duration,
				errors
			)
	_validate_social_distance(interaction.get("social_distance"), context, errors)
	var cooldown := _number_or_negative(interaction.get("cooldown_seconds"))
	if cooldown < duration or cooldown > 300.0:
		errors.append("%s.cooldown_seconds must be at least duration_seconds and no more than 300." % context)
	var weight := _number_or_negative(interaction.get("weight"))
	if weight <= 0.0 or weight > 10.0:
		errors.append("%s.weight must be greater than 0 and no more than 10." % context)
	if not _is_integer_number(interaction.get("priority")) or int(interaction.get("priority", -1)) not in range(0, 101):
		errors.append("%s.priority must be an integer from 0 through 100." % context)
	for boolean_field in ["visitor_allowed", "bidirectional"]:
		if not interaction.get(boolean_field) is bool:
			errors.append("%s.%s must be a boolean." % [context, boolean_field])


func _validate_participant(
	participant_variant: Variant,
	context: String,
	duration: float,
	errors: PackedStringArray
) -> void:
	if not participant_variant is Dictionary:
		errors.append("%s must be an object." % context)
		return
	var participant := participant_variant as Dictionary
	_validate_known_keys(participant, PARTICIPANT_KEYS, context, errors)
	var valid_roles := _validate_string_array(participant.get("roles"), "%s.roles" % context, true, errors)
	var valid_archetypes := _validate_string_array(
		participant.get("archetypes"), "%s.archetypes" % context, true, errors
	)
	if valid_roles and valid_archetypes:
		var roles := participant["roles"] as Array
		var archetypes := participant["archetypes"] as Array
		if roles.is_empty() and archetypes.is_empty():
			errors.append("%s must allow at least one role or archetype." % context)
		for role in roles:
			if String(role) != "*" and not _is_lower_snake_case(String(role)):
				errors.append("%s.roles contains invalid role '%s'." % [context, role])
		for archetype in archetypes:
			if StringName(archetype) != &"*" and not SUPPORTED_ARCHETYPES.has(StringName(archetype)):
				errors.append("%s.archetypes contains unsupported archetype '%s'." % [context, archetype])
	var sequence_variant: Variant = participant.get("animation_sequence")
	if not sequence_variant is Array or (sequence_variant as Array).is_empty():
		errors.append("%s.animation_sequence must be a non-empty array." % context)
		return
	var sequence_total := 0.0
	for step_index in (sequence_variant as Array).size():
		var step_context := "%s.animation_sequence[%d]" % [context, step_index]
		var step_variant: Variant = (sequence_variant as Array)[step_index]
		if not step_variant is Dictionary:
			errors.append("%s must be an object." % step_context)
			continue
		var step := step_variant as Dictionary
		_validate_known_keys(step, ANIMATION_STEP_KEYS, step_context, errors)
		var state := StringName(step.get("state", ""))
		if not SUPPORTED_ANIMATION_STATES.has(state):
			errors.append("%s.state uses unsupported animation '%s'." % [step_context, state])
		var seconds := _number_or_negative(step.get("seconds"))
		if seconds <= 0.0 or seconds > 10.0:
			errors.append("%s.seconds must be greater than 0 and no more than 10." % step_context)
		else:
			sequence_total += seconds
	if duration >= 0.0 and not is_equal_approx(sequence_total, duration):
		errors.append("%s.animation_sequence must total duration_seconds (%.3f != %.3f)." % [context, sequence_total, duration])


func _validate_social_distance(distance_variant: Variant, context: String, errors: PackedStringArray) -> void:
	if not distance_variant is Dictionary:
		errors.append("%s.social_distance must be an object." % context)
		return
	var distance := distance_variant as Dictionary
	_validate_known_keys(distance, SOCIAL_DISTANCE_KEYS, "%s.social_distance" % context, errors)
	var minimum := _number_or_negative(distance.get("minimum"))
	var preferred := _number_or_negative(distance.get("preferred"))
	var maximum := _number_or_negative(distance.get("maximum"))
	if minimum < 36.0 or maximum > 420.0 or minimum > preferred or preferred > maximum:
		errors.append(
			"%s.social_distance must satisfy 36 <= minimum <= preferred <= maximum <= 420."
			% context
		)


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


func _resolve_for_pair(
	interaction: Dictionary,
	actor_a_role: StringName,
	actor_a_archetype: StringName,
	actor_b_role: StringName,
	actor_b_archetype: StringName
) -> Dictionary:
	if (
		(actor_a_archetype == &"visitor" or actor_b_archetype == &"visitor")
		and not bool(interaction["visitor_allowed"])
	):
		return {}
	var participants := interaction["participants"] as Array
	var direct := (
		_selector_matches(participants[0] as Dictionary, actor_a_role, actor_a_archetype)
		and _selector_matches(participants[1] as Dictionary, actor_b_role, actor_b_archetype)
	)
	var swapped := false
	if not direct and bool(interaction["bidirectional"]):
		swapped = (
			_selector_matches(participants[1] as Dictionary, actor_a_role, actor_a_archetype)
			and _selector_matches(participants[0] as Dictionary, actor_b_role, actor_b_archetype)
		)
	if not direct and not swapped:
		return {}
	var actor_a_participant := participants[1] as Dictionary if swapped else participants[0] as Dictionary
	var actor_b_participant := participants[0] as Dictionary if swapped else participants[1] as Dictionary
	var result := interaction.duplicate(true)
	result["actor_a_sequence"] = (actor_a_participant["animation_sequence"] as Array).duplicate(true)
	result["actor_b_sequence"] = (actor_b_participant["animation_sequence"] as Array).duplicate(true)
	result["participant_order"] = "swapped" if swapped else "direct"
	return result


func _selector_matches(selector: Dictionary, role: StringName, archetype: StringName) -> bool:
	var roles := selector["roles"] as Array
	var archetypes := selector["archetypes"] as Array
	return (
		roles.has("*")
		or roles.has(String(role))
		or archetypes.has("*")
		or archetypes.has(String(archetype))
	)


func _has_all_tags(interaction: Dictionary, required_tags: PackedStringArray) -> bool:
	var interaction_tags := interaction["tags"] as Array
	for required_tag in required_tags:
		if not interaction_tags.has(required_tag):
			return false
	return true


func _sort_by_id(left: Dictionary, right: Dictionary) -> bool:
	return String(left["id"]) < String(right["id"])


func _sort_candidates(left: Dictionary, right: Dictionary) -> bool:
	var left_priority := int(left["priority"])
	var right_priority := int(right["priority"])
	if left_priority != right_priority:
		return left_priority > right_priority
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
	_interactions.clear()
	_interactions_by_id.clear()
	_last_validation_errors = PackedStringArray()
