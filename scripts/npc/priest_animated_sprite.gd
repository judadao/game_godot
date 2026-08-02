@tool
class_name PriestAnimatedSprite
extends Node2D

const FRAME_COUNT := 8
const ANIMATIONS := {
	&"front_idle": {"row": 0, "fps": 6.0},
	&"front_chat": {"row": 1, "fps": 8.0},
	&"side_walk": {"row": 2, "fps": 10.0},
	&"side_chat": {"row": 3, "fps": 8.0},
	&"side_idle": {
		"row": 3,
		"fps": 1.5,
		"frame_sequence": [0, 1, 0],
		"one_shot": true,
	},
	&"prayer": {"row": 4, "fps": 5.0},
	&"bless": {"row": 5, "fps": 6.0},
	&"comfort": {"row": 6, "fps": 6.0},
	&"share_goods": {"row": 6, "fps": 6.0},
	&"courage": {"row": 7, "fps": 6.0},
}

@export_enum("front_idle", "front_chat", "side_walk", "side_chat", "side_idle", "prayer", "bless", "comfort", "share_goods", "courage")
var animation_name := "front_idle":
	set(value):
		animation_name = value
		_elapsed = 0.0
		_frame_index = 0
		_apply_frame()

@export var autoplay := true

@onready var character_sprite: Sprite2D = $CharacterSprite

var _elapsed := 0.0
var _frame_index := 0


func _ready() -> void:
	_apply_frame()
	set_process(autoplay)


func _process(delta: float) -> void:
	advance_animation(delta)


func advance_animation(delta: float) -> void:
	if not autoplay or not ANIMATIONS.has(StringName(animation_name)):
		return
	_elapsed += maxf(delta, 0.0)
	var spec := ANIMATIONS[StringName(animation_name)] as Dictionary
	var fps := float(spec["fps"])
	var next_frame := 0
	var frame_sequence_variant: Variant = spec.get("frame_sequence", [])
	if frame_sequence_variant is Array and not (frame_sequence_variant as Array).is_empty():
		var frame_sequence := frame_sequence_variant as Array
		var sequence_index := int(floor(_elapsed * fps))
		if bool(spec.get("one_shot", false)):
			sequence_index = mini(sequence_index, frame_sequence.size() - 1)
		else:
			sequence_index %= frame_sequence.size()
		next_frame = int(frame_sequence[sequence_index])
	else:
		next_frame = int(floor(_elapsed * fps)) % FRAME_COUNT
	if next_frame != _frame_index:
		_frame_index = next_frame
		_apply_frame()


func play_animation(next_animation: StringName, restart := true) -> bool:
	if not ANIMATIONS.has(next_animation):
		push_warning("Unknown priest animation: %s" % next_animation)
		return false
	if restart or StringName(animation_name) != next_animation:
		_elapsed = 0.0
		_frame_index = 0
	animation_name = String(next_animation)
	autoplay = true
	set_process(true)
	_apply_frame()
	return true


func set_frame_for_review(frame_index: int) -> void:
	autoplay = false
	set_process(false)
	_frame_index = posmod(frame_index, FRAME_COUNT)
	_apply_frame()


func get_frame_index() -> int:
	return _frame_index


func get_animation_row() -> int:
	var spec: Dictionary = ANIMATIONS.get(StringName(animation_name), ANIMATIONS[&"front_idle"])
	return int(spec["row"])


func _apply_frame() -> void:
	if not is_instance_valid(character_sprite):
		return
	character_sprite.frame_coords = Vector2i(_frame_index, get_animation_row())
