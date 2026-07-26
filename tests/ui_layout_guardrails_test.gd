extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]
const CARD_SCENE := preload("res://scenes/ui/CardHandUI.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const SAFE_AREA_RATIO := 0.25
const REQUIRED_CARD_PATHS := [
	"CardSafeArea",
	"CardSafeArea/BottomMargin",
	"CardSafeArea/BottomMargin/BottomRow",
	"CardSafeArea/BottomMargin/BottomRow/APSlot/APControls",
	"CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows",
	"CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/BackRow",
	"CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/FrontRow",
	"CardSafeArea/BottomMargin/BottomRow/InfoSlot/InfoControls",
	"CardSafeArea/BottomMargin/BottomRow/InfoSlot/InfoControls/ComboHint",
	"CardSafeArea/BottomMargin/BottomRow/InfoSlot/InfoControls/CardGroupBadge",
	"BossCenter/BossStack/BossName",
	"BossCenter/BossStack/BossHealth",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_authored_boss_placeholders()
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	await _check_root_override_survives_initialization()
	quit(0 if _failures == 0 else 1)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var hud := HUD_SCENE.instantiate() as Control
	var card_hand := CARD_SCENE.instantiate() as Control
	viewport.add_child(hud)
	viewport.add_child(card_hand)
	await _wait_for_layout()
	_expect(hud.get_index() < card_hand.get_index(), "Runtime sibling order must add HUD before CardHandUI at %s." % viewport_size)

	var card_layout_is_ready := true
	for required_path in REQUIRED_CARD_PATHS:
		var authored_node := card_hand.get_node_or_null(required_path)
		_expect(
			authored_node != null and authored_node.owner != null,
			"CardHandUI must author %s in the Scene at %s." % [required_path, viewport_size]
		)
		card_layout_is_ready = card_layout_is_ready and authored_node is Control
	if not card_layout_is_ready:
		await _free_viewport(viewport)
		return

	var safe_area := card_hand.get_node("CardSafeArea") as Control
	var ap_controls := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/APSlot/APControls") as Control
	var card_rows := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows") as VBoxContainer
	var back_row := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/BackRow") as HBoxContainer
	var front_row := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/FrontRow") as HBoxContainer
	var redraw_button := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/APSlot/APControls/RedrawHand") as Button
	var energy_badge := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/APSlot/APControls/EnergyBadge") as Control
	var combo_hint := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/InfoSlot/InfoControls/ComboHint") as Control
	var group_badge := card_hand.get_node("CardSafeArea/BottomMargin/BottomRow/InfoSlot/InfoControls/CardGroupBadge") as Control
	var boss_name := card_hand.get_node("BossCenter/BossStack/BossName") as Control
	var boss_health := card_hand.get_node("BossCenter/BossStack/BossHealth") as Control
	_expect(back_row.get_child_count() == 0 and front_row.get_child_count() == 0, "Card rows must be empty before runtime cards are supplied at %s." % viewport_size)
	_expect(not boss_name.visible and not boss_health.visible, "Boss placeholder must start hidden at runtime at %s." % viewport_size)

	card_hand.call("set_cards", _sample_cards(), 5.0)
	card_hand.call("set_action_points", 5.0, 5.0)
	await _wait_for_layout()

	var safe_rect := _canvas_rect(safe_area)
	var rows_rect := _canvas_rect(card_rows)
	var expected_height := float(viewport_size.y) * SAFE_AREA_RATIO
	_expect(is_equal_approx(safe_rect.position.y, float(viewport_size.y) * (1.0 - SAFE_AREA_RATIO)), "Card safe area must begin at 75%% viewport height at %s." % viewport_size)
	_expect(is_equal_approx(safe_rect.size.y, expected_height), "Card safe area must remain 25%% viewport height at %s." % viewport_size)
	_expect(is_equal_approx(safe_rect.end.y, float(viewport_size.y)), "Card safe area must end at the viewport bottom at %s." % viewport_size)
	_expect(_inside_viewport(safe_rect, viewport_size), "Card safe area must remain inside %s." % viewport_size)
	_expect(not _canvas_rect(ap_controls).intersects(rows_rect), "AP controls must not overlap card rows at %s." % viewport_size)
	_expect(not _canvas_rect(combo_hint).intersects(rows_rect), "Combo controls must not overlap card rows at %s." % viewport_size)
	_expect(safe_rect.encloses(_canvas_rect(combo_hint)), "Combo controls must remain inside CardSafeArea instead of covering the map at %s." % viewport_size)
	_expect(safe_rect.encloses(_canvas_rect(group_badge)), "Card group controls must remain inside CardSafeArea instead of covering the map at %s." % viewport_size)
	_expect(safe_area is ColorRect and is_equal_approx((safe_area as ColorRect).color.a, 1.0), "Card safe-area background must remain opaque at %s." % viewport_size)
	_expect(
		_effective_z_index(safe_area) < _effective_z_index(hud),
		"Opaque card background must render behind the earlier HUD sibling at %s." % viewport_size
	)
	_expect(not redraw_button.disabled, "Full AP must leave the authored redraw control usable at %s." % viewport_size)

	var buttons: Array[Node] = []
	buttons.append_array(front_row.get_children())
	buttons.append_array(back_row.get_children())
	_expect(front_row.get_child_count() == 4, "FrontRow must contain the active four-card group at %s." % viewport_size)
	_expect(back_row.get_child_count() == 0, "BackRow must remain empty for the single hand at %s." % viewport_size)
	_expect(buttons.size() == 4, "The authored front row must contain all four cards at %s." % viewport_size)
	var union_rect := Rect2()
	var active_union_rect := Rect2()
	for index in buttons.size():
		var button := buttons[index] as Control
		_expect(button != null, "CardFan children must be Controls.")
		if button == null:
			continue
		var card_rect := _canvas_rect(button)
		union_rect = card_rect if index == 0 else union_rect.merge(card_rect)
		if button.get_parent() == front_row:
			active_union_rect = card_rect if index == 0 else active_union_rect.merge(card_rect)
		_expect(_inside_viewport(card_rect, viewport_size), "Resting card %d must be fully visible at %s." % [index, viewport_size])
		_expect(safe_rect.encloses(card_rect), "Resting card %d must remain in CardSafeArea at %s." % [index, viewport_size])
		if button.get_parent() == front_row:
			_expect(
				_effective_z_index(button) >= _effective_z_index(hud),
				"Active card content must remain at or above the HUD content layer at %s." % viewport_size
			)
		_expect(
			button.mouse_filter
			== (Control.MOUSE_FILTER_STOP if button.get_parent() == front_row else Control.MOUSE_FILTER_IGNORE),
			"Only the active card group may receive pointer input for card %d at %s."
			% [index, viewport_size]
		)
	_expect(absf(active_union_rect.get_center().x - float(viewport_size.x) * 0.5) <= 4.0, "Active four-card group must remain centered at %s." % viewport_size)

	var status_rect := _canvas_rect(hud.get_node("BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus") as Control)
	var quest_rect := _canvas_rect(hud.get_node("BottomHUD/HUDGrid/InfoColumn/QuestCenter/QuestProxy/HUDQuestTracker") as Control)
	var progress_rect := _canvas_rect(hud.get_node("BottomHUD/HUDGrid/ProgressColumn/ProgressCenter/ProgressProxy/HUDProgressPanel") as Control)
	_expect(_inside_viewport(status_rect, viewport_size), "HUD status must remain inside %s." % viewport_size)
	_expect(_inside_viewport(quest_rect, viewport_size), "HUD quest tracker must remain inside %s." % viewport_size)
	_expect(_inside_viewport(progress_rect, viewport_size), "HUD progress panel must remain inside %s." % viewport_size)
	_expect(status_rect.position.y >= safe_rect.position.y, "HUD status must stay in the lower-left HUD region at %s." % viewport_size)
	_expect(status_rect.end.x <= float(viewport_size.x) * 0.5, "HUD status must stay in the left half at %s." % viewport_size)
	_expect(quest_rect.position.y >= safe_rect.position.y, "HUD quest tracker must stay in the lower-right HUD region at %s." % viewport_size)
	_expect(progress_rect.position.y >= safe_rect.position.y, "HUD progress panel must stay in the lower-right HUD region at %s." % viewport_size)
	_expect(quest_rect.position.x >= float(viewport_size.x) * 0.5, "HUD quest tracker must stay in the right half at %s." % viewport_size)
	_expect(progress_rect.position.x >= float(viewport_size.x) * 0.5, "HUD progress panel must stay in the right half at %s." % viewport_size)
	_expect(not quest_rect.intersects(progress_rect), "HUD quest tracker and progress panel must not overlap at %s." % viewport_size)
	_expect(not status_rect.intersects(union_rect), "HUD status must not overlap the resting card union at %s." % viewport_size)
	_expect(not quest_rect.intersects(union_rect), "HUD quest tracker must not overlap the resting card union at %s." % viewport_size)
	_expect(not progress_rect.intersects(union_rect), "HUD progress panel must not overlap the resting card union at %s." % viewport_size)
	var hud_regions := {
		"HUDStatus": status_rect,
		"HUDQuestTracker": quest_rect,
		"HUDProgressPanel": progress_rect,
	}
	var static_card_controls := {
		"RedrawHand": _canvas_rect(redraw_button),
		"EnergyBadge": _canvas_rect(energy_badge),
		"ComboHint": _canvas_rect(combo_hint),
	}
	for control_name in static_card_controls:
		for hud_name in hud_regions:
			_expect(
				not (static_card_controls[control_name] as Rect2).intersects(hud_regions[hud_name] as Rect2),
				"%s must not cover %s at %s." % [control_name, hud_name, viewport_size]
			)

	var redraw_rect := _canvas_rect(redraw_button)
	for index in 4:
		card_hand.call("preview_card_hover", index, true)
		var hover_rect := _canvas_rect(buttons[index] as Control)
		_expect(_inside_viewport(hover_rect, viewport_size), "Hovered card %d must remain inside %s." % [index, viewport_size])
		_expect(not hover_rect.intersects(redraw_rect), "Hovered card %d must not overlap redraw controls at %s." % [index, viewport_size])
		card_hand.call("preview_card_hover", index, false)

	await _free_viewport(viewport)


func _check_authored_boss_placeholders() -> void:
	var card_hand := CARD_SCENE.instantiate() as Control
	var boss_name := card_hand.get_node("BossCenter/BossStack/BossName") as Label
	var boss_health := card_hand.get_node("BossCenter/BossStack/BossHealth") as ProgressBar
	_expect(boss_name.visible, "BossName must be visible in the authored editor scene.")
	_expect(not boss_name.text.is_empty(), "BossName must provide an editor placeholder.")
	_expect(boss_health.visible, "BossHealth must be visible in the authored editor scene.")
	_expect(boss_health.max_value > 0.0 and boss_health.value > 0.0, "BossHealth must provide an editor placeholder value.")
	card_hand.free()


func _check_root_override_survives_initialization() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var editor_hud_layer := CanvasLayer.new()
	var runtime_hud_layer := CanvasLayer.new()
	viewport.add_child(editor_hud_layer)
	viewport.add_child(runtime_hud_layer)
	var card_hand := CARD_SCENE.instantiate() as Control
	var hud := HUD_SCENE.instantiate() as Control
	_configure_map_override(card_hand, Vector2(17.0, 9.0), Vector2(0.94, 1.06))
	_configure_map_override(hud, Vector2(31.0, 14.0), Vector2(0.97, 1.03))
	var card_hand_override := _root_layout(card_hand)
	var hud_override := _root_layout(hud)
	editor_hud_layer.add_child(card_hand)
	editor_hud_layer.add_child(hud)
	await _wait_for_layout()
	_expect(_root_layout_matches(card_hand, card_hand_override), "CardHandUI initialization must preserve map-authored root anchors, offsets, and scale.")
	_expect(_root_layout_matches(hud, hud_override), "HUD initialization must preserve map-authored root anchors, offsets, and scale.")
	card_hand.reparent(runtime_hud_layer)
	hud.reparent(runtime_hud_layer)
	await _wait_for_layout()
	_expect(_root_layout_matches(card_hand, card_hand_override), "CardHandUI runtime adoption must preserve map-authored root anchors, offsets, and scale.")
	_expect(_root_layout_matches(hud, hud_override), "HUD runtime adoption must preserve map-authored root anchors, offsets, and scale.")
	await _free_viewport(viewport)


func _sample_cards() -> Array[Dictionary]:
	return [
		{"name": "Iron Will", "type": "combo", "description": "Gain super armor.", "cost": 1, "level": 1},
		{"name": "Healing Light", "type": "healing", "description": "Restore health.", "cost": 1, "level": 1},
		{"name": "Flame Imbue", "type": "combo", "description": "Future attacks gain flame.", "cost": 3, "level": 1},
		{"name": "Verdant Renewal", "type": "healing", "description": "Gain regeneration.", "cost": 2, "level": 1},
	]


func _configure_map_override(control: Control, offset: Vector2, control_scale: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = -offset.x
	control.offset_bottom = -offset.y
	control.scale = control_scale


func _root_layout(control: Control) -> Dictionary:
	return {
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"offset_left": control.offset_left,
		"offset_top": control.offset_top,
		"offset_right": control.offset_right,
		"offset_bottom": control.offset_bottom,
		"scale": control.scale,
	}


func _root_layout_matches(control: Control, expected: Dictionary) -> bool:
	return (
		is_equal_approx(control.anchor_left, float(expected["anchor_left"]))
		and is_equal_approx(control.anchor_top, float(expected["anchor_top"]))
		and is_equal_approx(control.anchor_right, float(expected["anchor_right"]))
		and is_equal_approx(control.anchor_bottom, float(expected["anchor_bottom"]))
		and is_equal_approx(control.offset_left, float(expected["offset_left"]))
		and is_equal_approx(control.offset_top, float(expected["offset_top"]))
		and is_equal_approx(control.offset_right, float(expected["offset_right"]))
		and is_equal_approx(control.offset_bottom, float(expected["offset_bottom"]))
		and control.scale.is_equal_approx(expected["scale"] as Vector2)
	)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _effective_z_index(item: CanvasItem) -> int:
	var effective_z := item.z_index
	var parent := item.get_parent()
	while item.z_as_relative and parent is CanvasItem:
		item = parent as CanvasItem
		effective_z += item.z_index
		parent = item.get_parent()
	return effective_z


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _free_viewport(viewport: SubViewport) -> void:
	viewport.queue_free()
	await process_frame


func _inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return (
		rect.position.x >= -0.5
		and rect.position.y >= -0.5
		and rect.end.x <= float(viewport_size.x) + 0.5
		and rect.end.y <= float(viewport_size.y) + 0.5
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
