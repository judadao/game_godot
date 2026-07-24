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
	var mayor: Node = map.find_child("MayorInteractive", true, false)
	if mayor == null:
		push_error("MayorInteractive is missing.")
		failed = true
	else:
		game._on_interaction_available(mayor, game.get_player())
		await process_frame

	var prompt_label := game.hud.get_node_or_null("InteractionPanel/PromptRow/PromptText") as Label
	if prompt_label == null:
		push_error("HUD prompt label is missing.")
		failed = true
	else:
		if prompt_label.text != "Talk to Mayor":
			push_error("Expected 'Talk to Mayor', got '%s'." % prompt_label.text)
			failed = true
		if prompt_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			push_error("Expected interaction prompt text to be centered.")
			failed = true

	game.queue_free()
	quit(1 if failed else 0)
