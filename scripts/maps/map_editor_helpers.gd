@tool
extends Node2D


func _enter_tree() -> void:
	_sync_editor_visibility()


func _ready() -> void:
	_sync_editor_visibility()


func _sync_editor_visibility() -> void:
	visible = Engine.is_editor_hint()
