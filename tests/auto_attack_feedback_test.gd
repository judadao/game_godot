extends SceneTree

const FEEDBACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var feedback := FEEDBACK_SCENE.instantiate()
	root.add_child(feedback)
	await process_frame
	feedback.play(
		Vector2(40.0, 80.0),
		Vector2(240.0, 80.0),
		24,
		6,
		8,
		false,
		1.5,
		1.4,
		{
			"stack_count": 6,
			"elements": ["flame", "frost", "storm", "venom"],
			"lifesteal": true,
		}
	)
	_expect(feedback.is_in_group("AutoAttackFeedback"), "Attack feedback must be discoverable for runtime verification.")
	_expect(feedback.get_damage_text() == "-24", "Attack feedback must show actual applied damage.")
	_expect(
		feedback.get_combo_text().contains("COMBO ×6")
			and feedback.get_combo_text().contains("POWER +8"),
		"Attack feedback must make the active Combo power visible."
	)
	_expect(
		int(feedback.call("get_visual_layer_count")) >= 4
			and float(feedback.call("get_attack_scale")) > 1.4,
		"Stacked elemental Combo effects must add visible projectile layers and scale."
	)
	await create_timer(0.2).timeout
	_expect(
		(feedback.get_node("DamageLabel") as Label).visible
			and (feedback.get_node("ComboLabel") as Label).visible,
		"Damage and Combo labels must appear when the projectile reaches its target."
	)
	await create_timer(0.4).timeout
	_expect(not is_instance_valid(feedback), "Short combat feedback must clean itself up.")
	if _failures == 0:
		print("PASS: visible Basic Attack travel, hit, damage, and Combo feedback")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
