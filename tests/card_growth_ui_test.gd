extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]
const UI_SCENE := preload("res://scenes/ui/CardGrowthUI.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in VIEWPORT_SIZES:
		await _check_responsive_modal(viewport_size)
	await _check_entry_projection_and_intents()
	quit(0 if _failures == 0 else 1)


func _check_responsive_modal(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var ui := UI_SCENE.instantiate() as Control
	viewport.add_child(ui)
	await _wait_for_layout()
	var modal := ui.get_node("CenterContainer/GrowthModal") as Control
	var grid_scroll := ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/OptionScroll") as ScrollContainer
	_expect(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "Growth UI must process while a pause token freezes gameplay at %s." % viewport_size)
	_expect(_inside_viewport(_canvas_rect(modal), viewport_size), "Growth modal must remain fully visible at %s." % viewport_size)
	_expect(absf(_canvas_rect(modal).get_center().x - float(viewport_size.x) * 0.5) <= 2.0, "Growth modal must remain centered horizontally at %s." % viewport_size)
	_expect(absf(_canvas_rect(modal).get_center().y - float(viewport_size.y) * 0.5) <= 2.0, "Growth modal must remain centered vertically at %s." % viewport_size)
	_expect(grid_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "Variable growth options must be scrollable at %s." % viewport_size)
	ui.queue_free()
	viewport.queue_free()
	await process_frame


func _check_entry_projection_and_intents() -> void:
	var ui := UI_SCENE.instantiate() as Control
	root.add_child(ui)
	await _wait_for_layout()
	var confirmed: Array[Dictionary] = []
	var close_requests: Array[bool] = []
	ui.choice_confirmed.connect(func(action: Dictionary) -> void: confirmed.append(action.duplicate(true)))
	ui.close_requested.connect(func() -> void: close_requests.append(true))
	var entry := {
		"source": "exp_level",
		"allowed_pages": ["upgrade", "reward"],
		"payload": {
			"upgrade_options": _long_upgrade_options(),
			"fallback_rewards": [{"resource_id": "gold", "amount": 75, "name": "75 Gold"}],
		},
	}
	ui.set_growth_entry(entry)
	await _wait_for_layout()
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/SourceTitle") as Label).text == "EXP LEVEL", "Growth source title must describe the current queue entry.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/NewCardTab") as Button).visible == false, "Undeclared New Card pages must remain hidden.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/UpgradeTab") as Button).visible, "Declared Upgrade pages must remain visible.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/FusionTab") as Button).visible == false, "Undeclared Fusion pages must remain hidden.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/RewardTab") as Button).visible, "Declared Reward pages must remain visible.")
	var grid := ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/OptionScroll/OptionGrid") as GridContainer
	_expect(grid.get_child_count() == 12, "Long upgrade data must populate every option into the scrolling grid.")
	var first_option := grid.get_child(0) as Button
	_expect(first_option.text.contains("#101") and first_option.text.contains("LV. 2"), "Upgrade options must show independent instance ID and level badges.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/DetailPanel/DetailLayout/DetailText") as RichTextLabel).text.contains("Lv. 2 → Lv. 3"), "Selected upgrade details must show a before-to-after comparison.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/ActionBar/ConfirmButton") as Button).disabled, "Confirm must remain disabled until an explicit selection is made.")
	ui.select_option(0)
	_expect(not (ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/ActionBar/ConfirmButton") as Button).disabled, "Selecting an option must enable confirmation.")
	ui.confirm_selection()
	_expect(confirmed.size() == 1 and String(confirmed[0].get("page", "")) == "upgrade" and int(confirmed[0].get("instance_id", 0)) == 101, "Confirmation must emit an upgrade intent for the selected instance without mutating domain state.")
	ui.request_close()
	_expect(close_requests.size() == 1 and confirmed.size() == 1 and ui.visible, "Close/cancel must emit an invalid-close request without consuming or hiding the current choice.")
	ui.set_growth_entry({"source": "exp_level", "allowed_pages": ["fusion"], "payload": {"fusion_options": []}})
	await _wait_for_layout()
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/EmptyReason") as Label).visible, "Allowed pages with no valid options must show a clear empty-state reason.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/ActionBar/ConfirmButton") as Button).disabled, "Empty growth pages must not allow confirmation.")
	ui.queue_free()
	await process_frame


func _long_upgrade_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for index in 12:
		options.append({
			"instance_id": 101 + index,
			"card_id": "ember_bolt",
			"name": "Ember Bolt %d" % (index + 1),
			"level": 2,
			"before": "Lv. 2: Deal 16 damage.",
			"after": "Lv. 3: Deal 22 damage.",
		})
	return options


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= float(viewport_size.x) + 0.5 and rect.end.y <= float(viewport_size.y) + 0.5


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
