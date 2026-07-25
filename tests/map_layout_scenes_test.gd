extends SceneTree

const LAYOUTS := [
	{
		"canonical": "res://scenes/maps/town.tscn",
		"layout": "res://scenes/maps/layouts/TownLayout.tscn",
	},
	{
		"canonical": "res://scenes/maps/autumn_forest.tscn",
		"layout": "res://scenes/maps/layouts/AutumnForestLayout.tscn",
	},
	{
		"canonical": "res://scenes/maps/crystal_caves.tscn",
		"layout": "res://scenes/maps/layouts/CrystalCavesLayout.tscn",
	},
	{
		"canonical": "res://scenes/maps/forbidden_graveyard.tscn",
		"layout": "res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn",
	},
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
		map.queue_free()
		await process_frame

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
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
	_expect(game.has_method("_resolve_layout_scene_path"), "Game must expose canonical-to-layout path resolution.")
	if game.has_method("_resolve_layout_scene_path"):
		for spec in LAYOUTS:
			_expect(
				String(game.call("_resolve_layout_scene_path", String(spec["canonical"]))) == String(spec["layout"]),
				"Canonical map path must resolve to its authoritative layout scene."
			)

	var autumn_layout := load(String(LAYOUTS[1]["layout"])) as PackedScene
	game.call("load_current_map", autumn_layout)
	await process_frame
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
	game.queue_free()
	await process_frame

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
