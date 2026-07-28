class_name IceUltimateVFX
extends Node2D

signal finished

const MIN_RADIUS := 96.0
const MAX_RADIUS_LIMIT := 720.0
const MIN_CRYSTALS := 10
const MAX_CRYSTALS := 40
const MIN_MIST_PARTICLES := 24
const MAX_MIST_PARTICLES := 96
const RING_POINT_COUNT := 72
const GOLDEN_ANGLE := 2.399963

@export_range(MIN_RADIUS, MAX_RADIUS_LIMIT, 1.0) var radius: float = 420.0
@export_range(0.1, 1.0, 0.05) var intensity: float = 0.8
@export_range(0.12, 3.0, 0.01) var duration: float = 0.9

@onready var frost_rings: Node2D = $FrostRings
@onready var outer_ring: Line2D = $FrostRings/OuterRing
@onready var inner_ring: Line2D = $FrostRings/InnerRing
@onready var ground_frost: Polygon2D = $GroundFrost
@onready var crystals: Node2D = $Crystals
@onready var cold_mist: GPUParticles2D = $ColdMist

var active: bool = false
var max_radius: float = 0.0
var crystal_count: int = 0

var _progress := 0.0
var _fade := 0.0
var _elapsed := 0.0
var _master_tween: Tween
var _crystal_nodes: Array[Polygon2D] = []


func _ready() -> void:
	set_process(false)
	visible = false


func play() -> void:
	if not is_inside_tree():
		push_error("IceUltimateVFX.play() requires the scene to be inside the SceneTree.")
		return
	if _master_tween != null and _master_tween.is_valid():
		_master_tween.kill()

	max_radius = clampf(radius, MIN_RADIUS, MAX_RADIUS_LIMIT)
	intensity = clampf(intensity, 0.1, 1.0)
	duration = maxf(0.12, duration)
	crystal_count = clampi(
		roundi(lerpf(float(MIN_CRYSTALS), float(MAX_CRYSTALS), intensity)),
		MIN_CRYSTALS,
		MAX_CRYSTALS
	)
	_progress = 0.0
	_fade = 0.0
	_elapsed = 0.0
	active = true
	visible = true
	modulate = Color.WHITE

	_build_ring_geometry()
	_build_ground_geometry()
	_build_crystals()
	_configure_mist()
	_set_progress(0.0)
	set_process(true)

	var expand_duration := duration * 0.68
	var hold_duration := duration * 0.10
	var fade_duration := duration * 0.22
	_master_tween = create_tween()
	_master_tween.set_trans(Tween.TRANS_QUINT)
	_master_tween.set_ease(Tween.EASE_OUT)
	_master_tween.tween_method(_set_progress, 0.0, 1.0, expand_duration)
	_master_tween.tween_interval(hold_duration)
	_master_tween.set_trans(Tween.TRANS_QUAD)
	_master_tween.tween_method(_set_fade, 0.0, 1.0, fade_duration)
	_master_tween.tween_callback(_finish)


func get_max_radius() -> float:
	return max_radius


func get_crystal_count() -> int:
	return crystal_count


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	outer_ring.rotation = _elapsed * 0.16
	inner_ring.rotation = -_elapsed * 0.24
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	var reveal_radius := max_radius * _progress
	var opacity := 1.0 - _fade
	draw_circle(
		Vector2.ZERO,
		reveal_radius,
		Color(0.16, 0.56, 0.78, opacity * 0.075)
	)
	draw_circle(
		Vector2.ZERO,
		reveal_radius * 0.58,
		Color(0.72, 0.96, 1.0, opacity * 0.055)
	)
	var crack_count := 8 + roundi(intensity * 10.0)
	for crack_index in crack_count:
		var base_angle := TAU * float(crack_index) / float(crack_count)
		var points := PackedVector2Array()
		var segment_count := 4 + crack_index % 3
		for segment_index in range(segment_count + 1):
			var segment_ratio := float(segment_index) / float(segment_count)
			var distance := reveal_radius * segment_ratio
			var bend := sin(float(crack_index * 17 + segment_index * 29)) * 0.055
			var point_angle := base_angle + bend
			points.append(Vector2.from_angle(point_angle) * distance)
		if points.size() > 1:
			draw_polyline(
				points,
				Color(0.02, 0.16, 0.28, opacity * 0.62),
				3.0 + intensity * 2.0,
				true
			)
			draw_polyline(
				points,
				Color(0.55, 0.94, 1.0, opacity * (0.32 + intensity * 0.38)),
				1.2 + intensity * 1.4,
				true
			)
			_draw_crack_branches(points, crack_index, opacity)

	var sparkle_count := 6 + roundi(intensity * 8.0)
	for sparkle_index in sparkle_count:
		var angle := float(sparkle_index) * GOLDEN_ANGLE + _elapsed * 0.45
		var distance := reveal_radius * (0.28 + 0.66 * _hash_ratio(sparkle_index + 41))
		var center := Vector2.from_angle(angle) * distance
		var size := 2.0 + 2.5 * intensity
		draw_line(
			center - Vector2(size, 0.0),
			center + Vector2(size, 0.0),
			Color(0.82, 0.98, 1.0, opacity * 0.86),
			1.2,
			true
		)
		draw_line(
			center - Vector2(0.0, size),
			center + Vector2(0.0, size),
			Color.WHITE,
			1.0,
			true
		)


