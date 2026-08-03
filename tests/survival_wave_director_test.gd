extends SceneTree

class PickupCollector:
	extends Node2D

	var health := 20
	var maximum_health := 100
	var speed_multiplier := 1.0
	var speed_duration := 0.0

	func restore_health(amount: int) -> int:
		var restored := mini(maxi(0, amount), maximum_health - health)
		health += restored
		return restored

	func apply_temporary_move_speed(multiplier: float, duration: float) -> void:
		speed_multiplier = multiplier
		speed_duration = duration


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
	var experience_drop_values: Array[int] = []
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
	director.connect(
		"experience_gem_spawned",
		func(_gem: Node, value: int) -> void: experience_drop_values.append(value)
	)
	root.add_child(director)
	_expect(
		ResourceLoader.exists("res://scenes/combat/SurvivalPickup.tscn"),
		"Survival enemies need one reusable runtime pickup scene."
	)
	_expect(
		director.has_signal("survival_pickup_spawned")
			and director.has_method("roll_survival_pickup")
			and director.has_method("apply_survival_pickup"),
		"Survival pickup drops need observable spawn, deterministic roll, and effect APIs."
	)
	if director.has_method("roll_survival_pickup"):
		var drop_chance := float(director.get("normal_pickup_drop_chance"))
		_expect(
			drop_chance >= 0.12,
			"Normal horde enemies must drop temporary pickups often enough to notice during a run."
		)
		_expect(
			director.call("roll_survival_pickup", drop_chance * 0.10) == &"healing_fruit"
				and director.call("roll_survival_pickup", drop_chance * 0.55) == &"experience_magnet"
				and director.call("roll_survival_pickup", drop_chance * 0.85) == &"swift_fruit"
				and director.call("roll_survival_pickup", drop_chance + 0.01) == &"",
			"Pickup rolls must cover healing fruit, experience magnet, speed fruit, and no drop."
		)
	_expect(bool(director.call("start_encounter")), "Survival encounter must start.")
	_expect(
		(director.call("get_active_enemies") as Array).size() == 24,
		"Survival must open with a twenty-four-enemy pressure wave."
	)
	_expect(
		not director.has_signal("phase_time_changed"),
		"Survival runtime must not expose the retired phase timer contract."
	)
	_expect(
		is_equal_approx(float(director.call("get_time_remaining")), 0.8),
		"Survival encounter must begin from one authoritative countdown."
	)
	var first_normal: Node
	var expected_normal_shards := 0
	for active_enemy in director.call("get_active_enemies") as Array:
		if String(active_enemy.get_meta("encounter_archetype_id", "")) != "elite":
			first_normal = active_enemy
			break
	_expect(first_normal != null, "Survival must begin with ordinary enemies.")
	if first_normal != null:
		var archetype := first_normal.get("archetype") as EnemyArchetype
		expected_normal_shards = archetype.experience_reward
		_expect(
			float(first_normal.get_meta("survival_health_multiplier", 0.0)) == 8.0,
			"Opening horde enemies must receive the 8x survival health floor."
		)
		director.set("_spawn_remaining", 10.0)
		director.call(
			"_on_survival_enemy_defeated",
			first_normal,
			archetype.experience_reward,
			archetype.gold_reward,
			false,
			false
		)
		_expect(
			float(director.get("_spawn_remaining")) <= 0.05,
			"Defeating a normal enemy must immediately arm a refill pass instead of leaving a lull."
		)
	_expect(
		experience_drop_values.size() == expected_normal_shards
			and experience_drop_values.all(func(value: int) -> bool: return value == 1),
		"Every ordinary enemy must burst into multiple one-XP gems."
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
	if director.has_method("apply_survival_pickup"):
		var collector := PickupCollector.new()
		root.add_child(collector)
		var pickup_scene := load("res://scenes/combat/SurvivalPickup.tscn") as PackedScene
		var pickup := pickup_scene.instantiate()
		root.add_child(pickup)
		var pickup_events: Array[StringName] = []
		pickup.connect(
			"collected",
			func(item_id: StringName, _collector: Node) -> void:
				pickup_events.append(item_id)
		)
		pickup.call("configure", &"healing_fruit", collector)
		pickup.call("collect", collector)
		pickup.call("collect", collector)
		_expect(
			pickup_events == [&"healing_fruit"],
			"A runtime pickup must resolve exactly once when the player collects it."
		)
		director.call("apply_survival_pickup", &"healing_fruit", collector)
		_expect(
			collector.health == 55,
			"Healing fruit must restore a meaningful fixed amount immediately."
		)
		director.call("apply_survival_pickup", &"swift_fruit", collector)
		_expect(
			is_equal_approx(collector.speed_multiplier, 1.4)
				and is_equal_approx(collector.speed_duration, 10.0),
			"Swift fruit must grant a forty-percent movement boost for ten seconds."
		)
		var gem_scene := load("res://scenes/combat/ExperienceGem.tscn") as PackedScene
		var magnet_collections: Array[int] = []
		for gem_value in [5, 8]:
			var gem := gem_scene.instantiate()
			director.add_child(gem)
			gem.call("configure", gem_value, collector)
			gem.connect(
				"collected",
				func(value: int) -> void: magnet_collections.append(value)
			)
		director.call("apply_survival_pickup", &"experience_magnet", collector)
		_expect(
			magnet_collections == [5, 8],
			"Experience magnet must immediately collect every active experience gem."
		)
		collector.queue_free()
	var late_sprout := director.call(
		"_spawn_survival_enemy",
		&"sprout",
		false
	) as EnemyBase
	_expect(
		late_sprout != null
			and int(late_sprout.health) == 200
			and int(late_sprout.archetype.max_health) == 200,
		"A normal enemy spawned at the end of the timeline must receive the 20x health scale."
	)
	director.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
