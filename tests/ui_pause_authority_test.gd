extends SceneTree

const PAUSE_VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

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
	var town_pause := game.call("get_open_ui", "PauseMenu") as Control
	_expect(town_pause != null, "ESC must open the pause menu.")
	var town_exit_combat := (
		town_pause.get_node_or_null("MenuPanel/Content/ButtonStack/ExitCombat") as Button
		if town_pause != null
		else null
	)
	_expect(
		town_exit_combat != null and town_exit_combat.disabled,
		"Exit Combat must remain visible but disabled outside an active battle."
	)
	game.call("_input", escape)
	_expect(not paused, "Closing the pause menu with ESC must resume gameplay.")

	game.call("_begin_autumn_run")
	game.call(
		"load_current_map",
		load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	)
	await process_frame
	await process_frame
	game.call("_input", escape)
	var battle_pause := game.call("get_open_ui", "PauseMenu") as Control
	var battle_exit_combat := (
		battle_pause.get_node_or_null("MenuPanel/Content/ButtonStack/ExitCombat") as Button
		if battle_pause != null
		else null
	)
	_expect(
		battle_exit_combat != null and not battle_exit_combat.disabled,
		"Exit Combat must become enabled during an active battle Run."
	)
	var permanent_gold_before := int(
		(game.get("meta_state") as MetaState).resources.get("gold", 0)
	)
	(game.get("run_state") as RunState).gold_earned = 7
	if battle_exit_combat != null:
		battle_exit_combat.pressed.emit()
	await process_frame
	await process_frame
	_expect(not paused, "Exiting combat from Pause must release the modal pause token.")
	_expect(
		not (game.get("run_state") as RunState).active,
		"Exiting combat must settle the active Run as a retreat."
	)
	_expect(
		int((game.get("meta_state") as MetaState).resources.get("gold", 0))
			== permanent_gold_before + 7,
		"Exiting combat must retain permanent rewards earned before retreat."
	)
	_expect(
		game.get("current_map").scene_file_path
			== "res://scenes/maps/town/TownMap.tscn",
		"Exiting combat must return directly to the authoritative Town map."
	)

	game.queue_free()
	await process_frame
	paused = false
	for viewport_size in PAUSE_VIEWPORT_SIZES:
		await _check_pause_layout(viewport_size)
	quit(0 if _failures == 0 else 1)


func _check_pause_layout(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var pause_menu := (
		load("res://scenes/ui/system/PauseMenu.tscn") as PackedScene
	).instantiate() as Control
	viewport.add_child(pause_menu)
	await process_frame
	pause_menu.open()
	await process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var panel := pause_menu.get_node("MenuPanel") as Control
	var exit_combat := pause_menu.get_node(
		"MenuPanel/Content/ButtonStack/ExitCombat"
	) as Button
	_expect(
		screen.encloses(panel.get_global_rect()),
		"Pause panel must remain on-screen at %s." % viewport_size
	)
	_expect(
		panel.get_global_rect().encloses(exit_combat.get_global_rect())
			and exit_combat.size.x >= 240.0
			and exit_combat.size.y >= 44.0,
		"Exit Combat must remain readable and inside Pause at %s." % viewport_size
	)
	viewport.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
