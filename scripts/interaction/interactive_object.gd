extends StaticBody2D

signal interaction_available(interactive: Node, interactor: Node)
signal interaction_unavailable(interactive: Node, interactor: Node)
signal interacted(interactive: Node, interactor: Node)

@export var interaction_id: StringName = &""
@export var prompt_text: String = "Interact"
@export var interaction_enabled: bool = true:
	set(value):
		interaction_enabled = value
		_update_interaction_area()

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	_update_interaction_area()
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

func interact(interactor: Node = null) -> bool:
	if not interaction_enabled:
		return false

	interacted.emit(self, interactor)
	return true

func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value

func is_interaction_enabled() -> bool:
	return interaction_enabled

func get_interaction_prompt() -> String:
	return prompt_text

func _update_interaction_area() -> void:
	if not is_node_ready():
		return

	interaction_area.monitoring = interaction_enabled
	interaction_area.monitorable = interaction_enabled

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if interaction_enabled:
		interaction_available.emit(self, body)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	interaction_unavailable.emit(self, body)
