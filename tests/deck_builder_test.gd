extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load for deck building.")
	var meta := MetaState.new()
	_expect(meta.selected_deck.size() == 16, "A new profile must provide a valid 16-card starter deck.")
	for card_id in meta.selected_deck:
		_expect(meta.unlocked_cards.has(card_id), "Every starter-deck card must already be discovered.")

	var ui := (load("res://scenes/ui/DeckBuilderUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	var discovered: Array[Dictionary] = []
	for card_id in meta.unlocked_cards:
		discovered.append(database.get_card(card_id))
	ui.call("configure", discovered, meta.selected_deck)
	_expect(int(ui.call("get_selected_count")) == 16, "Deck builder must restore the saved 16-card backpack.")
	var restored := ui.call("get_selected_deck") as Array
	_expect(restored.count("flame_imbue") == 1, "Rare Combo cards must be limited to one starting copy.")
	ui.call("configure", discovered, [
		"dash_strike", "dash_strike",
		"cleave", "cleave", "cleave", "cleave",
	], "cleave")
	var clamped := ui.call("get_selected_deck") as Array
	_expect(
		clamped.count("dash_strike") == 1 and clamped.count("cleave") == 3,
		"Restored loadouts must clamp Combo cards to one and ordinary cards to three."
	)
	_expect(
		String(ui.call("get_auto_attack_card_id")) == "cleave",
		"Deck builder must restore the separately selected automatic attack."
	)
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
