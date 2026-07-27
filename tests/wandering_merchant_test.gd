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
	var run := game.get("run_state") as RunState
	run.gold_earned = 200
	var player := game.get("player") as Node
	player.health = 10
	player.mana = 2
	var stock := game.call("_build_wandering_stock") as Array
	_expect(stock.size() >= 2, "Wandering merchant must stock run-restoration supplies.")
	_expect(bool(game.call("_purchase_wandering_offer", {"kind": "health_potion", "price": 25})), "Health potion must be purchasable.")
	_expect(int(player.health) == 50 and run.gold_earned == 175, "Health potion must restore 40 HP and spend 25 run gold.")
	_expect(bool(game.call("_purchase_wandering_offer", {"kind": "mana_potion", "price": 20})), "Mana potion must be purchasable.")
	_expect(int(player.mana) == 32 and run.gold_earned == 155, "Mana potion must restore 30 MP and spend 20 run gold.")
	var deck := game.get("deck_manager") as DeckManager
	_expect(
		deck.hand.size() == 4
			and deck.draw_pile.is_empty()
			and deck.discard_pile.is_empty(),
		"Merchant purchases must not alter the fixed four-skill loadout."
	)
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
