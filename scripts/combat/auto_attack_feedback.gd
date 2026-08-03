class_name AutoAttackFeedback
extends Node2D

const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

signal finished
signal impact_reached(did_hit: bool, combo_tier: int)

const ANTICIPATION_DURATION := 0.042
const TRAVEL_DURATION := 0.105
const IMPACT_DURATION := 0.18
const RELEASE_TEXTURE: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_release_sheet_v2.png"
)
const RELEASE_MASK: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_release_mask_v2.png"
)
const TRAVEL_TEXTURE: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_travel_sheet_v2.png"
)
const TRAVEL_MASK: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_travel_mask_v2.png"
)
const IMPACT_TEXTURE: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_impact_sheet_v2.png"
)
const IMPACT_MASK: Texture2D = preload(
	"res://assets/generated/vfx/basic_attack_impact_mask_v2.png"
)
const GENERATED_FRAME_COUNT := 8
const GENERATED_FRAME_SIZE := Vector2(320.0, 192.0)
const LAUNCH_PROGRESS := 0.18
const RELEASE_TRAVEL_END := 0.38
const TRAVEL_VISUAL_START := LAUNCH_PROGRESS
const TEMPORAL_AFTERIMAGE_SAMPLE_COUNT := 4
const RELEASE_SHEAR_SAMPLE_COUNT := 3
const IMPACT_ECHO_COUNT := 2
const CONTACT_FLASH_WINDOW := 0.045
const TRAVEL_HISTORY_LAGS := [0.026, 0.052, 0.084, 0.122]
# Compatibility aliases for retired helpers kept below the active generated path.
const ENERGY_BLADE_TEXTURE := TRAVEL_TEXTURE
const ENERGY_BLADE_AURA_TEXTURE := TRAVEL_MASK
const ENERGY_BLADE_FRAME_SIZE := GENERATED_FRAME_SIZE
const RELEASE_ARC_COUNT := 4
const DIRECTIONAL_IMPACT_SPIKE_COUNT := 9
const ATTACK_PRESENTATION_STAGES: Array[StringName] = [
	&"weapon_release",
	&"blade_travel",
	&"directional_impact",
]
const MODULAR_PARTS: Array[StringName] = [
	&"core_blade",
	&"crescent_edge",
	&"afterimage",
	&"shards",
	&"impact_wedge",
]
const PREMIUM_CRESCENT_LAYERS: Array[StringName] = [
	&"outer_glow",
	&"moon_core",
	&"inner_current",
	&"flow_ribbons",
	&"ground_cut",
	&"spark_debris",
	&"contact_bloom",
]

@onready var damage_label: Label = $DamageLabel
@onready var combo_label: Label = $ComboLabel
@onready var premium_crescent_layer: Node2D = $PremiumCrescentLayer

var _target_offset := Vector2.ZERO
var _travel_progress := 0.0
var _impact_progress := 0.0
var _accent := Color.WHITE
var _attack_size_multiplier := 1.0
var _visual_colors: Array[Color] = []
var _visual_elements: Array[StringName] = []
var _stack_count := 0
var _lifesteal := false
var _direction_index := 0
var _direction_count := 1
var _spread_degrees := 0.0
var _did_hit := false
var _elemental_aura: Node2D
var _combo_tier := 0
var _suppress_attack_geometry := false


func play(
	origin: Vector2,
	target_position: Vector2,
	damage: int,
	combo_count: int,
	combo_damage_bonus: int = 0,
	critical: bool = false,
	projectile_speed_multiplier: float = 1.0,
	attack_size_multiplier: float = 1.0,
	visual_profile: Dictionary = {}
) -> void:
	if bool(visual_profile.get("local_coordinates", false)):
		position = origin
	else:
		global_position = origin
	_target_offset = target_position - origin
	_stack_count = maxi(0, int(visual_profile.get("stack_count", 0)))
	_lifesteal = bool(visual_profile.get("lifesteal", false))
	_direction_count = maxi(1, int(visual_profile.get("direction_count", 1)))
	_direction_index = clampi(
		int(visual_profile.get("direction_index", 0)),
		0,
		_direction_count - 1
	)
	_spread_degrees = clampf(float(visual_profile.get("spread_degrees", 0.0)), 0.0, 360.0)
	_did_hit = damage > 0
	_combo_tier = clampi(combo_count / 3, 0, 3)
	_suppress_attack_geometry = bool(visual_profile.get("finisher", false))
	_visual_elements = _normalize_elements(visual_profile.get("elements", []) as Array)
	_visual_colors = _colors_for_elements(_visual_elements)
	# Sword energy keeps a white core. Elements remain independent silhouette layers.
	_accent = Color.WHITE
	_attack_size_multiplier = ATTACK_GEOMETRY.resolve_size_scale(
		attack_size_multiplier,
		_stack_count
	)
	premium_crescent_layer.call(
		"configure",
		_target_offset,
		_attack_size_multiplier,
		_combo_tier
	)
	premium_crescent_layer.visible = not _suppress_attack_geometry
	premium_crescent_layer.call("set_progress", _travel_progress, _impact_progress)
	damage_label.text = "%s%d" % ["CRIT  -" if critical else "-", maxi(0, damage)]
	damage_label.add_theme_color_override("font_color", _accent)
	combo_label.text = (
		String(visual_profile.get("finisher_name", "FINISHER"))
		if bool(visual_profile.get("finisher", false))
		else (
			"COMBO ×%d   POWER +%d" % [combo_count, maxi(0, combo_damage_bonus)]
			if combo_count > 0
			else "AUTO ATTACK"
		)
	)
	combo_label.add_theme_color_override("font_color", _accent.lightened(0.18))
	damage_label.position = _target_offset + Vector2(-42.0, -82.0)
	combo_label.position = _target_offset + Vector2(-70.0, -58.0)
	damage_label.visible = false
	combo_label.visible = false
	queue_redraw()

	var speed_scale := maxf(0.80, projectile_speed_multiplier)
	var travel_tween := create_tween()
	travel_tween.tween_method(
		_set_travel_progress,
		0.0,
		LAUNCH_PROGRESS,
		ANTICIPATION_DURATION / speed_scale
	)
	travel_tween.tween_method(
		_set_travel_progress,
		LAUNCH_PROGRESS,
		1.0,
		TRAVEL_DURATION / speed_scale
	)
	travel_tween.tween_callback(_show_impact)
	travel_tween.tween_method(
		_set_impact_progress,
		0.0,
		1.0,
		IMPACT_DURATION
	)
	travel_tween.tween_callback(_finish)


func get_combo_text() -> String:
	return combo_label.text if combo_label != null else ""


func get_damage_text() -> String:
	return damage_label.text if damage_label != null else ""


func get_visual_layer_count() -> int:
	if _suppress_attack_geometry:
		return 0
	return _visual_colors.size() + (1 if _lifesteal else 0)


func is_attack_geometry_suppressed() -> bool:
	return _suppress_attack_geometry


func get_attack_scale() -> float:
	return _attack_size_multiplier


func get_direction_count() -> int:
	return _direction_count


func get_spread_degrees() -> float:
	return _spread_degrees


func get_combo_visual_tier() -> int:
	return _combo_tier


func get_direction_angle_degrees() -> float:
	return _direction_angle_degrees()


func get_travel_offset() -> Vector2:
	return _target_offset


func get_sword_wave_core_color() -> Color:
	return _accent


func get_active_elements() -> Array[StringName]:
	return _visual_elements.duplicate()


func get_element_emphasis_pass_count() -> int:
	return _visual_elements.size() * 2


func get_combo_emphasis_pass_count() -> int:
	return _combo_tier * 2 + (1 if _combo_tier >= 3 else 0)


func get_energy_blade_frame_count() -> int:
	return GENERATED_FRAME_COUNT


func get_attack_presentation_stages() -> Array[StringName]:
	return ATTACK_PRESENTATION_STAGES.duplicate()


func get_modular_part_names() -> Array[StringName]:
	return MODULAR_PARTS.duplicate()


