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
		_expect(
			is_equal_approx(
				float(totals.get("finisher_damage_multiplier", 1.0)),
				1.35 * 1.25
			),
			"Different Divine Gift fields must stack directly in the same Run."
		)
		var fusion := gifts.call(
			"fuse_max_level",
			"resonant_grace",
			"echoing_will"
		) as Dictionary
		_expect(
			not fusion.is_empty()
				and String(fusion.get("kind", "")) == "evolved"
				and int(fusion.get("max_level", 0)) == 3
				and not String(fusion.get("accent_color", "")).is_empty()
				and not gifts.call("has_gift", "resonant_grace")
				and not gifts.call("has_gift", "echoing_will"),
			"Two maximum-level Gifts must fuse into a new colored Gift that can keep leveling."
		)
		var evolved_id := String(fusion.get("id", ""))
		var level_one_effects := (fusion.get("effects", {}) as Dictionary).duplicate(true)
		var evolved_reward_choices := gifts.call("get_reward_choices", 20) as Array
		var evolved_offered := false
		for choice in evolved_reward_choices:
			if (
				String(choice.get("gift_id", "")) == evolved_id
				and String(choice.get("kind", "")) == "evolved"
			):
				evolved_offered = true
		_expect(
			evolved_offered,
			"An evolved Gift below maximum level must return to later blessing choices."
		)
		var gift_queue := GrowthChoiceQueue.new()
		_expect(
			gift_queue.enqueue_divine_gifts(evolved_reward_choices, []),
			"Evolved blessing upgrades must be presentable by the in-run choice queue."
		)
		var queued_choices := (gift_queue.peek().get("choices", []) as Array)
		var queued_evolved_colored := false
		for choice in queued_choices:
			if (
				String(choice.get("gift_id", "")) == evolved_id
				and String(choice.get("card_color", "")) == "prismatic"
			):
				queued_evolved_colored = true
		_expect(
			queued_evolved_colored,
			"Evolved blessing choices must project their new prismatic color identity."
		)
		_expect(
			bool(gifts.call("add_or_upgrade", evolved_id))
				and bool(gifts.call("add_or_upgrade", evolved_id)),
			"An evolved Gift must continue upgrading from Lv.1 to Lv.3."
		)
		var evolved_max := gifts.call("get_gift", evolved_id) as Dictionary
		var evolved_effects := evolved_max.get("effects", {}) as Dictionary
		var evolved_mutations := evolved_max.get("finisher_mutations", {}) as Dictionary
		_expect(
			int(evolved_max.get("level", 0)) == 3
				and float(evolved_effects.get("finisher_damage_multiplier", 1.0))
					> float(level_one_effects.get("finisher_damage_multiplier", 1.0))
				and bool(evolved_mutations.get("final_burst", false))
				and bool(evolved_mutations.get("chain_lightning", false))
				and bool(evolved_mutations.get("death_spread", false)),
			"Evolved levels must retain inherited power and add executable spectacle buffs."
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
