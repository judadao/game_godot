extends SceneTree

const BATTLE_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const REQUIRED_NODE_PATHS: Array[String] = [
	"Background",
	"Ground",
	"Ground/Platforms",
	"SetDressing",
	"GameplayZones",
	"GameplayZones/SpawnZone",
	"GameplayZones/EventChoiceZone",
	"GameplayZones/EnemyWaveZone",
	"GameplayZones/MerchantZone",
	"GameplayZones/ExitZone",
	"PlayerSpawn",
	"ForestShortcutSpawn",
	"Player",
	"AutumnRunDirector",
	"HiddenBranchCache",
	"ForestRest",
	"ShortcutLever",
	"WanderingCardMerchant",
	"WorldCollision",
	"WorldCollision/FloorCollision",
	"WorldCollision/LeftWall",
	"WorldCollision/RightWall",
	"TownPortal",
	"ForwardPortal",
	"EditorHUDReference",
	"EditorHUDReference/HUD",
	"EditorHUDReference/CardHandUI",
	"EditorHelpers",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ResourceLoader.exists(BATTLE_MAP_PATH),
		"Autumn Battle Map V2 must exist at its authoritative scene path."
	)
	if not ResourceLoader.exists(BATTLE_MAP_PATH):
		quit(1)
		return

	var packed := load(BATTLE_MAP_PATH) as PackedScene
	_expect(packed != null, "Autumn Battle Map V2 must load as a PackedScene.")
	if packed == null:
		quit(1)
		return

	_assert_scene_is_standalone(packed)

	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	_expect(map is Node2D, "Autumn Battle Map V2 root must be a Node2D.")
	_expect(map.name == "AutumnBattleMapV2", "Autumn Battle Map V2 must retain its authoritative root name.")
	_expect(map.scene_file_path == BATTLE_MAP_PATH, "The V2 instance must retain its authoritative scene path.")
	_expect(int(map.get_meta("map_width", 0)) == 2600, "V2 map width must be 2600.")
	_expect(int(map.get_meta("map_height", 0)) == 720, "V2 map height must be 720.")
	_expect(int(map.get_meta("camera_limit_left", -1)) == 0, "V2 camera left limit must be 0.")
	_expect(int(map.get_meta("camera_limit_top", -1)) == 0, "V2 camera top limit must be 0.")
	_expect(int(map.get_meta("camera_limit_right", 0)) == 2600, "V2 camera right limit must be 2600.")
	_expect(int(map.get_meta("camera_limit_bottom", 0)) == 720, "V2 camera bottom limit must be 720.")

	for node_path in REQUIRED_NODE_PATHS:
		_expect(map.has_node(node_path), "Autumn Battle Map V2 must contain %s." % node_path)

	var players := map.find_children("Player", "CharacterBody2D", true, false)
	var cameras := map.find_children("*", "Camera2D", true, false)
	var hud_roots := map.find_children("HUD", "Control", true, false)
	var card_hand_roots := map.find_children("CardHandUI", "Control", true, false)
	_expect(players.size() == 1, "V2 must own exactly one Player.")
	_expect(cameras.size() == 1, "V2 must own exactly one Camera2D.")
	_expect(hud_roots.size() == 1, "V2 must reference exactly one HUD.")
	_expect(card_hand_roots.size() == 1, "V2 must reference exactly one CardHandUI.")

	var director := map.get_node_or_null("AutumnRunDirector")
	_expect(director is SurvivalWaveDirector, "AutumnRunDirector must reuse SurvivalWaveDirector.")
	_expect(
		director != null and director.is_in_group("EncounterDirectors"),
		"AutumnRunDirector must be discoverable through EncounterDirectors."
	)
	_assert_interaction_contracts(map)

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _assert_scene_is_standalone(packed: PackedScene) -> void:
	var state := packed.get_state()
	_expect(
		state.get_node_instance(0) == null,
		"Autumn Battle Map V2 root must be authored standalone, not inherited from a legacy map."
	)
	for index in state.get_node_count():
		var node_path := String(state.get_node_path(index))
		var is_nested_hud_override := (
			node_path.begins_with("EditorHUDReference/HUD/")
			or node_path.begins_with("EditorHUDReference/CardHandUI/")
		)
		_expect(
			not is_nested_hud_override,
			"V2 must not serialize nested EditorHUDReference overrides: %s." % node_path
		)


func _assert_interaction_contracts(map: Node) -> void:
	var expectations := {
		"HiddenBranchCache": {
			"interaction_id": &"forest_hidden_cache",
			"loot_table_id": &"forest_hidden_cache",
		},
		"ForestRest": {
			"interaction_id": &"forest_rest",
			"loot_table_id": &"forest_rest",
		},
		"ShortcutLever": {
			"interaction_id": &"forest_shortcut",
			"loot_table_id": &"forest_shortcut",
		},
		"WanderingCardMerchant": {
			"interaction_id": &"wandering_card_merchant",
			"shop_id": &"wandering_cards",
		},
		"TownPortal": {
			"interaction_id": &"autumn_forest_return",
			"target_scene_path": "res://scenes/maps/town.tscn",
			"target_spawn_name": &"PlayerSpawn",
		},
		"ForwardPortal": {
			"interaction_id": &"autumn_forward_gate",
			"target_scene_path": "res://scenes/maps/crystal_caves.tscn",
			"target_spawn_name": &"PlayerSpawn",
			"locked": true,
		},
	}
	for node_path in expectations:
		var interaction := map.get_node_or_null(node_path)
		_expect(interaction != null, "%s must exist for interaction contract checks." % node_path)
		if interaction == null:
			continue
		for property_name in expectations[node_path]:
			_expect(
				interaction.get(property_name) == expectations[node_path][property_name],
				"%s must preserve %s." % [node_path, property_name]
			)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
