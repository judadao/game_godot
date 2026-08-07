extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/HealingZoneController.tscn")

var _failures := 0


class TestCaster:
	extends Node2D

	var health := 20
	var max_health := 100

	func restore_health(amount: int) -> int:
		var restored := mini(max_health - health, maxi(0, amount))
		health += restored
		return restored


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := TestCaster.new()
	root.add_child(caster)
	var controller := CONTROLLER_SCENE.instantiate()
	caster.add_child(controller)
	_expect(controller.call("configure", caster, {
		"duration": 6.0,
		"radius": 220.0,
		"pulse_interval": 0.75,
		"heal_per_pulse": 8,
		"tier_rank": 2,
	}), "Healing zone must configure around its caster.")
	controller.call("advance", 1.6)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(caster.health == 44, "Healing zone must pulse immediately and then at its authored interval.")
	_expect(int(state.get("pulse_count", 0)) == 3, "Healing zone must expose its repeated healing cadence.")
	_expect(float(state.get("radius", 0.0)) == 220.0, "Healing zone must preserve authored radius.")
	caster.position = Vector2(120, 30)
	_expect((controller as Node2D).global_position == caster.global_position, "Healing zone must remain under the player's feet while moving.")
	if _failures == 0:
		print("PASS: Dawn Vitality creates a persistent player-following healing zone")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
