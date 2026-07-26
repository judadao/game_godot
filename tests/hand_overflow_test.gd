extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var deck := DeckManager.new(database)
	deck.set_protected_cards(["ember_bolt", "quickstep"])
	deck.start([
		"guard", "cleave", "quickstep", "healing_light", "frost_bind",
		"iron_skin", "dash_strike", "energy_surge", "battle_focus", "ember_bolt",
	], 5.0, true)
	_expect(deck.hand.size() == 8 and deck.hand.slice(0, 2) == ["ember_bolt", "quickstep"], "Opening hand must begin with both fixed cards.")
	var basic_index := deck.hand.find("ember_bolt")
	var basic := deck.play_from_hand(basic_index)
	_expect(not basic.is_empty() and deck.hand.size() == 8 and deck.last_play_retained, "Playing the fixed basic attack must not remove it from hand.")
	deck.draw_cards(2)
	_expect(deck.hand.size() == 10, "Multi-draw may temporarily overflow the eight-card hand.")

	var cards: Array[Dictionary] = []
	for card_id in deck.hand:
		cards.append(database.get_card(card_id))
	var ui := (load("res://scenes/ui/CardDiscardUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	ui.call("configure", cards, 2, ["ember_bolt", "quickstep"])
	_expect(ui.call("get_protected_indices") == [0, 1], "Overflow choice must protect both fixed cards.")
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