func get_travel_duration() -> float:
	return ANTICIPATION_DURATION + TRAVEL_DURATION


func get_impact_duration() -> float:
	return IMPACT_DURATION


func get_motion_profile() -> StringName:
	return &"slash_shockwave"


func get_animation_quality_profile() -> StringName:
	return &"premium_flowing_crescent"


func get_premium_crescent_layer_names() -> Array[StringName]:
	return PREMIUM_CRESCENT_LAYERS.duplicate()


func get_flow_ribbon_sample_count() -> int:
	return int(premium_crescent_layer.call("get_flow_ribbon_sample_count"))


func get_crescent_deformation_sample_count() -> int:
	return int(premium_crescent_layer.call("get_deformation_sample_count"))


func get_temporal_afterimage_sample_count() -> int:
	return TEMPORAL_AFTERIMAGE_SAMPLE_COUNT


func get_frame_interpolation_sample_count() -> int:
	return 2


func get_travel_pose_scale(progress: float) -> Vector2:
	return _travel_pose_scale(clampf(progress, 0.0, 1.0))


func get_impact_echo_count() -> int:
	return IMPACT_ECHO_COUNT


func get_contact_flash_window() -> float:
	return CONTACT_FLASH_WINDOW


func get_travel_distance_ratio_at_progress(progress: float) -> float:
	if _target_offset.is_zero_approx():
		return 0.0
	return _travel_point(progress).length() / _target_offset.length()


func get_generated_stage_frame_count(stage: StringName) -> int:
	return GENERATED_FRAME_COUNT if stage in ATTACK_PRESENTATION_STAGES else 0


func get_primary_procedural_stroke_count() -> int:
	return 0


func get_current_energy_blade_frame() -> int:
	return mini(
		GENERATED_FRAME_COUNT - 1,
		int(floor(clampf(_travel_progress, 0.0, 0.9999) * GENERATED_FRAME_COUNT))
	)


func attach_elemental_aura(
	aura_scene: PackedScene,
	elements: Array,
	intensity: int
) -> void:
	if _suppress_attack_geometry or aura_scene == null or elements.is_empty():
		return
	if _elemental_aura != null and is_instance_valid(_elemental_aura):
		_elemental_aura.queue_free()
	_elemental_aura = aura_scene.instantiate() as Node2D
	if _elemental_aura == null:
		return
	add_child(_elemental_aura)
	_elemental_aura.position = _travel_point(_travel_progress)
	if _elemental_aura.has_method("configure"):
		_elemental_aura.call("configure", elements, intensity)


func _draw() -> void:
	if _suppress_attack_geometry:
		return
	var direction := _target_offset.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if _travel_progress < 1.0:
		var tip := _travel_point(_travel_progress)
		if _travel_progress <= RELEASE_TRAVEL_END:
			var release_progress := clampf(
				_travel_progress / RELEASE_TRAVEL_END,
				0.0,
				0.9999
			)
			var release_pose := _release_pose_scale(release_progress)
			var release_direction := direction.rotated(_release_rotation(release_progress))
			_draw_generated_stage(
				RELEASE_TEXTURE,
				RELEASE_MASK,
				_generated_stage_frame(release_progress, &"weapon_release"),
				direction * 42.0,
				release_direction,
				Vector2(180.0, 154.0) * release_pose,
				1.0,
				&"weapon_release"
			)
		if _travel_progress >= TRAVEL_VISUAL_START:
			var visual_progress := clampf(
				(_travel_progress - TRAVEL_VISUAL_START)
					/ (1.0 - TRAVEL_VISUAL_START),
				0.0,
				0.9999
			)
			var travel_pose := _travel_pose_scale(visual_progress)
			var travel_direction := direction.rotated(_travel_rotation(visual_progress))
			_draw_generated_stage(
				TRAVEL_TEXTURE,
				TRAVEL_MASK,
				_generated_stage_frame(visual_progress, &"blade_travel"),
				tip,
				travel_direction,
				Vector2(182.0, 146.0) * travel_pose,
				1.0,
				&"blade_travel"
			)
	if _impact_progress > 0.0:
		var impact_pose := _impact_pose_scale(_impact_progress)
		var impact_snap := direction * lerpf(
			-18.0,
			6.0,
			1.0 - pow(1.0 - minf(1.0, _impact_progress * 4.0), 3.0)
		)
		impact_snap += direction.orthogonal() * sin(_impact_progress * PI * 2.0) * (
			3.5 * pow(1.0 - _impact_progress, 2.0)
		)
		_draw_generated_stage(
			IMPACT_TEXTURE,
			IMPACT_MASK,
			_generated_stage_frame(_impact_progress, &"directional_impact"),
			_target_offset + impact_snap,
			direction.rotated(_impact_rotation(_impact_progress)),
			Vector2(252.0, 198.0) * impact_pose,
			1.0,
			&"directional_impact"
		)


func _draw_combo_projectile_layers(tip: Vector2, tail: Vector2) -> void:
	if _combo_tier <= 0:
		return
	var direction := _target_offset.normalized()
	var normal := direction.orthogonal()
	var combo_color := _combo_color()
	var travel_phase := _travel_progress * TAU * (1.45 + float(_combo_tier) * 0.28)
	var orbit_radius := (13.0 + float(_combo_tier) * 4.0) * _attack_size_multiplier
	for side in [-1.0, 1.0]:
		var ribbon := PackedVector2Array()
		for point_index in 7:
			var ratio := float(point_index) / 6.0
			var center := tail.lerp(tip, ratio)
			var wave := sin(ratio * PI * 1.35 + travel_phase + side * 1.4)
			ribbon.append(
				center
				+ normal * side * orbit_radius * (0.35 + ratio * 0.65)
				+ normal * wave * orbit_radius * 0.22
			)
		draw_polyline(
			ribbon,
			Color(combo_color, 0.58 + float(_combo_tier) * 0.09),
			1.8 + float(_combo_tier) * 0.85,
			true
		)
	if _combo_tier >= 2:
		for echo_index in 2:
			var side := -1.0 if echo_index == 0 else 1.0
			var echo_offset := normal * side * orbit_radius * 0.72
			var echo := PackedVector2Array([
				tail - direction * (24.0 + float(echo_index) * 8.0) + echo_offset * 0.35,
				tail - direction * 5.0 + echo_offset * 0.72,
				tip - direction * 18.0 + echo_offset,
			])
			draw_polyline(
				echo,
				Color(combo_color.lightened(0.28), 0.46),
				3.2 * _attack_size_multiplier,
				true
			)
	if _combo_tier >= 3:
		for ray_index in 6:
			var angle := TAU * float(ray_index) / 6.0 + travel_phase * 0.35
			var ray := Vector2.from_angle(angle)
			var rune_center := tip - direction * 12.0 + ray * orbit_radius
			var tangent := ray.orthogonal()
			draw_colored_polygon(
				PackedVector2Array([
					rune_center + ray * 4.5,
					rune_center + tangent * 2.8,
					rune_center - ray * 4.5,
					rune_center - tangent * 2.8,
				]),
				Color(combo_color.lightened(0.24), 0.78)
			)


func _draw_combo_impact_layers(alpha: float, radius: float) -> void:
	if _combo_tier <= 0:
		return
	var combo_color := _combo_color()
	for tier_index in _combo_tier:
		var tier_radius := radius * (0.72 + float(tier_index) * 0.22)
		var start_angle := _impact_progress * TAU * (1.0 if tier_index % 2 == 0 else -1.0)
		draw_arc(
			_target_offset,
			tier_radius,
			start_angle,
			start_angle + PI * (0.82 + float(tier_index) * 0.18),
			18,
			Color(combo_color.lightened(float(tier_index) * 0.10), alpha * (0.86 - float(tier_index) * 0.10)),
			maxf(1.4, 4.2 - float(tier_index) * 0.55),
			true
		)
	if _combo_tier < 3:
		return
	for ray_index in 10:
		var ray := Vector2.from_angle(TAU * float(ray_index) / 10.0)
		draw_line(
			_target_offset + ray * radius * 0.42,
			_target_offset + ray * radius * 1.18,
			Color(combo_color.lightened(0.28), alpha * 0.90),
			2.2,
			true
		)


