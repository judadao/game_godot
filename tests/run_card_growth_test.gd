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
	_expect(int(run.card_levels.get("dash_strike", 0)) == 1, "Ordinary starting cards must begin at level one.")
	run.temporary_buffs["passives"] = ["wind_feather"]
	var copies_before := int(game.call("_get_card_copy_count", "dash_strike")) if game.has_method("_get_card_copy_count") else 0
	_expect(bool(game.call("_apply_card_reward", "dash_strike")), "An ordinary duplicate reward must add a playable copy.")
	_expect(int(run.card_levels.get("dash_strike", 0)) == 1, "Duplicate rewards must not auto-level cards.")
	_expect(
		game.has_method("_get_card_copy_count")
		and int(game.call("_get_card_copy_count", "dash_strike")) == copies_before + 1,
		"Duplicate rewards must remain separate until the campfire."
	)
	_expect(bool(game.call("_apply_card_reward", "dash_strike")), "A third ordinary copy must be addable for a level-three campfire merge.")
	_expect(game.has_method("_merge_card_at_campfire"), "Campfire must expose card merging.")
	_expect(bool(game.call("_merge_card_at_campfire", "dash_strike")), "Campfire must merge ordinary duplicate cards.")
	_expect(run.card_levels.has("gale_lunge"), "Matching level-three ordinary card and passive must evolve.")
	_expect(
		(game.get("meta_state") as MetaState).unlocked_evolutions.has("evolve_dash_strike"),
		"Triggered evolution must become a permanent discovery."
	)
	var deck := game.get("deck_manager") as DeckManager
	_expect(deck.hand.has("gale_lunge") or deck.draw_pile.has("gale_lunge") or deck.discard_pile.has("gale_lunge"), "Evolution must replace the playable base card.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
