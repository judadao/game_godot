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

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		not ResourceLoader.exists("res://scenes/maps/layouts/AutumnForestLayout.tscn"),
		"Obsolete AutumnForestLayout must not compete with AutumnBattleMapV2."
	)
	for spec in LAYOUTS:
		var layout_path := String(spec["layout"])
		_expect(ResourceLoader.exists(layout_path), "%s must exist." % layout_path)
		if not ResourceLoader.exists(layout_path):
			continue
		var map := (load(layout_path) as PackedScene).instantiate()
		root.add_child(map)
		await process_frame
		_expect(map.scene_file_path == layout_path, "%s must remain authoritative." % layout_path)
		_expect(map.name == String(spec["root"]), "%s must retain its root name." % layout_path)
		_expect(map.has_node("PlayerSpawn") and map.has_node("Player"), "%s must contain PlayerSpawn and Player." % layout_path)
		var reference := map.get_node_or_null("EditorHUDReference") as CanvasLayer
		_expect(reference != null and not reference.visible, "%s must keep a hidden editor HUD reference." % layout_path)
		var authored_hud := reference.get_node_or_null("HUD") as Control if reference != null else null
		_expect(authored_hud != null, "%s must author one HUD root." % layout_path)
		if layout_path == String(LAYOUTS[1]["layout"]):
			_expect(reference.get_node_or_null("CardHandUI") == null, "Autumn must not author a second card-hand root.")
			_expect(
				authored_hud.get_node_or_null("BottomStage/CardStage/AutumnCardHandUI") != null,
				"Autumn HUD must embed its sole card-hand renderer."
			)
		else:
			_expect(reference.get_node_or_null("CardHandUI") != null, "%s must retain its shared card-hand root." % layout_path)
		map.queue_free()
		await process_frame

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game.hud != null and game.hud.get_parent() == game.get_node("HUDLayer"), "Town HUD must be adopted into HUDLayer.")
	_expect(game.card_hand_ui != null and game.card_hand_ui.get_parent() == game.get_node("HUDLayer"), "Town shared hand must be adopted beside its HUD.")
	var town_hud := game.hud as Control
	var town_hand := game.card_hand_ui as Control
	_expect(town_hud != town_hand, "Town keeps its established two-root UI contract.")

	for spec in LAYOUTS:
		_expect(
			String(game.call("_resolve_main_scene_path", String(spec["canonical"]))) == String(spec["layout"]),
			"Canonical map path must resolve to its authoritative scene."
		)

	game.call("load_current_map", load(String(LAYOUTS[1]["layout"])) as PackedScene)
	await process_frame
	await process_frame
	_expect(not is_instance_valid(town_hud) and not is_instance_valid(town_hand), "Changing maps must release Town UI.")
	_expect(game.hud != null and game.hud.get_parent() == game.get_node("HUDLayer"), "Autumn HUD must be adopted into HUDLayer.")
	var embedded_hand := game.hud.get_node_or_null("BottomStage/CardStage/AutumnCardHandUI") as Control
	_expect(embedded_hand != null and game.card_hand_ui == embedded_hand, "Game must bind Autumn's embedded hand without reparenting it.")
	_expect(embedded_hand != null and embedded_hand.get_parent() != game.get_node("HUDLayer"), "Autumn hand must remain inside the single HUD authority.")
	_expect(_live_control_children(game.get_node("HUDLayer")) == 1, "Autumn HUDLayer must contain exactly one live Control root.")
	_expect(game.current_map.get_node_or_null("EditorHUDReference/HUD") == null, "Adoption must remove Autumn HUD from the map reference.")
	_expect(game.current_map.get_node_or_null("EditorHUDReference/CardHandUI") == null, "Autumn map must never gain a duplicate hand root.")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: authoritative map layouts and single Autumn HUD adoption")
	quit(1 if _failures > 0 else 0)


func _live_control_children(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is Control and not child.is_queued_for_deletion():
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
