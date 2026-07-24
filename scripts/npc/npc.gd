extends "res://scripts/interaction/interactive_object.gd"

signal dialogue_requested(npc: Node, dialogue_id: StringName, interactor: Node)

@export var display_name: String = "Town Resident"
@export var dialogue_id: StringName = &"town_resident"

func interact(interactor: Node = null) -> bool:
	if not super.interact(interactor):
		return false

	dialogue_requested.emit(self, dialogue_id, interactor)
	return true

func request_dialogue(interactor: Node = null) -> void:
	if interaction_enabled:
		dialogue_requested.emit(self, dialogue_id, interactor)
