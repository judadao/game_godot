extends SceneTree

const MAP_SCENES := [
	"res://scenes/maps/autumn_forest.tscn",
	"res://scenes/maps/crystal_caves.tscn",
	"res://scenes/maps/forbidden_graveyard.tscn",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in MAP_SCENES:
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s must load." % scene_path)
		if packed == null:
			continue

		var map := packed.instantiate()
		root.add_child(map)
		await process_frame

		var map_width := int(map.get_meta("map_width", 0))
		var camera_right := int(map.get_meta("camera_limit_right", 0))
		_expect(map_width >= 2600, "%s must expose its full map width." % scene_path)
		_expect(camera_right >= map_width, "%s camera must reach the map's right edge." % scene_path)
		_expect(map.has_node("PlayerSpawn"), "%s must have PlayerSpawn." % scene_path)
		_expect(map.has_node("TownPortal"), "%s must have a return portal." % scene_path)

		var portal := map.get_node_or_null("TownPortal")
		if portal != null:
			_expect(portal.is_visible_in_tree(), "%s return portal must be visible." % scene_path)
			_expect(
				String(portal.get("target_scene_path")) == "res://scenes/maps/town.tscn",
				"%s return portal must target town." % scene_path
			)
			_expect(
				(portal as Node2D).position.x < float(camera_right),
				"%s return portal must be inside the reachable camera range." % scene_path
			)

		var right_wall := map.get_node_or_null("WorldCollision/RightWall") as CollisionShape2D
		_expect(right_wall != null, "%s must have a right boundary." % scene_path)
		if right_wall != null:
			_expect(
				right_wall.position.x >= float(map_width),
				"%s right wall must not truncate the playable route." % scene_path
			)

		map.queue_free()
		await process_frame

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
