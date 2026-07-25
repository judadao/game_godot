extends "res://scripts/interaction/interactive_object.gd"

signal portal_entered(portal: Node, target_scene_path: String, target_spawn_name: StringName, interactor: Node)
signal locked_interaction(reason: String)

@export_file("*.tscn") var target_scene_path: String = "res://scenes/maps/town.tscn"
@export var target_spawn_name: StringName = &"PlayerSpawn"
@export var show_default_visual: bool = true
@export var locked := false
@export var locked_reason := "Defeat the boss to unlock this route."

@onready var default_visual: CanvasItem = $Visual


func _ready() -> void:
	super._ready()
	default_visual.visible = show_default_visual

func interact(interactor: Node = null) -> bool:
	if locked:
		locked_interaction.emit(locked_reason)
		return false
	if not super.interact(interactor):
		return false

	portal_entered.emit(self, target_scene_path, target_spawn_name, interactor)
	return true

func enter_portal(interactor: Node = null) -> void:
	if interaction_enabled and not locked:
		portal_entered.emit(self, target_scene_path, target_spawn_name, interactor)


func set_locked(is_locked: bool, reason: String = "") -> void:
	locked = is_locked
	if not reason.is_empty():
		locked_reason = reason


func get_interaction_prompt() -> String:
	return locked_reason if locked else super.get_interaction_prompt()
