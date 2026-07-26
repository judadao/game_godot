extends CharacterBody2D

signal state_changed(state: StringName)
signal resources_changed(health: int, max_health: int, mana: int, max_mana: int)
signal defeated

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
const FALLBACK_MOVE_LEFT: StringName = &"ui_left"
const FALLBACK_MOVE_RIGHT: StringName = &"ui_right"
const FALLBACK_JUMP: StringName = &"ui_accept"
const FALLBACK_JUMP_ALT: StringName = &"ui_up"
const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_JUMP: StringName = &"jump"

const IDLE_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png")
const RUN_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Run/Run-Sheet.png")
const JUMP_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Jumlp-All/Jump-All-Sheet.png")

@export var speed: float = 260.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0
@export var dash_distance: float = 150.0
@export var dash_cooldown: float = 0.65
@export var level: int = 1
@export var character_class: String = "Adventurer"
@export var experience: int = 0
@export var experience_to_next_level: int = 100
@export var max_health: int = 100
@export var health: int = 78
@export var max_mana: int = 50
@export var mana: int = 31
@export var attack_power: int = 16
@export var defense: int = 3

@onready var visual: Node2D = get_node_or_null("Visual") as Node2D
@onready var character_sprite: Sprite2D = get_node_or_null("Visual/CharacterSprite") as Sprite2D
@onready var interaction_detector: Area2D = get_node_or_null("InteractionDetector") as Area2D
@onready var combat_status_controller: Node = get_node_or_null("CombatStatusController")

var facing_direction: int = 1
var current_state: StringName = STATE_IDLE
var _dash_cooldown_remaining: float = 0.0
var _animation_name: StringName = &""
var _animation_elapsed: float = 0.0
var input_enabled: bool = true
var _invulnerable := false

func _ready() -> void:
	health = clampi(health, 0, maxi(1, max_health))
	mana = clampi(mana, 0, maxi(1, max_mana))
	resources_changed.emit(health, max_health, mana, max_mana)

func _physics_process(delta: float) -> void:
	_tick_dash_cooldown(delta)
	if combat_status_controller != null:
		combat_status_controller.call("tick", delta, get_tree().paused)

	var direction := get_move_direction()
	if direction != 0.0:
		set_facing_direction(signi(direction))

	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif _is_action_just_pressed(ACTION_JUMP, [FALLBACK_JUMP, FALLBACK_JUMP_ALT]):
		velocity.y = jump_velocity

	if _is_action_just_pressed(&"dash"):
		try_dash(signi(direction) if direction != 0.0 else facing_direction)

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
	_update_state(0.0)

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return

	facing_direction = signi(direction)
	if visual != null:
		visual.scale.x = float(facing_direction)
	if interaction_detector != null:
		interaction_detector.position.x = absf(interaction_detector.position.x) * float(facing_direction)

func take_hit(raw_damage: int, source_position: Vector2, knockback: float = 180.0, unblockable: bool = false) -> int:
	if _invulnerable or health <= 0:
		return 0
	var incoming := maxi(1, raw_damage - defense)
	var outcome := {
		"damage": incoming,
		"armor_tier": 0,
		"prevents_knockback": false,
		"retaliation_damage": 0,
	}
	if combat_status_controller != null:
		outcome = combat_status_controller.call("resolve_incoming_damage", incoming, unblockable) as Dictionary
	var applied := int(outcome.get("damage", 0))
	if applied <= 0:
		return 0
	take_damage(applied)
	if not bool(outcome.get("prevents_knockback", false)):
		velocity.x = signf(global_position.x - source_position.x) * knockback
	_apply_retaliation(source_position, int(outcome.get("retaliation_damage", 0)))
	_invulnerable = true
	get_tree().create_timer(0.55).timeout.connect(_clear_invulnerability, CONNECT_ONE_SHOT)
	return applied

func _clear_invulnerability() -> void:
	_invulnerable = false

func revive(at_position: Vector2) -> void:
	global_position = at_position
	health = max_health
	mana = maxi(1, max_mana / 2)
	velocity = Vector2.ZERO
	_invulnerable = false
	resources_changed.emit(health, max_health, mana, max_mana)

func restore_health(amount: int) -> int:
	if amount <= 0 or health >= max_health:
		return 0
	var restored := mini(amount, max_health - health)
	health += restored
	resources_changed.emit(health, max_health, mana, max_mana)
	return restored

func restore_mana(amount: int) -> int:
	if amount <= 0 or mana >= max_mana:
		return 0
	var restored := mini(amount, max_mana - mana)
	mana += restored
	resources_changed.emit(health, max_health, mana, max_mana)
	return restored

func take_damage(amount: int) -> int:
	var was_alive := health > 0
	var applied := mini(maxi(0, amount), health)
	health -= applied
	resources_changed.emit(health, max_health, mana, max_mana)
	if was_alive and health <= 0:
		defeated.emit()
	return applied

func spend_mana(amount: int) -> bool:
	var cost := maxi(0, amount)
	if mana < cost:
		return false
	mana -= cost
	resources_changed.emit(health, max_health, mana, max_mana)
	return true


func try_dash(direction: int = 0) -> bool:
	if not input_enabled or _dash_cooldown_remaining > 0.0:
		return false
	var dash_direction := direction if direction != 0 else facing_direction
	set_facing_direction(dash_direction)
	global_position.x += dash_distance * float(facing_direction)
	_dash_cooldown_remaining = dash_cooldown
	_invulnerable = true
	get_tree().create_timer(0.18).timeout.connect(_clear_invulnerability, CONNECT_ONE_SHOT)
	return true


func add_block(amount: int) -> int:
	return 0


func get_block() -> int:
	return 0


func get_combat_status_controller() -> Node:
	return combat_status_controller


func _apply_retaliation(source_position: Vector2, damage: int) -> void:
	if damage <= 0:
		return
	var closest_enemy: Node2D
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("Enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate) or not candidate.has_method("take_hit"):
			continue
		var distance := (candidate as Node2D).global_position.distance_squared_to(source_position)
		if distance < closest_distance:
			closest_enemy = candidate as Node2D
			closest_distance = distance
	if closest_enemy != null:
		closest_enemy.call("take_hit", damage, global_position, 0.0)

func _tick_dash_cooldown(delta: float) -> void:
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)

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

	_play_animation(current_state)
	_animation_elapsed += delta

	var fps := _get_animation_fps(_animation_name)
	var frame_count := character_sprite.hframes
	var next_frame := int(_animation_elapsed * fps)

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
		_:
			character_sprite.texture = IDLE_TEXTURE
			character_sprite.hframes = 4

func _get_animation_fps(animation_name: StringName) -> float:
	match animation_name:
		STATE_WALK:
			return 12.0
		STATE_JUMP:
			return 15.0
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
