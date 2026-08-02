extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := TOWN_SCENE.instantiate()
	root.add_child(town)
	await process_frame

	var priest := town.get_node_or_null("NPCs/Mayor")
	var witch := town.get_node_or_null("NPCs/EquipmentBlueprintMerchant")
	_expect(priest is AnimatableBody2D, "Town priest must be a movable AnimatableBody2D.")
	_expect(witch is Node2D, "Town priest behavior requires the witch target.")
	if priest == null or witch == null:
		_finish()
		return

	priest.set_process(false)
	priest.set("home_wait_seconds", 0.1)
	priest.set("chat_seconds", 0.2)
	priest.set("walk_speed", 600.0)
	var visual := priest.get_node("Visual")
	var body_collision := priest.get_node("BodyCollision") as CollisionShape2D
	var witch_visual := witch.get_node("Visual")
	witch_visual.set_process(false)
	witch_visual.set("ambient_enabled", true)
	witch_visual.call("play_state", &"idle")
	town.call("set_time_of_day_progress", 0.40)

	var home := priest.call("get_home_position") as Vector2
	_expect(home == Vector2(1130.0, 672.0), "Priest home must remain the approved Town baseline placement.")
	_expect(priest.call("get_behavior_state") == &"wait_home", "Priest must begin waiting at home.")
	_expect(StringName(visual.get("animation_name")) == &"front_idle", "Home wait must use front idle.")
	var runtime_height := 448.0 * absf(visual.scale.y)
	_expect(runtime_height >= 118.0 and runtime_height <= 122.0, "Priest Town scale must render the adult silhouette at 118-122 px tall.")
	var collision_shape := body_collision.shape as RectangleShape2D
	_expect(
		collision_shape != null and collision_shape.size.y >= 100.0,
		"Priest collision must still cover the resized runtime silhouette."
	)

	priest.call("advance_behavior", 0.11)
	_expect(priest.call("get_behavior_state") == &"walk_to_witch", "Priest must leave home after the wait timer.")
	_expect(StringName(visual.get("animation_name")) == &"side_walk", "Outbound travel must use side walk.")
	_expect(visual.scale.x > 0.0, "Outbound priest must face toward the witch.")
	priest.call("advance_behavior", 0.05)
	_expect(
		is_equal_approx(priest.position.y, home.y),
		"Priest travel must remain on the shared Town baseline."
	)
	_expect(
		is_zero_approx(float(priest.get("foreground_lane_offset"))),
		"Priest foreground lane offset must stay disabled."
	)
	_expect(priest.z_index == 0, "Priest travel must use the shared NPC depth layer.")

	_advance_until_state(priest, &"chat_with_witch")
	var conversation_position := priest.call("get_conversation_position") as Vector2
	_expect(priest.position == conversation_position, "Priest must stop at the authored conversation point.")
	_expect(is_equal_approx(conversation_position.x, witch.position.x - 95.0), "Priest must stop on the approach side of the witch.")
	_expect(StringName(visual.get("animation_name")) == &"side_chat", "Conversation must use side chat.")
	_expect(visual.scale.x > 0.0, "Priest must face right toward the witch while chatting.")
	_expect(priest.z_index == 0, "Conversation must restore the shared NPC depth layer.")
	_expect(witch_visual.call("get_active_state") == &"chat", "Witch must enter chat while the priest is beside her.")
	var witch_snapshot := witch_visual.call("get_animation_snapshot") as Dictionary
	_expect(
		float(witch_snapshot.get("facing_sign", 1.0)) < 0.0,
		"Witch must face left toward the priest during their conversation."
	)
	_expect(not bool(witch_visual.get("ambient_enabled")), "Witch ambient animation must pause during the conversation.")

	priest.call("advance_behavior", 0.21)
	_expect(priest.call("get_behavior_state") == &"walk_home", "Priest must return home after chatting.")
	_expect(StringName(visual.get("animation_name")) == &"side_walk", "Return travel must use side walk.")
	_expect(visual.scale.x < 0.0, "Returning priest must face home.")
	_expect(
		[&"idle", &"idle_look"].has(witch_visual.call("get_active_state")),
		"Witch must resume the supported autonomous idle policy after the conversation."
	)
	_expect(bool(witch_visual.get("ambient_enabled")), "Witch ambient animation must resume after chatting.")

	_advance_until_state(priest, &"wait_home")
	_expect(priest.position == home, "Priest must return to the exact home marker.")
	_expect(StringName(visual.get("animation_name")) == &"side_idle", "Returned priest must alternate into a calm non-front idle.")
	_expect(visual.scale.x > 0.0, "Returned priest idle must clear the return-walk flip.")
	_expect(priest.z_index == 0, "Returned priest must restore the shared NPC depth layer.")
	_expect(int(priest.call("get_completed_cycles")) == 1, "Priest must record one complete social round trip.")

	town.queue_free()
	await process_frame
	_finish()


func _advance_until_state(priest: Node, target_state: StringName) -> void:
	for _step in range(200):
		if priest.call("get_behavior_state") == target_state:
			return
		priest.call("advance_behavior", 0.05)
	_expect(false, "Priest behavior must reach %s without stalling." % target_state)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: priest Town social round-trip behavior")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
