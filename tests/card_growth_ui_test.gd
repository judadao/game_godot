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
	var grid := ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/OptionScroll/OptionGrid") as GridContainer
	_expect(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "Growth UI must process while a pause token freezes gameplay at %s." % viewport_size)
	_expect(_inside_viewport(_canvas_rect(modal), viewport_size), "Growth modal must remain fully visible at %s." % viewport_size)
	_expect(absf(_canvas_rect(modal).get_center().x - float(viewport_size.x) * 0.5) <= 2.0, "Growth modal must remain centered horizontally at %s." % viewport_size)
	_expect(absf(_canvas_rect(modal).get_center().y - float(viewport_size.y) * 0.5) <= 2.0, "Growth modal must remain centered vertically at %s." % viewport_size)
	_expect(grid_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "Variable growth options must be scrollable at %s." % viewport_size)

	ui.set_growth_entry({
		"source": "wave_blessing",
		"allowed_pages": ["new_card"],
		"payload": {"card_options": _long_card_ids()},
	})
	await _wait_for_layout()
	_expect(grid.get_child_count() == 16, "Long real wave payloads must populate inside the modal at %s." % viewport_size)
	_expect(_inside_viewport(_canvas_rect(modal), viewport_size), "Long wave content must not expand the modal beyond %s." % viewport_size)

	ui.set_growth_entry({
		"source": "exp_level",
		"allowed_pages": ["upgrade"],
		"payload": {"upgradeable_instance_ids": _long_instance_ids()},
	})
	await _wait_for_layout()
	_expect(grid.get_child_count() == 14, "Long real upgrade-ID payloads must populate inside the modal at %s." % viewport_size)
	_expect(_inside_viewport(_canvas_rect(modal), viewport_size), "Long upgrade content must not expand the modal beyond %s." % viewport_size)

	ui.set_growth_entry({
		"source": "exp_level",
		"allowed_pages": ["fusion"],
		"payload": {"fusion_recipes": _max_fusion_options()},
	})
	await _wait_for_layout()
	_expect(grid.get_child_count() == 6, "Max-level fusion data must populate inside the modal at %s." % viewport_size)
	_expect((grid.get_child(0) as Button).text.contains("#501") and (grid.get_child(0) as Button).text.contains("LV. 3"), "Max fusion rows must retain material badges at %s." % viewport_size)
	_expect(_inside_viewport(_canvas_rect(modal), viewport_size), "Max fusion content must not expand the modal beyond %s." % viewport_size)

	ui.set_growth_entry({"source": "exp_level", "allowed_pages": ["fusion"], "payload": {"fusion_recipes": []}})
	await _wait_for_layout()
	_expect(grid.get_child_count() == 0, "Empty real payloads must leave no stale rows at %s." % viewport_size)
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/EmptyReason") as Label).visible, "Empty real payloads must show a reason at %s." % viewport_size)
	_expect(_inside_viewport(_canvas_rect(modal), viewport_size), "Empty content must keep the modal inside %s." % viewport_size)
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
		"allowed_pages": ["upgrade", "fusion", "reward"],
		"payload": {
			"upgradeable_instance_ids": [101, 102],
			"upgradeable_instances": [
				{"instance_id": 101, "card_id": "ember_bolt", "name": "Ember Bolt", "level": 2, "before": 2, "after": 3},
				{"instance_id": 102, "card_id": "guard", "name": "Iron Will", "level": 1, "before": 1, "after": 2},
			],
			"fusion_recipes": [_fusion_recipe(501, 502)],
			"fallback_rewards": [{"resource_id": "gold", "amount": 75, "name": "75 Gold"}],
		},
	}
	ui.set_growth_entry(entry)
	await _wait_for_layout()
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/SourceTitle") as Label).text == "EXP LEVEL", "Growth source title must describe the current queue entry.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/NewCardTab") as Button).visible == false, "Undeclared New Card pages must remain hidden.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/UpgradeTab") as Button).visible, "Declared Upgrade pages must remain visible.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/FusionTab") as Button).visible, "Declared Fusion pages must remain visible.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/RewardTab") as Button).visible, "Declared Reward pages must remain visible.")
	var grid := ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/OptionScroll/OptionGrid") as GridContainer
	_expect(grid.get_child_count() == 2, "Rich projection data must resolve the queue's two authoritative upgrade IDs.")
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

	ui.set_growth_entry({"source": "wave_blessing", "allowed_pages": ["new_card"], "payload": {"card_options": ["guard", "cleave"]}})
	await _wait_for_layout()
	_expect(grid.get_child_count() == 2 and (grid.get_child(0) as Button).text.contains("Guard"), "Real wave String card IDs must project into selectable New Card rows.")
	ui.select_option(0)
	ui.confirm_selection()
	_expect(confirmed.size() == 2 and String(confirmed[1].get("card_id", "")) == "guard", "A real wave card ID must emit a New Card intent.")

	ui.set_growth_entry({"source": "exp_level", "allowed_pages": ["upgrade"], "payload": {"upgradeable_instance_ids": [701, 702]}})
	await _wait_for_layout()
	_expect(grid.get_child_count() == 2 and (grid.get_child(0) as Button).text.contains("#701"), "Raw authoritative upgrade IDs must remain selectable when rich projection is unavailable.")
	ui.select_option(0)
	ui.confirm_selection()
	_expect(confirmed.size() == 3 and int(confirmed[2].get("instance_id", 0)) == 701, "A raw upgrade instance ID must emit the exact Upgrade intent.")

	ui.set_growth_entry({"source": "exp_level", "allowed_pages": ["fusion"], "payload": {"fusion_recipes": [_fusion_recipe(501, 502)]}})
	await _wait_for_layout()
	var fusion_row := grid.get_child(0) as Button
	var fusion_detail := ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/DetailPanel/DetailLayout/DetailText") as RichTextLabel
	_expect(fusion_row.text.contains("#501") and fusion_row.text.contains("#502") and fusion_row.text.count("LV. 3") == 2, "Fusion rows must show both material instance IDs and both level-three badges.")
	_expect(fusion_detail.text.contains("#501") and fusion_detail.text.contains("#502") and fusion_detail.text.contains("→") and fusion_detail.text.contains("Lv. 1"), "Fusion details must compare both level-three materials to the level-one result.")
	ui.select_option(0)
	ui.confirm_selection()
	_expect(confirmed.size() == 4 and confirmed[3].get("material_instance_ids", []) == [501, 502] and String(confirmed[3].get("recipe_id", "")) == "fuse_unbreakable_stance", "Fusion confirmation must preserve the exact recipe and material instance IDs.")

	ui.set_growth_entry({"source": "exp_level", "allowed_pages": ["fusion"], "payload": {"fusion_options": []}})
	await _wait_for_layout()
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/EmptyReason") as Label).visible, "Allowed pages with no valid options must show a clear empty-state reason.")
	_expect((ui.get_node("CenterContainer/GrowthModal/ModalMargin/ModalLayout/ActionBar/ConfirmButton") as Button).disabled, "Empty growth pages must not allow confirmation.")
	ui.queue_free()
	await process_frame


func _long_card_ids() -> Array[String]:
	return [
		"guard", "cleave", "dash_strike", "frost_bind", "healing_light", "battle_focus",
		"iron_skin", "energy_surge", "flame_aura", "shockwave", "flame_imbue", "battle_rhythm",
		"stoneguard_combo", "blood_pact_combo", "verdant_renewal", "overdrive",
	]


func _long_instance_ids() -> Array[int]:
	var ids: Array[int] = []
	for index in 14:
		ids.append(801 + index)
	return ids


func _max_fusion_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for index in 6:
		options.append(_fusion_recipe(501 + index * 2, 502 + index * 2))
	return options


func _fusion_recipe(first_instance_id: int, second_instance_id: int) -> Dictionary:
	return {
		"id": "fuse_unbreakable_stance",
		"name": "Iron Will + Stone Form",
		"material_card_ids": ["guard", "iron_skin"],
		"material_instance_ids": [first_instance_id, second_instance_id],
		"required_level": 3,
		"result_card_id": "fortress_stance",
	}


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
