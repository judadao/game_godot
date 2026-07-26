extends SceneTree

const HUD_PATH := "res://scenes/ui/autumn/AutumnCombatHUD.tscn"
const MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const HAND_PATH := "res://scenes/ui/autumn/AutumnCardHandUI.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(HUD_PATH), "AutumnCombatHUD must be the authored combat-HUD scene.")
	if _failures > 0:
		quit(1)
		return
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	root.add_child(hud)
	await process_frame
	for node_path in [
		"TopLeftStack",
		"TopLeftStack/ActiveStatusList",
		"TopLeftStack/ObjectivePanel/ObjectiveRows",
		"TopCenterStack",
		"TopCenterStack/BossStack",
		"TopCenterStack/SkillToastStack",
		"BottomStage",
		"BottomStage/PlayerVitals/VitalsRows",
		"BottomStage/CardHandUI",
		"BottomStage/BottomRightPanel/ResourceRows",
	]:
		_expect(hud.has_node(node_path), "Autumn combat HUD must author %s." % node_path)
	var top_left := hud.get_node("TopLeftStack")
	var active_status_list := top_left.get_node_or_null("ActiveStatusList")
	var objective_panel := top_left.get_node_or_null("ObjectivePanel")
	_expect(active_status_list != null and active_status_list.get_parent() == top_left, "ActiveStatusList must be a direct TopLeftStack child.")
	_expect(objective_panel != null and objective_panel.get_parent() == top_left, "ObjectivePanel must be a direct TopLeftStack child.")
	_expect(hud.has_method("set_active_statuses"), "HUD root must project transient active statuses.")
	if active_status_list != null and hud.has_method("set_active_statuses"):
		hud.call("set_active_statuses", ["Armor 3s", "Regeneration 5s"])
		var visible_statuses := 0
		for status_row in active_status_list.get_node("StatusRows").get_children():
			if status_row is Control and (status_row as Control).visible:
				visible_statuses += 1
		_expect(visible_statuses == 2, "ActiveStatusList must show only projected active statuses.")
	var bottom_stage := hud.get_node("BottomStage")
	for bottom_path in [
		"PlayerVitals",
		"CardHandUI",
		"CardHandUI/CardSafeArea/BottomMargin/BottomRow/APSlot/APControls/EnergyBadge",
		"CardHandUI/CardSafeArea/BottomMargin/BottomRow/HintSlot/HintControls/CardGroupBadge",
		"BottomRightPanel/ResourceRows",
	]:
		_expect(bottom_stage.has_node(bottom_path), "BottomStage must own %s." % bottom_path)
	var hands := hud.find_children("*", "AutumnCardHandUI", true, false)
	_expect(hands.size() == 1, "Autumn combat HUD must contain exactly one embedded card hand.")
	if hands.size() == 1:
		_expect((hands[0] as Node).scene_file_path == HAND_PATH, "Embedded hand must use AutumnCardHandUI.")
		_expect(
			(hands[0] as AutumnCardHandUI).get_card_button_count() == 0,
			"Runtime-empty combat HUD must not synthesize placeholder cards."
		)
	_expect(hud.has_method("set_boss_health"), "HUD root must own boss projection.")
	_expect(hud.has_method("show_skill_toast"), "HUD root must own skill-toast projection.")
	_expect(not hud.has_method("set_combo"), "Combat HUD must not expose persistent combo projection.")
	var embedded_hand := hud.get_node("BottomStage/CardHandUI") as AutumnCardHandUI
	var combo_frame := embedded_hand.get_node("CardSafeArea/BottomMargin/BottomRow/InfoSlot/ComboFrame") as Control
	_expect(not combo_frame.visible, "Embedded Autumn card hand must hide the inherited persistent combo frame.")
	embedded_hand.set_combo("PERSISTENT", "MUST STAY HIDDEN")
	_expect(not combo_frame.visible, "set_combo compatibility calls must not restore persistent combo UI.")
	if hud.has_method("set_boss_health"):
		hud.call("set_boss_health", "Heartwood Guardian", 55, 100)
		var boss := hud.get_node("TopCenterStack/BossStack") as Control
		_expect(boss.visible, "Boss stack must become visible when a boss is projected.")
	if hud.has_method("show_skill_toast"):
		var toast_stack := hud.get_node("TopCenterStack/SkillToastStack")
		for skill in ["iron_momentum", "ember_chain", "gale_sequence", "fourth_skill"]:
			hud.call("show_skill_toast", skill, skill.capitalize())
		_expect(_visible_toast_count(toast_stack) == 3, "Distinct skill triggers must never exceed three visible toast rows.")
		await create_timer(1.6).timeout
		_expect(_visible_toast_count(toast_stack) == 0, "Every skill toast must hide and recycle after 1.5 seconds.")

		hud.call("show_skill_toast", "iron_momentum", "Iron Momentum")
		await create_timer(0.75).timeout
		var active_toast := _visible_toast(toast_stack)
		_expect(active_toast != null and active_toast.modulate.a < 0.75, "Skill toast must visibly alpha-fade before expiry.")
		hud.call("show_skill_toast", "iron_momentum", "Iron Momentum Refreshed")
		active_toast = _visible_toast(toast_stack)
		_expect(_visible_toast_count(toast_stack) == 1, "Visible duplicate skill triggers must refresh one toast, not add another.")
		_expect(active_toast != null and active_toast.modulate.a > 0.95, "Duplicate trigger must restart the toast fade at full alpha.")
		await create_timer(0.85).timeout
		_expect(_visible_toast_count(toast_stack) == 1, "Duplicate refresh must extend visibility past the original expiry.")
		await create_timer(0.75).timeout
		_expect(_visible_toast_count(toast_stack) == 0, "Refreshed toast must still finish and recycle 1.5 seconds later.")
	hud.queue_free()

	var autumn_map := (load(MAP_PATH) as PackedScene).instantiate()
	root.add_child(autumn_map)
	await process_frame
	var map_hud := autumn_map.get_node_or_null("EditorHUDReference/HUD") as Control
	_expect(map_hud != null, "Autumn map must retain its exact authored HUD adoption node.")
	if map_hud != null:
		_expect(map_hud.scene_file_path == HUD_PATH, "Autumn map must adopt AutumnCombatHUD, not the retired split HUD.")
		_expect(map_hud.find_children("*", "AutumnCardHandUI", true, false).size() == 1, "Map HUD must expose one card-hand authority.")
	autumn_map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _visible_toast_count(stack: Node) -> int:
	var count := 0
	for toast in stack.get_children():
		if toast is Control and (toast as Control).visible:
			count += 1
	return count


func _visible_toast(stack: Node) -> Control:
	for toast in stack.get_children():
		if toast is Control and (toast as Control).visible:
			return toast as Control
	return null
