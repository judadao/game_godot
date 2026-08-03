extends SceneTree

const CARD_GROWTH_UI_SCENE := preload("res://scenes/ui/cards/CardGrowthUI.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(2864, 1080),
]
const REQUIRED_AUTHORED_PATHS := [
	"Backdrop",
	"SafeMargin",
	"SafeMargin/ModalCenter",
	"SafeMargin/ModalCenter/ModalPanel",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/TopRow",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/BottomRow",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FusionSection",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/SelectionSummary",
	"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/ConfirmButton",
]

var _failures := 0
var _capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("CARD_GROWTH_CAPTURE_DIR")
	_check_authored_contract()
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	quit(0 if _failures == 0 else 1)


func _check_authored_contract() -> void:
	var ui := CARD_GROWTH_UI_SCENE.instantiate() as Control
	for path in REQUIRED_AUTHORED_PATHS:
		var node := ui.get_node_or_null(path)
		_expect(node != null and node.owner != null, "CardGrowthUI must author %s in its scene." % path)
	ui.free()


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var ui := CARD_GROWTH_UI_SCENE.instantiate() as Control
	viewport.add_child(ui)
	ui.call("present_page", _dense_experience_page())
	await process_frame
	await process_frame

	var panel := ui.get_node("SafeMargin/ModalCenter/ModalPanel") as Control
	var header := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header") as Control
	var body := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body") as Control
	var footer := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer") as Control
	var scroll := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll") as ScrollContainer
	var confirm := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/ConfirmButton") as Button
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var panel_rect := _canvas_rect(panel)

	_expect(viewport_rect.encloses(panel_rect), "Modal panel must remain fully inside %s." % viewport_size)
	_expect(panel_rect.position.x >= 24.0 and panel_rect.position.y >= 24.0, "Modal panel must preserve a safe edge margin at %s." % viewport_size)
	_expect(panel_rect.end.x <= viewport_size.x - 24.0 and panel_rect.end.y <= viewport_size.y - 24.0, "Modal panel must preserve its far-edge margin at %s." % viewport_size)
	_expect(panel_rect.size.x >= 900.0, "Modal content must remain wide enough to read cards at %s." % viewport_size)
	_expect(not _canvas_rect(header).intersects(_canvas_rect(footer)), "Header and footer must not overlap at %s." % viewport_size)
	_expect(not _canvas_rect(body).intersects(_canvas_rect(footer)), "Scrollable choice body and confirm controls must not overlap at %s." % viewport_size)
	_expect(panel_rect.encloses(_canvas_rect(confirm)), "Confirm button must remain inside the modal at %s." % viewport_size)
	_expect(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Five choices must not become a scrolling card list at %s." % viewport_size)

	var choice_buttons := ui.call("get_choice_buttons") as Array
	_expect(choice_buttons.size() == 5, "Dense pages must project only five readable choices at %s." % viewport_size)
	_expect(scroll.clip_contents, "Choice overflow must be clipped by the authored scroll region at %s." % viewport_size)
	for choice_variant in choice_buttons:
		var choice := choice_variant as Button
		_expect(
			panel_rect.encloses(_canvas_rect(choice)),
			"Every icon-bearing choice card must remain inside the modal at %s." % viewport_size
		)
	var first_choice := choice_buttons[0] as Button
	_expect(
		first_choice.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
		and first_choice.tooltip_text.contains(
			"Next level substantially improves this card's visible combat effect."
		),
		"Long localized choice text must trim safely while retaining its full tooltip at %s." % viewport_size
	)
	_expect(
		first_choice.icon != null
		and first_choice.icon.get_width() <= 48
		and first_choice.icon.get_height() <= 48,
		"Choice icons must be thumbnail-sized so source textures cannot expand the modal at %s." % viewport_size
	)
	var top_row := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/TopRow") as HBoxContainer
	var bottom_row := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/BottomRow") as HBoxContainer
	_expect(
		top_row.get_child_count() == 3 and bottom_row.get_child_count() == 2,
		"Five choices must use a centered three-over-two layout at %s." % viewport_size
	)
	_expect(ui.get_viewport().gui_get_focus_owner() is Button, "A presented page must establish keyboard/gamepad focus at %s." % viewport_size)

	ui.call("present_page", _divine_gift_page())
	await process_frame
	await process_frame
	var divine_buttons := ui.call("get_choice_buttons") as Array
	_expect(divine_buttons.size() == 3, "Divine Gift pages must keep three direct choices at %s." % viewport_size)
	for button_variant in divine_buttons:
		var gift_button := button_variant as Button
		_expect(
			panel_rect.encloses(_canvas_rect(gift_button))
				and gift_button.custom_minimum_size.y >= 240.0,
			"Ornate Divine Gift cards must remain fully inside the modal at %s." % viewport_size
		)
	var summary := ui.get_node(
		"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/SelectionSummary"
	) as Label
	_expect(
		summary.visible
			and summary.text.contains("已選")
			and summary.text.contains("連段"),
		"Divine Gift selection summary must remain visible and concrete at %s." % viewport_size
	)
	if viewport_size.y >= 900:
		panel_rect = _canvas_rect(panel)
		var first_gift_rect := _canvas_rect(divine_buttons[0] as Control)
		var summary_rect := _canvas_rect(summary)
		_expect(
			panel_rect.size.y <= 700.0
				and summary_rect.position.y - first_gift_rect.end.y <= 140.0,
			"Large viewports must not create an unfinished empty gulf below Divine Gift cards at %s."
				% viewport_size
		)
	if not _capture_directory.is_empty():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		var capture_path := _capture_directory.path_join(
			"card_growth_divine_%dx%d.png" % [viewport_size.x, viewport_size.y]
		)
		_expect(
			viewport.get_texture().get_image().save_png(capture_path) == OK,
			"Divine Gift visual capture must save at %s." % viewport_size
		)

	viewport.queue_free()
	await process_frame


func _dense_experience_page() -> Dictionary:
	var choices: Array[Dictionary] = []
	for index in 8:
		choices.append({
			"choice_id": "upgrade:%d" % index,
			"action": "upgrade",
			"instance_id": "instance-%d" % index,
			"card_id": "card-%d" % index,
			"name": "Upgrade Card With An Intentionally Long Localized Display Name %d" % (index + 1),
			"level": 1 + index % 2,
			"description": "Current effect text remains readable in the compact modal.",
			"upgrade_description": "Next level substantially improves this card's visible combat effect.",
			"icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png",
		})
	for index in 4:
		choices.append({
			"choice_id": "fusion:%d" % index,
			"action": "fusion",
			"left_instance_id": "left-%d" % index,
			"right_instance_id": "right-%d" % index,
			"left_name": "Material A%d" % index,
			"right_name": "Material B%d" % index,
			"result_name": "Fusion Result %d" % index,
			"result_card_id": "result-%d" % index,
		})
	return {"event_id": 99, "source": "experience", "choices": choices}


func _divine_gift_page() -> Dictionary:
	return {
		"event_id": 100,
		"source": "divine",
		"choices": [
			{
				"choice_id": "divine:100:gift:celestial_momentum",
				"action": "divine_gift",
				"gift_id": "celestial_momentum",
				"name": "天穹疾勢",
				"description": "每次連段都會加快戰鬥節奏，使具名終結技更大、更快。",
				"icon": "»",
				"element": "wind",
				"level": 0,
				"next_level": 1,
				"next_effects": {"combo_speed_bonus": 0.04, "finisher_size_multiplier": 1.10},
				"finisher_mutations": {"piercing": true, "speed_multiplier": 1.5},
				"type": "divine",
				"card_color": "gold",
			},
			{
				"choice_id": "divine:100:gift:echoing_will",
				"action": "divine_gift",
				"gift_id": "echoing_will",
				"name": "迴響意志",
				"description": "強化每次連段，並使具名終結技追加一次迴響。",
				"icon": "↻",
				"element": "dark",
				"level": 0,
				"next_level": 1,
				"next_effects": {"combo_effect_multiplier": 1.08, "finisher_damage_multiplier": 1.08},
				"finisher_mutations": {"finisher_echoes": 1, "echo_decay": 0.7},
				"type": "divine",
				"card_color": "gold",
			},
			{
				"choice_id": "divine:100:gift:boundless_font",
				"action": "divine_gift",
				"gift_id": "boundless_font",
				"name": "萬毒源泉",
				"description": "每次連段返還 AP，具名終結技則會恢復生命。",
				"icon": "◆",
				"element": "poison",
				"level": 0,
				"next_level": 1,
				"next_effects": {"combo_ap_refund": 0.10, "finisher_heal": 2},
				"finisher_mutations": {"poison_damage": 3, "poison_duration": 5.0},
				"type": "divine",
				"card_color": "gold",
			},
		],
	}


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
