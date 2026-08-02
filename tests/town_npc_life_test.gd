extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")
const LIFE_NPCS := [
	"VillagerMale", "EquipmentBlueprintMerchant", "Guard",
	"ItemMerchant", "Blacksmith", "Innkeeper",
]
const EXPECTED_ROLE_ACTIVITIES := {
	"VillagerMale": &"watch_square",
	"EquipmentBlueprintMerchant": &"check_charms",
	"Guard": &"watch_street",
	"ItemMerchant": &"arrange_goods",
	"Blacksmith": &"inspect_notes",
	"Innkeeper": &"welcome_guests",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := TOWN_SCENE.instantiate()
	root.add_child(town)
	await process_frame
	var actors: Array[TownNPCLife] = []
	for node_name in LIFE_NPCS:
		var actor := town.get_node_or_null("NPCs/%s" % node_name) as TownNPCLife
		_expect(actor != null, "%s must use TownNPCLife." % node_name)
		if actor != null:
			actors.append(actor)
			actor.set_process(false)
			_expect(actor is AnimatableBody2D, "%s must remain a movable collision body." % node_name)
			_expect(actor.is_in_group("town_life_npcs"), "%s must join the Town life group." % node_name)
			_expect(actor.get_home_position() == actor.position, "%s must capture its authored home anchor." % node_name)
	if actors.size() != LIFE_NPCS.size():
		_finish()
		return
	var traveler_bounds := actors[0].get_wander_bounds()
	var merchant_bounds := (town.get_node("NPCs/ItemMerchant") as TownNPCLife).get_wander_bounds()
	_expect(
		merchant_bounds.x - traveler_bounds.y >= 78.0,
		"Adjacent autonomous roam zones must preserve at least one body width of separation."
	)
	var guard := town.get_node("NPCs/Guard") as TownNPCLife
	guard.request_rest(1.0)
	_expect(guard.get_life_state() == &"rest", "Living NPCs must expose a seated rest activity.")
	_expect(guard.npc_visual.get_active_state() == &"sit", "Rest must play the authored sit animation.")

	for actor in actors:
		actor.life_enabled = false
	var traveler := town.get_node("NPCs/VillagerMale") as TownNPCLife
	var merchant := town.get_node("NPCs/ItemMerchant") as TownNPCLife
	traveler.life_enabled = true
	merchant.life_enabled = true
	traveler.minimum_idle_seconds = 0.1
	traveler.maximum_idle_seconds = 0.1
	traveler.social_chance = 1.0
	traveler.walk_speed = 600.0
	merchant.walk_speed = 600.0
	traveler.social_chat_seconds = 0.2
	merchant.social_chat_seconds = 0.2
	var traveler_home := traveler.position
	var merchant_home := merchant.position

	traveler.advance_life(10.0)
	_expect(traveler.get_life_state() == &"social_walk", "Available neighbors must schedule a social walk.")
	_expect(merchant.get_life_state() == &"social_walk", "A social invitation must reserve both participants.")
	_expect(traveler.get_social_partner() == merchant, "Traveler must retain the reserved partner.")
	_expect(merchant.get_social_partner() == traveler, "Merchant must retain the reserved partner.")
	guard.life_enabled = true
	guard.social_chance = 1.0
	guard.social_radius = 1000.0
	guard.advance_life(10.0)
	_expect(guard.get_social_partner() == null, "A third resident must not steal an already reserved partner.")
	_advance_pair_until_state(traveler, merchant, &"social_greet")
	_expect(
		float(traveler.get("_state_timer")) >= 1.5,
		"Residents must pause for a readable greeting instead of rushing into chat."
	)
	var expected_greeting := (
		&"greet" if traveler.npc_visual.get_supported_states().has(&"greet") else &"chat"
	)
	_expect(
		traveler.npc_visual.get_active_state() == expected_greeting,
		"The greeter must visibly open the conversation."
	)
	_advance_pair_until_state(traveler, merchant, &"social_chat")
	_expect(
		absf(traveler.position.x - merchant.position.x) >= 96.0,
		"Chat partners must stop beside rather than overlap each other."
	)
	_expect(traveler.npc_visual.get_active_state() == &"chat", "Traveler must play generated chat poses.")
	_expect(merchant.npc_visual.get_active_state() == &"chat", "Merchant must play generated chat poses.")
	var traveler_facing := float(traveler.npc_visual.get_animation_snapshot()["facing_sign"])
	var merchant_facing := float(merchant.npc_visual.get_animation_snapshot()["facing_sign"])
	_expect(traveler_facing > 0.0 and merchant_facing < 0.0, "Chat partners must face each other.")
	_advance_pair_until_state(traveler, merchant, &"social_react")
	_expect(
		float(traveler.get("_state_timer")) >= 1.5,
		"Face-to-face reactions need a relaxed beat before farewell."
	)
	_expect(
		traveler.npc_visual.get_active_state() == &"chat"
		and merchant.npc_visual.get_active_state() == &"chat",
		"Face-to-face reactions must preserve the directional conversation pose instead of snapping front-facing."
	)
	_advance_pair_until_state(traveler, merchant, &"social_farewell")
	_expect(
		float(traveler.get("_state_timer")) >= 1.2,
		"Farewell must remain visible long enough to read as a deliberate gesture."
	)

	_advance_pair_until_state(traveler, merchant, &"idle")
	_expect(
		traveler.position == traveler_home and merchant.position == merchant_home,
		"Social partners must return to authored home anchors."
	)
	_expect(traveler.get_completed_interactions() == 1, "Traveler must record the completed social interaction.")
	_expect(merchant.get_completed_interactions() == 1, "Merchant must record the completed social interaction.")
	var expected_sequence: Array[StringName] = [
		&"social_greet", &"social_chat", &"social_react", &"social_farewell",
	]
	_expect(
		traveler.get_last_social_sequence() == expected_sequence,
		"A relaxed conversation must progress through greeting, chat, reaction, and farewell."
	)
	_expect(
		merchant.get_last_social_sequence() == expected_sequence,
		"Both participants must retain the same completed conversation sequence."
	)
	_expect(
		traveler.get_last_completed_interaction_id() == &"greet"
		and merchant.get_last_completed_interaction_id() == &"greet",
		"Residents meeting for the first time must select the catalog's welcoming greeting."
	)
	_expect(
		traveler.get_last_social_reaction() == &"happy",
		"The greeting catalog sequence must resolve to a friendly reaction."
	)
	_expect(
		traveler.get_relationship_count(merchant) == 1
		and merchant.get_relationship_count(traveler) == 1,
		"A completed conversation must raise the relationship count for both residents."
	)
	_expect(
		not traveler.is_available_for_social() and not merchant.is_available_for_social(),
		"A completed interaction must apply its catalog cooldown to both residents."
	)

	guard.life_enabled = false
	traveler.life_enabled = false
	merchant.life_enabled = false
	traveler.advance_life(100.0)
	merchant.advance_life(100.0)
	traveler.life_enabled = true
	merchant.life_enabled = true
	town.call("set_time_of_day_progress", 1.0)
	traveler.advance_life(10.0)
	_expect(
		traveler.get_social_partner() == merchant,
		"Residents must be able to reserve another conversation after returning home."
	)
	_expect(
		traveler.get_active_interaction_id() == &"watch_sky"
		and merchant.get_active_interaction_id() == &"watch_sky",
		"Familiar residents must choose the scenic catalog interaction during golden hour."
	)
	_advance_pair_until_state(traveler, merchant, &"social_greet")
	merchant.set_external_interaction(true, Vector2(merchant.position.x + 100.0, merchant.position.y))
	_expect(
		merchant.get_life_state() == &"external_chat",
		"External interactions must preempt an autonomous conversation."
	)
	_expect(traveler.get_life_state() == &"return_home", "A cancelled partner must calmly return home.")
	_expect(
		traveler.get_social_partner() == null,
		"Cancelling a conversation must release the other resident's reservation."
	)
	_expect(
		traveler.get_completed_interactions() == 1,
		"Cancelled conversations must not count as completed interactions."
	)
	merchant.set_external_interaction(false)
	_advance_pair_until_state(traveler, merchant, &"idle")

	var witch := town.get_node("NPCs/EquipmentBlueprintMerchant") as TownNPCLife
	witch.life_enabled = true
	var witch_home := witch.position
	witch.set_external_interaction(true, Vector2(witch.position.x + 100.0, witch.position.y))
	_expect(witch.get_life_state() == &"external_chat", "Priest conversations must lock the witch into external chat.")
	_expect(witch.npc_visual.get_active_state() == &"chat", "External chat must use generated chat poses.")
	witch.advance_life(20.0)
	_expect(witch.position == witch_home, "External interaction lock must prevent autonomous wandering.")
	witch.set_external_interaction(false)
	_expect(witch.get_life_state() == &"idle", "Releasing external chat must restore autonomous idle.")

	for actor in actors:
		actor.life_enabled = false
	var scientist := town.get_node("NPCs/Blacksmith") as TownNPCLife
	witch.life_enabled = true
	scientist.life_enabled = true
	witch.social_chance = 1.0
	witch.social_radius = 2000.0
	witch.minimum_idle_seconds = 0.1
	witch.maximum_idle_seconds = 0.1
	witch.walk_speed = 600.0
	scientist.walk_speed = 600.0
	town.call("set_time_of_day_progress", 0.0)
	witch.advance_life(10.0)
	_advance_pair_until_state(witch, scientist, &"idle")
	witch.life_enabled = false
	scientist.life_enabled = false
	witch.advance_life(100.0)
	scientist.advance_life(100.0)
	witch.life_enabled = true
	scientist.life_enabled = true
	witch.advance_life(10.0)
	_expect(
		witch.get_active_interaction_id() == &"discuss_work"
		and scientist.get_active_interaction_id() == &"discuss_work",
		"Familiar working residents must select a role-appropriate daytime discussion."
	)
	witch.cancel_social_interaction()
	_expect(
		witch.get_life_state() == &"return_home"
		and scientist.get_life_state() == &"return_home",
		"Either participant must be able to cancel a reserved interaction cleanly."
	)
	witch.life_enabled = false
	scientist.life_enabled = false

	var role_activities: Array[StringName] = []
	for actor in actors:
		actor.request_role_activity(1.0)
		var activity_name := actor.get_role_activity_name()
		role_activities.append(activity_name)
		_expect(
			activity_name == EXPECTED_ROLE_ACTIVITIES.get(String(actor.name), &""),
			"%s must perform a daily activity tied to its resident role." % actor.name
		)
		_expect(
			actor.get_life_state() == &"role_activity",
			"%s must expose its daily activity as an observable life state." % actor.name
		)
	var expected_guard_work := (
		&"work" if guard.npc_visual.get_supported_states().has(&"work") else &"angry"
	)
	_expect(
		guard.npc_visual.get_active_state() == expected_guard_work,
		"The guard must visibly survey the street while on duty."
	)
	_expect(role_activities.size() == 6, "All six residents must expose role-specific daily activity contracts.")
	var unique_role_activities: Array[StringName] = []
	for activity_name in role_activities:
		if not unique_role_activities.has(activity_name):
			unique_role_activities.append(activity_name)
	_expect(unique_role_activities.size() == 6, "Resident roles must not collapse into one generic work activity.")

	town.queue_free()
	await process_frame
	_finish()


func _advance_pair_until_state(first: TownNPCLife, second: TownNPCLife, state: StringName) -> void:
	for _step in range(600):
		if first.get_life_state() == state and second.get_life_state() == state:
			return
		first.advance_life(0.05)
		second.advance_life(0.05)
	_expect(false, "Social pair must reach %s without stalling." % state)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC autonomous life and social interaction")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
