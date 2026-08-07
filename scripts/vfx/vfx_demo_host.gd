extends Node2D

@export var title := "Reusable VFX Primitive"
@export var replay_interval := 2.4

var _elapsed := 0.0


func _ready() -> void:
	var label := get_node_or_null("Title") as Label
	if label != null:
		label.text = title


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < replay_interval:
		return
	_elapsed = 0.0
	var effect := get_node_or_null("Effect")
	if effect != null and effect.has_method("play"):
		effect.call("play")
