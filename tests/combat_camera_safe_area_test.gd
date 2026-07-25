extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	game.call("load_current_map", load("res://scenes/maps/autumn_forest.tscn") as PackedScene)
	await process_frame
	var player := game.get("player") as Node
	var camera := player.find_child("Camera2D", true, false) as Camera2D
	_expect(camera != null and camera.position.y >= 135.0, "Battle camera must shift the world upward by half the reserved card stage.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
