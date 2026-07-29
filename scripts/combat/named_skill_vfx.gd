class_name NamedSkillVFX
extends Node2D

signal impact(profile_id: String, shake_strength: float, hit_stop: float)
signal finished(profile_id: String)

const CATALOG_SCRIPT := preload("res://scripts/systems/named_skill_vfx_catalog.gd")
const PART_NODE_NAMES := [&"Charge", &"Attack", &"Trail", &"Impact", &"Debris"]
const STAGE_ANTICIPATION := &"anticipation"
const STAGE_EXECUTION := &"execution"
const STAGE_IMPACT := &"impact"
const STAGE_DECAY := &"decay"
const MAX_ACCENT_LAYER_COUNT := 10
const DEFAULT_STACK_MILESTONES := [3, 6, 9]

@export var auto_free := true

var _catalog: RefCounted = CATALOG_SCRIPT.new()
var _profile: Dictionary = {}
var _profile_id := ""
var _sprites: Array[Sprite2D] = []
var _accent_sprites: Array[Sprite2D] = []
var _duration := 1.0
var _elapsed := 0.0
var _progress := 0.0
var _active := false
var _preview := false
var _direction := 1
var _active_scale := 1.0
var _impact_emitted := false
var _stage_name := STAGE_ANTICIPATION
var _evolution_level := 1
var _buff_stacks := 0
var _buff_stack_tier := 0
var _animation_archetype := &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node_name in PART_NODE_NAMES:
		var sprite := get_node_or_null(NodePath(String(node_name))) as Sprite2D
		if sprite != null:
			_sprites.append(sprite)
	_reset_parts()
	set_process(false)


func play(
	profile_id: String,
	direction: int = 1,
	intensity: float = 1.0,
	preview: bool = false,
	evolution_level: int = 1,
	buff_stacks: int = 0
) -> void:
	if _catalog.call("get_all_profiles").is_empty():
		if not bool(_catalog.call("load_catalog")):
			return
	var profile := _catalog.call("get_profile", profile_id) as Dictionary
	if profile.is_empty():
		push_error("Unknown named skill VFX profile: %s" % profile_id)
		return
	var atlas := load(String(profile.get("atlas_path", ""))) as Texture2D
	if atlas == null:
		push_error("Named skill VFX atlas failed to load: %s" % profile.get("atlas_path", ""))
		return
	_reset_parts()
	_profile = profile
	_profile_id = profile_id
	_direction = -1 if direction < 0 else 1
	_preview = preview
	_evolution_level = clampi(evolution_level, 1, 3)
	_buff_stacks = maxi(0, buff_stacks)
	_buff_stack_tier = _resolve_stack_tier(_buff_stacks)
	_animation_archetype = StringName(
		String(profile.get("archetype", profile.get("motion", "rush")))
	)
	_duration = maxf(0.1, float(profile.get("duration", 1.0)))
	_active_scale = (
		float(profile.get("preview_scale", 0.6))
		if preview
		else float(profile.get("scale", 1.0)) * clampf(intensity, 0.75, 1.45)
	)
	scale = Vector2(float(_direction) * _active_scale, _active_scale)
	_apply_atlas_parts(atlas)
	_elapsed = 0.0
	_progress = 0.0
	_impact_emitted = false
	_active = true
	visible = true
	set_process(true)
	_apply_progress(0.0)


func is_active() -> bool:
	return _active


func get_profile_id() -> String:
	return _profile_id


func get_part_count() -> int:
	return _sprites.size()


func get_active_layer_count() -> int:
	return _sprites.size() + _accent_sprites.size()


func get_evolution_level() -> int:
	return _evolution_level


func get_buff_stack_count() -> int:
	return _buff_stacks


func get_buff_stack_tier() -> int:
	return _buff_stack_tier


func get_animation_archetype() -> StringName:
	return _animation_archetype


