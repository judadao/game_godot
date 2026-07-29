extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	var flame := (game.get("card_database") as CardDatabase).get_card("flame_imbue")
	_expect(bool(game.call("_resolve_combo_card", flame)), "A Combo effect card must add timed attack power.")
	var run := game.get("run_state") as RunState
	var flame_effects := run.temporary_buffs.get("infusion_effects", []) as Array
	_expect(
		flame_effects.size() == 1
			and not bool((flame_effects[0] as Dictionary).get("persistent", true))
			and is_equal_approx(
				float((flame_effects[0] as Dictionary).get("remaining_seconds", 0.0)),
				1.5
			),
		"Each Combo card effect must own an independent 1.5-second lifetime."
	)
	_expect(
		is_equal_approx(
			float(run.temporary_buffs.get("combo_chain_remaining", 0.0)),
			2.5
		),
		"Skill-triggering Combo Chain must retain its separate 2.5-second window."
	)
	game.call("_tick_combo_effects", 1.49)
	_expect(
		not (run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(),
		"A Combo card effect must remain active immediately before 1.5 seconds."
	)
	game.call("_tick_combo_effects", 0.02)
	_expect(
		(run.temporary_buffs.get("infusion_effects", []) as Array).is_empty()
			and int(run.temporary_buffs.get("combo_chain_count", 0)) == 1,
		"Combo card effects must expire at 1.5 seconds without shortening Combo Chain."
	)
	game.call("_tick_combo_effects", 1.0)
	_expect(
		int(run.temporary_buffs.get("combo_chain_count", 0)) == 0,
		"Combo Chain must expire on its original independent timer."
	)
	_expect(bool(game.call("_resolve_combo_card", flame)), "A repeated Combo card must add an overlapping stack.")
	_expect(bool(game.call("_resolve_combo_card", flame)), "Rapid repeated Combo cards must stack while both timers are active.")
	_expect(
		int((run.temporary_buffs.get("combo_levels", {}) as Dictionary).get("flame", 0)) == 2,
		"Repeated effects must stack during their overlapping 1.5-second lifetimes."
	)
	run.temporary_buffs["active_infusions"] = []
	run.temporary_buffs["combo_levels"] = {}
	run.temporary_buffs["infusion_effects"] = []
	run.temporary_buffs["combo_chain_count"] = 0
	run.temporary_buffs["combo_chain_remaining"] = 0.0
	var giant_arc := (game.get("card_database") as CardDatabase).get_card("giant_arc")
	var cadence := (game.get("card_database") as CardDatabase).get_card(
		"quickened_cadence"
	)
	_expect(bool(game.call("_resolve_combo_card", giant_arc)), "Giant Arc must activate.")
	game.call("_tick_combo_effects", 0.75)
	_expect(bool(game.call("_resolve_combo_card", cadence)), "Quickened Cadence must activate later.")
	game.call("_tick_combo_effects", 0.76)
	var partially_expired := game.call(
		"_apply_combo_infusions_to_card",
		(game.get("card_database") as CardDatabase).get_card("ember_bolt")
	) as Dictionary
	_expect(
		is_equal_approx(float(partially_expired.get("attack_size_multiplier", 1.0)), 1.0)
			and float(partially_expired.get("auto_attack_interval", 1.0)) < 1.0,
		"Expired size must return to normal while a later independent speed effect remains."
	)

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
		(run.temporary_buffs.get("active_infusions", []) as Array).has("frost"),
		"A second Combo type must join the prepared attack."
	)
	for _attack in 3:
		game.call("_consume_combo_attack_charges")
	_expect(not (run.temporary_buffs.get("active_infusions", []) as Array).is_empty(), "Automatic attacks must not consume Combo identities.")
	_expect(not (run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(), "Timed Combo effects must remain active until their own timers expire.")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: independent timed Combo effects, Combo Chain, and AP discount")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
