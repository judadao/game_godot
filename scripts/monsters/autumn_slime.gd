extends CharacterBody2D

signal defeated(enemy: Node, experience: int, gold: int)
signal health_changed(current: int, maximum: int)

@export var max_health: int = 45
@export var attack_damage: int = 12
@export var defense: int = 1
@export var speed: float = 72.0
@export var detection_range: float = 320.0
@export var attack_range: float = 64.0
@export var attack_cooldown: float = 1.0
@export var experience_reward: int = 25
@export var gold_reward: int = 8
@export var gravity: float = 980.0

@onready var sprite: Sprite2D = $Sprite
@onready var health_fill: ColorRect = $HealthBar/Fill
var health: int
var target: Node2D
var _cooldown: float = 0.0
var _dying := false
var _anim_time := 0.0


func _ready() -> void:
	health = max_health
	target = get_tree().get_first_node_in_group("Player") as Node2D
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_anim_time += delta
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("Player") as Node2D
		velocity.x = 0.0
	else:
		var distance := global_position.distance_to(target.global_position)
		if distance <= attack_range:
			velocity.x = 0.0
			if _cooldown <= 0.0:
				_attack_target()
		elif distance <= detection_range:
			velocity.x = signf(target.global_position.x - global_position.x) * speed
			sprite.flip_h = velocity.x < 0.0
		else:
			velocity.x = 0.0
	move_and_slide()
	if sprite.frame < 2:
		sprite.frame = int(_anim_time * 3.0) % 2


func take_hit(raw_damage: int, source_position: Vector2, knockback: float = 180.0) -> int:
	if _dying:
		return 0
	var applied := maxi(1, raw_damage - defense)
	health = maxi(0, health - applied)
	velocity.x = signf(global_position.x - source_position.x) * knockback
	sprite.frame = 2
	health_changed.emit(health, max_health)
	_update_health_bar()
	if health <= 0:
		_die()
	return applied


func _attack_target() -> void:
	_cooldown = attack_cooldown
	sprite.frame = 2
	if target != null and target.has_method("take_hit"):
		target.call("take_hit", attack_damage, global_position, 220.0)


func _update_health_bar() -> void:
	if health_fill != null:
		health_fill.size.x = 72.0 * float(health) / float(maxi(1, max_health))


func _die() -> void:
	_dying = true
	collision_layer = 0
	collision_mask = 0
	$Hurtbox.monitorable = false
	sprite.frame = 3
	defeated.emit(self, experience_reward, gold_reward)
	await get_tree().create_timer(0.45).timeout
	queue_free()
