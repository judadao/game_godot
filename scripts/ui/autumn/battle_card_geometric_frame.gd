@tool
extends Control

const OLD_GOLD := Color(0.67, 0.49, 0.22, 1.0)
const BRIGHT_GOLD := Color(1.0, 0.82, 0.42, 1.0)
const DEEP_INK := Color(0.012, 0.010, 0.009, 0.10)

var _phase := 0.0
var _energy := 0.55
var _accent := OLD_GOLD


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase = fmod(float(Time.get_ticks_msec()) * 0.001 * 0.42, 1.0)
	queue_redraw()


func set_energy(value: float) -> void:
	_energy = clampf(value, 0.0, 1.0)


func set_accent(value: Color) -> void:
	_accent = value


func get_geometry_state() -> Dictionary:
	return {
		"code_native": true,
		"adjustable_arcs": true,
		"double_gold_lines": true,
		"integrated_medallions": true,
		"animated_charge": is_processing(),
		"global_timeline": true,
		"seamless_wrap": true,
	}


func get_timeline_phase() -> float:
	return _phase


func _draw() -> void:
	if size.x < 40.0 or size.y < 60.0:
		return
	var stroke_scale := clampf(minf(size.x / 190.0, size.y / 230.0), 0.72, 1.35)
	var dark_stroke := Color(0.025, 0.018, 0.012, 0.96)
	var base_gold := OLD_GOLD.lerp(_accent, 0.14)
	var line_gold := base_gold.lightened(0.08)
	var highlight := BRIGHT_GOLD.lerp(_accent.lightened(0.22), 0.12)

	_draw_card_silhouette()
	_draw_arches(dark_stroke, line_gold, highlight, stroke_scale)
	_draw_side_pillars(dark_stroke, line_gold, highlight, stroke_scale)
	_draw_title_cartouche(dark_stroke, line_gold, highlight, stroke_scale)
	_draw_medallion(Vector2(size.x * 0.17, size.y * 0.28), 20.0 * stroke_scale, dark_stroke, line_gold, highlight, stroke_scale)
	_draw_medallion(Vector2(size.x * 0.82, size.y * 0.28), 18.0 * stroke_scale, dark_stroke, line_gold, highlight, stroke_scale)
	_draw_medallion(Vector2(size.x * 0.82, size.y * 0.885), 18.0 * stroke_scale, dark_stroke, line_gold, highlight, stroke_scale)
	_draw_charge_flow(highlight, stroke_scale)


func _draw_card_silhouette() -> void:
	var points := PackedVector2Array([
		Vector2(size.x * 0.09, size.y * 0.91),
		Vector2(size.x * 0.09, size.y * 0.36),
		Vector2(size.x * 0.14, size.y * 0.17),
		Vector2(size.x * 0.31, size.y * 0.055),
		Vector2(size.x * 0.50, size.y * 0.025),
		Vector2(size.x * 0.69, size.y * 0.055),
		Vector2(size.x * 0.86, size.y * 0.17),
		Vector2(size.x * 0.91, size.y * 0.36),
		Vector2(size.x * 0.91, size.y * 0.91),
		Vector2(size.x * 0.75, size.y * 0.97),
		Vector2(size.x * 0.25, size.y * 0.97),
	])
	draw_colored_polygon(points, DEEP_INK)


func _draw_arches(dark: Color, gold: Color, highlight: Color, scale: float) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.36)
	_draw_elliptic_arc(center, Vector2(size.x * 0.41, size.y * 0.325), PI, TAU, dark, 5.2 * scale)
	_draw_elliptic_arc(center, Vector2(size.x * 0.41, size.y * 0.325), PI, TAU, gold, 1.75 * scale)
	_draw_elliptic_arc(center, Vector2(size.x * 0.375, size.y * 0.292), PI, TAU, dark, 3.4 * scale)
	_draw_elliptic_arc(center, Vector2(size.x * 0.375, size.y * 0.292), PI, TAU, highlight.darkened(0.18), 0.9 * scale)

	for tick_index in 17:
		var ratio := float(tick_index) / 16.0
		var angle := lerpf(PI * 1.08, PI * 1.92, ratio)
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + Vector2(direction.x * size.x * 0.415, direction.y * size.y * 0.33)
		var tick_length := (7.0 if tick_index % 4 == 0 else 4.0) * scale
		var outer := inner + direction.normalized() * tick_length
		draw_line(inner, outer, Color(gold.r, gold.g, gold.b, 0.88), 1.0 * scale, true)


