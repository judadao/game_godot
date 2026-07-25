extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	var player := game.get("player") as Node
	player.health = 12
	player.mana = 3
	var run := game.get("run_state") as RunState
	var levels_before := run.card_levels.duplicate(true)
	var deck := game.get("deck_manager") as DeckManager
	var cards_before: Array = deck.hand + deck.draw_pile + deck.discard_pile
	_expect(bool(game.call("_rest_at_campfire")), "Unused campfire must restore the player.")
	_expect(int(player.health) == int(player.max_health) and int(player.mana) == int(player.max_mana), "Campfire must fully restore HP and MP.")
	_expect(run.card_levels == levels_before, "Campfire must not upgrade cards.")
	_expect(deck.hand + deck.draw_pile + deck.discard_pile == cards_before, "Campfire must not merge, add, or remove cards.")
	_expect(not bool(game.call("_rest_at_campfire")), "Each campfire may restore only once per expedition.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
