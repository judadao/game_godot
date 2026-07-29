class_name FireUltimateVFX
extends Node2D

signal finished

const MIN_RADIUS := 96.0
const MAX_RADIUS := 960.0
const MIN_DURATION := 0.2
const MAX_DURATION := 3.0
const MIN_INTENSITY := 0.35
const MAX_INTENSITY := 2.5
const CIRCLE_SEGMENTS := 64
const BASE_RING_COUNT := 3
const PARTICLE_TAIL := 0.38
const RING_DELAYS := [0.0, 0.065, 0.13, 0.195]
const ANTICIPATION_END := 0.16
const IGNITION_END := 0.29
const INFERNO_END := 0.68
const IMPACT_END := 0.82
const VISUAL_BOUNDS_SCALE := 1.18
const MIN_READABILITY_HOLE := 44.0
const MAX_READABILITY_HOLE := 72.0
const STAGE_ANTICIPATION := &"anticipation"
const STAGE_IGNITION := &"ignition"
const STAGE_EXPANDING_INFERNO := &"expanding_inferno"
const STAGE_IMPACT_CROWN := &"impact_crown"
const STAGE_EMBER_DECAY := &"ember_decay"
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
@onready var anticipation_guide: Line2D = $AnticipationGuide
@onready var impact_crown: Line2D = $ImpactCrown
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
var _stage_name := STAGE_ANTICIPATION
var _pillars_triggered := false
var _embers_triggered := false


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
	_stage_name = STAGE_ANTICIPATION
	_pillars_triggered = false
	_embers_triggered = false
	_configure_particles()
	flame_pillars.emitting = false
	ember_sparks.emitting = false
	_reset_visuals()

	if _lifecycle_tween != null and _lifecycle_tween.is_valid():
		_lifecycle_tween.kill()
	_lifecycle_tween = create_tween()
	_lifecycle_tween.set_trans(Tween.TRANS_LINEAR)
	_lifecycle_tween.tween_method(_set_progress, 0.0, 1.0, _effect_duration)
	_lifecycle_tween.tween_interval(PARTICLE_TAIL)
	_lifecycle_tween.tween_callback(_finish)


func is_active() -> bool:
	return _active


func get_max_radius() -> float:
	return _max_radius


func get_ring_count() -> int:
	return _ring_count


func get_stage_name() -> StringName:
	return _stage_name


func get_readability_hole_radius() -> float:
	return clampf(_max_radius * 0.14, MIN_READABILITY_HOLE, MAX_READABILITY_HOLE)


func get_visual_bounds_radius() -> float:
	return _max_radius * VISUAL_BOUNDS_SCALE


func get_particle_budget() -> int:
	return flame_pillars.amount + ember_sparks.amount


func debug_set_progress(value: float) -> void:
	if not _active:
		return
	_set_progress(value)


func _draw() -> void:
	if not _active:
		return
	match _stage_name:
		STAGE_ANTICIPATION:
			_draw_anticipation(_stage_progress(0.0, ANTICIPATION_END))
		STAGE_IGNITION:
			_draw_ignition(_stage_progress(ANTICIPATION_END, IGNITION_END))
		STAGE_EXPANDING_INFERNO:
			_draw_expanding_inferno(_stage_progress(IGNITION_END, INFERNO_END))
		STAGE_IMPACT_CROWN:
			_draw_impact(_stage_progress(INFERNO_END, IMPACT_END))
		STAGE_EMBER_DECAY:
			_draw_ember_decay(_stage_progress(IMPACT_END, 1.0))


func _draw_anticipation(stage_progress: float) -> void:
	var gather := ease(stage_progress, 2.25)
	var safe_radius := get_readability_hole_radius()
	var outer_radius := lerpf(_max_radius * 0.42, safe_radius + 30.0, gather)
	for ring_index in 3:
		var radius_offset := float(ring_index) * (10.0 + 2.0 * _active_intensity)
		var alpha := (0.18 + stage_progress * 0.44) * (1.0 - float(ring_index) * 0.18)
		var start_angle := -PI * 0.92 + float(ring_index) * 0.58 - stage_progress * 1.7
		draw_arc(
			Vector2.ZERO,
			outer_radius + radius_offset,
			start_angle,
			start_angle + PI * (1.12 + float(ring_index) * 0.15),
			30,
			Color(1.0, 0.31 + float(ring_index) * 0.12, 0.025, alpha),
			2.0 + float(2 - ring_index) * 0.8,
			true
		)
	_draw_gathering_streaks(outer_radius, stage_progress)


