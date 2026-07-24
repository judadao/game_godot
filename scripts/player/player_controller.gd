extends CharacterBody2D

@export var speed: float = 260.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0

func _physics_process(delta: float) -> void:
	var direction := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction += 1.0

	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_W) or Input.is_action_just_pressed("ui_up"):
		velocity.y = jump_velocity

	move_and_slide()
