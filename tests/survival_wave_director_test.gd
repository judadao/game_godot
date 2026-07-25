extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var script := load("res://scripts/combat/survival_wave_director.gd") as GDScript
	_expect(script != null, "SurvivalWaveDirector script must exist.")
	if script == null:
		quit(1)
		return
	var director: Node = script.new()
	var test_phases: Array[Dictionary] = [
		{"duration": 0.2, "spawn_interval": 0.05, "alive_cap": 2, "pool": [&"sprout"]},
		{"duration": 0.2, "spawn_interval": 0.05, "alive_cap": 4, "pool": [&"hopper"]},
		{"duration": -1.0, "spawn_interval": 0.05, "alive_cap": 6, "pool": [&"sprout"]},
	]
	director.set("survival_phases", test_phases)
	root.add_child(director)
	_expect(bool(director.call("start_encounter")), "Survival encounter must start.")
	_expect(int(director.call("get_current_alive_cap")) == 2, "Phase one must use its configured alive cap.")
	director.call("advance_survival", 0.21)
	_expect(int(director.call("get_wave_number")) == 2, "Elapsed phase time must advance without clearing every enemy.")
	_expect(int(director.call("get_current_alive_cap")) == 4, "Later phases must raise the alive cap.")
	director.call("advance_survival", 0.21)
	_expect(int(director.call("get_wave_number")) == 3, "Final timed phase must enter the boss phase.")
	_expect(int(director.call("get_guardian_spawn_count")) == 1, "Boss phase must spawn the guardian exactly once.")
	director.call("advance_survival", 2.0)
	_expect(int(director.call("get_guardian_spawn_count")) == 1, "Boss must never respawn while its stage is active.")
	director.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
