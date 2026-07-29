class_name SurvivalPickup
extends Area2D

signal collected(item_id: StringName, collector: Node)

@export var attraction_radius := 180.0
@export var pickup_radius := 32.0
@export var attraction_speed := 260.0
@export var lifetime := 18.0

@onready var visual: Node2D = get_node_or_null("Visual") as Node2D
@onready var core: Polygon2D = get_node_or_null("Visual/Core") as Polygon2D
@onready var accent: Polygon2D = get_node_or_null("Visual/Accent") as Polygon2D
@onready var ring: Line2D = get_node_or_null("Visual/Ring") as Line2D

var item_id: StringName = &"healing_fruit"
var _target: Node2D
var _collected := false
var _elapsed := 0.0
var _lifetime_remaining := 18.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_lifetime_remaining = lifetime
	_apply_visual_profile()


func configure(id: StringName, target: Node2D = null) -> void:
	item_id = id
	_target = target
	_lifetime_remaining = lifetime
	_apply_visual_profile()


func _physics_process(delta: float) -> void:
	advance_pickup(delta)


func advance_pickup(delta: float) -> void:
	if _collected:
		return
	var safe_delta := maxf(0.0, delta)
	_lifetime_remaining -= safe_delta
	if _lifetime_remaining <= 0.0:
		_collected = true
		queue_free()
		return
	_elapsed += safe_delta
	if visual != null:
		visual.position.y = -26.0 + sin(_elapsed * 4.8) * 4.0
		visual.rotation = sin(_elapsed * 2.4) * 0.08
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("Player") as Node2D
	if _target == null:
		return
	var distance := global_position.distance_to(_target.global_position)
	if distance <= pickup_radius:
		collect(_target)
	elif distance <= attraction_radius:
		global_position = global_position.move_toward(
			_target.global_position,
			attraction_speed * safe_delta
		)


func collect(collector: Node = null) -> void:
	if _collected:
		return
	var resolved_collector := collector if collector != null else _target
	if resolved_collector == null or not is_instance_valid(resolved_collector):
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collected.emit(item_id, resolved_collector)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body == _target or body.is_in_group("Player"):
		collect(body)


func _apply_visual_profile() -> void:
	if core == null or accent == null or ring == null:
		return
	match item_id:
		&"experience_magnet":
			core.color = Color(0.16, 0.82, 1.0)
			accent.color = Color(0.9, 1.0, 1.0)
			ring.default_color = Color(0.22, 0.9, 1.0, 0.9)
			core.polygon = PackedVector2Array([
				Vector2(-14.0, -15.0), Vector2(-5.0, -15.0),
				Vector2(-5.0, 6.0), Vector2(5.0, 6.0),
				Vector2(5.0, -15.0), Vector2(14.0, -15.0),
				Vector2(14.0, 8.0), Vector2(7.0, 15.0),
				Vector2(-7.0, 15.0), Vector2(-14.0, 8.0),
			])
		&"swift_fruit":
			core.color = Color(1.0, 0.78, 0.14)
			accent.color = Color(0.42, 1.0, 0.58)
			ring.default_color = Color(1.0, 0.84, 0.24, 0.9)
			core.polygon = PackedVector2Array([
				Vector2(-15.0, -5.0), Vector2(-2.0, -16.0),
				Vector2(15.0, -8.0), Vector2(9.0, 4.0),
				Vector2(0.0, 16.0), Vector2(-12.0, 9.0),
			])
		_:
			core.color = Color(1.0, 0.3, 0.18)
			accent.color = Color(0.5, 1.0, 0.32)
			ring.default_color = Color(1.0, 0.45, 0.22, 0.9)
			core.polygon = PackedVector2Array([
				Vector2(0.0, -14.0), Vector2(13.0, -7.0),
				Vector2(15.0, 5.0), Vector2(7.0, 16.0),
				Vector2(-7.0, 16.0), Vector2(-15.0, 5.0),
				Vector2(-13.0, -7.0),
			])