func _travel_point(progress: float) -> Vector2:
	if progress <= LAUNCH_PROGRESS:
		return Vector2.ZERO
	var travel_progress := clampf(
		(progress - LAUNCH_PROGRESS) / (1.0 - LAUNCH_PROGRESS),
		0.0,
		1.0
	)
	var shockwave_progress := 1.0 - pow(1.0 - travel_progress, 4.0)
	return _target_offset * shockwave_progress


func _generated_frame(progress: float) -> int:
	return mini(
		GENERATED_FRAME_COUNT - 1,
		int(floor(clampf(progress, 0.0, 0.9999) * GENERATED_FRAME_COUNT))
	)


func _generated_stage_frame(progress: float, stage: StringName) -> int:
	return _generated_frame(_curved_stage_progress(progress, stage))


func _curved_stage_progress(progress: float, stage: StringName) -> float:
	var curved_progress := clampf(progress, 0.0, 0.9999)
	match stage:
		&"weapon_release":
			curved_progress = pow(curved_progress, 0.72)
		&"blade_travel":
			curved_progress = smoothstep(0.0, 0.92, curved_progress)
		&"directional_impact":
			curved_progress = pow(curved_progress, 0.58)
	return clampf(curved_progress, 0.0, 0.9999)


func _current_stage_progress(stage: StringName) -> float:
	match stage:
		&"weapon_release":
			return clampf(_travel_progress / RELEASE_TRAVEL_END, 0.0, 0.9999)
		&"blade_travel":
			return clampf(
				(_travel_progress - TRAVEL_VISUAL_START)
					/ (1.0 - TRAVEL_VISUAL_START),
				0.0,
				0.9999
			)
		&"directional_impact":
			return clampf(_impact_progress, 0.0, 0.9999)
	return 0.0


func _generated_frame_mix(stage: StringName) -> Vector3:
	var curved_progress := _curved_stage_progress(
		_current_stage_progress(stage),
		stage
	)
	var frame_position := curved_progress * float(GENERATED_FRAME_COUNT - 1)
	var lower_frame := clampi(floori(frame_position), 0, GENERATED_FRAME_COUNT - 1)
	var upper_frame := clampi(ceili(frame_position), lower_frame, GENERATED_FRAME_COUNT - 1)
	return Vector3(
		float(lower_frame),
		float(upper_frame),
		frame_position - float(lower_frame)
	)


func _release_pose_scale(progress: float) -> Vector2:
	if progress < 0.28:
		var gather := smoothstep(0.0, 0.28, progress)
		return Vector2(
			lerpf(0.64, 0.78, gather),
			lerpf(1.08, 1.24, gather)
		)
	if progress < 0.62:
		var snap := ease(_range_progress(progress, 0.28, 0.62), 0.30)
		return Vector2(
			lerpf(0.78, 1.13, snap),
			lerpf(1.24, 0.94, snap)
		)
	var settle := smoothstep(0.62, 1.0, progress)
	return Vector2(
		lerpf(1.13, 1.0, settle),
		lerpf(0.94, 1.0, settle)
	)


func _travel_pose_scale(progress: float) -> Vector2:
	if progress < 0.14:
		var release := smoothstep(0.0, 0.14, progress)
		return Vector2(
			lerpf(0.72, 1.10, release),
			lerpf(1.18, 0.92, release)
		)
	if progress < 0.42:
		var settle := smoothstep(0.14, 0.42, progress)
		return Vector2(
			lerpf(1.10, 1.02, settle),
			lerpf(0.92, 1.0, settle)
		)
	var decay := smoothstep(0.42, 1.0, progress)
	return Vector2(
		lerpf(1.02, 0.96, decay),
		lerpf(1.0, 1.06, decay)
	)


func _impact_pose_scale(progress: float) -> Vector2:
	if progress < 0.20:
		var contact := ease(_range_progress(progress, 0.0, 0.20), 0.26)
		return Vector2(
			lerpf(0.68, 1.14, contact),
			lerpf(1.22, 0.94, contact)
		)
	var release := smoothstep(0.20, 1.0, progress)
	return Vector2(
		lerpf(1.14, 1.04, release),
		lerpf(0.94, 1.08, release)
	)


func _release_rotation(progress: float) -> float:
	return deg_to_rad(lerpf(-4.5, 1.2, ease(progress, 0.45)))


func _travel_rotation(progress: float) -> float:
	return deg_to_rad(sin(progress * PI) * -1.8 + (1.0 - progress) * 0.8)


func _impact_rotation(progress: float) -> float:
	return deg_to_rad(lerpf(-3.2, 0.0, ease(minf(1.0, progress * 3.5), 0.32)))


func _range_progress(value: float, start: float, finish: float) -> float:
	return clampf((value - start) / maxf(0.001, finish - start), 0.0, 1.0)


