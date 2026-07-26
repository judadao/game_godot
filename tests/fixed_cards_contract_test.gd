extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var quickstep := database.get_card("quickstep")
	var quickstep_effect := quickstep.get("effect", {}) as Dictionary
	_expect(
		int(quickstep.get("cost", -1)) == 1
		and String(quickstep_effect.get("kind", "")) == "dash"
		and int(quickstep_effect.get("distance", 0)) == 120
		and is_equal_approx(float(quickstep_effect.get("evasion_seconds", 0.0)), 0.2),
		"Quickstep must remain an ordinary one-AP Dash card."
	)

	var deck := DeckManager.new(database)
	deck.set_protected_cards([])
	deck.hand_size = 8
	deck.start([
		"ember_bolt", "quickstep", "guard", "cleave",
		"healing_light", "frost_bind", "iron_skin", "dash_strike",
		"energy_surge", "battle_focus",
	], 5.0, false)
	_expect(deck.hand.size() == 8, "Combat must draw two complete groups of four.")
	_expect(deck.protected_card_ids.is_empty(), "Attack and Dash cards must not be pinned.")

	var basic := deck.play_from_hand(deck.hand.find("ember_bolt"))
	_expect(
		String(basic.get("id", "")) == "ember_bolt"
		and deck.discard_pile.has("ember_bolt"),
		"Manual Attack cards must follow ordinary discard routing."
	)
	var dash := deck.play_from_hand(deck.hand.find("quickstep"))
	_expect(
		String(dash.get("id", "")) == "quickstep"
		and deck.discard_pile.has("quickstep"),
		"Quickstep must follow ordinary discard routing after use."
	)
	deck.draw_cards(2)
	_expect(deck.hand.size() == 8, "Played cards must be replaced to restore the eight-card hand.")

	var previous := deck.hand.duplicate()
	deck.energy = deck.max_energy
	_expect(deck.redraw_hand_for_all_energy(), "Full AP redraw must remain available.")
	_expect(
		deck.hand.size() == 8 and deck.hand != previous,
		"Redraw must replace the complete unpinned hand."
	)

	if _failures == 0:
		print("PASS: ordinary Attack and Dash eight-card lifecycle")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
