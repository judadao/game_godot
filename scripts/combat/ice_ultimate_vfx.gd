class_name IceUltimateVFX
extends Node2D

signal finished
signal stage_changed(stage_name: StringName)

const MIN_RADIUS := 160.0
const MAX_RADIUS_LIMIT := 720.0
const MIN_DURATION := 0.5
const MAX_DURATION := 3.5
const MIN_CRYSTALS := 10
const MAX_CRYSTALS := 40
const MIN_SHARDS := 12
const MAX_SHARDS := 64
const MIN_MIST_PARTICLES := 24
const MAX_MIST_PARTICLES := 96
const RING_POINT_COUNT := 80
const READABILITY_HOLE_RADIUS := 64.0
const MIST_TAIL_DURATION := 0.18
const GOLDEN_ANGLE := 2.399963
const STAGE_NAMES := [
	&"anticipation",
	&"radial_freeze",
	&"crystal_eruption",
	&"shatter_highlight",
	&"cold_mist_decay",
]
const STAGE_ENDS := [0.14, 0.38, 0.67, 0.83, 1.0]

@export_range(MIN_RADIUS, MAX_RADIUS_LIMIT, 1.0) var radius: float = 460.0
@export_range(0.1, 1.0, 0.05) var intensity: float = 0.85
@export_range(MIN_DURATION, MAX_DURATION, 0.05) var duration: float = 1.55

@onready var ground_frost: Polygon2D = $GroundFrost
@onready var frost_rings: Node2D = $FrostRings
@onready var outer_ring: Line2D = $FrostRings/OuterRing
@onready var inner_ring: Line2D = $FrostRings/InnerRing
@onready var highlight_ring: Line2D = $HighlightRing
@onready var crystals: Node2D = $Crystals
@onready var shatter_fragments: Node2D = $ShatterFragments
@onready var cold_mist: GPUParticles2D = $ColdMist
@onready var center_readability: Polygon2D = $CenterReadability

var active := false
var max_radius := 0.0
var crystal_count := 0
var shard_count := 0

var _effect_duration := 1.55
var _elapsed := 0.0
var _normalized_progress := 0.0
var _stage_index := -1
var _stage_progress := 0.0
var _mist_started := false
var _crystal_nodes: Array[Polygon2D] = []
var _shard_nodes: Array[Polygon2D] = []


func _ready() -> void:
	set_process(false)
	visible = false
	_reset_authored_layers()


func play(center: Variant = null) -> void:
	if not is_inside_tree():
		push_error("IceUltimateVFX.play() requires the scene to be inside the SceneTree.")
		return
	_apply_center(center)
	max_radius = clampf(radius, MIN_RADIUS, MAX_RADIUS_LIMIT)
	intensity = clampf(intensity, 0.1, 1.0)
	_effect_duration = clampf(duration, MIN_DURATION, MAX_DURATION)
	crystal_count = clampi(
		roundi(lerpf(float(MIN_CRYSTALS), float(MAX_CRYSTALS), intensity)),
		MIN_CRYSTALS,
		MAX_CRYSTALS
	)
	shard_count = clampi(
		roundi(lerpf(float(MIN_SHARDS), float(MAX_SHARDS), intensity)),
		MIN_SHARDS,
		MAX_SHARDS
	)
	_elapsed = 0.0
	_normalized_progress = 0.0
	_stage_index = -1
	_stage_progress = 0.0
	_mist_started = false
	active = true
	visible = true
	modulate = Color.WHITE

	_build_ring_geometry()
	_build_ground_geometry()
	_build_crystals()
	_build_shatter_fragments()
	_configure_mist()
	_set_normalized_progress(0.0)
	set_process(true)


func is_active() -> bool:
	return active


func get_max_radius() -> float:
	return max_radius


func get_crystal_count() -> int:
	return crystal_count


func get_shard_count() -> int:
	return shard_count


func get_visual_budget() -> int:
	return crystal_count + shard_count + cold_mist.amount


func get_stage_name() -> StringName:
	if _stage_index < 0 or _stage_index >= STAGE_NAMES.size():
		return &"inactive"
	return STAGE_NAMES[_stage_index]


