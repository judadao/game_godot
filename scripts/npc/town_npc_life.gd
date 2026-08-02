class_name TownNPCLife
extends AnimatableBody2D

signal life_state_changed(state: StringName)

const STATE_IDLE: StringName = &"idle"
const STATE_EMOTE: StringName = &"emote"
const STATE_REST: StringName = &"rest"
const STATE_WANDER: StringName = &"wander"
const STATE_SOCIAL_WALK: StringName = &"social_walk"
const STATE_SOCIAL_CHAT: StringName = &"social_chat"
const STATE_RETURN_HOME: StringName = &"return_home"
const STATE_EXTERNAL_CHAT: StringName = &"external_chat"
const EMOTE_STATES: Array[StringName] = [
	&"laugh", &"happy", &"surprised", &"sad", &"angry",
]

@export var life_enabled := true
@export_range(24.0, 140.0, 1.0) var roam_radius := 72.0
@export_range(20.0, 120.0, 1.0) var walk_speed := 48.0
@export_range(120.0, 420.0, 1.0) var social_radius := 340.0
@export_range(36.0, 72.0, 1.0) var social_spacing := 50.0
@export_range(55.0, 100.0, 1.0) var personal_space := 80.0
@export_range(1.0, 12.0, 0.1) var minimum_idle_seconds := 2.4
@export_range(1.0, 12.0, 0.1) var maximum_idle_seconds := 5.8
@export_range(1.0, 8.0, 0.1) var social_chat_seconds := 3.2
@export_range(0.0, 1.0, 0.01) var social_chance := 0.34

@onready var npc_visual: TownNPCVisual = $Visual

var _rng := RandomNumberGenerator.new()
var _state: StringName = STATE_IDLE
var _home_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _state_timer := 0.0
var _partner: TownNPCLife
var _social_ready := false
var _social_leader := false
var _external_lock := false
var _external_previous_ambient := false
var _completed_interactions := 0


func _ready() -> void:
	_home_position = position
	_target_position = position
	_rng.seed = _stable_seed()
	if is_instance_valid(npc_visual):
		npc_visual.ambient_enabled = false
	_set_state(STATE_IDLE)
	_state_timer = _next_idle_duration()


func _process(delta: float) -> void:
	advance_life(delta)


func advance_life(delta: float) -> void:
	if not life_enabled or _external_lock:
		return
	var step := maxf(delta, 0.0)
	match _state:
		STATE_IDLE, STATE_EMOTE, STATE_REST:
			_state_timer -= step
			if _state_timer <= 0.0:
				_choose_next_activity()
		STATE_WANDER, STATE_RETURN_HOME, STATE_SOCIAL_WALK:
			_advance_motion(step)
		STATE_SOCIAL_CHAT:
			if _social_leader:
				_state_timer -= step
				if _state_timer <= 0.0:
					_finish_social_pair()


func get_life_state() -> StringName:
	return _state


func get_home_position() -> Vector2:
	return _home_position


func get_wander_bounds() -> Vector2:
	var minimum_x := _home_position.x - roam_radius
	var maximum_x := _home_position.x + roam_radius
	for candidate in get_parent().get_children():
		var other := candidate as TownNPCLife
		if other == null or other == self:
			continue
		var other_home_x := other.get_home_position().x
		if other_home_x < _home_position.x:
			minimum_x = maxf(
				minimum_x,
				(_home_position.x + other_home_x) * 0.5 + personal_space * 0.5
			)
		elif other_home_x > _home_position.x:
			maximum_x = minf(
				maximum_x,
				(_home_position.x + other_home_x) * 0.5 - personal_space * 0.5
			)
	return Vector2(minimum_x, maximum_x)


func get_completed_interactions() -> int:
	return _completed_interactions


func get_social_partner() -> TownNPCLife:
	return _partner


func is_available_for_social() -> bool:
	return (
		life_enabled
		and not _external_lock
		and _state == STATE_IDLE
		and not is_instance_valid(_partner)
	)


func request_rest(duration := 2.0) -> void:
	if _external_lock:
		return
	_cancel_social_pair()
	_set_state(STATE_REST)
	_state_timer = maxf(duration, 0.1)


func set_external_interaction(active: bool, partner_position := Vector2.ZERO) -> void:
	if active:
		_cancel_social_pair()
		_external_lock = true
		_external_previous_ambient = npc_visual.ambient_enabled
		npc_visual.ambient_enabled = false
		_set_state(STATE_EXTERNAL_CHAT)
		_face_toward(partner_position.x)
		return
	_external_lock = false
	npc_visual.ambient_enabled = _external_previous_ambient
	_partner = null
	_set_state(STATE_IDLE)
	_state_timer = _next_idle_duration()


