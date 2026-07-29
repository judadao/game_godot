extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cards := CardDatabase.new()
	_expect(cards.load_catalog(), "Card content must load.")
	_expect(cards.get_all_cards().size() == 38, "Vertical slice must ship 38 practical cards.")
	var card_ids := {}
	var represented_types := {}
	for card in cards.get_all_cards():
		card_ids[String(card["id"])] = true
		represented_types[String(card["type"]).to_lower()] = true
		_expect(ResourceLoader.exists(String(card["icon_path"])), "Every card icon path must resolve.")
		if String(card.get("type", "")) == "combo":
			var combo_effect := card.get("effect", {}) as Dictionary
			if String(combo_effect.get("kind", "")) == "infusion":
				_expect(
					is_equal_approx(float(combo_effect.get("combo_duration", 0.0)), 1.5),
					"Every timed Combo infusion must use the 1.5-second base duration."
				)
			for status_variant in combo_effect.get("statuses", []) as Array:
				if status_variant is Dictionary:
					_expect(
						is_equal_approx(
							float((status_variant as Dictionary).get("duration", 0.0)),
							1.5
						),
						"Every timed Combo status must use the 1.5-second base duration."
					)
	for required_type in ["attack", "skill", "power", "healing", "status", "ultimate", "combo"]:
		_expect(represented_types.has(required_type), "Card catalog must represent %s." % required_type)

	var evolutions := EvolutionManager.new(cards)
	_expect(evolutions.load_recipes(), "Evolution content must load.")
	_expect(evolutions.get_all_recipes().size() == 6, "Vertical slice must ship six card fusion recipes.")
	for recipe in evolutions.get_all_recipes():
		_expect(card_ids.has(String(recipe["left_card_id"])), "Fusion left material card must exist.")
		_expect(card_ids.has(String(recipe["right_card_id"])), "Fusion right material card must exist.")
		_expect(card_ids.has(String(recipe["result_card_id"])), "Fusion result card must exist.")

	var finishers := ComboFinisherCatalog.new()
	_expect(finishers.load_catalog(), "Combo Finisher content must load.")
	_expect(
		finishers.get_all_recipes().size() == 5,
		"Vertical slice must ship five learned three-Combo Finisher recipes."
	)
	for finisher in finishers.get_all_recipes():
		_expect(
			(finisher.get("sequence", []) as Array).size() == 3,
			"Every Finisher must use one exact three-Combo sequence."
		)
		for skill_id in finisher.get("required_skills", []):
			_expect(
				card_ids.has(String(skill_id)),
				"Every Finisher required skill must exist in the card catalog."
			)

	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "Divine Gift content must load.")
	_expect(
		gifts.get_reward_choices(20).size() == 6,
		"Vertical slice must ship six Run-local Divine Gifts."
	)

	var inventory_script := load("res://scripts/systems/inventory_manager.gd")
	var inventory: RefCounted = inventory_script.new()
	var equipment_catalog := inventory.call("get_equipment_catalog") as Array
	_expect(equipment_catalog.size() == 10, "Vertical slice must ship ten fixed equipment items.")
	for item_variant in equipment_catalog:
		var item := item_variant as Dictionary
		_expect(not (item.get("effects", {}) as Dictionary).is_empty(), "Equipment must provide attributes.")
		_expect(not (item.get("special_ability", {}) as Dictionary).is_empty(), "Equipment must provide a special ability.")
	_expect(
		inventory.call("get_resource_ids") == [&"gold", &"autumn_wood", &"stone", &"magic_shard", &"autumn_core"],
		"Economy must expose the five specified permanent resources."
	)
	for action in ["move_left", "move_right", "jump", "dash", "interact", "card_focus", "pause", "redraw_hand"]:
		_expect(InputMap.has_action(action), "Required input action '%s' must exist." % action)
	for removed_action in ["attack", "skill", "use_hp_potion", "use_mp_potion"]:
		_expect(not InputMap.has_action(removed_action), "Legacy combat action '%s' must be removed." % removed_action)
	var expected_keys := [KEY_Q, KEY_W, KEY_E, KEY_R]
	var expected_buttons := [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_A, JOY_BUTTON_B]
	for index in 4:
		var action := "card_slot_%d" % (index + 1)
		_expect(InputMap.has_action(action), "Project must define %s." % action)
		if not InputMap.has_action(action):
			continue
		var has_key := false
		var has_button := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == expected_keys[index]:
				has_key = true
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == expected_buttons[index]:
				has_button = true
		_expect(has_key and has_button, "%s must map its keyboard key and joypad face button." % action)
	for scene_path in [
		"res://scenes/game/game.tscn",
		"res://scenes/maps/town.tscn",
		"res://scenes/maps/battle_portal_hub.tscn",
		"res://scenes/maps/autumn_forest.tscn",
		"res://scenes/monsters/AutumnEnemy.tscn",
		"res://scenes/monsters/AutumnGuardian.tscn",
		"res://scenes/ui/cards/CardHandUI.tscn",
		"res://scenes/ui/town/TownEternalForgeHUD.tscn",
		"res://scenes/ui/town/TownCardHandUI.tscn",
		"res://scenes/maps/town/portals/TownBattleGateway.tscn",
		"res://scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn",
		"res://scenes/ui/town/MaterialYardUI.tscn",
		"res://scenes/ui/town/PlayerBlacksmithUI.tscn",
		"res://scenes/ui/town/TownHallUI.tscn",
		"res://scenes/ui/town/TownResidenceUI.tscn",
		"res://scenes/ui/results/RunResultUI.tscn",
		"res://scenes/ui/cards/DeckBuilderUI.tscn",
		"res://scenes/ui/cards/CardDiscardUI.tscn",
		"res://scenes/ui/cards/CardGrowthUI.tscn",
		"res://scenes/combat/ExperienceGem.tscn",
	]:
		_expect(ResourceLoader.exists(scene_path), "Required scene must exist: %s" % scene_path)
	var forest := (load("res://scenes/maps/autumn_forest.tscn") as PackedScene).instantiate()
	root.add_child(forest)
	await process_frame
	_expect(forest.has_node("AutumnRunDirector"), "Autumn Forest must contain its complete run director.")
	_expect((forest.get_node("AutumnRunDirector") as EncounterDirector).build_autumn_run_plan().size() == 5, "Autumn run must contain five escalating waves.")
	forest.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
