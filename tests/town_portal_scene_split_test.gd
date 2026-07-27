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

	_expect(portal_set.get_child_count() == 1, "Town PortalSet must contain one gateway instance.")
	var gateway := portal_set.get_node_or_null("BattleGateway")
	_expect(gateway != null, "Town PortalSet must contain BattleGateway.")
	if gateway != null:
		_expect(
			gateway.scene_file_path == "res://scenes/props/town/portals/TownBattleGateway.tscn",
			"BattleGateway must remain a linked dedicated scene."
		)
		_expect(gateway.collision_layer == 0, "BattleGateway must not block the street.")
		_expect(
			gateway.target_scene_path == "res://scenes/maps/battle_portal_hub.tscn",
			"BattleGateway target is wrong."
		)

	portal_set.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
