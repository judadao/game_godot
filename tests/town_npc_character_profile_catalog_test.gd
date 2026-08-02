extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/npc/town_npc_character_profile_catalog.gd")
const INTERACTION_CATALOG_SCRIPT := preload("res://scripts/npc/town_npc_interaction_catalog.gd")
const EXPECTED_PROFILE_IDS := ["priest", "scientist", "witch"]
const REQUIRED_ACTIONS := {
	"priest": ["prayer", "bless", "comfort", "share_goods", "courage"],
	"witch": ["read_grimoire", "brew_potion", "divination", "cast_ward", "hidden_concern"],
	"scientist": ["write_notes", "measure", "assemble", "malfunction", "inspiration", "concern"],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: RefCounted = CATALOG_SCRIPT.new()
	_expect(catalog.load_catalog(), "Town NPC character profile catalog must load.")
	_expect(catalog.get_schema_version() == 1, "Profile catalog must expose schema version 1.")
	var profiles: Array[Dictionary] = catalog.get_all_profiles()
	var profile_ids: Array[String] = []
	for profile in profiles:
		profile_ids.append(String(profile.get("id", "")))
	_expect(profile_ids == EXPECTED_PROFILE_IDS, "Profiles must use deterministic character ID ordering.")

	var interaction_catalog: RefCounted = INTERACTION_CATALOG_SCRIPT.new()
	_expect(interaction_catalog.load_catalog(), "Interaction catalog must load for profile references.")
	for character_id in EXPECTED_PROFILE_IDS:
		_assert_character_profile(catalog, interaction_catalog, character_id)

	var priest_dawn: Dictionary = catalog.get_period_profile(&"priest", 0.05)
	_expect(String(priest_dawn.get("id", "")) == "dawn", "Priest must begin the day in the dawn period.")
	_expect((priest_dawn.get("locations", []) as Array).has("temple"), "Priest dawn must include the temple.")
	_expect((priest_dawn.get("activities", []) as Array).has("prayer"), "Priest dawn must include prayer.")
	for period_variant in (catalog.get_profile(&"priest").get("day_periods", []) as Array):
		_expect(
			not ((period_variant as Dictionary).get("activities", []) as Array).has("courage"),
			"Priest courage is event-driven and must not be selected as an ambient daily activity."
		)
	var witch_night: Dictionary = catalog.get_period_profile(&"witch", 0.90)
	_expect(String(witch_night.get("id", "")) == "night", "Witch must expose a night routine.")
	_expect((witch_night.get("activities", []) as Array).has("divination"), "Witch night must include divination.")
	var scientist_afternoon: Dictionary = catalog.get_period_profile(&"scientist", 0.60)
	_expect(String(scientist_afternoon.get("id", "")) == "afternoon", "Scientist must expose an afternoon routine.")
	_expect(not (scientist_afternoon.get("activities", []) as Array).has("malfunction"), "Scientist malfunction requires an authored failure event, not ambient scheduling.")
	for period_variant in (catalog.get_profile(&"scientist").get("day_periods", []) as Array):
		_expect(
			float((period_variant as Dictionary).get("minimum_stay_seconds", 0.0)) >= 14.0,
			"Scientist activities must have a slow Town cadence instead of rapidly looping key poses."
		)

	_expect(
		catalog.is_interaction_allowed(&"priest", &"witch", &"comfort"),
		"Priest must be allowed to comfort the witch."
	)
	_expect(
		catalog.is_interaction_allowed(&"witch", &"scientist", &"discuss_work"),
		"Witch and scientist must be allowed to debate their work."
	)
	_expect(
		catalog.is_interaction_allowed(&"scientist", &"guard", &"discuss_work"),
		"Scientist must be allowed to discuss prototypes with the guard."
	)
	_expect(
		not catalog.is_interaction_allowed(&"scientist", &"guard", &"gossip"),
		"Logical partner allowlists must reject interactions not authored for the pair."
	)

	var mutable_profile: Dictionary = catalog.get_profile(&"priest")
	(mutable_profile.get("ambient_actions", []) as Array).append("consumer_mutation")
	_expect(
		not (catalog.get_ambient_actions(&"priest") as Array).has("consumer_mutation"),
		"Profile getters must return deep copies."
	)

	var invalid := {
		"schema_version": 1,
		"profiles": [{
			"id": "Bad Priest",
			"ambient_actions": ["prayer", "prayer"],
			"day_periods": [{
				"id": "dawn",
				"start_progress": 0.2,
				"end_progress": 0.1,
				"locations": [],
				"activities": ["unknown_action"],
				"minimum_stay_seconds": -1.0,
				"movement_speed": 50.0,
			}],
			"logical_partner_interactions": [{
				"partner_id": "Bad Partner",
				"interaction_ids": [],
			}],
		}],
	}
	var errors: PackedStringArray = catalog.validate_catalog_data(invalid)
	_expect(errors.size() >= 8, "Validation must reject IDs, duplicates, gaps, timing, empty lists, unknown actions, and authority fields.")
	_expect(_errors_mention(errors, "movement_speed"), "Profile schema must reject movement authority fields.")

	_finish()


func _assert_character_profile(
	catalog: RefCounted,
	interaction_catalog: RefCounted,
	character_id: String
) -> void:
	var profile: Dictionary = catalog.get_profile(StringName(character_id))
	_expect(not profile.is_empty(), "%s profile must exist." % character_id)
	var ambient_actions: Array = catalog.get_ambient_actions(StringName(character_id))
	for required_action in REQUIRED_ACTIONS[character_id]:
		_expect(
			ambient_actions.has(required_action),
			"%s must define ambient action '%s'." % [character_id, required_action]
		)
	var periods: Array = profile.get("day_periods", []) as Array
	_expect(periods.size() >= 5, "%s must define a full-day rhythm with at least five periods." % character_id)
	var previous_end := 0.0
	for period_variant in periods:
		var period := period_variant as Dictionary
		_expect(
			is_equal_approx(float(period.get("start_progress", -1.0)), previous_end),
			"%s day periods must be contiguous." % character_id
		)
		previous_end = float(period.get("end_progress", -1.0))
		_expect(float(period.get("minimum_stay_seconds", 0.0)) >= 2.0, "%s periods must have a meaningful minimum stay." % character_id)
		_expect(not (period.get("locations", []) as Array).is_empty(), "%s periods must name at least one logical location." % character_id)
		_expect(not (period.get("activities", []) as Array).is_empty(), "%s periods must name at least one activity." % character_id)
	_expect(is_equal_approx(previous_end, 1.0), "%s day periods must cover the full normalized day." % character_id)

	var partner_rules: Array = profile.get("logical_partner_interactions", []) as Array
	_expect(not partner_rules.is_empty(), "%s must define logical partner interactions." % character_id)
	for rule_variant in partner_rules:
		var rule := rule_variant as Dictionary
		for interaction_id in rule.get("interaction_ids", []) as Array:
			_expect(
				not interaction_catalog.get_interaction(StringName(interaction_id)).is_empty(),
				"%s partner rule must reference known interaction '%s'." % [character_id, interaction_id]
			)


func _errors_mention(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC setting-driven character profiles")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
