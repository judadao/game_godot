extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := TOWN_SCENE.instantiate()
	root.add_child(town)
	await process_frame
	var priest := town.get_node("NPCs/Mayor")
	var witch := town.get_node("NPCs/EquipmentBlueprintMerchant") as TownNPCLife
	var required_methods := [&"get_active_daily_activity"]
	for method_name in required_methods:
		_expect(priest.has_method(method_name), "Priest must expose %s." % method_name)
	if not priest.has_method("get_active_daily_activity"):
		town.queue_free()
		await process_frame
		_finish()
		return
	priest.set_process(false)
	witch.set_process(false)
	priest.set("home_wait_seconds", 0.1)
	priest.set("home_activity_seconds", 0.2)
	priest.set("minimum_visit_cooldown_seconds", 10.0)
	priest.set("maximum_visit_cooldown_seconds", 10.0)
	priest.set("walk_speed", 10000.0)

	town.call("set_time_of_day_progress", 0.05)
	priest.call("advance_behavior", 0.11)
	_expect(priest.call("get_behavior_state") == &"home_activity", "At dawn the priest must pray or build courage instead of visiting the witch.")
	_expect(priest.call("get_active_daily_activity") == &"prayer", "Dawn ambient activity must remain calm prayer; courage requires an authored danger event.")

	priest.call("advance_behavior", 10.1)
	town.call("set_time_of_day_progress", 0.40)
	witch.set_external_interaction(true, Vector2(witch.position.x + 100.0, witch.position.y))
	priest.call("advance_behavior", 0.11)
	_expect(priest.call("get_behavior_state") == &"home_activity", "The priest must not interrupt a busy witch.")
	witch.set_external_interaction(false)
	priest.call("advance_behavior", 6.1)
	priest.call("advance_behavior", 0.11)
	_expect(priest.call("get_behavior_state") == &"walk_to_witch", "At noon the priest may visit an available witch.")

	_advance_until_state(priest, &"wait_home")
	priest.call("advance_behavior", 0.11)
	_expect(priest.call("get_behavior_state") == &"home_activity", "Visit cooldown must prevent an immediate repeated witch round-trip.")

	var visual := priest.get_node("Visual")
	for action in [&"prayer", &"bless", &"comfort", &"share_goods", &"courage"]:
		_expect(visual.call("play_animation", action, true), "Priest must support authored action %s." % action)
	town.queue_free()
	await process_frame
	_finish()


func _advance_until_state(priest: Node, target: StringName) -> void:
	for _step in range(400):
		if priest.call("get_behavior_state") == target:
			return
		priest.call("advance_behavior", 0.05)
	_expect(false, "Priest must reach %s." % target)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: priest setting-driven daily rhythm")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