func get_evolution_signature() -> String:
	var layers := _profile.get("evolution_layers", []) as Array
	var unlocked: Array[String] = []
	for layer_index in mini(_evolution_level, layers.size()):
		unlocked.append(String(layers[layer_index]))
	return "%s:L%d:S%d:%s" % [
		_animation_archetype,
		_evolution_level,
		_buff_stack_tier,
		"+".join(unlocked),
	]


func get_stage_name() -> StringName:
	return _stage_name


func get_impact_strength() -> float:
	return float(_profile.get("shake_strength", 0.0))


func get_hit_stop_duration() -> float:
	return float(_profile.get("hit_stop", 0.0))


func debug_set_progress(value: float) -> void:
	if not _active:
		return
	_elapsed = clampf(value, 0.0, 1.0) * _duration
	_apply_progress(clampf(value, 0.0, 1.0))


func _process(delta: float) -> void:
	if not _active:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.05)
	_elapsed = minf(_duration, _elapsed + real_delta)
	_apply_progress(_elapsed / _duration)
	if _elapsed >= _duration:
		_finish()


func _apply_atlas_parts(atlas: Texture2D) -> void:
	var columns := maxi(1, int(_profile.get("columns", 5)))
	var rows := maxi(1, int(_profile.get("rows", 1)))
	var row := clampi(int(_profile.get("row", 0)), 0, rows - 1)
	var atlas_size := atlas.get_size()
	var crop_inset := 3
	var region_y := _profile.get("region_y", []) as Array
	var top := (
		int(region_y[0])
		if region_y.size() == 2
		else roundi(atlas_size.y * float(row) / float(rows))
	)
	var bottom := (
		int(region_y[1])
		if region_y.size() == 2
		else roundi(atlas_size.y * float(row + 1) / float(rows))
	)
	for column in mini(_sprites.size(), columns):
		var left := roundi(atlas_size.x * float(column) / float(columns))
		var right := roundi(atlas_size.x * float(column + 1) / float(columns))
		var region := AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(
			left + crop_inset,
			top + crop_inset,
			right - left - crop_inset * 2,
			bottom - top - crop_inset * 2
		)
		region.filter_clip = true
		_sprites[column].texture = region
	_rebuild_accent_sprites()


func _rebuild_accent_sprites() -> void:
	for sprite in _accent_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
			sprite.queue_free()
	_accent_sprites.clear()
	if _sprites.size() < 5:
		return
	var accent_count := mini(
		MAX_ACCENT_LAYER_COUNT,
		(_evolution_level - 1) * 2 + _buff_stack_tier
	)
	for accent_index in accent_count:
		var sprite := Sprite2D.new()
		sprite.name = "EvolutionAccent%d" % (accent_index + 1)
		sprite.texture = _sprites[_accent_part_index(accent_index)].texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.use_parent_material = true
		sprite.z_index = -1 if accent_index % 2 == 0 else 1
		add_child(sprite)
		_accent_sprites.append(sprite)
		_set_alpha(sprite, 0.0)


func _accent_part_index(accent_index: int) -> int:
	match String(_animation_archetype):
		"blade_storm_lane", "rail_prison", "returning_arc":
			return 1 + accent_index % 2
		"compression_detonation":
			return 0 if accent_index % 2 == 0 else 3
		"orbiting_wheel":
			return 1 + accent_index % 3
		"descending_tomb", "armor_lock":
			return 1 if accent_index % 2 == 0 else 4
		"rhythm_pulse":
			return 0 if accent_index % 2 == 0 else 3
		"tactical_ward":
			return [0, 2, 3][accent_index % 3]
	return 1 + accent_index % 4


func _resolve_stack_tier(stack_count: int) -> int:
	var milestones := _profile.get("stack_milestones", DEFAULT_STACK_MILESTONES) as Array
	var tier := 0
	for milestone_variant in milestones:
		var milestone := int(milestone_variant)
		if milestone > 0 and stack_count >= milestone:
			tier += 1
	return tier


