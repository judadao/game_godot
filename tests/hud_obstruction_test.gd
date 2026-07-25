extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
