class_name Hurtbox
extends Area2D

@export var receiver_path: NodePath = NodePath("..")


func receive_hit(damage: int, source_position: Vector2, knockback: float = 180.0) -> int:
	var receiver := get_node_or_null(receiver_path)
	if receiver != null and receiver.has_method("take_hit"):
		return int(receiver.call("take_hit", damage, source_position, knockback))
	return 0