func _build_ring_geometry() -> void:
	outer_ring.points = _circle_points(max_radius, RING_POINT_COUNT)
	inner_ring.points = _circle_points(max_radius * 0.72, RING_POINT_COUNT)
	outer_ring.width = 3.0 + intensity * 4.0
	inner_ring.width = 1.5 + intensity * 2.5


func _build_ground_geometry() -> void:
	ground_frost.polygon = _circle_points(max_radius, RING_POINT_COUNT)
	ground_frost.color = Color(0.24, 0.76, 0.92, 0.10 + intensity * 0.10)


func _build_crystals() -> void:
	for child in crystals.get_children():
		child.queue_free()
	_crystal_nodes.clear()

	for crystal_index in crystal_count:
		var crystal := Polygon2D.new()
		var height := 24.0 + 28.0 * _hash_ratio(crystal_index + 13) * intensity
		var half_width := 4.0 + 4.0 * _hash_ratio(crystal_index + 71)
		crystal.polygon = PackedVector2Array([
			Vector2(-half_width, 2.0),
			Vector2(-half_width * 0.34, -height * 0.72),
			Vector2(0.0, -height),
			Vector2(half_width * 0.42, -height * 0.58),
			Vector2(half_width, 2.0),
		])
		crystal.color = Color(
			0.36 + 0.18 * _hash_ratio(crystal_index + 5),
			0.82 + 0.12 * _hash_ratio(crystal_index + 19),
			1.0,
			0.94
		)
		crystal.z_index = crystal_index % 3
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([
			Vector2(-half_width * 1.5, 4.0),
			Vector2(half_width * 2.2, 4.0),
			Vector2(half_width * 3.0, 10.0),
			Vector2(-half_width * 0.8, 10.0),
		])
		shadow.color = Color(0.01, 0.12, 0.20, 0.34)
		shadow.z_index = -1
		crystal.add_child(shadow)

		var highlight := Polygon2D.new()
		highlight.polygon = PackedVector2Array([
			Vector2(-half_width * 0.16, -height * 0.02),
			Vector2(0.0, -height * 0.90),
			Vector2(half_width * 0.22, -height * 0.56),
			Vector2(half_width * 0.18, -height * 0.06),
		])
		highlight.color = Color(0.88, 0.99, 1.0, 0.72)
		crystal.add_child(highlight)
		crystals.add_child(crystal)
		_crystal_nodes.append(crystal)


func _draw_crack_branches(
	spine: PackedVector2Array,
	crack_index: int,
	opacity: float
) -> void:
	if spine.size() < 4:
		return
	for branch_index in 2:
		var source_index := mini(
			spine.size() - 2,
			1 + (crack_index + branch_index * 2) % (spine.size() - 2)
		)
		var source := spine[source_index]
		var direction := source.normalized().rotated(
			(-0.42 if branch_index == 0 else 0.38)
			+ sin(float(crack_index) * 1.9) * 0.08
		)
		var length := max_radius * (0.055 + 0.025 * _hash_ratio(crack_index * 7 + branch_index))
		var branch := PackedVector2Array([
			source,
			source + direction * length * 0.48,
			source + direction * length,
		])
		draw_polyline(
			branch,
			Color(0.72, 0.97, 1.0, opacity * 0.52),
			1.0 + intensity,
			true
		)


func _configure_mist() -> void:
	cold_mist.amount = clampi(
		roundi(lerpf(float(MIN_MIST_PARTICLES), float(MAX_MIST_PARTICLES), intensity)),
		MIN_MIST_PARTICLES,
		MAX_MIST_PARTICLES
	)
	cold_mist.lifetime = maxf(0.16, duration * 0.72)
	cold_mist.explosiveness = 0.74
	cold_mist.one_shot = true
	cold_mist.emitting = false
	var material := cold_mist.process_material as ParticleProcessMaterial
	if material != null:
		material = material.duplicate() as ParticleProcessMaterial
		material.emission_sphere_radius = max_radius * 0.72
		material.initial_velocity_min = max_radius * 0.05
		material.initial_velocity_max = max_radius * 0.12
		cold_mist.process_material = material
	cold_mist.restart()


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - _progress, 3.0)
	frost_rings.scale = Vector2.ONE * maxf(0.01, eased)
	ground_frost.scale = Vector2.ONE * maxf(0.01, eased)

	for crystal_index in _crystal_nodes.size():
		var crystal := _crystal_nodes[crystal_index]
		var reveal_at := 0.12 + 0.62 * _hash_ratio(crystal_index + 29)
		var rise := clampf((_progress - reveal_at) / 0.22, 0.0, 1.0)
		var angle := float(crystal_index) * GOLDEN_ANGLE
		var ring_ratio := 0.22 + 0.73 * _hash_ratio(crystal_index + 97)
		crystal.position = Vector2.from_angle(angle) * max_radius * ring_ratio * eased
		crystal.rotation = sin(float(crystal_index) * 1.7) * 0.16
		crystal.scale = Vector2(0.55 + intensity * 0.45, rise)
		crystal.modulate.a = rise
	queue_redraw()


func _set_fade(value: float) -> void:
	_fade = clampf(value, 0.0, 1.0)
	modulate.a = 1.0 - _fade
	queue_redraw()


func _finish() -> void:
	if not active:
		return
	active = false
	set_process(false)
	cold_mist.emitting = false
	finished.emit()
	queue_free()


func _circle_points(circle_radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		points.append(Vector2.from_angle(angle) * circle_radius)
	points.append(points[0])
	return points


func _hash_ratio(value: int) -> float:
	var hashed: int = absi(value * 1103515245 + 12345) % 1000
	return float(hashed) / 999.0
