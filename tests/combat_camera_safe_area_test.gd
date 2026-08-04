extends SceneTree

const ROUTE_SCENES := [
	"res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
	"res://scenes/maps/expedition/CrystalRoute.tscn",
	"res://scenes/maps/expedition/HellAutumnRoute.tscn",
	"res://scenes/maps/expedition/HellCrystalRoute.tscn",
	"res://scenes/maps/expedition/HellRoute.tscn",
	"res://scenes/maps/expedition/HeavenAutumnRoute.tscn",
	"res://scenes/maps/expedition/HeavenCrystalRoute.tscn",
	"res://scenes/maps/expedition/DisorderHellRoute.tscn",
	"res://scenes/maps/expedition/HeavenRoute.tscn",
]
const BOSS_SCENES := [
	"res://scenes/maps/boss/AutumnBossArena.tscn",
	"res://scenes/maps/boss/CrystalBossArena.tscn",
	"res://scenes/maps/boss/HellAutumnBossArena.tscn",
	"res://scenes/maps/boss/HellCrystalBossArena.tscn",
	"res://scenes/maps/boss/HellBossArena.tscn",
	"res://scenes/maps/boss/HeavenAutumnBossArena.tscn",
	"res://scenes/maps/boss/HeavenCrystalBossArena.tscn",
	"res://scenes/maps/boss/DisorderHellBossArena.tscn",
	"res://scenes/maps/boss/HeavenBossArena.tscn",
]
const CARD_STAGE_TOP := 475.2

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	game.call("load_current_map", load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene)
	await process_frame
	var player := game.get("player") as Node
	var camera := player.find_child("Camera2D", true, false) as Camera2D
	_expect(
		camera != null and camera.position.y >= 88.0 and camera.position.y <= 92.0,
		"Battle camera offset must center gameplay inside the upper 75 percent world region."
	)
	for scene_path in ROUTE_SCENES:
		await _check_player_safe_area(game, scene_path, false)
	for scene_path in BOSS_SCENES:
		await _check_player_safe_area(game, scene_path, true)
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _check_player_safe_area(game: Node, scene_path: String, is_boss: bool) -> void:
	game.call("load_current_map", load(scene_path) as PackedScene)
	await process_frame
	await process_frame
	var player := game.get("player") as Node2D
	var screen_position := player.get_global_transform_with_canvas().origin
	_expect(
		screen_position.y < CARD_STAGE_TOP - 24.0,
		"%s player must remain above the card stage (screen y %.1f)." % [scene_path, screen_position.y]
	)
	var map := game.get("current_map") as Node
	var spawn := map.find_child("PlayerSpawn", true, false) as Node2D
	if is_boss:
		if scene_path.ends_with("AutumnBossArena.tscn") and not scene_path.contains("Hell") and not scene_path.contains("Heaven"):
			_expect(spawn.position.y <= 1360.0, "%s portrait boss spawn must remain on its floor." % scene_path)
		else:
			_expect(spawn.position.y <= 600.0, "%s boss spawn must use the Autumn battle vertical frame." % scene_path)
	else:
		var route := map.get_node_or_null("GeneratedRoute")
		if route != null and route.has_method("get_floor_y_at"):
			_expect(
				float(route.call("get_floor_y_at", spawn.position.x)) <= 500.0,
				"%s route floor must align with the Autumn battle vertical frame." % scene_path
			)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