func _apply_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var anticipation_ratio := float(_profile.get("anticipation_time", 0.15)) / _duration
	var impact_ratio := float(_profile.get("impact_time", 0.6)) / _duration
	var impact_end := minf(0.9, impact_ratio + 0.14 / _duration)
	if _progress < anticipation_ratio:
		_stage_name = STAGE_ANTICIPATION
	elif _progress < impact_ratio:
		_stage_name = STAGE_EXECUTION
	elif _progress < impact_end:
		_stage_name = STAGE_IMPACT
	else:
		_stage_name = STAGE_DECAY
	if not _impact_emitted and _progress >= impact_ratio:
		_impact_emitted = true
		impact.emit(
			_profile_id,
			float(_profile.get("shake_strength", 0.0)),
			float(_profile.get("hit_stop", 0.0))
		)
	_layout_parts(anticipation_ratio, impact_ratio, impact_end)


func _layout_parts(anticipation_ratio: float, impact_ratio: float, impact_end: float) -> void:
	if _sprites.size() < 5:
		return
	var source := _vector_from_profile("source")
	var target := _vector_from_profile("target")
	var motion := String(_profile.get("motion", "rush"))
	var execution := _range_progress(_progress, anticipation_ratio, impact_ratio)
	var strike := _range_progress(_progress, impact_ratio, impact_end)
	var decay := _range_progress(_progress, impact_end, 1.0)
	var charge := _sprites[0]
	var attack := _sprites[1]
	var trail := _sprites[2]
	var impact_part := _sprites[3]
	var debris := _sprites[4]

	var charge_anchor := source
	if motion in ["pierce", "wheel", "burial", "ward"]:
		charge_anchor = target
	elif motion == "detonation":
		charge_anchor = source.lerp(target, 0.45)
	charge.position = charge_anchor
	charge.rotation = _charge_rotation(motion)
	charge.scale = Vector2.ONE * lerpf(0.46, 0.96, ease(_range_progress(_progress, 0.0, anticipation_ratio), 0.55))
	_set_alpha(charge, _window_alpha(_progress, 0.0, anticipation_ratio * 0.72, impact_ratio + 0.03))

	match motion:
		"pierce":
			attack.position = target
			trail.position = source.lerp(target, ease(execution, 0.18))
			trail.scale = Vector2(lerpf(0.56, 1.22, execution), lerpf(0.72, 1.0, execution))
		"wheel":
			attack.position = target
			trail.position = target
			attack.rotation = -0.18 + execution * 0.34
			trail.rotation = -0.08
		"burial":
			attack.position = target
			trail.position = target
			attack.scale = Vector2(lerpf(1.16, 0.92, execution), lerpf(0.58, 1.08, execution))
		"detonation":
			attack.position = source.lerp(target, ease(execution, 0.32))
			trail.position = target
			trail.rotation = -0.09
		"lock", "pulse", "ward":
			attack.position = source.lerp(target, ease(execution, 0.48))
			trail.position = target
		"reprise":
			attack.position = source.lerp(target, ease(execution, 0.28))
			trail.position = source.lerp(target, minf(1.0, execution * 1.12))
		_:
			attack.position = source.lerp(target, ease(execution, 0.2))
			trail.position = source.lerp(target, minf(1.0, execution * 1.18))
			attack.scale = Vector2(lerpf(0.62, 1.08, execution), lerpf(0.82, 1.0, execution))

	if motion not in ["burial", "rush", "pierce"]:
		attack.scale = Vector2.ONE * lerpf(0.72, 1.02, ease(execution, 0.42))
	if motion not in ["pierce"]:
		trail.scale = Vector2.ONE * lerpf(0.78, 1.06, execution)
	_set_alpha(attack, _window_alpha(_progress, anticipation_ratio * 0.62, impact_ratio * 0.8, impact_end))
	_set_alpha(trail, _window_alpha(_progress, anticipation_ratio, impact_ratio * 0.88, impact_end + 0.06))

	impact_part.position = target
	impact_part.rotation = -0.04 if motion in ["detonation", "wheel"] else 0.0
	impact_part.scale = Vector2.ONE * lerpf(0.34, 1.18, ease(strike, 0.32))
	_set_alpha(impact_part, _window_alpha(_progress, impact_ratio - 0.015, impact_ratio + 0.035, impact_end))

	debris.position = target
	debris.rotation = decay * (0.2 if motion in ["wheel", "ward"] else 0.08)
	debris.scale = Vector2.ONE * lerpf(0.58, 1.24, ease(maxf(strike, decay), 0.55))
	_set_alpha(debris, _window_alpha(_progress, impact_ratio, impact_end, 1.0))
	_layout_archetype(
		source,
		target,
		anticipation_ratio,
		impact_ratio,
		impact_end,
		execution,
		strike,
		decay,
		charge,
		attack,
		trail,
		impact_part,
		debris
	)
	_layout_accent_layers(
		source,
		target,
		anticipation_ratio,
		impact_ratio,
		impact_end,
		execution,
		strike,
		decay
	)


