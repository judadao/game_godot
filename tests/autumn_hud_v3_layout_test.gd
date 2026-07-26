extends SceneTree

const HUD_PATH := "res://scenes/ui/autumn/AutumnHUD.tscn"
const CARD_PATH := "res://scenes/ui/autumn/AutumnCardHandUI.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]
const HUD_COLUMNS := ["StatusColumn", "APReserve", "HandReserve", "HintReserve", "InfoColumn", "ProgressColumn"]
const CARD_COLUMNS := ["StatusReserve", "APSlot", "HandSlot", "HintSlot", "InfoSlot", "ProgressReserve"]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(HUD_PATH), "AutumnHUD must exist for layout verification.")
	_expect(ResourceLoader.exists(CARD_PATH), "AutumnCardHandUI must exist for layout verification.")
	if _failures > 0:
		quit(1)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	quit(0 if _failures == 0 else 1)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	var cards := (load(CARD_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(hud)
	viewport.add_child(cards)
	await process_frame
	await process_frame

	var hud_grid := hud.get_node("BottomHUD/HUDGrid") as HBoxContainer
	var card_grid := cards.get_node("CardSafeArea/BottomMargin/BottomRow") as HBoxContainer
	var safe_area := cards.get_node("CardSafeArea") as Control
	_expect(is_equal_approx(safe_area.anchor_top, 0.75), "Autumn card safe area must begin at 75%% for %s." % viewport_size)
	_expect(is_equal_approx(safe_area.anchor_bottom, 1.0), "Autumn card safe area must end at 100%% for %s." % viewport_size)
	_expect(
		is_equal_approx(_canvas_rect(safe_area).position.y, float(viewport_size.y) * 0.75),
		"Autumn card safe-area pixels must align to 75%% for %s." % viewport_size
	)
	for index in HUD_COLUMNS.size():
		var hud_column := hud_grid.get_node(HUD_COLUMNS[index]) as Control
		var card_column := card_grid.get_node(CARD_COLUMNS[index]) as Control
		var hud_rect := _canvas_rect(hud_column)
		var card_rect := _canvas_rect(card_column)
		_expect(
			absf(hud_rect.position.x - card_rect.position.x) <= 1.5
			and absf(hud_rect.end.x - card_rect.end.x) <= 1.5,
			"Autumn HUD/card column %d must align at %s." % [index, viewport_size]
		)

	cards.call("set_cards", _sample_cards(), 5.0)
	cards.call("set_action_points", 5.0, 5.0)
	await process_frame
	await process_frame
	var back_row := cards.get_node("CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/BackRow") as HBoxContainer
	var front_row := cards.get_node("CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/FrontRow") as HBoxContainer
	_expect(back_row.get_child_count() == 4, "Autumn back row must contain four cards at %s." % viewport_size)
	_expect(front_row.get_child_count() == 4, "Autumn front row must contain four cards at %s." % viewport_size)
	var safe_rect := _canvas_rect(safe_area)
	for button in back_row.get_children() + front_row.get_children():
		_expect(
			button is Control and safe_rect.encloses(_canvas_rect(button as Control)),
			"Every Autumn card must remain inside the bottom safe area at %s." % viewport_size
		)

	viewport.queue_free()
	await process_frame


func _sample_cards() -> Array[Dictionary]:
	return [
		{"id": "ember_bolt", "name": "Ember Bolt", "type": "attack", "description": "Deal damage.", "cost": 1, "level": 1, "fixed": true},
		{"id": "quickstep", "name": "Quickstep", "type": "skill", "description": "Dash and evade.", "cost": 1, "level": 1, "fixed": true},
		{"id": "guard", "name": "Guard", "type": "defense", "description": "Gain block.", "cost": 1, "level": 1},
		{"id": "cleave", "name": "Cleave", "type": "attack", "description": "Arc strike.", "cost": 2, "level": 1},
		{"id": "flame_imbue", "name": "Flame Infusion", "type": "power", "description": "Gain flame.", "cost": 2, "level": 1},
		{"id": "gale_lunge", "name": "Gale Lunge", "type": "skill", "description": "Dash.", "cost": 2, "level": 3},
		{"id": "healing_light", "name": "Healing Light", "type": "skill", "description": "Recover.", "cost": 2, "level": 1},
		{"id": "meteor", "name": "Meteor", "type": "ultimate", "description": "Heavy damage.", "cost": 5, "level": 1},
	]


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
