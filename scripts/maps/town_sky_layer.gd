extends Node2D

@onready var sky: Sprite2D = $Sky
@onready var sky_wash: ColorRect = $SkyWash


func _ready() -> void:
	add_to_group("town_sky_tint_target")


func set_sky_tint(tint: Color) -> void:
	sky.self_modulate = tint


func get_sky_tint() -> Color:
	return sky.self_modulate


func set_sky_grade(grade_color: Color, strength: float) -> void:
	set_sky_atmosphere(grade_color, grade_color, strength, grade_color, 0.0, 0.12)


func set_sky_atmosphere(
	zenith_color: Color,
	horizon_color: Color,
	strength: float,
	glow_color: Color,
	glow_strength: float,
	sun_x: float
) -> void:
	var shader_material := sky.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("zenith_color", zenith_color)
	shader_material.set_shader_parameter("horizon_color", horizon_color)
	shader_material.set_shader_parameter("glow_color", glow_color)
	shader_material.set_shader_parameter("grade_strength", clampf(strength, 0.0, 1.0))
	shader_material.set_shader_parameter("glow_strength", clampf(glow_strength, 0.0, 1.0))
	shader_material.set_shader_parameter("sun_x", clampf(sun_x, -0.3, 1.3))
	var wash_material := sky_wash.material as ShaderMaterial
	if wash_material != null:
		wash_material.set_shader_parameter("zenith_color", zenith_color)
		wash_material.set_shader_parameter("horizon_color", horizon_color)
		wash_material.set_shader_parameter("glow_color", glow_color)
		wash_material.set_shader_parameter("atmosphere_strength", clampf(strength, 0.0, 1.0))
		wash_material.set_shader_parameter("glow_strength", clampf(glow_strength, 0.0, 1.0))
		wash_material.set_shader_parameter("sun_x", clampf(sun_x, -0.3, 1.3))


func get_sky_grade() -> Dictionary:
	var shader_material := sky.material as ShaderMaterial
	if shader_material == null:
		return {
			"color": Color.WHITE,
			"zenith_color": Color.WHITE,
			"horizon_color": Color.WHITE,
			"strength": 0.0,
			"glow_color": Color.WHITE,
			"glow_strength": 0.0,
			"sun_x": 0.12,
		}
	return {
		"color": shader_material.get_shader_parameter("horizon_color") as Color,
		"zenith_color": shader_material.get_shader_parameter("zenith_color") as Color,
		"horizon_color": shader_material.get_shader_parameter("horizon_color") as Color,
		"strength": float(shader_material.get_shader_parameter("grade_strength")),
		"glow_color": shader_material.get_shader_parameter("glow_color") as Color,
		"glow_strength": float(shader_material.get_shader_parameter("glow_strength")),
		"sun_x": float(shader_material.get_shader_parameter("sun_x")),
	}


func get_sky_contract() -> Dictionary:
	return {
		"cloud_free": true,
		"tintable": true,
		"color_grade": true,
		"dynamic_gradient": true,
		"source": sky.texture.resource_path if sky.texture != null else "",
	}
