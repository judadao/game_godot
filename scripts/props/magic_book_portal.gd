extends "res://scripts/interaction/portal.gd"

@export var display_name: String = "Arcane Destination"
@export var portal_tint: Color = Color(0.58, 0.72, 1.0, 1.0)
@export var float_height: float = 7.0
@export var float_speed: float = 2.1

@onready var book_anchor: Node2D = $BookAnchor
@onready var glow: Polygon2D = $PortalGlow
@onready var destination_label: Label = $DestinationLabel

var _book_origin: Vector2
var _time := 0.0


func _ready() -> void:
	super._ready()
	_book_origin = book_anchor.position
	glow.color = portal_tint * Color(1.0, 1.0, 1.0, 0.3)
	destination_label.text = display_name.to_upper()
	destination_label.modulate = portal_tint


func _process(delta: float) -> void:
	_time += delta
	book_anchor.position.y = _book_origin.y + sin(_time * float_speed) * float_height
	glow.scale = Vector2.ONE * (1.0 + sin(_time * float_speed) * 0.05)
