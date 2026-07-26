extends SceneTree

const LAYOUTS := [
	{
		"canonical": "res://scenes/maps/town.tscn",
		"layout": "res://scenes/maps/town/TownMap.tscn",
		"root": "TownMap",
	},
	{
		"canonical": "res://scenes/maps/autumn_forest.tscn",
		"layout": "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		"root": "AutumnBattleMapV2",
	},
	{
		"canonical": "res://scenes/maps/crystal_caves.tscn",
		"layout": "res://scenes/maps/layouts/CrystalCavesLayout.tscn",
		"root": "CrystalCaves",
	},
	{
		"canonical": "res://scenes/maps/forbidden_graveyard.tscn",
		"layout": "res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn",
		"root": "ForbiddenGraveyard",
	},
]

const ROOT_LAYOUT_PROPERTIES := [
	"layout_mode",
	"anchors_preset",
	"anchor_left",
	"anchor_top",
	"anchor_right",
	"anchor_bottom",
	"offset_left",
	"offset_top",
	"offset_right",
	"offset_bottom",
	"position",
	"scale",
	"rotation",
	"pivot_offset",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		not ResourceLoader.exists("res://scenes/maps/layouts/AutumnForestLayout.tscn"),
		"Obsolete AutumnForestLayout must not compete with the authoritative AutumnBattleMapV2 scene."
	)
	var map_root_layouts: Dictionary = {}
	for spec in LAYOUTS:
		var layout_path := String(spec["layout"])
		_expect(ResourceLoader.exists(layout_path), "%s must exist." % layout_path)
		if not ResourceLoader.exists(layout_path):
			continue
		var packed := load(layout_path) as PackedScene
		var map := packed.instantiate()
		root.add_child(map)
		await process_frame
		_expect(map.scene_file_path == layout_path, "%s must be the authoritative instantiated scene." % layout_path)
		_expect(map.name == String(spec["root"]), "%s must retain its canonical map root name." % layout_path)
		_expect(map.has_node("PlayerSpawn"), "%s must inherit PlayerSpawn." % layout_path)
		_expect(map.has_node("Player"), "%s must inherit Player." % layout_path)
		_expect(int(map.get_meta("map_width", 0)) > 0, "%s must inherit map metadata." % layout_path)
		var reference := map.get_node_or_null("EditorHUDReference") as CanvasLayer
		_expect(reference != null, "%s must include the shared editor HUD reference." % layout_path)
		_expect(reference != null and not reference.visible, "Editor HUD reference must stay hidden at runtime.")
		_expect(
			reference != null and reference.get_node_or_null("CardHandUI") != null,
			"%s must include an editable card hand UI." % layout_path
		)
		var hud_preview := reference.get_node_or_null("HUD") as Control if reference != null else null
		var card_hand_preview := reference.get_node_or_null("CardHandUI") as Control if reference != null else null
		_expect(hud_preview != null, "%s must include an editable HUD root." % layout_path)
		_expect(card_hand_preview != null, "%s must include an editable card hand root." % layout_path)
		if hud_preview != null and card_hand_preview != null:
			map_root_layouts[layout_path] = {
				"hud": _root_layout_snapshot(hud_preview),
				"card_hand": _root_layout_snapshot(card_hand_preview),
			}
		map.queue_free()
		await process_frame

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	var town_capture := {"token": "town_source"}
	var town_capture_callable := _capture_map_ui_node.bind(town_capture)
	node_added.connect(town_capture_callable)
	root.add_child(game)
	await process_frame
	node_added.disconnect(town_capture_callable)
	var starting_map := game.get("starting_map") as PackedScene
	_expect(
		starting_map != null and starting_map.resource_path == String(LAYOUTS[0]["layout"]),
		"Game must start from the authoritative Town layout scene."
	)
	_expect(
		game.current_map != null
		and game.current_map.get_node_or_null("EditorHUDReference/HUD") == null,
		"Runtime HUD must be adopted from the current authoritative map layout."
	)
	_expect(
		game.hud != null and game.hud.get_parent() == game.get_node("HUDLayer"),
		"Runtime HUD from the map layout must be adopted into the global HUD layer."
	)
	_expect(
		game.current_map != null
		and game.current_map.get_node_or_null("EditorHUDReference/CardHandUI") == null,
		"Runtime card hand must be adopted from the current authoritative map layout."
	)
	_expect(
		game.card_hand_ui != null and game.card_hand_ui.get_parent() == game.get_node("HUDLayer"),
		"Runtime card hand from the map layout must be adopted into the global HUD layer."
	)
	_assert_adopted_map_ui(
		game,
		map_root_layouts[String(LAYOUTS[0]["layout"])] as Dictionary,
		town_capture,
		"Town"
	)
	var town_hud := game.hud as Control
	var town_card_hand := game.card_hand_ui as Control
	_expect(game.has_method("_resolve_main_scene_path"), "Game must expose canonical-to-main-scene path resolution.")
	if game.has_method("_resolve_main_scene_path"):
		for spec in LAYOUTS:
			_expect(
				String(game.call("_resolve_main_scene_path", String(spec["canonical"]))) == String(spec["layout"]),
				"Canonical map path must resolve to its authoritative main scene."
			)

	var autumn_layout := load(String(LAYOUTS[1]["layout"])) as PackedScene
	var autumn_capture := {"token": "autumn_source"}
	var autumn_capture_callable := _capture_map_ui_node.bind(autumn_capture)
	node_added.connect(autumn_capture_callable)
	game.call("load_current_map", autumn_layout)
	await process_frame
	node_added.disconnect(autumn_capture_callable)
	_expect(not is_instance_valid(town_hud), "Changing maps must release the previous Town HUD instance.")
	_expect(not is_instance_valid(town_card_hand), "Changing maps must release the previous Town card hand instance.")
	_expect(
		game.current_map != null and game.current_map.scene_file_path == String(LAYOUTS[1]["layout"]),
		"Game must load the authoritative Autumn layout before adopting its HUD."
	)
	_expect(
		game.current_map.get_node_or_null("EditorHUDReference/HUD") == null,
		"Changing maps must adopt the new layout's HUD instance."
	)
	_expect(
		game.hud != null and game.hud.get_parent() == game.get_node("HUDLayer"),
		"Autumn layout HUD must remain attached to the global HUD layer at runtime."
	)
	_expect(
		game.current_map.get_node_or_null("EditorHUDReference/CardHandUI") == null,
		"Changing maps must adopt the new layout's card hand UI instance."
	)
	_expect(
		game.card_hand_ui != null and game.card_hand_ui.get_parent() == game.get_node("HUDLayer"),
		"Autumn layout card hand must remain attached to the global HUD layer at runtime."
	)
	_assert_adopted_map_ui(
		game,
		map_root_layouts[String(LAYOUTS[1]["layout"])] as Dictionary,
		autumn_capture,
		"Autumn"
	)
	game.queue_free()
	await process_frame

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _root_layout_snapshot(control: Control) -> Dictionary:
	var snapshot: Dictionary = {}
	for property_name in ROOT_LAYOUT_PROPERTIES:
		snapshot[property_name] = control.get(property_name)
	return snapshot


