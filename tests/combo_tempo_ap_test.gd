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

	_expect(game.has_method("_apply_card_tempo"), "Game must reward sustained low-cost card play with AP tempo.")
	_expect(game.has_method("_tick_card_tempo"), "Game must expose deterministic AP tempo expiry.")
	_expect(game.has_method("_get_card_tempo_regen_bonus"), "Game must expose the AP regeneration earned from tempo.")
	if (
		not game.has_method("_apply_card_tempo")
		or not game.has_method("_tick_card_tempo")
		or not game.has_method("_get_card_tempo_regen_bonus")
	):
		game.queue_free()
		await process_frame
		quit(1)
		return

	var deck := game.get("deck_manager") as DeckManager
	var database := game.get("card_database") as CardDatabase
	var run := game.get("run_state") as RunState
	deck.energy = 0.0

	var one_ap_refund := float(game.call("_apply_card_tempo", database.get_card("energy_surge")))
	_expect(is_equal_approx(one_ap_refund, 0.35), "A one-AP card must immediately refund 0.35 AP.")
	_expect(is_equal_approx(deck.energy, 0.35), "The one-AP tempo refund must reach the live deck energy.")
	_expect(int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 2, "A one-AP card must build two tempo stacks.")

	var two_ap_refund := float(game.call("_apply_card_tempo", database.get_card("iron_skin")))
	_expect(is_equal_approx(two_ap_refund, 0.15), "A two-AP card must immediately refund 0.15 AP.")
	_expect(int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 3, "A two-AP card must build one tempo stack.")

	for _index in 5:
		game.call("_apply_card_tempo", database.get_card("guard"))
	_expect(int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 8, "Tempo must cap at eight stacks.")
	_expect(
		is_equal_approx(float(game.call("_get_card_tempo_regen_bonus")), 0.96),
		"Eight tempo stacks must add 0.96 AP per second."
	)

	var energy_before_heavy := deck.energy
	var heavy_refund := float(game.call("_apply_card_tempo", database.get_card("ascendant_combo")))
	_expect(is_zero_approx(heavy_refund), "A three-AP power card must not refund AP.")
	_expect(is_equal_approx(deck.energy, energy_before_heavy), "A power card must not change AP after its normal cost is paid.")
	_expect(int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 4, "A three-AP power card must spend four tempo stacks.")

	var discounted_heavy := database.get_card("ascendant_combo")
	discounted_heavy["cost"] = 2
	game.call("_apply_card_tempo", discounted_heavy)
	_expect(
		int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 0,
		"A discounted power card must still be classified by its catalog cost."
	)

	game.call("_apply_card_tempo", database.get_card("guard"))
	game.call("_tick_card_tempo", 6.1)
	_expect(int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 0, "Tempo must expire when the player stops playing cards.")
	_expect(is_zero_approx(float(game.call("_get_card_tempo_regen_bonus"))), "Expired tempo must stop increasing AP regeneration.")

	deck.start(["guard", "guard", "guard", "guard"], 5.0)
	deck.energy = 2.0
	game.call("_on_card_selected", 0)
	_expect(
		is_equal_approx(deck.energy, 0.15)
			and int(run.temporary_buffs.get("card_tempo_stacks", 0)) == 1,
		"Playing a basic Combo through the combat hand must spend AP, refund tempo AP, and build tempo."
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: low-cost card tempo rewards sustained play without enabling power-card spam")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
