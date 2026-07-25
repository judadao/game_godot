extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	_expect(game.has_method("_apply_card_reward"), "Game must expose run card rewards.")
	if not game.has_method("_apply_card_reward"):
		game.queue_free()
		await process_frame
		quit(1)
		return
	var run := game.get("run_state") as RunState
	_expect(int(run.card_levels.get("ember_bolt", 0)) == 1, "Starting cards must begin at level one.")
	run.temporary_buffs["passives"] = ["ember_core"]
	var copies_before := int(game.call("_get_card_copy_count", "ember_bolt")) if game.has_method("_get_card_copy_count") else 0
	_expect(bool(game.call("_apply_card_reward", "ember_bolt")), "A duplicate reward must add a playable copy.")
	_expect(int(run.card_levels.get("ember_bolt", 0)) == 1, "Duplicate rewards must not auto-level cards.")
	_expect(
		game.has_method("_get_card_copy_count")
		and int(game.call("_get_card_copy_count", "ember_bolt")) == copies_before + 1,
		"Duplicate rewards must remain separate until the campfire."
	)
	_expect(bool(game.call("_apply_card_reward", "ember_bolt")), "A third copy must be addable for a level-three campfire merge.")
	_expect(game.has_method("_merge_card_at_campfire"), "Campfire must expose card merging.")
	_expect(bool(game.call("_merge_card_at_campfire", "ember_bolt")), "Campfire must merge duplicate cards.")
	_expect(run.card_levels.has("inferno_orb"), "Matching level-three card and passive must evolve.")
	_expect(
		(game.get("meta_state") as MetaState).unlocked_evolutions.has("evolve_ember_bolt"),
		"Triggered evolution must become a permanent discovery."
	)
	var deck := game.get("deck_manager") as DeckManager
	_expect(deck.hand.has("inferno_orb") or deck.draw_pile.has("inferno_orb") or deck.discard_pile.has("inferno_orb"), "Evolution must replace the playable base card.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
