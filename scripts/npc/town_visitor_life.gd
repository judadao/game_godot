class_name TownVisitorLife
extends AnimatableBody2D

signal visitor_state_changed(state: StringName)
signal town_pass_completed(visitor: TownVisitorLife)
signal resident_greeted(visitor: TownVisitorLife, resident: TownNPCLife)

const STATE_OFFSCREEN_WAIT: StringName = &"offscreen_wait"
const STATE_CROSSING: StringName = &"crossing"
const STATE_PAUSE: StringName = &"pause"
const STATE_SOCIAL_GREET: StringName = &"social_greet"
const STATE_SOCIAL_CHAT: StringName = &"social_chat"
const STATE_EXITING: StringName = &"exiting"
const EXTERNALLY_SCHEDULED_RESIDENT_IDS: Array[StringName] = [&"witch"]

@export var visitor_enabled := true
@export_enum("left_to_right", "right_to_left") var route_direction := "left_to_right"
@export_range(-300.0, -40.0, 1.0) var left_boundary_x := -140.0
@export_range(1980.0, 2240.0, 1.0) var right_boundary_x := 2082.0
@export_range(620.0, 700.0, 1.0) var route_y := 672.0
@export_range(120.0, 1880.0, 1.0) var greeting_stop_x := 1280.0
@export_range(20.0, 180.0, 1.0) var walk_speed := 46.0
@export_range(0.0, 20.0, 0.1) var initial_delay_seconds := 1.5
@export_range(0.1, 8.0, 0.1) var pause_seconds := 1.8
@export_range(0.1, 2.0, 0.1) var greet_seconds := 0.7
@export_range(0.1, 8.0, 0.1) var chat_seconds := 2.8
@export_range(2.0, 30.0, 0.1) var cycle_delay_seconds := 12.0
@export_range(40.0, 260.0, 1.0) var greeting_radius := 150.0
@export var preferred_resident_name: StringName
@export var greeting_enabled := true

@onready var npc_visual: TownNPCVisual = $Visual

var _state: StringName = STATE_OFFSCREEN_WAIT
var _state_timer := 0.0
var _target_position := Vector2.ZERO
var _partner: TownNPCLife
var _completed_passes := 0
var _completed_greetings := 0


func _ready() -> void:
	if is_instance_valid(npc_visual):
		npc_visual.ambient_enabled = false
	restart_route(initial_delay_seconds)


func _exit_tree() -> void:
	_release_partner()


func _process(delta: float) -> void:
	advance_visitor(delta)


func advance_visitor(delta: float) -> void:
	if not visitor_enabled:
		return
	var step := maxf(delta, 0.0)
	match _state:
		STATE_OFFSCREEN_WAIT:
			_state_timer -= step
			if _state_timer <= 0.0:
				_begin_crossing()
		STATE_CROSSING, STATE_EXITING:
			_advance_motion(step)
		STATE_PAUSE:
			_state_timer -= step
			if _state_timer <= 0.0:
				_begin_exit()
		STATE_SOCIAL_GREET:
			_state_timer -= step
			if _state_timer <= 0.0 or not is_instance_valid(_partner):
				_begin_social_chat()
		STATE_SOCIAL_CHAT:
			_state_timer -= step
			if _state_timer <= 0.0 or not is_instance_valid(_partner):
				_finish_greeting()


func restart_route(delay_seconds := -1.0) -> void:
	_release_partner()
	position = get_entry_position()
	_target_position = position
	z_index = 0
	_state_timer = initial_delay_seconds if delay_seconds < 0.0 else maxf(delay_seconds, 0.0)
	_set_state(STATE_OFFSCREEN_WAIT)


func get_visitor_state() -> StringName:
	return _state


func get_entry_position() -> Vector2:
	return Vector2(
		left_boundary_x if route_direction == "left_to_right" else right_boundary_x,
		route_y
	)


