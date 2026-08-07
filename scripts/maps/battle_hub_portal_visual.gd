class_name BattleHubPortalVisual
extends Node2D

@export var accent := Color(0.95, 0.48, 0.18, 1.0):
	set(value):
		accent = value
		if is_node_ready():
			_apply_state()

@export var sealed := false:
	set(value):
		sealed = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	_apply_state()


func set_sealed(value: bool) -> void:
	sealed = value


func _apply_state() -> void:
	var active_portal := get_node_or_null("ActivePortalAnimation") as Node2D
	var sealed_portal := get_node_or_null("SealedPortalAnimation") as Node2D
	var seal_rig := get_node_or_null("SealRig") as Node2D
	if active_portal != null:
		active_portal.visible = not sealed
		active_portal.modulate = Color(accent.r, accent.g, accent.b, 0.94)
	if sealed_portal != null:
		sealed_portal.visible = sealed
		sealed_portal.modulate = Color(
			lerpf(accent.r, 0.16, 0.7),
			lerpf(accent.g, 0.18, 0.7),
			lerpf(accent.b, 0.24, 0.65),
			0.66
		)
		for sprite in sealed_portal.find_children("*", "AnimatedSprite2D", true, false):
			(sprite as AnimatedSprite2D).speed_scale = 0.22
	if seal_rig != null:
		seal_rig.visible = sealed
		for child in seal_rig.get_children():
			if child is Line2D:
				(child as Line2D).default_color = Color(accent.r, accent.g, accent.b, 0.88)
