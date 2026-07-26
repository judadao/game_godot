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
		"TopLeftStack/StatusPanel/StatusRows",
		"TopCenterStack",
		"TopCenterStack/BossStack",
		"TopCenterStack/SkillToastStack",
		"BottomStage",
		"BottomStage/CardHandUI",
		"BottomStage/BottomRightPanel/ResourceRows",
		"BottomStage/ObjectivePanel/ObjectiveRows",
	]:
		_expect(hud.has_node(node_path), "Autumn combat HUD must author %s." % node_path)
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
	if hud.has_method("set_boss_health"):
		hud.call("set_boss_health", "Heartwood Guardian", 55, 100)
		var boss := hud.get_node("TopCenterStack/BossStack") as Control
		_expect(boss.visible, "Boss stack must become visible when a boss is projected.")
	if hud.has_method("show_skill_toast"):
		hud.call("show_skill_toast", "iron_momentum", "Iron Momentum")
		hud.call("show_skill_toast", "iron_momentum", "Iron Momentum")
		var toasts := hud.get_node("TopCenterStack/SkillToastStack").get_children()
		var visible_count := 0
		for toast in toasts:
			if toast is Control and (toast as Control).visible:
				visible_count += 1
		_expect(visible_count == 1, "Visible duplicate skill triggers must refresh one toast, not add another.")
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
