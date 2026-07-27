extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"guard", "iron_skin", "healing_light", "renewal",
		"blood_pact_combo", "verdant_renewal",
		"flame_imbue", "frostburst_imbue", "battle_rhythm",
	])
	var deck := game.get("deck_manager") as DeckManager
	var complete_deck: Array = deck.hand + deck.draw_pile + deck.discard_pile
	_expect(complete_deck.has("flame_imbue") and complete_deck.has("frostburst_imbue"), "Combo cards must be shuffled into the ordinary combat deck.")
	_expect(
		complete_deck.has("healing_light")
			and complete_deck.has("verdant_renewal")
			and not complete_deck.has("dash_strike")
			and not complete_deck.has("gale_lunge"),
		"Combat hand pool must include Healing cards without prioritizing Dash Combo cards."
	)
	_expect(deck.hand.size() == 4, "Combat must draw one four-card Combo/Healing hand.")

	for _play_index in 12:
		deck.energy = deck.max_energy
		game.call("_on_card_selected", 0)
		_expect(deck.hand.size() == 4, "Playing cards repeatedly must always refill the hand to four.")
	var run := game.get("run_state") as RunState
	run.temporary_buffs["active_infusions"] = []
	run.temporary_buffs["combo_levels"] = {}
	run.temporary_buffs["infusion_effects"] = []
	run.temporary_buffs["combo_chain_count"] = 0
	run.temporary_buffs["combo_chain_remaining"] = 0.0
	run.temporary_buffs["combo_chain_skills"] = {}
	run.temporary_buffs["combo_chain_order"] = []
	var expanded_effects: Array = []
	for card_id in [
		"sweeping_reach",
		"quickened_cadence",
		"crushing_momentum",
		"keen_focus_combo",
		"storm_charge",
	]:
		var expanded_card := database_card(game, card_id)
		_expect(
			String(expanded_card.get("type", "")) == "combo",
			"%s must be an available non-Dash Combo card." % card_id
		)
		var expanded_effect := (expanded_card.get("effect", {}) as Dictionary).duplicate(true)
		expanded_effect["remaining_seconds"] = 8.0
		expanded_effects.append(expanded_effect)
	run.temporary_buffs["infusion_effects"] = expanded_effects
	var expanded_attack := game.call(
		"_apply_combo_infusions_to_card",
		database_card(game, "ember_bolt")
	) as Dictionary
	var expanded_attack_effect := expanded_attack.get("effect", {}) as Dictionary
	_expect(
		float(expanded_attack.get("auto_attack_range", 0.0)) > 260.0
			and float(expanded_attack.get("auto_attack_interval", 99.0)) < 1.0
			and int(expanded_attack_effect.get("amount", 0)) >= 19
			and float(expanded_attack_effect.get("critical_chance", 0.0)) >= 0.18
			and float(expanded_attack_effect.get("combo_stun", 0.0)) >= 0.12,
		"Expanded Combo cards must modify range, speed, power, critical chance, and lightning status."
	)
	run.temporary_buffs["infusion_effects"] = []

	deck.start(["flame_imbue", "flame_imbue", "frostburst_imbue", "battle_rhythm"], 5.0)
	var flame := deck.play_from_hand(0)
	_expect(not flame.is_empty() and is_equal_approx(deck.energy, 2.0), "Flame Imbue must be an ordinary three-AP hand play.")
	_expect(bool(game.call("_resolve_combo_card", flame)), "Playing Flame Imbue must activate its persistent infusion.")
	_expect(deck.discard_pile.has("flame_imbue") and deck.exhaust_pile.is_empty(), "A played Combo card must recycle through discard without cooldown or exhaust.")
	deck.energy = 5.0
	var second_flame := deck.play_from_hand(0)
	_expect(bool(game.call("_resolve_combo_card", second_flame)), "A duplicate Combo card must add another stack.")
	_expect(
		int(run.temporary_buffs.get("combo_chain_count", 0)) >= 2,
		"Repeated Combo cards must build a visible global Combo Chain."
	)
	var chain_skills := run.temporary_buffs.get("combo_chain_skills", {}) as Dictionary
	_expect(
		int(chain_skills.get("Flame Imbue", 0)) == 2,
		"Combo Chain must retain per-skill stack counts for the persistent HUD list."
	)
	for _stack_index in 7:
		_expect(
			bool(game.call("_resolve_combo_card", database_card(game, "flame_imbue"))),
			"Combo effects must continue stacking toward the chain milestones."
		)
	var milestone_attack := game.call(
		"_apply_combo_infusions_to_card",
		database_card(game, "ember_bolt")
	) as Dictionary
	var milestone_effect := milestone_attack.get("effect", {}) as Dictionary
	_expect(
		int(run.temporary_buffs.get("combo_chain_count", 0)) >= 9
			and float(milestone_effect.get("lifesteal_ratio", 0.0)) >= 0.05
			and float(milestone_effect.get("combo_stun", 0.0)) >= 0.15,
		"Nine Combo stacks must unlock Power, Lifesteal, and Stun milestones."
	)
	var frost := deck.play_from_hand(0)
	_expect(frost.is_empty(), "An unaffordable Combo card must remain in hand.")
	deck.energy = 5.0
	frost = deck.play_from_hand(0)
	_expect(bool(game.call("_resolve_combo_card", frost)), "Playing Frostburst Imbue must activate its persistent infusion.")
	var rhythm := deck.play_from_hand(0)
	_expect(bool(game.call("_resolve_combo_card", rhythm)), "Non-element Combo cards must also resolve run buffs.")
	_expect(
		not bool(game.call("_resolve_combo_card", database_card(game, "stoneguard_combo"))),
		"Counterguard is now a direct timed status card, not a legacy infusion."
	)

	var database := game.get("card_database") as CardDatabase
	var base := database.get_card("ember_bolt")
	var infused := game.call("_apply_combo_infusions_to_card", base) as Dictionary
	var effect := infused.get("effect", {}) as Dictionary
	_expect(int(effect.get("amount", 0)) >= int((base.get("effect", {}) as Dictionary).get("amount", 0)) + 12, "Stacked Combo infusions and rhythm buffs must all add damage.")
	_expect(effect.has("burn_duration") and effect.has("frost_ratio") and effect.has("combo_stun"), "Dual infusion must attach burn, slow, and stun.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "flame_imbue"))), "Flame must reach max level.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "frostburst_imbue"))), "Frost must gain a second level.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "frostburst_imbue"))), "Frost must reach max level.")
	var active_combos := game.get("run_state").temporary_buffs.get("active_infusions", []) as Array
	_expect(active_combos.has("thermal_shatter") and not active_combos.has("flame") and not active_combos.has("frost"), "Two max-level compatible Combo abilities must evolve into one slot.")
	_expect(active_combos.size() == 2, "Legacy infusion evolution must retain Rhythm plus Thermal Shatter.")
	_expect(
		not bool(game.call("_resolve_combo_card", database_card(game, "blood_pact_combo"))),
		"Blood Pact is now a direct reusable healing status, not a legacy infusion."
	)

	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	var enemy := (load("res://scenes/monsters/AutumnEnemy.tscn") as PackedScene).instantiate()
	var runner := CardEffectRunner.new()
	root.add_child(player)
	root.add_child(enemy)
	root.add_child(runner)
	await process_frame
	runner.cast(infused, player, [enemy])
	var status := enemy.call("get_status_snapshot") as Dictionary
	_expect(float(status.get("burn_remaining", 0.0)) > 0.0, "Flame infusion must apply burn.")
	_expect(float(status.get("slow_remaining", 0.0)) > 0.0, "Frost infusion must apply slow.")
	_expect(float(status.get("stun_remaining", 0.0)) > 0.0, "Dual infusion must briefly stun.")
	runner.queue_free()
	enemy.queue_free()
	player.queue_free()
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func database_card(game: Node, card_id: String) -> Dictionary:
	return (game.get("card_database") as CardDatabase).get_card(card_id)
