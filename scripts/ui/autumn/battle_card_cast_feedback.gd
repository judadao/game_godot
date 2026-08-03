@tool
extends Control

const OLD_GOLD := Color(0.78, 0.58, 0.27, 1.0)
const BRIGHT_GOLD := Color(1.0, 0.88, 0.54, 1.0)

var _accent := OLD_GOLD
var _intensity := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_accent(value: Color) -> void:
	_accent = value
	queue_redraw()


func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	queue_redraw()


func get_feedback_state() -> Dictionary:
	return {
		"intensity": _intensity,
		"top_layer": z_index >= 20,
		"ritual_arcs": true,
		"burst_ticks": 12,
		"medallion_flash": true,
		"no_rectangular_overlay": true,
	}


func _draw() -> void:
	if _intensity <= 0.001 or size.x < 40.0 or size.y < 60.0:
		return
	var progress := 1.0 - _intensity
	var pulse := sin(progress * PI)
	var color := BRIGHT_GOLD.lerp(_accent.lightened(0.28), 0.42)
	var center := Vector2(size.x * 0.5, size.y * 0.44)
	var radius := minf(size.x * 0.40, size.y * 0.295) * lerpf(0.78, 1.06, progress)
	var arc_alpha := clampf(_intensity * 0.82 + pulse * 0.28, 0.0, 1.0)
	var rotation := progress * PI * 0.38
	draw_arc(
		center,
		radius,
		-PI * 0.94 + rotation,
		PI * 0.18 + rotation,
		48,
		Color(color.r, color.g, color.b, arc_alpha),
		2.8,
		true
	)
	draw_arc(
		center,
		radius * 0.90,
		PI * 0.06 - rotation,
		PI * 1.18 - rotation,
		48,
		Color(_accent.r, _accent.g, _accent.b, arc_alpha * 0.72),
		1.8,
		true
	)
	for tick_index in 12:
		var angle := TAU * float(tick_index) / 12.0 + rotation * 0.34
		var direction := Vector2.from_angle(angle)
		var inner := center + direction * radius * 0.91
		var outer := center + direction * radius * (1.06 + pulse * 0.08)
		draw_line(
			inner,
			outer,
			Color(color.r, color.g, color.b, arc_alpha * 0.86),
			2.2 if tick_index % 3 == 0 else 1.3,
			true
		)

	_draw_medallion_flash(Vector2(size.x * 0.17, size.y * 0.28), 22.0, color, arc_alpha)
	_draw_medallion_flash(Vector2(size.x * 0.82, size.y * 0.28), 20.0, color, arc_alpha * 0.88)
	_draw_medallion_flash(Vector2(size.x * 0.82, size.y * 0.885), 20.0, color, arc_alpha * 0.92)
	var sweep_left := size.x * 0.14
	var sweep_right := lerpf(sweep_left, size.x * 0.74, clampf(progress * 1.7, 0.0, 1.0))
	draw_line(
		Vector2(sweep_left, size.y * 0.795),
		Vector2(sweep_right, size.y * 0.795),
		Color(color.r, color.g, color.b, arc_alpha * 0.82),
		2.0,
		true
	)


func _draw_medallion_flash(
	center: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	draw_arc(
		center,
		radius * lerpf(0.88, 1.12, 1.0 - _intensity),
		0.0,
		TAU,
		40,
		Color(color.r, color.g, color.b, alpha),
		2.4,
		true
	)
