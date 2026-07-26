@tool
class_name AutumnInteractionPrompt
extends Control

const WORLD_BOTTOM_RATIO := 0.66
const VIEWPORT_MARGIN := 16.0
const TARGET_RISE := 72.0

var _target_ref: WeakRef


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	if not Engine.is_editor_hint():
		visible = false


func _process(_delta: float) -> void:
	_sync_to_target()


func set_target(target: CanvasItem) -> void:
	if target == null:
		clear_target()
		return
	_target_ref = weakref(target)
	set_process(true)
	_sync_to_target()


func clear_target() -> void:
	_target_ref = null
	set_process(false)


func _sync_to_target() -> void:
	var target := _target_ref.get_ref() as CanvasItem if _target_ref != null else null
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		visible = false
		clear_target()
		return
	var viewport_size := get_viewport_rect().size
	var target_position := target.get_global_transform_with_canvas().origin
	var maximum_x := maxf(VIEWPORT_MARGIN, viewport_size.x - size.x - VIEWPORT_MARGIN)
	var maximum_y := maxf(
		VIEWPORT_MARGIN,
		viewport_size.y * WORLD_BOTTOM_RATIO - size.y - VIEWPORT_MARGIN
	)
	position = Vector2(
		clampf(target_position.x - size.x * 0.5, VIEWPORT_MARGIN, maximum_x),
		clampf(target_position.y - size.y - TARGET_RISE, VIEWPORT_MARGIN, maximum_y)
	)
