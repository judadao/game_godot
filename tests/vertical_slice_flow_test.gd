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
	_expect(director.get_wave_number() == 1, "Autumn run must begin with the first encounter wave.")

	var deck := game.get("deck_manager") as DeckManager
	var energy_before := deck.energy
	var total_health_before := 0
	for enemy in director.get_active_enemies():
		total_health_before += int(enemy.get("health"))
	var attack_index := deck.hand.find("ember_bolt")
	if attack_index < 0:
		deck.hand[0] = "ember_bolt"
		attack_index = 0
	game.call("_on_card_selected", attack_index)
	_expect(deck.energy < energy_before, "Playing a card in the real run must spend energy.")
	var total_health_after := 0
	for enemy in director.get_active_enemies():
		total_health_after += int(enemy.get("health"))
	_expect(total_health_after < total_health_before, "Playing an attack card must damage the live encounter.")
	deck.energy = 0.0
	game.call("_process", 2.0)
	_expect(deck.energy >= 1.29 and not deck.hand.is_empty(), "AP must recover over time so the run cannot deadlock.")

	run.temporary_buffs["passives"] = ["wind_feather"]
	game.call("_apply_level_up_choice", {"kind": "upgrade_card", "card_id": "dash_strike"})
	game.call("_apply_level_up_choice", {"kind": "upgrade_card", "card_id": "dash_strike"})
	_expect(run.card_levels.has("gale_lunge"), "Ordinary run-card growth must produce an Evolution.")

	for _phase in 4:
		director.call("advance_survival", 999.0)
	var guardian: Node
	for enemy in director.get_active_enemies():
		if enemy.is_in_group("Bosses"):
			guardian = enemy
			break
	_expect(guardian != null, "Timed survival phases must culminate in a guardian boss.")
	if guardian != null:
		guardian.call("take_hit", 99999, Vector2.ZERO, 0.0)
	await process_frame
	await process_frame
	_expect(not bool(director.get("_running")), "Defeating the boss must stop survival spawning.")
	_expect((game.get("meta_state") as MetaState).boss_defeated, "Boss victory must become permanent progress.")
	_expect((game.get("meta_state") as MetaState).dash_upgrade_unlocked, "Heartwood Guardian victory must unlock Dash equipment growth.")
	_expect(
		int((game.get("meta_state") as MetaState).resources.get("autumn_core", 0)) >= 1,
		"Boss victory must award an Autumn Core."
	)
	var forward_portal: Node = game.get("current_map").get_node("ForwardPortal")
	_expect(not bool(forward_portal.get("locked")), "Boss victory must unlock the forward route.")
	game.call("_on_portal_entered", forward_portal, "res://scenes/maps/crystal_caves.tscn", &"PlayerSpawn", game.get("player"))
	await process_frame
	_expect(
		game.get("current_map").scene_file_path == "res://scenes/maps/layouts/CrystalCavesLayout.tscn",
		"Boss victory must enter the authoritative Crystal Caves layout."
	)

	var town := game.get("town_manager") as RefCounted
	var inventory := game.get("inventory_manager") as RefCounted
	var smith_before := int(town.call("get_building_level", &"blacksmith"))
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
		int((game.get("meta_state") as MetaState).resources.get("gold", 0)) == permanent_gold_before + 11,
		"Death must retain earned permanent gold."
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