func _draw_generated_stage(
	texture: Texture2D,
	mask: Texture2D,
	frame_index: int,
	center: Vector2,
	direction: Vector2,
	base_size: Vector2,
	alpha: float,
	stage: StringName
) -> void:
	if texture == null or mask == null or alpha <= 0.001:
		return
	var spectacle_scale := float([1.0, 1.08, 1.18, 1.30][_combo_tier])
	var size := base_size * _attack_size_multiplier * spectacle_scale
	var source_rect := _generated_source_rect(frame_index)
	var normal := direction.orthogonal()

	for combo_pass in _combo_tier:
		var offset := (
			-direction * (5.0 + float(combo_pass) * 4.0)
			+ normal
				* sin(
					_travel_progress * TAU * 2.0
						+ float(combo_pass) * 1.7
				)
				* (2.0 + float(combo_pass))
		)
		_draw_generated_frame(
			mask,
			source_rect,
			center + offset,
			direction,
			size * (1.07 + float(combo_pass) * 0.045),
			Color(_combo_color(), alpha * (0.34 - float(combo_pass) * 0.055))
		)

	for element_index in _visual_elements.size():
		var colors := _generated_element_colors(_visual_elements[element_index])
		var lane_offset := normal * (
			float(element_index) - float(_visual_elements.size() - 1) * 0.5
		) * 3.0
		_draw_generated_frame(
			mask,
			source_rect,
			center - direction * 3.0 + lane_offset,
			direction,
			size * (1.13 + float(element_index) * 0.025),
			Color(colors[0], alpha * 0.58)
		)
		_draw_generated_frame(
			mask,
			source_rect,
			center + lane_offset,
			direction,
			size * (1.055 + float(element_index) * 0.018),
			Color(colors[1], alpha * 0.52)
		)

	if _lifesteal:
		_draw_generated_frame(
			mask,
			source_rect,
			center - direction * 4.0,
			direction,
			size * 1.11,
			Color(0.94, 0.08, 0.30, alpha * 0.48)
		)

	if stage == &"weapon_release":
		for shear_index in RELEASE_SHEAR_SAMPLE_COUNT:
			var sample_number := float(shear_index + 1)
			var shear_frame := maxi(0, frame_index - shear_index - 1)
			var shear_direction := direction.rotated(
				deg_to_rad((-2.4 + float(shear_index) * 2.2) * (1.0 - _travel_progress))
			)
			_draw_generated_frame(
				texture,
				_generated_source_rect(shear_frame),
				center - direction * (4.0 + sample_number * 3.5)
					+ normal * (-1.0 if shear_index % 2 == 0 else 1.0) * sample_number * 1.8,
				shear_direction,
				size * Vector2(1.0 + sample_number * 0.026, 1.0 + sample_number * 0.045),
				Color(0.54, 0.88, 1.0, alpha * (0.19 - float(shear_index) * 0.045))
			)

	if stage == &"blade_travel":
		for ghost_index in range(TEMPORAL_AFTERIMAGE_SAMPLE_COUNT - 1, -1, -1):
			var lag: float = TRAVEL_HISTORY_LAGS[ghost_index]
			var historical_progress := maxf(
				TRAVEL_VISUAL_START,
				_travel_progress - lag
			)
			var historical_visual_progress := clampf(
				(historical_progress - TRAVEL_VISUAL_START)
					/ (1.0 - TRAVEL_VISUAL_START),
				0.0,
				0.9999
			)
			var ghost_frame := _generated_stage_frame(
				historical_visual_progress,
				&"blade_travel"
			)
			var sample_number := float(ghost_index + 1)
			var ghost_alpha := alpha * (0.20 - float(ghost_index) * 0.032)
			_draw_generated_frame(
				texture,
				_generated_source_rect(ghost_frame),
				_travel_point(historical_progress)
					+ normal
						* sin(
							historical_visual_progress * PI * 2.0
								+ sample_number * 1.7
						)
						* sample_number
						* 1.4,
				direction,
				size * Vector2(
					1.0 + sample_number * 0.018,
					1.0 + sample_number * 0.032
				),
				Color(0.38, 0.78, 1.0, ghost_alpha)
			)

	if stage == &"directional_impact":
		for echo_index in range(IMPACT_ECHO_COUNT - 1, -1, -1):
			var sample_number := float(echo_index + 1)
			var delayed_progress := maxf(
				0.0,
				_impact_progress - 0.085 * sample_number
			)
			var echo_frame := _generated_stage_frame(
				delayed_progress,
				&"directional_impact"
			)
			var echo_fade := (
				1.0 - smoothstep(0.46 + float(echo_index) * 0.10, 1.0, _impact_progress)
			)
			_draw_generated_frame(
				texture,
				_generated_source_rect(echo_frame),
				center - direction * sample_number * 5.0
					+ normal * (-1.0 if echo_index % 2 == 0 else 1.0) * sample_number * 2.4,
				direction.rotated(deg_to_rad((-1.4 + float(echo_index) * 2.8) * echo_fade)),
				size * Vector2(
					1.0 + sample_number * 0.055,
					1.0 + sample_number * 0.075
				),
				Color(0.40, 0.82, 1.0, alpha * (0.22 - float(echo_index) * 0.045) * echo_fade)
			)

	var frame_mix := _generated_frame_mix(stage)
	var lower_frame := int(frame_mix.x)
	var upper_frame := int(frame_mix.y)
	var frame_blend := frame_mix.z
	_draw_generated_frame(
		texture,
		_generated_source_rect(lower_frame),
		center,
		direction,
		size,
		Color(1.0, 1.0, 1.0, alpha * (1.0 - frame_blend))
	)
	if upper_frame != lower_frame and frame_blend > 0.001:
		_draw_generated_frame(
			texture,
			_generated_source_rect(upper_frame),
			center,
			direction,
			size,
			Color(1.0, 1.0, 1.0, alpha * frame_blend)
		)
	if stage == &"directional_impact":
		var flash_progress := clampf(
			_impact_progress / maxf(0.001, CONTACT_FLASH_WINDOW / IMPACT_DURATION),
			0.0,
			1.0
		)
		var flash_alpha := sin(flash_progress * PI) * (1.0 - flash_progress) * 0.92
		if flash_alpha > 0.001:
			_draw_generated_frame(
				mask,
				source_rect,
				center + direction * 2.0,
				direction,
				size * lerpf(0.78, 1.03, ease(flash_progress, 0.34)),
				Color(0.92, 0.99, 1.0, flash_alpha)
			)


func _draw_generated_frame(
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	direction: Vector2,
	size: Vector2,
	color: Color
) -> void:
	draw_set_transform(center, direction.angle(), Vector2.ONE)
	draw_texture_rect_region(
		texture,
		Rect2(-size * 0.5, size),
		source_rect,
		color
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _generated_source_rect(frame_index: int) -> Rect2:
	return Rect2(
		Vector2(GENERATED_FRAME_SIZE.x * float(frame_index), 0.0),
		GENERATED_FRAME_SIZE
	)


func _generated_element_colors(element: StringName) -> Array[Color]:
	match element:
		&"flame":
			return [Color(0.88, 0.025, 0.008), Color(1.0, 0.48, 0.045)]
		&"frost":
			return [Color(0.04, 0.42, 1.0), Color(0.62, 0.94, 1.0)]
		&"storm":
			return [Color(0.42, 0.18, 1.0), Color(0.88, 0.72, 1.0)]
		&"venom":
			return [Color(0.08, 0.46, 0.04), Color(0.48, 1.0, 0.18)]
	return [Color(0.08, 0.42, 0.88), Color(0.62, 0.94, 1.0)]


func _draw_weapon_release(direction: Vector2, normal: Vector2) -> void:
	var release_progress := clampf(_travel_progress / 0.34, 0.0, 1.0)
	var envelope := (
		smoothstep(0.0, 0.12, release_progress)
		* (1.0 - smoothstep(0.68, 1.0, release_progress))
	)
	if envelope <= 0.001:
		return
	var palette := _brush_palette()
	var center := direction * 18.0
	var base_angle := direction.angle() - 1.30
	var sweep := 2.34 * ease(release_progress, 0.58)
	for arc_index in RELEASE_ARC_COUNT:
		var lane := float(arc_index)
		var radius := (
			(43.0 + lane * 6.0 + sin(lane * 2.4) * 3.0)
			* _attack_size_multiplier
			* (0.88 + release_progress * 0.12)
		)
		var start_angle := base_angle + lane * 0.10 - (0.16 if arc_index == 0 else 0.0)
		var end_angle := (
			start_angle
			+ sweep * (1.0 - lane * 0.075)
			- (0.14 if arc_index == 2 else 0.0)
		)
		var body_width := (10.0 - lane * 1.45) * _attack_size_multiplier
		_draw_tapered_brush_arc(
			center,
			radius,
			start_angle,
			end_angle,
			body_width + 5.0 * _attack_size_multiplier,
			Color(palette[0], envelope * (0.62 - lane * 0.075)),
			arc_index
		)
		_draw_tapered_brush_arc(
			center,
			radius - 0.8 * _attack_size_multiplier,
			start_angle + 0.025,
			end_angle - 0.025,
			body_width,
			Color(palette[1], envelope * (0.88 - lane * 0.08)),
			arc_index + 7
		)
		_draw_tapered_brush_arc(
			center,
			radius - 2.0 * _attack_size_multiplier,
			start_angle + 0.11,
			end_angle - 0.07,
			maxf(1.4, body_width * 0.22),
			Color(palette[2], envelope * (0.96 - lane * 0.11)),
			arc_index + 13
		)
	var thrust_end := direction * lerpf(38.0, 76.0, release_progress) * _attack_size_multiplier
	var thrust_start := direction * 8.0 + normal * 5.0 * _attack_size_multiplier
	draw_line(
		thrust_start - direction * 12.0,
		thrust_end,
		Color(palette[0], envelope * 0.58),
		8.0 * _attack_size_multiplier,
		true
	)
	draw_line(
		thrust_start,
		thrust_end,
		Color(palette[2], envelope),
		2.2 * _attack_size_multiplier,
		true
	)
	for fleck_index in 6:
		var ratio := float(fleck_index + 1) / 7.0
		var fleck_center := (
			direction * lerpf(22.0, 68.0, ratio) * _attack_size_multiplier
			+ normal
				* sin(float(fleck_index) * 2.17 + release_progress * 5.0)
				* (9.0 + float(fleck_index % 3) * 4.0)
				* _attack_size_multiplier
		)
		draw_line(
			fleck_center - direction * (5.0 + float(fleck_index % 2) * 3.0),
			fleck_center,
			Color(palette[1], envelope * 0.72),
			(1.2 + float(fleck_index % 3) * 0.45) * _attack_size_multiplier,
			true
		)


func _draw_tapered_brush_arc(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	max_width: float,
	color: Color,
	seed: int
) -> void:
	const SEGMENT_COUNT := 16
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for point_index in SEGMENT_COUNT + 1:
		var ratio := float(point_index) / float(SEGMENT_COUNT)
		var angle := lerpf(start_angle, end_angle, ratio)
		var taper := pow(sin(ratio * PI), 0.62)
		var roughness := sin(float(seed) * 1.73 + ratio * TAU * 2.0) * max_width * 0.10
		var half_width := max_width * (0.08 + taper * 0.42)
		var radial := Vector2.from_angle(angle)
		outer.append(center + radial * (radius + half_width + roughness))
		inner.append(center + radial * (radius - half_width + roughness * 0.35))
	var polygon := PackedVector2Array()
	for point in outer:
		polygon.append(point)
	for point_index in range(inner.size() - 1, -1, -1):
		polygon.append(inner[point_index])
	draw_colored_polygon(polygon, color)


func _draw_energy_blade_sprite(center: Vector2, direction: Vector2) -> void:
	if ENERGY_BLADE_TEXTURE == null:
		return
	var frame_index := get_current_energy_blade_frame()
	var source_rect := _energy_blade_source_rect(frame_index)
	var pulse := 1.0 + sin(_travel_progress * PI) * 0.05
	var combo_spectacle_scale := ATTACK_GEOMETRY.resolve_combo_spectacle_scale(
		_combo_tier * 3
	)
	var launch_scale := lerpf(0.78, 1.0, smoothstep(0.10, 0.34, _travel_progress))
	var width := (
		176.0
		* _attack_size_multiplier
		* pulse
		* combo_spectacle_scale
		* launch_scale
	)
	var height := 106.0 * _attack_size_multiplier * combo_spectacle_scale * launch_scale
	var angle := direction.angle()
	var launch_alpha := smoothstep(0.10, 0.27, _travel_progress)
	var fade := launch_alpha * (1.0 - smoothstep(0.78, 1.0, _travel_progress))
	_draw_projectile_brush_backing(center, direction, width, height, fade)
	_draw_combo_frame_aura(center, direction, width, height, source_rect, fade)
	for layer_index in _visual_elements.size():
		_draw_element_frame_aura(
			_visual_elements[layer_index],
			layer_index,
			center,
			direction,
			width,
			height,
			source_rect,
			fade
		)
	for ghost_index in range(2, 0, -1):
		var ghost_frame := maxi(0, frame_index - ghost_index)
		if ghost_frame == frame_index:
			continue
		var ghost_offset := direction * (-14.0 * float(ghost_index) * _attack_size_multiplier)
		var ghost_scale := 1.0 + float(ghost_index) * 0.045
		draw_set_transform(center + ghost_offset, angle, Vector2.ONE)
		draw_texture_rect_region(
			ENERGY_BLADE_TEXTURE,
			Rect2(
				Vector2(-width * ghost_scale * 0.5, -height * ghost_scale * 0.5),
				Vector2(width * ghost_scale, height * ghost_scale)
			),
			_energy_blade_source_rect(ghost_frame),
			Color(0.30, 0.78, 1.0, 0.15 * fade / float(ghost_index))
		)
	draw_set_transform(center, angle, Vector2.ONE)
	draw_texture_rect_region(
		ENERGY_BLADE_TEXTURE,
		Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height)),
		source_rect,
		Color(0.92, 0.99, 1.0, 0.96 * fade)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_elemental_edge_flow(center, direction, width, height, fade)


