extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var player := game.get("player") as Node
	var portal := game.get("current_map").get_node("Portals/ForestPortal") as Node
	game.call("_on_interaction_available", portal, player)
	game.call("_try_interact")
	await process_frame
	var builder := game.call("get_open_ui", "DeckBuilderUI") as Control
	_expect(builder != null, "Real Town forest-portal interaction must open deck building.")
	_expect(game.has_method("_normalize_expedition_deck"), "Game must normalize migrated expedition decks.")
	if builder != null:
		var invalid_deck: Array[String] = ["missing_card"]
		builder.emit_signal("deck_confirmed", invalid_deck)
		await process_frame
		await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		"Normalized confirmation must enter the authoritative Autumn Battle V2 scene."
	)
	_expect((game.get("run_state") as RunState).active, "Entering Autumn Forest must start a run.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
