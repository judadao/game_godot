extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/ResidualLightningController.tscn")

var _failures := 0


class TestTarget:
	extends Node2D
	var damage_taken := 0
	func take_hit(amount: int, _source: Vector2, _knockback := 0.0) -> int:
		damage_taken += amount
		return amount


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := Node2D.new()
	root.add_child(caster)
	var targets: Array = []
	for index in 35:
		var target := TestTarget.new()
		target.position = Vector2(float(index * 10), 0.0)
		root.add_child(target)
		targets.append(target)
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.call("configure", caster, func() -> Array: return targets, {
		"marked_target_limit": 30, "residual_duration": 1.2,
		"chain_interval": 0.12, "residual_damage": 2,
		"final_strike_damage": 18, "tier_rank": 3,
	})
	controller.call("advance", 2.0)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("marked_target_count", 0)) == 30, "Master Lightning must mark at most thirty enemies.")
	_expect(int(state.get("final_strike_count", 0)) == 30, "Every surviving residual mark must receive a sky strike.")
	_expect((targets[0] as TestTarget).damage_taken > (targets[34] as TestTarget).damage_taken, "Marked enemies must take residual and final lightning while unmarked enemies remain untouched.")
	if _failures == 0:
		print("PASS: Lightning chains residual marks and finishes with delayed sky strikes")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
