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
		"energy_surge", "healing_light", "battle_rhythm", "storm_charge",
	])
	var deck := game.get("deck_manager") as DeckManager
	var player := game.get("player") as Node
	deck.hand_instances.assign([
		CardInstance.new("energy_surge", 1, "auto-energy"),
		CardInstance.new("healing_light", 1, "auto-heal"),
		CardInstance.new("battle_rhythm", 1, "auto-cheap"),
		CardInstance.new("storm_charge", 1, "auto-heavy"),
	])
	deck.energy = 1.0
	player.set("health", player.get("max_health"))
	_expect(
		int(game.call("_choose_auto_use_card_index")) == 0,
		"Auto Use must prefer an affordable Energy Cycle that produces net AP."
	)

	deck.hand_instances.remove_at(0)
	player.set("health", maxi(1, int(player.get("max_health")) / 3))
	_expect(
		int(game.call("_choose_auto_use_card_index")) == 0,
		"Auto Use must prioritize affordable direct healing at low health."
	)

	player.set("health", player.get("max_health"))
	var run := game.get("run_state") as RunState
	run.temporary_buffs["active_infusions"] = ["rhythm"]
	run.temporary_buffs["combo_levels"] = {"rhythm": 12}
	deck.energy = 3.0
	_expect(
		int(game.call("_choose_auto_use_card_index")) == 2,
		"Auto Use must skip a max-stacked Combo and spend available AP on a useful card."
	)

	game.call("_on_auto_use_changed", true)
	_expect(
		bool(game.get("_auto_use_cards")),
		"Auto Use checkbox intent must enable automatic card play in Game."
	)
	while not (game.get("ui_stack") as Array).is_empty():
		game.call("close_top_ui")
	game.call("_tick_auto_use", 0.3)
	_expect(
		deck.energy < 3.0
			and (run.temporary_buffs.get("active_infusions", []) as Array).has("storm"),
		"Enabled Auto Use must actually play the selected card and advance the hand."
	)
	game.call("_on_auto_use_changed", false)
	_expect(
		not bool(game.get("_auto_use_cards")),
		"Disabling Auto Use must immediately restore manual-only play."
	)

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
