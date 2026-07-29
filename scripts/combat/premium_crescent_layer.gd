class_name PremiumCrescentLayer
extends Node2D

const ATLAS: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_crescent_quality_atlas_v3.png"
)
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 2
const RELEASE_END := 0.38
const TRAVEL_START := 0.18
const FLOW_RIBBON_SAMPLES := 3
const DEFORMATION_SAMPLES := 3

const TILE_OUTER_GLOW := 0
const TILE_MOON_CORE := 1
const TILE_INNER_CURRENT := 2
const TILE_FLOW_RIBBONS := 3
const TILE_GROUND_CUT := 4
const TILE_SPARK_DEBRIS := 5
const TILE_CONTACT_BLOOM := 6
const TILE_DECAY_FRAGMENTS := 7

var _target_offset := Vector2.RIGHT
var _travel_progress := 0.0
var _impact_progress := 0.0
var _attack_scale := 1.0
var _combo_tier := 0


func configure(target_offset: Vector2, attack_scale: float, combo_tier: int) -> void:
	_target_offset = target_offset
	_attack_scale = clampf(attack_scale, 1.0, 3.0)
	_combo_tier = clampi(combo_tier, 0, 3)
	queue_redraw()


func set_progress(travel_progress: float, impact_progress: float) -> void:
	_travel_progress = clampf(travel_progress, 0.0, 1.0)
	_impact_progress = clampf(impact_progress, 0.0, 1.0)
	queue_redraw()


func get_flow_ribbon_sample_count() -> int:
	return FLOW_RIBBON_SAMPLES


func get_deformation_sample_count() -> int:
	return DEFORMATION_SAMPLES


func _draw() -> void:
	if ATLAS == null:
		return
	var direction := _target_offset.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if _travel_progress < 1.0:
		_draw_release(direction)
		_draw_travel(direction)
	if _impact_progress > 0.0:
		_draw_impact(direction)


func _draw_release(direction: Vector2) -> void:
	if _travel_progress > RELEASE_END:
		return
	var progress := clampf(_travel_progress / RELEASE_END, 0.0, 1.0)
	var envelope := (
		smoothstep(0.0, 0.11, progress)
		* (1.0 - smoothstep(0.72, 1.0, progress))
	)
	if envelope <= 0.001:
		return
	var snap := ease(smoothstep(0.0, 0.76, progress), 0.32)
	var center := direction * lerpf(23.0, 47.0, snap)
	var pulse := 1.0 + sin(progress * PI * 2.5) * 0.025
	var crescent_size := Vector2(
		lerpf(88.0, 164.0, snap),
		lerpf(148.0, 214.0, snap)
	) * _attack_scale * pulse
	_draw_tile(
		TILE_OUTER_GLOW,
		center - direction * 4.0,
		direction,
		crescent_size * 1.10,
		Color(0.38, 0.72, 1.0, envelope * 0.42),
		deg_to_rad(lerpf(-5.0, 1.0, progress))
	)
	_draw_tile(
		TILE_MOON_CORE,
		center,
		direction,
		crescent_size,
		Color(0.92, 0.98, 1.0, envelope * 0.86),
		deg_to_rad(lerpf(-2.8, 0.8, progress))
	)
	_draw_tile(
		TILE_INNER_CURRENT,
		center + direction * 2.0,
		direction,
		crescent_size * Vector2(1.01, 0.98),
		Color(0.34, 0.80, 1.0, envelope * 0.56),
		deg_to_rad(sin(progress * PI) * 1.8)
	)
	_draw_tile(
		TILE_GROUND_CUT,
		center - direction * 18.0 + direction.orthogonal() * crescent_size.y * 0.39,
		direction,
		Vector2(crescent_size.x * 1.34, crescent_size.y * 0.49),
		Color(0.42, 0.82, 1.0, envelope * 0.52)
	)


