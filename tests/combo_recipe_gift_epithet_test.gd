extends SceneTree

const RECIPE_CATALOG_PATH := "res://scripts/systems/combo_finisher_catalog.gd"

class DamageTarget:
	extends Node2D

	var health := 1000
	var statuses: Array[String] = []

	func take_damage(amount: int) -> int:
		var dealt := mini(health, maxi(0, amount))
		health -= dealt
		return dealt

	func apply_status(status_id: String, _effect: Dictionary) -> void:
		statuses.append(status_id)


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ResourceLoader.exists(RECIPE_CATALOG_PATH),
		"Three-skill finishers need one authoritative recipe catalog."
	)
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])
	var database := game.get("card_database") as CardDatabase
	var run := game.get("run_state") as RunState

	game.call("_record_combo_formula", database.get_card("healing_light"))
	var healing_history := run.temporary_buffs.get("combo_formula_history", []) as Array
	_expect(
		healing_history.size() == 1
			and String((healing_history[0] as Dictionary).get("id", "")) == "healing_light",
		"Healing must enter and preserve its position in the ordered three-card formula."
	)

	for _repeat in 3:
		game.call("_record_combo_formula", database.get_card("echo_volley"))
	var queue := run.temporary_buffs.get("finisher_queue", []) as Array
	_expect(
		queue.size() == 1
			and String((queue[0] as Dictionary).get("recipe_id", ""))
				== "thousand_blade_kill",
		"Echo Volley three times must match the learned Thousand Blade Kill recipe."
	)
	for _repeat in 3:
		game.call("_record_combo_formula", database.get_card("storm_charge"))
	_expect(
		(run.temporary_buffs.get("finisher_queue", []) as Array).size() == 2,
		"Two completed recipes must queue without overwriting each other."
	)

	var gifts := game.get("divine_gift_manager") as RefCounted
	gifts.call("add_or_upgrade", "eternal_memory")
	var finisher := game.call(
		"_build_formula_finisher",
		database.get_card("ember_bolt")
	) as Dictionary
	_expect(
		String(finisher.get("name", "")) == "絕對零度的千羽相應",
		"The ice Gift must transform 千羽相應 while preserving the stable recipe identity."
	)
	var finisher_effect := finisher.get("effect", {}) as Dictionary
	_expect(
		float(finisher_effect.get("frost_duration", 0.0)) > 0.0
			and bool(finisher_effect.get("shatter", false)),
		"The ice epithet must add freezing and shatter mechanics, not only damage."
	)
	var target := DamageTarget.new()
	root.add_child(target)
	var resolution := (game.get("card_effect_runner") as CardEffectRunner).cast(
		finisher,
		game.get("player"),
		[target]
	)
	_expect(
		target.statuses.has("slow")
			and int(resolution.get("mutation_damage", 0)) > 0,
		"Absolute Zero must actually slow and shatter targets during combat."
	)
	target.queue_free()
	game.call("_consume_finisher_formula")
	_expect(
		(run.temporary_buffs.get("finisher_queue", []) as Array).size() == 1,
		"Releasing one automatic Finisher must leave later queued Finishers intact."
	)

	var locked_meta := game.get("meta_state") as MetaState
	locked_meta.unlocked_cards.erase("flame_imbue")
	run.temporary_buffs["combo_formula_history"] = []
	run.temporary_buffs["finisher_queue"] = []
	for card_id in ["flame_imbue", "echo_volley", "storm_charge"]:
		game.call("_record_combo_formula", database.get_card(card_id))
	_expect(
		(run.temporary_buffs.get("finisher_queue", []) as Array).is_empty(),
		"A recipe cannot release when one required Combo skill is not learned."
	)

	game.get("growth_choice_queue").clear()
	game.call("_on_elite_defeated", Vector2.ZERO)
	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	_expect(
		(game.get("growth_choice_queue") as GrowthChoiceQueue).size() == 1,
		"One stage may enqueue at most one mandatory Divine Gift page."
	)

	var fusion_manager := DivineGiftManager.new()
	_expect(fusion_manager.load_catalog(), "Divine Gift catalog must load.")
	for gift_id in ["eternal_memory", "echoing_will"]:
		for _level in 3:
			fusion_manager.add_or_upgrade(gift_id)
	var evolved := fusion_manager.fuse_max_level(
		"eternal_memory",
		"echoing_will"
	)
	var offered_ids: Array[String] = []
	for choice in fusion_manager.get_reward_choices(20):
		offered_ids.append(String(choice.get("gift_id", "")))
	_expect(
		not evolved.is_empty()
			and not offered_ids.has("eternal_memory")
			and not offered_ids.has("echoing_will"),
		"Ascended Gift components must permanently leave this Run's reward pool."
	)

	paused = false
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: learned recipes, queued Finishers, Gift epithets, and finite rewards")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
