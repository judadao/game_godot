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
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])
	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	var original_ids: Array[String] = []
	var original_levels: Dictionary = {}
	for instance in run.card_instances:
		original_ids.append(instance.instance_id)
		original_levels[instance.instance_id] = instance.level

	run.add_experience(run.experience_required * 3)
	game.call("_on_experience_collected", 0)
	await process_frame
	_expect(
		game.get_open_ui("CardGrowthUI") == null,
		"Experience must not open in-combat card upgrades."
	)
	_expect(
		deck.hand.size() == 4
			and deck.draw_pile.is_empty()
			and deck.discard_pile.is_empty(),
		"Experience must not alter or rotate the fixed hand."
	)
	for instance in run.card_instances:
		_expect(
			original_ids.has(instance.instance_id)
				and instance.level == int(original_levels[instance.instance_id]),
			"Experience must not upgrade, replace, or fuse fixed cards."
		)

	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	await process_frame
	var gift_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(gift_ui != null, "Elite defeat must open a Divine Gift choice.")
	var queue := game.get("growth_choice_queue") as GrowthChoiceQueue
	var page := queue.peek()
	_expect(
		String(page.get("source", "")) == "divine"
			and not (page.get("choices", []) as Array).is_empty(),
		"Elite growth must contain Divine Gift choices only."
	)
	if gift_ui != null:
		gift_ui.call("confirm_selected_choice")
		await process_frame
	var gifts := game.get("divine_gift_manager") as RefCounted
	_expect(
		not (gifts.call("get_inventory") as Array).is_empty(),
		"Confirming the elite reward must add one run-local Divine Gift."
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: EXP leaves cards fixed and elite growth awards Divine Gifts")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
