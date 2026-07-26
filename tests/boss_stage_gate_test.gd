extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var portal := (load("res://scenes/props/Portal.tscn") as PackedScene).instantiate()
	root.add_child(portal)
	await process_frame
	_expect(portal.has_method("set_locked"), "Portal must expose stage lock state.")
	portal.call("set_locked", true, "Defeat the boss")
	_expect(not bool(portal.call("interact", null)), "Locked portal must reject travel.")
	portal.call("set_locked", false, "")
	var entered: Array[bool] = []
	portal.connect("portal_entered", func(_portal: Node, _path: String, _spawn: StringName, _interactor: Node) -> void: entered.append(true))
	_expect(bool(portal.call("interact", null)) and entered == [true], "Unlocked portal must emit normal travel.")

	var forest := (load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene).instantiate()
	root.add_child(forest)
	await process_frame
	_expect(forest.has_node("ForwardPortal"), "Battle stage must contain a boss-gated forward portal.")
	if forest.has_node("ForwardPortal"):
		_expect(bool(forest.get_node("ForwardPortal").get("locked")), "Forward portal must start locked.")
	forest.queue_free()
	portal.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