func _draw_projectile_brush_backing(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	fade: float
) -> void:
	if fade <= 0.001:
		return
	var normal := direction.orthogonal()
	var palette := _brush_palette()
	var nose := center + direction * width * 0.42
	var shoulder := center + direction * width * 0.12
	var tail := center - direction * width * 0.48
	var silhouette := PackedVector2Array([
		nose,
		shoulder + normal * height * 0.29,
		center - direction * width * 0.12 + normal * height * 0.41,
		tail + normal * height * 0.18,
		tail - direction * width * 0.11 + normal * height * 0.04,
		tail - direction * width * 0.04 - normal * height * 0.08,
		center - direction * width * 0.10 - normal * height * 0.34,
		shoulder - normal * height * 0.24,
	])
	draw_colored_polygon(silhouette, Color(palette[0], fade * 0.40))
	for stroke_index in 3:
		var side := -1.0 if stroke_index % 2 == 0 else 1.0
		var lane := float(stroke_index)
		var stroke_tail := (
			tail
			- direction * width * (0.06 + lane * 0.055)
			+ normal * side * height * (0.08 + lane * 0.085)
		)
		var stroke_head := (
			center
			+ direction * width * (0.16 + lane * 0.045)
			+ normal * side * height * (0.04 + lane * 0.035)
		)
		draw_line(
			stroke_tail,
			stroke_head,
			Color(palette[1], fade * (0.56 - lane * 0.09)),
			(5.0 - lane * 0.9) * _attack_size_multiplier,
			true
		)
		draw_line(
			stroke_tail + direction * width * 0.05,
			stroke_head,
			Color(palette[2], fade * (0.76 - lane * 0.11)),
			maxf(1.0, (1.9 - lane * 0.25) * _attack_size_multiplier),
			true
		)


func _draw_combo_frame_aura(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	source_rect: Rect2,
	fade: float
) -> void:
	if _combo_tier <= 0:
		return
	var combo_color := _combo_color()
	var normal := direction.orthogonal()
	for pass_index in _combo_tier:
		var phase := _travel_progress * TAU * 2.0 + float(pass_index) * 2.2
		_draw_aura_mask_pass(
			center,
			direction,
			width,
			height,
			source_rect,
			Color(combo_color, fade * (0.34 - float(pass_index) * 0.055)),
			1.11 + float(pass_index) * 0.055,
			-direction * (7.0 + float(pass_index) * 4.0)
				+ normal * sin(phase) * (3.0 + float(pass_index) * 1.5)
		)


func _draw_element_frame_aura(
	element: StringName,
	layer_index: int,
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	source_rect: Rect2,
	fade: float
) -> void:
	var normal := direction.orthogonal()
	var phase := _travel_progress * TAU * 2.8 + float(layer_index) * 2.1
	var drift := normal * sin(phase) * 3.5 - direction * (4.0 + float(layer_index) * 2.0)
	match element:
		&"flame":
			_draw_aura_mask_pass(
				center, direction, width, height, source_rect,
				Color(0.92, 0.06, 0.015, fade * 0.58),
				1.19 + float(layer_index) * 0.025,
				drift - direction * 3.0
			)
			_draw_aura_mask_pass(
				center, direction, width, height, source_rect,
				Color(1.0, 0.58, 0.06, fade * 0.52),
				1.075 + float(layer_index) * 0.02,
				drift * 0.45
			)
		&"frost":
			_draw_aura_mask_pass(
				center, direction, width, height, source_rect,
				Color(0.08, 0.52, 1.0, fade * 0.54),
				1.17 + float(layer_index) * 0.025,
				drift
			)
			_draw_aura_mask_pass(
				center, direction, width, height, source_rect,
				Color(0.72, 0.96, 1.0, fade * 0.62),
				1.065 + float(layer_index) * 0.02,
				normal * -sin(phase) * 1.5
			)
		_:
			var layer_color := _visual_colors[layer_index]
			_draw_aura_mask_pass(
				center, direction, width, height, source_rect,
				Color(layer_color, fade * 0.48),
				1.15 + float(layer_index) * 0.025,
				drift
			)
			_draw_aura_mask_pass(
				center, direction, width, height, source_rect,
				Color(layer_color.lightened(0.28), fade * 0.36),
				1.07,
				drift * 0.35
			)


func _draw_aura_mask_pass(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	source_rect: Rect2,
	color: Color,
	scale_multiplier: float,
	offset: Vector2
) -> void:
	draw_set_transform(center + offset, direction.angle(), Vector2.ONE)
	draw_texture_rect_region(
		ENERGY_BLADE_AURA_TEXTURE,
		Rect2(
			Vector2(
				-width * scale_multiplier * 0.5,
				-height * scale_multiplier * 0.5
			),
			Vector2(width * scale_multiplier, height * scale_multiplier)
		),
		source_rect,
		color
	)


