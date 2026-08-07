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
	controller.call("advance", 2.0)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("wheel_count", 0)) == 5, "Basic Moon Wheel must launch five readable wheels.")
	_expect(int(state.get("round_trip_count", 0)) == 1 and int(state.get("resolved_pass_count", 0)) == 2, "One round trip must resolve an outbound and a returning damage pass.")
	_expect(target.hit_count >= 2, "Moon Wheel must damage on both directions of the bounce.")
	if _failures == 0:
		print("PASS: Moon Wheel bounces five wheels through one basic round trip")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
