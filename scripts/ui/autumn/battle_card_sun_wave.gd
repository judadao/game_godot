@tool
extends Control

const RAY_COUNT := 60
const RAY_WIDTH := 2.40
const ACCENT_RAY_WIDTH := 3.80
const OLD_GOLD := Color(0.86, 0.62, 0.24, 1.0)

var _phase := 0.0
var _phase_offset := 0.0
var _energy := 0.55


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase = float(Time.get_ticks_msec()) * 0.001 * 1.9
	queue_redraw()


func set_phase_offset(value: float) -> void:
	_phase_offset = fmod(value, TAU)


func set_energy(value: float) -> void:
	_energy = clampf(value, 0.0, 1.0)


func get_visualizer_state() -> Dictionary:
	return {
		"ray_count": RAY_COUNT,
		"music_wave": true,
		"variable_heights": true,
		"radial_360": true,
		"sacred_geometry": true,
		"ray_width": RAY_WIDTH,
		"accent_ray_width": ACCENT_RAY_WIDTH,
		"circular_envelope": true,
		"circularity": 1.0,
		"global_timeline": true,
		"seamless_wrap": true,
		"continuous_motion": is_processing(),
	}


func get_timeline_phase() -> float:
	return fmod(_phase + _phase_offset, TAU)


func _draw() -> void:
	if size.x < 40.0 or size.y < 60.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.45)
	var outer_limit := minf(size.x * 0.44, size.y * 0.315)
	var inner_radius := outer_limit * 0.10
	_draw_sacred_geometry(center, inner_radius, outer_limit)
	for ray_index in RAY_COUNT:
		var ratio := float(ray_index) / float(RAY_COUNT - 1)
		var angle := TAU * ratio - PI * 0.5
		var wave_a := sin(_phase + _phase_offset + float(ray_index) * 0.41)
		var wave_b := sin(_phase * 0.61 - _phase_offset + float(ray_index) * 0.17)
		var wave := clampf((wave_a * 0.68 + wave_b * 0.32 + 1.0) * 0.5, 0.0, 1.0)
		var direction := Vector2.from_angle(angle)
		var start_radius := inner_radius * lerpf(0.82, 1.24, sin(float(ray_index) * 1.37) * 0.5 + 0.5)
		var finish_radius := outer_limit * lerpf(0.52, 1.0, pow(wave, 0.78))
		var start := center + direction * start_radius
		var finish := center + direction * finish_radius
		var alpha := lerpf(0.60, 0.96, wave) * lerpf(0.78, 1.0, _energy)
		var width := RAY_WIDTH if ray_index % 5 else ACCENT_RAY_WIDTH
		var ray_color := (
			Color(1.0, 0.84, 0.48, alpha)
			if ray_index % 6 == 0
			else Color(OLD_GOLD.r, OLD_GOLD.g, OLD_GOLD.b, alpha)
		)
		draw_line(
			start,
			finish,
			ray_color,
			width,
			true
		)


func _draw_sacred_geometry(center: Vector2, inner_radius: float, outer_limit: float) -> void:
	var geometry_color := Color(OLD_GOLD.r, OLD_GOLD.g, OLD_GOLD.b, 0.18 * _energy)
	for ring_ratio in [0.82, 1.34, 1.86]:
		draw_arc(center, inner_radius * ring_ratio, 0.0, TAU, 64, geometry_color, 0.8, true)
	_draw_polygon_ring(center, inner_radius * 1.36, 6, _phase * 0.045, geometry_color)
	_draw_polygon_ring(center, inner_radius * 1.86, 12, -_phase * 0.032, geometry_color)
	draw_arc(
		center,
		outer_limit * 0.48,
		0.0,
		TAU,
		96,
		Color(OLD_GOLD.r, OLD_GOLD.g, OLD_GOLD.b, 0.16 * _energy),
		0.7,
		true
	)
	draw_arc(
		center,
		outer_limit * 0.76,
		0.0,
		TAU,
		120,
		Color(1.0, 0.80, 0.40, 0.08 * _energy),
		0.6,
		true
	)
	draw_arc(
		center,
		outer_limit * 0.98,
		0.0,
		TAU,
		120,
		Color(OLD_GOLD.r, OLD_GOLD.g, OLD_GOLD.b, 0.05 * _energy),
		0.6,
		true
	)


func _draw_polygon_ring(
	center: Vector2,
	radius: float,
	sides: int,
	rotation_offset: float,
	color: Color
) -> void:
	var points := PackedVector2Array()
	for point_index in sides + 1:
		var angle := TAU * float(point_index % sides) / float(sides) + rotation_offset
		points.append(center + Vector2.from_angle(angle) * radius)
	draw_polyline(points, color, 0.75, true)
