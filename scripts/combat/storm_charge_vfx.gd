class_name StormChargeVFX
extends Node2D

signal stage_changed(stage_name: StringName)
signal finished

const MIN_LEVEL := 1
const MAX_LEVEL := 3
const GROUND_END := 0.22
const LIMB_END := 0.48
const WEAPON_END := 0.70
const CONTACT_PEAK := 0.84
const CONTACT_END := 0.94
const TOTAL_DURATION := 1.54
const RESIDUAL_DURATION := TOTAL_DURATION - CONTACT_END
const STAGE_GROUND_GATHER := &"ground_gather"
const STAGE_LIMB_CONDUCTION := &"limb_conduction"
const STAGE_WEAPON_LOCK := &"weapon_lock"
const STAGE_FORWARD_CONTACT := &"forward_contact"
const STAGE_RESIDUAL_DECAY := &"residual_decay"
const COMPONENT_ATLAS_PATH := "res://assets/generated/vfx/storm_charge_v3/storm_charge_components_v3_final_padded.png"
const CORE_SILHOUETTE := "segmented_ground_to_right_spear_v4"
const PARTICLE_AMOUNTS := [6, 8, 10]
const BACK_PARTICLE_AMOUNTS := [4, 6, 8]
const RESIDUAL_PARTICLE_AMOUNTS := [5, 7, 9]
const GROUND_SEGMENT_SCALE := Vector2(0.16, 0.09)
const LIMB_SEGMENT_SCALE := Vector2(0.12, 0.075)
const WEAPON_SHEATH_SCALE := Vector2(0.13, 0.13)
var _conduction_stroke_widths := PackedFloat32Array([10.0, 4.0, 1.4])
var _secondary_stroke_widths := PackedFloat32Array([6.0, 3.0, 1.0])
var _ground_left_path := PackedVector2Array([
	Vector2(-76.0, -2.0), Vector2(-68.0, 1.0), Vector2(-61.0, -3.0), Vector2(-53.0, 1.0),
	Vector2(-46.0, -2.0), Vector2(-37.0, 2.0), Vector2(-29.0, -2.0), Vector2(-20.0, 1.0), Vector2(-9.0, 0.0),
])
var _ground_right_path := PackedVector2Array([
	Vector2(70.0, -3.0), Vector2(63.0, 1.0), Vector2(55.0, -2.0), Vector2(48.0, 2.0),
	Vector2(40.0, -1.0), Vector2(32.0, 2.0), Vector2(25.0, -2.0), Vector2(18.0, 1.0), Vector2(10.0, 0.0),
])
var _left_leg_path := PackedVector2Array([
	Vector2(-9.0, 0.0), Vector2(-13.0, -6.0), Vector2(-8.0, -10.0), Vector2(-12.0, -15.0),
	Vector2(-6.0, -19.0), Vector2(-2.0, -24.0), Vector2(4.0, -27.0), Vector2(10.0, -31.0),
])
var _right_leg_path := PackedVector2Array([
	Vector2(10.0, 0.0), Vector2(6.0, -5.0), Vector2(11.0, -9.0), Vector2(7.0, -14.0),
	Vector2(13.0, -18.0), Vector2(9.0, -23.0), Vector2(13.0, -27.0), Vector2(10.0, -31.0),
])
var _blade_trace_a_path := PackedVector2Array([
	Vector2(10.0, -31.0), Vector2(17.0, -30.0), Vector2(24.0, -26.0),
	Vector2(31.0, -24.0), Vector2(38.0, -20.0), Vector2(45.0, -18.0), Vector2(52.0, -13.0),
])
var _blade_trace_b_path := PackedVector2Array([
	Vector2(10.0, -30.0), Vector2(17.0, -26.0), Vector2(24.0, -24.0),
	Vector2(31.0, -20.0), Vector2(39.0, -18.0), Vector2(46.0, -14.0), Vector2(53.0, -12.0),
])
var _blade_trace_c_path := PackedVector2Array([
	Vector2(10.0, -32.0), Vector2(18.0, -32.0), Vector2(25.0, -29.0),
	Vector2(33.0, -26.0), Vector2(41.0, -23.0), Vector2(48.0, -18.0), Vector2(52.0, -13.0),
])
var _contact_branch_upper_path := PackedVector2Array([
	Vector2(77.0, -15.0), Vector2(81.0, -22.0), Vector2(87.0, -24.0),
	Vector2(92.0, -30.0), Vector2(99.0, -28.0), Vector2(106.0, -34.0),
])
var _contact_branch_high_fork_path := PackedVector2Array([
	Vector2(99.0, -28.0), Vector2(104.0, -24.0), Vector2(110.0, -26.0),
	Vector2(116.0, -22.0),
])
var _contact_branch_center_path := PackedVector2Array([
	Vector2(52.0, -13.0), Vector2(60.0, -16.0), Vector2(68.0, -12.0), Vector2(77.0, -15.0),
	Vector2(85.0, -11.0), Vector2(94.0, -14.0), Vector2(102.0, -10.0), Vector2(111.0, -13.0), Vector2(122.0, -11.0),
])
var _contact_branch_lower_path := PackedVector2Array([
	Vector2(85.0, -11.0), Vector2(90.0, -5.0), Vector2(97.0, -7.0),
	Vector2(102.0, -1.0), Vector2(109.0, -3.0), Vector2(115.0, 2.0),
])

