extends SceneTree

class ProcessProbe:
	extends Node
	var ticks := 0

	func _process(_delta: float) -> void:
		ticks += 1


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var map_root := game.get_node("MapRoot")
	var probe := ProcessProbe.new()
	map_root.add_child(probe)
	await process_frame
	var running_ticks := probe.ticks
	_expect(running_ticks > 0, "World processing must run before a modal opens.")

	var growth_scene: PackedScene = game.get("card_growth_scene")
	var growth_ui := game.call("open_ui", "CardGrowthUI", growth_scene, true) as Control
	_expect(growth_ui != null, "Card growth modal must open.")
	_expect(paused, "Opening a card growth modal must pause the SceneTree immediately.")
	var paused_ticks := probe.ticks
	await process_frame
	await process_frame
	_expect(
		probe.ticks == paused_ticks,
		"Card growth and new-card choices must stop world, enemy, and wave processing."
	)

	game.call("close_ui", growth_ui)
	_expect(not paused, "Resolving the last pausing modal must resume the SceneTree.")
	await process_frame
	_expect(probe.ticks > paused_ticks, "World processing must resume after closing the modal.")

	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	game.call("_input", escape)
	_expect(paused, "ESC must pause gameplay in the same input dispatch that opens the menu.")
	_expect(game.call("get_open_ui", "PauseMenu") != null, "ESC must open the pause menu.")
	game.call("_input", escape)
	_expect(not paused, "Closing the pause menu with ESC must resume gameplay.")

	game.queue_free()
	await process_frame
	paused = false
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
