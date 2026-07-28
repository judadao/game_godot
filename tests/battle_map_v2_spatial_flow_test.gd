extends SceneTree

const BATTLE_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const WORLD_BOTTOM := 540.0

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load(BATTLE_MAP_PATH) as PackedScene).instantiate()
	root.add_child(map)
	await process_frame

	var west := map.get_node_or_null("WestSafePortal") as Node2D
	var spawn := map.get_node_or_null("PlayerSpawn") as Node2D
	var east := map.get_node_or_null("EastSafePortal") as Node2D
	_expect(
		west != null and spawn != null and east != null
			and west.position.x < spawn.position.x
			and spawn.position.x < east.position.x,
		"Battle landmarks must span the complete route in traversal order."
	)
	for world_path in ["WestSafePortal", "PlayerSpawn", "EastSafePortal"]:
		var world_node := map.get_node_or_null(world_path) as Node2D
		if world_node != null:
			_expect(world_node.position.y <= WORLD_BOTTOM, "%s must stay above the HUD." % world_path)

	var stage := map.get_node_or_null("EditorHUDReference/CardStageGuide") as Control
	var hud_bottom := map.get_node_or_null("EditorHUDReference/HUD/BottomStage") as Control
	_expect(stage != null and is_equal_approx(stage.position.y, 475.2), "HUD stage must retain its safe top edge.")
	_expect(hud_bottom != null and is_equal_approx(hud_bottom.anchor_top, 0.66), "Battle HUD must retain its lower composition.")

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
