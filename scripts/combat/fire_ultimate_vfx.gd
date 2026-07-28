class_name FireUltimateVFX
extends Node2D

signal finished

const MIN_RADIUS := 96.0
const MAX_RADIUS := 960.0
const MIN_DURATION := 0.2
const MAX_DURATION := 3.0
const MIN_INTENSITY := 0.35
const MAX_INTENSITY := 2.5
const CIRCLE_SEGMENTS := 56
const BASE_RING_COUNT := 3
const PARTICLE_TAIL := 0.34
const RING_DELAYS := [0.0, 0.12, 0.24, 0.36]
const FLAME_COLORS := [
	Color(1.0, 0.18, 0.015, 0.94),
	Color(1.0, 0.48, 0.035, 0.96),
	Color(1.0, 0.86, 0.24, 0.98),
	Color(1.0, 0.98, 0.72, 1.0),
]

@export_range(MIN_RADIUS, MAX_RADIUS, 1.0) var radius := 420.0
@export_range(MIN_INTENSITY, MAX_INTENSITY, 0.05) var intensity := 1.0
@export_range(MIN_DURATION, MAX_DURATION, 0.05) var duration := 0.9

@onready var scorched_ground: Polygon2D = $ScorchedGround
@onready var inner_wave: Line2D = $FireWaves/InnerWave
@onready var middle_wave: Line2D = $FireWaves/MiddleWave
@onready var outer_wave: Line2D = $FireWaves/OuterWave
@onready var echo_wave: Line2D = $FireWaves/EchoWave
@onready var flame_pillars: GPUParticles2D = $FlamePillars
@onready var ember_sparks: GPUParticles2D = $EmberSparks

var _active := false
var _progress := 0.0
var _max_radius := 420.0
var _active_intensity := 1.0
var _effect_duration := 0.9
var _ring_count := BASE_RING_COUNT
var _waves: Array[Line2D] = []
var _lifecycle_tween: Tween


func _ready() -> void:
	_waves = [inner_wave, middle_wave, outer_wave, echo_wave]
	_reset_visuals()


func play(center: Variant = null) -> void:
	if not is_inside_tree():
		push_error("FireUltimateVFX.play() requires the effect to be inside the SceneTree.")
		return
	_apply_center(center)
	_max_radius = clampf(radius, MIN_RADIUS, MAX_RADIUS)
	_active_intensity = clampf(intensity, MIN_INTENSITY, MAX_INTENSITY)
	_effect_duration = clampf(duration, MIN_DURATION, MAX_DURATION)
	_ring_count = BASE_RING_COUNT + (1 if _active_intensity >= 1.25 else 0)
	_active = true
	_progress = 0.0
	_configure_particles()
	_reset_visuals()
	flame_pillars.restart()
	ember_sparks.restart()
	flame_pillars.emitting = true
	ember_sparks.emitting = true

	if _lifecycle_tween != null and _lifecycle_tween.is_valid():
		_lifecycle_tween.kill()
	_lifecycle_tween = create_tween()
	_lifecycle_tween.set_trans(Tween.TRANS_QUART)
	_lifecycle_tween.set_ease(Tween.EASE_OUT)
	_lifecycle_tween.tween_method(_set_progress, 0.0, 1.0, _effect_duration)
	_lifecycle_tween.tween_interval(PARTICLE_TAIL)
	_lifecycle_tween.tween_callback(_finish)


func is_active() -> bool:
	return _active


func get_max_radius() -> float:
	return _max_radius


func get_ring_count() -> int:
	return _ring_count


func _draw() -> void:
	if not _active:
		return
	var fade := 1.0 - smoothstep(0.58, 1.0, _progress)
	var heat_radius := _max_radius * ease(_progress, 0.34)
	var ignition := 1.0 - smoothstep(0.0, 0.32, _progress)
	draw_circle(Vector2.ZERO, heat_radius * 0.98, Color(0.13, 0.018, 0.004, 0.10 * fade))
	draw_circle(Vector2.ZERO, heat_radius * 0.72, Color(0.62, 0.08, 0.008, 0.055 * fade))
	draw_circle(Vector2.ZERO, 70.0 * ignition, Color(1.0, 0.72, 0.22, 0.22 * ignition))
	draw_circle(Vector2.ZERO, 28.0 * ignition, Color(1.0, 0.97, 0.72, 0.72 * ignition))
	draw_arc(
		Vector2.ZERO,
		heat_radius,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(1.0, 0.38, 0.035, 0.12 * fade),
		maxf(1.2, 3.2 * sqrt(_active_intensity) * fade),
		true
	)
	_draw_flame_crown(heat_radius, fade)
	_draw_heat_ripples(heat_radius, fade)