func _layout_archetype(
	source: Vector2,
	target: Vector2,
	anticipation_ratio: float,
	impact_ratio: float,
	impact_end: float,
	execution: float,
	strike: float,
	decay: float,
	charge: Sprite2D,
	attack: Sprite2D,
	trail: Sprite2D,
	impact_part: Sprite2D,
	debris: Sprite2D
) -> void:
	var anticipation := _range_progress(_progress, 0.0, anticipation_ratio)
	var snap := ease(execution, 0.22)
	var contact_bloom := _contact_bloom(strike)
	match String(_animation_archetype):
		"blade_storm_lane":
			var lane_snap := ease(execution, 0.14)
			charge.position = source + Vector2(18.0, -5.0)
			charge.scale = Vector2(
				lerpf(0.38, 1.08, anticipation),
				lerpf(1.18, 0.74, anticipation)
			)
			attack.position = source.lerp(target, lane_snap)
			attack.scale = Vector2(
				lerpf(0.54, 1.15, lane_snap),
				lerpf(0.72, 1.0, lane_snap)
			)
			trail.position = source.lerp(target, minf(1.0, lane_snap * 0.86))
			trail.scale = Vector2(lerpf(0.48, 1.38, lane_snap), 0.92)
			trail.rotation = sin(execution * PI) * -0.045
			impact_part.scale = Vector2(
				lerpf(0.62, 1.32, contact_bloom),
				lerpf(1.34, 0.94, contact_bloom)
			)
			debris.rotation = -0.12 + decay * 0.26
		"compression_detonation":
			var collapse := 1.0 - ease(anticipation, 2.2)
			var core := source.lerp(target, 0.62)
			charge.position = core
			charge.scale = Vector2.ONE * lerpf(0.42, 1.28, collapse)
			charge.rotation = anticipation * 0.38
			attack.position = source.lerp(core, snap)
			attack.scale = Vector2(
				lerpf(1.28, 0.62, snap),
				lerpf(0.58, 1.18, snap)
			)
			trail.position = core.lerp(target, ease(execution, 0.34))
			trail.rotation = -0.22 + execution * 0.44
			trail.scale = Vector2.ONE * lerpf(0.42, 1.16, execution)
			impact_part.scale = Vector2.ONE * lerpf(0.24, 1.52, contact_bloom)
			debris.scale = Vector2(
				lerpf(0.52, 1.34, maxf(strike, decay)),
				lerpf(0.34, 1.48, maxf(strike, decay))
			)
		"rail_prison":
			var rail_snap := smoothstep(0.0, 0.34, execution)
			charge.position = source
			charge.scale = Vector2(
				lerpf(0.44, 0.82, anticipation),
				lerpf(1.32, 0.78, anticipation)
			)
			attack.position = target
			attack.scale = Vector2(lerpf(0.24, 1.22, rail_snap), 0.76)
			trail.position = source.lerp(target, rail_snap)
			trail.scale = Vector2(lerpf(0.28, 1.58, rail_snap), 0.68)
			impact_part.scale = Vector2(
				lerpf(0.38, 0.92, contact_bloom),
				lerpf(1.48, 1.08, contact_bloom)
			)
			debris.rotation = sin(decay * PI * 3.0) * 0.035
		"orbiting_wheel":
			var orbit_angle := lerpf(-1.08, 0.12, ease(execution, 0.4))
			var orbit_radius := lerpf(118.0, 18.0, ease(execution, 0.52))
			charge.position = target + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
			charge.rotation = orbit_angle + PI * 0.5
			attack.position = target
			attack.rotation = -0.45 + execution * 1.02
			attack.scale = Vector2.ONE * lerpf(0.58, 1.18, execution)
			trail.position = target
			trail.rotation = 0.36 - execution * 0.74
			trail.scale = Vector2.ONE * lerpf(0.72, 1.32, execution)
			impact_part.rotation = strike * 0.72
			impact_part.scale = Vector2.ONE * lerpf(0.38, 1.42, contact_bloom)
			debris.rotation = -decay * 0.48
		"descending_tomb":
			var burial_drop := ease(execution, 0.26)
			charge.position = target + Vector2(0.0, lerpf(-156.0, -88.0, anticipation))
			charge.scale = Vector2(
				lerpf(0.58, 0.92, anticipation),
				lerpf(1.28, 0.86, anticipation)
			)
			attack.position = target + Vector2(0.0, lerpf(-172.0, 0.0, burial_drop))
			attack.scale = Vector2(
				lerpf(0.72, 1.08, burial_drop),
				lerpf(1.42, 0.94, burial_drop)
			)
			trail.position = target + Vector2(0.0, 18.0)
			trail.scale = Vector2(lerpf(0.46, 1.34, execution), 0.62)
			impact_part.scale = Vector2(
				lerpf(1.34, 0.96, contact_bloom),
				lerpf(0.34, 1.42, contact_bloom)
			)
			debris.position = target + Vector2(0.0, lerpf(18.0, -34.0, decay))
		"armor_lock":
			var lock_angle := anticipation * PI * 1.4
			charge.position = source + Vector2(cos(lock_angle), sin(lock_angle)) * lerpf(76.0, 34.0, anticipation)
			attack.position = source
			attack.scale = Vector2.ONE * lerpf(1.22, 0.82, execution)
			trail.position = source
			trail.rotation = -lock_angle * 0.42
			impact_part.position = source
			impact_part.scale = Vector2.ONE * lerpf(0.72, 1.14, contact_bloom)
			debris.position = source
			debris.rotation = decay * 0.18
		"returning_arc":
			var outbound := sin(execution * PI * 0.5)
			var return_lift := sin(execution * PI) * -46.0
			charge.position = source + Vector2(-18.0, -24.0)
			attack.position = source.lerp(target, outbound) + Vector2(0.0, return_lift)
			attack.rotation = lerpf(-0.32, 0.18, execution)
			trail.position = source.lerp(target, minf(1.0, outbound * 0.84))
			trail.rotation = -attack.rotation
			impact_part.rotation = 0.16 - strike * 0.32
			debris.position = target.lerp(source, decay * 0.34)
		"rhythm_pulse":
			var beat := _rhythm_pulse(_progress)
			charge.position = source
			charge.scale = Vector2.ONE * lerpf(0.62, 1.0, anticipation)
			attack.position = source
			attack.scale = Vector2.ONE * (0.72 + beat * 0.36)
			trail.position = source
			trail.scale = Vector2.ONE * lerpf(0.64, 1.28, execution)
			trail.rotation = execution * 0.22
			impact_part.position = source
			impact_part.scale = Vector2.ONE * lerpf(0.48, 1.26, contact_bloom)
			debris.position = source
			debris.rotation = -decay * 0.24
		"tactical_ward":
			var construct := smoothstep(0.0, 0.72, anticipation)
			charge.position = source
			charge.rotation = -0.22 + construct * 0.22
			charge.scale = Vector2.ONE * lerpf(0.42, 1.04, construct)
			attack.position = source
			attack.rotation = execution * 0.14
			attack.scale = Vector2.ONE * lerpf(0.72, 1.1, execution)
			trail.position = source
			trail.rotation = -execution * 0.18
			trail.scale = Vector2.ONE * lerpf(0.86, 1.24, execution)
			impact_part.position = source
			impact_part.scale = Vector2.ONE * lerpf(0.58, 1.18, contact_bloom)
			debris.position = source
			debris.rotation = decay * 0.12
		_:
			return
	var authored_pulse := _authored_beat_pulse(_progress)
	var beat_kick := 1.0 + authored_pulse * 0.045
	attack.scale *= Vector2(beat_kick, lerpf(1.0, 0.975, authored_pulse))
	trail.scale *= Vector2.ONE * (1.0 + authored_pulse * 0.025)
	if strike > 0.0:
		impact_part.scale *= Vector2.ONE * (1.0 + authored_pulse * 0.055)


