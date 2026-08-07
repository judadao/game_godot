extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/DrStoneDroneController.tscn")

var _failures := 0
var _targets: Array = []


class TestTarget:
	extends CharacterBody2D

	var damage_taken := 0
	var hit_count := 0


	func take_hit(raw_damage: int, _source: Vector2, _knockback: float = 0.0) -> int:
		damage_taken += maxi(0, raw_damage)
		hit_count += 1
		return maxi(0, raw_damage)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := Node2D.new()
	root.add_child(caster)
	var target := TestTarget.new()
	target.position = Vector2(140.0, 0.0)
	root.add_child(target)
	_targets = [target]
	var controller := CONTROLLER_SCENE.instantiate()
	caster.add_child(controller)
	_expect(bool(controller.call("configure", caster, Callable(self, "_provide_targets"), {
		"drone_count": 3, "duration": 1.2, "attack_interval": 0.30,
		"attack_range": 300.0, "damage_per_shot": 4, "tier_rank": 1,
	})), "DR. Stone must create its basic drone formation.")
	controller.call("advance", 0.65)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("active_drone_count", 0)) == 3, "Basic DR. Stone must start with three active drones.")
	_expect(target.hit_count >= 2, "Stone drones must automatically acquire and attack nearby enemies.")
	controller.call("advance", 0.70)
	state = controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("active_drone_count", 0)) == 0 and int(state.get("crashed_drone_count", 0)) == 3, "Drones must crash after their authored lifetime.")
	controller.call("configure", caster, Callable(self, "_provide_targets"), {
		"drone_count": 6, "duration": 2.0, "attack_interval": 0.24,
		"attack_range": 360.0, "damage_per_shot": 6, "tier_rank": 2,
	})
	state = controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("active_drone_count", 0)) == 6 and int(state.get("refill_generation", 0)) == 2, "Recasting must replenish and upgrade the existing squad instead of stacking another controller.")
	controller.queue_free()
	caster.queue_free()
	target.queue_free()
	await process_frame

	var effect_scene := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var previous_count := 0
	for tier in range(1, 4):
		var effect := effect_scene.instantiate()
		root.add_child(effect)
		effect.call("play_series", "dr_stone", tier, 1, false, 1.0)
		var visual := effect.call("get_dr_stone_vfx_state") as Dictionary
		_expect(String(visual.get("renderer", "")) == "blessing_mutable_stone_drone_squad", "DR. Stone needs a dedicated mutable drone renderer.")
		_expect((visual.get("layer_ids", []) as Array) == ["stone_core", "levitation_runes", "thruster_debris", "shot_trails", "impact_bursts", "crash_sequence"], "Drone VFX must include flight, fire, impact, and crash layers.")
		_expect(bool(visual.get("blessing_mutable", false)), "Drone projectile, trail, impact, and material layers must be Blessing-mutable.")
		var count := int(visual.get("drone_count", 0))
		_expect(count > previous_count, "DR. Stone must add more drones every tier.")
		previous_count = count
		effect.queue_free()
		await process_frame
	_finish()


func _provide_targets() -> Array:
	return _targets.duplicate()


func _finish() -> void:
	if _failures == 0:
		print("PASS: DR. Stone drones auto-fire, crash, and replenish")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
