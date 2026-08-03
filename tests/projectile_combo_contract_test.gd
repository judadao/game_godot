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
	var geometry := load("res://scripts/combat/attack_geometry.gd") as GDScript
	_expect(geometry != null, "Shared attack-shape geometry must load.")
	if geometry != null:
		_expect(
			bool(geometry.call(
				"directional_sweep_contains",
				Vector2.ZERO, Vector2(100.0, 0.0), Vector2(50.0, 52.0), 0.0, 53.0
			)),
			"Directional sword energy must include points inside its swept blade silhouette."
		)
		_expect(
			not bool(geometry.call(
				"directional_sweep_contains",
				Vector2.ZERO, Vector2(100.0, 0.0), Vector2(50.0, 54.0), 0.0, 53.0
			)),
			"Directional sword energy must exclude points beyond its visible blade height."
		)
		_expect(
			bool(geometry.call(
				"directional_sweep_contains",
				Vector2.ZERO, Vector2(100.0, 0.0), Vector2(120.0, 30.0), 0.0, 53.0
			))
				and not bool(geometry.call(
					"directional_sweep_contains",
					Vector2.ZERO, Vector2(100.0, 0.0), Vector2(-1.0, 0.0), 0.0, 53.0
				)),
			"The moving blade must use a rounded forward cap without damaging behind the player."
		)
		_expect(
			bool(geometry.call(
				"radial_contains",
				Vector2.ZERO, Vector2(60.0, 0.0), 12.0, 50.0
			)),
			"Circular attacks must intersect the target hurtbox instead of testing only its root point."
		)
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
			and is_equal_approx(
				float((combo.get("effect", {}) as Dictionary).get("combo_duration", 99.0)),
				1.5
			),
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
	_expect(
		game.has_method("_get_auto_attack_hit_half_width"),
		"Automatic attacks must expose one authoritative hit width derived from their visible size."
	)
	var player := game.get("player") as Node2D
	var forward_target := DamageTarget.new()
	forward_target.position = player.global_position + Vector2(100.0, 0.0)
	root.add_child(forward_target)
	var rear_target := DamageTarget.new()
	rear_target.position = player.global_position + Vector2(-100.0, 0.0)
	root.add_child(rear_target)
	player.call("set_facing_direction", 1)
	if game.has_method("_get_auto_attack_hit_half_width"):
		var enlarged_half_width := float(game.call(
			"_get_auto_attack_hit_half_width",
			basic_attack
		))
		var enlarged_visual_target := DamageTarget.new()
		enlarged_visual_target.global_position = (
			player.global_position + Vector2(160.0, 40.0)
		)
		root.add_child(enlarged_visual_target)
		var enlarged_match := game.call(
			"_match_targets_to_attack_directions",
			[enlarged_visual_target],
			1,
			0.0,
			260.0,
			enlarged_half_width
		) as Array
		_expect(
			enlarged_half_width >= 88.0
				and enlarged_match.size() == 1
				and enlarged_match[0] == enlarged_visual_target,
			"An enemy swept by a doubled Combo attack must be inside the matching damage corridor."
		)
		var outside_visual_target := DamageTarget.new()
		outside_visual_target.global_position = (
			player.global_position + Vector2(160.0, 103.0)
		)
		root.add_child(outside_visual_target)
		var outside_match := game.call(
			"_match_targets_to_attack_directions",
			[outside_visual_target], 1, 0.0, 260.0, enlarged_half_width
		) as Array
		_expect(
			outside_match.size() == 1 and outside_match[0] == null,
			"An enemy beyond the enlarged Combo edge must remain outside its damage corridor."
		)
		var range_edge_target := DamageTarget.new()
		range_edge_target.global_position = (
			player.global_position + Vector2(260.0, 40.0)
		)
		root.add_child(range_edge_target)
		var range_edge_match := game.call(
			"_match_targets_to_attack_directions",
			[range_edge_target], 1, 0.0, 260.0, enlarged_half_width
		) as Array
		var range_edge_endpoint := game.call(
			"_auto_attack_target_endpoint",
			range_edge_target, 0, 1, 0.0, 260.0
		) as Vector2
		_expect(
			range_edge_match.size() == 1
				and range_edge_match[0] == range_edge_target
				and range_edge_endpoint.is_equal_approx(
					game.call("_auto_attack_origin") + Vector2(260.0, 0.0)
				),
			"Range and VFX endpoint must use the same forward projection for off-axis targets."
		)
		enlarged_visual_target.queue_free()
		outside_visual_target.queue_free()
		range_edge_target.queue_free()
	var forward_assignments := game.call(
		"_match_targets_to_attack_directions",
		[rear_target, forward_target],
		1,
		0.0,
		260.0
	) as Array
	_expect(
		forward_assignments.size() == 1
			and forward_assignments[0] == forward_target,
		"A single projectile must use player facing and must not auto-target an enemy behind."
	)
	var forward_aim := game.call("_auto_attack_direction_endpoint", 0, 1, 0.0, 260.0) as Vector2
	player.call("set_facing_direction", -1)
	var backward_aim := game.call("_auto_attack_direction_endpoint", 0, 1, 0.0, 260.0) as Vector2
	_expect(
		forward_aim.x > player.global_position.x
			and backward_aim.x < player.global_position.x
			and is_equal_approx(forward_aim.y, backward_aim.y),
		"Projectile endpoints must be fixed by player facing rather than enemy positions."
	)
	var off_ray_target := Node2D.new()
	root.add_child(off_ray_target)
	off_ray_target.global_position = player.global_position + Vector2(200.0, 80.0)
	player.call("set_facing_direction", 1)
	var off_ray_match := game.call(
		"_match_targets_to_attack_directions",
		[off_ray_target],
		1,
		0.0,
		260.0
	) as Array
	_expect(
		off_ray_match.size() == 1 and off_ray_match[0] == null,
		"A straight projectile must not damage an enemy far outside its visible flight corridor."
	)
	var below_target := DamageTarget.new()
	root.add_child(below_target)
	below_target.global_position = player.global_position + Vector2(0.0, 180.0)
	var downward_match := game.call(
		"_match_targets_to_attack_directions",
		[below_target],
		1,
		0.0,
		260.0
	) as Array
	_expect(
		downward_match.size() == 1 and downward_match[0] == null,
		"Horizontal combat must not auto-hit enemies on a platform below."
	)
	var radial_target := DamageTarget.new()
	root.add_child(radial_target)
	radial_target.global_position = player.global_position + Vector2(-80.0, 0.0)
	_expect(
		bool(game.call(
			"_is_target_in_auto_attack_shape",
			radial_target,
			database.get_card("cleave"),
			120.0,
			53.0
		))
			and not bool(game.call(
				"_is_target_in_auto_attack_shape",
				radial_target,
				database.get_card("ember_bolt"),
				260.0,
				53.0
			)),
		"Radial and directional attacks must use their own shapes instead of one shared rectangle."
	)
	forward_target.queue_free()
	rear_target.queue_free()

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
		not bool(((run.temporary_buffs.get("infusion_effects", []) as Array)[0] as Dictionary).get(
			"persistent",
			true
		)),
		"Projectile Combo effects must use their own short timer."
	)
	game.call("_tick_combo_effects", 1.49)
	_expect(
		not (run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(),
		"Projectile Combo effects must remain active immediately before 1.5 seconds."
	)
	game.call("_tick_combo_effects", 0.02)
	_expect(
		(run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(),
		"Projectile amount and spread must disappear after their own 1.5-second timer."
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
			and feedback.has_method("get_travel_offset")
			and (feedback.call("get_travel_offset") as Vector2).is_equal_approx(
				Vector2(180.0, 40.0)
			)
			and not feedback.has_method("get_homing_strength"),
		"Feedback must preserve its fixed firing endpoint instead of rotating or tracking it."
	)

	feedback.queue_free()
	off_ray_target.queue_free()
	below_target.queue_free()
	radial_target.queue_free()
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
