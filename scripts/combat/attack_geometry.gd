class_name AttackGeometry
extends RefCounted

const ENERGY_BLADE_HALF_HEIGHT := 53.0
const COMBO_SPECTACLE_SCALES := [1.0, 1.10, 1.22, 1.36]


static func resolve_size_scale(
	attack_size_multiplier: float,
	stack_count: int
) -> float:
	return clampf(
		attack_size_multiplier
			* (1.0 + minf(10.0, float(maxi(0, stack_count))) * 0.035),
		1.0,
		3.0
	)


static func resolve_combo_spectacle_scale(combo_count: int) -> float:
	var combo_tier := clampi(combo_count / 3, 0, COMBO_SPECTACLE_SCALES.size() - 1)
	return float(COMBO_SPECTACLE_SCALES[combo_tier])


static func directional_sweep_contains(
	origin: Vector2,
	endpoint: Vector2,
	target_center: Vector2,
	target_radius: float,
	blade_half_height: float
) -> bool:
	var sweep_axis := endpoint - origin
	if sweep_axis.is_zero_approx():
		return target_center.distance_to(origin) <= (
			maxf(1.0, blade_half_height) + maxf(0.0, target_radius)
		)
	if (target_center - origin).dot(sweep_axis.normalized()) < 0.0:
		return false
	var closest := Geometry2D.get_closest_point_to_segment(
		target_center,
		origin,
		endpoint
	)
	return target_center.distance_to(closest) <= (
		maxf(1.0, blade_half_height) + maxf(0.0, target_radius)
	)


static func radial_contains(
	center: Vector2,
	target_center: Vector2,
	target_radius: float,
	radius: float
) -> bool:
	return center.distance_to(target_center) <= (
		maxf(0.0, radius) + maxf(0.0, target_radius)
	)


static func target_center(target: Node2D) -> Vector2:
	var collision := target.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	return collision.global_position if collision != null else target.global_position


static func target_radius(target: Node2D) -> float:
	var collision := target.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return 0.0
	var shape := collision.shape
	var radius := 0.0
	if shape is CircleShape2D:
		radius = (shape as CircleShape2D).radius
	elif shape is RectangleShape2D:
		radius = (shape as RectangleShape2D).size.length() * 0.5
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		radius = maxf(capsule.radius, capsule.height * 0.5)
	return radius * maxf(absf(collision.global_scale.x), absf(collision.global_scale.y))