func get_readability_hole_radius() -> float:
	return READABILITY_HOLE_RADIUS


func get_visual_bounds_radius() -> float:
	return max_radius * 1.14


func debug_set_progress(value: float) -> void:
	if not active:
		return
	_set_normalized_progress(clampf(value, 0.0, 0.999))


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed = minf(_elapsed + delta, _effect_duration + MIST_TAIL_DURATION)
	if _elapsed <= _effect_duration:
		_set_normalized_progress(_elapsed / _effect_duration)
	frost_rings.rotation = sin(_elapsed * 2.4) * 0.018
	outer_ring.rotation = _elapsed * 0.12
	inner_ring.rotation = -_elapsed * 0.19
	if _elapsed >= _effect_duration + MIST_TAIL_DURATION:
		_finish()


func _draw() -> void:
	if not active:
		return
	match get_stage_name():
		&"anticipation":
			_draw_anticipation()
		&"radial_freeze":
			_draw_radial_freeze()
		&"crystal_eruption":
			_draw_crystal_eruption()
		&"shatter_highlight":
			_draw_shatter_highlight()
		&"cold_mist_decay":
			_draw_cold_mist_decay()


func _draw_anticipation() -> void:
	var pulse := sin(_stage_progress * PI)
	var contraction := lerpf(max_radius * 0.48, READABILITY_HOLE_RADIUS * 1.35, _stage_progress)
	draw_circle(
		Vector2.ZERO,
		READABILITY_HOLE_RADIUS * (1.18 + pulse * 0.12),
		Color(0.7, 0.97, 1.0, 0.05 + pulse * 0.08)
	)
	for arc_index in 4:
		var angle_offset := _elapsed * (1.6 + float(arc_index) * 0.24)
		draw_arc(
			Vector2.ZERO,
			contraction * (0.62 + float(arc_index) * 0.13),
			angle_offset + float(arc_index) * 1.2,
			angle_offset + float(arc_index) * 1.2 + PI * 0.72,
			20,
			Color(0.5, 0.91, 1.0, (0.24 + pulse * 0.42) * (1.0 - float(arc_index) * 0.13)),
			1.4 + intensity * 1.8,
			true
		)
	for mote_index in 14:
		var angle := float(mote_index) * GOLDEN_ANGLE - _elapsed * 1.7
		var start_radius := contraction * (0.78 + 0.18 * _hash_ratio(mote_index + 31))
		var end_radius := maxf(READABILITY_HOLE_RADIUS, start_radius - 18.0 - intensity * 14.0)
		var start := Vector2.from_angle(angle) * start_radius
		var end := Vector2.from_angle(angle + 0.06) * end_radius
		draw_line(start, end, Color(0.82, 0.99, 1.0, 0.35 + pulse * 0.45), 1.2, true)


func _draw_radial_freeze() -> void:
	var freeze_progress := _ease_out_cubic(_stage_progress)
	var reveal_radius := max_radius * freeze_progress
	draw_circle(Vector2.ZERO, reveal_radius, Color(0.12, 0.48, 0.68, 0.08))
	draw_circle(Vector2.ZERO, reveal_radius * 0.68, Color(0.55, 0.9, 1.0, 0.045))
	for front_index in 3:
		var delayed := clampf((_stage_progress - float(front_index) * 0.11) / 0.78, 0.0, 1.0)
		var ring_radius := max_radius * _ease_out_cubic(delayed)
		var alpha := sin(delayed * PI) * (0.78 - float(front_index) * 0.16)
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			0.0,
			TAU,
			64,
			Color(0.68, 0.96, 1.0, alpha),
			7.0 - float(front_index) * 1.8,
			true
		)
		draw_arc(
			Vector2.ZERO,
			ring_radius + 5.0,
			0.0,
			TAU,
			64,
			Color(0.08, 0.34, 0.62, alpha * 0.52),
			2.0,
			true
		)
	_draw_cracks(reveal_radius, 0.9, freeze_progress)


