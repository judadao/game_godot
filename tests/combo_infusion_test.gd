extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	var deck := game.get("deck_manager") as DeckManager
	var complete_deck: Array = deck.hand + deck.draw_pile + deck.discard_pile
	_expect(complete_deck.has("flame_imbue") and complete_deck.has("frostburst_imbue"), "Combo cards must be shuffled into the ordinary combat deck.")
	_expect(deck.hand.size() == 8, "Combat must draw two switchable groups of four cards.")

	deck.start(["flame_imbue", "flame_imbue", "frostburst_imbue", "battle_rhythm"], 5.0)
	var flame := deck.play_from_hand(0)
	_expect(not flame.is_empty() and is_equal_approx(deck.energy, 2.0), "Flame Imbue must be an ordinary three-AP hand play.")
	_expect(bool(game.call("_resolve_combo_card", flame)), "Playing Flame Imbue must activate its persistent infusion.")
	_expect(deck.exhaust_pile.has("flame_imbue") and not deck.discard_pile.has("flame_imbue"), "A played Combo card must exhaust instead of entering the draw cycle.")
	deck.energy = 5.0
	var second_flame := deck.play_from_hand(0)
	_expect(bool(game.call("_resolve_combo_card", second_flame)), "A duplicate Combo card must add another stack.")
	var frost := deck.play_from_hand(0)
	_expect(frost.is_empty(), "An unaffordable Combo card must remain in hand.")
	deck.energy = 5.0
	frost = deck.play_from_hand(0)
	_expect(bool(game.call("_resolve_combo_card", frost)), "Playing Frostburst Imbue must activate its persistent infusion.")
	var rhythm := deck.play_from_hand(0)
	_expect(bool(game.call("_resolve_combo_card", rhythm)), "Non-element Combo cards must also resolve run buffs.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "stoneguard_combo"))), "A fourth distinct Combo ability must fit.")
	_expect(not bool(game.call("_resolve_combo_card", database_card(game, "blood_pact_combo"))), "A fifth distinct Combo ability must be rejected.")

	var database := game.get("card_database") as CardDatabase
	var base := database.get_card("ember_bolt")
	var infused := game.call("_apply_combo_infusions_to_card", base) as Dictionary
	var effect := infused.get("effect", {}) as Dictionary
	_expect(int(effect.get("amount", 0)) == int((base.get("effect", {}) as Dictionary).get("amount", 0)) + 14, "Stacked Combo infusions and rhythm buffs must all add damage.")
	_expect(effect.has("burn_duration") and effect.has("frost_ratio") and effect.has("combo_stun"), "Dual infusion must attach burn, slow, and stun.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "flame_imbue"))), "Flame must reach max level.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "frostburst_imbue"))), "Frost must gain a second level.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "frostburst_imbue"))), "Frost must reach max level.")
	var active_combos := game.get("run_state").temporary_buffs.get("active_infusions", []) as Array
	_expect(active_combos.has("thermal_shatter") and not active_combos.has("flame") and not active_combos.has("frost"), "Two max-level compatible Combo abilities must evolve into one slot.")
	_expect(active_combos.size() == 3, "Combo evolution must free one of the four ability slots.")
	_expect(bool(game.call("_resolve_combo_card", database_card(game, "blood_pact_combo"))), "A new Combo ability must fit after evolution frees a slot.")

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
