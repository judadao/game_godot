extends SceneTree

const TARGET_ADAPTER := preload("res://scripts/combat/combat_target_adapter.gd")

var _failures := 0


class HitTarget:
	extends Node2D
	var received_source := Vector2.ZERO
	var received_knockback := 0.0

	func take_hit(amount: int, source: Vector2, knockback: float) -> int:
		received_source = source
		received_knockback = knockback
		return amount


class DamageTarget:
	extends Node2D
	var damage_taken := 0

	func take_damage(amount: int) -> int:
		damage_taken += amount
		return amount


func _init() -> void:
	var source := Vector2(12.0, 34.0)
	var hit_target := HitTarget.new()
	_expect(TARGET_ADAPTER.deal_damage(hit_target, 7, source, 55.0) == 7, "Combat target adapter must prefer the full take_hit contract.")
	_expect(hit_target.received_source == source and is_equal_approx(hit_target.received_knockback, 55.0), "Combat target adapter must preserve source and knockback.")
	var damage_target := DamageTarget.new()
	_expect(TARGET_ADAPTER.deal_damage(damage_target, 9, source, 80.0) == 9 and damage_target.damage_taken == 9, "Combat target adapter must support the take_damage compatibility fallback.")
	var unsupported := Node2D.new()
	_expect(TARGET_ADAPTER.deal_damage(unsupported, 5, source, 20.0) == 0, "Unsupported combat targets must report zero damage.")
	_expect(TARGET_ADAPTER.deal_damage(null, 5, source, 20.0) == 0, "A released or missing combat target must be ignored safely.")
	hit_target.free()
	damage_target.free()
	unsupported.free()
	if _failures == 0:
		print("PASS: combat target damage dispatch is centralized without changing target contracts")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
