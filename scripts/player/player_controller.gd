extends CharacterBody2D

signal state_changed(state: StringName)
signal resources_changed(health: int, max_health: int, mana: int, max_mana: int)
signal defeated
signal dash_performed(start_position: Vector2, end_position: Vector2)

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_JUMP: StringName = &"jump"
const FALLBACK_MOVE_LEFT: StringName = &"ui_left"
const FALLBACK_MOVE_RIGHT: StringName = &"ui_right"
const FALLBACK_MOVE_DOWN: StringName = &"ui_down"
const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_JUMP: StringName = &"jump"
const STATE_ATTACK: StringName = &"attack"

const IDLE_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png")
const RUN_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Run/Run-Sheet.png")
const JUMP_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Jumlp-All/Jump-All-Sheet.png")
const ATTACK_TEXTURE: Texture2D = preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Attack-01/Attack-01-Sheet.png")
const ATTACK_FRAME_COUNT := 8
const ATTACK_FPS := 16.0
const ATTACK_DURATION := float(ATTACK_FRAME_COUNT) / ATTACK_FPS

@export var speed: float = 260.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0
@export var dash_distance: float = 150.0
@export var dash_cooldown: float = 0.65
@export var dash_duration: float = 0.14
@export var dash_evasion_seconds: float = 0.18
@export var jump_evasion_seconds: float = 0.10
@export var max_air_jumps: int = 0
@export var platform_drop_speed := 180.0
@export var platform_drop_clearance := 24.0
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
@onready var combat_status_controller: CombatStatusController = get_node_or_null("CombatStatusController") as CombatStatusController

var facing_direction: int = 1
var current_state: StringName = STATE_IDLE
var _dash_cooldown_remaining: float = 0.0
var _dash_remaining: float = 0.0
var _dash_start_position := Vector2.ZERO
var _dash_collision_layer: int = 0
var _air_jumps_remaining: int = 0
var _animation_name: StringName = &""
var _animation_elapsed: float = 0.0
var _attack_animation_remaining := 0.0
var input_enabled: bool = true
var _invulnerability_remaining := 0.0
var _block := 0
var _temporary_move_speed_multiplier := 1.0
var _temporary_move_speed_remaining := 0.0

func _ready() -> void:
	health = clampi(health, 0, maxi(1, max_health))
	mana = clampi(mana, 0, maxi(1, max_mana))
	resources_changed.emit(health, max_health, mana, max_mana)

func _physics_process(delta: float) -> void:
	_tick_dash_cooldown(delta)
	_tick_invulnerability(delta)
	_tick_temporary_move_speed(delta)
	if _dash_remaining > 0.0:
		_advance_dash(delta)
		_update_state(float(facing_direction))
		_update_character_animation(delta)
		return

	var direction := get_move_direction()
	if direction != 0.0:
		set_facing_direction(signi(direction))

	velocity.x = direction * speed * _temporary_move_speed_multiplier

	if is_on_floor():
		_air_jumps_remaining = max_air_jumps
		if _is_action_just_pressed(ACTION_MOVE_DOWN, [FALLBACK_MOVE_DOWN]):
			try_drop_through_platform()
		elif _is_action_just_pressed(ACTION_JUMP):
			_start_jump()
	else:
		velocity.y += gravity * delta
		if _is_action_just_pressed(ACTION_JUMP) and _air_jumps_remaining > 0:
			_air_jumps_remaining -= 1
			_start_jump()

	if (
		_is_action_just_pressed(&"dash")
		and try_dash(signi(direction) if direction != 0.0 else facing_direction)
	):
		_advance_dash(delta)
		_update_state(float(facing_direction))
		_update_character_animation(delta)
		return

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


func try_drop_through_platform() -> bool:
	if not input_enabled or not is_on_floor() or not _is_standing_on_one_way_platform():
		return false
	global_position.y += platform_drop_clearance
	velocity.y = maxf(velocity.y, platform_drop_speed)
	return true


func _is_standing_on_one_way_platform() -> bool:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().dot(up_direction) < 0.7:
			continue
		var collider := collision.get_collider() as CollisionObject2D
		if collider == null:
			continue
		var shape_index := collision.get_collider_shape_index()
		var owner_id := collider.shape_find_owner(shape_index)
		var shape_owner := collider.shape_owner_get_owner(owner_id) as CollisionShape2D
		if shape_owner != null and shape_owner.one_way_collision:
			return true
	return false


func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return

	facing_direction = signi(direction)
	if visual != null:
		visual.scale.x = float(facing_direction)
	if interaction_detector != null:
		interaction_detector.position.x = absf(interaction_detector.position.x) * float(facing_direction)


func play_attack_animation() -> bool:
	if character_sprite == null or health <= 0:
		return false
	_attack_animation_remaining = ATTACK_DURATION
	_play_animation(STATE_ATTACK)
	return true


func get_active_animation() -> StringName:
	return _animation_name

func take_hit(
	raw_damage: int,
	source_position: Vector2,
	knockback: float = 180.0,
	unblockable: bool = false,
	source: Node = null
) -> int:
	if is_invulnerable() or health <= 0:
		return 0
	var applied := maxi(1, raw_damage - defense)
	if not unblockable and combat_status_controller != null:
		applied = maxi(1, int(round(float(applied) * (1.0 - combat_status_controller.get_damage_reduction()))))
	if not unblockable:
		var absorbed := mini(_block, applied)
		_block -= absorbed
		applied -= absorbed
	if applied <= 0:
		return 0
	take_damage(applied)
	_show_hit_feedback()
	if combat_status_controller == null or combat_status_controller.get_super_armor_tier() <= 0:
		velocity.x = signf(global_position.x - source_position.x) * knockback
	if source != null and is_instance_valid(source) and combat_status_controller != null:
		var retaliation := combat_status_controller.get_retaliation_damage()
		if retaliation > 0:
			if source.has_method("take_hit"):
				source.call("take_hit", retaliation, global_position, 0.0)
			elif source.has_method("take_damage"):
				source.call("take_damage", retaliation)
	grant_invulnerability(0.55)
	return applied


