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
	for card_id in ["seeking_arc", "echo_volley"]:
		var combo := database.get_card(card_id)
		_expect(
			String(combo.get("type", "")) == "combo"
				and String(combo.get("combo_family", "")) == "offense"
				and float((combo.get("effect", {}) as Dictionary).get("combo_duration", 99.0)) <= 2.5,
			"%s must be a short offensive Combo card." % card_id
		)

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"seeking_arc", "echo_volley", "guard", "healing_light",
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
		bool(game.call("_resolve_combo_card", database.get_card("seeking_arc"))),
		"Forked Arc must activate additional attack directions."
	)
	_expect(
		bool(game.call("_resolve_combo_card", database.get_card("echo_volley"))),
		"Echo Volley must activate projectile amount."
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
		"Direction count and per-direction projectile amount must come from separate Combo cards."
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
	var expected_projectiles := int(modified_effect.get("projectile_count", 1))
	_expect(
		int(volley_result.get("affected", 0)) == expected_directions
			and int(volley_result.get("total", 0))
				== int(modified_effect.get("amount", 0))
					* expected_directions
					* expected_projectiles,
		"Forked Arc must spread targets by direction while Echo Volley repeats each direction."
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
		{"direction_count": 3, "direction_index": 1}
	)
	_expect(
		feedback.has_method("get_direction_count")
			and int(feedback.call("get_direction_count")) == 3
			and not feedback.has_method("get_homing_strength"),
		"Direction Combo must reach the visible automatic-attack fan without homing."
	)

	feedback.queue_free()
	runner.queue_free()
	for target in damage_targets:
		(target as Node).queue_free()
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
