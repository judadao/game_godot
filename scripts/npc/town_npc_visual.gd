extends Node2D
class_name TownNPCVisual

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_SIT: StringName = &"sit"
const STATE_CHAT: StringName = &"chat"
const STATE_LAUGH: StringName = &"laugh"
const STATE_HAPPY: StringName = &"happy"
const STATE_SAD: StringName = &"sad"
const STATE_SURPRISED: StringName = &"surprised"
const STATE_ANGRY: StringName = &"angry"
const STATE_IDLE_LOOK: StringName = &"idle_look"
const STATE_IDLE_STRETCH: StringName = &"idle_stretch"
const STATE_GREET: StringName = &"greet"
const STATE_WORK: StringName = &"work"
const SUPPORTED_STATES: Array[StringName] = [
	STATE_IDLE, STATE_WALK, STATE_SIT, STATE_CHAT, STATE_LAUGH,
	STATE_HAPPY, STATE_SAD, STATE_SURPRISED, STATE_ANGRY,
	STATE_IDLE_LOOK, STATE_IDLE_STRETCH, STATE_GREET, STATE_WORK,
]
const FRAME_RATE := 5.0
const ATLAS_CELL_SIZE := Vector2(144.0, 152.0)
const ATLAS_BODY_HEIGHT := 132.0
const STATE_ROWS := {
	STATE_IDLE: 0,
	STATE_WALK: 1,
	STATE_SIT: 2,
	STATE_CHAT: 3,
	STATE_LAUGH: 4,
	STATE_HAPPY: 5,
	STATE_SAD: 6,
	STATE_SURPRISED: 7,
	STATE_ANGRY: 8,
	STATE_IDLE_LOOK: 9,
	STATE_IDLE_STRETCH: 10,
	STATE_GREET: 11,
	STATE_WORK: 12,
}
const CHARACTER_STATE_ROWS := {
	&"witch": {
		&"read_grimoire": 13,
		&"brew_potion": 14,
		&"divination": 15,
		&"cast_ward": 16,
		&"hidden_concern": 9,
	},
	&"scientist": {
		&"write_notes": 13,
		&"measure": 14,
		&"assemble": 15,
		&"malfunction": 16,
		&"inspiration": 5,
		&"concern": 9,
	},
}
const CHARACTER_ACTION_FRAME_RATE := 2.0
const CHARACTER_ACTION_SETTLE_SECONDS := 4.0
const SETTLED_IDLE_FRAME_RATE := 1.0
const LEFT_FACING_DIRECTIONAL_CHARACTERS: Array[StringName] = [&"witch"]

@export_range(80.0, 160.0, 1.0) var target_height := 118.0
@export_enum("calm", "social", "merchant", "scholar", "guard") var ambient_profile := "calm"
@export_enum("idle", "walk", "sit", "chat", "laugh", "happy", "sad", "surprised", "angry", "idle_look", "idle_stretch", "greet", "work") var initial_state := "idle"
@export var ambient_enabled := true
@export_range(0.0, 4.0, 0.1) var phase_offset := 0.0

@onready var visual_root: Node2D = $VisualRoot
@onready var body_sprite: Sprite2D = $VisualRoot/BodySprite

var _active_state: StringName = STATE_IDLE
var _elapsed := 0.0
var _pose_frame := 0
var _base_scale := Vector2.ONE
var _ambient_timer := 0.0
var _ambient_index := 0
var _facing_sign := 1.0
var _native_directional_facing_sign := 1.0


func _ready() -> void:
	if body_sprite.texture == null:
		push_error("TownNPCVisual requires a character texture.")
		return
	_native_directional_facing_sign = _resolve_native_directional_facing_sign()
	_active_state = StringName(initial_state) if get_supported_states().has(StringName(initial_state)) else STATE_IDLE
	var source_height := ATLAS_BODY_HEIGHT if body_sprite.region_enabled else float(body_sprite.texture.get_height())
	body_sprite.position = (
		Vector2(0.0, -ATLAS_CELL_SIZE.y * 0.5 + 8.0)
		if body_sprite.region_enabled
		else Vector2(0.0, -source_height * 0.5)
	)
	var uniform_scale := target_height / maxf(1.0, source_height)
	_base_scale = Vector2(uniform_scale, uniform_scale)
	_elapsed = phase_offset
	_ambient_timer = _ambient_interval()
	_apply_pose()


