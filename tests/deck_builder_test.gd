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

	var ui := (load("res://scenes/ui/cards/DeckBuilderUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	var discovered: Array[Dictionary] = []
	for card_id in meta.unlocked_cards:
		discovered.append(database.get_card(card_id))
	ui.call("configure", discovered, meta.selected_deck)
	_expect(int(ui.call("get_selected_count")) == 4, "Deck builder must restore the fixed four-skill loadout.")
	var restored := ui.call("get_selected_deck") as Array
	_expect(_healing_count(database, restored) >= 1, "The fixed loadout must contain at least one Healing skill.")
	_expect(
		not restored.has("energy_surge"),
		"Deck builder must not restore a skill that cannot advance a Finisher recipe."
	)
	ui.call("configure", discovered, [
		"healing_light", "renewal", "verdant_renewal", "storm_charge",
	])
	_expect(
		_healing_count(database, ui.call("get_selected_deck") as Array) == 3,
		"Deck builder must preserve a legal loadout containing multiple Healing skills."
	)
	ui.call("configure", discovered, [
		"guard", "guard",
		"cleave", "cleave", "cleave", "cleave",
	], "cleave")
	var clamped := ui.call("get_selected_deck") as Array
	_expect(
		clamped.size() == 4
			and clamped.count("guard") == 1
			and _healing_count(database, clamped) >= 1,
		"Legacy loadouts must become four unique combat skills with at least one Healing skill."
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


func _healing_count(database: CardDatabase, card_ids: Array) -> int:
	var count := 0
	for card_id in card_ids:
		if String(database.get_card(String(card_id)).get("type", "")) == "healing":
			count += 1
	return count