func _energy_blade_source_rect(frame_index: int) -> Rect2:
	return Rect2(
		Vector2(ENERGY_BLADE_FRAME_SIZE.x * float(frame_index), 0.0),
		ENERGY_BLADE_FRAME_SIZE
	)


func _draw_elemental_edge_flow(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	fade: float
) -> void:
	if _visual_elements.is_empty():
		return
	for layer_index in _visual_elements.size():
		match _visual_elements[layer_index]:
			&"flame":
				_draw_flame_edge_flow(center, direction, width, height, fade, layer_index)
			&"frost":
				_draw_frost_edge_flow(center, direction, width, height, fade, layer_index)
			_:
				_draw_generic_element_flow(
					center,
					direction,
					width,
					height,
					fade,
					layer_index
				)


func _draw_flame_edge_flow(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	fade: float,
	layer_index: int
) -> void:
	var normal := direction.orthogonal()
	for tongue_index in 7:
		var seed := float(layer_index * 11 + tongue_index) * 1.371
		var flow := fmod(seed * 0.31 + _travel_progress * 3.4, 1.0)
		var side := -1.0 if (tongue_index + layer_index) % 2 == 0 else 1.0
		var tip := (
			center
			- direction * width * (0.04 + flow * 0.38)
			+ normal * side * height * (0.13 + fmod(seed, 0.25))
		)
		var length := width * (0.045 + (1.0 - flow) * 0.085)
		var tongue := PackedVector2Array()
		for point_index in 7:
			var ratio := float(point_index) / 6.0
			var curl := (
				normal
				* side
				* sin(ratio * PI)
				* sin(seed + _travel_progress * TAU * 3.2)
				* 6.0
			)
			var flutter := normal * sin(seed * 2.0 + ratio * TAU) * (1.0 - ratio) * 2.2
			tongue.append(
				tip - direction * length * (1.0 - ratio) + curl + flutter
			)
		draw_polyline(
			tongue,
			Color(
				Color(1.0, 0.18, 0.025) if tongue_index % 2 == 0
				else Color(1.0, 0.46, 0.055),
				fade * (0.62 + (1.0 - flow) * 0.24)
			),
			(1.15 + float(tongue_index % 3) * 0.32) * _attack_size_multiplier,
			true
		)
	for spark_index in 4:
		var seed := float(spark_index) * 1.91 + float(layer_index)
		var spark_position := (
			center
			- direction * width * (0.20 + fmod(seed, 0.18))
			+ normal * sin(seed * 2.4 + _travel_progress * TAU * 4.0) * height * 0.32
		)
		draw_line(
			spark_position - direction * (3.0 + float(spark_index) * 1.2),
			spark_position,
			Color(1.0, 0.48, 0.08, fade * 0.68),
			1.1 * _attack_size_multiplier,
			true
		)


func _draw_frost_edge_flow(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	fade: float,
	layer_index: int
) -> void:
	var normal := direction.orthogonal()
	for shard_index in 7:
		var seed := float(layer_index * 13 + shard_index) * 1.217
		var side := -1.0 if (shard_index + layer_index) % 2 == 0 else 1.0
		var flow := fmod(seed * 0.29 + _travel_progress * 2.35, 1.0)
		var shard_tip := (
			center
			- direction * width * (0.03 + flow * 0.40)
			+ normal * side * height * (0.16 + fmod(seed, 0.27))
		)
		var shard_length := (7.0 + float(shard_index % 3) * 3.5) * _attack_size_multiplier
		var shard_width := (2.2 + float(shard_index % 2) * 1.3) * _attack_size_multiplier
		var shard_base := shard_tip - direction * shard_length
		draw_colored_polygon(
			PackedVector2Array([
				shard_tip,
				shard_base + normal * shard_width,
				shard_base - direction * shard_length * 0.28,
				shard_base - normal * shard_width,
			]),
			Color(0.42, 0.9, 1.0, fade * (0.58 + (1.0 - flow) * 0.24))
		)
		draw_line(
			shard_base,
			shard_tip,
			Color(0.9, 1.0, 1.0, fade * 0.88),
			1.1 * _attack_size_multiplier,
			true
		)
	for mist_index in 3:
		var side := -1.0 if mist_index % 2 == 0 else 1.0
		var start := center - direction * width * (0.20 + float(mist_index) * 0.055)
		var mist := PackedVector2Array([start])
		for point_index in range(1, 6):
			var ratio := float(point_index) / 5.0
			mist.append(
				start
				- direction * width * 0.11 * ratio
				+ normal * side * sin(ratio * PI) * height * (0.055 + float(mist_index) * 0.018)
			)
		draw_polyline(
			mist,
			Color(0.62, 0.92, 1.0, fade * 0.24),
			(0.9 + float(mist_index) * 0.28) * _attack_size_multiplier,
			true
		)


func _draw_generic_element_flow(
	center: Vector2,
	direction: Vector2,
	width: float,
	height: float,
	fade: float,
	layer_index: int
) -> void:
	var normal := direction.orthogonal()
	var layer_color := _visual_colors[layer_index]
	for mote_index in 5:
		var seed := float(layer_index * 7 + mote_index) * 1.173
		var flow := fmod(seed * 0.37 + _travel_progress * 2.8, 1.0)
		var side := -1.0 if (mote_index + layer_index) % 2 == 0 else 1.0
		var mote_position := (
			center
			- direction * width * (0.06 + flow * 0.32)
			+ normal * side * height * (0.12 + fmod(seed, 0.28))
		)
		draw_line(
			mote_position - direction * width * 0.06,
			mote_position,
			Color(layer_color, fade * 0.62),
			1.8 * _attack_size_multiplier,
			true
		)


func _draw_energy_cutouts(
	center: Vector2,
	direction: Vector2,
	normal: Vector2,
	half_height: float,
	depth: float
) -> void:
	for cut_index in 3:
		var side := -1.0 if cut_index < 2 else 1.0
		var height_ratio := 0.24 + float(cut_index) * 0.19
		var start := center + normal * half_height * side * height_ratio
		var finish := (
			start
			+ direction * depth * (0.52 + float(cut_index) * 0.10)
			- normal * side * (8.0 + float(cut_index) * 3.0) * _attack_size_multiplier
		)
		draw_line(start, finish, Color(0.36, 0.82, 1.0, 0.28), 1.6 * _attack_size_multiplier, true)


func _draw_energy_wisps(
	center: Vector2,
	direction: Vector2,
	normal: Vector2,
	half_height: float,
	depth: float
) -> void:
	for wisp_index in 5:
		var side := -1.0 if wisp_index < 3 else 1.0
		var lane := 0.18 + float(wisp_index % 3) * 0.22
		var start := center + normal * half_height * side * lane
		var points := PackedVector2Array([start])
		for point_index in range(1, 7):
			var ratio := float(point_index) / 6.0
			points.append(
				start
				+ direction * depth * sin(ratio * PI * 0.86) * (0.62 + lane * 0.3)
				- normal * side * ratio * half_height * (0.34 + lane * 0.2)
			)
		draw_polyline(
			points,
			Color(
				0.75 + lane * 0.2,
				0.96,
				1.0,
				0.22 + (1.0 - lane) * 0.16
			),
			(1.2 + lane) * _attack_size_multiplier,
			true
		)


func _draw_energy_trails(
	center: Vector2,
	direction: Vector2,
	normal: Vector2,
	half_height: float
) -> void:
	for trail_index in 5:
		var offset := (float(trail_index) - 2.0) * half_height * 0.31
		var trail_end := center + normal * offset - direction * (12.0 + float(trail_index) * 4.0)
		var trail_start := trail_end - direction * (25.0 + float(trail_index) * 12.0)
		for segment_index in 3:
			var segment_start := trail_start.lerp(trail_end, float(segment_index) / 3.0)
			var segment_end := trail_start.lerp(trail_end, float(segment_index + 1) / 3.0)
			draw_line(
				segment_start,
				segment_end,
				Color(
					0.28,
					0.9,
					1.0,
					(0.10 + float(segment_index) * 0.08)
					* (1.0 - float(trail_index) * 0.10)
				),
				(0.8 + float(segment_index) * 0.55) * _attack_size_multiplier,
				true
			)


