extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load("res://scenes/maps/town.tscn") as PackedScene).instantiate()
	root.add_child(town)
	await process_frame

	var gateway := town.get_node_or_null("Portals/BattleGateway")
	_expect(gateway != null, "Town must expose one BattleGateway.")
	_expect(town.get_node("Portals").get_child_count() == 1, "Town must not retain internal fast-travel portals.")
	if gateway != null:
		_expect(gateway.target_spawn_name == &"PlayerSpawn", "Battle gateway must use the hub spawn.")
		_expect(
			gateway.target_scene_path == "res://scenes/maps/battle_portal_hub.tscn",
			"Battle gateway must target the portal hub."
		)
		_expect(gateway.collision_layer == 0, "Battle gateway must not block the town road.")

	town.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
