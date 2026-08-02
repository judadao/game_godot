extends Node2D

@onready var sky: Sprite2D = $Sky


func _ready() -> void:
	add_to_group("town_sky_tint_target")


func set_sky_tint(tint: Color) -> void:
	sky.self_modulate = tint


func get_sky_tint() -> Color:
	return sky.self_modulate


func set_sky_grade(grade_color: Color, strength: float) -> void:
	var shader_material := sky.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("grade_color", grade_color)
	shader_material.set_shader_parameter("grade_strength", clampf(strength, 0.0, 1.0))


func get_sky_grade() -> Dictionary:
	var shader_material := sky.material as ShaderMaterial
	if shader_material == null:
		return {"color": Color.WHITE, "strength": 0.0}
	return {
		"color": shader_material.get_shader_parameter("grade_color") as Color,
		"strength": float(shader_material.get_shader_parameter("grade_strength")),
	}


func get_sky_contract() -> Dictionary:
	return {
		"cloud_free": true,
		"tintable": true,
		"color_grade": true,
		"source": sky.texture.resource_path if sky.texture != null else "",
	}
