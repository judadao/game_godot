@tool
extends CanvasLayer


func _enter_tree() -> void:
	visible = Engine.is_editor_hint()


func _ready() -> void:
	visible = Engine.is_editor_hint()
