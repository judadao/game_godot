extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := (load("res://scenes/ui/cards/CardHandUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	var cards: Array[Dictionary] = []
	for index in 4:
		cards.append({
			"id": "card_%d" % index,
			"name": "Card %d" % index,
			"type": "combo",
			"level": 1,
			"cost": 1,
			"description": "Test",
		})
	ui.call("set_cards", cards, 5.0)
	await process_frame
	await process_frame
	_expect(int(ui.call("get_group_count")) == 1, "Combat must expose exactly one hand group.")
	_expect(int(ui.call("get_card_button_count")) == 4, "Combat must render exactly four cards.")
	var first_card := ui.call("get_card_layout", 0) as Dictionary
	_expect(
		(ui.call("get_card_button", 0) as Control).get_parent().name == "FrontRow"
		and (ui.call("get_card_button", 3) as Control).get_parent().name == "FrontRow",
		"All four cards must use the single authored front row."
	)
	_expect(
		(first_card.get("scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ONE),
		"The single hand row must use the active card scale."
	)
	_expect(
		not InputMap.has_action("card_group_1") and not InputMap.has_action("card_group_2"),
		"Removed A/S hand-group actions must not remain in the input map."
	)
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
