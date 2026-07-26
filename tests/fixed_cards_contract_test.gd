extends SceneTree

const FIXED_IDS: Array[String] = ["ember_bolt", "quickstep"]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var quickstep := database.get_card("quickstep")
	_expect(int(quickstep.get("cost", -1)) == 1, "Fixed Quickstep must cost exactly 1 AP.")
	var quickstep_effect := quickstep.get("effect", {}) as Dictionary
	_expect(
		String(quickstep_effect.get("kind", "")) == "dash"
		and int(quickstep_effect.get("distance", 0)) == 120
		and is_equal_approx(float(quickstep_effect.get("evasion_seconds", 0.0)), 0.2),
		"Fixed Quickstep must remain a 120-pixel Dash with 0.2 seconds of evasion."
	)
	_expect(not quickstep_effect.has("draw_cards"), "Fixed Quickstep must not draw cards.")

	var deck := DeckManager.new(database)
	_expect(deck.has_method("set_protected_cards"), "DeckManager must accept an ordered protected-card collection.")
	_expect(deck.has_method("is_card_protected"), "DeckManager must expose protected-card membership.")
	if not deck.has_method("set_protected_cards") or not deck.has_method("is_card_protected"):
		quit(1)
		return

	deck.call("set_protected_cards", FIXED_IDS)
	_expect(bool(deck.call("is_card_protected", "ember_bolt")), "Ember Bolt must be protected.")
	_expect(bool(deck.call("is_card_protected", "quickstep")), "Quickstep must be protected.")
	_expect(not bool(deck.call("is_card_protected", "guard")), "Ordinary cards must not become protected.")

	deck.hand_size = 8
	deck.start([
		"guard", "cleave", "healing_light", "frost_bind",
		"iron_skin", "dash_strike", "energy_surge", "battle_focus",
		"quickstep", "ember_bolt",
	], 5.0, true)
	_expect(
		deck.hand.slice(0, 2) == FIXED_IDS,
		"Shuffled opening hand must pin Ember Bolt and Quickstep at indices zero and one; got %s."
		% [deck.hand]
	)

	var basic := deck.play_from_hand(0)
	_expect(String(basic.get("id", "")) == "ember_bolt", "Q must play the fixed basic attack.")
	_expect(deck.hand.slice(0, 2) == FIXED_IDS, "Playing the basic attack must retain both fixed slots.")
	var dash := deck.play_from_hand(1)
	_expect(String(dash.get("id", "")) == "quickstep", "W must play the fixed Dash.")
	_expect(deck.hand.slice(0, 2) == FIXED_IDS, "Playing Dash must retain both fixed slots.")
	_expect(
		not deck.discard_pile.has("ember_bolt")
		and not deck.discard_pile.has("quickstep")
		and not deck.exhaust_pile.has("ember_bolt")
		and not deck.exhaust_pile.has("quickstep"),
		"Fixed cards must never enter discard or exhaust piles."
	)

	deck.energy = deck.max_energy
	_expect(deck.redraw_hand_for_all_energy(), "Full AP redraw must remain available.")
	_expect(deck.hand.slice(0, 2) == FIXED_IDS, "Full redraw must retain both fixed cards in order.")
	deck.end_turn()
	_expect(deck.hand.slice(0, 2) == FIXED_IDS, "End-turn cycling must retain both fixed cards in order.")

	if _failures == 0:
		print("PASS: fixed basic attack and Dash deck lifecycle")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
