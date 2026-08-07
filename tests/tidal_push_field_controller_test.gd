extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/TidalPushFieldController.tscn")

var _failures := 0


class TestTarget:
	extends CharacterBody2D
	var damage_taken := 0
	func take_hit(amount: int, _source: Vector2, _knockback := 0.0) -> int:
		damage_taken += amount
		return amount


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := Node2D.new()
	root.add_child(caster)
	var target := TestTarget.new()
	target.position = Vector2(80, 0)
	root.add_child(target)
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.call("configure", caster, func() -> Array: return [target], {
		"duration": 2.4, "radius": 340.0, "tick_interval": 0.20,
		"push_distance": 120.0, "damage_per_tick": 3, "tier_rank": 3,
	})
	controller.call("advance", 3.0)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(target.damage_taken > 0, "The wave must damage enemies throughout the push.")
	_expect(float(state.get("applied_push_distance", 0.0)) <= 140.0, "Wave displacement must stay capped inside useful auto-attack range.")
	_expect(target.position.x > 80.0, "The wave must push enemies outward from the player.")
	if _failures == 0:
		print("PASS: Water Flow applies damaging capped outward push over time")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
