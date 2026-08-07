extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/BlackHoleFieldController.tscn")

var _failures := 0
var _targets: Array = []


class TestTarget:
	extends CharacterBody2D

	var health := 500
	var damage_taken := 0
	var hit_count := 0
	var last_source := Vector2.ZERO
	var last_knockback := 0.0


	func take_hit(raw_damage: int, source_position: Vector2, knockback: float = 0.0) -> int:
		var dealt := mini(health, maxi(0, raw_damage))
		health -= dealt
		damage_taken += dealt
		hit_count += 1
		last_source = source_position
		last_knockback = knockback
		return dealt


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := CONTROLLER_SCENE.instantiate() as Node2D
	root.add_child(controller)
	var near := TestTarget.new()
	near.position = Vector2(90.0, 0.0)
	root.add_child(near)
	var escaping := TestTarget.new()
	escaping.position = Vector2(120.0, 0.0)
	root.add_child(escaping)
	var outside := TestTarget.new()
	outside.position = Vector2(260.0, 0.0)
	root.add_child(outside)
	_targets = [near, escaping, outside]
	_expect(controller.has_method("configure") and controller.has_method("advance"), "Black Hole needs deterministic configure and advance APIs.")
	_expect(bool(controller.call("configure", Vector2.ZERO, Callable(self, "_provide_targets"), {
		"duration": 1.0,
		"radius": 180.0,
		"tick_interval": 0.25,
		"damage_per_tick": 3,
		"burst_damage": 24,
		"pull_strength": 120.0,
		"burst_knockback": 80.0,
		"tier_rank": 1,
	})), "Black Hole field must accept one authored combat profile.")
	controller.call("advance", 0.30)
	_expect(near.damage_taken >= 3 and near.hit_count >= 1, "Enemies in the event horizon must take repeated small damage while being pulled.")
	_expect(near.velocity.x < 0.0, "Enemies to the right of the core must be pulled toward its center.")
	_expect(outside.damage_taken == 0 and outside.velocity.is_zero_approx(), "Enemies outside the event horizon must remain untouched.")
	escaping.position = Vector2(230.0, 0.0)
	var escaping_damage_before := escaping.damage_taken
	controller.call("advance", 0.75)
	var state := controller.call("get_debug_state") as Dictionary
	_expect(bool(state.get("detonated", false)), "Black Hole must detonate once after its pull duration.")
	_expect(near.damage_taken >= 27, "Enemies still inside must take the large delayed detonation after the small ticks.")
	_expect(escaping.damage_taken == escaping_damage_before, "Enemies that escape before detonation must not take the final burst.")
	_expect(int(state.get("burst_hit_count", 0)) == 1, "The final burst must only count enemies still inside the radius.")
	controller.queue_free()
	near.queue_free()
	escaping.queue_free()
	outside.queue_free()
	await process_frame
	_finish()


func _provide_targets() -> Array:
	return _targets.duplicate()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Black Hole pulls, ticks, and detonates only inside its event horizon")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
