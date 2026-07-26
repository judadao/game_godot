extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var merge_game := game_scene.instantiate()
	root.add_child(merge_game)
	await process_frame
	await process_frame
	var test_deck := [
		"ember_bolt", "quickstep", "guard", "guard",
		"cleave", "cleave", "cleave", "dash_strike",
		"healing_light", "frost_bind", "energy_surge", "iron_skin",
		"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
	]
	merge_game.call("_begin_autumn_run", test_deck)
	var merge_run := merge_game.get("run_state") as RunState
	var merge_deck := merge_game.get("deck_manager") as DeckManager
	var guard_before := int(merge_game.call("_get_card_copy_count", "guard")) if merge_game.has_method("_get_card_copy_count") else 0
	_expect(guard_before == 2, "Starting deck must contain two Guard copies for merge.")
	_expect(bool(merge_game.call("_merge_card_at_campfire", "guard")), "Campfire merge must succeed for duplicates.")
	_expect(int(merge_run.card_levels.get("guard", 0)) == 2, "Merging two copies must raise the card to level two.")
	_expect(int(merge_game.call("_get_card_copy_count", "guard")) == 1, "Merge must consume the extra copy.")
	_expect(bool(merge_run.temporary_buffs.get("campfire_used", false)), "Successful merge must consume the campfire action.")
	_expect(not bool(merge_game.call("_upgrade_card_at_campfire", "cleave")), "A second campfire action in the same run must fail.")
	_expect(merge_deck.hand.size() + merge_deck.draw_pile.size() + merge_deck.discard_pile.size() == 15, "Merge must reduce the 16-card expedition deck by exactly one.")
	merge_game.queue_free()
	await process_frame

	var upgrade_game := game_scene.instantiate()
	root.add_child(upgrade_game)
	await process_frame
	await process_frame
	upgrade_game.call("_begin_autumn_run", test_deck)
	var upgrade_run := upgrade_game.get("run_state") as RunState
	var cleave_before := int(upgrade_game.call("_get_card_copy_count", "cleave")) if upgrade_game.has_method("_get_card_copy_count") else 0
	_expect(bool(upgrade_game.call("_upgrade_card_at_campfire", "cleave")), "Campfire upgrade must level an owned card.")
	_expect(int(upgrade_run.card_levels.get("cleave", 0)) == 2, "Upgrade must raise the selected card one level.")
	_expect(int(upgrade_game.call("_get_card_copy_count", "cleave")) == cleave_before, "Upgrade must not consume a card copy.")
	_expect(bool(upgrade_run.temporary_buffs.get("campfire_used", false)), "Successful upgrade must consume the campfire action.")
	upgrade_game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
