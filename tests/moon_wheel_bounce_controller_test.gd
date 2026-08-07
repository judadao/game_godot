extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/MoonWheelBounceController.tscn")

var _failures := 0


class TestTarget:
	extends Node2D
	var damage_taken := 0
	var hit_count := 0
	func take_hit(amount: int, _source: Vector2, _knockback := 0.0) -> int:
		damage_taken += amount
		hit_count += 1
		return amount


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := Node2D.new()
	root.add_child(caster)
	var target := TestTarget.new()
	target.position = Vector2(120, 0)
	root.add_child(target)
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.call("configure", caster, func() -> Array: return [target], {
		"wheel_count": 5, "round_trip_count": 1, "duration": 1.4,
		"range": 420.0, "damage_per_contact": 3, "tier_rank": 1,
	})
	controller.call("advance", 0.65)
	_expect(target.hit_count == 1, "The first rebound must land as a readable contact instead of resolving the whole pass on one frame.")
	controller.call("advance", 0.12)
	_expect(target.hit_count == 2, "The second wheel contact must follow after a short cadence gap.")
	controller.call("advance", 2.0)
	_expect(target.hit_count == 3, "A large delta must release only one overdue contact instead of collapsing the remaining volley into one frame.")
	var backlog_state := controller.call("get_debug_state") as Dictionary
	_expect(int(backlog_state.get("pending_contact_count", 0)) > 0, "Overdue Moon Wheel contacts must remain queued for later frames.")
	controller.call("advance", 0.0)
	controller.call("advance", 0.0)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("wheel_count", 0)) == 5, "Basic Moon Wheel must launch five readable wheels.")
	_expect(int(state.get("round_trip_count", 0)) == 1 and int(state.get("resolved_pass_count", 0)) == 2, "One round trip must resolve an outbound and a returning damage pass.")
	_expect(target.hit_count == 4, "Five basic wheels against one target must preserve two contacts on both directions of the bounce.")
	_expect(String(state.get("contact_cadence", "")) == "staggered_rebound_volley", "Moon Wheel impacts must expose their staggered rebound cadence.")
	_test_tier_contact_cap(caster, 8, 2, 2.2, 8)
	_test_tier_contact_cap(caster, 12, 3, 3.1, 12)
	_test_late_target_retarget(caster)
	if _failures == 0:
		print("PASS: Moon Wheel bounces five wheels through one basic round trip")
	quit(1 if _failures > 0 else 0)


func _test_tier_contact_cap(
	caster: Node2D,
	wheel_count: int,
	round_trip_count: int,
	duration: float,
	expected_hits: int
) -> void:
	var target := TestTarget.new()
	target.position = Vector2(120, 0)
	root.add_child(target)
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.call("configure", caster, func() -> Array: return [target], {
		"wheel_count": wheel_count,
		"round_trip_count": round_trip_count,
		"duration": duration,
		"range": 540.0,
		"damage_per_contact": 3,
		"tier_rank": round_trip_count,
	})
	controller.call("advance", duration + 0.1)
	for _step in wheel_count * round_trip_count * 2 + 2:
		controller.call("advance", 0.0)
	_expect(target.hit_count == expected_hits, "Moon Wheel tier %d must preserve its exact one-target damage contact cap." % round_trip_count)
	controller.queue_free()
	target.queue_free()


func _test_late_target_retarget(caster: Node2D) -> void:
	var live_targets: Array[Node2D] = []
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.call("configure", caster, func() -> Array[Node2D]: return live_targets, {
		"wheel_count": 5,
		"round_trip_count": 1,
		"duration": 1.4,
		"range": 420.0,
		"damage_per_contact": 3,
		"tier_rank": 1,
	})
	controller.call("advance", 0.74)
	var late_target := TestTarget.new()
	late_target.position = Vector2(100, 0)
	root.add_child(late_target)
	live_targets.append(late_target)
	controller.call("advance", 0.04)
	_expect(late_target.hit_count == 1, "A target entering during the remaining pass slots must be acquired by the next Moon Wheel contact.")
	controller.queue_free()
	late_target.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
