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
	var portal := game.get("current_map").get_node("Portals/BattleGateway") as Node
	(player as Node2D).global_position = (portal as Node2D).global_position
	game.call("_on_interaction_available", portal, player)
	var prompt_label := game.get("hud").get_node(
		"InteractionPanel/PromptRow/PromptText"
	) as Label
	_expect(
		prompt_label.text == "Enter",
		"Town BattleGateway prompt must show only the action because the portal label is already visible."
	)
	game.call("_try_interact")
	await process_frame
	await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/battle_portal_hub.tscn",
		"Town BattleGateway must enter the portal hub."
	)
	player = game.get("player") as Node
	portal = game.get("current_map").get_node("RegionPortals/AutumnPortal") as Node
	(player as Node2D).global_position = (portal as Node2D).global_position
	game.call("_on_interaction_available", portal, player)
	game.call("_try_interact")
	await process_frame
	var builder := game.call("get_open_ui", "DeckBuilderUI") as Control
	_expect(builder != null, "Hub Autumn portal must open deck building without entering a safe zone.")
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/battle_portal_hub.tscn",
		"Opening the Autumn loadout must keep the player in the hub until confirmation."
	)
	_expect(game.has_method("_normalize_expedition_deck"), "Game must normalize migrated expedition decks.")
	if builder != null:
		var invalid_deck: Array[String] = ["missing_card"]
		builder.emit_signal("deck_confirmed", invalid_deck)
		await process_frame
		await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		"Hub confirmation must enter the authoritative Autumn Battle V2 scene directly."
	)
	_expect((game.get("run_state") as RunState).active, "Entering Autumn Forest must start a run.")
	var battle_player := game.get("player") as Node2D
	var spawn := game.get("current_map").get_node_or_null("PlayerSpawn") as Node2D
	_expect(
		battle_player != null
			and spawn != null
			and battle_player.global_position.distance_to(spawn.global_position) <= 16.0,
		"Direct Autumn entry must place the transferred player at the battle PlayerSpawn. Got %s, expected %s."
		% [battle_player.global_position if battle_player != null else Vector2.INF, spawn.global_position if spawn != null else Vector2.INF]
	)
	var director := game.get("current_map").get_node_or_null("AutumnRunDirector") as Node
	_expect(
		director != null and bool(director.get("_running")),
		"Direct Autumn entry must start the battle encounter."
	)
	_expect(
		director != null and not (director.call("get_active_enemies") as Array).is_empty(),
		"The started Autumn encounter must spawn its initial enemy group."
	)
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
