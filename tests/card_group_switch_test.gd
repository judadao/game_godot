extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := (load("res://scenes/ui/CardHandUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	var cards: Array[Dictionary] = []
	for index in 8:
		cards.append({
			"id": "card_%d" % index,
			"name": "Card %d" % index,
			"type": "attack",
			"level": 1,
			"cost": 1,
			"description": "Test",
		})
	ui.call("set_cards", cards, 5.0)
	_expect(int(ui.call("get_active_group")) == 0, "The first four-card group must be active initially.")
	_expect(int(ui.call("get_card_button_count")) == 4, "Only one group of four cards may cover the map.")
	ui.call("set_active_group", 1)
	_expect(int(ui.call("get_active_group")) == 1, "The second hand group must be selectable.")
	_expect(int(ui.call("get_visible_card_global_index", 0)) == 4, "Q on group two must address the fifth held card.")
	_expect(InputMap.has_action("card_group_1") and InputMap.has_action("card_group_2"), "A/S hand-group actions must exist.")
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