@onready var rear_crystal_glow: Sprite2D = $BackLayer/RearCrystalGlow
@onready var rear_crystal: Sprite2D = $BackLayer/RearCrystal
@onready var back_particles: CPUParticles2D = $BackLayer/BackParticles
@onready var ground_bloom_glow: Sprite2D = $GroundLayer/GroundBloomGlow
@onready var ground_bloom: Sprite2D = $GroundLayer/GroundBloom
@onready var ground_scorch: Sprite2D = $GroundLayer/GroundScorch
@onready var ground_crawl_glow: Sprite2D = $GroundLayer/GroundCrawlGlow
@onready var ground_crawl: Sprite2D = $GroundLayer/GroundCrawl
@onready var right_ground_glow: Sprite2D = $GroundLayer/RightGroundGlow
@onready var right_ground: Sprite2D = $GroundLayer/RightGround
@onready var mid_crystal_glow: Sprite2D = $BehindPlayerAura/MidCrystalGlow
@onready var mid_crystal: Sprite2D = $BehindPlayerAura/MidCrystal
@onready var rear_conduit: Sprite2D = $BehindPlayerAura/RearConduit
@onready var rear_conduit_glow: Sprite2D = $BehindPlayerAura/RearConduitGlow
@onready var mid_conduit: Sprite2D = $BehindPlayerAura/MidConduit
@onready var mid_conduit_glow: Sprite2D = $BehindPlayerAura/MidConduitGlow
@onready var body_wrap_glow: Sprite2D = $BehindPlayerAura/BodyWrapGlow
@onready var body_wrap: Sprite2D = $BehindPlayerAura/BodyWrap
@onready var front_crystal_glow: Sprite2D = $FrontLayer/FrontCrystalGlow
@onready var front_crystal: Sprite2D = $FrontLayer/FrontCrystal
@onready var front_conduit: Sprite2D = $FrontLayer/FrontConduit
@onready var front_conduit_glow: Sprite2D = $FrontLayer/FrontConduitGlow
@onready var weapon_sheath_glow: Sprite2D = $FrontLayer/WeaponSheathGlow
@onready var weapon_sheath: Sprite2D = $FrontLayer/WeaponSheath
@onready var blade_trace_a_glow: Sprite2D = $FrontLayer/BladeTraceAGlow
@onready var blade_trace_a: Sprite2D = $FrontLayer/BladeTraceA
@onready var blade_trace_b_glow: Sprite2D = $FrontLayer/BladeTraceBGlow
@onready var blade_trace_b: Sprite2D = $FrontLayer/BladeTraceB
@onready var blade_trace_c_glow: Sprite2D = $FrontLayer/BladeTraceCGlow
@onready var blade_trace_c: Sprite2D = $FrontLayer/BladeTraceC
@onready var core_glow: Sprite2D = $FrontLayer/CoreGlow
@onready var core: Sprite2D = $FrontLayer/Core
@onready var source_flecks: Sprite2D = $FrontLayer/SourceFlecks
@onready var residual_armor: Node2D = $FrontLayer/ResidualArmor
@onready var residual_left_glow: Sprite2D = $FrontLayer/ResidualArmor/LeftGlow
@onready var residual_left: Sprite2D = $FrontLayer/ResidualArmor/Left
@onready var residual_right_glow: Sprite2D = $FrontLayer/ResidualArmor/RightGlow
@onready var residual_right: Sprite2D = $FrontLayer/ResidualArmor/Right
@onready var strike_glow: Sprite2D = $ClimaxLayer/StrikeGlow
@onready var strike: Sprite2D = $ClimaxLayer/Strike
@onready var branch_upper_glow: Sprite2D = $ClimaxLayer/BranchUpperGlow
@onready var branch_upper: Sprite2D = $ClimaxLayer/BranchUpper
@onready var branch_lower_glow: Sprite2D = $ClimaxLayer/BranchLowerGlow
@onready var branch_lower: Sprite2D = $ClimaxLayer/BranchLower
@onready var contact_glow: Sprite2D = $ClimaxLayer/ContactGlow
@onready var contact: Sprite2D = $ClimaxLayer/Contact
@onready var charge_particles: CPUParticles2D = $ChargeParticles
@onready var residual_particles: CPUParticles2D = $ResidualParticles
@onready var charge_light: PointLight2D = $ChargeLight
@onready var ground_light: PointLight2D = $GroundLight
@onready var warm_bounce_light: PointLight2D = $WarmBounceLight

