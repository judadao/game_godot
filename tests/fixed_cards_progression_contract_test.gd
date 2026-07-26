extends SceneTree

const FIXED_IDS: Array[String] = ["ember_bolt", "quickstep"]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var valid_ids: Array[String] = []
	for card in database.get_all_cards():
		valid_ids.append(String(card.get("id", "")))

	var migrated: Array[String] = [
		"guard", "guard", "cleave", "cleave",
		"iron_skin", "healing_light", "frost_bind", "energy_surge",
		"battle_focus", "dash_strike", "flame_imbue", "frostburst_imbue",
		"stoneguard_combo", "battle_rhythm", "meteor", "forest_call",
	]
	var meta := MetaState.new()
	meta.selected_deck = migrated.duplicate()
	var meta_normalized := meta.normalize_selected_deck(valid_ids)
	_verify_normalized_deck(meta_normalized, "MetaState")

	var builder := (load("res://scenes/ui/DeckBuilderUI.tscn") as PackedScene).instantiate()
	root.add_child(builder)
	await process_frame
	builder.call("configure", database.get_all_cards(), migrated)
	var selected := builder.call("get_selected_deck") as Array[String]
	_expect(selected.count("ember_bolt") == 1, "Deck builder must reserve exactly one Ember Bolt.")
	_expect(selected.count("quickstep") == 1, "Deck builder must reserve exactly one Quickstep.")
	_expect(selected.size() <= 16, "Deck builder must keep both fixed cards inside the 16-card maximum.")
	builder.queue_free()
	await process_frame

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var game_normalized := game.call("_normalize_expedition_deck", migrated) as Array[String]
	_verify_normalized_deck(game_normalized, "Game")
	game.call("_begin_autumn_run", migrated)
	var deck := game.get("deck_manager") as DeckManager
	var run := game.get("run_state") as RunState
	_expect(deck.hand.slice(0, 2) == FIXED_IDS, "Autumn run must open with Q basic attack and W Dash.")
	_expect(not run.card_levels.has("ember_bolt"), "Basic attack must not enter card-level growth.")
	_expect(not run.card_levels.has("quickstep"), "Dash must not enter card-level growth.")

	for fixed_id in FIXED_IDS:
		var copies_before := int(game.call("_get_card_copy_count", fixed_id))
		_expect(not bool(game.call("_apply_card_reward", fixed_id)), "%s must reject duplicate card rewards." % fixed_id)
		_expect(int(game.call("_get_card_copy_count", fixed_id)) == copies_before, "%s reward rejection must not mutate the deck." % fixed_id)
		run.card_levels[fixed_id] = 1
		_expect(
			not bool(game.call("_apply_level_up_choice", {"kind": "upgrade_card", "card_id": fixed_id})),
			"%s must reject XP card upgrades." % fixed_id
		)
		_expect(not bool(game.call("_merge_card_at_campfire", fixed_id)), "%s must reject campfire merging." % fixed_id)

	run.gold_earned = 200
	for fixed_id in FIXED_IDS:
		var copies_before := int(game.call("_get_card_copy_count", fixed_id))
		_expect(
			not bool(game.call("_purchase_wandering_offer", {
				"kind": "purge",
				"price": 45,
				"card_id": fixed_id,
			})),
			"Merchant must reject purging %s." % fixed_id
		)
		_expect(int(game.call("_get_card_copy_count", fixed_id)) == copies_before, "Rejected purge must preserve %s." % fixed_id)

	var cards: Array[Dictionary] = []
	for card_id in deck.hand:
		cards.append(database.get_card(card_id))
	var discard_ui := (load("res://scenes/ui/CardDiscardUI.tscn") as PackedScene).instantiate()
	root.add_child(discard_ui)
	await process_frame
	_expect(discard_ui.has_method("get_protected_indices"), "Overflow UI must expose all protected indices.")
	if discard_ui.has_method("get_protected_indices"):
		discard_ui.call("configure", cards, 1, FIXED_IDS)
		var protected_indices := discard_ui.call("get_protected_indices") as Array[int]
		_expect(protected_indices == [0, 1], "Overflow UI must protect hand slots zero and one.")
	discard_ui.queue_free()

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: fixed-card normalization, reservation, removal, and growth rules")
	quit(1 if _failures > 0 else 0)


func _verify_normalized_deck(deck_ids: Array[String], owner_name: String) -> void:
	_expect(deck_ids.size() == 16, "%s must retain a 16-card migrated deck." % owner_name)
	_expect(deck_ids.slice(0, 2) == FIXED_IDS, "%s must normalize fixed cards into the first two slots." % owner_name)
	_expect(deck_ids.count("ember_bolt") == 1, "%s must retain exactly one Ember Bolt." % owner_name)
	_expect(deck_ids.count("quickstep") == 1, "%s must retain exactly one Quickstep." % owner_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
