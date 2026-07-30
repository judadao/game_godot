extends Node2D

const ENTRANCE_TO_LABEL := {
	"MaterialYard": "MaterialYard",
	"PlayerBlacksmith": "PlayerBlacksmith",
	"TownHall": "TownHall",
	"SwordSoulShop": "SwordSoulShop",
	"EquipmentBlueprintShop": "EquipmentBlueprintShop",
	"FarEastResidence": "FarEastResidence",
}


func _ready() -> void:
	_hide_building_labels()
	var entrances := get_node_or_null("../../BuildingEntrances")
	if entrances == null:
		push_error("Town location labels require BuildingEntrances.")
		return
	for entrance_name in ENTRANCE_TO_LABEL:
		var entrance := entrances.get_node_or_null(entrance_name)
		var label := get_node_or_null(ENTRANCE_TO_LABEL[entrance_name]) as Label
		if entrance == null or label == null:
			push_error("Town location label contract is incomplete: %s." % entrance_name)
			continue
		entrance.interaction_available.connect(
			_on_foundation_entered.bind(label)
		)
		entrance.interaction_unavailable.connect(
			_on_foundation_exited.bind(label)
		)


func _hide_building_labels() -> void:
	for label_name in ENTRANCE_TO_LABEL.values():
		var label := get_node_or_null(label_name) as Label
		if label != null:
			label.hide()


func _on_foundation_entered(
	_interactive: Node,
	interactor: Node,
	label: Label
) -> void:
	if not interactor.is_in_group("Player"):
		return
	_hide_building_labels()
	label.show()


func _on_foundation_exited(
	_interactive: Node,
	interactor: Node,
	label: Label
) -> void:
	if interactor.is_in_group("Player"):
		label.hide()