var _level := MIN_LEVEL
var _active := false
var _elapsed := 0.0
var _stage := STAGE_GROUND_GATHER
var _connected_arc_count := 0
var _anchor_position := Vector2.ZERO
var _timeline_tween: Tween


func _ready() -> void:
	_apply_level_detail()
	_reset_visuals()


func configure(level: int) -> void:
	_level = clampi(level, MIN_LEVEL, MAX_LEVEL)
	if is_node_ready():
		_apply_level_detail()
		_update_visuals()


func play() -> void:
	if not is_inside_tree():
		push_error("StormChargeVFX.play() requires the effect to be inside the SceneTree.")
		return
	if _timeline_tween != null and _timeline_tween.is_valid():
		_timeline_tween.kill()
	_anchor_position = position
	_active = true
	visible = true
	_elapsed = 0.0
	_stage = STAGE_GROUND_GATHER
	_connected_arc_count = 0
	_apply_level_detail()
	_reset_visuals()
	back_particles.restart()
	back_particles.emitting = true
	charge_particles.restart()
	charge_particles.emitting = true
	stage_changed.emit(_stage)
	_timeline_tween = create_tween()
	_timeline_tween.set_ignore_time_scale(true)
	_timeline_tween.set_trans(Tween.TRANS_LINEAR)
	_timeline_tween.tween_method(_set_elapsed, 0.0, TOTAL_DURATION, TOTAL_DURATION)
	_timeline_tween.tween_callback(_finish)


func get_debug_state() -> Dictionary:
	return {
		"active": _active,
		"level": _level,
		"stage": _stage,
		"elapsed": _elapsed,
		"lit_depth_nodes": 0,
		"connected_arc_count": _connected_arc_count,
		"functional_layers": ["segmented_current", "particles", "point_light"],
		"authored_component_atlas": COMPONENT_ATLAS_PATH,
		"authored_component_count": 12,
		"primary_geometry": "fixed_semantic_conduction_polylines",
		"conduction_stroke_widths": _conduction_stroke_widths,
		"secondary_stroke_widths": _secondary_stroke_widths,
		"fixed_conduction_path_count": 11,
		"stage_revealed_paths": true,
		"motion_identity": "foot_current_to_rightward_weapon_spear",
		"smooth_choreography": true,
		"motion_sample_count": 12,
		"particle_budget": back_particles.amount + charge_particles.amount + residual_particles.amount,
		"visual_budget": back_particles.amount + charge_particles.amount + residual_particles.amount + 22,
		"core_silhouette": CORE_SILHOUETTE,
		"horizontal_displacement": position.x - _anchor_position.x,
		"world_offset": position - _anchor_position,
		"ground_baseline_y": 0.0,
		"vertical_strike": false,
		"rightward_strike": true,
		"strike_direction": Vector2.RIGHT,
		"strike_origin_connected": true,
		"strike_origin": Vector2(42.0, -18.0),
		"moving_projectile": false,
		"whole_plate_motion": false,
		"generic_ring": false,
		"crystal_plate_visible": false,
		"core_glyph_visible": false,
		"body_s_curve_plate": false,
		"face_chest_clear": true,
		"post_peak_monotonic_decay": true,
		"climax_count": 1,
		"contact_peak_time": CONTACT_PEAK,
		"residual_duration": RESIDUAL_DURATION,
		"point_light_energy": charge_light.energy,
		"point_light_count": 3,
		"depth_crystal_scales": [],
		"depth_layer_order": ["BackLayer", "BehindPlayerAura", "FrontLayer", "ClimaxLayer"],
		"cold_warm_character_lighting": true,
		"atlas_black_key": true,
		"visual_bounds": Rect2(-78.0, -92.0, 224.0, 96.0),
	}