func get_exit_position() -> Vector2:
	return Vector2(
		right_boundary_x if route_direction == "left_to_right" else left_boundary_x,
		route_y
	)


func get_completed_passes() -> int:
	return _completed_passes


func get_completed_greetings() -> int:
	return _completed_greetings


func get_social_partner() -> TownNPCLife:
	return _partner


func _begin_crossing() -> void:
	_target_position = Vector2(greeting_stop_x, route_y)
	_face_toward(_target_position.x)
	z_index = 1
	_set_state(STATE_CROSSING)


func _advance_motion(delta: float) -> void:
	_face_toward(_target_position.x)
	position = position.move_toward(_target_position, walk_speed * delta)
	if position.distance_to(_target_position) > 0.5:
		return
	position = _target_position
	if _state == STATE_CROSSING:
		_arrive_at_greeting_stop()
	else:
		_complete_pass()


func _arrive_at_greeting_stop() -> void:
	var resident := _find_social_resident()
	if is_instance_valid(resident):
		_begin_greeting(resident)
		return
	_state_timer = pause_seconds
	_set_state(STATE_PAUSE)


func _find_social_resident() -> TownNPCLife:
	if not greeting_enabled or get_parent() == null:
		return null
	var preferred := get_parent().get_node_or_null(NodePath(String(preferred_resident_name))) as TownNPCLife
	if _resident_is_available(preferred):
		return preferred
	var nearest: TownNPCLife
	var nearest_distance := INF
	for candidate in get_parent().get_children():
		var resident := candidate as TownNPCLife
		if not _resident_is_available(resident):
			continue
		var distance := absf(resident.position.x - position.x)
		if distance < nearest_distance:
			nearest = resident
			nearest_distance = distance
	return nearest


func _resident_is_available(resident: TownNPCLife) -> bool:
	return (
		is_instance_valid(resident)
		and not EXTERNALLY_SCHEDULED_RESIDENT_IDS.has(
			StringName(resident.get_meta("character_id", ""))
		)
		and resident.is_available_for_social()
		and absf(resident.position.x - position.x) <= greeting_radius
	)


func _begin_greeting(resident: TownNPCLife) -> void:
	_partner = resident
	_partner.set_external_interaction(true, position)
	_face_toward(_partner.position.x)
	_state_timer = greet_seconds
	_set_state(STATE_SOCIAL_GREET)


func _begin_social_chat() -> void:
	if not is_instance_valid(_partner):
		_finish_greeting()
		return
	_state_timer = chat_seconds
	_set_state(STATE_SOCIAL_CHAT)


func _finish_greeting() -> void:
	var greeted_resident := _partner
	_release_partner()
	if is_instance_valid(greeted_resident):
		_completed_greetings += 1
		resident_greeted.emit(self, greeted_resident)
	_begin_exit()


func _release_partner() -> void:
	var resident := _partner
	_partner = null
	if is_instance_valid(resident) and not resident.is_queued_for_deletion():
		resident.set_external_interaction(false)


func _begin_exit() -> void:
	_target_position = get_exit_position()
	_face_toward(_target_position.x)
	z_index = 1
	_set_state(STATE_EXITING)


func _complete_pass() -> void:
	_completed_passes += 1
	town_pass_completed.emit(self)
	restart_route(cycle_delay_seconds)


func _set_state(next_state: StringName) -> void:
	_state = next_state
	if is_instance_valid(npc_visual):
		match _state:
			STATE_CROSSING, STATE_EXITING:
				npc_visual.play_state(&"walk")
			STATE_SOCIAL_GREET:
				if not npc_visual.play_state(&"greet"):
					npc_visual.play_state(&"chat")
			STATE_SOCIAL_CHAT:
				npc_visual.play_state(&"chat")
			_:
				npc_visual.play_state(&"idle")
	visitor_state_changed.emit(_state)


func _face_toward(target_x: float) -> void:
	if is_instance_valid(npc_visual):
		npc_visual.set_facing_direction(target_x - position.x)
