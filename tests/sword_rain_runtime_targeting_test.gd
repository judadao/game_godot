extends SceneTree

var _failures := 0
var _targets: Array[Node2D] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null, "Sword Rain runtime targeting needs NamedSkillVFX.")
	if effect == null:
		_finish()
		return
	root.add_child(effect)
	var first := _make_target("FirstEnemy", Vector2(260.0, 120.0), Vector2(0.0, -46.0))
	var second := _make_target("SecondEnemy", Vector2(410.0, 96.0), Vector2(0.0, -52.0))
	_targets.assign([first, second])
	await process_frame
	_expect(
		effect.has_method("configure_runtime_targeting")
			and effect.has_method("get_sword_rain_targeting_state"),
		"Sword Rain must accept a live enemy provider and expose retarget diagnostics."
	)
	if not effect.has_method("configure_runtime_targeting"):
		_finish()
		return
	effect.call("configure_runtime_targeting", Callable(self, "_provide_targets"))
	effect.call("play_series", "sword_rain", 1, 1, false)
	var cadence := effect.call("get_sword_rain_cadence_state") as Dictionary
	var orbit_end := float(cadence.get("orbit_end_ratio", 0.0))
	var lock_end := float(cadence.get("lock_end_ratio", 0.0))
	effect.call("debug_set_progress", (orbit_end + lock_end) * 0.5)
	var locked := effect.call("get_sword_rain_targeting_state") as Dictionary
	_expect(bool(locked.get("runtime_targeting_enabled", false)), "Combat Sword Rain must use live runtime targeting.")
	_expect(int(locked.get("wave_target_count", 0)) >= 1, "Lock phase must bind at least one live enemy.")
	_expect(
		_positions_near(locked.get("wave_target_world_positions", []) as Array, Vector2(260.0, 74.0), 3.0),
		"Sword Rain must lock the target Hurtbox center instead of its ground origin."
	)
	first.queue_free()
	await process_frame
	_targets = [second]
	effect.call("debug_set_progress", lock_end + 0.12)
	var retargeted := effect.call("get_sword_rain_targeting_state") as Dictionary
	_expect(int(retargeted.get("retarget_count", 0)) >= 1, "A vanished target must retarget a nearby surviving enemy.")
	_expect(
		_positions_near(retargeted.get("wave_target_world_positions", []) as Array, Vector2(410.0, 44.0), 3.0),
		"Retargeted Sword Rain must keep aiming at the replacement Hurtbox center."
	)
	_expect(not bool(retargeted.get("uses_ground_fallback", true)), "Ground fallback is legal only when no enemies remain.")
	effect.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _make_target(node_name: String, world_position: Vector2, hurtbox_offset: Vector2) -> Node2D:
	var target := Node2D.new()
	target.name = node_name
	target.position = world_position
	root.add_child(target)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	target.add_child(hurtbox)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = hurtbox_offset
	collision.shape = CircleShape2D.new()
	hurtbox.add_child(collision)
	return target


func _provide_targets() -> Array:
	return _targets.duplicate()


func _positions_near(values: Array, expected: Vector2, tolerance: float) -> bool:
	for value in values:
		if value is Vector2 and (value as Vector2).distance_to(expected) <= tolerance:
			return true
	return false


func _finish() -> void:
	if _failures == 0:
		print("PASS: Sword Rain tracks Hurtbox centers and retargets surviving enemies")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