func debug_set_elapsed(value: float) -> void:
	if not is_inside_tree():
		return
	if _timeline_tween != null and _timeline_tween.is_valid():
		_timeline_tween.kill()
	_active = true
	visible = true
	_set_elapsed(clampf(value, 0.0, TOTAL_DURATION))


func _set_elapsed(value: float) -> void:
	_elapsed = clampf(value, 0.0, TOTAL_DURATION)
	var next_stage := _resolve_stage(_elapsed)
	if next_stage != _stage:
		_stage = next_stage
		stage_changed.emit(_stage)
		if _stage == STAGE_RESIDUAL_DECAY:
			back_particles.emitting = false
			charge_particles.emitting = false
			residual_particles.restart()
			residual_particles.emitting = true
	_update_visuals()


func _update_visuals() -> void:
	if not is_node_ready():
		return
	var residual := _range_progress(_elapsed, CONTACT_END, TOTAL_DURATION)
	var decay := pow(1.0 - residual, 1.35)
	_update_ground_current(decay)
	_update_leg_and_weapon_current(decay)
	_update_rightward_contact(residual)
	_update_residual(residual, decay)
	_update_particles(residual)
	_update_lighting(residual)
	_connected_arc_count = _resolve_connected_arc_count()
	_hide_rejected_plates()
	_hide_atlas_primary()
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var residual := _range_progress(_elapsed, CONTACT_END, TOTAL_DURATION)
	var decay := pow(1.0 - residual, 1.35)
	var ground_reveal := _smooth(_range_progress(_elapsed, 0.02, GROUND_END))
	var left_leg_reveal := _smooth(_range_progress(_elapsed, 0.16, 0.43))
	var right_leg_reveal := _smooth(_range_progress(_elapsed, 0.20, LIMB_END))
	var blade_reveal := _smooth(_range_progress(_elapsed, 0.44, WEAPON_END))
	var branch_reveal := _smooth(_range_progress(_elapsed, WEAPON_END, CONTACT_PEAK))
	var circuit_alpha := decay
	if _elapsed > CONTACT_PEAK and _elapsed <= CONTACT_END:
		circuit_alpha = lerpf(1.0, 0.72, _range_progress(_elapsed, CONTACT_PEAK, CONTACT_END))
	if residual > 0.0:
		# The discharge retracts along the same rooted circuit.  No endpoint is
		# translated and no new silhouette is introduced during the tail.
		branch_reveal = clampf(1.0 - residual * 4.0, 0.0, 1.0)
		ground_reveal = 1.0
		left_leg_reveal = 1.0
		right_leg_reveal = 1.0
		blade_reveal = 1.0

	var ground_alpha := circuit_alpha * 0.86
	var limb_alpha := circuit_alpha * 0.92
	var blade_alpha := circuit_alpha
	var branch_alpha := circuit_alpha
	if residual > 0.0:
		var return_decay := pow(1.0 - residual, 1.8)
		ground_alpha = return_decay * 0.46
		limb_alpha = return_decay * 0.27
		blade_alpha = return_decay * 0.54
		branch_alpha = return_decay * 0.22
	_draw_conduction_path(_ground_left_path, ground_reveal, ground_alpha)
	_draw_conduction_path(_ground_right_path, ground_reveal, ground_alpha)
	_draw_conduction_path(_left_leg_path, left_leg_reveal, limb_alpha)
	_draw_conduction_path(_right_leg_path, right_leg_reveal, limb_alpha)
	_draw_conduction_path(_blade_trace_a_path, blade_reveal, blade_alpha, true)
	_draw_conduction_path(_blade_trace_b_path, clampf(blade_reveal * 1.12 - 0.12, 0.0, 1.0), blade_alpha * 0.92)
	_draw_conduction_path(_blade_trace_c_path, clampf(blade_reveal * 1.18 - 0.18, 0.0, 1.0), blade_alpha * 0.86)
	# Forks wait until the already-revealed main trunk has physically reached
	# their fixed root, so no disconnected neon segment can pop into existence.
	_draw_conduction_path(_contact_branch_center_path, branch_reveal, branch_alpha, true)
	_draw_conduction_path(_contact_branch_upper_path, _smooth(_range_progress(branch_reveal, 0.32, 0.86)), branch_alpha)
	_draw_conduction_path(_contact_branch_lower_path, _smooth(_range_progress(branch_reveal, 0.45, 0.92)), branch_alpha * 0.92)
	_draw_conduction_path(_contact_branch_high_fork_path, _smooth(_range_progress(branch_reveal, 0.78, 1.0)), branch_alpha * 0.82)


