extends SceneTree

const CARD_FAN_PATH := "CardSafeArea/BottomMargin/BottomRow/HandSlot/CardFan"
const ENERGY_BADGE_PATH := "CardSafeArea/BottomMargin/BottomRow/LeftSlot/LeftControls/EnergyBadge"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/ui/CardHandUI.tscn") as PackedScene
	var ui := scene.instantiate()
	ui.position = Vector2(23.0, 11.0)
	root.add_child(ui)
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load for hand layout.")
	var cards: Array[Dictionary] = []
	for card_id in ["ember_bolt", "guard", "cleave", "quickstep", "healing_light"]:
		cards.append(database.get_card(card_id))
	ui.call("set_cards", cards, 3)
	await process_frame
	await process_frame
	_expect(
		ui.position == Vector2(23.0, 11.0),
		"Card hand root offsets edited in a map layout must survive initialization."
	)
	ui.position = Vector2.ZERO

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
	var safe_area := ui.get_node("CardSafeArea") as ColorRect
	var viewport_height: float = ui.get_viewport_rect().size.y
	_expect(
		safe_area.position.y >= viewport_height - 196.0,
		"Card stage must not hide more than 196 pixels of the battle map."
	)
	_expect(
		is_equal_approx(safe_area.size.y, viewport_height - safe_area.position.y),
		"Card stage must cover the viewport all the way to the bottom edge."
	)
	_expect(
		is_equal_approx(safe_area.color.a, 1.0),
		"Card stage must be opaque so the battle map cannot show through the hand."
	)
	_expect(
		is_equal_approx(float(ui.call("get_resting_visible_height")), 168.0),
		"Resting hand must expose the full card."
	)
	var card_fan := ui.get_node_or_null(CARD_FAN_PATH) as Control
	_expect(card_fan != null, "Card hand must provide the scene-authored CardFan.")
	if card_fan == null:
		ui.queue_free()
		await process_frame
		quit(1)
		return
	var buttons := card_fan.get_children()
	_expect(buttons.size() == 4, "The active card group must create four runtime cards inside CardFan.")
	if buttons.size() != 4:
		ui.queue_free()
		await process_frame
		quit(1)
		return
	var first := buttons[0] as Button
	var second := buttons[1] as Button
	var middle := buttons[2] as Button
	_expect(first != null and second != null and middle != null, "CardFan runtime children must be card buttons.")
	if first == null or second == null or middle == null:
		ui.queue_free()
		await process_frame
		quit(1)
		return
	_expect(
		second.position.x - first.position.x < first.size.x,
		"Cards must overlap instead of spanning a wide opaque bar."
	)
	_expect(
		absf((second.position.x + middle.position.x) * 0.5 + middle.size.x * 0.5 - card_fan.size.x * 0.5) <= 8.0,
		"Visible four-card group must remain centered in the scene-authored CardFan."
	)
	var safe_rect := _canvas_rect(safe_area)
	for index in buttons.size():
		var card := buttons[index] as Control
		if card == null:
			continue
		var card_rect := _canvas_rect(card)
		_expect(safe_rect.encloses(card_rect), "Resting card %d must remain inside the dedicated bottom card stage." % index)
		_expect(_inside_viewport(card_rect, ui.get_viewport_rect().size), "Resting card %d must remain fully visible above the viewport edge." % index)
	var resting := ui.call("get_card_layout", 2) as Dictionary
	var resting_position := resting.get("position", Vector2.ZERO) as Vector2
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
	var energy_badge := ui.get_node_or_null(ENERGY_BADGE_PATH) as Control
	_expect(energy_badge != null, "Scene-authored energy badge must remain available for detached editor safety.")
	if energy_badge == null:
		ui.queue_free()
		await process_frame
		quit(1)
		return
	var attached_badge_position := energy_badge.position
	var attached_card_position := middle.position
	root.remove_child(ui)
	ui.call("_layout_cards")
	_expect(
		energy_badge.position == attached_badge_position,
		"Detached editor card hand must not move scene-authored controls."
	)
	_expect(
		middle.position == attached_card_position,
		"Detached editor card hand must not recalculate CardFan-local card positions from an unavailable viewport."
	)
	ui.free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _inside_viewport(rect: Rect2, viewport_size: Vector2) -> bool:
	return (
		rect.position.x >= -0.5
		and rect.position.y >= -0.5
		and rect.end.x <= viewport_size.x + 0.5
		and rect.end.y <= viewport_size.y + 0.5
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