func _layout_accent_layers(
	source: Vector2,
	target: Vector2,
	anticipation_ratio: float,
	impact_ratio: float,
	impact_end: float,
	execution: float,
	strike: float,
	decay: float
) -> void:
	if _accent_sprites.is_empty():
		return
	var show_alpha := _window_alpha(
		_progress,
		anticipation_ratio * 0.34,
		anticipation_ratio,
		minf(1.0, impact_end + 0.22)
	)
	var archetype := String(_animation_archetype)
	var count := _accent_sprites.size()
	for accent_index in count:
		var sprite := _accent_sprites[accent_index]
		var sample := float(accent_index + 1)
		var ratio := sample / float(count + 1)
		var side := -1.0 if accent_index % 2 == 0 else 1.0
		var alpha := show_alpha * (0.62 - ratio * 0.20)
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE * (0.72 + ratio * 0.34)
		match archetype:
			"blade_storm_lane":
				var delayed := clampf(execution * 1.42 - ratio * 0.32, 0.0, 1.0)
				sprite.position = source.lerp(target, ease(delayed, 0.16))
				sprite.position.y += side * (16.0 + sample * 4.8)
				sprite.rotation = side * (0.035 + ratio * 0.08)
				sprite.scale = Vector2(0.68 + delayed * 0.42, 0.72 + ratio * 0.18)
			"compression_detonation":
				var implode_angle := ratio * TAU + execution * 1.8
				var implode_radius := lerpf(116.0, 14.0, ease(execution, 0.48))
				sprite.position = target + Vector2(cos(implode_angle), sin(implode_angle)) * implode_radius
				sprite.rotation = implode_angle + PI * 0.5
				sprite.scale = Vector2.ONE * lerpf(0.58, 1.12, maxf(execution, strike))
			"rail_prison":
				var rail_progress := clampf(execution * 1.3 - ratio * 0.12, 0.0, 1.0)
				sprite.position = source.lerp(target, smoothstep(0.0, 0.52, rail_progress))
				sprite.position.y += side * (22.0 + floorf(float(accent_index) * 0.5) * 12.0)
				sprite.scale = Vector2(lerpf(0.38, 1.22, rail_progress), 0.62)
			"orbiting_wheel":
				var wheel_angle := ratio * TAU + execution * PI * 1.7
				var wheel_radius := lerpf(112.0, 52.0, maxf(execution, strike))
				sprite.position = target + Vector2(cos(wheel_angle), sin(wheel_angle)) * wheel_radius
				sprite.rotation = wheel_angle + PI * 0.5
			"descending_tomb":
				var staggered_drop := clampf(execution * 1.34 - ratio * 0.28, 0.0, 1.0)
				sprite.position = target + Vector2(
					side * (22.0 + sample * 9.0),
					lerpf(-184.0 - sample * 8.0, 8.0, ease(staggered_drop, 0.24))
				)
				sprite.rotation = side * lerpf(0.18, 0.04, staggered_drop)
				sprite.scale = Vector2(0.66, 0.88 + ratio * 0.42)
			"armor_lock":
				var plate_angle := ratio * TAU - execution * 1.4
				var plate_radius := lerpf(96.0, 46.0, execution)
				sprite.position = source + Vector2(cos(plate_angle), sin(plate_angle)) * plate_radius
				sprite.rotation = plate_angle + PI * 0.5
				sprite.scale = Vector2(0.58, 0.82)
			"returning_arc":
				var arc_progress := clampf(execution * 1.26 - ratio * 0.16, 0.0, 1.0)
				sprite.position = source.lerp(target, arc_progress)
				sprite.position.y += side * sin(arc_progress * PI) * (38.0 + sample * 5.0)
				sprite.rotation = side * lerpf(-0.28, 0.22, arc_progress)
			"rhythm_pulse":
				var pulse := fposmod(_progress * (3.0 + ratio) - ratio * 0.38, 1.0)
				sprite.position = source
				sprite.scale = Vector2.ONE * lerpf(0.46, 1.36 + ratio * 0.28, pulse)
				sprite.rotation = side * ratio * 0.24
				alpha *= sin(pulse * PI)
			"tactical_ward":
				var corner_angle := ratio * TAU + PI * 0.25
				var corner_radius := lerpf(104.0, 68.0, execution)
				sprite.position = source + Vector2(cos(corner_angle), sin(corner_angle)) * corner_radius
				sprite.rotation = corner_angle
				sprite.scale = Vector2(0.62, 0.86)
			_:
				sprite.position = source.lerp(target, ratio)
		alpha *= 0.90 + 0.10 * sin(_progress * TAU * 2.0 + sample)
		alpha *= 0.88 + 0.12 * _authored_beat_pulse(_progress)
		if strike > 0.0:
			alpha *= lerpf(1.0, 0.62, strike)
		if decay > 0.0:
			alpha *= 1.0 - decay
		_set_alpha(sprite, alpha)


