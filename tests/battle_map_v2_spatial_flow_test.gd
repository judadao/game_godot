extends SceneTree

const BATTLE_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const WORLD_BOTTOM := 540.0
const VIEWPORT_BOTTOM := 720.0

const ROUTE_ZONES: Array[Dictionary] = [
	{"path": "GameplayZones/SpawnZone", "minimum_x": 0.0, "maximum_x": 420.0},
	{"path": "GameplayZones/EventChoiceZone", "minimum_x": 420.0, "maximum_x": 820.0},
	{"path": "GameplayZones/EnemyWaveZone", "minimum_x": 820.0, "maximum_x": 1650.0},
	{"path": "GameplayZones/MerchantZone", "minimum_x": 1650.0, "maximum_x": 2100.0},
	{"path": "GameplayZones/ExitZone", "minimum_x": 2100.0, "maximum_x": 2600.0},
]

const WORLD_NODE_PATHS: Array[String] = [
	"TownPortal",
	"PlayerSpawn",
	"ForestShortcutSpawn",
	"HiddenBranchCache",
	"AutumnRunDirector",
	"ForestRest",
	"WanderingCardMerchant",
	"ShortcutLever",
	"ForwardPortal",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ResourceLoader.exists(BATTLE_MAP_PATH),
		"Autumn Battle Map V2 must exist before its spatial route can be verified."
	)
	if not ResourceLoader.exists(BATTLE_MAP_PATH):
		quit(1)
		return

	var packed := load(BATTLE_MAP_PATH) as PackedScene
	_expect(packed != null, "Autumn Battle Map V2 must load for spatial verification.")
	if packed == null:
		quit(1)
		return

	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	_assert_route_zones(map)
	_assert_gameplay_landmarks_follow_route(map)
	_assert_world_stays_above_hud(map)
	_assert_bottom_ui_owns_last_quarter(map)

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _assert_route_zones(map: Node) -> void:
	var previous_x := -1.0
	for zone_spec in ROUTE_ZONES:
		var zone_path := String(zone_spec["path"])
		var zone := map.get_node_or_null(zone_path) as Node2D
		_expect(zone != null, "V2 route must contain %s." % zone_path)
		if zone == null:
			continue
		var zone_x := zone.global_position.x
		_expect(
			zone_x >= float(zone_spec["minimum_x"]) and zone_x <= float(zone_spec["maximum_x"]),
			"%s must be authored inside its approved horizontal segment." % zone_path
		)
		_expect(zone_x > previous_x, "V2 route zones must progress strictly from left to right.")
		previous_x = zone_x


func _assert_gameplay_landmarks_follow_route(map: Node) -> void:
	_expect_x_in_segment(map, "TownPortal", 0.0, 420.0)
	_expect_x_in_segment(map, "PlayerSpawn", 0.0, 420.0)
	_expect_x_in_segment(map, "HiddenBranchCache", 420.0, 820.0)
	_expect_x_in_segment(map, "AutumnRunDirector", 820.0, 1650.0)
	_expect_x_in_segment(map, "ForestRest", 1650.0, 2100.0)
	_expect_x_in_segment(map, "WanderingCardMerchant", 1650.0, 2100.0)
	_expect_x_in_segment(map, "ShortcutLever", 1650.0, 2100.0)
	_expect_x_in_segment(map, "ForwardPortal", 2100.0, 2600.0)

	var spawn := map.get_node_or_null("PlayerSpawn") as Node2D
	var event := map.get_node_or_null("HiddenBranchCache") as Node2D
	var arena := map.get_node_or_null("AutumnRunDirector") as Node2D
	var merchant := map.get_node_or_null("WanderingCardMerchant") as Node2D
	var exit := map.get_node_or_null("ForwardPortal") as Node2D
	if spawn != null and event != null and arena != null and merchant != null and exit != null:
		_expect(
			spawn.global_position.x
			< event.global_position.x
			and event.global_position.x
			< arena.global_position.x
			and arena.global_position.x
			< merchant.global_position.x
			and merchant.global_position.x
			< exit.global_position.x,
			"Gameplay landmarks must follow spawn, event, wave, merchant, exit order."
		)


func _assert_world_stays_above_hud(map: Node) -> void:
	for node_path in WORLD_NODE_PATHS:
		var world_node := map.get_node_or_null(node_path) as Node2D
		_expect(world_node != null, "World landmark %s must exist." % node_path)
		if world_node == null:
			continue
		var y := world_node.global_position.y
		_expect(
			y >= 0.0 and y <= WORLD_BOTTOM,
			"%s must remain inside the y=0..540 world region." % node_path
		)


func _assert_bottom_ui_owns_last_quarter(map: Node) -> void:
	var stage_guide := map.get_node_or_null("EditorHUDReference/CardStageGuide") as Control
	var viewport_guide := map.get_node_or_null("EditorHUDReference/ViewportBoundary") as Control
	var hud_bottom := map.get_node_or_null("EditorHUDReference/HUD/BottomHUD") as Control
	var card_safe_area := map.get_node_or_null("EditorHUDReference/CardHandUI/CardSafeArea") as Control
	_expect(stage_guide != null, "Editor HUD reference must expose the bottom-stage guide.")
	_expect(viewport_guide != null, "Editor HUD reference must expose the 1280x720 viewport guide.")
	_expect(hud_bottom != null, "HUD must expose its bottom-quarter container.")
	_expect(card_safe_area != null, "Card hand must expose its bottom-quarter safe area.")
	if stage_guide != null:
		_expect(is_equal_approx(stage_guide.position.y, WORLD_BOTTOM), "HUD stage must start at y=540.")
		_expect(
			is_equal_approx(stage_guide.position.y + stage_guide.size.y, VIEWPORT_BOTTOM),
			"HUD stage must end at y=720."
		)
	if viewport_guide != null:
		_expect(is_equal_approx(viewport_guide.size.y, VIEWPORT_BOTTOM), "Editor viewport guide must be 720 pixels tall.")
	if hud_bottom != null:
		_expect(is_equal_approx(hud_bottom.anchor_top, 0.75), "HUD content must begin at 75% viewport height.")
		_expect(is_equal_approx(hud_bottom.anchor_bottom, 1.0), "HUD content must end at the viewport bottom.")
	if card_safe_area != null:
		_expect(is_equal_approx(card_safe_area.anchor_top, 0.75), "Card safe area must begin at 75% viewport height.")
		_expect(is_equal_approx(card_safe_area.anchor_bottom, 1.0), "Card safe area must end at the viewport bottom.")


func _expect_x_in_segment(map: Node, node_path: String, minimum_x: float, maximum_x: float) -> void:
	var world_node := map.get_node_or_null(node_path) as Node2D
	_expect(world_node != null, "%s must exist in the V2 route." % node_path)
	if world_node == null:
		return
	var x := world_node.global_position.x
	_expect(
		x >= minimum_x and x <= maximum_x,
		"%s must be inside x=%d..%d." % [node_path, int(minimum_x), int(maximum_x)]
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
