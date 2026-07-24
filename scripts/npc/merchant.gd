extends "res://scripts/interaction/interactive_object.gd"

signal dialogue_requested(npc: Node, dialogue_id: StringName, interactor: Node)
signal shop_requested(merchant: Node, shop_id: StringName, interactor: Node)

@export var display_name: String = "Item Merchant"
@export var dialogue_id: StringName = &"item_merchant_greeting"
@export var shop_id: StringName = &"general_store"
@export var opens_shop_on_interact: bool = true

func interact(interactor: Node = null) -> bool:
	if not super.interact(interactor):
		return false

	if opens_shop_on_interact:
		shop_requested.emit(self, shop_id, interactor)
	else:
		dialogue_requested.emit(self, dialogue_id, interactor)

	return true

func request_shop(interactor: Node = null) -> void:
	if interaction_enabled:
		shop_requested.emit(self, shop_id, interactor)

func request_dialogue(interactor: Node = null) -> void:
	if interaction_enabled:
		dialogue_requested.emit(self, dialogue_id, interactor)
