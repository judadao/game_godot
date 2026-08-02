class_name PriestTownBehavior
extends AnimatableBody2D

signal behavior_state_changed(state: StringName)

const STATE_WAIT_HOME: StringName = &"wait_home"
const STATE_WALK_TO_WITCH: StringName = &"walk_to_witch"
const STATE_CHAT_WITH_WITCH: StringName = &"chat_with_witch"
const STATE_WALK_HOME: StringName = &"walk_home"

@export var witch_path := NodePath("../EquipmentBlueprintMerchant")
@export_range(20.0, 180.0, 1.0) var walk_speed := 100.0
@export_range(48.0, 160.0, 1.0) var conversation_offset := 95.0
@export_range(0.1, 20.0, 0.1) var home_wait_seconds := 4.0
@export_range(0.1, 20.0, 0.1) var chat_seconds := 4.5
@export_range(0.1, 8.0, 0.1) var arrival_tolerance := 1.0
@export_range(12.0, 56.0, 1.0) var foreground_lane_offset := 46.0
@export_range(24.0, 120.0, 1.0) var lane_entry_distance := 70.0

@onready var priest_visual: PriestAnimatedSprite = $Visual

var _state: StringName = STATE_WAIT_HOME
var _state_elapsed := 0.0
var _home_position := Vector2.ZERO
var _witch: Node2D
var _base_visual_scale := Vector2.ONE
var _witch_ambient_was_enabled := true
var _witch_previous_state: StringName = &"idle"
var _completed_cycles := 0
var _route_index := 0


func _ready() -> void:
	_home_position = position
	_base_visual_scale = priest_visual.scale
	_resolve_witch()
	_enter_state(STATE_WAIT_HOME)


func _process(delta: float) -> void:
	advance_behavior(delta)


func advance_behavior(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if not is_instance_valid(_witch):
		_resolve_witch()
	match _state:
		STATE_WAIT_HOME:
			_state_elapsed += step
			if _state_elapsed >= home_wait_seconds and is_instance_valid(_witch):
				_enter_state(STATE_WALK_TO_WITCH)
		STATE_WALK_TO_WITCH:
			if not is_instance_valid(_witch):
				_enter_state(STATE_WALK_HOME)
				return
			_advance_route(_outbound_route(), step, STATE_CHAT_WITH_WITCH)
		STATE_CHAT_WITH_WITCH:
			_state_elapsed += step
			if _state_elapsed >= chat_seconds:
				_enter_state(STATE_WALK_HOME)
		STATE_WALK_HOME:
			_advance_route(_return_route(), step, STATE_WAIT_HOME)


func get_behavior_state() -> StringName:
	return _state


func get_home_position() -> Vector2:
	return _home_position


func get_conversation_position() -> Vector2:
	return Vector2(_conversation_x(), _home_position.y)


func get_completed_cycles() -> int:
	return _completed_cycles


func _resolve_witch() -> void:
	_witch = get_node_or_null(witch_path) as Node2D


func _conversation_x() -> float:
	if not is_instance_valid(_witch):
		return _home_position.x
	return _witch.position.x + conversation_offset


func _outbound_route() -> Array[Vector2]:
	var lane_y := _home_position.y + foreground_lane_offset
	return [
		Vector2(_home_position.x + lane_entry_distance, lane_y),
		Vector2(_conversation_x(), lane_y),
		get_conversation_position(),
	]


func _return_route() -> Array[Vector2]:
	var lane_y := _home_position.y + foreground_lane_offset
	return [
		Vector2(_conversation_x(), lane_y),
		Vector2(_home_position.x, lane_y),
		_home_position,
	]


func _advance_route(route: Array[Vector2], delta: float, completion_state: StringName) -> void:
	if route.is_empty():
		_enter_state(completion_state)
		return
	_route_index = clampi(_route_index, 0, route.size() - 1)
	var target := route[_route_index]
	position = position.move_toward(target, walk_speed * delta)
	if position.distance_to(target) > arrival_tolerance:
		return
	position = target
	_route_index += 1
	if _route_index < route.size():
		return
	if completion_state == STATE_WAIT_HOME:
		_completed_cycles += 1
	_enter_state(completion_state)


func _enter_state(next_state: StringName) -> void:
	if _state == STATE_CHAT_WITH_WITCH and next_state != STATE_CHAT_WITH_WITCH:
		_release_witch_chat()
	_state = next_state
	_state_elapsed = 0.0
	_route_index = 0
	match _state:
		STATE_WAIT_HOME:
			z_index = 0
			_set_visual(&"front_idle", 1.0)
		STATE_WALK_TO_WITCH:
			z_index = 2
			_set_visual(&"side_walk", 1.0)
		STATE_CHAT_WITH_WITCH:
			z_index = 0
			_set_visual(&"side_chat", -1.0)
			_begin_witch_chat()
		STATE_WALK_HOME:
			z_index = 2
			_set_visual(&"side_walk", -1.0)
	behavior_state_changed.emit(_state)


func _set_visual(animation: StringName, facing_sign: float) -> void:
	if not is_instance_valid(priest_visual):
		return
	priest_visual.scale = Vector2(
		absf(_base_visual_scale.x) * signf(facing_sign),
		_base_visual_scale.y
	)
	priest_visual.play_animation(animation, true)


func _begin_witch_chat() -> void:
	var witch_visual := _witch_visual()
	if witch_visual == null:
		return
	_witch_ambient_was_enabled = bool(witch_visual.get("ambient_enabled"))
	if witch_visual.has_method("get_active_state"):
		_witch_previous_state = StringName(witch_visual.call("get_active_state"))
	if _witch.has_method("set_external_interaction"):
		_witch.call("set_external_interaction", true, position)
		return
	witch_visual.set("ambient_enabled", false)
	if witch_visual.has_method("play_state"):
		witch_visual.call("play_state", &"chat")


func _release_witch_chat() -> void:
	if is_instance_valid(_witch) and _witch.has_method("set_external_interaction"):
		_witch.call("set_external_interaction", false)
		return
	var witch_visual := _witch_visual()
	if witch_visual == null:
		return
	if witch_visual.has_method("play_state"):
		witch_visual.call("play_state", _witch_previous_state)
	witch_visual.set("ambient_enabled", _witch_ambient_was_enabled)


func _witch_visual() -> Node:
	if not is_instance_valid(_witch):
		return null
	return _witch.get_node_or_null("Visual")