func _draw_crystal_eruption() -> void:
	draw_circle(Vector2.ZERO, max_radius, Color(0.11, 0.43, 0.62, 0.075))
	_draw_cracks(max_radius, 0.8, 1.0)
	var flare := sin(clampf(_stage_progress * 1.8, 0.0, 1.0) * PI)
	for ray_index in 12:
		var angle := float(ray_index) * GOLDEN_ANGLE + sin(float(ray_index) * 2.1) * 0.12
		var inner := READABILITY_HOLE_RADIUS * (1.4 + 0.22 * _hash_ratio(ray_index + 9))
		var outer := max_radius * (0.42 + 0.5 * _hash_ratio(ray_index + 73))
		draw_line(
			Vector2.from_angle(angle) * inner,
			Vector2.from_angle(angle) * outer,
			Color(0.73, 0.96, 1.0, flare * 0.18),
			1.0 + intensity,
			true
		)
	_draw_sparkles(max_radius, 14, 0.75)


func _draw_shatter_highlight() -> void:
	var flash := sin(_stage_progress * PI)
	var flash_radius := max_radius * lerpf(0.42, 1.06, _ease_out_cubic(_stage_progress))
	draw_circle(Vector2.ZERO, flash_radius, Color(0.72, 0.96, 1.0, flash * 0.10))
	draw_arc(
		Vector2.ZERO,
		flash_radius,
		0.0,
		TAU,
		72,
		Color(0.94, 1.0, 1.0, flash * 0.72),
		2.0 + 5.0 * (1.0 - _stage_progress),
		true
	)
	for ray_index in 18:
		var angle := float(ray_index) * GOLDEN_ANGLE + 0.18 * sin(float(ray_index) * 3.7)
		var inner := max_radius * (0.18 + 0.28 * _hash_ratio(ray_index + 44))
		var length := max_radius * (0.12 + 0.18 * _hash_ratio(ray_index + 88)) * flash
		draw_line(
			Vector2.from_angle(angle) * inner,
			Vector2.from_angle(angle) * (inner + length),
			Color(0.83, 0.98, 1.0, flash * 0.74),
			1.0 + 1.5 * intensity,
			true
		)
	_draw_sparkles(max_radius * 1.04, 22, flash)


func _draw_cold_mist_decay() -> void:
	var fade := 1.0 - _stage_progress
	draw_circle(Vector2.ZERO, max_radius, Color(0.12, 0.42, 0.56, 0.055 * fade))
	for ribbon_index in 7:
		var y_offset := lerpf(-max_radius * 0.36, max_radius * 0.34, float(ribbon_index) / 6.0)
		var drift := sin(_elapsed * 1.8 + float(ribbon_index) * 1.3) * max_radius * 0.08
		var points := PackedVector2Array()
		for point_index in 9:
			var ratio := float(point_index) / 8.0
			points.append(Vector2(
				lerpf(-max_radius * 0.78, max_radius * 0.78, ratio) + drift,
				y_offset + sin(ratio * TAU + _elapsed + float(ribbon_index)) * 12.0
			))
		draw_polyline(
			points,
			Color(0.58, 0.87, 0.96, fade * (0.055 + float(ribbon_index % 3) * 0.018)),
			10.0 + float(ribbon_index % 2) * 5.0,
			true
		)
	_draw_sparkles(max_radius, 10, fade * 0.55)


func _draw_cracks(reveal_radius: float, opacity: float, reveal: float) -> void:
	var crack_count := 12 + roundi(intensity * 10.0)
	for crack_index in crack_count:
		var base_angle := TAU * float(crack_index) / float(crack_count)
		base_angle += sin(float(crack_index) * 2.43) * 0.11
		var path_length := reveal_radius * (0.72 + 0.26 * _hash_ratio(crack_index + 17))
		var points := PackedVector2Array()
		var segment_count := 5 + crack_index % 3
		for segment_index in range(segment_count + 1):
			var ratio := float(segment_index) / float(segment_count)
			var distance := lerpf(READABILITY_HOLE_RADIUS, path_length, ratio)
			var bend := sin(float(crack_index * 17 + segment_index * 29)) * 0.065
			points.append(Vector2.from_angle(base_angle + bend) * distance)
		draw_polyline(
			points,
			Color(0.01, 0.13, 0.25, opacity * 0.72 * reveal),
			3.6 + intensity * 1.8,
			true
		)
		draw_polyline(
			points,
			Color(0.66, 0.96, 1.0, opacity * 0.78 * reveal),
			1.0 + intensity,
			true
		)
		if crack_index % 2 == 0:
			_draw_crack_branch(points, crack_index, opacity * reveal)


