extends Node2D

signal progress_changed(remaining: int, total: int)
signal zone_cleared(experience: int, gold: int)

@onready var trigger: Area2D = $Trigger
@onready var left_gate: CollisionShape2D = get_node_or_null("Barriers/LeftGate") as CollisionShape2D
@onready var right_gate: CollisionShape2D = get_node_or_null("Barriers/RightGate") as CollisionShape2D
var _active := false
var _cleared := false
var _total := 0
var _remaining := 0
var _experience := 0
var _gold := 0


func _ready() -> void:
	_set_gates_disabled(true)
	trigger.body_entered.connect(_on_body_entered)
	for enemy in $Enemies.get_children():
		if enemy.has_signal("defeated"):
			enemy.connect("defeated", _on_enemy_defeated)
			_total += 1
	_remaining = _total


func _on_body_entered(body: Node) -> void:
	if _active or _cleared or not body.is_in_group("Player"):
		return
	_active = true
	_set_gates_disabled(false)
	progress_changed.emit(_remaining, _total)


func _on_enemy_defeated(_enemy: Node, experience: int, gold: int) -> void:
	_remaining = maxi(0, _remaining - 1)
	_experience += experience
	_gold += gold
	progress_changed.emit(_remaining, _total)
	if _remaining == 0:
		_cleared = true
		_set_gates_disabled(true)
		zone_cleared.emit(_experience, _gold)


func _set_gates_disabled(disabled: bool) -> void:
	if left_gate != null:
		left_gate.set_deferred("disabled", disabled)
	if right_gate != null:
		right_gate.set_deferred("disabled", disabled)
