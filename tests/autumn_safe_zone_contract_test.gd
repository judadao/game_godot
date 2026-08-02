extends SceneTree

const SAFE_CANONICAL_PATH := "res://scenes/maps/autumn_safe_zone.tscn"
const SAFE_MAP_PATH := "res://scenes/maps/autumn_safe/AutumnSafeZoneMap.tscn"
const BATTLE_CANONICAL_PATH := "res://scenes/maps/autumn_forest.tscn"
const TOWN_CANONICAL_PATH := "res://scenes/maps/town.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ResourceLoader.exists(SAFE_MAP_PATH, "PackedScene"),
		"Autumn safe zone must have an authoritative map scene."
	)
	if not ResourceLoader.exists(SAFE_MAP_PATH, "PackedScene"):
		quit(1)
		return

	var registry: Object = (load("res://scripts/systems/map_registry.gd") as Script).new()
	_expect(
		String(registry.call("resolve", SAFE_CANONICAL_PATH)) == SAFE_MAP_PATH,
		"Autumn safe canonical path must resolve to AutumnSafeZoneMap."
	)

	var map := (load(SAFE_MAP_PATH) as PackedScene).instantiate()
	root.add_child(map)
	await process_frame

	_expect(map.name == "AutumnSafeZoneMap", "Safe zone root must retain its map identity.")
	_expect(
		String(map.get_meta("map_role", "")) == "autumn_safe_zone",
		"Safe zone must declare its map role."
	)
	_expect(
		int(map.get_meta("map_width", 0)) == 1280
			and int(map.get_meta("camera_limit_right", 0)) == 1280,
		"Safe-zone camp must fit inside one 1280px gameplay viewport."
	)
	for node_path in [
		"PlayerSpawn",
		"BattleReturnSpawn",
		"Player",
		"WorldCollision/FloorCollision",
		"TownPortal",
		"BattlePortal",
		"Campfire",
		"SeatedTrailMerchant",
		"EditorHUDReference/HUD",
	]:
		_expect(map.has_node(node_path), "Safe zone must author %s." % node_path)

	var players := map.find_children("Player", "CharacterBody2D", true, false)
	var cameras := map.find_children("*", "Camera2D", true, false)
	var directors := map.find_children("*", "SurvivalWaveDirector", true, false)
	var card_hands: Array[Node] = []
	for control in map.find_children("*", "Control", true, false):
		if control is CardHandUI:
			card_hands.append(control)
	_expect(players.size() == 1, "Safe zone must own exactly one Player.")
	_expect(cameras.size() == 1, "Safe zone must own exactly one Camera2D.")
	_expect(directors.is_empty(), "Safe zone must not own a combat director.")
	_expect(card_hands.is_empty(), "Safe zone must not create an unused CardHand UI authority.")
	_expect(not map.has_node("Shelter"), "Safe-zone camp must not render an unrelated house behind the fire.")

	var town_portal := map.get_node_or_null("TownPortal")
	var battle_portal := map.get_node_or_null("BattlePortal")
	var spawn := map.get_node_or_null("PlayerSpawn") as Node2D
	var campfire := map.get_node_or_null("Campfire") as Node2D
	var merchant := map.get_node_or_null("SeatedTrailMerchant") as CollisionObject2D
	if town_portal != null:
		_expect(
			String(town_portal.get("target_scene_path")) == TOWN_CANONICAL_PATH,
			"Safe zone TownPortal must return to Town."
		)
		_expect(
			(town_portal as Node2D).position.x >= 140.0,
			"Safe-zone Town portal must remain fully inside the left camera edge."
		)
	if battle_portal != null:
		_expect(
			String(battle_portal.get("target_scene_path")) == BATTLE_CANONICAL_PATH,
			"Safe zone BattlePortal must enter the Autumn battle canonical route."
		)
		_expect(
			(battle_portal as Node2D).position.x <= 1180.0,
			"Safe-zone Battle portal must remain fully inside the right camera edge."
		)
	if town_portal is Node2D and battle_portal is Node2D and spawn != null and campfire != null:
		_expect(
			(town_portal as Node2D).position.x
				< spawn.position.x
				and spawn.position.x
				< campfire.position.x
				and campfire.position.x
				< (battle_portal as Node2D).position.x,
			"Safe zone must progress left-to-right from Town return to camp to battle."
		)
	if merchant != null and campfire != null:
		_expect(
			merchant.collision_layer == 0,
			"Seated merchant body must not block the safe-zone route."
		)
		_expect(
			absf((merchant as Node2D).position.x - campfire.position.x) <= 260.0,
			"Seated merchant must remain visibly beside the campfire."
		)
		_expect(
			merchant.has_node("Visual")
				and merchant.has_node("Visual/VisualRoot/BodySprite")
				and (merchant.get_node("Visual/VisualRoot/BodySprite") as Sprite2D).texture != null
				and merchant.get_node("Visual").call("get_active_state") == &"sit",
			"Seated merchant must use an authored character visual."
		)

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
