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
	director.set("survival_duration", 0.8)
	director.set("final_rush_duration", 0.3)
	var elite_times: Array[float] = [0.2]
	var boss_times: Array[float] = [0.4]
	director.set("scheduled_elite_times", elite_times)
	director.set("scheduled_boss_times", boss_times)
	director.set("final_rush_elite_interval", 0.1)
	director.set("final_rush_boss_interval", 0.15)
	var time_events: Array[Dictionary] = []
	var elite_reward_events: Array[Vector2] = []
	director.connect(
		"elite_defeated",
		func(world_position: Vector2) -> void: elite_reward_events.append(world_position)
	)
	director.connect(
		"survival_time_changed",
		func(remaining: float, total: float, alive: int, cap: int, final_rush: bool) -> void:
			time_events.append({
				"remaining": remaining,
				"total": total,
				"alive": alive,
				"cap": cap,
				"final_rush": final_rush,
			})
	)
	root.add_child(director)
	_expect(bool(director.call("start_encounter")), "Survival encounter must start.")
	_expect(
		not director.has_signal("phase_time_changed"),
		"Survival runtime must not expose the retired phase timer contract."
	)
	_expect(
		is_equal_approx(float(director.call("get_time_remaining")), 0.8),
		"Survival encounter must begin from one authoritative countdown."
	)
	director.call("advance_survival", 0.21)
	_expect(
		float(director.call("get_survival_elapsed")) >= 0.21,
		"Director must expose elapsed survival time as the timeline authority."
	)
	_expect(
		int(director.call("get_spawned_elite_count")) == 1,
		"Crossing the configured timeline event must spawn one elite."
	)
	var first_elite: Node
	for enemy in director.call("get_active_enemies") as Array:
		if String(enemy.get_meta("encounter_archetype_id", "")) == "elite":
			first_elite = enemy
			break
	_expect(first_elite != null, "Scheduled elite event must create an elite enemy instance.")
	if first_elite != null:
		director.call(
			"_on_survival_enemy_defeated",
			first_elite,
			80,
			30,
			false,
			false
		)
	_expect(
		int(director.call("get_elite_defeat_count")) == 1
			and elite_reward_events.size() == 1,
		"Every defeated elite must expose a unique blessing reward event."
	)
	director.call("advance_survival", 0.21)
	_expect(
		int(director.call("get_spawned_boss_count")) == 1,
		"Crossing the configured boss time must spawn one non-completion boss."
	)
	director.call("advance_survival", 0.11)
	_expect(bool(director.call("is_final_rush")), "The final countdown window must enter Final Rush.")
	_expect(
		int(director.call("get_spawned_elite_count")) >= 2
			and int(director.call("get_spawned_boss_count")) >= 2,
		"Final Rush must immediately add both elite and boss pressure."
	)
	director.call("advance_survival", 0.3)
	_expect(
		is_zero_approx(float(director.call("get_time_remaining")))
			and int(director.call("get_completion_boss_spawn_count")) == 1,
		"Countdown completion must spawn exactly one completion Guardian."
	)
	director.call("advance_survival", 2.0)
	_expect(
		int(director.call("get_completion_boss_spawn_count")) == 1,
		"Completion Guardian must never be duplicated after the timer expires."
	)
	_expect(
		time_events.any(func(event: Dictionary) -> bool: return bool(event["final_rush"])),
		"Countdown projection must explicitly expose the Final Rush state."
	)
	director.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
