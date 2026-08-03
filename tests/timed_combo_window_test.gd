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
		"Each Combo card effect must keep its independent 1.5-second lifetime."
	)
	_expect(
		is_equal_approx(
			float(run.temporary_buffs.get("combo_chain_remaining", 0.0)),
			2.0
		),
		"The first three total Combo stacks must use the forgiving two-second chain window."
	)
	_expect(
		is_equal_approx(float(game.call("_combo_chain_duration_for_count", 3)), 2.0)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 4)), 1.3)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 5)), 1.2)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 10)), 0.7)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 11)), 0.6)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 12)), 0.6)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 1, 0.5)), 2.5)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 4, 0.5)), 1.8)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 10, 0.5)), 1.2)
			and is_equal_approx(float(game.call("_combo_chain_duration_for_count", 11, 0.5)), 1.1),
		"Combo Chain must tighten from 1.3 seconds after stack three and keep a 0.6-second floor."
	)
	game.call("_tick_combo_effects", 1.49)
	_expect(
		not (run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(),
		"A Combo card effect must remain active immediately before its own timer expires."
	)
	game.call("_tick_combo_effects", 0.02)
	_expect(
		(run.temporary_buffs.get("infusion_effects", []) as Array).is_empty()
			and int(run.temporary_buffs.get("combo_chain_count", 0)) == 1,
		"The card effect must expire without clearing the two-second opening chain window."
	)
	game.call("_tick_combo_effects", 0.50)
	_expect(
		(run.temporary_buffs.get("infusion_effects", []) as Array).is_empty()
			and int(game.call("_combo_chain_stack_for_card", flame)) == 0,
		"The opening Combo Chain and corresponding Sword Soul count must clear after two seconds."
	)
	_expect(bool(game.call("_resolve_combo_card", flame)), "A repeated Combo card must add an overlapping stack.")
	_expect(bool(game.call("_resolve_combo_card", flame)), "Rapid repeated Combo cards must stack while both timers are active.")
	_expect(bool(game.call("_resolve_combo_card", flame)), "The third opening Combo must remain valid.")
	_expect(bool(game.call("_resolve_combo_card", flame)), "The fourth Combo must enter the pressure window.")
	_expect(
		int((run.temporary_buffs.get("combo_levels", {}) as Dictionary).get("flame", 0)) == 4
			and int(run.temporary_buffs.get("combo_chain_count", 0)) == 4
			and is_equal_approx(
				float(run.temporary_buffs.get("combo_chain_remaining", 0.0)),
				1.3
			),
		"The fourth successful Combo must use the post-increment total and reset to 1.3 seconds."
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
	run.temporary_buffs["active_infusions"] = []
	run.temporary_buffs["combo_levels"] = {}
	run.temporary_buffs["infusion_effects"] = []
	run.temporary_buffs["combo_chain_count"] = 0
	run.temporary_buffs["combo_chain_remaining"] = 0.0
	var discounted_flame := game.call("_card_for_cast", "flame_imbue") as Dictionary
	var discounted_rhythm := game.call("_card_for_cast", "battle_rhythm") as Dictionary
	_expect(int(discounted_flame.get("cost", 0)) == 1, "Combo equipment must reduce a two-AP Sword Soul by one.")
	_expect(int(discounted_rhythm.get("cost", 0)) == 1, "Combo AP discount must never lower a card below one AP.")
	var cost_deck := DeckManager.new(game.get("card_database") as CardDatabase)
	cost_deck.start(["flame_imbue"], 5.0)
	_expect(not cost_deck.play_from_hand(0, int(discounted_flame.get("cost", 0))).is_empty(), "Projected Combo cost must remain playable.")
	_expect(is_equal_approx(cost_deck.energy, 4.0), "Playing through DeckManager must spend the equipment-adjusted Combo AP.")

	var frost := (game.get("card_database") as CardDatabase).get_card("frostburst_imbue")
	_expect(bool(game.call("_resolve_combo_card", frost)), "A second timed Combo type must activate.")
	var equipped_effects := run.temporary_buffs.get("infusion_effects", []) as Array
	_expect(
		equipped_effects.size() == 1
			and is_equal_approx(
				float((equipped_effects[0] as Dictionary).get("remaining_seconds", 0.0)),
				2.0
			)
			and is_equal_approx(
				float(run.temporary_buffs.get("combo_chain_remaining", 0.0)),
				2.5
			),
		"Focus Amulet must extend the opening effect and chain windows to 2.0 and 2.5 seconds."
	)
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
