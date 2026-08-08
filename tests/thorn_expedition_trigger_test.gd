extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const DECK_BUILDER_SCENE := preload("res://scenes/ui/cards/DeckBuilderUI.tscn")
const THORN_BASIC_ID := "ancient_roots_pursuit"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("development/force_dev_mode_in_tests", true)
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var meta := game.get("meta_state") as MetaState
	var manager := game.get("skill_recipe_manager") as SkillRecipeManager
	_expect(
		meta.active_skill_ids.is_empty(),
		"Dev mode may unlock every skill, but must not silently activate every recipe before expedition selection."
	)
	var builder := DECK_BUILDER_SCENE.instantiate() as Control
	root.add_child(builder)
	await process_frame
	var cards := (game.get("card_database") as CardDatabase).get_all_cards()
	builder.call("configure", cards, [
		"blood_pact_combo", "healing_light", "renewal", "verdant_renewal",
	], "ember_bolt", meta.active_skill_ids)
	_expect(
		not (builder.call("get_selected_skill_recipe_ids") as Array).has(THORN_BASIC_ID),
		"Opening the expedition builder must not preselect Thorn merely because dev mode unlocked it."
	)
	_expect(
		bool(builder.call("choose_skill_recipe", THORN_BASIC_ID)),
		"The expedition selector must allow the basic Thorn recipe."
	)
	var selected_skills := builder.call("get_selected_skill_recipe_ids") as Array
	_expect(
		selected_skills == [THORN_BASIC_ID],
		"The deck builder must retain the selected Thorn recipe until confirmation."
	)
	var selected_deck := builder.call("get_selected_deck") as Array[String]
	game.call(
		"_on_loadout_confirmed",
		selected_deck,
		"ember_bolt",
		builder,
		"",
		&""
	)
	_expect(
		meta.active_skill_ids == [THORN_BASIC_ID],
		"Confirming an expedition must persist the selected Thorn recipe as active."
	)
	_expect(
		manager.get_active_ids() == [THORN_BASIC_ID],
		"The production skill matcher must activate the confirmed Thorn recipe immediately."
	)
	var thorn_skill := manager.get_skill(THORN_BASIC_ID)
	var routes := thorn_skill.get("combo_routes", []) as Array
	var route := routes[0] as Array if not routes.is_empty() else []
	game.call("_begin_autumn_run", selected_deck)
	await process_frame
	var deck := game.get("deck_manager") as DeckManager
	deck.energy = deck.max_energy
	for card_id_variant in route:
		var card_id := String(card_id_variant)
		var slot_index := -1
		for index in deck.hand_instances.size():
			if deck.hand_instances[index].card_id == card_id:
				slot_index = index
				break
		_expect(slot_index >= 0, "The selected Thorn route card must remain in the live expedition hand: %s" % card_id)
		if slot_index >= 0:
			var projected := game.call("_card_for_cast", deck.hand_instances[slot_index]) as Dictionary
			var cost := float(projected.get("cost", 0.0))
			var waited := 0.0
			while deck.energy < cost and waited < 3.0:
				game.call("_process", 0.05)
				waited += 0.05
			game.call("_on_card_selected", slot_index)
			await process_frame
	var queue := (game.get("run_state") as RunState).temporary_buffs.get("finisher_queue", []) as Array
	var matched_thorn := queue.any(func(candidate: Variant) -> bool:
		return candidate is Dictionary and String((candidate as Dictionary).get("id", "")) == THORN_BASIC_ID
	)
	_expect(
		matched_thorn,
		"The confirmed expedition loadout must queue Thorn after its real cards are played in combat."
	)
	game.queue_free()
	builder.queue_free()
	await process_frame
	ProjectSettings.set_setting("development/force_dev_mode_in_tests", false)
	if _failures == 0:
		print("PASS: expedition confirmation activates and queues the selected Thorn recipe")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
