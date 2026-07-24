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
const ANIMATION_ATTACK: StringName = &"attack"

const IDLE_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png")
const RUN_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Run/Run-Sheet.png")
const JUMP_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Jumlp-All/Jump-All-Sheet.png")
const ATTACK_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Attack-01/Attack-01-Sheet.png")

@export var speed: float = 260.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0
@export var attack_recovery: float = 0.25
@export var level: int = 1
@export var character_class: String = "Adventurer"
@export var experience: int = 0
@export var experience_to_next_level: int = 100

@onready var visual: Node2D = get_node_or_null("Visual") as Node2D
@onready var character_sprite: Sprite2D = get_node_or_null("Visual/CharacterSprite") as Sprite2D
@onready var interaction_detector: Area2D = get_node_or_null("InteractionDetector") as Area2D
@onready var attack_origin: Marker2D = get_node_or_null("AttackOrigin") as Marker2D

var facing_direction: int = 1
var current_state: StringName = STATE_IDLE
var _attack_cooldown: float = 0.0
var _animation_name: StringName = &""
var _animation_elapsed: float = 0.0
var _attack_animation_active: bool = false
var input_enabled: bool = true

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
	_update_character_animation(delta)

func get_move_direction() -> float:
	if not input_enabled:
		return 0.0

	var direction := 0.0
	if _is_action_pressed(ACTION_MOVE_LEFT, [FALLBACK_MOVE_LEFT]):
		direction -= 1.0
	if _is_action_pressed(ACTION_MOVE_RIGHT, [FALLBACK_MOVE_RIGHT]):
		direction += 1.0

	return clampf(direction, -1.0, 1.0)

func set_input_enabled(is_enabled: bool) -> void:
	input_enabled = is_enabled
	if input_enabled:
		return
	velocity.x = 0.0
	_attack_animation_active = false
	_update_state(0.0)

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
	_attack_animation_active = true
	_play_animation(ANIMATION_ATTACK)
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

func _update_character_animation(delta: float) -> void:
	if character_sprite == null:
		return

	var target_animation := current_state
	if _attack_animation_active:
		target_animation = ANIMATION_ATTACK

	_play_animation(target_animation)
	_animation_elapsed += delta

	var fps := _get_animation_fps(_animation_name)
	var frame_count := character_sprite.hframes
	var next_frame := int(_animation_elapsed * fps)

	if _animation_name == ANIMATION_ATTACK and next_frame >= frame_count:
		_attack_animation_active = false
		_play_animation(current_state)
		return

	character_sprite.frame = next_frame % frame_count

func _play_animation(animation_name: StringName) -> void:
	if character_sprite == null or animation_name == _animation_name:
		return

	_animation_name = animation_name
	_animation_elapsed = 0.0
	character_sprite.frame = 0

	match animation_name:
		STATE_WALK:
			character_sprite.texture = RUN_TEXTURE
			character_sprite.hframes = 8
		STATE_JUMP:
			character_sprite.texture = JUMP_TEXTURE
			character_sprite.hframes = 15
		ANIMATION_ATTACK:
			character_sprite.texture = ATTACK_TEXTURE
			character_sprite.hframes = 8
		_:
			character_sprite.texture = IDLE_TEXTURE
			character_sprite.hframes = 4

func _get_animation_fps(animation_name: StringName) -> float:
	match animation_name:
		STATE_WALK:
			return 12.0
		STATE_JUMP:
			return 15.0
		ANIMATION_ATTACK:
			return 14.0
		_:
			return 5.0

func _is_action_pressed(action: StringName, fallback_actions: Array[StringName] = []) -> bool:
	if not input_enabled:
		return false
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true

	for fallback_action in fallback_actions:
		if InputMap.has_action(fallback_action) and Input.is_action_pressed(fallback_action):
			return true

	return false

func _is_action_just_pressed(action: StringName, fallback_actions: Array[StringName] = []) -> bool:
	if not input_enabled:
		return false
	if InputMap.has_action(action) and Input.is_action_just_pressed(action):
		return true

	for fallback_action in fallback_actions:
		if InputMap.has_action(fallback_action) and Input.is_action_just_pressed(fallback_action):
			return true

	return false
