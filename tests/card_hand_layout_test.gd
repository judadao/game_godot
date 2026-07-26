extends SceneTree

const CARD_ROWS_PATH := "CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows"
const BACK_ROW_PATH := CARD_ROWS_PATH + "/BackRow"
const FRONT_ROW_PATH := CARD_ROWS_PATH + "/FrontRow"
const ENERGY_BADGE_PATH := "CardSafeArea/BottomMargin/BottomRow/APSlot/APControls/EnergyBadge"

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
	for card_id in ["guard", "iron_skin", "dash_strike", "flame_imbue"]:
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
		is_equal_approx(safe_area.position.y, viewport_height * 0.75),
		"Card stage must reserve exactly the bottom 25 percent of the viewport."
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
		float(ui.call("get_resting_visible_height")) <= 82.0,
		"Compact resting cards must fit the single row inside the bottom HUD."
	)
	var card_rows := ui.get_node_or_null(CARD_ROWS_PATH) as VBoxContainer
	var back_row := ui.get_node_or_null(BACK_ROW_PATH) as HBoxContainer
	var front_row := ui.get_node_or_null(FRONT_ROW_PATH) as HBoxContainer
	_expect(card_rows != null and back_row != null and front_row != null, "Card hand must provide scene-authored VBox/BackRow/FrontRow containers.")
	if card_rows == null or back_row == null or front_row == null:
		ui.queue_free()
		await process_frame
		quit(1)
		return
	var buttons: Array[Node] = []
	buttons.append_array(front_row.get_children())
	buttons.append_array(back_row.get_children())
	_expect(buttons.size() == cards.size(), "The front row must create every held Combo card.")
	if buttons.size() != cards.size():
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
		second.position.x >= first.position.x + first.size.x,
		"Cards in a row must be laid out by HBoxContainer without overlap."
	)
	_expect(
		front_row.get_child_count() == 4 and back_row.get_child_count() == 0,
		"The single four-card hand must occupy FrontRow only."
	)
	var safe_rect := _canvas_rect(safe_area)
	for index in buttons.size():
		var card := buttons[index] as Control
		if card == null:
			continue
		var card_rect := _canvas_rect(card)
		_expect(
			safe_rect.encloses(card_rect),
			"Resting card %d must remain inside the dedicated bottom card stage. safe=%s fan=%s local=%s card=%s layout=%s"
			% [index, safe_rect, _canvas_rect(card_rows), card.position, card_rect, ui.call("get_card_layout", index)]
		)
		_expect(_inside_viewport(card_rect, ui.get_viewport_rect().size), "Resting card %d must remain fully visible above the viewport edge." % index)
	var resting := ui.call("get_card_layout", 2) as Dictionary
	var resting_position := resting.get("position", Vector2.ZERO) as Vector2
	ui.call("preview_card_hover", 2, true)
	var raised := ui.call("get_card_layout", 2) as Dictionary
	_expect(
		float((raised.get("position", Vector2.ZERO) as Vector2).y) <= resting_position.y - 8.0
		and float((raised.get("position", Vector2.ZERO) as Vector2).y) >= resting_position.y - 12.0,
		"Hovered card must rise 8–12 pixels without leaving its row. resting=%s raised=%s"
		% [resting_position, raised.get("position", Vector2.ZERO)]
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
	_expect(deck.hand_size == 4, "Combat must hold one group of four cards.")
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
	ui.call("_capture_resting_layouts")
	_expect(
		energy_badge.position == attached_badge_position,
		"Detached editor card hand must not move scene-authored controls."
	)
	_expect(
		middle.position == attached_card_position,
		"Detached editor card hand must not recalculate container-managed card positions from an unavailable viewport."
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
