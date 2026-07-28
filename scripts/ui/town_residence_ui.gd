class_name TownResidenceUI
extends Control

signal closed

@onready var residence_name: Label = $Shade/Center/ResidencePanel/PanelMargin/Content/ResidenceName
@onready var message: Label = $Shade/Center/ResidencePanel/PanelMargin/Content/Message

var _context_id: StringName


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func set_context(context_id: StringName) -> void:
	_context_id = context_id
	if not is_node_ready():
		return
	residence_name.text = (
		"EAST RESIDENCE"
		if context_id == &"east_residence"
		else "FAR EAST RESIDENCE"
	)
	message.text = "Private residence\nNo public services are available here."


func get_context_id() -> StringName:
	return _context_id
