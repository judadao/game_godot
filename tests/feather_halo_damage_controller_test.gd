extends SceneTree

class DamageTarget:
	extends Node2D
	var hit_count := 0
	var damage_total := 0
	var last_knockback := 0.0

	func take_hit(damage: int, _source: Vector2, knockback: float = 0.0) -> int:
		hit_count += 1
		damage_total += damage
		last_knockback = knockback
		return damage


var _failures := 0
var _targets: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(
		"res://scenes/combat/FeatherHaloDamageController.tscn"
	) as PackedScene
	_expect(packed != null, "Feather needs a reusable contact-field gameplay controller.")
	if packed == null:
		_finish()
		return
	var caster := Node2D.new()
	var controller := packed.instantiate()
	var nearby := DamageTarget.new()
	var distant := DamageTarget.new()
	root.add_child(caster)
	caster.add_child(controller)
	root.add_child(nearby)
	root.add_child(distant)
	caster.global_position = Vector2.ZERO
	nearby.global_position = Vector2(120.0, 0.0)
	distant.global_position = Vector2(420.0, 0.0)
	_targets.assign([nearby, distant])
	_expect(controller.has_method("configure") and controller.has_method("advance"), "Feather contact field needs deterministic configure and advance APIs.")
	controller.call("configure", caster, Callable(self, "_provide_targets"), {
		"duration": 4.8,
		"radius": 176.0,
		"tick_interval": 0.30,
		"damage_per_tick": 5,
		"knockback": 115.0,
		"feather_count": 3,
	})
	controller.call("advance", 0.91)
	_expect(nearby.hit_count >= 3, "Enemies touching the rotating feathers must take repeated damage for the halo duration.")
	_expect(nearby.last_knockback >= 100.0, "Every contact tick must keep pushing nearby enemies away from the player.")
	_expect(distant.hit_count == 0, "Feather contact damage must not become a target-seeking ranged projectile.")
	var before_refresh := float((controller.call("get_debug_state") as Dictionary).get("remaining_seconds", 0.0))
	controller.call("configure", caster, Callable(self, "_provide_targets"), {
		"duration": 6.4,
		"radius": 204.0,
		"tick_interval": 0.30,
		"damage_per_tick": 7,
		"knockback": 132.0,
		"feather_count": 7,
	})
	var refreshed := controller.call("get_debug_state") as Dictionary
	_expect(float(refreshed.get("remaining_seconds", 0.0)) > before_refresh, "Casting Feather quickly must refresh and extend the existing contact field.")
	_expect(int(refreshed.get("feather_count", 0)) == 7, "More feathers must produce the longer advanced field instead of a second controller.")
	_expect(String(refreshed.get("attack_mode", "")) == "orbit_contact", "Feathers must attack by orbit contact, never by homing toward enemies.")
	caster.queue_free()
	nearby.queue_free()
	distant.queue_free()
	await process_frame
	_finish()


func _provide_targets() -> Array:
	return _targets.duplicate()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Feather halo continuously damages and pushes touching enemies")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
