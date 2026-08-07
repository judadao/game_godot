class_name ParticleBurst2D
extends GPUParticles2D

@export var primary_color := Color.WHITE
@export var secondary_color := Color(0.35, 0.8, 1.0, 1.0)
@export_range(1, 160, 1) var particle_amount := 32
@export_range(0.05, 4.0, 0.01) var burst_lifetime := 0.65
@export_range(0.0, 1.0, 0.01) var burst_explosiveness := 0.88
@export_range(0.0, 720.0, 1.0) var initial_speed := 150.0
@export_range(0.0, 180.0, 1.0) var spread_degrees := 72.0
@export var direction := Vector2.RIGHT
@export var gravity := Vector2(0.0, 120.0)
@export var visual_bounds := Vector2(512.0, 512.0)


func _ready() -> void:
	configure()


func configure() -> void:
	amount = clampi(particle_amount, 1, 160)
	lifetime = maxf(burst_lifetime, 0.05)
	one_shot = true
	explosiveness = clampf(burst_explosiveness, 0.0, 1.0)
	randomness = 0.42
	visibility_rect = Rect2(-visual_bounds * 0.5, visual_bounds)
	local_coords = true
	draw_order = GPUParticles2D.DRAW_ORDER_LIFETIME
	texture = _make_particle_texture()
	process_material = _make_process_material()


func burst() -> void:
	configure()
	restart()
	emitting = true


func _make_particle_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		primary_color,
		primary_color.lerp(secondary_color, 0.35),
		secondary_color,
		Color(secondary_color, 0.0),
	])
	var texture_2d := GradientTexture2D.new()
	texture_2d.width = 5
	texture_2d.height = 16
	texture_2d.fill = GradientTexture2D.FILL_LINEAR
	texture_2d.fill_from = Vector2(0.5, 0.0)
	texture_2d.fill_to = Vector2(0.5, 1.0)
	texture_2d.gradient = gradient
	return texture_2d


func _make_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	material.direction = Vector3(safe_direction.x, safe_direction.y, 0.0)
	material.spread = spread_degrees
	material.gravity = Vector3(gravity.x, gravity.y, 0.0)
	material.initial_velocity_min = initial_speed * 0.58
	material.initial_velocity_max = initial_speed
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.scale_min = 0.45
	material.scale_max = 1.15
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.15))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = scale_curve
	material.scale_curve = curve_texture
	return material
