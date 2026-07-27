extends SceneTree

var _failures := 0


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
			and int(basic_effect.get("target_count", 1)) == 1
			and is_zero_approx(float(basic_attack.get("homing_strength", 0.0))),
		"Combo Chain alone must preserve the base attack's single non-homing projectile."
	)
	_expect(
		float(basic_attack.get("attack_size_multiplier", 1.0)) >= 2.0,
		"Combo Chain may still amplify damage, range, and spectacle."
	)

	run.temporary_buffs["combo_chain_count"] = 0
	_expect(
		bool(game.call("_resolve_combo_card", database.get_card("seeking_arc"))),
		"Seeking Arc must activate tracking."
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
		float(modified_attack.get("homing_strength", 0.0)) > 0.0
			and int(modified_effect.get("projectile_count", 1)) >= 2
			and int(modified_effect.get("target_count", 1)) >= 2,
		"Tracking and amount must come only from their active Combo cards."
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
		{"homing_strength": 0.8}
	)
	_expect(
		feedback.has_method("get_homing_strength")
			and float(feedback.call("get_homing_strength")) >= 0.8,
		"Tracking Combo must reach the visible automatic-attack trajectory."
	)

	feedback.queue_free()
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