func _contact_bloom(strike: float) -> float:
	if strike <= 0.0:
		return 0.0
	if strike < 0.34:
		return ease(strike / 0.34, 0.24)
	return lerpf(1.0, 0.86, smoothstep(0.34, 1.0, strike))


func _rhythm_pulse(progress: float) -> float:
	return _authored_beat_pulse(progress, 0.075)


func _authored_beat_pulse(progress: float, width: float = 0.06) -> float:
	var beats := _profile.get("beat_pattern", []) as Array
	var pulse := 0.0
	for beat_variant in beats:
		var distance := absf(progress - float(beat_variant))
		pulse = maxf(pulse, 1.0 - smoothstep(0.0, width, distance))
	return pulse


func _charge_rotation(motion: String) -> float:
	if motion == "wheel":
		return -0.22 + _progress * 0.44
	if motion == "ward":
		return sin(_progress * PI) * 0.05
	return 0.0


func _vector_from_profile(key: String) -> Vector2:
	var values := _profile.get(key, [0.0, 0.0]) as Array
	return Vector2(float(values[0]), float(values[1]))


func _window_alpha(value: float, start: float, peak: float, finish: float) -> float:
	if value <= start or value >= finish:
		return 0.0
	var rise := smoothstep(start, maxf(start + 0.001, peak), value)
	var fall := 1.0 - smoothstep(maxf(peak, start + 0.001), maxf(finish, peak + 0.001), value)
	return clampf(rise * fall, 0.0, 1.0)


func _range_progress(value: float, start: float, finish: float) -> float:
	return clampf((value - start) / maxf(0.001, finish - start), 0.0, 1.0)


func _set_alpha(sprite: Sprite2D, alpha: float) -> void:
	sprite.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))


func _reset_parts() -> void:
	for sprite in _sprites:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		_set_alpha(sprite, 0.0)
	for sprite in _accent_sprites:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		_set_alpha(sprite, 0.0)
	visible = false


func _finish() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	finished.emit(_profile_id)
	if auto_free:
		queue_free()
	else:
		_reset_parts()
