extends SceneTree

var _failures := 0


class FailingSaveService:
	extends SaveService

	func save_meta(_path: String, _data: Dictionary) -> bool:
		return false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(_has_property(game, "skill_recipe_manager"), "Game must own the skill-series catalog boundary.")
	_expect(_has_property(game, "growth_choice_queue"), "Game must own the sole GrowthChoiceQueue.")
	_expect(
		_has_property(game, "card_collection_service"),
		"Game must compose the sole cross-authority CardCollectionService."
	)
	_expect(game.has_method("_open_next_growth_choice"), "Game must project queued growth through CardGrowthUI.")
	_expect(game.has_method("_apply_growth_resolution"), "Game must resolve growth choices by instance id.")
	for legacy_method in [
		"_build_level_up_choices",
		"_on_level_up_choice",
		"_apply_level_up_choice",
		"_merge_card_at_campfire",
		"_upgrade_card_at_campfire",
		"_try_evolve_card",
		"_show_campfire_card_choices",
		"_on_card_reward_selected",
		"_apply_card_reward",
	]:
		_expect(not game.has_method(legacy_method), "Removed legacy growth entry must stay absent: %s." % legacy_method)
	game.call("_begin_autumn_run")
	game.call(
		"load_current_map",
		load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	)
	await process_frame
	await process_frame
	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	_expect(run.active, "Autumn expedition must start.")
	_expect(not run.card_instances.is_empty(), "Run must use card instances.")
	_expect(deck.get_all_instances().size() == run.card_instances.size(), "Deck and run must contain the same instance count.")
	for run_instance in run.card_instances:
		var deck_instance := deck.find_instance(run_instance.instance_id)
		_expect(deck_instance == run_instance, "Deck and run must share exact CardInstance objects.")
	var embedded_hand := game.get("hud").get_node_or_null("BottomStage/CardStage/AutumnCardHandUI") as Control
	_expect(embedded_hand != null, "Autumn HUD must own the embedded hand renderer.")
	_expect(game.get("card_hand_ui") == embedded_hand, "Game must bind to the embedded renderer instead of creating a duplicate hand.")
	_expect(game.get_open_ui("LevelUpUI") == null, "Legacy LevelUpUI must not be opened.")
	var skill_manager := game.get("skill_recipe_manager") as SkillRecipeManager
	var attack := (game.get("card_database") as CardDatabase).get_card("ember_bolt")
	var skill_triggers := skill_manager.record_card(attack)
	game.call("_resolve_skill_triggers", skill_triggers)
	var player := game.get("player") as Node
	var statuses := player.call("get_combat_status_projection") as Array
	_expect(not statuses.any(
		func(status: Dictionary) -> bool:
			return String(status.get("source_id", "")) == "iron_momentum"
	), "Retired Iron Momentum must not remain an invisible combat trigger.")
	var toast_stack := (game.get("hud") as Control).get_node(
		"BottomStage/ActivityFeed/FeedMargin/FeedRows/SkillToastStack"
	)
	_expect(toast_stack.get_child_count() == 0, "Retired passive skills must not create HUD toasts.")
	_expect(skill_manager.get_all_series().size() == 13, "Game must load all 13 new skill series.")

	var fixed_ids := deck.hand.duplicate()
	deck.energy = deck.max_energy
	game.call("_on_card_selected", 0)
	_expect(
		deck.hand == fixed_ids
			and deck.draw_pile.is_empty()
			and deck.discard_pile.is_empty(),
		"Combat skills must spend AP while remaining in their fixed slots."
	)
	game.call("_on_experience_collected", run.experience_required)
	await process_frame
	await process_frame
	_expect(
		game.get_open_ui("CardGrowthUI") != null,
		"Every EXP level must open the Blessing growth modal."
	)
	var level_page := (game.get("growth_choice_queue") as GrowthChoiceQueue).peek()
	var level_only := true
	for choice_variant in level_page.get("choices", []) as Array:
		level_only = level_only and String((choice_variant as Dictionary).get("action", "")) == "divine_gift"
	_expect(level_only, "EXP growth must offer only new or upgraded Blessings.")
	(game.get_open_ui("CardGrowthUI") as Control).call("confirm_selected_choice")
	await process_frame
	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	await process_frame
	var growth_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(growth_ui != null and paused, "Elite Divine Gift choice must own the paused growth modal.")
	var page := (game.get("growth_choice_queue") as GrowthChoiceQueue).peek()
	var divine_only := true
	for choice_variant in page.get("choices", []) as Array:
		var choice := choice_variant as Dictionary
		divine_only = (
			divine_only
			and String(choice.get("action", "")).begins_with("divine_")
		)
	_expect(
		String(page.get("source", "")) == "elite"
			and divine_only,
		"Elite loot must offer only Blessing upgrade or fusion actions."
	)
	paused = false
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: fixed card instances, Skill, Divine Gift queue, and single Autumn HUD authority")
	quit(1 if _failures > 0 else 0)


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
