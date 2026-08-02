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
const SUPPORTED_STATES: Array[StringName] = [
	STATE_IDLE, STATE_WALK, STATE_SIT, STATE_CHAT, STATE_LAUGH,
	STATE_HAPPY, STATE_SAD, STATE_SURPRISED, STATE_ANGRY,
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
}

@export_range(80.0, 160.0, 1.0) var target_height := 118.0
@export_enum("calm", "social", "merchant", "scholar", "guard") var ambient_profile := "calm"
@export_enum("idle", "walk", "sit", "chat", "laugh", "happy", "sad", "surprised", "angry") var initial_state := "idle"
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


func _ready() -> void:
	if body_sprite.texture == null:
		push_error("TownNPCVisual requires a character texture.")
		return
	_active_state = StringName(initial_state) if SUPPORTED_STATES.has(StringName(initial_state)) else STATE_IDLE
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
	_pose_frame = int(floor(_elapsed * FRAME_RATE)) % 4
	if ambient_enabled:
		_ambient_timer -= step
		if _ambient_timer <= 0.0:
			_advance_ambient_state()
	_apply_pose()


func play_state(state: StringName) -> bool:
	if not SUPPORTED_STATES.has(state):
		return false
	_active_state = state
	_elapsed = phase_offset
	_pose_frame = int(floor(_elapsed * FRAME_RATE)) % 4
	_apply_pose()
	return true


func get_active_state() -> StringName:
	return _active_state


func get_supported_states() -> Array[StringName]:
	return SUPPORTED_STATES.duplicate()


