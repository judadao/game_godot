extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/BodyOverdriveController.tscn")

var _failures := 0


class TestCaster:
	extends Node2D

	var move_multiplier := 1.0
	var attack_multiplier := 1.0
	var move_duration := 0.0
	var attack_duration := 0.0

	func apply_temporary_move_speed(multiplier: float, duration: float) -> void:
		move_multiplier = multiplier
		move_duration = duration

	func apply_temporary_attack_speed(multiplier: float, duration: float) -> void:
		attack_multiplier = multiplier
		attack_duration = duration


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := TestCaster.new()
	root.add_child(caster)
	var controller := CONTROLLER_SCENE.instantiate()
	caster.add_child(controller)
	_expect(controller.call("configure", caster, {
		"duration": 7.0,
		"move_speed_multiplier": 1.80,
		"attack_speed_multiplier": 1.75,
		"afterimage_count": 8,
		"tier_rank": 3,
	}), "Shared Branch body overdrive must configure on the player.")
	var state := controller.call("get_debug_state") as Dictionary
	_expect(caster.move_multiplier == 1.80 and caster.move_duration == 7.0, "Body overdrive must greatly increase movement speed for its full duration.")
	_expect(caster.attack_multiplier == 1.75 and caster.attack_duration == 7.0, "Body overdrive must greatly increase automatic attack speed.")
	_expect(int(state.get("afterimage_count", 0)) == 8, "Master body overdrive must author a dense afterimage trail.")
	controller.call("advance", 2.5)
	state = controller.call("get_debug_state") as Dictionary
	_expect(float(state.get("remaining_seconds", 0.0)) <= 4.5, "Body overdrive must expose a finite remaining duration.")
	if _failures == 0:
		print("PASS: Shared Branch strengthens the player with aura, speed, and afterimage parameters")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