func _draw_side_pillars(dark: Color, gold: Color, highlight: Color, scale: float) -> void:
	for side in [-1.0, 1.0]:
		var x_outer := size.x * (0.09 if side < 0.0 else 0.91)
		var x_inner := size.x * (0.12 if side < 0.0 else 0.88)
		var top := size.y * 0.35
		var bottom := size.y * 0.91
		draw_line(Vector2(x_outer, top), Vector2(x_outer, bottom), dark, 5.0 * scale, true)
		draw_line(Vector2(x_outer, top), Vector2(x_outer, bottom), gold, 1.65 * scale, true)
		draw_line(Vector2(x_inner, top + 7.0 * scale), Vector2(x_inner, bottom - 5.0 * scale), dark, 3.2 * scale, true)
		draw_line(Vector2(x_inner, top + 7.0 * scale), Vector2(x_inner, bottom - 5.0 * scale), highlight.darkened(0.22), 0.8 * scale, true)
		var cap_direction := 1.0 if side < 0.0 else -1.0
		var top_cap := PackedVector2Array([
			Vector2(x_outer, top),
			Vector2(x_outer + cap_direction * size.x * 0.055, top),
			Vector2(x_outer + cap_direction * size.x * 0.055, top + 6.0 * scale),
			Vector2(x_inner, top + 6.0 * scale),
		])
		draw_polyline(top_cap, dark, 4.0 * scale, true)
		draw_polyline(top_cap, gold, 1.2 * scale, true)
		var diamond_center := Vector2(x_outer, size.y * 0.54)
		_draw_diamond(diamond_center, Vector2(5.0, 8.0) * scale, dark, gold, scale)


func _draw_title_cartouche(dark: Color, gold: Color, highlight: Color, scale: float) -> void:
	var y_top := size.y * 0.805
	var y_bottom := size.y * 0.965
	var left := size.x * 0.11
	var right := size.x * 0.78
	var step := size.x * 0.045
	var points := PackedVector2Array([
		Vector2(left, y_top + 7.0 * scale),
		Vector2(left + step, y_top + 7.0 * scale),
		Vector2(left + step * 1.35, y_top),
		Vector2(right - step * 1.35, y_top),
		Vector2(right - step, y_top + 7.0 * scale),
		Vector2(right, y_top + 7.0 * scale),
		Vector2(right, y_bottom),
		Vector2(left, y_bottom),
		Vector2(left, y_top + 7.0 * scale),
	])
	draw_colored_polygon(points, Color(0.025, 0.018, 0.012, 0.82))
	draw_polyline(points, dark, 4.6 * scale, true)
	draw_polyline(points, gold, 1.4 * scale, true)
	draw_line(
		Vector2(left + step * 1.6, y_top + 4.0 * scale),
		Vector2(right - step * 1.6, y_top + 4.0 * scale),
		Color(highlight.r, highlight.g, highlight.b, 0.48),
		0.75 * scale,
		true
	)


func _draw_medallion(center: Vector2, radius: float, dark: Color, gold: Color, highlight: Color, scale: float) -> void:
	draw_circle(center, radius, Color(0.008, 0.009, 0.010, 0.96))
	draw_arc(center, radius, 0.0, TAU, 48, dark, 5.0 * scale, true)
	draw_arc(center, radius, 0.0, TAU, 48, gold, 1.7 * scale, true)
	draw_arc(center, radius - 3.0 * scale, 0.0, TAU, 48, Color(highlight.r, highlight.g, highlight.b, 0.45), 0.65 * scale, true)


func _draw_diamond(center: Vector2, radius: Vector2, dark: Color, gold: Color, scale: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius.y),
		center + Vector2(radius.x, 0.0),
		center + Vector2(0.0, radius.y),
		center + Vector2(-radius.x, 0.0),
		center + Vector2(0.0, -radius.y),
	])
	draw_polyline(points, dark, 3.6 * scale, true)
	draw_polyline(points, gold, 1.1 * scale, true)


func _draw_charge_flow(highlight: Color, scale: float) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.36)
	var start_angle := PI + _phase * PI
	var sweep := PI * lerpf(0.08, 0.15, _energy)
	var charge_color := Color(highlight.r, highlight.g, highlight.b, 0.55 + _energy * 0.35)
	var end_angle := start_angle + sweep
	_draw_elliptic_arc(
		center,
		Vector2(size.x * 0.41, size.y * 0.325),
		start_angle,
		minf(end_angle, TAU),
		charge_color,
		2.7 * scale
	)
	if end_angle > TAU:
		_draw_elliptic_arc(
			center,
			Vector2(size.x * 0.41, size.y * 0.325),
			PI,
			PI + end_angle - TAU,
			charge_color,
			2.7 * scale
		)
	var side_wave := (sin(_phase * TAU - PI * 0.5) + 1.0) * 0.5
	var right_y := lerpf(size.y * 0.36, size.y * 0.91, side_wave)
	var left_y := lerpf(size.y * 0.91, size.y * 0.36, side_wave)
	draw_circle(Vector2(size.x * 0.91, right_y), 1.8 * scale, Color(highlight.r, highlight.g, highlight.b, 0.82))
	draw_circle(Vector2(size.x * 0.09, left_y), 1.8 * scale, Color(highlight.r, highlight.g, highlight.b, 0.66))


func _draw_elliptic_arc(
	center: Vector2,
	radii: Vector2,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	if end_angle <= start_angle:
		return
	var points := PackedVector2Array()
	var point_count := maxi(3, int(ceilf((end_angle - start_angle) / TAU * 96.0)))
	for point_index in point_count + 1:
		var ratio := float(point_index) / float(point_count)
		var angle := lerpf(start_angle, end_angle, ratio)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)
