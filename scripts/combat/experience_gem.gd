class_name ExperienceGem
extends Area2D

signal collected(value: int)

@export var attraction_radius := 180.0
@export var pickup_radius := 30.0
@export var minimum_speed := 180.0
@export var maximum_speed := 520.0

var _value := 1
var _target: Node2D
var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	advance_pickup(delta)


func configure(value: int, target: Node2D = null) -> void:
	_value = maxi(1, value)
	_target = target


func advance_pickup(delta: float) -> void:
	if _collected:
		return
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("Player") as Node2D
	if _target == null:
		return
	var distance := global_position.distance_to(_target.global_position)
	if distance <= pickup_radius:
		collect()
		return
	if distance > attraction_radius:
		return
	var pull := 1.0 - distance / attraction_radius
	var speed := lerpf(minimum_speed, maximum_speed, pull)
	global_position = global_position.move_toward(_target.global_position, speed * maxf(0.0, delta))


func collect() -> void:
	if _collected:
		return
	_collected = true
	monitoring = false
	monitorable = false
	collected.emit(_value)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body == _target or body.is_in_group("Player"):
		collect()
