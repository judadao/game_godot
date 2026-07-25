extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/ui/CardHandUI.tscn") as PackedScene
	var ui := scene.instantiate()
	root.add_child(ui)
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load for hand layout.")
	var cards: Array[Dictionary] = []
	for card_id in ["ember_bolt", "guard", "cleave", "quickstep", "healing_light"]:
		cards.append(database.get_card(card_id))
	ui.call("set_cards", cards, 3)
	await process_frame

	_expect(ui.has_method("get_hand_panel_count"), "Card hand must expose its obstruction contract.")
	_expect(ui.has_method("get_resting_visible_height"), "Card hand must expose resting visible height.")
	_expect(ui.has_method("get_card_layout"), "Card hand must expose deterministic card layout.")
	_expect(ui.has_method("preview_card_hover"), "Card hand must expose hover preview for testing.")
	if not ui.has_method("get_card_layout"):
		ui.queue_free()
		await process_frame
		quit(1)
		return

	_expect(int(ui.call("get_hand_panel_count")) == 0, "Hand must not create a large opaque background panel.")
	_expect(
		is_equal_approx(float(ui.call("get_resting_visible_height")), 154.0),
		"Resting hand must expose nearly the full card."
	)
	var first := ui.call("get_card_layout", 0) as Dictionary
	var second := ui.call("get_card_layout", 1) as Dictionary
	var middle := ui.call("get_card_layout", 2) as Dictionary
	_expect(
		float((second.get("position", Vector2.ZERO) as Vector2).x)
		- float((first.get("position", Vector2.ZERO) as Vector2).x) < 132.0,
		"Cards must overlap instead of spanning a wide opaque bar."
	)
	_expect(
		absf((
			float((second.get("position", Vector2.ZERO) as Vector2).x)
			+ float((middle.get("position", Vector2.ZERO) as Vector2).x)
		) * 0.5 + 66.0 - 640.0) <= 8.0,
		"Visible four-card group must remain centered in a 1280-wide viewport."
	)
	var resting_position := middle.get("position", Vector2.ZERO) as Vector2
	ui.call("preview_card_hover", 2, true)
	var raised := ui.call("get_card_layout", 2) as Dictionary
	_expect(
		float((raised.get("position", Vector2.ZERO) as Vector2).y) <= resting_position.y - 70.0,
		"Hovered card must rise enough to reveal its complete text."
	)
	_expect(int(raised.get("z_index", 0)) >= 100, "Hovered card must draw in front of the hand.")
	_expect((raised.get("scale", Vector2.ONE) as Vector2).x >= 1.08, "Hovered card must enlarge.")
	ui.call("preview_card_hover", 2, false)
	var restored := ui.call("get_card_layout", 2) as Dictionary
	_expect(
		(restored.get("position", Vector2.ZERO) as Vector2).is_equal_approx(resting_position),
		"Card must return to its resting fan position after hover."
	)
	_expect(bool(ui.call("has_compact_energy_display")), "Compact hand must retain an energy display.")
	_expect(bool(ui.call("has_compact_combo_display")), "Compact hand must retain a combo display.")
	var deck := DeckManager.new(database)
	_expect(deck.hand_size == 8, "Combat must hold two groups of four cards.")
	_expect(ui.has_method("get_shortcut_label"), "Card hand must expose slot shortcut labels.")
	if ui.has_method("get_shortcut_label"):
		for index in 4:
			_expect(
				String(ui.call("get_shortcut_label", index)) == ["Q", "W", "E", "R"][index],
				"Four cards must display Q/W/E/R in order."
			)
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
