extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/town/TownMap.tscn",
		"A new session must begin in the authoritative Town main scene."
	)

	var town_player := game.get("player") as Node
	game.call(
		"_on_portal_entered",
		null,
		"res://scenes/maps/autumn_forest.tscn",
		&"PlayerSpawn",
		town_player
	)
	await process_frame
	var deck_builder := game.call("get_open_ui", "DeckBuilderUI") as Control
	_expect(deck_builder != null, "Entering the forest must first open the expedition deck builder.")
	if deck_builder != null:
		deck_builder.emit_signal("deck_confirmed", game.get("meta_state").selected_deck)
		await process_frame
		await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		"Town portal must enter the authoritative Autumn Battle V2 scene."
	)
	var run := game.get("run_state") as RunState
	_expect(run.active, "Entering Autumn Forest must start transient run state.")
	var director := game.get("current_map").get_node("AutumnRunDirector") as EncounterDirector
	_expect(
		director.has_method("get_time_remaining")
			and float(director.call("get_time_remaining")) > 0.0,
		"Autumn run must begin with one visible survival countdown."
	)
	var objective_text := game.get("hud").get_node(
		"TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/ObjectiveText"
	) as Label
	_expect(
		objective_text.text == "SURVIVE UNTIL DAWN",
		"Generic enemy progress must not overwrite the survival countdown objective."
	)

	var deck := game.get("deck_manager") as DeckManager
	var energy_before := deck.energy
	var hand_before := deck.hand.duplicate()
	var total_health_before := 0
	for enemy in director.get_active_enemies():
		total_health_before += int(enemy.get("health"))
	var first_enemy := director.get_active_enemies()[0] as Node2D
	first_enemy.global_position = (game.get("player") as Node2D).global_position + Vector2(24, 0)
	game.set("_auto_attack_remaining", 0.0)
	game.call("_process", 0.2)
	_expect(
		float(game.get("_auto_attack_remaining")) > 0.0,
		"The equipped Basic Attack must fire automatically at a horizontal target."
	)
	_expect(is_equal_approx(deck.energy, energy_before), "Basic Attacks must not spend AP.")
	_expect(deck.hand == hand_before, "Basic Attacks must not mutate the four-card Combo/Healing hand.")
	var total_health_after := 0
	for enemy in director.get_active_enemies():
		total_health_after += int(enemy.get("health"))
	_expect(total_health_after < total_health_before, "The equipped Basic Attack must damage the live encounter.")
	var paid_index := -1
	for index in deck.hand_instances.size():
		var projected := game.call("_card_for_cast", deck.hand_instances[index]) as Dictionary
		if int(projected.get("cost", 0)) > 0 and int(projected.get("cost", 0)) <= deck.energy:
			paid_index = index
			break
	_expect(paid_index >= 0, "The random opening hand must contain an affordable paid card.")
	if paid_index >= 0:
		game.call("_on_card_selected", paid_index)
	_expect(deck.energy < energy_before, "Playing a manual card in the real run must spend AP.")
	deck.energy = 0.0
	game.call("_process", 2.0)
	_expect(deck.energy >= 1.29 and not deck.hand.is_empty(), "AP must recover over time so the run cannot deadlock.")

	var gifts := game.get("divine_gift_manager") as RefCounted
	_expect(
		gifts != null and bool(gifts.call("add_or_upgrade", "resonant_grace")),
		"In-run progression must award a Divine Gift instead of upgrading fixed cards."
	)

	director.call("advance_survival", float(director.get("survival_duration")) + 1.0)
	await process_frame
	await process_frame
	_expect(not bool(director.get("_running")), "Surviving 8:30 must stop survival spawning immediately.")
	_expect((game.get("meta_state") as MetaState).boss_defeated, "Survival completion must become permanent progress.")
	_expect((game.get("meta_state") as MetaState).dash_upgrade_unlocked, "Survival completion must unlock Dash equipment growth.")
	_expect(
		int((game.get("meta_state") as MetaState).resources.get("autumn_core", 0)) >= 1,
		"Survival completion must award Autumn Cores."
	)
	var east_portal: Node = game.get("current_map").get_node("EastSafePortal")
	_expect(not bool(east_portal.get("locked")), "Boss victory must preserve the east return route.")
	game.call("_on_portal_entered", east_portal, "res://scenes/maps/autumn_safe_zone.tscn", &"BattleReturnSpawn", game.get("player"))
	await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/autumn_safe/AutumnSafeZoneMap.tscn",
		"Boss victory must return to the authoritative Autumn safe zone."
	)
	_expect(not (game.get("run_state") as RunState).active, "Returning to camp after victory must settle the run.")
	var result_ui := game.call("get_open_ui", "RunResultUI") as Control
	_expect(result_ui != null, "Returning to camp must present the settled Run Result.")
	if result_ui != null:
		result_ui.emit_signal("return_to_town_requested")
	await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/town/TownMap.tscn",
		"Safe-zone Town portal must return to the authoritative Town map."
	)

	var town := game.get("town_manager") as RefCounted
	var inventory := game.get("inventory_manager") as RefCounted
	town.call("apply_dict", {"building_levels": {"blacksmith": 0}})
	var smith_before := int(town.call("get_building_level", &"blacksmith"))
	for resource_id in (town.call("get_next_upgrade_cost", &"blacksmith") as Dictionary):
		inventory.call(
			"add_resource",
			StringName(resource_id),
			int((town.call("get_next_upgrade_cost", &"blacksmith") as Dictionary)[resource_id])
		)
	_expect(bool(town.call("upgrade_building", &"blacksmith")), "Retained run resources must support a Town upgrade.")
	_expect(int(town.call("get_building_level", &"blacksmith")) == smith_before + 1, "Town upgrade must persist in manager state.")
	game.call("_sync_progression_to_meta")
	var save := SaveService.new()
	var save_path := "user://saves/vertical_slice_flow_test.json"
	_expect(save.save_meta(save_path, (game.get("meta_state") as MetaState).to_dict()), "Vertical slice progress must save.")
	var loaded := save.load_meta(save_path)
	_expect(
		int(((loaded.get("town_state", {}) as Dictionary).get("building_levels", {}) as Dictionary).get("blacksmith", 0)) == smith_before + 1,
		"Town upgrade must survive reload."
	)

	var permanent_gold_before := int((game.get("meta_state") as MetaState).resources.get("gold", 0))
	game.call("_begin_autumn_run")
	run.gold_earned = 11
	var forest := load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	game.call("load_current_map", forest)
	await process_frame
	await game.call("_on_player_defeated")
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/town/TownMap.tscn",
		"Death must return the player to the authoritative Town main scene."
	)
	_expect(
		int((game.get("meta_state") as MetaState).resources.get("gold", 0)) == permanent_gold_before + 7,
		"Death must retain 65 percent of earned permanent gold."
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
