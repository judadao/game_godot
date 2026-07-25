@tool
extends Node2D

const INITIAL_CAMERA_VIEW := Rect2(0, 0, 1280, 720)
const PREVIEW_COLOR := Color(1.0, 0.78, 0.22, 0.9)


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(INITIAL_CAMERA_VIEW, PREVIEW_COLOR, false, 3.0)
	draw_line(Vector2(640, 0), Vector2(640, 18), PREVIEW_COLOR, 3.0)
