extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_expect(game.get("meta_state") is MetaState, "Game must own persistent meta state.")
	_expect(game.get("run_state") is RunState, "Game must own transient run state.")
	if not game.get("meta_state") is MetaState or not game.get("run_state") is RunState:
		game.queue_free()
		await process_frame
		quit(1)
		return
	var original_player := game.get("player") as Node
	original_player.set("health", 41)
	original_player.set("mana", 17)
	original_player.set("level", 4)
	original_player.set("experience", 23)

	var forest := load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	game.call("load_current_map", forest)
	var forest_player := game.get("player") as Node
	_expect(forest_player != original_player, "Map swap should instantiate the destination player.")
	_expect(int(forest_player.get("health")) == 41, "Portal travel must preserve current health.")
	_expect(int(forest_player.get("mana")) == 17, "Portal travel must preserve current mana.")
	_expect(int(forest_player.get("level")) == 4, "Portal travel must preserve run level.")
	_expect(int(forest_player.get("experience")) == 23, "Portal travel must preserve run experience.")
	var player_spawn := game.get("current_map").get_node_or_null("PlayerSpawn") as Marker2D
	_expect(
		player_spawn != null
		and (forest_player as Node2D).global_position.is_equal_approx(player_spawn.global_position),
		"Regenerated Autumn routes must always begin from the authored route entrance."
	)

	game.call("_begin_autumn_run")
	var run := game.get("run_state") as RunState
	var meta := game.get("meta_state") as MetaState
	var gold_before := int(meta.resources.get("gold", 0))
	var wood_before := int(meta.resources.get("autumn_wood", 0))
	_expect(run.active, "Entering Autumn Forest must begin a run.")
	run.gold_earned = 35
	run.materials_earned = {"autumn_wood": 4}
	game.call("_finish_run", false)
	_expect(not run.active and run.level == 1, "Finishing a failed run must reset transient state.")
	_expect(int(meta.resources.get("gold", 0)) == gold_before + 35, "Failed-run gold must transfer to permanent state.")
	_expect(int(meta.resources.get("autumn_wood", 0)) == wood_before + 4, "Failed-run materials must transfer to permanent state.")

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