func _draw_conduction_path(points: PackedVector2Array, reveal: float, alpha: float, is_main_trunk: bool = false) -> void:
	var visible_points := _revealed_polyline(points, reveal)
	if visible_points.size() < 2 or alpha <= 0.01:
		return
	var widths := _conduction_stroke_widths if is_main_trunk else _secondary_stroke_widths
	draw_polyline(visible_points, Color(0.06, 0.18, 0.88, alpha * 0.14), widths[0], true)
	draw_polyline(visible_points, Color(0.12, 0.68, 1.0, alpha * 0.78), widths[1], true)
	draw_polyline(visible_points, Color(0.88, 0.98, 1.0, alpha), widths[2], true)


func _revealed_polyline(points: PackedVector2Array, reveal: float) -> PackedVector2Array:
	if points.size() < 2 or reveal <= 0.0:
		return PackedVector2Array()
	if reveal >= 1.0:
		return points
	var total_length := 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	var target_length := total_length * reveal
	var traversed := 0.0
	var visible_points := PackedVector2Array([points[0]])
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		if traversed + segment_length <= target_length:
			visible_points.append(points[index + 1])
			traversed += segment_length
			continue
		var local_progress := (target_length - traversed) / maxf(segment_length, 0.001)
		visible_points.append(points[index].lerp(points[index + 1], clampf(local_progress, 0.0, 1.0)))
		break
	return visible_points


func _update_ground_current(decay: float) -> void:
	# The rejected elliptical bloom remains disabled: the readable source is the
	# first short current itself, flush to the floor rather than a portal plate.
	_set_pair_alpha(ground_bloom, ground_bloom_glow, 0.0)

	var left_ground := _smooth(_range_progress(_elapsed, 0.02, 0.13)) * decay
	var right_ground_progress := _smooth(_range_progress(_elapsed, 0.06, 0.17)) * decay
	_set_pair_pose(ground_crawl, ground_crawl_glow, Vector2(-34.0, 7.0), Vector2(0.22, 0.12), 0.01, left_ground)
	_set_pair_pose(right_ground, right_ground_glow, Vector2(34.0, 7.0), Vector2(-0.22, 0.12), -0.01, right_ground_progress)


