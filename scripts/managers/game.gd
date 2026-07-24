extends Node

@export var starting_map: PackedScene = preload("res://scenes/maps/town.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")

@onready var map_root: Node = $MapRoot
@onready var ui_root: CanvasLayer = $UIRoot

func _ready() -> void:
	load_starting_map()
	load_hud()

func load_starting_map() -> void:
	for child in map_root.get_children():
		child.queue_free()

	if starting_map == null:
		push_error("Game entry has no starting_map assigned.")
		return

	map_root.add_child(starting_map.instantiate())

func load_hud() -> void:
	if hud_scene == null:
		return

	ui_root.add_child(hud_scene.instantiate())
