extends SceneTree

const MAP_SCENES := [
	{
		"path": "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		"portal": "WestSafePortal",
		"target": "res://scenes/maps/autumn_safe_zone.tscn",
		"right_wall": "WorldBounds/RightWall",
	},
	{
		"path": "res://scenes/maps/crystal_caves.tscn",
		"portal": "WestReturnPortal",
		"target": "res://scenes/maps/battle_portal_hub.tscn",
		"right_wall": "WorldBounds/RightWall",
	},
	{
		"path": "res://scenes/maps/hell_rift.tscn",
		"portal": "WestReturnPortal",
		"target": "res://scenes/maps/battle_portal_hub.tscn",
		"right_wall": "WorldBounds/RightWall",
	},
	{
		"path": "res://scenes/maps/heaven_sanctuary.tscn",
		"portal": "WestReturnPortal",
		"target": "res://scenes/maps/battle_portal_hub.tscn",
		"right_wall": "WorldBounds/RightWall",
	},
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec in MAP_SCENES:
		var scene_path := String(spec["path"])
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
		var portal_path := String(spec["portal"])
		_expect(map.has_node(portal_path), "%s must have a return portal." % scene_path)

		var portal := map.get_node_or_null(portal_path)
		if portal != null:
			_expect(portal.is_visible_in_tree(), "%s return portal must be visible." % scene_path)
			_expect(
				String(portal.get("target_scene_path")) == String(spec["target"]),
				"%s return portal must target its owning safe destination." % scene_path
			)
			_expect(
				(portal as Node2D).position.x < float(camera_right),
				"%s return portal must be inside the reachable camera range." % scene_path
			)

		var right_wall := map.get_node_or_null(String(spec["right_wall"])) as CollisionShape2D
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
