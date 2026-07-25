extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failed := false
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	if game_scene == null:
		push_error("Game scene failed to load.")
		quit(1)
		return

	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var map: Node = game.get_current_map()
	var mayor: Node = map.get_node_or_null("NPCs/Mayor")
	if mayor == null:
		push_error("NPCs/Mayor is missing.")
		failed = true
	else:
		game._on_interaction_available(mayor, game.get_player())
		await process_frame

	var prompt_label := game.hud.get_node_or_null("InteractionPanel/PromptRow/PromptText") as Label
	var prompt_panel := game.hud.get_node_or_null("InteractionPanel") as Control
	if prompt_label == null:
		push_error("HUD prompt label is missing.")
		failed = true
	else:
		if prompt_label.text != "Talk — Mayor":
			push_error("Expected 'Talk — Mayor', got '%s'." % prompt_label.text)
			failed = true
		if prompt_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			push_error("Expected interaction prompt text to be centered.")
			failed = true
	if prompt_panel == null:
		push_error("HUD prompt panel is missing.")
		failed = true
	else:
		var viewport_width := game.get_viewport().get_visible_rect().size.x
		var panel_center_x := prompt_panel.global_position.x + prompt_panel.size.x * 0.5
		if absf(panel_center_x - viewport_width * 0.5) > 2.0:
			push_error("Expected interaction prompt panel centered at %.1f, got %.1f." % [viewport_width * 0.5, panel_center_x])
			failed = true

	game.queue_free()
	quit(1 if failed else 0)
