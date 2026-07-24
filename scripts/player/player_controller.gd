extends CharacterBody2D

signal attack_started(origin: Vector2, direction: Vector2)
signal state_changed(state: StringName)

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
const ACTION_ATTACK: StringName = &"attack"
const FALLBACK_MOVE_LEFT: StringName = &"ui_left"
const FALLBACK_MOVE_RIGHT: StringName = &"ui_right"
const FALLBACK_JUMP: StringName = &"ui_accept"
const FALLBACK_JUMP_ALT: StringName = &"ui_up"
const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_JUMP: StringName = &"jump"

@export var speed: float = 260.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0
@export var attack_recovery: float = 0.25

@onready var visual: Node2D = get_node_or_null("Visual") as Node2D
@onready var interaction_detector: Area2D = get_node_or_null("InteractionDetector") as Area2D
@onready var attack_origin: Marker2D = get_node_or_null("AttackOrigin") as Marker2D

var facing_direction: int = 1
var current_state: StringName = STATE_IDLE
var _attack_cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	_tick_attack_cooldown(delta)

	var direction := get_move_direction()
	if direction != 0.0:
		set_facing_direction(signi(direction))

	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif _is_action_just_pressed(ACTION_JUMP, [FALLBACK_JUMP, FALLBACK_JUMP_ALT]):
		velocity.y = jump_velocity

	if _is_action_just_pressed(ACTION_ATTACK):
		attack()

	move_and_slide()
	_update_state(direction)

func get_move_direction() -> float:
	var direction := 0.0
	if _is_action_pressed(ACTION_MOVE_LEFT, [FALLBACK_MOVE_LEFT]):
		direction -= 1.0
	if _is_action_pressed(ACTION_MOVE_RIGHT, [FALLBACK_MOVE_RIGHT]):
		direction += 1.0

	return clampf(direction, -1.0, 1.0)

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return

	facing_direction = signi(direction)
	if visual != null:
		visual.scale.x = float(facing_direction)
	if attack_origin != null:
		attack_origin.position.x = absf(attack_origin.position.x) * float(facing_direction)
	if interaction_detector != null:
		interaction_detector.position.x = absf(interaction_detector.position.x) * float(facing_direction)

func attack() -> bool:
	if _attack_cooldown > 0.0:
		return false

	_attack_cooldown = attack_recovery
	var origin := global_position
	if attack_origin != null:
		origin = attack_origin.global_position

	attack_started.emit(origin, Vector2(facing_direction, 0.0))
	return true

func _tick_attack_cooldown(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

func _update_state(direction: float) -> void:
	var next_state := STATE_IDLE
	if not is_on_floor():
		next_state = STATE_JUMP
	elif direction != 0.0:
		next_state = STATE_WALK

	if next_state == current_state:
		return

	current_state = next_state
	state_changed.emit(current_state)

func _is_action_pressed(action: StringName, fallback_actions: Array[StringName] = []) -> bool:
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true

	for fallback_action in fallback_actions:
		if InputMap.has_action(fallback_action) and Input.is_action_pressed(fallback_action):
			return true

	return false

func _is_action_just_pressed(action: StringName, fallback_actions: Array[StringName] = []) -> bool:
	if InputMap.has_action(action) and Input.is_action_just_pressed(action):
		return true

	for fallback_action in fallback_actions:
		if InputMap.has_action(fallback_action) and Input.is_action_just_pressed(fallback_action):
			return true

	return false
