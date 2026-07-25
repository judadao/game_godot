extends "res://scripts/interaction/interactive_object.gd"

signal portal_entered(portal: Node, target_scene_path: String, target_spawn_name: StringName, interactor: Node)

@export_file("*.tscn") var target_scene_path: String = "res://scenes/maps/town.tscn"
@export var target_spawn_name: StringName = &"PlayerSpawn"
@export var show_default_visual: bool = true

@onready var default_visual: CanvasItem = $Visual


func _ready() -> void:
	super._ready()
	default_visual.visible = show_default_visual

func interact(interactor: Node = null) -> bool:
	if not super.interact(interactor):
		return false

	portal_entered.emit(self, target_scene_path, target_spawn_name, interactor)
	return true

func enter_portal(interactor: Node = null) -> void:
	if interaction_enabled:
		portal_entered.emit(self, target_scene_path, target_spawn_name, interactor)
