extends Control
class_name TownNPCPortrait

const SUPPORTED_STATES: Array[StringName] = [
	&"idle", &"chat", &"laugh", &"happy", &"sad", &"surprised", &"angry",
]
const FRAME_RATE := 5.0

@export var character_texture: Texture2D
@export var default_state: StringName = &"idle"
@export_range(0.0, 4.0, 0.1) var phase_offset := 0.0

@onready var portrait_motion: Control = $PortraitMotion
@onready var portrait_texture: TextureRect = $PortraitMotion/PortraitTexture

var _active_state: StringName = &"idle"
var _elapsed := 0.0
var _pose_frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	_active_state = default_state if SUPPORTED_STATES.has(default_state) else &"idle"
	_elapsed = phase_offset
	set_character_texture(character_texture)
	resized.connect(_layout_portrait)
	_layout_portrait.call_deferred()


func _process(delta: float) -> void:
	advance_animation(delta)


func set_character_texture(texture: Texture2D) -> void:
	character_texture = texture
	if portrait_texture != null:
		portrait_texture.texture = character_texture
		_layout_portrait()


func play_state(state: StringName) -> bool:
	if not SUPPORTED_STATES.has(state):
		return false
	_active_state = state
	_elapsed = phase_offset
	_pose_frame = int(floor(_elapsed * FRAME_RATE)) % 4
	_apply_pose()
	return true


func advance_animation(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	_pose_frame = int(floor(_elapsed * FRAME_RATE)) % 4
	_apply_pose()


func get_active_state() -> StringName:
	return _active_state


func get_supported_states() -> Array[StringName]:
	return SUPPORTED_STATES.duplicate()


func _layout_portrait() -> void:
	if portrait_texture == null or character_texture == null or size.x <= 0.0:
		return
	var aspect: float = float(character_texture.get_height()) / maxf(1.0, float(character_texture.get_width()))
	var rendered_height: float = maxf(size.y, size.x * aspect)
	portrait_motion.position = Vector2.ZERO
	portrait_motion.size = size
	portrait_motion.pivot_offset = Vector2(size.x * 0.5, size.y)
	portrait_texture.position = Vector2(0.0, -rendered_height * 0.015)
	portrait_texture.size = Vector2(size.x, rendered_height)
	_apply_pose()


func _apply_pose() -> void:
	if portrait_motion == null:
		return
	var vertical: float = [0.0, -1.0, -2.0, -1.0][_pose_frame]
	var rotation_degrees := 0.0
	var scale_factor := Vector2.ONE
	var tone := Color.WHITE
	match _active_state:
		&"chat":
			vertical = [0.0, -2.0, -1.0, -2.0][_pose_frame]
			rotation_degrees = [0.5, 0.0, -0.5, 0.0][_pose_frame]
		&"laugh":
			vertical = [0.0, -3.0, -5.0, -2.0][_pose_frame]
			rotation_degrees = [-0.7, 0.7, -0.7, 0.7][_pose_frame]
		&"happy":
			vertical = [0.0, -2.0, -4.0, -2.0][_pose_frame]
			scale_factor = Vector2(1.01, 1.01)
		&"sad":
			vertical = [2.0, 3.0, 4.0, 3.0][_pose_frame]
			rotation_degrees = -0.5
			tone = Color(0.84, 0.9, 1.0)
		&"surprised":
			vertical = [0.0, -5.0, -2.0, -4.0][_pose_frame]
			scale_factor = [Vector2.ONE, Vector2(0.99, 1.025), Vector2.ONE, Vector2(0.99, 1.015)][_pose_frame]
		&"angry":
			vertical = [1.0, 0.0, 1.0, 0.0][_pose_frame]
			rotation_degrees = [-0.7, 0.7, -0.7, 0.7][_pose_frame]
			tone = Color(1.0, 0.86, 0.82)
	portrait_motion.position = Vector2(0.0, roundf(vertical))
	portrait_motion.scale = scale_factor
	portrait_motion.rotation_degrees = rotation_degrees
	portrait_texture.self_modulate = tone
