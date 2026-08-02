extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")
const LIFE_NPCS := [
	"VillagerMale", "EquipmentBlueprintMerchant", "Guard",
	"ItemMerchant", "Blacksmith", "Innkeeper",
]

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
	_advance_pair_until_state(traveler, merchant, &"social_chat")
	_expect(absf(traveler.position.x - merchant.position.x) >= 96.0, "Chat partners must stop beside rather than overlap each other.")
	_expect(traveler.npc_visual.get_active_state() == &"chat", "Traveler must play generated chat poses.")
	_expect(merchant.npc_visual.get_active_state() == &"chat", "Merchant must play generated chat poses.")
	var traveler_facing := float(traveler.npc_visual.get_animation_snapshot()["facing_sign"])
	var merchant_facing := float(merchant.npc_visual.get_animation_snapshot()["facing_sign"])
	_expect(traveler_facing > 0.0 and merchant_facing < 0.0, "Chat partners must face each other.")

	_advance_pair_until_state(traveler, merchant, &"idle")
	_expect(traveler.position == traveler_home and merchant.position == merchant_home, "Social partners must return to authored home anchors.")
	_expect(traveler.get_completed_interactions() == 1, "Traveler must record the completed social interaction.")
	_expect(merchant.get_completed_interactions() == 1, "Merchant must record the completed social interaction.")

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

	town.queue_free()
	await process_frame
	_finish()


func _advance_pair_until_state(first: TownNPCLife, second: TownNPCLife, state: StringName) -> void:
	for _step in range(200):
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
