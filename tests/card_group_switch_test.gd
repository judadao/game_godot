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
	await process_frame
	await process_frame
	_expect(int(ui.call("get_active_group")) == 0, "The first four-card group must be active initially.")
	_expect(int(ui.call("get_card_button_count")) == 8, "Both four-card groups must remain visible.")
	var first_group_front := ui.call("get_card_layout", 0) as Dictionary
	var second_group_back := ui.call("get_card_layout", 4) as Dictionary
	_expect(
		(ui.call("get_card_button", 0) as Control).get_parent().name == "FrontRow"
		and (ui.call("get_card_button", 4) as Control).get_parent().name == "BackRow",
		"Active group one must be parented to FrontRow and group two to BackRow."
	)
	_expect(
		float((first_group_front.get("position", Vector2.ZERO) as Vector2).y)
		> float((second_group_back.get("position", Vector2.ZERO) as Vector2).y),
		"The active first group must sit in the lower foreground row."
	)
	_expect(
		int(first_group_front.get("z_index", 0)) > int(second_group_back.get("z_index", 0)),
		"The active first group must draw above the inactive group."
	)
	_expect(
		(first_group_front.get("scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ONE)
		and is_equal_approx((second_group_back.get("scale", Vector2.ZERO) as Vector2).x, 0.92),
		"FrontRow cards must remain at 100 percent while BackRow cards use 92 percent scale. front=%s back=%s"
		% [first_group_front.get("scale"), second_group_back.get("scale")]
	)
	_expect(ui.has_method("toggle_active_group"), "Card hand must expose one shared group-toggle action.")
	if ui.has_method("toggle_active_group"):
		ui.call("toggle_active_group")
	await process_frame
	await process_frame
	_expect(int(ui.call("get_active_group")) == 1, "The second hand group must be selectable.")
	_expect(int(ui.call("get_visible_card_global_index", 0)) == 4, "Q on group two must address the fifth held card.")
	var first_group_back := ui.call("get_card_layout", 0) as Dictionary
	var second_group_front := ui.call("get_card_layout", 4) as Dictionary
	_expect(
		(ui.call("get_card_button", 0) as Control).get_parent().name == "BackRow"
		and (ui.call("get_card_button", 4) as Control).get_parent().name == "FrontRow",
		"A/S switching must exchange the groups between the authored rows."
	)
	_expect(
		float((second_group_front.get("position", Vector2.ZERO) as Vector2).y)
		> float((first_group_back.get("position", Vector2.ZERO) as Vector2).y),
		"Selecting group two must move it into the lower foreground row."
	)
	_expect(
		int(second_group_front.get("z_index", 0)) > int(first_group_back.get("z_index", 0)),
		"Selecting group two must draw it above group one."
	)
	_expect(
		(second_group_front.get("scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ONE)
		and is_equal_approx((first_group_back.get("scale", Vector2.ZERO) as Vector2).x, 0.92),
		"Switching groups must move the 92 percent treatment to the new BackRow. front=%s back=%s"
		% [second_group_front.get("scale"), first_group_back.get("scale")]
	)
	if ui.has_method("toggle_active_group"):
		ui.call("toggle_active_group")
		_expect(int(ui.call("get_active_group")) == 0, "The same toggle must return from group two to group one.")
		ui.call("toggle_active_group")
		_expect(int(ui.call("get_active_group")) == 1, "Repeated A/S/LT/RT toggles must alternate groups.")
	_expect(InputMap.has_action("card_group_1") and InputMap.has_action("card_group_2"), "A/S hand-group actions must exist.")
	_expect(
		not _actions_share_physical_key(&"move_left", &"card_group_1")
		and not _actions_share_physical_key(&"move_right", &"card_group_2"),
		"Card group A/S keys must not also move the player."
	)
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _actions_share_physical_key(first_action: StringName, second_action: StringName) -> bool:
	for first_event in InputMap.action_get_events(first_action):
		if not first_event is InputEventKey:
			continue
		var first_key := (first_event as InputEventKey).physical_keycode
		for second_event in InputMap.action_get_events(second_action):
			if second_event is InputEventKey and (second_event as InputEventKey).physical_keycode == first_key:
				return true
	return false
