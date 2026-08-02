class_name PriestTownBehavior
extends AnimatableBody2D

signal behavior_state_changed(state: StringName)

const PROFILE_CATALOG_SCRIPT := preload("res://scripts/npc/town_npc_character_profile_catalog.gd")
const STATE_WAIT_HOME: StringName = &"wait_home"
const STATE_HOME_ACTIVITY: StringName = &"home_activity"
const STATE_WALK_TO_WITCH: StringName = &"walk_to_witch"
const STATE_CHAT_WITH_WITCH: StringName = &"chat_with_witch"
const STATE_WALK_HOME: StringName = &"walk_home"

@export var witch_path := NodePath("../EquipmentBlueprintMerchant")
@export_range(20.0, 180.0, 1.0) var walk_speed := 100.0
@export_range(48.0, 160.0, 1.0) var conversation_offset := 95.0
@export_range(0.1, 20.0, 0.1) var home_wait_seconds := 4.0
@export_range(0.1, 30.0, 0.1) var home_activity_seconds := 6.0
@export_range(0.1, 20.0, 0.1) var chat_seconds := 7.5
@export_range(4.0, 120.0, 1.0) var minimum_visit_cooldown_seconds := 24.0
@export_range(4.0, 120.0, 1.0) var maximum_visit_cooldown_seconds := 42.0
@export_range(0.1, 8.0, 0.1) var arrival_tolerance := 1.0
@export_range(0.0, 56.0, 1.0) var foreground_lane_offset := 0.0

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
var _profile_catalog: RefCounted
var _rng := RandomNumberGenerator.new()
var _active_daily_activity: StringName = &"prayer"
var _last_daily_activity: StringName
var _home_activity_duration := 6.0
var _visit_cooldown_remaining := 0.0
var _wait_pose_index := 0


func _ready() -> void:
	_home_position = position
	_base_visual_scale = priest_visual.scale
	_rng.seed = absi(hash("priest_daily_rhythm") + int(round(position.x * 17.0))) + 1
	_profile_catalog = PROFILE_CATALOG_SCRIPT.new()
	if not _profile_catalog.call("load_catalog"):
		_profile_catalog = null
	_resolve_witch()
	_enter_state(STATE_WAIT_HOME)


func _process(delta: float) -> void:
	advance_behavior(delta)


func advance_behavior(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_visit_cooldown_remaining = maxf(0.0, _visit_cooldown_remaining - step)
	if not is_instance_valid(_witch):
		_resolve_witch()
	match _state:
		STATE_WAIT_HOME:
			_state_elapsed += step
			if _state_elapsed >= home_wait_seconds:
				_schedule_next_home_behavior()
		STATE_HOME_ACTIVITY:
			_state_elapsed += step
			if _state_elapsed >= _home_activity_duration:
				_last_daily_activity = _active_daily_activity
				_enter_state(STATE_WAIT_HOME)
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


func get_active_daily_activity() -> StringName:
	return _active_daily_activity


func _resolve_witch() -> void:
	_witch = get_node_or_null(witch_path) as Node2D


func _conversation_x() -> float:
	if not is_instance_valid(_witch):
		return _home_position.x
	return _witch.position.x - conversation_offset


func _outbound_route() -> Array[Vector2]:
	if is_zero_approx(foreground_lane_offset):
		return [get_conversation_position()]
	return [
		Vector2(_conversation_x(), _home_position.y + foreground_lane_offset),
		get_conversation_position(),
	]


func _return_route() -> Array[Vector2]:
	if is_zero_approx(foreground_lane_offset):
		return [_home_position]
	return [
		Vector2(_home_position.x, _home_position.y + foreground_lane_offset),
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
			_set_visual(_next_wait_animation(), 1.0)
		STATE_HOME_ACTIVITY:
			z_index = 0
			_set_visual(_active_daily_activity, 1.0)
		STATE_WALK_TO_WITCH:
			z_index = 2 if not is_zero_approx(foreground_lane_offset) else 0
			_set_visual(&"side_walk", 1.0)
		STATE_CHAT_WITH_WITCH:
			if not _witch_is_available_for_visit():
				_enter_state(STATE_WALK_HOME)
				return
			z_index = 0
			_set_visual(&"side_chat", 1.0)
			_begin_witch_chat()
		STATE_WALK_HOME:
			_visit_cooldown_remaining = _next_visit_cooldown()
			z_index = 2 if not is_zero_approx(foreground_lane_offset) else 0
			_set_visual(&"side_walk", -1.0)
	behavior_state_changed.emit(_state)


func _schedule_next_home_behavior() -> void:
	var period := _current_period_profile()
	var period_id := StringName(period.get("id", "dawn"))
	if (
		period_id in [&"noon", &"afternoon", &"evening"]
		and _visit_cooldown_remaining <= 0.0
		and _witch_is_available_for_visit()
	):
		_enter_state(STATE_WALK_TO_WITCH)
		return
	var activities := period.get("activities", ["prayer"]) as Array
	var candidates: Array[StringName] = []
	for activity_variant in activities:
		var activity := StringName(activity_variant)
		if activity != _last_daily_activity and priest_visual.ANIMATIONS.has(activity):
			candidates.append(activity)
	if candidates.is_empty():
		candidates.append(&"prayer")
	_active_daily_activity = candidates[0]
	_home_activity_duration = maxf(
		home_activity_seconds,
		float(period.get("minimum_stay_seconds", home_activity_seconds))
	)
	_enter_state(STATE_HOME_ACTIVITY)


func _current_period_profile() -> Dictionary:
	if _profile_catalog == null:
		return {"id": "dawn", "activities": ["prayer"], "minimum_stay_seconds": home_activity_seconds}
	return _profile_catalog.call("get_period_profile", &"priest", _town_time_progress()) as Dictionary


func _town_time_progress() -> float:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("get_time_of_day_contract"):
			var contract: Dictionary = ancestor.call("get_time_of_day_contract")
			return clampf(float(contract.get("progress", 0.0)), 0.0, 1.0)
		ancestor = ancestor.get_parent()
	return 0.0


func _witch_is_available_for_visit() -> bool:
	if not is_instance_valid(_witch):
		return false
	if _witch.has_method("is_available_for_social"):
		return bool(_witch.call("is_available_for_social"))
	return true


func _next_visit_cooldown() -> float:
	var minimum := minf(minimum_visit_cooldown_seconds, maximum_visit_cooldown_seconds)
	var maximum := maxf(minimum_visit_cooldown_seconds, maximum_visit_cooldown_seconds)
	return _rng.randf_range(minimum, maximum)


func _next_wait_animation() -> StringName:
	var animation := &"front_idle" if _wait_pose_index % 2 == 0 else &"side_idle"
	_wait_pose_index += 1
	return animation


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
