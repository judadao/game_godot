extends SceneTree

const WITCH_SCENE := preload("res://scenes/npc/town/FemaleVillager.tscn")
const TRAVELER_SCENE := preload("res://scenes/npc/town/MaleVillager.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var witch := WITCH_SCENE.instantiate() as TownNPCLife
	var traveler := TRAVELER_SCENE.instantiate() as TownNPCLife
	root.add_child(witch)
	root.add_child(traveler)
	await process_frame
	witch.set_process(false)
	traveler.set_process(false)
	_assert_direction_contract(witch, -1.0, "Witch")
	_assert_direction_contract(traveler, 1.0, "Traveler")
	witch.queue_free()
	traveler.queue_free()
	await process_frame
	_finish()


func _assert_direction_contract(
	actor: TownNPCLife,
	expected_native_sign: float,
	label: String
) -> void:
	var visual := actor.npc_visual
	var body := visual.body_sprite
	visual.ambient_enabled = false
	visual.play_state(&"walk")

	visual.set_facing_direction(1.0)
	var right_snapshot := visual.get_animation_snapshot()
	_expect(
		float(right_snapshot.get("native_directional_facing_sign", 1.0))
			== expected_native_sign,
		"%s must declare the atlas walk row's native direction." % label
	)
	_expect(
		body.flip_h == (expected_native_sign < 0.0),
		"%s moving right must render facing right rather than walking backward." % label
	)
	_expect(
		float(right_snapshot["facing_sign"]) > 0.0,
		"%s rightward velocity must retain a positive facing direction." % label
	)

	visual.set_facing_direction(-1.0)
	var left_snapshot := visual.get_animation_snapshot()
	_expect(
		body.flip_h == (expected_native_sign > 0.0),
		"%s moving left must render facing left rather than walking backward." % label
	)
	_expect(
		float(left_snapshot["facing_sign"]) < 0.0,
		"%s leftward velocity must retain a negative facing direction." % label
	)

	_assert_life_motion_direction(actor, expected_native_sign, 1.0, label)
	_assert_life_motion_direction(actor, expected_native_sign, -1.0, label)


func _assert_life_motion_direction(
	actor: TownNPCLife,
	native_sign: float,
	direction: float,
	label: String
) -> void:
	actor.position = actor.get_home_position()
	actor.set("_target_position", actor.position + Vector2(direction * 80.0, 0.0))
	actor.call("_set_state", &"wander")
	var previous_x := actor.position.x
	actor.advance_life(0.1)
	var velocity_sign := signf(actor.position.x - previous_x)
	var rendered_sign := native_sign * (-1.0 if actor.npc_visual.body_sprite.flip_h else 1.0)
	_expect(
		is_equal_approx(velocity_sign, direction),
		"%s TownNPCLife motion must advance in the requested direction." % label
	)
	_expect(
		is_equal_approx(rendered_sign, velocity_sign),
		"%s rendered walk direction must match its TownNPCLife velocity." % label
	)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC atlas-native facing matches movement direction")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
