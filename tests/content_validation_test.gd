extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cards := CardDatabase.new()
	_expect(cards.load_catalog(), "Card content must load.")
	_expect(cards.get_all_cards().size() == 24, "Vertical slice must ship 24 practical cards.")
	var card_ids := {}
	var represented_types := {}
	for card in cards.get_all_cards():
		card_ids[String(card["id"])] = true
		represented_types[String(card["type"]).to_lower()] = true
		_expect(ResourceLoader.exists(String(card["icon_path"])), "Every card icon path must resolve.")
	for required_type in ["attack", "utility", "healing", "power", "summon", "status", "ultimate", "combo"]:
		_expect(represented_types.has(required_type), "Card catalog must represent %s." % required_type)
	_expect(not represented_types.has("defense"), "Defense must no longer be a player card type.")
	_expect(not represented_types.has("skill"), "Skill is reserved for passive attack-sequence recipes.")

	var evolutions := EvolutionManager.new(cards)
	_expect(evolutions.load_recipes(), "Fusion content must load.")
	_expect(evolutions.get_all_recipes().size() == 6, "Vertical slice must ship six fusions.")
	for recipe in evolutions.get_all_recipes():
		for material_id in recipe["material_card_ids"]:
			_expect(card_ids.has(String(material_id)), "Fusion material card must exist.")
		_expect(card_ids.has(String(recipe["result_card_id"])), "Fusion result card must exist.")

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
	for action in ["move_left", "move_right", "jump", "dash", "interact", "card_focus", "pause", "redraw_hand", "card_group_1", "card_group_2"]:
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
		"res://scenes/maps/autumn_forest.tscn",
		"res://scenes/monsters/AutumnEnemy.tscn",
		"res://scenes/monsters/AutumnGuardian.tscn",
		"res://scenes/ui/CardHandUI.tscn",
		"res://scenes/ui/TownProgressUI.tscn",
		"res://scenes/ui/RunResultUI.tscn",
		"res://scenes/ui/DeckBuilderUI.tscn",
		"res://scenes/ui/CardDiscardUI.tscn",
		"res://scenes/ui/CardGrowthUI.tscn",
		"res://scenes/combat/ExperienceGem.tscn",
	]:
		_expect(ResourceLoader.exists(scene_path), "Required scene must exist: %s" % scene_path)
	for obsolete_growth_path in [
		"res://scenes/ui/LevelUpUI.tscn",
		"res://scripts/ui/level_up_ui.gd",
	]:
		_expect(not ResourceLoader.exists(obsolete_growth_path), "Obsolete growth content must be removed: %s" % obsolete_growth_path)
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
