extends SceneTree

const MAIN_SCENES := [
	{
		"path": "res://scenes/maps/town/TownMap.tscn",
		"root": "TownMap",
		"required": [
			"ParallaxBackground",
			"Buildings",
			"Ground",
			"Props",
			"Portals",
			"NPCs",
			"WorldCollision",
			"PlayerSpawn",
		],
	},
	{
		"path": "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		"root": "AutumnBattleMapV2",
		"required": [
			"Background",
			"Ground",
			"Ground/Platforms",
			"SetDressing",
			"AutumnRunDirector",
			"HiddenBranchCache",
			"ForestRest",
			"ShortcutLever",
			"TownPortal",
			"ForwardPortal",
			"WorldCollision",
			"PlayerSpawn",
		],
	},
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec in MAIN_SCENES:
		var scene_path := String(spec["path"])
		_expect(ResourceLoader.exists(scene_path), "%s must exist as a clear map editing entry." % scene_path)
		if not ResourceLoader.exists(scene_path):
			continue
		var map := (load(scene_path) as PackedScene).instantiate()
		root.add_child(map)
		await process_frame
		_expect(map.name == String(spec["root"]), "%s must have a clear main-scene root name." % scene_path)
		_expect(map.scene_file_path == scene_path, "%s must be the instantiated authoritative scene." % scene_path)
		_expect(int(map.get_meta("map_width", 0)) > 0, "%s must expose map bounds." % scene_path)
		for required_path in spec["required"] as Array:
			_expect(map.has_node(String(required_path)), "%s must show %s." % [scene_path, required_path])
		_expect(map.find_children("Player", "CharacterBody2D", true, false).size() == 1, "%s must contain one Player." % scene_path)
		_expect(map.find_children("*", "Camera2D", true, false).size() == 1, "%s must contain one Camera." % scene_path)
		var helpers := map.get_node_or_null("EditorHelpers") as CanvasItem
		_expect(helpers != null, "%s must contain EditorHelpers." % scene_path)
		_expect(helpers != null and not helpers.visible, "EditorHelpers must hide outside the editor.")
		_expect(map.has_node("EditorHUDReference/HUD"), "%s must preview the real HUD." % scene_path)
		_expect(map.has_node("EditorHUDReference/CardHandUI"), "%s must preview the real card hand." % scene_path)
		_expect(map.find_children("HUD", "Control", true, false).size() == 1, "%s must contain one HUD preview." % scene_path)
		_expect(map.find_children("CardHandUI", "Control", true, false).size() == 1, "%s must contain one card hand preview." % scene_path)
		map.queue_free()
		await process_frame

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var starting_map := game.get("starting_map") as PackedScene
	_expect(
		starting_map != null and starting_map.resource_path == String(MAIN_SCENES[0]["path"]),
		"Game must start from TownMap.tscn."
	)
	_expect(
		String(game.call("_resolve_main_scene_path", "res://scenes/maps/town.tscn"))
		== String(MAIN_SCENES[0]["path"]),
		"Canonical Town portal path must resolve to TownMap.tscn."
	)
	_expect(
		String(game.call("_resolve_main_scene_path", "res://scenes/maps/autumn_forest.tscn"))
		== String(MAIN_SCENES[1]["path"]),
		"Canonical Autumn portal path must resolve to AutumnBattleMapV2.tscn."
	)
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