func _draw_crack_branch(spine: PackedVector2Array, crack_index: int, opacity: float) -> void:
	if spine.size() < 4:
		return
	var source_index := 2 + crack_index % (spine.size() - 3)
	var source := spine[source_index]
	var direction := source.normalized().rotated(
		(-0.48 if crack_index % 4 == 0 else 0.42)
		+ sin(float(crack_index) * 1.9) * 0.07
	)
	var length := max_radius * (0.055 + 0.035 * _hash_ratio(crack_index + 101))
	draw_polyline(
		PackedVector2Array([
			source,
			source + direction * length * 0.48,
			source + direction * length,
		]),
		Color(0.72, 0.98, 1.0, opacity * 0.58),
		1.0 + intensity * 0.7,
		true
	)


func _draw_sparkles(area_radius: float, count: int, opacity: float) -> void:
	for sparkle_index in count:
		var angle := float(sparkle_index) * GOLDEN_ANGLE + _elapsed * 0.38
		var distance := area_radius * (0.24 + 0.72 * _hash_ratio(sparkle_index + 141))
		var center := Vector2.from_angle(angle) * distance
		var size := 2.0 + 3.0 * intensity * _hash_ratio(sparkle_index + 211)
		draw_line(
			center - Vector2(size, 0.0),
			center + Vector2(size, 0.0),
			Color(0.76, 0.97, 1.0, opacity * 0.84),
			1.1,
			true
		)
		draw_line(
			center - Vector2(0.0, size),
			center + Vector2(0.0, size),
			Color.WHITE,
			1.0,
			true
		)


func _set_normalized_progress(value: float) -> void:
	_normalized_progress = clampf(value, 0.0, 1.0)
	var next_stage := _resolve_stage_index(_normalized_progress)
	var stage_start := 0.0 if next_stage == 0 else float(STAGE_ENDS[next_stage - 1])
	var stage_end := float(STAGE_ENDS[next_stage])
	_stage_progress = inverse_lerp(stage_start, stage_end, _normalized_progress)
	if next_stage != _stage_index:
		_stage_index = next_stage
		_enter_stage()
	_update_stage_layers()
	queue_redraw()


func _resolve_stage_index(progress: float) -> int:
	for index in STAGE_ENDS.size():
		if progress <= float(STAGE_ENDS[index]):
			return index
	return STAGE_ENDS.size() - 1


func _enter_stage() -> void:
	var stage_name := get_stage_name()
	if stage_name == &"cold_mist_decay" and not _mist_started:
		_mist_started = true
		cold_mist.restart()
		cold_mist.emitting = true
	stage_changed.emit(stage_name)


func _update_stage_layers() -> void:
	match get_stage_name():
		&"anticipation":
			_update_anticipation_layers()
		&"radial_freeze":
			_update_radial_layers()
		&"crystal_eruption":
			_update_crystal_layers()
		&"shatter_highlight":
			_update_shatter_layers()
		&"cold_mist_decay":
			_update_decay_layers()


func _update_anticipation_layers() -> void:
	var pulse := sin(_stage_progress * PI)
	var ring_scale := lerpf(0.48, 0.16, _stage_progress)
	frost_rings.scale = Vector2.ONE * ring_scale
	outer_ring.modulate.a = 0.22 + pulse * 0.68
	inner_ring.modulate.a = 0.32 + pulse * 0.62
	ground_frost.modulate.a = 0.0
	highlight_ring.modulate.a = 0.0
	center_readability.modulate.a = 0.42 + pulse * 0.28
	_hide_crystals()
	_hide_shards()


