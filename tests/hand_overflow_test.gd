extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var deck := DeckManager.new(database)
	deck.set_protected_cards([])
	deck.start([
		"guard", "cleave", "shockwave", "healing_light", "frost_bind",
		"iron_skin", "dash_strike", "energy_surge", "battle_focus", "ember_bolt",
	], 5.0, false)
	_expect(deck.hand.size() == 4, "Opening hand must contain exactly four cards.")
	deck.draw_cards(2)
	_expect(deck.hand.size() == 6, "Multi-draw may temporarily overflow the four-card hand.")

	var cards: Array[Dictionary] = []
	for card_id in deck.hand:
		cards.append(database.get_card(card_id))
	var ui := (load("res://scenes/ui/cards/CardDiscardUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	ui.call("configure", cards, 2, [])
	_expect(
		(ui.call("get_protected_indices") as Array).is_empty(),
		"Overflow selection must not reserve removed fixed-card slots."
	)
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