func get_animation_snapshot() -> Dictionary:
	return {
		"state": _active_state,
		"frame": _pose_frame,
		"position": visual_root.position,
		"scale": visual_root.scale,
		"rotation": visual_root.rotation,
		"region": body_sprite.region_rect,
		"facing_sign": _facing_sign,
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
			return [STATE_IDLE, STATE_CHAT, STATE_IDLE, STATE_LAUGH, STATE_HAPPY, STATE_WALK]
		"merchant":
			return [STATE_IDLE, STATE_CHAT, STATE_IDLE, STATE_LAUGH, STATE_SURPRISED]
		"scholar":
			return [STATE_IDLE, STATE_CHAT, STATE_SURPRISED, STATE_LAUGH, STATE_ANGRY]
		"guard":
			return [STATE_IDLE, STATE_WALK, STATE_IDLE, STATE_ANGRY, STATE_CHAT]
		_:
			return [STATE_IDLE, STATE_CHAT, STATE_IDLE, STATE_HAPPY]


func _ambient_interval() -> float:
	return 4.4 + fmod(absf(phase_offset) * 1.7, 2.2)


func _apply_pose() -> void:
	if visual_root == null:
		return
	if body_sprite.region_enabled:
		var state_row := int(STATE_ROWS.get(_active_state, 0))
		body_sprite.region_rect = Rect2(
			_pose_frame * ATLAS_CELL_SIZE.x,
			state_row * ATLAS_CELL_SIZE.y,
			ATLAS_CELL_SIZE.x,
			ATLAS_CELL_SIZE.y
		)
	body_sprite.flip_h = (
		_facing_sign < 0.0
		and (_active_state == STATE_WALK or _active_state == STATE_CHAT)
	)
	var vertical_offsets := [0.0, -1.0, -2.0, -1.0]
	var position_offset := Vector2(0.0, vertical_offsets[_pose_frame])
	var scale_factor := Vector2.ONE
	var rotation_degrees := 0.0
	var tone := Color.WHITE
	match _active_state:
		STATE_WALK:
			position_offset.y = [0.0, -2.0, 0.0, -2.0][_pose_frame]
			rotation_degrees = [-0.25, 0.25, -0.25, 0.25][_pose_frame]
		STATE_SIT:
			position_offset.y = [0.0, -1.0, 0.0, -1.0][_pose_frame]
		STATE_CHAT:
			position_offset.y = [0.0, -1.0, 0.0, -1.0][_pose_frame]
			rotation_degrees = [0.3, 0.0, -0.3, 0.0][_pose_frame]
		STATE_LAUGH:
			position_offset.y = [0.0, -3.0, -5.0, -2.0][_pose_frame]
			rotation_degrees = [-1.0, 1.0, -1.0, 1.0][_pose_frame]
		STATE_HAPPY:
			position_offset.y = [0.0, -2.0, -4.0, -2.0][_pose_frame]
			scale_factor = Vector2(1.02, 1.02)
		STATE_SAD:
			position_offset.y = [3.0, 4.0, 5.0, 4.0][_pose_frame]
			rotation_degrees = [-0.8, -1.2, -0.8, -1.2][_pose_frame]
			tone = Color(0.82, 0.88, 1.0)
		STATE_SURPRISED:
			position_offset.y = [0.0, -5.0, -2.0, -4.0][_pose_frame]
			scale_factor = [Vector2.ONE, Vector2(0.98, 1.05), Vector2.ONE, Vector2(0.98, 1.03)][_pose_frame]
		STATE_ANGRY:
			position_offset.y = [1.0, 0.0, 1.0, 0.0][_pose_frame]
			rotation_degrees = [-1.2, 1.2, -1.2, 1.2][_pose_frame]
			tone = Color(1.0, 0.82, 0.78)
		_:
			scale_factor.y = [1.0, 1.006, 1.012, 1.006][_pose_frame]
	visual_root.position = position_offset.round()
	visual_root.scale = _base_scale * scale_factor
	visual_root.rotation_degrees = rotation_degrees
	body_sprite.self_modulate = tone
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(30.0, -target_height + 8.0)
	match _active_state:
		STATE_CHAT:
			_draw_chat_marks(origin)
		STATE_LAUGH:
			_draw_laugh_marks(origin)
		STATE_HAPPY:
			_draw_heart(origin)
		STATE_SAD:
			_draw_teardrop(origin)
		STATE_SURPRISED:
			_draw_exclamation(origin)
		STATE_ANGRY:
			_draw_anger_mark(origin)


func _draw_chat_marks(origin: Vector2) -> void:
	for index in range(3):
		var rise := float((_pose_frame + index) % 2)
		draw_circle(origin + Vector2(index * 8.0, -index * 4.0 - rise), 3.0, Color("f5deb0"))


func _draw_laugh_marks(origin: Vector2) -> void:
	var color := Color("ffd166")
	draw_line(origin + Vector2(-3, 3), origin + Vector2(6, -5), color, 3.0)
	draw_line(origin + Vector2(7, 5), origin + Vector2(15, -2), color, 3.0)


func _draw_heart(origin: Vector2) -> void:
	var color := Color("ef6f72")
	draw_circle(origin + Vector2(3, 1), 4.0, color)
	draw_circle(origin + Vector2(10, 1), 4.0, color)
	draw_colored_polygon(PackedVector2Array([origin, origin + Vector2(13, 0), origin + Vector2(6.5, 11)]), color)


func _draw_teardrop(origin: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([origin, origin + Vector2(-3, 6), origin + Vector2(3, 6)]), Color("75c8e8"))


func _draw_exclamation(origin: Vector2) -> void:
	var color := Color("ffe08a")
	draw_rect(Rect2(origin, Vector2(3, 10)), color)
	draw_rect(Rect2(origin + Vector2(0, 13), Vector2(3, 3)), color)


func _draw_anger_mark(origin: Vector2) -> void:
	var color := Color("e85d4a")
	draw_line(origin + Vector2(-5, 0), origin + Vector2(5, 5), color, 2.0)
	draw_line(origin + Vector2(0, -5), origin + Vector2(5, 5), color, 2.0)
	draw_line(origin + Vector2(5, 5), origin + Vector2(10, -2), color, 2.0)