func _draw_ignition(stage_progress: float) -> void:
	var pulse := sin(stage_progress * PI)
	var safe_radius := get_readability_hole_radius()
	var ignition_radius := lerpf(safe_radius + 12.0, _max_radius * 0.31, ease(stage_progress, 0.6))
	for ring_index in 3:
		draw_arc(
			Vector2.ZERO,
			safe_radius + 9.0 + float(ring_index) * 12.0 + pulse * 9.0,
			0.0,
			TAU,
			36,
			Color(1.0, 0.74 + float(ring_index) * 0.08, 0.24, pulse * (0.46 - float(ring_index) * 0.1)),
			5.0 - float(ring_index),
			true
		)
	for ray_index in 18:
		var angle := TAU * float(ray_index) / 18.0 + sin(float(ray_index) * 2.17) * 0.08
		var direction := Vector2.from_angle(angle)
		var length := ignition_radius * (0.64 + 0.32 * absf(sin(float(ray_index) * 1.71)))
		var start := direction * (safe_radius + 8.0)
		var finish := direction * length
		draw_line(
			start,
			finish,
			FLAME_COLORS[ray_index % FLAME_COLORS.size()] * Color(1.0, 1.0, 1.0, pulse * 0.88),
			2.4 + 2.2 * pulse,
			true
		)
	_draw_flame_crown(ignition_radius, 0.36 + pulse * 0.5, 0.66)


func _draw_expanding_inferno(stage_progress: float) -> void:
	var advance := ease(stage_progress, 0.42)
	var safe_radius := get_readability_hole_radius()
	var wave_radius := lerpf(safe_radius + 30.0, _max_radius * 0.96, advance)
	var front_alpha := 1.0 - smoothstep(0.76, 1.0, stage_progress) * 0.32
	draw_arc(
		Vector2.ZERO,
		wave_radius,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(1.0, 0.28, 0.018, 0.42 * front_alpha),
		4.4 * sqrt(_active_intensity),
		true
	)
	draw_arc(
		Vector2.ZERO,
		maxf(safe_radius + 4.0, wave_radius - 13.0),
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(1.0, 0.9, 0.38, 0.32 * front_alpha),
		2.2 * sqrt(_active_intensity),
		true
	)
	_draw_flame_crown(wave_radius, front_alpha, lerpf(0.72, 1.0, stage_progress))
	_draw_heat_ripples(wave_radius, 0.62 * front_alpha)
	_draw_inferno_slashes(wave_radius, stage_progress)
	_draw_spiral_flame_ribbons(stage_progress, 0.34 + 0.34 * stage_progress)
	_draw_scorched_cracks(stage_progress, 0.12 + 0.18 * stage_progress)


func _draw_impact(stage_progress: float) -> void:
	var strike := sin(stage_progress * PI)
	var crown_radius := _max_radius * (0.96 + 0.025 * strike)
	_draw_broken_impact_arcs(crown_radius, strike)
	_draw_spiral_flame_ribbons(1.0, 0.5 + 0.42 * strike)
	_draw_scorched_cracks(1.0, 0.18 + 0.2 * strike)
	_draw_eruption_columns(strike)
	_draw_flame_crown(crown_radius, 0.36 + strike * 0.3, 0.78)


