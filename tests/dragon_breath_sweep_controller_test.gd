extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/DragonBreathSweepController.tscn")

var _failures := 0


class TestTarget:
	extends Node2D

	var damage_taken := 0

	func take_hit(amount: int, _source: Vector2, _knockback := 0.0) -> int:
		damage_taken += maxi(0, amount)
		return maxi(0, amount)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := Node2D.new()
	root.add_child(caster)
	var targets: Array = []
	for x in [-240.0, -80.0, 80.0, 240.0]:
		var target := TestTarget.new()
		target.position = Vector2(x, 0.0)
		root.add_child(target)
		targets.append(target)
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	_expect(controller.call("configure", caster, func() -> Array: return targets, {
		"side_sweep_count": 2,
		"side_sweep_duration": 0.9,
		"rain_emitter_count": 20,
		"rain_duration": 1.5,
		"range": 460.0,
		"damage_per_sweep": 12,
		"damage_per_rain_hit": 3,
		"tier_rank": 3,
	}), "Dragon Breath must configure its master pattern.")
	controller.call("advance", 3.0)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("side_sweep_count", 0)) == 2, "Master Dragon Breath must keep two side sweeps.")
	_expect(int(state.get("rain_emitter_count", 0)) == 20, "Master Dragon Breath must form a twenty-head upper row.")
	_expect(is_equal_approx(float(state.get("rain_duration", 0.0)), 1.5), "The downward breath phase must last 1.5 seconds.")
	_expect(int(state.get("resolved_side_sweeps", 0)) == 2, "Both left and right sweep layers must resolve.")
	_expect(int(state.get("resolved_rain_emitters", 0)) == 20, "Every upper-row emitter must participate in the master rain.")
	_expect((targets[0] as TestTarget).damage_taken > 0 and (targets[3] as TestTarget).damage_taken > 0, "The 180-degree sweep must cover both sides without moving the player.")
	if _failures == 0:
		print("PASS: Dragon Breath resolves 1/2/2+20 layered sweep patterns")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