func _update_radial_layers() -> void:
	var expansion := _ease_out_cubic(_stage_progress)
	frost_rings.scale = Vector2.ONE * maxf(0.02, expansion)
	outer_ring.modulate.a = sin(_stage_progress * PI) * 0.95
	inner_ring.modulate.a = clampf(sin(_stage_progress * PI) * 1.12, 0.0, 1.0)
	ground_frost.scale = Vector2.ONE * maxf(0.02, expansion)
	ground_frost.modulate.a = 0.34 + 0.34 * _stage_progress
	highlight_ring.modulate.a = 0.0
	center_readability.modulate.a = 0.72
	_hide_crystals()
	_hide_shards()


func _update_crystal_layers() -> void:
	frost_rings.scale = Vector2.ONE
	outer_ring.modulate.a = lerpf(0.72, 0.34, _stage_progress)
	inner_ring.modulate.a = lerpf(0.58, 0.22, _stage_progress)
	ground_frost.scale = Vector2.ONE
	ground_frost.modulate.a = 0.68
	highlight_ring.modulate.a = 0.0
	center_readability.modulate.a = 0.78
	_hide_shards()
	for crystal_index in _crystal_nodes.size():
		var crystal := _crystal_nodes[crystal_index]
		var reveal_at := 0.04 + 0.58 * _hash_ratio(crystal_index + 29)
		var rise := smoothstep(reveal_at, minf(1.0, reveal_at + 0.28), _stage_progress)
		_place_crystal(crystal, crystal_index, rise, rise)


func _update_shatter_layers() -> void:
	frost_rings.scale = Vector2.ONE * lerpf(1.0, 1.06, _stage_progress)
	outer_ring.modulate.a = (1.0 - _stage_progress) * 0.42
	inner_ring.modulate.a = (1.0 - _stage_progress) * 0.3
	ground_frost.modulate.a = lerpf(0.68, 0.48, _stage_progress)
	center_readability.modulate.a = 0.82
	var highlight_progress := _ease_out_cubic(_stage_progress)
	highlight_ring.scale = Vector2.ONE * lerpf(0.52, 1.12, highlight_progress)
	highlight_ring.width = lerpf(12.0, 2.0, highlight_progress)
	highlight_ring.modulate.a = sin(_stage_progress * PI)
	for crystal_index in _crystal_nodes.size():
		var crystal := _crystal_nodes[crystal_index]
		_place_crystal(
			crystal,
			crystal_index,
			lerpf(1.0, 0.82, _stage_progress),
			lerpf(1.0, 0.48, _stage_progress)
		)
	for shard_index in _shard_nodes.size():
		var shard := _shard_nodes[shard_index]
		var delayed := clampf((_stage_progress - 0.18 * _hash_ratio(shard_index + 37)) / 0.82, 0.0, 1.0)
		var angle := float(shard_index) * GOLDEN_ANGLE + sin(float(shard_index) * 2.3) * 0.2
		var source_radius := max_radius * (0.22 + 0.66 * _hash_ratio(shard_index + 57))
		var travel := max_radius * (0.08 + 0.18 * _hash_ratio(shard_index + 91))
		var tangent := Vector2.from_angle(angle).orthogonal()
		shard.position = (
			Vector2.from_angle(angle) * (source_radius + travel * _ease_out_cubic(delayed))
			+ tangent * sin(delayed * PI) * 18.0
		)
		shard.rotation = angle + delayed * (1.8 + _hash_ratio(shard_index + 7) * 2.4)
		shard.scale = Vector2.ONE * lerpf(0.35, 1.0, delayed)
		shard.modulate.a = sin(delayed * PI) * 0.94


func _update_decay_layers() -> void:
	var fade := 1.0 - _stage_progress
	frost_rings.scale = Vector2.ONE * lerpf(1.06, 1.12, _stage_progress)
	outer_ring.modulate.a = fade * 0.18
	inner_ring.modulate.a = fade * 0.12
	ground_frost.modulate.a = fade * 0.48
	highlight_ring.modulate.a = fade * 0.12
	center_readability.modulate.a = fade * 0.66
	for crystal_index in _crystal_nodes.size():
		var crystal := _crystal_nodes[crystal_index]
		_place_crystal(crystal, crystal_index, lerpf(0.82, 0.64, _stage_progress), fade * 0.44)
		crystal.position.y += _stage_progress * 14.0
	for shard_index in _shard_nodes.size():
		var shard := _shard_nodes[shard_index]
		shard.position.y += _stage_progress * 0.8
		shard.modulate.a = fade * 0.28


