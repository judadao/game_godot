extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load for deck building.")
	var meta := MetaState.new()
	_expect(meta.selected_deck.size() == 4, "A new profile must provide exactly four fixed skills.")
	for card_id in meta.selected_deck:
		_expect(meta.unlocked_cards.has(card_id), "Every starter-deck card must already be discovered.")

	var ui := (load("res://scenes/ui/DeckBuilderUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	var discovered: Array[Dictionary] = []
	for card_id in meta.unlocked_cards:
		discovered.append(database.get_card(card_id))
	ui.call("configure", discovered, meta.selected_deck)
	_expect(int(ui.call("get_selected_count")) == 4, "Deck builder must restore the fixed four-skill loadout.")
	var restored := ui.call("get_selected_deck") as Array
	_expect(restored.count("healing_light") == 1, "The fixed loadout must contain exactly one Healing skill.")
	ui.call("configure", discovered, [
		"guard", "guard",
		"cleave", "cleave", "cleave", "cleave",
	], "cleave")
	var clamped := ui.call("get_selected_deck") as Array
	_expect(
		clamped.size() == 4
			and clamped.count("guard") == 1
			and clamped.count("healing_light") == 1,
		"Legacy loadouts must become one Healing plus three unique Combo skills."
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
