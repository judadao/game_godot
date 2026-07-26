extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var autumn := load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	game.call("load_current_map", autumn)
	await process_frame
	await process_frame

	var map: Node = game.get_current_map()
	var target := map.get_node_or_null("HiddenBranchCache") as CanvasItem
	_expect(target != null, "Autumn V2 must expose a real interactive target.")
	if target == null:
		game.queue_free()
		quit(1)
		return
	game.call("_on_interaction_available", target, game.get_player())
	await process_frame
	await process_frame

	var prompt_label := game.hud.get_node_or_null("InteractionPanel/PromptRow/PromptText") as Label
	var prompt_panel := game.hud.get_node_or_null("InteractionPanel") as Control
	_expect(prompt_label != null, "Autumn interaction prompt label must exist.")
	_expect(prompt_panel != null and prompt_panel.visible, "Autumn interaction prompt must become visible.")
	if prompt_label != null:
		_expect(prompt_label.text == "Open hidden cache", "Prompt must show the interactive action.")
		_expect(
			prompt_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"Interaction prompt text must remain centered."
		)
	if prompt_panel != null:
		var viewport_size := game.get_viewport().get_visible_rect().size
		var prompt_rect := _canvas_rect(prompt_panel)
		var target_position := target.get_global_transform_with_canvas().origin
		_expect(
			prompt_rect.end.y <= viewport_size.y * 0.75 - 16.0,
			"Interaction prompt must stay above the bottom HUD safe area."
		)
		_expect(
			absf(prompt_rect.get_center().x - target_position.x) <= 4.0,
			"Interaction prompt must follow the interactive target horizontally."
		)
		var previous_center := prompt_rect.get_center()
		(target as Node2D).position.x += 96.0
		await process_frame
		await process_frame
		var moved_center := _canvas_rect(prompt_panel).get_center()
		_expect(
			moved_center.x >= previous_center.x + 90.0,
			"Interaction prompt must move when its target moves."
		)

	game.call("_on_interaction_unavailable", target, game.get_player())
	await process_frame
	_expect(prompt_panel != null and not prompt_panel.visible, "Leaving interaction range must hide the prompt.")

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