func _build_ring_geometry() -> void:
	outer_ring.points = _organic_circle_points(max_radius, 0)
	inner_ring.points = _organic_circle_points(max_radius * 0.73, 1)
	highlight_ring.points = _circle_points(max_radius, RING_POINT_COUNT)
	outer_ring.width = 4.0 + intensity * 4.0
	inner_ring.width = 2.0 + intensity * 3.0


func _build_ground_geometry() -> void:
	ground_frost.polygon = _circle_points(max_radius, RING_POINT_COUNT)
	ground_frost.color = Color(0.16, 0.61, 0.8, 0.22 + intensity * 0.1)
	center_readability.polygon = _circle_points(READABILITY_HOLE_RADIUS, 40)


func _build_crystals() -> void:
	for child in crystals.get_children():
		child.free()
	_crystal_nodes.clear()
	for crystal_index in crystal_count:
		var crystal := Polygon2D.new()
		var major := crystal_index % 5 == 0
		var height := (
			(58.0 if major else 27.0)
			+ (54.0 if major else 34.0) * _hash_ratio(crystal_index + 13) * intensity
		)
		var half_width := (
			(8.0 if major else 4.5)
			+ (5.0 if major else 3.5) * _hash_ratio(crystal_index + 71)
		)
		crystal.polygon = PackedVector2Array([
			Vector2(-half_width, 3.0),
			Vector2(-half_width * 0.72, -height * 0.42),
			Vector2(-half_width * 0.25, -height * 0.78),
			Vector2(0.0, -height),
			Vector2(half_width * 0.38, -height * 0.64),
			Vector2(half_width, 3.0),
		])
		crystal.color = Color(
			0.18 + 0.16 * _hash_ratio(crystal_index + 5),
			0.68 + 0.2 * _hash_ratio(crystal_index + 19),
			1.0,
			0.96
		)
		crystal.use_parent_material = true
		crystal.z_index = crystal_index % 4
		_add_crystal_facets(crystal, half_width, height)
		crystals.add_child(crystal)
		_crystal_nodes.append(crystal)


func _place_crystal(
	crystal: Polygon2D,
	crystal_index: int,
	rise: float,
	alpha: float
) -> void:
	var angle := float(crystal_index) * GOLDEN_ANGLE
	var major := crystal_index % 5 == 0
	var ring_ratio := (
		0.68 + 0.28 * _hash_ratio(crystal_index + 97)
		if major
		else 0.28 + 0.64 * _hash_ratio(crystal_index + 97)
	)
	var target := Vector2.from_angle(angle) * max_radius * ring_ratio
	crystal.position = target + Vector2.from_angle(angle) * (1.0 - rise) * 22.0
	crystal.rotation = sin(float(crystal_index) * 1.7) * 0.14
	var width_scale := 0.76 + 0.58 * _hash_ratio(crystal_index + 63)
	crystal.scale = Vector2(width_scale, maxf(0.02, rise))
	crystal.modulate.a = alpha


func _add_crystal_facets(crystal: Polygon2D, half_width: float, height: float) -> void:
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-half_width, 2.0),
		Vector2(-half_width * 0.7, -height * 0.4),
		Vector2(0.0, -height),
		Vector2(-half_width * 0.12, -height * 0.08),
	])
	shadow.color = Color(0.02, 0.18, 0.38, 0.62)
	crystal.add_child(shadow)
	var highlight := Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(-half_width * 0.12, -height * 0.05),
		Vector2(0.0, -height * 0.92),
		Vector2(half_width * 0.26, -height * 0.6),
		Vector2(half_width * 0.2, -height * 0.08),
	])
	highlight.color = Color(0.9, 1.0, 1.0, 0.82)
	crystal.add_child(highlight)
	var base_glow := Polygon2D.new()
	base_glow.polygon = PackedVector2Array([
		Vector2(-half_width * 1.7, 1.0),
		Vector2(half_width * 1.8, 1.0),
		Vector2(half_width * 1.25, 8.0),
		Vector2(-half_width * 1.2, 8.0),
	])
	base_glow.color = Color(0.38, 0.88, 1.0, 0.42)
	base_glow.z_index = -1
	crystal.add_child(base_glow)


