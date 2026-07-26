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
	var run := game.get("run_state") as RunState
	var instances_before := run.card_instances.duplicate(true)
	_expect(not game.has_method("_merge_card_at_campfire"), "Campfires must not expose card fusion.")
	_expect(not game.has_method("_upgrade_card_at_campfire"), "Campfires must not expose card upgrades.")
	_expect(game.has_method("_rest_at_campfire"), "Campfires must retain restoration.")
	_expect(bool(game.call("_rest_at_campfire")), "The first campfire use must restore the expedition player.")
	_expect(run.card_instances == instances_before, "Restoration-only campfires must not mutate card instances.")
	_expect(bool(run.temporary_buffs.get("campfire_used", false)), "Restoration must still consume the campfire use.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