func _capture_map_ui_node(node: Node, capture: Dictionary) -> void:
	var parent := node.get_parent()
	if parent == null or parent.name != "EditorHUDReference":
		return
	var key := ""
	if node.name == "HUD":
		key = "hud"
	elif node.name == "CardHandUI":
		key = "card_hand"
	if key.is_empty():
		return
	var sentinel := "%s:%s" % [capture.get("token", ""), key]
	node.set_meta("adoption_identity_sentinel", sentinel)
	capture[key] = node
	capture["%s_id" % key] = node.get_instance_id()
	capture["%s_sentinel" % key] = sentinel


func _assert_adopted_map_ui(
	game: Node,
	expected_layouts: Dictionary,
	source_capture: Dictionary,
	map_name: String
) -> void:
	var hud_layer := game.get_node_or_null("HUDLayer")
	var current_map := game.get("current_map") as Node
	var runtime_hud := game.get("hud") as Control
	var runtime_card_hand := game.get("card_hand_ui") as Control
	var expected_hud := expected_layouts.get("hud", {}) as Dictionary
	var expected_card_hand := expected_layouts.get("card_hand", {}) as Dictionary

	_expect(runtime_hud != null and runtime_hud.get_parent() == hud_layer, "%s HUD must be adopted into HUDLayer." % map_name)
	_expect(runtime_card_hand != null and runtime_card_hand.get_parent() == hud_layer, "%s card hand must be adopted into HUDLayer." % map_name)
	_expect(runtime_hud == source_capture.get("hud"), "%s must reparent the exact source-map HUD instance." % map_name)
	_expect(runtime_card_hand == source_capture.get("card_hand"), "%s must reparent the exact source-map card hand instance." % map_name)
	if runtime_hud != null:
		_expect(
			runtime_hud.get_instance_id() == int(source_capture.get("hud_id", 0))
			and runtime_hud.get_meta("adoption_identity_sentinel", "") == source_capture.get("hud_sentinel", ""),
			"%s HUD identity sentinel must survive Game adoption." % map_name
		)
	if runtime_card_hand != null:
		_expect(
			runtime_card_hand.get_instance_id() == int(source_capture.get("card_hand_id", 0))
			and runtime_card_hand.get_meta("adoption_identity_sentinel", "") == source_capture.get("card_hand_sentinel", ""),
			"%s card hand identity sentinel must survive Game adoption." % map_name
		)
	_expect(
		current_map != null and current_map.get_node_or_null("EditorHUDReference/HUD") == null,
		"%s adoption must remove the HUD root from its map reference." % map_name
	)
	_expect(
		current_map != null and current_map.get_node_or_null("EditorHUDReference/CardHandUI") == null,
		"%s adoption must remove the card hand root from its map reference." % map_name
	)
	_expect(runtime_hud != runtime_card_hand, "%s adoption must keep distinct HUD and card hand roots." % map_name)
	_expect(
		_count_live_control_children(hud_layer) == 2,
		"%s adoption must keep exactly one live HUD root and one live card hand root." % map_name
	)
	_expect_root_layout(runtime_hud, expected_hud, "%s HUD" % map_name)
	_expect_root_layout(runtime_card_hand, expected_card_hand, "%s card hand" % map_name)


func _count_live_control_children(parent: Node) -> int:
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if child is Control and not child.is_queued_for_deletion():
			count += 1
	return count


func _expect_root_layout(control: Control, expected: Dictionary, label: String) -> void:
	if control == null:
		return
	for property_name in ROOT_LAYOUT_PROPERTIES:
		_expect(
			control.get(property_name) == expected.get(property_name),
			"%s must preserve map-authored root %s through Game reparenting." % [label, property_name]
		)
