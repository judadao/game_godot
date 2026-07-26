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
	deck.hand_size = 8
	deck.start([
		"ember_bolt", "shockwave", "guard", "cleave",
		"healing_light", "frost_bind", "iron_skin", "dash_strike",
		"energy_surge", "battle_focus",
	], 5.0, false)
	_expect(deck.hand.size() == 8, "Combat must draw two complete groups of four.")
	_expect(deck.protected_card_ids.is_empty(), "Combat cards must not be pinned.")

	var basic := deck.play_from_hand(deck.hand.find("ember_bolt"))
	_expect(
		String(basic.get("id", "")) == "ember_bolt"
		and deck.discard_pile.has("ember_bolt"),
		"Manual Attack cards must follow ordinary discard routing."
	)
	deck.draw_cards(1)
	_expect(deck.hand.size() == 8, "Played cards must be replaced to restore the eight-card hand.")

	var previous := deck.hand.duplicate()
	deck.energy = deck.max_energy
	_expect(deck.redraw_hand_for_all_energy(), "Full AP redraw must remain available.")
	_expect(
		deck.hand.size() == 8 and deck.hand != previous,
		"Redraw must replace the complete unpinned hand."
	)

	if _failures == 0:
		print("PASS: intrinsic Dash remains outside the ordinary eight-card lifecycle")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
