extends SceneTree

const BATTLE_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const SAFE_PATH := "res://scenes/maps/autumn_safe_zone.tscn"
const REQUIRED_NODE_PATHS: Array[String] = [
	"GeneratedBackdrop",
	"GeneratedRoute",
	"PlayerSpawn",
	"Player",
	"AutumnRunDirector",
	"WorldBounds/LeftWall",
	"WorldBounds/RightWall",
	"WestSafePortal",
	"EastSafePortal",
	"EditorHUDReference/HUD",
	"EditorHUDReference/HUD/BottomStage/CardStage/AutumnCardHandUI",
	"EditorHelpers/MapBounds",
	"EditorHelpers/ChunkSeams",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BATTLE_MAP_PATH) as PackedScene
	_expect(packed != null, "Autumn Battle Map V2 must load.")
	if packed == null:
		quit(1)
		return
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	_expect(map.name == "AutumnBattleMapV2", "Battle map must retain its authoritative identity.")
	_expect(int(map.get_meta("map_width", 0)) == 10560, "Battle map must expose its modular route width.")
	_expect(int(map.get_meta("camera_limit_right", 0)) == 10560, "Camera must reach the route tail.")
	for node_path in REQUIRED_NODE_PATHS:
		_expect(map.has_node(node_path), "Autumn Battle Map V2 must contain %s." % node_path)

	_expect(map.find_children("Player", "CharacterBody2D", true, false).size() == 1, "Battle map must own one Player.")
	_expect(map.find_children("*", "Camera2D", true, false).size() == 1, "Battle map must own one Camera2D.")
	var director := map.get_node_or_null("AutumnRunDirector")
	_expect(director is SurvivalWaveDirector, "Battle map must reuse SurvivalWaveDirector.")
	if director != null:
		_expect(bool(director.get("route_wide_encounter")), "Director engagement must follow enemies across the long route.")
		_expect(bool(director.get("spawn_around_player")), "Director must spawn around the current player position.")
	for portal_path in ["WestSafePortal", "EastSafePortal"]:
		var portal := map.get_node_or_null(portal_path)
		_expect(portal != null, "%s must exist." % portal_path)
		if portal != null:
			_expect(String(portal.get("target_scene_path")) == SAFE_PATH, "%s must return to the safe zone." % portal_path)
			_expect(not bool(portal.get("locked")), "%s must always remain usable." % portal_path)
	for retired_path in [
		"GameplayZones",
		"ForestShortcutSpawn",
		"HiddenBranchCache",
		"WanderingCardMerchant",
		"ShortcutLever",
	]:
		_expect(
			not map.has_node(retired_path),
			"Regenerated battle map must not retain old-map node %s." % retired_path
		)
	_expect(
		map.find_children("Dressing", "Node2D", true, false).is_empty(),
		"Generated route must not reintroduce old fence, sign, or prop dressing."
	)

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
