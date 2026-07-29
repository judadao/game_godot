class_name ExperienceGem
extends Area2D

signal collected(value: int)

@export var attraction_radius := 72.0
@export var pickup_radius := 30.0
@export var minimum_speed := 180.0
@export var maximum_speed := 520.0

var _value := 1
var _target: Node2D
var _collected := false
var _launch_velocity := Vector2.ZERO
var _launch_remaining := 0.0
var _launch_ground_y := 0.0
var _visual_time := 0.0

@onready var back_glow: Polygon2D = $BackGlow
@onready var visual: Polygon2D = $Visual
@onready var sparkle: Polygon2D = $Sparkle


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	advance_pickup(delta)


func _process(delta: float) -> void:
	_visual_time += maxf(0.0, delta)
	var pulse := 1.0 + sin(_visual_time * 7.0) * 0.12
	back_glow.scale = Vector2.ONE * pulse
	back_glow.rotation = -_visual_time * 0.9
	visual.scale = Vector2.ONE * lerpf(0.96, 1.06, (pulse - 0.88) / 0.24)
	sparkle.rotation = _visual_time * 1.8
	sparkle.modulate.a = 0.72 + sin(_visual_time * 9.0) * 0.24


func configure(value: int, target: Node2D = null) -> void:
	_value = maxi(1, value)
	_target = target


func launch(initial_velocity: Vector2, duration: float = 0.25) -> void:
	_launch_velocity = initial_velocity
	_launch_remaining = maxf(0.0, duration)
	_launch_ground_y = global_position.y


func advance_pickup(delta: float) -> void:
	if _collected:
		return
	var safe_delta := maxf(0.0, delta)
	if _launch_remaining > 0.0:
		var launch_step := minf(safe_delta, _launch_remaining)
		global_position += _launch_velocity * launch_step
		_launch_velocity.x = move_toward(_launch_velocity.x, 0.0, 360.0 * launch_step)
		_launch_velocity.y += 980.0 * launch_step
		_launch_remaining = maxf(0.0, _launch_remaining - launch_step)
		if _launch_remaining > 0.0:
			return
		global_position.y = _launch_ground_y
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
	global_position = global_position.move_toward(_target.global_position, speed * safe_delta)


func collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collected.emit(_value)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body == _target or body.is_in_group("Player"):
		collect()
