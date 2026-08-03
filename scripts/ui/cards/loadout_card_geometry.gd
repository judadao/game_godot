@tool
class_name LoadoutCardGeometry
extends Control

const OLD_GOLD := Color(0.67, 0.49, 0.22, 1.0)
const BRIGHT_GOLD := Color(1.0, 0.84, 0.46, 1.0)

var _accent := OLD_GOLD
var _selected := false
var _phase := 0.0
var _phase_offset := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Headless contract tests do not render animation frames; avoid an unbounded redraw loop there.
	var renders_geometry := DisplayServer.get_name() != "headless"
	visible = renders_geometry
	set_process(renders_geometry)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * (0.72 if _selected else 0.34), TAU)
	queue_redraw()


func set_card_state(accent: Color, selected: bool, stable_id: String = "") -> void:
	_accent = accent
	_selected = selected
	_phase_offset = float(abs(stable_id.hash()) % 1000) / 1000.0 * TAU
	queue_redraw()


func get_geometry_state() -> Dictionary:
	return {
		"animated": true,
		"runtime_processing": is_processing(),
		"double_gold_lines": true,
		"ritual_rings": 3,
		"radial_ticks": 12,
		"selected": _selected,
	}


func _draw() -> void:
	if size.x < 80.0 or size.y < 54.0:
		return
	var pulse := 0.5 + 0.5 * sin(_phase * 1.8 + _phase_offset)
	var alpha := lerpf(0.44, 0.82, pulse) if _selected else lerpf(0.24, 0.42, pulse)
	var gold := OLD_GOLD.lerp(BRIGHT_GOLD, 0.56 if _selected else 0.20)
	var accent_gold := gold.lerp(_accent.lightened(0.12), 0.24)
	var outer := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
	var inner := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
	draw_rect(outer, Color(gold.r, gold.g, gold.b, alpha), false, 1.8 if _selected else 1.1)
	draw_rect(inner, Color(accent_gold.r, accent_gold.g, accent_gold.b, alpha * 0.52), false, 0.8)
	_draw_corners(outer, gold, alpha)

	var center := Vector2(minf(48.0, size.x * 0.22), size.y * 0.50)
	var radius := minf(30.0, size.y * 0.30)
	for ring_index in 3:
		var ring_radius := radius + float(ring_index) * 4.0
		var rotation := _phase * (1.0 if ring_index % 2 == 0 else -0.72) + _phase_offset
		var arc_span := PI * (1.05 + float(ring_index) * 0.16)
		draw_arc(
			center,
			ring_radius,
			rotation,
			rotation + arc_span,
			36,
			Color(gold.r, gold.g, gold.b, alpha * (0.82 - float(ring_index) * 0.16)),
			1.6 if ring_index == 0 and _selected else 0.9,
			true
		)
	for tick_index in 12:
		var angle := TAU * float(tick_index) / 12.0 + _phase * 0.18 + _phase_offset
		var direction := Vector2.from_angle(angle)
		draw_line(
			center + direction * (radius + 7.0),
			center + direction * (radius + (12.0 if tick_index % 3 == 0 else 10.0)),
			Color(accent_gold.r, accent_gold.g, accent_gold.b, alpha * 0.72),
			1.2 if tick_index % 3 == 0 else 0.7,
			true
		)
	var rail_y := size.y - 14.0
	draw_line(
		Vector2(18.0, rail_y),
		Vector2(size.x - 18.0, rail_y),
		Color(gold.r, gold.g, gold.b, alpha * 0.72),
		1.0,
		true
	)
	var traveler_x := lerpf(22.0, size.x - 22.0, fposmod((_phase + _phase_offset) / TAU, 1.0))
	draw_circle(Vector2(traveler_x, rail_y), 2.2 if _selected else 1.4, Color(BRIGHT_GOLD.r, BRIGHT_GOLD.g, BRIGHT_GOLD.b, alpha))


func _draw_corners(rect: Rect2, gold: Color, alpha: float) -> void:
	var color := Color(gold.r, gold.g, gold.b, alpha)
	var length := 13.0
	for data in [
		[rect.position, Vector2.RIGHT, Vector2.DOWN],
		[Vector2(rect.end.x, rect.position.y), Vector2.LEFT, Vector2.DOWN],
		[Vector2(rect.position.x, rect.end.y), Vector2.RIGHT, Vector2.UP],
		[rect.end, Vector2.LEFT, Vector2.UP],
	]:
		var origin := data[0] as Vector2
		draw_line(origin, origin + (data[1] as Vector2) * length, color, 2.0, true)
		draw_line(origin, origin + (data[2] as Vector2) * length, color, 2.0, true)
