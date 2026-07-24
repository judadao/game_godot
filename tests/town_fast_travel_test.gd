extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load("res://scenes/maps/town.tscn") as PackedScene).instantiate()
	root.add_child(town)
	await process_frame

	var entrance := town.get_node("Portals/EntranceFastTravelPortal")
	var tail := town.get_node("Portals/EastRoadPortal")
	_expect(town.has_node("TownEntranceArrival"), "Town entrance arrival marker must exist.")
	_expect(town.has_node("TownTailArrival"), "Town tail arrival marker must exist.")
	_expect(entrance.target_spawn_name == &"TownTailArrival", "Entrance portal must target town tail.")
	_expect(tail.target_spawn_name == &"TownEntranceArrival", "Tail portal must target town entrance.")
	_expect(entrance.target_scene_path == "res://scenes/maps/town.tscn", "Fast travel must stay in town.")
	_expect(tail.target_scene_path == "res://scenes/maps/town.tscn", "Return fast travel must stay in town.")
	_expect(entrance.collision_layer == 0 and tail.collision_layer == 0, "Fast-travel portals must not block town roads.")

	town.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
