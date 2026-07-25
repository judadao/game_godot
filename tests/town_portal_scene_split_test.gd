extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/props/town/TownPortalSet.tscn") as PackedScene
	_expect(packed != null, "TownPortalSet must load.")
	if packed == null:
		quit(1)
		return

	var portal_set := packed.instantiate()
	root.add_child(portal_set)
	await process_frame

	var expected_scenes := {
		"EntranceFastTravelPortal": "res://scenes/props/town/portals/TownFastTravelPortal.tscn",
		"ForestPortal": "res://scenes/props/town/portals/TownForestPortal.tscn",
		"CavesPortal": "res://scenes/props/town/portals/TownCavesPortal.tscn",
		"GraveyardPortal": "res://scenes/props/town/portals/TownGraveyardPortal.tscn",
		"EastRoadPortal": "res://scenes/props/town/portals/TownFastTravelPortal.tscn",
	}
	var expected_names := [
		"EntranceFastTravelPortal",
		"ForestPortal",
		"CavesPortal",
		"GraveyardPortal",
		"EastRoadPortal",
	]
	_expect(portal_set.get_child_count() == 5, "PortalSet must contain exactly five instances.")
	for index in expected_names.size():
		var portal_name: String = expected_names[index]
		var portal := portal_set.get_node(portal_name)
		_expect(portal.scene_file_path == expected_scenes[portal_name], "%s has the wrong scene link." % portal_name)
		_expect(portal_set.get_child(index) == portal, "%s is out of scene-tree order." % portal_name)
		_expect(portal.collision_layer == 0, "%s must not block the street." % portal_name)

	_expect(
		portal_set.get_node("EntranceFastTravelPortal").target_spawn_name == &"TownTailArrival",
		"Entrance fast travel must target TownTailArrival."
	)
	_expect(
		portal_set.get_node("EastRoadPortal").target_spawn_name == &"TownEntranceArrival",
		"East fast travel must target TownEntranceArrival."
	)
	_expect(
		portal_set.get_node("ForestPortal").target_scene_path == "res://scenes/maps/autumn_forest.tscn",
		"Forest portal target is wrong."
	)
	_expect(
		portal_set.get_node("CavesPortal").target_scene_path == "res://scenes/maps/crystal_caves.tscn",
		"Caves portal target is wrong."
	)
	_expect(
		portal_set.get_node("GraveyardPortal").target_scene_path == "res://scenes/maps/forbidden_graveyard.tscn",
		"Graveyard portal target is wrong."
	)

	portal_set.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