func _draw_ember_decay(stage_progress: float) -> void:
	var fade := 1.0 - ease(stage_progress, 1.7)
	var drift := ease(stage_progress, 0.7)
	draw_arc(
		Vector2.ZERO,
		_max_radius * (0.96 + 0.03 * stage_progress),
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(0.9, 0.12, 0.008, 0.28 * fade),
		3.0 + 3.0 * fade,
		true
	)
	for ember_index in 28:
		var angle := fmod(float(ember_index) * 2.399963, TAU)
		var radial_ratio := 0.24 + fmod(float(ember_index) * 0.173, 0.72)
		var origin := Vector2.from_angle(angle) * _max_radius * radial_ratio
		var rise := Vector2(
			sin(float(ember_index) * 1.83 + stage_progress * 5.0) * 7.0,
			-(12.0 + float(ember_index % 6) * 5.0) * drift
		)
		var ember_alpha := fade * (0.28 + float(ember_index % 4) * 0.12)
		draw_line(
			origin + rise,
			origin + rise + Vector2(0.0, -5.0 - float(ember_index % 5) * 2.0),
			FLAME_COLORS[ember_index % FLAME_COLORS.size()] * Color(1.0, 1.0, 1.0, ember_alpha),
			1.2 + float(ember_index % 3) * 0.7,
			true
		)


func _draw_gathering_streaks(outer_radius: float, stage_progress: float) -> void:
	var safe_radius := get_readability_hole_radius()
	for streak_index in 12:
		var angle := TAU * float(streak_index) / 12.0 + stage_progress * 0.7
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var outer := direction * (outer_radius + float(streak_index % 3) * 9.0)
		var inner := direction * maxf(safe_radius + 8.0, outer_radius - 25.0)
		draw_line(
			outer + tangent * 5.0,
			inner,
			Color(1.0, 0.46, 0.06, 0.2 + stage_progress * 0.34),
			1.4 + float(streak_index % 2),
			true
		)


func _draw_inferno_slashes(wave_radius: float, stage_progress: float) -> void:
	for slash_index in 16:
		var angle := TAU * float(slash_index) / 16.0 + float(slash_index % 4) * 0.045
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var base := direction * wave_radius * (0.82 + 0.08 * sin(float(slash_index) * 2.4))
		var sweep := (
			tangent * (18.0 + float(slash_index % 5) * 4.0)
			+ direction * (12.0 + 20.0 * stage_progress)
		)
		draw_line(
			base - sweep * 0.55,
			base + sweep,
			Color(1.0, 0.52, 0.06, 0.2 + 0.28 * (1.0 - stage_progress)),
			1.6 + float(slash_index % 3) * 0.7,
			true
		)


func _draw_broken_impact_arcs(crown_radius: float, strike: float) -> void:
	for arc_index in 14:
		var start_angle := (
			TAU * float(arc_index) / 14.0
			+ sin(float(arc_index) * 2.37) * 0.11
		)
		var arc_length := 0.19 + 0.16 * absf(sin(float(arc_index) * 1.61))
		var radius_offset := (
			-12.0
			+ float(arc_index % 4) * 8.0
			+ sin(float(arc_index) * 3.73) * 5.0
		)
		var color: Color = FLAME_COLORS[(arc_index + 2) % FLAME_COLORS.size()]
		color.a *= strike * (0.42 + float(arc_index % 3) * 0.13)
		draw_arc(
			Vector2.ZERO,
			crown_radius + radius_offset,
			start_angle,
			start_angle + arc_length,
			9,
			color,
			4.0 + float(arc_index % 4) * 2.2,
			true
		)


func _draw_spiral_flame_ribbons(stage_progress: float, alpha: float) -> void:
	var safe_radius := get_readability_hole_radius() + 14.0
	for ribbon_index in 9:
		var base_angle := TAU * float(ribbon_index) / 9.0 + float(ribbon_index % 3) * 0.08
		var turn := -1.0 if ribbon_index % 2 == 0 else 1.0
		var ribbon_points := PackedVector2Array()
		for point_index in 13:
			var ratio := float(point_index) / 12.0
			var radius_at_point := lerpf(
				safe_radius,
				_max_radius * (0.68 + 0.12 * float(ribbon_index % 4) / 3.0),
				ease(ratio, 0.72)
			)
			var curve_angle := (
				base_angle
				+ turn * sin(ratio * PI) * (0.26 + 0.08 * float(ribbon_index % 3))
				+ stage_progress * 0.06
			)
			ribbon_points.append(Vector2.from_angle(curve_angle) * radius_at_point)
		var pulse := 0.82 + 0.18 * sin(float(ribbon_index) * 2.3 + _progress * 8.0)
		draw_polyline(
			ribbon_points,
			Color(0.62, 0.035, 0.004, alpha * 0.28 * pulse),
			12.0 + float(ribbon_index % 3) * 2.5,
			true
		)
		draw_polyline(
			ribbon_points,
			Color(1.0, 0.23, 0.012, alpha * 0.46 * pulse),
			5.5 + float(ribbon_index % 2) * 1.8,
			true
		)
		draw_polyline(
			ribbon_points,
			Color(1.0, 0.82, 0.22, alpha * 0.58 * pulse),
			1.5 + float(ribbon_index % 3) * 0.45,
			true
		)


