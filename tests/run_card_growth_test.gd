extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])
	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	var original_ids: Array[String] = []
	var original_levels: Dictionary = {}
	for instance in run.card_instances:
		original_ids.append(instance.instance_id)
		original_levels[instance.instance_id] = instance.level

	game.call("_on_experience_collected", run.experience_required)
	await process_frame
	await process_frame
	var queue := game.get("growth_choice_queue") as GrowthChoiceQueue
	var level_page := queue.peek()
	_expect(
		game.get_open_ui("CardGrowthUI") != null
			and String(level_page.get("source", "")) == "experience",
		"Every level-up must open the Blessing choice page."
	)
	for choice_variant in level_page.get("choices", []) as Array:
		_expect(
			String((choice_variant as Dictionary).get("action", "")) == "divine_gift",
			"Level-up choices must be new or upgraded Blessings, never merges."
		)
	_expect(
		deck.hand.size() == 4
			and deck.draw_pile.is_empty()
			and deck.discard_pile.is_empty(),
		"Experience must not alter or rotate the fixed hand."
	)
	for instance in run.card_instances:
		_expect(
			original_ids.has(instance.instance_id)
				and instance.level == int(original_levels[instance.instance_id]),
			"Experience must not upgrade, replace, or fuse fixed cards."
		)

	var level_ui := game.get_open_ui("CardGrowthUI") as Control
	if level_ui != null:
		level_ui.call("confirm_selected_choice")
		await process_frame
	var gifts := game.get("divine_gift_manager") as RefCounted
	_expect(
		not (gifts.call("get_inventory") as Array).is_empty(),
		"Confirming a level-up must add one run-local Blessing."
	)

	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	await process_frame
	var gift_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(gift_ui != null, "Elite defeat must open an upgrade-or-merge Blessing choice.")
	var page := queue.peek()
	_expect(
		String(page.get("source", "")) == "elite"
			and not (page.get("choices", []) as Array).is_empty(),
		"Elite loot must contain owned Blessing upgrades or merges."
	)
	for choice_variant in page.get("choices", []) as Array:
		_expect(
			String((choice_variant as Dictionary).get("action", "")) in [
				"divine_gift", "divine_fusion",
			],
			"Elite loot must not grant a brand-new Blessing."
		)
	if gift_ui != null:
		gift_ui.call("confirm_selected_choice")
		await process_frame
	var timeline_director := SurvivalWaveDirector.new()
	timeline_director.name = "AutumnRunDirector"
	game.get("current_map").add_child(timeline_director)
	timeline_director.set("_elite_defeat_count", 1)
	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	await process_frame
	_expect(
		String(queue.peek().get("source", "")) == "elite",
		"A later Elite event number must enqueue another elite loot page in the same countdown."
	)
	var later_elite_ui := game.get_open_ui("CardGrowthUI") as Control
	if later_elite_ui != null:
		later_elite_ui.call("confirm_selected_choice")
		await process_frame
	var added_boss_fixture := false
	for reward_variant in gifts.call("get_reward_choices", 20) as Array:
		var reward := reward_variant as Dictionary
		if int(reward.get("level", 0)) == 0:
			added_boss_fixture = bool(gifts.call(
				"add_or_upgrade", String(reward.get("gift_id", ""))
			))
			break
	_expect(added_boss_fixture, "Boss loot fixture must own an unfinished Blessing.")
	game.call("_on_survival_boss_defeated", Vector2.ZERO, false)
	await process_frame
	await process_frame
	_expect(
		String(queue.peek().get("source", "")) == "boss",
		"Every defeated boss must enqueue an upgrade-or-merge Blessing loot page."
	)
	var gold_before := run.gold_earned
	var wood_before := int(run.materials_earned.get("autumn_wood", 0))
	game.call("_on_reward_bag_collected", &"money", {"gold": 9})
	game.call("_on_reward_bag_collected", &"material", {"autumn_wood": 2})
	_expect(
		run.gold_earned == gold_before + 9
			and int(run.materials_earned.get("autumn_wood", 0)) == wood_before + 2,
		"Collected money and monster-material bags must enter the run reward summary."
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: EXP awards Blessings while elite loot upgrades or merges them")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
