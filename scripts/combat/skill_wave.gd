extends Area2D

@export var speed: float = 520.0
@export var damage: int = 24
@export var lifetime: float = 0.75
var direction: int = 1
var _hit_targets: Dictionary = {}


func setup(facing: int, skill_damage: int) -> void:
	direction = signi(facing) if facing != 0 else 1
	damage = skill_damage
	scale.x = float(direction)


func _physics_process(delta: float) -> void:
	position.x += speed * float(direction) * delta
	lifetime -= delta
	for area in get_overlapping_areas():
		if area.has_method("receive_hit") and not _hit_targets.has(area):
			_hit_targets[area] = true
			area.call("receive_hit", damage, global_position, 260.0)
	if lifetime <= 0.0:
		queue_free()
