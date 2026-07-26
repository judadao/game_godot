extends SceneTree

const EXPECTED_TYPES := [
	"attack",
	"power",
	"summon",
	"healing",
	"status",
	"ultimate",
	"combo",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database_script := load("res://scripts/systems/card_database.gd") as GDScript
	var deck_script := load("res://scripts/systems/deck_manager.gd") as GDScript
	var evolution_script := load("res://scripts/systems/evolution_manager.gd") as GDScript
	_expect(database_script != null, "CardDatabase script must load.")
	_expect(deck_script != null, "DeckManager script must load.")
	_expect(evolution_script != null, "EvolutionManager script must load.")
	if database_script == null or deck_script == null or evolution_script == null:
		quit(1)
		return

	var database: RefCounted = database_script.new()
	_expect(bool(database.call("load_catalog")), "Card catalog must load and validate.")
	var cards: Array = database.call("get_all_cards")
	_expect(cards.size() == 24, "Card catalog must contain 24 practical cards without a direct Dash card.")

	var seen_ids := {}
	var seen_types := {}
	for raw_card in cards:
		var card := raw_card as Dictionary
		var card_id := String(card.get("id", ""))
		var card_type := String(card.get("type", ""))
		var effect := card.get("effect", {}) as Dictionary
		_expect(not card_id.is_empty() and not seen_ids.has(card_id), "Every card ID must be non-empty and unique.")
		seen_ids[card_id] = true
		seen_types[card_type] = int(seen_types.get(card_type, 0)) + 1
		_expect(int(card.get("cost", -1)) >= 0, "%s must have a non-negative energy cost." % card_id)
		_expect(not (card.get("effect", {}) as Dictionary).is_empty(), "%s must define an effect." % card_id)
		_expect(
			card_id != "quickstep" and String(effect.get("kind", "")) not in ["dash", "dash_damage"],
			"%s must not duplicate the intrinsic Dash action as a card." % card_id
		)
		_expect(not String(card.get("rarity", "")).is_empty(), "%s must define rarity metadata." % card_id)
		_expect(int(card.get("level", 0)) >= 1, "%s must define a positive current level." % card_id)
		_expect(int(card.get("max_level", 0)) >= int(card.get("level", 0)), "%s must define a valid max level." % card_id)
		_expect(not (card.get("combo_tags", []) as Array).is_empty(), "%s must define combo tags." % card_id)
		_expect(
			not card.has("evolution_condition") and not card.has("evolution_result"),
			"%s must not retain the removed passive-evolution fields." % card_id
		)
		var level_three_upgrade := _find_upgrade(card.get("upgrade_effects", []) as Array, 3)
		_expect(not level_three_upgrade.is_empty(), "%s must define a level-three upgrade." % card_id)
		_expect(
			not String(level_three_upgrade.get("mechanic_change", "")).is_empty(),
			"%s level-three upgrade must describe a visible mechanism change." % card_id
		)
		var icon_path := String(card.get("icon_path", ""))
		_expect(not icon_path.is_empty() and ResourceLoader.exists(icon_path), "%s must reference a loadable icon." % card_id)
	for card_type in EXPECTED_TYPES:
		_expect(int(seen_types.get(card_type, 0)) >= 1, "Required card type '%s' must be represented." % card_type)
	_expect(not seen_types.has("defense"), "Removed Defense taxonomy must not return.")

	var deck: RefCounted = deck_script.new(database)
	deck.set("hand_size", 3)
	deck.call("start", ["ember_bolt", "battle_focus", "guard", "dash_strike"], 3)
	_expect(deck.get("hand") == ["ember_bolt", "battle_focus", "guard"], "Deck opening hand must preserve deterministic order.")
	var played := deck.call("play_from_hand", 0) as Dictionary
	_expect(String(played.get("id", "")) == "ember_bolt", "Affordable card must be returned when played.")
	_expect(int(deck.get("energy")) == 2, "Playing a card must spend its energy cost.")
	_expect(deck.has_method("regenerate_energy"), "Deck must support real-time AP regeneration.")
	if deck.has_method("regenerate_energy"):
		var regenerated := float(deck.call("regenerate_energy", 0.5, 0.65))
		_expect(is_equal_approx(regenerated, 0.325), "AP regeneration must be fractional and time-based.")
		_expect(is_equal_approx(float(deck.get("energy")), 2.325), "Regenerated AP must be immediately available.")
		deck.call("regenerate_energy", 99.0, 0.65)
		_expect(is_equal_approx(float(deck.get("energy")), float(deck.get("max_energy"))), "AP regeneration must clamp to maximum.")
		deck.set("energy", 2.0)
	var hand_before_failed_play := (deck.get("hand") as Array).duplicate()
	_expect((deck.call("play_from_hand", 0) as Dictionary).is_empty(), "Unaffordable card must not play.")
	_expect(deck.get("hand") == hand_before_failed_play, "Rejected card must remain in hand.")
	_expect(int(deck.get("energy")) == 2, "Rejected card must not spend energy.")

	var cycle_deck: RefCounted = deck_script.new(database)
	cycle_deck.set("hand_size", 2)
	cycle_deck.call("start", ["ember_bolt", "guard", "dash_strike"], 3)
	cycle_deck.call("play_from_hand", 0)
	cycle_deck.call("play_from_hand", 0)
	var redrawn: Array = cycle_deck.call("draw_cards", 3)
	_expect(
		redrawn == ["dash_strike", "ember_bolt"]
		and (cycle_deck.get("cooldown_pile") as Array).size() == 1,
		"Ordinary cards must recycle while timed cards stay out of the draw cycle during cooldown."
	)

	var redraw_deck := DeckManager.new(database)
	redraw_deck.start([
		"ember_bolt", "guard", "cleave", "shockwave", "healing_light",
		"frost_bind", "iron_skin", "dash_strike", "energy_surge", "battle_focus",
	], 5.0)
	var original_hand := redraw_deck.hand.duplicate()
	_expect(redraw_deck.redraw_hand_for_all_energy(), "Full AP must allow a complete hand redraw.")
	_expect(is_zero_approx(redraw_deck.energy), "Hand redraw must spend all AP.")
	_expect(redraw_deck.hand.size() == 8, "Hand redraw must draw two groups of four cards.")
	_expect(redraw_deck.hand != original_hand, "Hand redraw must replace the current cards.")
	_expect(not redraw_deck.redraw_hand_for_all_energy(), "Hand redraw must fail until AP is full again.")
	_expect((cycle_deck.get("discard_pile") as Array).is_empty(), "Reshuffled cards must leave discard.")

	var evolution: RefCounted = evolution_script.new(database)
	_expect(bool(evolution.call("load_recipes")), "Fusion recipes must load and validate card references.")
	var recipes: Array = evolution.call("get_all_recipes")
	_expect(recipes.size() == 6, "Fusion catalog must contain six valid recipes.")
	var fusion_materials: Array = []
	var instance_index := 0
	for raw_recipe in recipes:
		var recipe := raw_recipe as Dictionary
		for field in ["left_card_id", "right_card_id"]:
			instance_index += 1
			fusion_materials.append(CardInstance.new(
				String(recipe.get(field, "")),
				3,
				"fusion-material-%02d" % instance_index
			))
	var available: Array = evolution.call("find_available_fusions", fusion_materials)
	_expect(available.size() >= 6, "All six recipes must become available from distinct matching Lv3 instances.")

	quit(0 if _failures == 0 else 1)


func _find_upgrade(upgrades: Array, level: int) -> Dictionary:
	for raw_upgrade in upgrades:
		var upgrade := raw_upgrade as Dictionary
		if int(upgrade.get("level", 0)) == level:
			return upgrade
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
