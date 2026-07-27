extends SceneTree

const BASE_COMBO_SECONDS := 4.0

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	_expect(game.has_method("_tick_combo_effects"), "Game must expose deterministic Combo countdown ticking.")
	_expect(game.has_method("_get_combo_time_remaining"), "Game must expose the current Combo window.")
	if not game.has_method("_tick_combo_effects") or not game.has_method("_get_combo_time_remaining"):
		game.queue_free()
		await process_frame
		quit(1)
		return

	var flame := (game.get("card_database") as CardDatabase).get_card("flame_imbue")
	_expect(bool(game.call("_resolve_combo_card", flame)), "A Combo effect card must open a timed window.")
	_expect(
		is_equal_approx(float(game.call("_get_combo_time_remaining")), BASE_COMBO_SECONDS),
		"Base Combo window must last four seconds."
	)
	game.call("_tick_combo_effects", 2.0)
	_expect(
		is_equal_approx(float(game.call("_get_combo_time_remaining")), 2.0),
		"Combo time must count down in real time."
	)
	_expect(bool(game.call("_resolve_combo_card", flame)), "Fast play must add a separately timed Combo stack.")
	game.call("_tick_combo_effects", 2.1)
	var run := game.get("run_state") as RunState
	_expect(int((run.temporary_buffs.get("combo_levels", {}) as Dictionary).get("flame", 0)) == 1, "An old stack must expire without deleting a newer fast-played stack.")

	var inventory := game.get("inventory_manager") as RefCounted
	inventory.call("add_equipment", &"focus_amulet")
	inventory.call("equip", &"focus_amulet")
	var discounted_flame := game.call("_card_for_cast", "flame_imbue") as Dictionary
	var discounted_rhythm := game.call("_card_for_cast", "battle_rhythm") as Dictionary
	_expect(int(discounted_flame.get("cost", 0)) == 2, "Combo equipment must reduce a three-AP Combo card by one.")
	_expect(int(discounted_rhythm.get("cost", 0)) == 1, "Combo AP discount must never lower a card below one AP.")
	var cost_deck := DeckManager.new(game.get("card_database") as CardDatabase)
	cost_deck.start(["flame_imbue"], 5.0)
	_expect(not cost_deck.play_from_hand(0, int(discounted_flame.get("cost", 0))).is_empty(), "Projected Combo cost must remain playable.")
	_expect(is_equal_approx(cost_deck.energy, 3.0), "Playing through DeckManager must spend the equipment-adjusted Combo AP.")

	var frost := (game.get("card_database") as CardDatabase).get_card("frostburst_imbue")
	_expect(bool(game.call("_resolve_combo_card", frost)), "A second timed Combo type must activate.")
	_expect(
		is_equal_approx(float(game.call("_get_combo_time_remaining")), 5.0),
		"Combo equipment must extend new Combo windows."
	)
	game.call("_tick_combo_effects", 5.1)
	_expect((run.temporary_buffs.get("active_infusions", []) as Array).is_empty(), "All Combo effects must disappear after their individual timers expire.")
	_expect((run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(), "Expired effects must stop modifying attacks.")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: timed Combo stacks, AP discount, and equipment duration")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
