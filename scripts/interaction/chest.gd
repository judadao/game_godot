extends "res://scripts/interaction/interactive_object.gd"

signal chest_opened(chest: Node, loot_table_id: StringName, interactor: Node)

@export var loot_table_id: StringName = &"prototype_town_chest"
@export var can_reopen: bool = false

var is_open: bool = false

func interact(interactor: Node = null) -> bool:
	if is_open and not can_reopen:
		return false

	if not super.interact(interactor):
		return false

	is_open = true
	chest_opened.emit(self, loot_table_id, interactor)
	return true

func reset_chest() -> void:
	is_open = false