func _build_shatter_fragments() -> void:
	for child in shatter_fragments.get_children():
		child.free()
	_shard_nodes.clear()
	for shard_index in shard_count:
		var shard := Polygon2D.new()
		var length := 11.0 + 16.0 * _hash_ratio(shard_index + 17)
		var width := 3.0 + 5.0 * _hash_ratio(shard_index + 83)
		shard.polygon = PackedVector2Array([
			Vector2(-width, 0.0),
			Vector2(0.0, -length),
			Vector2(width * 0.7, 0.0),
			Vector2(0.0, length * 0.28),
		])
		shard.color = (
			Color(0.85, 1.0, 1.0, 0.96)
			if shard_index % 3 == 0
			else Color(0.28, 0.78, 1.0, 0.9)
		)
		shard.use_parent_material = true
		shatter_fragments.add_child(shard)
		_shard_nodes.append(shard)


func _configure_mist() -> void:
	cold_mist.amount = clampi(
		roundi(lerpf(float(MIN_MIST_PARTICLES), float(MAX_MIST_PARTICLES), intensity)),
		MIN_MIST_PARTICLES,
		MAX_MIST_PARTICLES
	)
	cold_mist.lifetime = maxf(0.16, _effect_duration * 0.24)
	cold_mist.one_shot = true
	cold_mist.explosiveness = 0.28
	cold_mist.emitting = false
	var material := cold_mist.process_material as ParticleProcessMaterial
	if material != null:
		material = material.duplicate() as ParticleProcessMaterial
		material.emission_ring_radius = max_radius * 0.92
		material.emission_ring_inner_radius = max_radius * 0.2
		material.initial_velocity_min = max_radius * 0.035
		material.initial_velocity_max = max_radius * 0.09
		cold_mist.process_material = material


func _hide_crystals() -> void:
	for crystal in _crystal_nodes:
		crystal.modulate.a = 0.0
		crystal.scale = Vector2(0.7, 0.02)


func _hide_shards() -> void:
	for shard in _shard_nodes:
		shard.modulate.a = 0.0
		shard.scale = Vector2.ONE * 0.2


func _reset_authored_layers() -> void:
	ground_frost.modulate.a = 0.0
	outer_ring.modulate.a = 0.0
	inner_ring.modulate.a = 0.0
	highlight_ring.modulate.a = 0.0
	center_readability.modulate.a = 0.0
	cold_mist.emitting = false


func _apply_center(center: Variant) -> void:
	if center == null:
		return
	if center is Vector2:
		global_position = center
		return
	if center is Node2D:
		global_position = (center as Node2D).global_position
		return
	push_warning("IceUltimateVFX.play() center must be Vector2, Node2D, or null.")


func _organic_circle_points(circle_radius: float, seed: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in RING_POINT_COUNT:
		var angle := TAU * float(point_index) / float(RING_POINT_COUNT)
		var wobble := (
			1.0
			+ 0.018 * sin(angle * 7.0 + float(seed) * 1.8)
			+ 0.012 * sin(angle * 13.0 - float(seed) * 0.9)
		)
		points.append(Vector2.from_angle(angle) * circle_radius * wobble)
	points.append(points[0])
	return points


func _circle_points(circle_radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		points.append(Vector2.from_angle(angle) * circle_radius)
	points.append(points[0])
	return points


func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse


func _hash_ratio(value: int) -> float:
	var hashed: int = absi(value * 1103515245 + 12345) % 1000
	return float(hashed) / 999.0


func _finish() -> void:
	if not active:
		return
	active = false
	set_process(false)
	cold_mist.emitting = false
	finished.emit()
	queue_free()
