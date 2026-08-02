extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := TOWN_SCENE.instantiate()
	root.add_child(town)
	await process_frame
	var witch := town.get_node("NPCs/EquipmentBlueprintMerchant") as TownNPCLife
	var scientist := town.get_node("NPCs/Blacksmith") as TownNPCLife
	witch.set_process(false)
	scientist.set_process(false)
	_expect(
		witch.minimum_idle_seconds >= 5.0 and witch.maximum_idle_seconds >= 9.0,
		"Profile residents need long idle windows for a relaxed Town cadence."
	)
	_expect(
		witch.social_chance <= 0.12,
		"Witch must use a low-frequency social initiation cadence."
	)
	_expect(
		float(witch.get("minimum_social_recovery_seconds")) >= 120.0,
		"Witch must keep a long global recovery after both initiated and received conversations."
	)
	_expect(
		scientist.minimum_role_recovery_seconds >= 10.0
		and scientist.maximum_role_recovery_seconds >= 16.0,
		"Scientist needs a long recovery window between authored work actions."
	)
	town.call("set_time_of_day_progress", 0.20)

	_expect(witch.get_current_period_id() == &"morning", "Witch runtime must resolve the current profile period from Town time.")
	_expect(
		witch.call("_character_archetype") == &"scholar",
		"Witch interactions must use the scholar archetype."
	)
	_expect(
		not witch.request_character_activity(&"unknown_action", 20.0),
		"Character activity requests must reject actions absent from the profile."
	)
	_expect(
		witch.request_character_activity(&"read_grimoire", 0.2),
		"Character activity requests must accept actions declared by the profile."
	)
	_expect(witch.get_life_state() == &"role_activity", "Accepted character actions must enter role activity state.")
	_expect(witch.get_role_activity_name() == &"read_grimoire", "Requested character action must be observable.")
	_expect(witch.npc_visual.get_active_state() == &"read_grimoire", "Role activity must prefer the character-specific visual.")
	witch.advance_life(11.9)
	_expect(
		witch.get_life_state() == &"role_activity",
		"Requested character activity must honor the period's 12-second minimum stay."
	)
	witch.advance_life(0.2)
	_expect(witch.get_life_state() == &"idle", "Completed character activity must use normal idle recovery.")

	witch.call("_begin_scheduled_role_activity")
	var first_scheduled_action := witch.get_role_activity_name()
	_expect(
		first_scheduled_action != &"read_grimoire",
		"Automatic period scheduling must avoid the most recently completed character action."
	)
	witch.advance_life(12.1)
	witch.call("_begin_scheduled_role_activity")
	_expect(
		witch.get_role_activity_name() != first_scheduled_action,
		"Automatic period scheduling must not select the same character action consecutively."
	)

	_expect(
		scientist.request_character_activity(&"write_notes", 0.2),
		"Scientist must accept a profile-backed morning work action."
	)
	scientist.advance_life(17.9)
	_expect(
		scientist.get_life_state() == &"role_activity",
		"Scientist morning work must preserve its relaxed 18-second minimum stay."
	)
	scientist.advance_life(0.2)
	_expect(
		scientist.get_life_state() == &"idle",
		"Scientist must return to the long idle recovery after completing work."
	)

	witch.call("_prepare_social_interaction", scientist)
	_expect(
		[&"discuss_work", &"chat", &"watch_sky"].has(witch.get_active_interaction_id()),
		"Profile-backed social selection must stay inside the mutual witch/scientist allowlist."
	)

	witch.cancel_social_interaction()
	witch.social_chance = 0.0
	witch.role_activity_chance = 0.0
	witch.walk_speed = 10000.0
	for cycle in range(24):
		witch.call("_choose_next_activity")
		_expect(
			witch.get_life_state() != &"rest",
			"Profile characters must not enter the generic sit row without an authored seat event (cycle %d)." % cycle
		)
		witch.advance_life(100.0)

	town.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC runtime consumes character profiles")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
