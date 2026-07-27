extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := (load("res://scenes/ui/hud/HUD.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	var viewport_size: Vector2 = hud.get_viewport_rect().size
	var status_rect := _canvas_rect(hud.get_node("BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus") as Control)
	var quest_rect := _canvas_rect(hud.get_node("BottomHUD/HUDGrid/InfoColumn/QuestCenter/QuestProxy/HUDQuestTracker") as Control)
	var progress_rect := _canvas_rect(hud.get_node("BottomHUD/HUDGrid/ProgressColumn/ProgressCenter/ProgressProxy/HUDProgressPanel") as Control)
	var bottom_hud_top: float = viewport_size.y * 0.75
	_expect(status_rect.position.y >= bottom_hud_top, "Player status must be anchored in the lower-left HUD column.")
	_expect(status_rect.end.x <= viewport_size.x * 0.22 + 1.0, "Player status must remain in the first proportional column.")
	_expect(quest_rect.position.y >= bottom_hud_top, "Objective tracker must be anchored in the lower-right HUD column.")
	_expect(progress_rect.position.y >= bottom_hud_top, "Gold and experience must be anchored in the lower-right HUD column.")
	_expect(quest_rect.position.x >= viewport_size.x * 0.68, "Objective tracker must remain in the fourth proportional column.")
	_expect(progress_rect.position.x >= viewport_size.x * 0.88, "Gold and experience must remain in the fifth proportional column.")
	_expect(quest_rect.end.x <= progress_rect.position.x, "Right-side objective and progress panels must not overlap.")
	var hotbar := hud.get_node("HUDHotbar") as Control
	_expect(not hotbar.get_node("Icons/Attack").visible, "Legacy attack HUD must be hidden.")
	_expect(not hotbar.get_node("Icons/Skill").visible, "Legacy skill HUD must be hidden.")
	for hint_name in ["HealthKey", "ManaKey", "AttackKey", "SkillKey"]:
		_expect(not hotbar.get_node(hint_name).visible, "Lower-left key hints must be hidden.")
	_expect(hotbar.anchor_top == 0.0 and hotbar.offset_top >= 100.0, "Compact potion HUD must be moved away from the lower-left play area.")
	_expect(hotbar.size.x <= 150.0 and hotbar.size.y <= 70.0, "Remaining potion HUD must use a compact footprint.")
	hud.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
