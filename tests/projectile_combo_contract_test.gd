extends SceneTree

var _failures := 0


class DamageTarget:
	extends Node2D

	var health := 1000

	func take_damage(amount: int) -> int:
		var dealt := mini(health, maxi(0, amount))
		health -= dealt
		return dealt


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Projectile Combo contract requires the production catalog.")
	_expect(
		database.get_card("seeking_arc").is_empty(),
		"Directional growth must not remain duplicated as a separate Forked Arc card."
	)
	var combo := database.get_card("echo_volley")
	_expect(
		String(combo.get("type", "")) == "combo"
			and String(combo.get("combo_family", "")) == "offense"
			and float((combo.get("effect", {}) as Dictionary).get("combo_duration", 99.0)) <= 2.5,
		"Echo Volley must be the single short projectile-amount Combo card."
	)

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"echo_volley", "guard", "healing_light", "renewal",
	])
	var run := game.get("run_state") as RunState
	run.temporary_buffs["combo_chain_count"] = 12
	var basic_attack := game.call(
		"_apply_combo_infusions_to_card",
		database.get_card("ember_bolt")
	) as Dictionary
	var basic_effect := basic_attack.get("effect", {}) as Dictionary
	_expect(
		int(basic_effect.get("projectile_count", 1)) == 1
			and int(basic_effect.get("direction_count", 1)) == 1
			and int(basic_effect.get("target_count", 1)) == 1
			and not basic_attack.has("homing_strength"),
		"Combo Chain alone must preserve the base attack's single forward direction."
	)
	_expect(
		float(basic_attack.get("attack_size_multiplier", 1.0)) >= 2.0,
		"Combo Chain may still amplify damage, range, and spectacle."
	)

	run.temporary_buffs["combo_chain_count"] = 0
	_expect(
		bool(game.call("_resolve_combo_card", database.get_card("echo_volley"))),
		"Echo Volley must activate projectile amount and fan spread."
	)
	var modified_attack := game.call(
		"_apply_combo_infusions_to_card",
		database.get_card("ember_bolt")
	) as Dictionary
	var modified_effect := modified_attack.get("effect", {}) as Dictionary
	_expect(
		not modified_attack.has("homing_strength")
			and int(modified_effect.get("direction_count", 1)) >= 2
			and int(modified_effect.get("projectile_count", 1)) >= 2
			and int(modified_effect.get("target_count", 1))
				== int(modified_effect.get("direction_count", 1)),
		"Echo Volley projectile amount must also define its number of attack directions."
	)
	_expect(
		is_equal_approx(float(modified_effect.get("spread_degrees", 0.0)), 90.0),
		"Echo Volley Lv.1 must form a narrow 90-degree fan."
	)
	for target_level in [2, 3]:
		var instance := CardInstance.new("echo_volley", target_level, "echo-%d" % target_level)
		var leveled_combo := game.call("_card_for_cast", instance) as Dictionary
		var leveled_effect := leveled_combo.get("effect", {}) as Dictionary
		_expect(
			int(leveled_effect.get("projectile_bonus", 0)) == (3 if target_level == 2 else 7)
				and is_equal_approx(
					float(leveled_effect.get("spread_degrees", 0.0)),
					180.0 if target_level == 2 else 360.0
				),
			"Echo Volley Lv.%d must increase amount and expand toward a full circle." % target_level
		)
	var runner := CardEffectRunner.new()
	root.add_child(runner)
	var damage_targets: Array = []
	for target_index in 4:
		var target := DamageTarget.new()
		target.position = Vector2(60.0 + target_index * 20.0, target_index * 12.0)
		root.add_child(target)
		damage_targets.append(target)
	var volley_result := runner.cast(modified_attack, game.get("player"), damage_targets)
	var expected_directions := int(modified_effect.get("direction_count", 1))
	var expected_projectiles := mini(
		int(modified_effect.get("projectile_count", 1)),
		damage_targets.size()
	)
	_expect(
		int(volley_result.get("affected", 0)) == expected_directions
			and int(volley_result.get("total", 0))
				== int(modified_effect.get("amount", 0))
					* expected_projectiles,
		"Echo Volley must distribute one projectile per available fan direction."
	)
	var isolated_target := DamageTarget.new()
	isolated_target.position = Vector2(80.0, 0.0)
	root.add_child(isolated_target)
	var isolated_result := runner.cast(
		modified_attack,
		game.get("player"),
		[isolated_target]
	)
	_expect(
		int(isolated_result.get("affected", 0)) == 1
			and int(isolated_result.get("total", 0))
				== int(modified_effect.get("amount", 0)),
		"Empty fan directions must miss instead of multiplying damage into one isolated target."
	)
	_expect(
		float(game.call("_get_combo_time_remaining")) <= 3.0
			and float(run.temporary_buffs.get("combo_chain_remaining", 0.0)) <= 3.0,
		"Combo effects and Chain must demand renewal within three seconds."
	)
	game.call("_tick_combo_effects", 3.1)
	_expect(
		is_zero_approx(float(game.call("_get_combo_time_remaining")))
			and int(run.temporary_buffs.get("combo_chain_count", 0)) == 0,
		"Projectile Combo effects and Chain must expire after the short action window."
	)

	var feedback := (
		load("res://scenes/combat/AutoAttackFeedback.tscn") as PackedScene
	).instantiate()
	root.add_child(feedback)
	feedback.call(
		"play",
		Vector2.ZERO,
		Vector2(180.0, 40.0),
		20,
		2,
		8,
		false,
		1.0,
		1.0,
		{"direction_count": 8, "direction_index": 7, "spread_degrees": 360.0}
	)
	_expect(
		feedback.has_method("get_direction_count")
			and int(feedback.call("get_direction_count")) == 8
			and feedback.has_method("get_spread_degrees")
			and is_equal_approx(float(feedback.call("get_spread_degrees")), 360.0)
			and feedback.has_method("get_direction_angle_degrees")
			and is_equal_approx(
				float(feedback.call("get_direction_angle_degrees")),
				135.0
			)
			and not feedback.has_method("get_homing_strength"),
		"Max-level amount Combo must reach the visible full-circle attack without homing."
	)

	feedback.queue_free()
	runner.queue_free()
	for target in damage_targets:
		(target as Node).queue_free()
	isolated_target.queue_free()
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