func _show_hit_feedback() -> void:
	if visual == null:
		return
	visual.modulate = Color(1.0, 0.22, 0.16, 1.0)
	var tween := visual.create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.18)

func grant_invulnerability(duration: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining, maxf(0.0, duration))


func is_invulnerable() -> bool:
	return _invulnerability_remaining > 0.0


func _clear_invulnerability() -> void:
	_invulnerability_remaining = 0.0


func revive(at_position: Vector2) -> void:
	global_position = at_position
	health = max_health
	mana = maxi(1, max_mana / 2)
	velocity = Vector2.ZERO
	_invulnerability_remaining = 0.0
	_dash_remaining = 0.0
	if _dash_collision_layer != 0:
		collision_layer = _dash_collision_layer
	_dash_collision_layer = 0
	_block = 0
	_temporary_move_speed_multiplier = 1.0
	_temporary_move_speed_remaining = 0.0
	if combat_status_controller != null:
		combat_status_controller.clear_all()
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


func apply_temporary_move_speed(multiplier: float, duration: float) -> void:
	_temporary_move_speed_multiplier = maxf(
		_temporary_move_speed_multiplier,
		maxf(1.0, multiplier)
	)
	_temporary_move_speed_remaining = maxf(
		_temporary_move_speed_remaining,
		maxf(0.0, duration)
	)


func get_temporary_move_speed_snapshot() -> Dictionary:
	return {
		"multiplier": _temporary_move_speed_multiplier,
		"remaining": _temporary_move_speed_remaining,
	}

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
	if not input_enabled or _dash_cooldown_remaining > 0.0 or _dash_remaining > 0.0:
		return false
	var dash_direction := direction if direction != 0 else facing_direction
	set_facing_direction(dash_direction)
	_dash_start_position = global_position
	_dash_remaining = maxf(0.01, dash_duration)
	_dash_cooldown_remaining = dash_cooldown
	_dash_collision_layer = collision_layer
	collision_layer = 0
	velocity = Vector2(dash_distance * float(facing_direction) / _dash_remaining, 0.0)
	grant_invulnerability(_dash_remaining + dash_evasion_seconds)
	return true


func _advance_dash(delta: float) -> void:
	var step := minf(maxf(delta, 0.0), _dash_remaining)
	velocity = Vector2(dash_distance * float(facing_direction) / maxf(0.01, dash_duration), 0.0)
	move_and_collide(velocity * step)
	_dash_remaining = maxf(0.0, _dash_remaining - step)
	if _dash_remaining > 0.0:
		return
	velocity.x = 0.0
	collision_layer = _dash_collision_layer
	_dash_collision_layer = 0
	dash_performed.emit(_dash_start_position, global_position)


func add_block(amount: int) -> int:
	var granted := maxi(0, amount)
	_block += granted
	return granted


func get_block() -> int:
	return _block


func apply_combat_status(source_id: String, display_name: String, effect: Dictionary) -> bool:
	if combat_status_controller == null:
		return false
	return combat_status_controller.apply_effect(source_id, display_name, effect)


func set_combat_status_timers_paused(is_paused: bool) -> void:
	if combat_status_controller != null:
		combat_status_controller.set_timers_paused(is_paused)


func get_combat_status_projection() -> Array[Dictionary]:
	return combat_status_controller.get_status_projection() if combat_status_controller != null else []


func resolve_lifesteal(dealt_damage: int) -> int:
	if dealt_damage <= 0 or combat_status_controller == null:
		return 0
	var ratio := combat_status_controller.get_lifesteal_ratio()
	if ratio <= 0.0:
		return 0
	return restore_health(maxi(1, int(round(float(dealt_damage) * ratio))))

func _tick_dash_cooldown(delta: float) -> void:
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)


func _tick_invulnerability(delta: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining - maxf(delta, 0.0), 0.0)


func _tick_temporary_move_speed(delta: float) -> void:
	if _temporary_move_speed_remaining <= 0.0:
		_temporary_move_speed_multiplier = 1.0
		return
	_temporary_move_speed_remaining = maxf(
		0.0,
		_temporary_move_speed_remaining - maxf(delta, 0.0)
	)
	if _temporary_move_speed_remaining <= 0.0:
		_temporary_move_speed_multiplier = 1.0


func _start_jump() -> void:
	velocity.y = jump_velocity
	grant_invulnerability(jump_evasion_seconds)

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

	if _attack_animation_remaining > 0.0:
		_attack_animation_remaining = maxf(0.0, _attack_animation_remaining - maxf(delta, 0.0))
		_play_animation(STATE_ATTACK)
		_animation_elapsed += delta
		character_sprite.frame = mini(
			ATTACK_FRAME_COUNT - 1,
			int(_animation_elapsed * ATTACK_FPS)
		)
		if _attack_animation_remaining <= 0.0:
			_play_animation(current_state)
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
		STATE_ATTACK:
			character_sprite.texture = ATTACK_TEXTURE
			character_sprite.hframes = ATTACK_FRAME_COUNT
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
		STATE_ATTACK:
			return ATTACK_FPS
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
