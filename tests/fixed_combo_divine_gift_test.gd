extends SceneTree

const GIFT_MANAGER_PATH := "res://scripts/systems/divine_gift_manager.gd"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Fixed Combo test requires the production catalog.")
	var deck := DeckManager.new(database)
	_expect(deck.has_method("start_fixed_hand"), "DeckManager must expose fixed four-card combat.")
	if deck.has_method("start_fixed_hand"):
		deck.call("start_fixed_hand", [
			"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		], 5.0)
		var original_hand := deck.hand.duplicate()
		var played := deck.play_from_hand(1, 3)
		_expect(not played.is_empty(), "An affordable fixed Combo must be playable.")
		_expect(
			deck.hand == original_hand
				and deck.draw_pile.is_empty()
				and deck.discard_pile.is_empty(),
			"Playing a fixed Combo must never draw, discard, rotate, or replace cards."
		)

	_expect(ResourceLoader.exists(GIFT_MANAGER_PATH), "Divine Gifts need one run-local authority.")
	if ResourceLoader.exists(GIFT_MANAGER_PATH):
		var gifts: RefCounted = (load(GIFT_MANAGER_PATH) as Script).new()
		_expect(bool(gifts.call("load_catalog")), "Divine Gift catalog must load.")
		_expect(bool(gifts.call("add_or_upgrade", "resonant_grace")), "A Divine Gift must enter the run.")
		gifts.call("add_or_upgrade", "resonant_grace")
		gifts.call("add_or_upgrade", "resonant_grace")
		gifts.call("add_or_upgrade", "echoing_will")
		gifts.call("add_or_upgrade", "echoing_will")
		gifts.call("add_or_upgrade", "echoing_will")
		var totals := gifts.call("get_global_effects") as Dictionary
		_expect(
			int(totals.get("combo_stack_bonus", 0)) > 0
				and float(totals.get("finisher_damage_multiplier", 1.0)) > 1.0,
			"Every Divine Gift must change both all Combo cards and the Finisher."
		)
		var fusion := gifts.call(
			"fuse_max_level",
			"resonant_grace",
			"echoing_will"
		) as Dictionary
		_expect(
			not fusion.is_empty()
				and String(fusion.get("kind", "")) == "evolved"
				and not gifts.call("has_gift", "resonant_grace")
				and not gifts.call("has_gift", "echoing_will"),
			"Two distinct maximum-level Divine Gifts must fuse into one evolved Gift."
		)

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game.has_method("_record_combo_formula"), "Game must record the three cards before a Finisher.")
	_expect(game.has_method("_build_formula_finisher"), "Game must assemble one named Finisher from the formula.")
	if game.has_method("_record_combo_formula") and game.has_method("_build_formula_finisher"):
		game.call("_begin_autumn_run", [
			"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		])
		(game.get("divine_gift_manager") as RefCounted).call(
			"add_or_upgrade",
			"resonant_grace"
		)
		var run := game.get("run_state") as RunState
		for card_id in ["flame_imbue", "echo_volley", "storm_charge"]:
			game.call("_record_combo_formula", database.get_card(card_id))
		_expect(
			bool(run.temporary_buffs.get("finisher_pending", false)),
			"Every third fixed-card use must prepare the next automatic Finisher."
		)
		var finisher := game.call(
			"_build_formula_finisher",
			database.get_card("ember_bolt")
		) as Dictionary
		var effect := finisher.get("effect", {}) as Dictionary
		_expect(
			String(finisher.get("name", "")).ends_with("天輪斷")
				and int(effect.get("amount", 0)) > int(
					(database.get_card("ember_bolt").get("effect", {}) as Dictionary).get(
						"amount",
						0
					)
				)
				and int(effect.get("projectile_count", 1)) > 1
				and float(effect.get("burn_duration", 0.0)) > 0.0,
			"The one Finisher must combine its base, preceding Combo formula, and global Gift layer."
		)
		var stacks_before := (
			run.temporary_buffs.get("persistent_combo_stacks", {}) as Dictionary
		).duplicate(true)
		game.call("_consume_finisher_formula")
		_expect(
			(run.temporary_buffs.get("persistent_combo_stacks", {}) as Dictionary)
				== stacks_before,
			"Using the Finisher must not consume persistent Combo stacks."
		)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: fixed Combo hand, formula Finisher, and global Divine Gifts")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