func _draw_leading_pressure_wave(
	center: Vector2,
	direction: Vector2,
	normal: Vector2,
	half_height: float,
	depth: float
) -> void:
	var pressure_center := center + direction * depth * 0.92
	var pressure := PackedVector2Array()
	for index in 13:
		var ratio := float(index) / 12.0
		var vertical := lerpf(-half_height * 0.62, half_height * 0.62, ratio)
		var forward := sin(ratio * PI) * depth * 0.20
		pressure.append(pressure_center + normal * vertical + direction * forward)
	draw_polyline(
		pressure,
		Color(0.76, 0.95, 1.0, 0.24),
		1.6 * _attack_size_multiplier,
		true
	)


func _draw_energy_motes(
	center: Vector2,
	direction: Vector2,
	normal: Vector2,
	half_height: float,
	depth: float
) -> void:
	for mote_index in 8:
		var seed := float(mote_index) * 1.618
		var travel := fmod(seed + _travel_progress * 2.2, 1.0)
		var side := -1.0 if mote_index % 2 == 0 else 1.0
		var point := (
			center
			- direction * (10.0 + travel * depth * 1.35)
			+ normal * side * half_height * (0.12 + fmod(seed, 0.72))
		)
		var alpha := (1.0 - travel) * 0.48
		draw_circle(
			point,
			(0.9 + float(mote_index % 3) * 0.45) * _attack_size_multiplier,
			Color(0.64, 0.95, 1.0, alpha)
		)


func _draw_energy_impact(alpha: float, radius: float) -> void:
	var direction := _target_offset.normalized()
	var normal := direction.orthogonal()
	var center := _target_offset
	var burst_height := radius * 1.8
	var burst := PackedVector2Array([
		center - direction * radius * 0.92 + normal * radius * 0.16,
		center + direction * radius * 0.18 + normal * radius * 0.05,
		center + direction * radius * 0.28 - normal * burst_height,
		center + direction * radius * 0.48 - normal * radius * 0.12,
		center + direction * radius * 0.82,
		center + direction * radius * 0.16 + normal * radius * 0.12,
	])
	draw_colored_polygon(burst, Color(0.12, 0.72, 1.0, alpha * 0.22))
	draw_line(
		center - direction * radius,
		center + direction * radius,
		Color(0.92, 1.0, 1.0, alpha * 0.88),
		maxf(2.0, 5.0 * (1.0 - _impact_progress)),
		true
	)
	for shard_index in 7:
		var shard_angle := lerpf(-1.22, 1.22, float(shard_index) / 6.0)
		var shard_direction := direction.rotated(shard_angle)
		var shard_start := center + shard_direction * radius * 0.28
		var shard_end := center + shard_direction * radius * (0.72 + float(shard_index % 3) * 0.16)
		draw_line(
			shard_start,
			shard_end,
			Color(0.5, 0.92, 1.0, alpha * 0.62),
			maxf(1.0, 2.2 * (1.0 - _impact_progress)),
			true
		)
	draw_arc(
		center,
		radius * 1.28,
		0.0,
		TAU,
		32,
		Color(0.2, 0.62, 1.0, alpha * 0.24),
		1.4,
		true
	)


func _draw_directional_brush_impact(alpha: float, radius: float) -> void:
	var direction := _target_offset.normalized()
	var normal := direction.orthogonal()
	var center := _target_offset
	var palette := _brush_palette()
	var expansion := ease(_impact_progress, 0.56)
	var up := normal if normal.y < 0.0 else -normal
	if _visual_elements.has(&"flame"):
		for smoke_index in 4:
			var smoke_center := (
				center
				- direction * radius * (0.16 + float(smoke_index) * 0.12)
				+ up * radius * (0.08 + float(smoke_index % 2) * 0.16)
			)
			draw_circle(
				smoke_center,
				radius * (0.20 + float(smoke_index % 3) * 0.055),
				Color(palette[0], alpha * (0.26 - float(smoke_index) * 0.035))
			)
	var wedge_start := center - direction * radius * 0.34
	var wedge_tip := center + direction * radius * (1.12 + expansion * 0.24)
	draw_colored_polygon(
		PackedVector2Array([
			wedge_start - normal * radius * 0.34,
			wedge_tip,
			wedge_start + normal * radius * 0.34,
			center - direction * radius * 0.52,
		]),
		Color(palette[0], alpha * 0.60)
	)
	draw_colored_polygon(
		PackedVector2Array([
			center - direction * radius * 0.22 - normal * radius * 0.18,
			wedge_tip - direction * radius * 0.12,
			center - direction * radius * 0.20 + normal * radius * 0.18,
		]),
		Color(palette[1], alpha * 0.76)
	)
	draw_line(
		center - direction * radius * 0.12,
		wedge_tip - direction * radius * 0.06,
		Color(palette[2], alpha * 0.94),
		maxf(1.2, 3.2 * _attack_size_multiplier * (1.0 - _impact_progress * 0.5)),
		true
	)
	for plume_index in 5:
		var lane := lerpf(-0.40, 0.34, float(plume_index) / 4.0)
		var plume_base := center + direction * radius * lane
		var plume_height := (
			radius
			* (0.62 + float((plume_index * 3) % 5) * 0.16)
			* (0.82 + expansion * 0.28)
		)
		var plume_drift := direction * radius * sin(float(plume_index) * 1.8) * 0.18
		var plume_tip := plume_base + up * plume_height + plume_drift
		var plume_width := radius * (0.15 + float(plume_index % 2) * 0.06)
		draw_colored_polygon(
			PackedVector2Array([
				plume_base - direction * plume_width * 1.35,
				plume_tip,
				plume_base + direction * plume_width,
				plume_base - up * radius * 0.12,
			]),
			Color(palette[0], alpha * 0.68)
		)
		draw_colored_polygon(
			PackedVector2Array([
				plume_base - direction * plume_width * 0.62,
				plume_tip - up * plume_height * 0.12,
				plume_base + direction * plume_width * 0.54,
			]),
			Color(palette[1], alpha * (0.72 + float(plume_index % 2) * 0.10))
		)
		draw_line(
			plume_base,
			plume_tip - up * plume_height * 0.10,
			Color(palette[2], alpha * 0.86),
			maxf(1.0, (1.8 + float(plume_index % 3) * 0.45) * _attack_size_multiplier),
			true
		)
	for spike_index in DIRECTIONAL_IMPACT_SPIKE_COUNT:
		var ratio := float(spike_index) / float(DIRECTIONAL_IMPACT_SPIKE_COUNT - 1)
		var fan_angle := lerpf(-1.40, 1.40, ratio)
		var spike_direction := direction.rotated(fan_angle)
		var length_ratio := (
			0.88
			+ 0.38 * absf(sin(float(spike_index) * 1.83 + 0.4))
			+ (0.44 if spike_index == DIRECTIONAL_IMPACT_SPIKE_COUNT / 2 else 0.0)
			+ (0.18 if spike_index in [0, DIRECTIONAL_IMPACT_SPIKE_COUNT - 1] else 0.0)
		)
		var spike_length := radius * length_ratio * (0.72 + expansion * 0.52)
		var base_width := (
			radius
			* (0.12 + float(spike_index % 3) * 0.035)
			* (1.0 - _impact_progress * 0.42)
		)
		var tangent := spike_direction.orthogonal()
		var spike_start := (
			center
			- direction * radius * 0.20
			+ normal * lerpf(-radius * 0.18, radius * 0.18, ratio)
		)
		var spike_tip := spike_start + spike_direction * spike_length
		draw_colored_polygon(
			PackedVector2Array([
				spike_start - tangent * base_width * 1.45,
				spike_tip,
				spike_start + tangent * base_width * 1.45,
				spike_start - spike_direction * base_width * 0.75,
			]),
			Color(palette[0], alpha * 0.62)
		)
		draw_colored_polygon(
			PackedVector2Array([
				spike_start - tangent * base_width * 0.72,
				spike_tip - spike_direction * spike_length * 0.08,
				spike_start + tangent * base_width * 0.72,
			]),
			Color(palette[1], alpha * 0.82)
		)
		draw_line(
			spike_start,
			spike_tip - spike_direction * spike_length * 0.06,
			Color(palette[2], alpha * 0.94),
			maxf(1.0, 2.1 * _attack_size_multiplier * (1.0 - _impact_progress * 0.55)),
			true
		)
	for debris_index in 8:
		var debris_angle := (
			direction.angle()
			+ lerpf(-1.35, 1.35, float(debris_index) / 7.0)
			+ sin(float(debris_index) * 2.4) * 0.10
		)
		var debris_direction := Vector2.from_angle(debris_angle)
		var debris_center := center + debris_direction * radius * (0.62 + expansion * 0.46)
		var debris_tangent := debris_direction.orthogonal()
		var debris_size := (2.0 + float(debris_index % 3) * 1.6) * _attack_size_multiplier
		draw_colored_polygon(
			PackedVector2Array([
				debris_center + debris_direction * debris_size * 1.7,
				debris_center + debris_tangent * debris_size * 0.65,
				debris_center - debris_direction * debris_size,
				debris_center - debris_tangent * debris_size * 0.65,
			]),
			Color(palette[1], alpha * 0.76)
		)


