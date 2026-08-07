class_name CombatTargetAdapter
extends RefCounted


static func deal_damage(
	target: Node,
	amount: int,
	source: Vector2,
	knockback: float = 0.0
) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	if target.has_method("take_hit"):
		return int(target.call("take_hit", amount, source, knockback))
	if target.has_method("take_damage"):
		return int(target.call("take_damage", amount))
	return 0
