extends "res://scripts/interaction/interactive_object.gd"

signal building_ui_requested(
	entrance: Node,
	building_id: StringName,
	ui_route: StringName,
	service_id: StringName,
	interactor: Node
)

@export var display_name := "Building"
@export var building_id: StringName
@export var ui_route: StringName = &"town_progress"
@export var service_id: StringName


func interact(interactor: Node = null) -> bool:
	if not super.interact(interactor):
		return false
	building_ui_requested.emit(self, building_id, ui_route, service_id, interactor)
	return true
