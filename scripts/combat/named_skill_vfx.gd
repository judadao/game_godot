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

@export var auto_free := true

var _catalog: RefCounted = CATALOG_SCRIPT.new()
var _profile: Dictionary = {}
var _profile_id := ""
var _sprites: Array[Sprite2D] = []
var _duration := 1.0
var _elapsed := 0.0
var _progress := 0.0
var _active := false
var _preview := false
var _direction := 1
var _active_scale := 1.0
var _impact_emitted := false
var _stage_name := STAGE_ANTICIPATION


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
	preview: bool = false
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
	_profile = profile
	_profile_id = profile_id
	_direction = -1 if direction < 0 else 1
	_preview = preview
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