func _draw_elemental_impact(alpha: float, radius: float) -> void:
	for layer_index in _visual_elements.size():
		var element := _visual_elements[layer_index]
		match element:
			&"flame":
				for ray_index in 9:
					var angle := (
						TAU * float(ray_index) / 9.0
						+ _impact_progress * 0.65
						+ float(layer_index) * 0.3
					)
					var ray := Vector2.from_angle(angle)
					draw_line(
						_target_offset + ray * radius * 0.42,
						_target_offset + ray * radius * (1.05 + float(ray_index % 3) * 0.14),
						Color(
							1.0,
							0.18 + float(ray_index % 2) * 0.42,
							0.025,
							alpha * 0.84
						),
						(2.0 + float(ray_index % 3)) * _attack_size_multiplier,
						true
					)
			&"frost":
				for shard_index in 8:
					var angle := TAU * float(shard_index) / 8.0 + float(layer_index) * 0.22
					var ray := Vector2.from_angle(angle)
					var tangent := ray.orthogonal()
					var shard_center := _target_offset + ray * radius * 0.92
					draw_colored_polygon(
						PackedVector2Array([
							shard_center + ray * radius * 0.38,
							shard_center + tangent * radius * 0.11,
							shard_center - ray * radius * 0.18,
							shard_center - tangent * radius * 0.11,
						]),
						Color(0.48, 0.92, 1.0, alpha * 0.72)
					)
					draw_line(
						shard_center - ray * radius * 0.12,
						shard_center + ray * radius * 0.30,
						Color(0.92, 1.0, 1.0, alpha * 0.9),
						1.2 * _attack_size_multiplier,
						true
					)


func _brush_palette() -> Array[Color]:
	if _visual_elements.has(&"flame"):
		return [
			Color(0.20, 0.025, 0.018, 1.0),
			Color(1.0, 0.20, 0.035, 1.0),
			Color(1.0, 0.84, 0.34, 1.0),
		]
	if _visual_elements.has(&"frost"):
		return [
			Color(0.018, 0.11, 0.19, 1.0),
			Color(0.12, 0.68, 1.0, 1.0),
			Color(0.86, 0.99, 1.0, 1.0),
		]
	if _combo_tier > 0:
		return [
			Color(0.12, 0.075, 0.012, 1.0),
			_combo_color(),
			Color(1.0, 0.98, 0.78, 1.0),
		]
	return [
		Color(0.015, 0.075, 0.13, 1.0),
		Color(0.20, 0.72, 1.0, 1.0),
		Color(0.94, 1.0, 1.0, 1.0),
	]


func _direction_angle_degrees() -> float:
	if _direction_count <= 1 or _spread_degrees <= 0.0:
		return 0.0
	if _spread_degrees >= 359.5:
		return -180.0 + 360.0 * float(_direction_index) / float(_direction_count)
	return lerpf(
		-_spread_degrees * 0.5,
		_spread_degrees * 0.5,
		float(_direction_index) / float(_direction_count - 1)
	)


func _set_travel_progress(value: float) -> void:
	_travel_progress = clampf(value, 0.0, 1.0)
	if _elemental_aura != null and is_instance_valid(_elemental_aura):
		_elemental_aura.position = _travel_point(_travel_progress)
	premium_crescent_layer.call("set_progress", _travel_progress, _impact_progress)
	queue_redraw()


func _set_impact_progress(value: float) -> void:
	_impact_progress = clampf(value, 0.0, 1.0)
	premium_crescent_layer.call("set_progress", _travel_progress, _impact_progress)
	queue_redraw()


func _show_impact() -> void:
	if _elemental_aura != null and is_instance_valid(_elemental_aura):
		_elemental_aura.position = _target_offset
	impact_reached.emit(_did_hit, _combo_tier)
	damage_label.visible = _did_hit
	combo_label.visible = _did_hit
	if not _did_hit:
		return
	var label_tween := create_tween().set_parallel(true)
	label_tween.tween_property(damage_label, "position:y", damage_label.position.y - 24.0, IMPACT_DURATION)
	label_tween.tween_property(combo_label, "position:y", combo_label.position.y - 18.0, IMPACT_DURATION)
	label_tween.tween_property(damage_label, "modulate:a", 0.0, IMPACT_DURATION).set_delay(0.12)
	label_tween.tween_property(combo_label, "modulate:a", 0.0, IMPACT_DURATION).set_delay(0.12)


func _finish() -> void:
	finished.emit()
	queue_free()


func _accent_for_combo(combo_count: int) -> Color:
	if combo_count >= 9:
		return Color(0.82, 0.38, 1.0, 1.0)
	if combo_count >= 6:
		return Color(0.38, 1.0, 0.58, 1.0)
	if combo_count >= 3:
		return Color(1.0, 0.82, 0.20, 1.0)
	return Color(1.0, 0.56, 0.18, 1.0)


func _combo_color() -> Color:
	match _combo_tier:
		1:
			return Color(1.0, 0.68, 0.12, 1.0)
		2:
			return Color(1.0, 0.84, 0.26, 1.0)
		3:
			return Color(1.0, 0.94, 0.58, 1.0)
	return Color.WHITE


func _normalize_elements(elements: Array) -> Array[StringName]:
	var normalized: Array[StringName] = []
	for element_variant in elements:
		var element := StringName(String(element_variant).strip_edges().to_lower())
		match element:
			&"fire", &"flame":
				element = &"flame"
			&"ice", &"frost":
				element = &"frost"
			&"lightning", &"storm", &"thunder":
				element = &"storm"
			&"poison", &"venom":
				element = &"venom"
			&"water", &"wind", &"light", &"dark", &"normal":
				pass
			_:
				continue
		if not normalized.has(element):
			normalized.append(element)
	return normalized


func _colors_for_elements(elements: Array) -> Array[Color]:
	var colors: Array[Color] = []
	for element_variant in elements:
		var color := Color.WHITE
		match StringName(element_variant):
			&"flame":
				color = Color(1.0, 0.25, 0.06, 1.0)
			&"frost":
				color = Color(0.20, 0.86, 1.0, 1.0)
			&"storm":
				color = Color(0.82, 0.54, 1.0, 1.0)
			&"venom":
				color = Color(0.34, 1.0, 0.24, 1.0)
			_:
				continue
		colors.append(color)
	return colors


func _blended_accent(colors: Array[Color], fallback: Color) -> Color:
	if colors.is_empty():
		return fallback
	var blended := colors[0]
	for index in range(1, colors.size()):
		blended = blended.lerp(colors[index], 0.38)
	return blended.lightened(minf(0.22, float(_stack_count) * 0.012))