func _draw_eruption_columns(strike: float) -> void:
	var offsets := [-0.86, -0.68, -0.5, -0.31, 0.31, 0.5, 0.68, 0.86]
	for column_index in offsets.size():
		var x := _max_radius * float(offsets[column_index])
		var base := Vector2(x, 18.0 + float(column_index % 3) * 5.0)
		var height := _max_radius * (
			0.34
			+ 0.2 * absf(sin(float(column_index) * 1.71 + _progress * 4.0))
		) * (0.68 + 0.32 * strike)
		var half_width := (
			14.0
			+ _max_radius * 0.035
			+ float(column_index % 3) * 4.0
		)
		var lean := (
			-1.0 if column_index % 2 == 0 else 1.0
		) * height * (0.07 + float(column_index % 3) * 0.025)
		var flame := PackedVector2Array([
			base - Vector2(half_width, 0.0),
			base + Vector2(-half_width * 0.82, -height * 0.2),
			base + Vector2(-half_width * 0.3 + lean * 0.22, -height * 0.53),
			base + Vector2(lean, -height),
			base + Vector2(half_width * 0.2 + lean * 0.36, -height * 0.58),
			base + Vector2(half_width * 0.78, -height * 0.25),
			base + Vector2(half_width, 0.0),
		])
		var outer_color: Color = FLAME_COLORS[column_index % 3]
		outer_color.a *= strike * (0.42 + float(column_index % 3) * 0.08)
		draw_colored_polygon(flame, outer_color)
		var core := flame.duplicate()
		for point_index in core.size():
			core[point_index] = base.lerp(core[point_index], 0.55)
		draw_colored_polygon(core, Color(1.0, 0.9, 0.32, outer_color.a * 0.82))
		var splash_direction := -1.0 if column_index % 2 == 0 else 1.0
		draw_line(
			base,
			base + Vector2(splash_direction * half_width * 2.2, -8.0 - float(column_index % 3) * 5.0),
			Color(1.0, 0.42, 0.025, outer_color.a * 0.8),
			3.0 + float(column_index % 2) * 1.5,
			true
		)


func _draw_scorched_cracks(stage_progress: float, alpha: float) -> void:
	var safe_radius := get_readability_hole_radius()
	for crack_index in 20:
		var angle := TAU * float(crack_index) / 20.0 + sin(float(crack_index) * 4.17) * 0.08
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var start_radius := safe_radius + 16.0 + float(crack_index % 3) * 8.0
		var reach := _max_radius * (
			0.42
			+ 0.3 * stage_progress
			+ 0.08 * absf(sin(float(crack_index) * 1.37))
		)
		var start := direction * start_radius
		var bend := direction * lerpf(start_radius, reach, 0.58) + tangent * (
			-9.0 + float(crack_index % 5) * 4.5
		)
		var finish := direction * reach
		draw_polyline(
			PackedVector2Array([start, bend, finish]),
			Color(0.96, 0.12, 0.008, alpha * (0.38 + float(crack_index % 4) * 0.1)),
			0.9 + float(crack_index % 3) * 0.45,
			true
		)
		if crack_index % 2 == 0:
			var branch_direction := (finish - bend).normalized().rotated(
				-0.42 if crack_index % 4 == 0 else 0.42
			)
			draw_line(
				bend,
				bend + branch_direction * (14.0 + float(crack_index % 5) * 3.0),
				Color(1.0, 0.42, 0.04, alpha * 0.42),
				1.2,
				true
			)