func _process(delta: float) -> void:
	advance_animation(delta)


func advance_animation(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_elapsed += step
	if _is_character_action_state(_active_state):
		if _has_character_action_settled():
			_pose_frame = int(floor(
				(_elapsed - CHARACTER_ACTION_SETTLE_SECONDS) * SETTLED_IDLE_FRAME_RATE
			)) % 4
		else:
			_pose_frame = mini(int(floor(_elapsed * CHARACTER_ACTION_FRAME_RATE)), 3)
	else:
		_pose_frame = int(floor(_elapsed * FRAME_RATE)) % 4
	if ambient_enabled:
		_ambient_timer -= step
		if _ambient_timer <= 0.0:
			_advance_ambient_state()
	_apply_pose()


func play_state(state: StringName) -> bool:
	if not get_supported_states().has(state):
		return false
	_active_state = state
	_elapsed = 0.0 if _is_character_action_state(state) else phase_offset
	_pose_frame = 0 if _is_character_action_state(state) else int(floor(_elapsed * FRAME_RATE)) % 4
	_apply_pose()
	return true


func get_active_state() -> StringName:
	return _active_state


func get_supported_states() -> Array[StringName]:
	var supported := SUPPORTED_STATES.duplicate()
	var character_rows := _character_state_rows()
	for state in character_rows:
		if not supported.has(StringName(state)):
			supported.append(StringName(state))
	return supported


func has_runtime_overlay_for_active_state() -> bool:
	return _active_state == STATE_CHAT


func get_animation_snapshot() -> Dictionary:
	return {
		"state": _active_state,
		"rendered_state": _rendered_state(),
		"frame": _pose_frame,
		"position": visual_root.position,
		"scale": visual_root.scale,
		"rotation": visual_root.rotation,
		"region": body_sprite.region_rect,
		"facing_sign": _facing_sign,
		"native_directional_facing_sign": _native_directional_facing_sign,
	}


func set_facing_direction(direction: float) -> void:
	if not is_zero_approx(direction):
		_facing_sign = signf(direction)
	_apply_pose()


func _advance_ambient_state() -> void:
	var sequence := _ambient_sequence()
	_ambient_index = (_ambient_index + 1) % sequence.size()
	_active_state = sequence[_ambient_index]
	_elapsed = phase_offset
	_ambient_timer = 1.6 if _active_state != STATE_IDLE else _ambient_interval()


func _ambient_sequence() -> Array[StringName]:
	match ambient_profile:
		"social":
			return [STATE_IDLE, STATE_IDLE_LOOK, STATE_CHAT, STATE_GREET, STATE_LAUGH, STATE_HAPPY, STATE_WALK]
		"merchant":
			return [STATE_IDLE, STATE_WORK, STATE_CHAT, STATE_IDLE_STRETCH, STATE_LAUGH, STATE_SURPRISED]
		"scholar":
			return [STATE_IDLE, STATE_WORK, STATE_IDLE_LOOK, STATE_CHAT, STATE_SURPRISED, STATE_LAUGH]
		"guard":
			return [STATE_IDLE, STATE_IDLE_LOOK, STATE_WALK, STATE_WORK, STATE_GREET, STATE_CHAT]
		_:
			return [STATE_IDLE, STATE_IDLE_LOOK, STATE_IDLE_STRETCH, STATE_CHAT, STATE_HAPPY]


func _ambient_interval() -> float:
	return 4.4 + fmod(absf(phase_offset) * 1.7, 2.2)


func _apply_pose() -> void:
	if visual_root == null:
		return
	if body_sprite.region_enabled:
		var state_row := _state_row(_rendered_state())
		body_sprite.region_rect = Rect2(
			_pose_frame * ATLAS_CELL_SIZE.x,
			state_row * ATLAS_CELL_SIZE.y,
			ATLAS_CELL_SIZE.x,
			ATLAS_CELL_SIZE.y
		)
	var rendered_state := _rendered_state()
	var directional_state := (
		rendered_state == STATE_WALK
		or rendered_state == STATE_CHAT
		or rendered_state == STATE_GREET
	)
	body_sprite.flip_h = (
		directional_state
		and not is_equal_approx(_facing_sign, _native_directional_facing_sign)
	)
	var position_offset := Vector2.ZERO
	var scale_factor := Vector2.ONE
	var rotation_degrees := 0.0
	var tone := Color.WHITE
	match rendered_state:
		STATE_WALK:
			position_offset.y = [0.0, -2.0, 0.0, -2.0][_pose_frame]
			rotation_degrees = [-0.25, 0.25, -0.25, 0.25][_pose_frame]
		STATE_SIT:
			position_offset.y = [0.0, -1.0, 0.0, -1.0][_pose_frame]
		STATE_CHAT:
			position_offset.y = [0.0, -1.0, 0.0, -1.0][_pose_frame]
			rotation_degrees = [0.3, 0.0, -0.3, 0.0][_pose_frame]
		STATE_LAUGH:
			pass
		STATE_HAPPY:
			pass
		STATE_SAD:
			tone = Color(0.82, 0.88, 1.0)
		STATE_SURPRISED:
			pass
		STATE_ANGRY:
			tone = Color(1.0, 0.82, 0.78)
		STATE_IDLE_LOOK:
			pass
		STATE_IDLE_STRETCH:
			pass
		STATE_GREET:
			pass
		STATE_WORK:
			pass
		_:
			pass
	visual_root.position = position_offset.round()
	visual_root.scale = _base_scale * scale_factor
	visual_root.rotation_degrees = rotation_degrees
	body_sprite.self_modulate = tone
	queue_redraw()


func _resolve_native_directional_facing_sign() -> float:
	var actor := get_parent()
	if actor == null:
		return 1.0
	var character_id := StringName(actor.get_meta("character_id", ""))
	return -1.0 if LEFT_FACING_DIRECTIONAL_CHARACTERS.has(character_id) else 1.0


func _state_row(state: StringName) -> int:
	var character_rows := _character_state_rows()
	if character_rows.has(state):
		return int(character_rows[state])
	return int(STATE_ROWS.get(state, 0))


func _character_state_rows() -> Dictionary:
	var actor := get_parent()
	if actor == null:
		return {}
	var character_id := StringName(actor.get_meta("character_id", ""))
	return CHARACTER_STATE_ROWS.get(character_id, {}) as Dictionary


func _is_character_action_state(state: StringName) -> bool:
	return _character_state_rows().has(state)


func _has_character_action_settled() -> bool:
	return (
		_is_character_action_state(_active_state)
		and _elapsed >= CHARACTER_ACTION_SETTLE_SECONDS
	)


func _rendered_state() -> StringName:
	# A role action is performed once, held long enough to read, then returns to
	# a slow breathing idle while TownNPCLife keeps the calm work-state dwell.
	# This avoids both a rapid GIF loop and a 12–18 second frozen final pose.
	return STATE_IDLE if _has_character_action_settled() else _active_state


func _draw() -> void:
	if not has_runtime_overlay_for_active_state():
		return
	var origin := Vector2(30.0, -target_height + 8.0)
	_draw_chat_marks(origin)


func _draw_chat_marks(origin: Vector2) -> void:
	for index in range(3):
		var rise := float((_pose_frame + index) % 2)
		draw_circle(origin + Vector2(index * 8.0, -index * 4.0 - rise), 3.0, Color("f5deb0"))
