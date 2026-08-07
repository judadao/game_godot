extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/FirePillarFieldController.tscn")

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
	var target := TestTarget.new()
	root.add_child(target)
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.call("configure", caster, func() -> Array: return [target], {
		"pillar_count": 5, "field_radius": 360.0, "eruption_interval": 0.18,
		"damage_per_pillar": 9, "tier_rank": 1, "random_seed": 42,
	})
	controller.call("advance", 2.0)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("pillar_count", 0)) == 5 and int(state.get("erupted_count", 0)) == 5, "Basic Fire must erupt five discontinuous pillars.")
	_expect((state.get("eruption_positions", []) as Array).size() == 5, "Every fire pillar needs an authored world position for VFX.")
	_expect(target.damage_taken > 0, "Fire pillars must deal damage when erupting near a target.")
	if _failures == 0:
		print("PASS: Fire series erupts staggered random ground pillars")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
