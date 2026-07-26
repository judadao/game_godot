extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", ["cleave", "guard", "dash_strike"])

	_expect(game.has_method("acquire_modal_pause"), "Game must expose owner-keyed modal pause acquisition.")
	_expect(game.has_method("release_modal_pause"), "Game must expose owner-keyed modal pause release.")
	var queue := game.get("growth_choice_queue") as GrowthChoiceQueue
	_expect(queue != null, "Game must own the growth queue that drives the modal.")
	if queue == null:
		await _cleanup(game)
		return

	queue.enqueue({
		"source": GrowthChoiceQueue.WAVE_BLESSING_SOURCE,
		"allowed_pages": ["new_card"],
		"payload": {"card_options": ["guard"]},
	})
	queue.enqueue({
		"source": GrowthChoiceQueue.EXP_LEVEL_SOURCE,
		"allowed_pages": ["reward"],
		"payload": {"fallback_rewards": [{"resource_id": "gold", "amount": 75}]},
	})
	await process_frame

	var modal := game.call("get_open_ui", "CardGrowthUI") as Control
	_expect(modal != null, "The first queued growth entry must open CardGrowthUI.")
	_expect(paused, "An unresolved growth choice must pause the gameplay tree.")
	_expect(not (game.get("current_map") as Node).can_process(), "Growth pause must stop the gameplay map subtree.")
	if modal != null:
		_expect(modal.process_mode == Node.PROCESS_MODE_ALWAYS, "Growth UI must remain always-processing while gameplay is paused.")
		modal.call("request_close")
		await process_frame
		_expect(queue.get_queue_count() == 2, "Close requests must not consume the current growth entry.")
		_expect(game.call("get_open_ui", "CardGrowthUI") == modal, "An unresolved close must keep the growth modal open.")
		game.call("close_top_ui")
		_expect(game.call("get_open_ui", "CardGrowthUI") == modal, "Generic modal close paths must not dismiss an unresolved growth choice.")

	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	run.temporary_buffs["infusion_effects"] = [{"infusion_id": "flame", "remaining_seconds": 4.0}]
	deck.energy = 0.0
	game.call("_process", 1.0)
	_expect(is_equal_approx(float((run.temporary_buffs["infusion_effects"] as Array)[0].get("remaining_seconds", 0.0)), 4.0), "Growth pause must freeze combo windows.")
	_expect(is_zero_approx(deck.energy), "Growth pause must freeze AP regeneration.")

	game.call("acquire_modal_pause", "external_modal")
	game.call("acquire_modal_pause", "external_modal")
	if modal != null:
		modal.call("select_option", 0)
		modal.call("confirm_selection")
	await process_frame
	_expect(queue.get_queue_count() == 1, "Confirming one choice must advance exactly one queued entry.")
	modal = game.call("get_open_ui", "CardGrowthUI") as Control
	_expect(modal != null and String((modal.get("_entry") as Dictionary).get("source", "")) == GrowthChoiceQueue.EXP_LEVEL_SOURCE, "The same modal must project the next queued entry in FIFO order.")
	if modal != null:
		modal.call("select_option", 0)
		modal.call("confirm_selection")
	await process_frame
	_expect(queue.is_empty(), "Confirming every growth choice must drain the queue.")
	_expect(game.call("get_open_ui", "CardGrowthUI") == null, "CardGrowthUI must close once the queue is empty.")
	_expect(paused, "Another modal pause owner must keep gameplay paused after growth drains.")
	game.call("release_modal_pause", "external_modal")
	_expect(paused, "An owner with two references must remain paused after releasing only one.")
	game.call("release_modal_pause", "external_modal")
	_expect(not paused, "Gameplay may resume only after the queue and every modal pause owner are clear.")
	await _cleanup(game)


func _cleanup(game: Node) -> void:
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
