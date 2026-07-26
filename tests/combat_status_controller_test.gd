extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller_scene := load("res://scenes/combat/CombatStatusController.tscn") as PackedScene
	_expect(controller_scene != null, "CombatStatusController scene must load.")
	if controller_scene == null:
		quit(1)
		return

	var controller := controller_scene.instantiate()
	root.add_child(controller)
	await process_frame

	controller.call("apply_damage_reduction", "stone_form", 0.30, 5.0, "Stone Form")
	controller.call("apply_damage_reduction", "stone_form", 0.10, 8.0, "Stone Form")
	_expect(
		is_equal_approx(float(controller.call("get_damage_reduction")), 0.30),
		"Reapplying one source must refresh time without weakening its reduction."
	)
	controller.call("apply_damage_reduction", "counterguard", 0.25, 6.0, "Counterguard")
	controller.call("apply_damage_reduction", "blessing", 0.25, 6.0, "Blessing")
	_expect(
		is_equal_approx(float(controller.call("get_damage_reduction")), 0.60),
		"Distinct reduction sources must stack but cap at 60 percent."
	)

	controller.call("apply_super_armor", "iron_will", 1, 4.0, "Iron Will")
	controller.call("apply_super_armor", "unbreakable", 2, 2.0, "Unbreakable Stance")
	_expect(int(controller.call("get_super_armor_tier")) == 2, "The strongest active super armor tier must win.")

	var snapshot := controller.call("get_status_projection") as Array
	_expect(snapshot.size() >= 5, "HUD projection must expose every active source.")
	for raw_status in snapshot:
		var status := raw_status as Dictionary
		_expect(not String(status.get("name", "")).is_empty(), "Every projected status needs a display name.")
		_expect(float(status.get("remaining_seconds", 0.0)) > 0.0, "Every projected status needs remaining time.")

	controller.call("set_timers_paused", true)
	controller.call("advance", 3.0)
	var paused_snapshot := controller.call("get_status_projection") as Array
	_expect(
		is_equal_approx(_remaining_for(paused_snapshot, "unbreakable"), 2.0),
		"Explicit pause must freeze status timers."
	)
	controller.call("set_timers_paused", false)
	controller.call("advance", 2.1)
	_expect(int(controller.call("get_super_armor_tier")) == 1, "Expired strong armor must reveal the remaining weak tier.")

	controller.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _remaining_for(snapshot: Array, source_id: String) -> float:
	for raw_status in snapshot:
		var status := raw_status as Dictionary
		if String(status.get("source_id", "")) == source_id:
			return float(status.get("remaining_seconds", 0.0))
	return -1.0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