func _choose_next_activity() -> void:
	var roll := _rng.randf()
	if roll < social_chance and _try_begin_social_pair():
		return
	if roll < 0.68:
		var bounds := get_wander_bounds()
		_target_position = Vector2(
			_rng.randf_range(bounds.x, bounds.y),
			_home_position.y
		)
		_set_state(STATE_WANDER)
		return
	if roll < 0.82:
		_set_state(STATE_REST)
		_state_timer = _rng.randf_range(1.8, 3.4)
		return
	_set_state(STATE_EMOTE)
	_state_timer = _rng.randf_range(1.4, 2.2)


func _try_begin_social_pair() -> bool:
	var best_partner: TownNPCLife
	var best_distance := INF
	for candidate in get_parent().get_children():
		var other := candidate as TownNPCLife
		if other == null or other == self or not other.is_available_for_social():
			continue
		var distance := absf(other.position.x - position.x)
		if distance <= social_radius and distance < best_distance:
			best_distance = distance
			best_partner = other
	if not is_instance_valid(best_partner):
		return false
	var midpoint := (position.x + best_partner.position.x) * 0.5
	var self_is_left := position.x <= best_partner.position.x
	_begin_social_walk(
		best_partner,
		midpoint + (-social_spacing if self_is_left else social_spacing),
		get_instance_id() < best_partner.get_instance_id()
	)
	best_partner._begin_social_walk(
		self,
		midpoint + (social_spacing if self_is_left else -social_spacing),
		get_instance_id() > best_partner.get_instance_id()
	)
	return true


func _begin_social_walk(next_partner: TownNPCLife, target_x: float, leader: bool) -> void:
	_partner = next_partner
	_social_leader = leader
	_social_ready = false
	_target_position = Vector2(target_x, _home_position.y)
	_set_state(STATE_SOCIAL_WALK)


func _advance_motion(delta: float) -> void:
	var direction := signf(_target_position.x - position.x)
	if not is_zero_approx(direction):
		_face_toward(_target_position.x)
	position = position.move_toward(_target_position, walk_speed * delta)
	z_index = 1
	if position.distance_to(_target_position) > 0.5:
		return
	position = _target_position
	z_index = 0
	match _state:
		STATE_SOCIAL_WALK:
			_social_ready = true
			if is_instance_valid(_partner) and _partner._social_ready:
				if _social_leader:
					_begin_social_chat_pair()
				elif _partner._social_leader:
					_partner._begin_social_chat_pair()
		STATE_RETURN_HOME:
			_set_state(STATE_IDLE)
			_state_timer = _next_idle_duration()
		_:
			_set_state(STATE_IDLE)
			_state_timer = _rng.randf_range(1.2, 3.0)


func _begin_social_chat_pair() -> void:
	if not is_instance_valid(_partner):
		_set_state(STATE_RETURN_HOME)
		_target_position = _home_position
		return
	_set_state(STATE_SOCIAL_CHAT)
	_partner._set_state(STATE_SOCIAL_CHAT)
	_state_timer = social_chat_seconds
	_partner._state_timer = social_chat_seconds
	_face_toward(_partner.position.x)
	_partner._face_toward(position.x)


func _finish_social_pair() -> void:
	var finished_partner := _partner
	_completed_interactions += 1
	_partner = null
	_social_ready = false
	_social_leader = false
	_target_position = _home_position
	_set_state(STATE_RETURN_HOME)
	if is_instance_valid(finished_partner):
		finished_partner._completed_interactions += 1
		finished_partner._partner = null
		finished_partner._social_ready = false
		finished_partner._social_leader = false
		finished_partner._target_position = finished_partner._home_position
		finished_partner._set_state(STATE_RETURN_HOME)


func _cancel_social_pair() -> void:
	var cancelled_partner := _partner
	_partner = null
	_social_ready = false
	_social_leader = false
	if is_instance_valid(cancelled_partner) and cancelled_partner._partner == self:
		cancelled_partner._partner = null
		cancelled_partner._social_ready = false
		cancelled_partner._social_leader = false
		cancelled_partner._target_position = cancelled_partner._home_position
		cancelled_partner._set_state(STATE_RETURN_HOME)


func _set_state(next_state: StringName) -> void:
	_state = next_state
	match _state:
		STATE_WANDER, STATE_SOCIAL_WALK, STATE_RETURN_HOME:
			npc_visual.play_state(&"walk")
		STATE_SOCIAL_CHAT, STATE_EXTERNAL_CHAT:
			npc_visual.play_state(&"chat")
		STATE_REST:
			npc_visual.play_state(&"sit")
		STATE_EMOTE:
			npc_visual.play_state(EMOTE_STATES[_rng.randi_range(0, EMOTE_STATES.size() - 1)])
		_:
			npc_visual.play_state(&"idle")
	life_state_changed.emit(_state)


func _face_toward(target_x: float) -> void:
	if is_instance_valid(npc_visual):
		npc_visual.set_facing_direction(target_x - position.x)


func _next_idle_duration() -> float:
	return _rng.randf_range(minimum_idle_seconds, maximum_idle_seconds)


func _stable_seed() -> int:
	var character_id := String(get_meta("character_id", name))
	return absi(hash(character_id) + int(round(position.x * 17.0))) + 1
