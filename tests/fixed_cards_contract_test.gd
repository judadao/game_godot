extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	_expect(
		not database.has_card("quickstep"),
		"Intrinsic Dash must not be duplicated as a Quickstep card in the production catalog."
	)
	for card in database.get_all_cards():
		var effect := card.get("effect", {}) as Dictionary
		_expect(
			String(effect.get("kind", "")) not in ["dash", "dash_damage"],
			"Production cards must not provide a direct Dash effect: %s." % card.get("id", "")
		)

	var deck := DeckManager.new(database)
	deck.set_protected_cards([])
	deck.hand_size = 4
	deck.start([
		"guard", "iron_skin", "dash_strike", "gale_lunge",
		"flame_imbue", "frostburst_imbue",
	], 5.0, false)
	_expect(deck.hand.size() == 4, "Combat must draw one complete group of four.")
	_expect(deck.protected_card_ids.is_empty(), "Combat cards must not be pinned.")
	var basic := deck.play_from_hand(deck.hand.find("guard"))
	_expect(
		String(basic.get("type", "")) == "combo",
		"Manual hand cards must be Combo cards."
	)
	deck.draw_cards(1)
	_expect(deck.hand.size() == 4, "Played cards must be replaced to restore the four-card hand.")

	var previous := deck.hand.duplicate()
	deck.energy = 0.5
	_expect(deck.discard_and_redraw_hand(), "T discard must remain available below full AP.")
	_expect(
		deck.hand.size() == 4 and deck.hand != previous,
		"Redraw must replace the complete unpinned hand."
	)

	if _failures == 0:
		print("PASS: intrinsic Dash remains outside the four-card Combo lifecycle")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