func _draw_flame_crown(wave_radius: float, fade: float, height_scale: float) -> void:
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
			wave_radius * 0.075
			+ wave_radius * 0.105 * absf(sin(float(index) * 1.77 + _progress * 5.0))
		) * sqrt(_active_intensity) * height_scale
		height = minf(
			height,
			maxf(0.0, get_visual_bounds_radius() - base.length())
		)
		var width := (
			7.0
			+ wave_radius * 0.018
			+ float(index % 4) * 2.1
		) * minf(1.2, sqrt(_active_intensity))
		var lean := tangent * (
			-0.22
			+ float(index % 5) * 0.11
		) * height
		var flame := PackedVector2Array([
			base - tangent * width,
			base + outward * height * 0.34 - tangent * width * 0.48,
			base + outward * height * 0.7 + lean * 0.42 - tangent * width * 0.2,
			base + outward * height + lean,
			base + outward * height * 0.62 + lean * 0.24 + tangent * width * 0.42,
			base + outward * height * 0.3 + tangent * width,
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
	_stage_name = _resolve_stage(_progress)
	_update_particle_stage()
	_update_scorch()
	_update_waves()
	_update_stage_guides()
	queue_redraw()


func _update_scorch() -> void:
	var scorch_progress := ease(
		clampf((_progress - ANTICIPATION_END) / (INFERNO_END - ANTICIPATION_END), 0.0, 1.0),
		0.45
	)
	var scorch_radius := _max_radius * 0.91 * scorch_progress
	scorched_ground.polygon = _circle_points(scorch_radius, CIRCLE_SEGMENTS)
	scorched_ground.color = Color(
		0.11,
		0.025,
		0.008,
		0.2 * scorch_progress * (1.0 - smoothstep(IMPACT_END, 1.0, _progress))
	)


func _update_waves() -> void:
	for index in _waves.size():
		var wave := _waves[index]
		var enabled := index < _ring_count
		wave.visible = enabled
		if not enabled:
			continue
		var local_progress := clampf(
			(
				_progress
				- IGNITION_END
				- float(RING_DELAYS[index])
			) / (
				INFERNO_END
				- IGNITION_END
				- float(RING_DELAYS[index])
			),
			0.0,
			1.0
		)
		var wave_radius := lerpf(
			get_readability_hole_radius() + 18.0,
			_max_radius,
			ease(local_progress, 0.34)
		)
		wave.points = _organic_circle_points(wave_radius, CIRCLE_SEGMENTS, index)
		var alpha := sin(local_progress * PI)
		if _progress >= INFERNO_END:
			alpha = 1.0 - smoothstep(INFERNO_END, IMPACT_END, _progress)
		wave.modulate.a = clampf(alpha * (0.76 - float(index) * 0.08), 0.0, 1.0)
		wave.width = (
			(5.6 - float(index) * 0.7)
			* sqrt(_active_intensity)
		)


func _update_stage_guides() -> void:
	var anticipation_progress := _stage_progress(0.0, ANTICIPATION_END)
	anticipation_guide.visible = _stage_name == STAGE_ANTICIPATION
	if anticipation_guide.visible:
		var gather := ease(anticipation_progress, 2.25)
		var outer_radius := lerpf(
			_max_radius * 0.4,
			get_readability_hole_radius() + 22.0,
			gather
		)
		anticipation_guide.points = _spiral_points(outer_radius, anticipation_progress)
		anticipation_guide.modulate.a = 0.35 + anticipation_progress * 0.55
		anticipation_guide.width = 2.5 + anticipation_progress * 2.5

	var impact_progress := _stage_progress(INFERNO_END, IMPACT_END)
	impact_crown.visible = _stage_name == STAGE_IMPACT_CROWN
	if impact_crown.visible:
		impact_crown.points = _crown_points(
			_max_radius * (0.96 + 0.02 * sin(impact_progress * PI)),
			CIRCLE_SEGMENTS
		)
		impact_crown.modulate.a = sin(impact_progress * PI) * 0.32
		impact_crown.width = 2.5 + 2.0 * sqrt(_active_intensity)


func _update_particle_stage() -> void:
	if not _pillars_triggered and _progress >= IGNITION_END:
		_pillars_triggered = true
		flame_pillars.restart()
		flame_pillars.emitting = true
	if not _embers_triggered and _progress >= INFERNO_END:
		_embers_triggered = true
		ember_sparks.restart()
		ember_sparks.emitting = true


func _configure_particles() -> void:
	flame_pillars.amount = clampi(roundi(30.0 * _active_intensity), 18, 76)
	ember_sparks.amount = clampi(roundi(58.0 * _active_intensity), 28, 144)
	flame_pillars.lifetime = minf(0.72, _effect_duration * 0.48 + 0.16)
	ember_sparks.lifetime = minf(0.72, _effect_duration * 0.38 + 0.28)
	var pillar_material := flame_pillars.process_material as ParticleProcessMaterial
	if pillar_material != null:
		pillar_material.emission_ring_radius = _max_radius * 0.76
		pillar_material.emission_ring_inner_radius = maxf(
			get_readability_hole_radius(),
			_max_radius * 0.2
		)
		pillar_material.initial_velocity_min = _max_radius * 0.12 / flame_pillars.lifetime
		pillar_material.initial_velocity_max = _max_radius * 0.28 / flame_pillars.lifetime
	var spark_material := ember_sparks.process_material as ParticleProcessMaterial
	if spark_material != null:
		spark_material.emission_ring_radius = _max_radius * 0.88
		spark_material.emission_ring_inner_radius = _max_radius * 0.58
		spark_material.initial_velocity_min = _max_radius * 0.14 / ember_sparks.lifetime
		spark_material.initial_velocity_max = _max_radius * 0.26 / ember_sparks.lifetime


func _reset_visuals() -> void:
	scorched_ground.polygon = _circle_points(1.0, CIRCLE_SEGMENTS)
	scorched_ground.color.a = 0.0
	for wave in _waves:
		wave.points = _circle_points(1.0, CIRCLE_SEGMENTS)
		wave.modulate.a = 0.0
	echo_wave.visible = false
	anticipation_guide.points = _spiral_points(1.0, 0.0)
	anticipation_guide.modulate.a = 0.0
	anticipation_guide.visible = false
	impact_crown.points = _circle_points(1.0, CIRCLE_SEGMENTS)
	impact_crown.modulate.a = 0.0
	impact_crown.visible = false
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


func _spiral_points(outer_radius: float, stage_progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_radius := get_readability_hole_radius() + 5.0
	for index in 52:
		var ratio := float(index) / 51.0
		var angle := (
			-PI * 0.5
			+ ratio * TAU * 1.64
			- stage_progress * 1.8
		)
		var radius_at_point := lerpf(outer_radius, safe_radius, ratio)
		points.append(Vector2.from_angle(angle) * radius_at_point)
	return points


func _crown_points(circle_radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segment_count:
		var angle := TAU * float(index) / float(segment_count)
		var tooth := (
			0.985
			+ 0.035 * sin(angle * 7.0 + 0.4)
			+ 0.022 * sin(angle * 13.0 - 0.8)
		)
		points.append(Vector2.from_angle(angle) * circle_radius * tooth)
	points.append(points[0])
	return points


func _stage_progress(stage_start: float, stage_end: float) -> float:
	return clampf((_progress - stage_start) / (stage_end - stage_start), 0.0, 1.0)


func _resolve_stage(progress_value: float) -> StringName:
	if progress_value < ANTICIPATION_END:
		return STAGE_ANTICIPATION
	if progress_value < IGNITION_END:
		return STAGE_IGNITION
	if progress_value < INFERNO_END:
		return STAGE_EXPANDING_INFERNO
	if progress_value < IMPACT_END:
		return STAGE_IMPACT_CROWN
	return STAGE_EMBER_DECAY


func _finish() -> void:
	if not _active:
		return
	_active = false
	flame_pillars.emitting = false
	ember_sparks.emitting = false
	finished.emit()
	queue_free()