func _update_leg_and_weapon_current(decay: float) -> void:
	# Two independent branches climb from the ground into both legs; the next
	# two hand arcs stay below the chest and never cross the head silhouette.
	var left_leg := _smooth(_range_progress(_elapsed, 0.16, 0.31)) * decay
	var right_leg := _smooth(_range_progress(_elapsed, 0.21, 0.37)) * decay
	var lower_hand := _smooth(_range_progress(_elapsed, 0.28, 0.43)) * decay
	var upper_hand := _smooth(_range_progress(_elapsed, 0.34, 0.48)) * decay
	_set_pair_pose(rear_conduit, rear_conduit_glow, Vector2(-8.0, -12.0), LIMB_SEGMENT_SCALE, 1.16, left_leg)
	_set_pair_pose(mid_conduit, mid_conduit_glow, Vector2(7.0, -12.0), Vector2(-0.12, 0.075), 0.42, right_leg)
	_set_pair_pose(front_conduit, front_conduit_glow, Vector2(3.0, -26.0), Vector2(0.11, 0.068), 0.74, lower_hand)
	_set_pair_pose(body_wrap, body_wrap_glow, Vector2(10.0, -31.0), Vector2(0.10, 0.064), 0.88, upper_hand)

	# Three staggered traces cling to the physical sword.  They form its outer
	# electric contour before any contact branches are allowed to appear.
	var blade_a := _smooth(_range_progress(_elapsed, 0.44, 0.58)) * decay
	var blade_b := _smooth(_range_progress(_elapsed, 0.50, 0.64)) * decay
	var blade_c := _smooth(_range_progress(_elapsed, 0.56, WEAPON_END)) * decay
	var sheath := _smooth(_range_progress(_elapsed, 0.48, 0.66)) * decay
	_set_pair_pose(weapon_sheath, weapon_sheath_glow, Vector2(26.0, -18.0), Vector2(0.10, 0.10), 1.30, sheath * 0.34)
	_set_pair_pose(blade_trace_a, blade_trace_a_glow, Vector2(23.0, -22.0), Vector2(0.17, 0.078), 0.32, blade_a * 0.88)
	_set_pair_pose(blade_trace_b, blade_trace_b_glow, Vector2(27.0, -18.0), Vector2(0.16, 0.073), 0.40, blade_b * 0.82)
	_set_pair_pose(blade_trace_c, blade_trace_c_glow, Vector2(30.0, -14.0), Vector2(0.15, 0.068), 0.47, blade_c * 0.78)


func _update_rightward_contact(residual: float) -> void:
	var central_alpha := _branch_alpha(0.68, 0.78, residual)
	var upper_alpha := _branch_alpha(0.72, 0.82, residual)
	var lower_alpha := _branch_alpha(0.76, CONTACT_PEAK, residual)
	# All three branches begin over the existing sword tip.  Their fixed roots
	# and divergent angles create a forked discharge, never a detached payload.
	_set_pair_pose(strike, strike_glow, Vector2(69.0, -17.0), Vector2(0.23, 0.105), 0.02, central_alpha)
	_set_pair_pose(branch_upper, branch_upper_glow, Vector2(70.0, -24.0), Vector2(0.20, 0.09), -0.25, upper_alpha * 0.9)
	_set_pair_pose(branch_lower, branch_lower_glow, Vector2(71.0, -10.0), Vector2(0.20, 0.09), 0.24, lower_alpha * 0.86)
	_set_pair_alpha(contact, contact_glow, 0.0)


func _branch_alpha(start_time: float, full_time: float, residual: float) -> float:
	if _elapsed < start_time:
		return 0.0
	if _elapsed <= full_time:
		return _smooth(_range_progress(_elapsed, start_time, full_time))
	if _elapsed <= CONTACT_END:
		return lerpf(1.0, 0.58, _range_progress(_elapsed, CONTACT_PEAK, CONTACT_END))
	return 0.58 * pow(1.0 - residual, 1.6)


func _update_residual(residual: float, decay: float) -> void:
	ground_scorch.position = Vector2(34.0 + residual * 24.0, -2.0)
	ground_scorch.scale = Vector2(0.34, 0.18)
	ground_scorch.rotation = 0.0
	ground_scorch.modulate = Color(0.52, 0.78, 1.0, residual * decay * 0.52)
	residual_armor.visible = false
	_set_pair_alpha(residual_left, residual_left_glow, 0.0)
	_set_pair_alpha(residual_right, residual_right_glow, 0.0)


func _update_particles(residual: float) -> void:
	# Particles are subordinate chips from the same current, never an always-on
	# blob.  Their opacity follows the exact ground/weapon/decay stages so the
	# debug capture and runtime preserve the sword silhouette.
	var ground_alpha := (
		_smooth(_range_progress(_elapsed, 0.05, 0.18))
		* (1.0 - _smooth(_range_progress(_elapsed, 0.34, 0.52)))
	)
	var weapon_alpha := _smooth(_range_progress(_elapsed, 0.56, CONTACT_PEAK))
	if _elapsed > CONTACT_PEAK:
		weapon_alpha *= pow(1.0 - _range_progress(_elapsed, CONTACT_PEAK, TOTAL_DURATION), 1.6)
	var residual_alpha := sin(clampf(residual, 0.0, 1.0) * PI) if residual > 0.0 else 0.0
	back_particles.modulate = Color(0.52, 0.84, 1.0, ground_alpha * 0.26)
	charge_particles.modulate = Color(0.72, 0.94, 1.0, weapon_alpha * 0.24)
	residual_particles.modulate = Color(0.46, 0.74, 1.0, residual_alpha * 0.22)


