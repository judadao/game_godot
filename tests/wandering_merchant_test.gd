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
	_expect(stock.size() >= 5, "Wandering merchant must stock potions, cards, and purge.")
	_expect(bool(game.call("_purchase_wandering_offer", {"kind": "health_potion", "price": 25})), "Health potion must be purchasable.")
	_expect(int(player.health) == 50 and run.gold_earned == 175, "Health potion must restore 40 HP and spend 25 run gold.")
	_expect(bool(game.call("_purchase_wandering_offer", {"kind": "mana_potion", "price": 20})), "Mana potion must be purchasable.")
	_expect(int(player.mana) == 32 and run.gold_earned == 155, "Mana potion must restore 30 MP and spend 20 run gold.")
	var deck := game.get("deck_manager") as DeckManager
	var meta := game.get("meta_state") as MetaState
	var removable: CardInstance
	for instance in run.card_instances:
		if instance.card_id == "ember_bolt":
			removable = instance
			break
	_expect(removable != null, "The expedition must contain a removable Attack CardInstance.")
	if removable != null:
		var removable_id := removable.instance_id
		var count_before := deck.get_all_instances().size()
		_expect(bool(game.call("_purchase_wandering_offer", {
			"kind": "purge",
			"price": 45,
			"card_id": removable.card_id,
			"instance_id": removable_id,
		})), "Merchant purge must accept the former fixed attack by exact identity.")
		_expect(
			deck.get_all_instances().size() == count_before - 1
			and deck.find_instance(removable_id) == null
			and run.get_card_instance(removable_id) == null
			and meta.get_card_instance(removable_id) == null,
			"Merchant purge must remove the same identity from Deck, Run, and Meta."
		)
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