func _draw_flame_crown(wave_radius: float, fade: float) -> void:
	var flame_count := clampi(roundi(18.0 * _active_intensity), 12, 42)
	for index in flame_count:
		var angle := TAU * float(index) / float(flame_count) + float(index % 3) * 0.045
		var radial_variation := (
			0.84
			+ 0.10 * sin(float(index) * 2.31)
			+ 0.045 * sin(float(index) * 5.73 + _progress * 9.0)
		)
		var base := Vector2.from_angle(angle) * wave_radius * radial_variation
		var tangent := Vector2.from_angle(angle).orthogonal()
		var outward := Vector2.from_angle(angle)
		var height := (
			24.0
			+ 25.0 * absf(sin(float(index) * 1.77 + _progress * 5.0))
		) * sqrt(_active_intensity)
		var width := 4.0 + 3.0 * sqrt(_active_intensity)
		var flame := PackedVector2Array([
			base - tangent * width,
			base + outward * height * 0.42 - tangent * width * 0.38,
			base + outward * height + tangent * width * 0.12,
			base + outward * height * 0.38 + tangent * width,
			base + tangent * width,
		])
		var color: Color = FLAME_COLORS[index % FLAME_COLORS.size()]
		color.a *= fade * (0.72 + 0.18 * sin(float(index) + _progress * TAU))
		draw_colored_polygon(flame, color)
		var core := flame.duplicate()
		for point_index in core.size():
			core[point_index] = base.lerp(core[point_index], 0.46)
		draw_colored_polygon(core, Color(1.0, 0.93, 0.55, color.a * 0.82))


func _draw_heat_ripples(wave_radius: float, fade: float) -> void:
	for ripple_index in 3:
		var ripple_radius := wave_radius * (0.38 + float(ripple_index) * 0.19)
		var ripple_alpha := fade * (0.13 - float(ripple_index) * 0.025)
		draw_arc(
			Vector2.ZERO,
			ripple_radius,
			-0.16,
			PI + 0.16,
			28,
			Color(1.0, 0.68, 0.18, ripple_alpha),
			2.0 + _active_intensity,
			true
		)


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_update_scorch()
	_update_waves()
	queue_redraw()


func _update_scorch() -> void:
	var scorch_progress := ease(minf(1.0, _progress * 1.8), 0.45)
	var scorch_radius := _max_radius * 0.91 * scorch_progress
	scorched_ground.polygon = _circle_points(scorch_radius, CIRCLE_SEGMENTS)
	scorched_ground.color = Color(
		0.11,
		0.025,
		0.008,
		0.42 * (1.0 - smoothstep(0.62, 1.0, _progress))
	)


func _update_waves() -> void:
	for index in _waves.size():
		var wave := _waves[index]
		var enabled := index < _ring_count
		wave.visible = enabled
		if not enabled:
			continue
		var local_progress := clampf(
			(_progress - float(RING_DELAYS[index])) / (0.72 - float(RING_DELAYS[index])),
			0.0,
			1.0
		)
		var wave_radius := _max_radius * ease(local_progress, 0.28)
		wave.points = _organic_circle_points(wave_radius, CIRCLE_SEGMENTS, index)
		var alpha := sin(local_progress * PI) * (1.0 - _progress * 0.3)
		wave.modulate.a = clampf(alpha * 0.82, 0.0, 1.0)
		wave.width = (
			(5.6 - float(index) * 0.7)
			* sqrt(_active_intensity)
		)


func _configure_particles() -> void:
	flame_pillars.amount = clampi(roundi(42.0 * _active_intensity), 20, 104)
	ember_sparks.amount = clampi(roundi(64.0 * _active_intensity), 28, 152)
	flame_pillars.lifetime = minf(0.8, _effect_duration * 0.72 + 0.2)
	ember_sparks.lifetime = minf(0.95, _effect_duration * 0.8 + 0.25)
	var pillar_material := flame_pillars.process_material as ParticleProcessMaterial
	if pillar_material != null:
		pillar_material.emission_ring_radius = _max_radius * 0.72
		pillar_material.emission_ring_inner_radius = _max_radius * 0.18
		pillar_material.initial_velocity_min = 70.0 * _active_intensity
		pillar_material.initial_velocity_max = 145.0 * _active_intensity
	var spark_material := ember_sparks.process_material as ParticleProcessMaterial
	if spark_material != null:
		spark_material.emission_ring_radius = _max_radius * 0.88
		spark_material.emission_ring_inner_radius = _max_radius * 0.12
		spark_material.initial_velocity_min = 105.0 * _active_intensity
		spark_material.initial_velocity_max = 225.0 * _active_intensity


func _reset_visuals() -> void:
	scorched_ground.polygon = _circle_points(1.0, CIRCLE_SEGMENTS)
	scorched_ground.color.a = 0.0
	for wave in _waves:
		wave.points = _circle_points(1.0, CIRCLE_SEGMENTS)
		wave.modulate.a = 0.0
	echo_wave.visible = false
	queue_redraw()


func _apply_center(center: Variant) -> void:
	if center == null:
		return
	if center is Vector2:
		global_position = center
		return
	if center is Node2D:
		global_position = (center as Node2D).global_position
		return
	push_warning("FireUltimateVFX.play() center must be Vector2, Node2D, or null.")


func _circle_points(circle_radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segment_count:
		var angle := TAU * float(index) / float(segment_count)
		points.append(Vector2.from_angle(angle) * circle_radius)
	points.append(points[0])
	return points


func _organic_circle_points(
	circle_radius: float,
	segment_count: int,
	seed: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segment_count:
		var angle := TAU * float(index) / float(segment_count)
		var wobble := (
			1.0
			+ 0.028 * sin(angle * 5.0 + float(seed) * 1.7)
			+ 0.016 * sin(angle * 11.0 - _progress * 7.0 + float(seed))
		)
		points.append(Vector2.from_angle(angle) * circle_radius * wobble)
	points.append(points[0])
	return points


func _finish() -> void:
	if not _active:
		return
	_active = false
	flame_pillars.emitting = false
	ember_sparks.emitting = false
	finished.emit()
	queue_free()