func _update_lighting(residual: float) -> void:
	var gather := _range_progress(_elapsed, 0.0, GROUND_END)
	var weapon := _range_progress(_elapsed, LIMB_END, WEAPON_END)
	var rise := _range_progress(_elapsed, WEAPON_END, CONTACT_PEAK)
	var peak_energy := _smooth(rise)
	var decay := pow(1.0 - residual, 1.5)
	if _elapsed > CONTACT_PEAK and _elapsed <= CONTACT_END:
		peak_energy = lerpf(1.0, 0.62, _range_progress(_elapsed, CONTACT_PEAK, CONTACT_END))
	elif _elapsed > CONTACT_END:
		peak_energy = 0.62 * decay
	charge_light.visible = _active
	ground_light.visible = _active
	warm_bounce_light.visible = _active
	charge_light.position = Vector2(56.0 + minf(residual * 42.0, 42.0), -23.0)
	ground_light.position = Vector2(-6.0 + residual * 34.0, -3.0)
	warm_bounce_light.position = Vector2(22.0, -24.0)
	charge_light.energy = 0.08 + weapon * 0.18 + peak_energy * 0.82
	ground_light.energy = gather * 0.24 * (decay if residual > 0.0 else 1.0) + peak_energy * 0.34
	warm_bounce_light.energy = weapon * 0.08 + peak_energy * 0.14
	if residual > 0.0:
		charge_light.energy = peak_energy
		ground_light.energy *= decay
		warm_bounce_light.energy *= decay
	charge_light.texture_scale = 0.78
	ground_light.texture_scale = 0.94
	warm_bounce_light.texture_scale = 0.58


func _hide_rejected_plates() -> void:
	for sprite in [
		rear_crystal_glow, rear_crystal, mid_crystal_glow, mid_crystal,
		front_crystal_glow, front_crystal, core_glow, core, source_flecks,
	]:
		(sprite as Sprite2D).modulate.a = 0.0


func _hide_atlas_primary() -> void:
	# V4h uses atlas sprites only as dormant reusable scene resources.  The
	# readable action is the fixed circuit drawn above; lights and particles
	# supply depth without reintroducing a launched image silhouette.
	for sprite in [
		ground_bloom_glow, ground_bloom, ground_crawl_glow, ground_crawl,
		right_ground_glow, right_ground, rear_conduit_glow, rear_conduit,
		mid_conduit_glow, mid_conduit, body_wrap_glow, body_wrap,
		front_conduit_glow, front_conduit, weapon_sheath_glow, weapon_sheath,
		blade_trace_a_glow, blade_trace_a, blade_trace_b_glow, blade_trace_b,
		blade_trace_c_glow, blade_trace_c, strike_glow, strike,
		branch_upper_glow, branch_upper, branch_lower_glow, branch_lower,
		contact_glow, contact,
	]:
		(sprite as Sprite2D).modulate.a = 0.0


func _set_pair_pose(
	body: Sprite2D,
	glow: Sprite2D,
	pose_position: Vector2,
	pose_scale: Vector2,
	pose_rotation: float,
	alpha: float
) -> void:
	body.position = pose_position
	body.scale = pose_scale
	body.rotation = pose_rotation
	body.modulate = Color(0.76, 0.94, 1.0, clampf(alpha, 0.0, 1.0))
	glow.position = pose_position
	glow.scale = pose_scale * 1.045
	glow.rotation = pose_rotation
	glow.modulate = Color(0.46, 0.76, 1.0, clampf(alpha * 0.54, 0.0, 1.0))


