extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := EncounterDirector.new()
	root.add_child(director)
	await process_frame
	_expect(director.start_encounter(), "Encounter must start for leash testing.")
	var enemies := director.get_active_enemies()
	_expect(not enemies.is_empty(), "Encounter must spawn an active wave.")
	if enemies.is_empty():
		quit(1)
		return
	var enemy := enemies[0] as Node2D
	var spawn_position := enemy.position
	var warning_values: Array[int] = []
	var cancel_events: Array[bool] = []
	var reset_events: Array[bool] = []
	director.disengage_warning.connect(func(seconds: int) -> void: warning_values.append(seconds))
	director.disengage_cancelled.connect(func() -> void: cancel_events.append(true))
	director.combat_reset.connect(func() -> void: reset_events.append(true))

	director.update_engagement(Vector2(100, 0), 0.1)
	_expect(director.is_engaged(), "Entering 650 pixels must engage the encounter.")
	director.update_engagement(Vector2(900, 0), 0.01)
	director.update_engagement(Vector2(900, 0), 1.0)
	_expect(director.get_disengage_remaining() <= 4.01, "Leaving 760 pixels must start a five-second countdown.")
	_expect(not warning_values.is_empty(), "Leash countdown must emit a visible warning.")
	director.update_engagement(Vector2(700, 0), 0.1)
	_expect(director.get_disengage_remaining() < 0.0, "Returning inside the leash must cancel countdown.")
	_expect(cancel_events.size() == 1, "Countdown cancellation must emit once.")

	enemy.call("take_hit", 12, Vector2.ZERO, 0.0)
	enemy.call("apply_status", "slow", {"ratio": 0.5, "duration": 4.0})
	enemy.position += Vector2(180, -40)
	var maximum := int((enemy.get("archetype") as Resource).get("max_health"))
	_expect(int(enemy.get("health")) < maximum, "Test enemy must be damaged before reset.")
	director.update_engagement(Vector2(900, 0), 0.01)
	director.update_engagement(Vector2(900, 0), 5.1)
	_expect(reset_events.size() == 1, "Countdown timeout must reset combat once.")
	_expect(not director.is_engaged(), "Reset encounter must return to unengaged state.")
	_expect(enemy.position.is_equal_approx(spawn_position), "Living enemy must return to recorded spawn position.")
	_expect(int(enemy.get("health")) == maximum, "Living enemy must restore maximum health.")
	var status := enemy.call("get_status_snapshot") as Dictionary
	_expect(float(status.get("slow_remaining", 1.0)) == 0.0, "Encounter reset must clear slow.")
	_expect(float(status.get("stun_remaining", 1.0)) == 0.0, "Encounter reset must clear stun.")
	director.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
