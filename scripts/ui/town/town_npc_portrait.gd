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
var _atlas_texture: AtlasTexture
var _atlas_columns := 1
var _atlas_rows := 1
var _atlas_fps := FRAME_RATE
var _state_rows: Dictionary = {}
var _crop_mode: StringName = &"full_body"
var _one_shot := false
var _animation_finished := false


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
	_atlas_texture = null
	_atlas_columns = 1
	_atlas_rows = 1
	_state_rows.clear()
	if portrait_texture != null:
		portrait_texture.texture = character_texture
		_layout_portrait()


func configure_animation_atlas(portrait: Dictionary) -> bool:
	var texture_path := String(portrait.get("texture_path", ""))
	var loaded_texture := load(texture_path) as Texture2D
	if loaded_texture == null:
		push_error("Animated portrait texture could not load: %s" % texture_path)
		return false
	var columns := int(portrait.get("columns", 0))
	var rows := int(portrait.get("rows", 0))
	var state_rows_variant: Variant = portrait.get("state_rows", {})
	if columns <= 0 or rows <= 0 or not state_rows_variant is Dictionary:
		push_error("Animated portrait requires a positive grid and state rows.")
		return false
	character_texture = loaded_texture
	_atlas_columns = columns
	_atlas_rows = rows
	_atlas_fps = maxf(0.1, float(portrait.get("fps", FRAME_RATE)))
	_crop_mode = StringName(portrait.get("crop_mode", "full_body"))
	_one_shot = bool(portrait.get("one_shot", false))
	_animation_finished = false
	_state_rows = (state_rows_variant as Dictionary).duplicate(true)
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = character_texture
	if portrait_texture != null:
		portrait_texture.texture = _atlas_texture
	_elapsed = phase_offset
	_pose_frame = 0
	_update_atlas_region()
	_layout_portrait()
	return true


func play_state(state: StringName) -> bool:
	if not SUPPORTED_STATES.has(state):
		return false
	_active_state = state
	_elapsed = 0.0
	_pose_frame = 0
	_animation_finished = false
	_apply_pose()
	return true


func advance_animation(delta: float) -> void:
	if _one_shot and _animation_finished:
		return
	_elapsed += maxf(delta, 0.0)
	var raw_frame := int(floor(_elapsed * _atlas_fps))
	if _one_shot:
		_pose_frame = mini(raw_frame, _atlas_columns - 1)
		_animation_finished = raw_frame >= _atlas_columns - 1
	else:
		_pose_frame = raw_frame % _atlas_columns
	_apply_pose()


func get_active_state() -> StringName:
	return _active_state


func get_supported_states() -> Array[StringName]:
	return SUPPORTED_STATES.duplicate()


func get_crop_mode() -> StringName:
	return _crop_mode


func is_animation_finished() -> bool:
	return _animation_finished


func get_pose_frame() -> int:
	return _pose_frame


func _layout_portrait() -> void:
	if portrait_texture == null or character_texture == null or size.x <= 0.0:
		return
	var cell_width := float(character_texture.get_width()) / maxf(1.0, float(_atlas_columns))
	var cell_height := float(character_texture.get_height()) / maxf(1.0, float(_atlas_rows))
	var aspect: float = cell_height / maxf(1.0, cell_width)
	var rendered_width := size.x
	var rendered_height: float = maxf(size.y, rendered_width * aspect)
	var top_offset := -rendered_height * 0.015
	if _crop_mode == &"half_body":
		rendered_width = size.x * 1.48
		rendered_height = maxf(size.y * 1.55, rendered_width * aspect)
		top_offset = -rendered_height * 0.12
	portrait_motion.position = Vector2.ZERO
	portrait_motion.size = size
	portrait_motion.pivot_offset = Vector2(size.x * 0.5, size.y)
	portrait_texture.position = Vector2((size.x - rendered_width) * 0.5, top_offset)
	portrait_texture.size = Vector2(rendered_width, rendered_height)
	_apply_pose()


func _apply_pose() -> void:
	if portrait_motion == null:
		return
	_update_atlas_region()
	var motion_frame := _pose_frame % 4
	var vertical: float = [0.0, -1.0, -2.0, -1.0][motion_frame]
	var rotation_degrees := 0.0
	var scale_factor := Vector2.ONE
	var tone := Color.WHITE
	match _active_state:
		&"chat":
			vertical = [0.0, -2.0, -1.0, -2.0][motion_frame]
			rotation_degrees = [0.5, 0.0, -0.5, 0.0][motion_frame]
		&"laugh":
			vertical = [0.0, -3.0, -5.0, -2.0][motion_frame]
			rotation_degrees = [-0.7, 0.7, -0.7, 0.7][motion_frame]
		&"happy":
			vertical = [0.0, -2.0, -4.0, -2.0][motion_frame]
			scale_factor = Vector2(1.01, 1.01)
		&"sad":
			vertical = [2.0, 3.0, 4.0, 3.0][motion_frame]
			rotation_degrees = -0.5
			tone = Color(0.84, 0.9, 1.0)
		&"surprised":
			vertical = [0.0, -5.0, -2.0, -4.0][motion_frame]
			scale_factor = [Vector2.ONE, Vector2(0.99, 1.025), Vector2.ONE, Vector2(0.99, 1.015)][motion_frame]
		&"angry":
			vertical = [1.0, 0.0, 1.0, 0.0][motion_frame]
			rotation_degrees = [-0.7, 0.7, -0.7, 0.7][motion_frame]
			tone = Color(1.0, 0.86, 0.82)
	portrait_motion.position = Vector2(0.0, roundf(vertical))
	portrait_motion.scale = scale_factor
	portrait_motion.rotation_degrees = rotation_degrees
	portrait_texture.self_modulate = tone


func _update_atlas_region() -> void:
	if _atlas_texture == null or character_texture == null:
		return
	var cell_size := Vector2(
		float(character_texture.get_width()) / float(_atlas_columns),
		float(character_texture.get_height()) / float(_atlas_rows)
	)
	var row := clampi(int(_state_rows.get(String(_active_state), 0)), 0, _atlas_rows - 1)
	_atlas_texture.region = Rect2(Vector2(_pose_frame, row) * cell_size, cell_size)