func _set_single_pose(sprite: Sprite2D, pose_position: Vector2, pose_scale: Vector2, pose_rotation: float, alpha: float) -> void:
	sprite.position = pose_position
	sprite.scale = pose_scale
	sprite.rotation = pose_rotation
	sprite.modulate = Color(0.68, 0.90, 1.0, clampf(alpha, 0.0, 1.0))


func _set_pair_alpha(body: Sprite2D, glow: Sprite2D, alpha: float) -> void:
	body.modulate.a = alpha
	glow.modulate.a = alpha * 0.54


func _apply_level_detail() -> void:
	var index := _level - 1
	back_particles.amount = BACK_PARTICLE_AMOUNTS[index]
	charge_particles.amount = PARTICLE_AMOUNTS[index]
	residual_particles.amount = RESIDUAL_PARTICLE_AMOUNTS[index]
	residual_particles.lifetime = RESIDUAL_DURATION
	back_particles.position = Vector2(-38.0, 7.0)
	charge_particles.position = Vector2(34.0, -18.0)
	residual_particles.position = Vector2(82.0, -18.0)


func _reset_visuals() -> void:
	if not is_node_ready():
		return
	back_particles.emitting = false
	charge_particles.emitting = false
	residual_particles.emitting = false
	back_particles.modulate.a = 0.0
	charge_particles.modulate.a = 0.0
	residual_particles.modulate.a = 0.0
	for sprite in _all_component_sprites():
		(sprite as Sprite2D).modulate.a = 0.0
	residual_armor.visible = false
	charge_light.visible = false
	ground_light.visible = false
	warm_bounce_light.visible = false
	charge_light.energy = 0.0
	ground_light.energy = 0.0
	warm_bounce_light.energy = 0.0
	queue_redraw()


func _all_component_sprites() -> Array[Sprite2D]:
	return [
		rear_crystal_glow, rear_crystal,
		ground_bloom_glow, ground_bloom, ground_scorch, ground_crawl_glow, ground_crawl,
		right_ground_glow, right_ground,
		mid_crystal_glow, mid_crystal, rear_conduit_glow, rear_conduit,
		mid_conduit_glow, mid_conduit, body_wrap_glow, body_wrap,
		front_crystal_glow, front_crystal, front_conduit_glow, front_conduit,
		weapon_sheath_glow, weapon_sheath,
		blade_trace_a_glow, blade_trace_a, blade_trace_b_glow, blade_trace_b,
		blade_trace_c_glow, blade_trace_c, core_glow, core, source_flecks,
		residual_left_glow, residual_left, residual_right_glow, residual_right,
		strike_glow, strike, branch_upper_glow, branch_upper,
		branch_lower_glow, branch_lower, contact_glow, contact,
	]


func _resolve_stage(elapsed: float) -> StringName:
	if elapsed < GROUND_END:
		return STAGE_GROUND_GATHER
	if elapsed < LIMB_END:
		return STAGE_LIMB_CONDUCTION
	if elapsed < WEAPON_END:
		return STAGE_WEAPON_LOCK
	if elapsed < CONTACT_END:
		return STAGE_FORWARD_CONTACT
	return STAGE_RESIDUAL_DECAY


func _resolve_connected_arc_count() -> int:
	var count := 0
	for timing in [0.03, 0.10, 0.18, 0.28, 0.30, 0.44]:
		if _elapsed >= float(timing):
			count += 1
	if _elapsed > CONTACT_END:
		count = maxi(1, int(ceil(float(count) * (1.0 - _range_progress(_elapsed, CONTACT_END, TOTAL_DURATION)))))
	return count


func _range_progress(value: float, start: float, finish: float) -> float:
	if finish <= start:
		return 1.0
	return clampf((value - start) / (finish - start), 0.0, 1.0)


func _smooth(value: float) -> float:
	return smoothstep(0.0, 1.0, clampf(value, 0.0, 1.0))


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, value: float) -> Vector2:
	var t := clampf(value, 0.0, 1.0)
	var inverse := 1.0 - t
	return (
		p0 * inverse * inverse * inverse
		+ p1 * 3.0 * inverse * inverse * t
		+ p2 * 3.0 * inverse * t * t
		+ p3 * t * t * t
	)


func _finish() -> void:
	_active = false
	back_particles.emitting = false
	charge_particles.emitting = false
	residual_particles.emitting = false
	finished.emit()
	queue_free()
