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
	_expect(_has_property(game, "skill_recipe_manager"), "Game must own the passive SkillRecipeManager.")
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
	var skill_triggers: Array[Dictionary] = []
	for index in 5:
		skill_triggers = skill_manager.record_card(attack)
	game.call("_resolve_skill_triggers", skill_triggers)
	var player := game.get("player") as Node
	var statuses := player.call("get_combat_status_projection") as Array
	_expect(statuses.any(
		func(status: Dictionary) -> bool:
			return String(status.get("source_id", "")) == "iron_momentum"
	), "Five attacks must apply Iron Momentum weak super armor.")
	var toast_stack := (game.get("hud") as Control).get_node("TopCenterStack/SkillToastStack")
	_expect(toast_stack.get_child_count() == 1, "Triggered skill must show one temporary HUD toast.")

	deck.start(run.card_instances, run.max_energy, false)
	var guard_index := -1
	for index in deck.hand_instances.size():
		if deck.hand_instances[index].card_id == "guard":
			guard_index = index
			break
	_expect(guard_index >= 0, "Deterministic test hand must contain Iron Will.")
	if guard_index >= 0:
		deck.play_from_hand(guard_index)
		game.call("_refresh_cooldown_display")
		var cooldown_rows := (game.get("hud") as Control).get_node("BottomStage/CardStage/CooldownStrip/CooldownMargin/CooldownRows")
		_expect(cooldown_rows.get_child_count() == 1 and "Iron Will" in String(cooldown_rows.get_child(0).text), "Played cooldown card must appear in the HUD cooldown strip.")
	run.add_experience(run.experience_required)
	game.call("_enqueue_experience_growth")
	run.add_experience(run.experience_required)
	game.call("_enqueue_experience_growth")
	_expect(
		(game.get("growth_choice_queue") as GrowthChoiceQueue).size() == 1,
		"Pending EXP levels must project one fresh page at a time instead of queuing stale choices."
	)
	await process_frame
	await process_frame
	var growth_ui: Control = game.get_open_ui("CardGrowthUI") as Control
	_expect(growth_ui != null, "Pending EXP growth must open the unified CardGrowthUI.")
	_expect(paused, "CardGrowthUI must pause gameplay.")
	_expect(growth_ui.process_mode == Node.PROCESS_MODE_ALWAYS, "Growth UI must remain interactive while gameplay is paused.")
	var cooldown_before := float(deck.cooldown_pile[0].get("remaining_seconds", 0.0))
	var status_before := float((player.call("get_combat_status_projection") as Array)[0].get("remaining_seconds", 0.0))
	await create_timer(0.12, true, false, true).timeout
	_expect(
		is_equal_approx(float(deck.cooldown_pile[0].get("remaining_seconds", 0.0)), cooldown_before),
		"Card cooldowns must freeze while growth modal owns pause."
	)
	_expect(
		is_equal_approx(float((player.call("get_combat_status_projection") as Array)[0].get("remaining_seconds", 0.0)), status_before),
		"Combat status timers must freeze while growth modal owns pause."
	)
	var page := (game.get("growth_choice_queue") as GrowthChoiceQueue).peek()
	var first_choice := (page.get("choices", []) as Array)[0] as Dictionary
	var selected_instance := run.get_card_instance(String(first_choice.get("instance_id", "")))
	var selected_level_before := selected_instance.level if selected_instance != null else -1
	game.set("save_service", FailingSaveService.new())
	growth_ui.call("select_choice", String(first_choice.get("choice_id", "")))
	growth_ui.call("confirm_selected_choice")
	await process_frame
	await process_frame
	_expect(paused and game.get_open_ui("CardGrowthUI") == growth_ui, "A failed permanent save must keep the growth modal open.")
	_expect((game.get("growth_choice_queue") as GrowthChoiceQueue).size() == 1, "A failed permanent save must not consume the queued page.")
	_expect(run.pending_level_ups == 2, "A failed permanent save must not consume pending EXP levels.")
	if selected_instance != null:
		_expect(selected_instance.level == selected_level_before, "A failed permanent save must roll back the selected CardInstance level.")
	game.set("save_service", SaveService.new())
	growth_ui.call("confirm_selected_choice")
	await process_frame
	await process_frame
	_expect(paused, "Resolving the first of multiple pending levels must immediately open the next paused page.")
	_expect(run.pending_level_ups == 1, "A successful retry must consume exactly one pending level.")
	paused = false
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Game card instances, Skill, growth queue, and single Autumn HUD authority")
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