func _draw_travel(direction: Vector2) -> void:
	if _travel_progress < TRAVEL_START:
		return
	var progress := clampf(
		(_travel_progress - TRAVEL_START) / (1.0 - TRAVEL_START),
		0.0,
		1.0
	)
	var envelope := (
		smoothstep(0.0, 0.10, progress)
		* (1.0 - smoothstep(0.76, 1.0, progress))
	)
	if envelope <= 0.001:
		return
	var center := _travel_point(_travel_progress)
	var normal := direction.orthogonal()
	var flutter := sin(progress * PI * 2.0)
	var spectacle := float([1.0, 1.05, 1.11, 1.18][_combo_tier])
	var base_size := Vector2(170.0, 218.0) * _attack_scale * spectacle
	var deform := Vector2(
		1.0 + sin(progress * PI) * 0.075,
		1.0 - sin(progress * PI) * 0.035
	)

	for sample_index in range(FLOW_RIBBON_SAMPLES - 1, -1, -1):
		var sample := float(sample_index + 1)
		var lagged_progress := maxf(
			TRAVEL_START,
			_travel_progress - 0.033 * sample
		)
		var ribbon_center := (
			_travel_point(lagged_progress)
			- direction * (13.0 + sample * 10.0)
			+ normal * sin(progress * TAU + sample * 1.9) * sample * 2.4
		)
		_draw_tile(
			TILE_FLOW_RIBBONS,
			ribbon_center,
			direction,
			Vector2(248.0 + sample * 18.0, 142.0 + sample * 8.0)
				* _attack_scale
				* spectacle,
			Color(0.22, 0.58, 1.0, envelope * (0.20 - sample_index * 0.038)),
			deg_to_rad(flutter * (1.4 + sample * 0.3))
		)

	_draw_tile(
		TILE_OUTER_GLOW,
		center - direction * 3.0,
		direction,
		base_size * deform * 1.11,
		Color(0.28, 0.61, 1.0, envelope * 0.47),
		deg_to_rad(-flutter * 1.25)
	)
	_draw_tile(
		TILE_INNER_CURRENT,
		center + direction * (1.5 + flutter * 2.0),
		direction,
		base_size * Vector2(1.025, 0.985),
		Color(0.30, 0.80, 1.0, envelope * 0.68),
		deg_to_rad(flutter * 1.75)
	)
	_draw_tile(
		TILE_MOON_CORE,
		center + direction * 2.0,
		direction,
		base_size * Vector2(0.91, 1.0) * deform,
		Color(0.92, 0.98, 1.0, envelope * 0.88),
		deg_to_rad(-flutter * 0.72)
	)
	_draw_tile(
		TILE_SPARK_DEBRIS,
		center - direction * 42.0,
		direction,
		Vector2(218.0, 174.0) * _attack_scale * spectacle,
		Color(0.34, 0.76, 1.0, envelope * 0.34)
	)


func _draw_impact(direction: Vector2) -> void:
	var progress := _impact_progress
	var contact := ease(minf(1.0, progress * 5.0), 0.24)
	var decay := 1.0 - smoothstep(0.42, 1.0, progress)
	var flash := sin(minf(1.0, progress * 4.4) * PI)
	var normal := direction.orthogonal()
	var center := _target_offset + direction * lerpf(-12.0, 5.0, contact)
	var spectacle := float([1.0, 1.08, 1.17, 1.28][_combo_tier])
	var bloom_size := Vector2(
		lerpf(146.0, 258.0, contact),
		lerpf(188.0, 278.0, contact)
	) * _attack_scale * spectacle
	_draw_tile(
		TILE_CONTACT_BLOOM,
		center,
		direction,
		bloom_size,
		Color(0.76, 0.93, 1.0, maxf(flash * 0.72, decay * 0.46)),
		deg_to_rad(lerpf(-3.0, 1.5, contact))
	)
	_draw_tile(
		TILE_MOON_CORE,
		center + direction * 4.0,
		direction,
		bloom_size * Vector2(0.68, 0.84),
		Color(0.94, 0.99, 1.0, flash * 0.68)
	)
	_draw_tile(
		TILE_DECAY_FRAGMENTS,
		center - direction * (7.0 + progress * 22.0),
		direction,
		bloom_size * (0.86 + progress * 0.30),
		Color(0.30, 0.72, 1.0, decay * 0.64),
		deg_to_rad(progress * 4.0)
	)
	_draw_tile(
		TILE_SPARK_DEBRIS,
		center + direction * progress * 22.0,
		direction,
		Vector2(252.0, 214.0) * _attack_scale * spectacle * (0.84 + progress * 0.36),
		Color(0.50, 0.86, 1.0, decay * 0.62)
	)
	_draw_tile(
		TILE_GROUND_CUT,
		center - direction * 30.0 + normal * bloom_size.y * 0.35,
		direction,
		Vector2(bloom_size.x * 1.18, bloom_size.y * 0.38),
		Color(0.46, 0.84, 1.0, decay * 0.48)
	)


func _draw_tile(
	tile_index: int,
	center: Vector2,
	direction: Vector2,
	size: Vector2,
	color: Color,
	rotation_offset: float = 0.0
) -> void:
	if color.a <= 0.001:
		return
	var cell_size := Vector2(
		float(ATLAS.get_width()) / float(ATLAS_COLUMNS),
		float(ATLAS.get_height()) / float(ATLAS_ROWS)
	)
	var column := tile_index % ATLAS_COLUMNS
	var row := tile_index / ATLAS_COLUMNS
	var source := Rect2(Vector2(float(column), float(row)) * cell_size, cell_size)
	draw_set_transform(center, direction.angle() + rotation_offset, Vector2.ONE)
	draw_texture_rect_region(
		ATLAS,
		Rect2(-size * 0.5, size),
		source,
		color
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _travel_point(progress: float) -> Vector2:
	if progress <= TRAVEL_START:
		return Vector2.ZERO
	var travel_progress := clampf(
		(progress - TRAVEL_START) / (1.0 - TRAVEL_START),
		0.0,
		1.0
	)
	return _target_offset * (1.0 - pow(1.0 - travel_progress, 4.0))
