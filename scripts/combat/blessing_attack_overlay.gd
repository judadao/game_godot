class_name BlessingAttackOverlay
extends Node2D

const MAX_TOTAL_OBJECTS := 6
const MAX_COPIES_PER_PROFILE := 2
const MIN_OBJECT_WIDTH := 84.0
const MAX_OBJECT_WIDTH := 176.0

var _profiles: Array[Dictionary] = []
var _textures: Array[Texture2D] = []
var _target_offset := Vector2.ZERO
var _stack_count := 0
var _attack_scale := 1.0
var _combo_tier := 0
var _travel_progress := 0.0
var _impact_progress := 0.0


func configure(
	profiles: Array,
	target_offset: Vector2,
	stack_count: int,
	attack_scale: float,
	combo_tier: int
) -> void:
	_profiles.clear()
	_textures.clear()
	_target_offset = target_offset
	_stack_count = maxi(0, stack_count)
	_attack_scale = maxf(0.5, attack_scale)
	_combo_tier = clampi(combo_tier, 0, 3)
	for profile_variant in profiles:
		if not profile_variant is Dictionary:
			continue
		var profile := (profile_variant as Dictionary).duplicate(true)
		var asset_path := String(profile.get("asset_path", ""))
		if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
			continue
		var texture := load(asset_path) as Texture2D
		if texture == null:
			continue
		_profiles.append(profile)
		_textures.append(texture)
	queue_redraw()


func set_progress(travel_progress: float, impact_progress: float) -> void:
	_travel_progress = clampf(travel_progress, 0.0, 1.0)
	_impact_progress = clampf(impact_progress, 0.0, 1.0)
	queue_redraw()


func get_profile_count() -> int:
	return _profiles.size()


func get_object_count() -> int:
	var total := 0
	for profile in _profiles:
		total += _copy_count(profile)
	return mini(total, MAX_TOTAL_OBJECTS)


func get_asset_paths() -> Array[String]:
	var paths: Array[String] = []
	for profile in _profiles:
		paths.append(String(profile.get("asset_path", "")))
	return paths


func get_motion_names() -> Array[StringName]:
	var motions: Array[StringName] = []
	for profile in _profiles:
		motions.append(StringName(profile.get("motion", "direct_growth")))
	return motions


func get_object_width_range() -> Vector2:
	return Vector2(MIN_OBJECT_WIDTH, MAX_OBJECT_WIDTH)


func _draw() -> void:
	if _profiles.is_empty():
		return
	var drawn := 0
	for profile_index in _profiles.size():
		var profile := _profiles[profile_index]
		var texture := _textures[profile_index]
		var copies := _copy_count(profile)
		for copy_index in copies:
			if drawn >= MAX_TOTAL_OBJECTS:
				return
			_draw_object(profile, texture, profile_index, copy_index, copies)
			drawn += 1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _copy_count(profile: Dictionary) -> int:
	var level := clampi(int(profile.get("level", 1)), 1, 3)
	var growth_count := 1
	if level >= 3 or _combo_tier >= 3 or _stack_count >= 12:
		growth_count += 1
	var fair_limit := maxi(1, floori(float(MAX_TOTAL_OBJECTS) / maxf(1.0, _profiles.size())))
	return clampi(growth_count, 1, mini(MAX_COPIES_PER_PROFILE, fair_limit))


func _draw_object(
	profile: Dictionary,
	texture: Texture2D,
	profile_index: int,
	copy_index: int,
	copy_count: int
) -> void:
	var level := clampi(int(profile.get("level", 1)), 1, 3)
	var delay := float(copy_index) * 0.14 + float(profile_index) * 0.035
	var phase := clampf((_travel_progress - delay) / maxf(0.48, 1.0 - delay), 0.0, 1.0)
	var motion := String(profile.get("motion", "direct_growth"))
	var pose := _motion_pose(motion, phase, copy_index, copy_count)
	var accent := Color.from_string(String(profile.get("accent_color", "#ffffff")), Color.WHITE)
	var scale_growth := 1.0 + float(level - 1) * 0.16 + float(_combo_tier) * 0.07
	var evolved_scale := 1.22 if bool(profile.get("evolved", false)) else 1.0
	var width := clampf(94.0 * minf(_attack_scale, 1.55) * scale_growth * evolved_scale, MIN_OBJECT_WIDTH, MAX_OBJECT_WIDTH)
	var aspect := float(texture.get_height()) / maxf(1.0, float(texture.get_width()))
	var size := Vector2(width, width * aspect)
	var impact_scale := 1.0
	var alpha := float(pose.get("alpha", sin(phase * PI)))
	var tint_strength := float(pose.get("tint", 0.0))
	if _impact_progress > 0.0:
		impact_scale = lerpf(1.0, 1.52 + float(level - 1) * 0.12, _impact_progress)
		alpha = 1.0 - _impact_progress
		tint_strength = maxf(tint_strength, _impact_progress * 0.64)
	var tint := Color.WHITE.lerp(accent.lightened(0.24), tint_strength)
	draw_set_transform(
		pose.get("position", Vector2.ZERO) as Vector2,
		float(pose.get("rotation", 0.0)),
		Vector2.ONE * float(pose.get("scale", 1.0)) * impact_scale
	)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(tint, clampf(alpha, 0.0, 0.98)))
	if level >= 3 and _impact_progress <= 0.0:
		var direction := _safe_direction()
		draw_set_transform(
			(pose.get("position", Vector2.ZERO) as Vector2) - direction * 28.0,
			float(pose.get("rotation", 0.0)),
			Vector2.ONE * float(pose.get("scale", 1.0)) * 1.08
		)
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(accent, alpha * 0.11))


func _motion_pose(motion: String, phase: float, index: int, count: int) -> Dictionary:
	var direction := _safe_direction()
	var perpendicular := direction.orthogonal()
	var spread := float(index) - float(count - 1) * 0.5
	var fade := sin(phase * PI)
	match motion:
		"fire_blade_growth":
			return {"position": _target_offset * phase, "rotation": direction.angle(), "scale": lerpf(0.70, 1.34, phase), "alpha": fade, "tint": phase * 0.38}
		"shadow_recall":
			var recall_phase := phase / 0.68 if phase <= 0.68 else 1.0 - (phase - 0.68) / 0.32 * 0.16
			return {"position": _target_offset * recall_phase + perpendicular * spread * 48.0, "rotation": direction.angle() + PI * phase * 0.42, "scale": lerpf(0.82, 1.18, phase), "alpha": fade, "tint": 0.32 + phase * 0.36}
		"venom_seed_bloom":
			return {"position": _target_offset * phase - Vector2(0.0, sin(phase * PI) * (92.0 + absf(spread) * 24.0)), "rotation": phase * TAU * 0.58, "scale": lerpf(0.68, 1.42, phase), "alpha": fade, "tint": phase * 0.28}
		"lightning_blink":
			var stepped := minf(1.0, floor(phase * 5.0) / 4.0)
			var zigzag := perpendicular * (32.0 if int(floor(phase * 5.0)) % 2 == 0 else -32.0)
			return {"position": _target_offset * stepped + zigzag * (1.0 - stepped), "rotation": direction.angle(), "scale": 1.12 + sin(phase * TAU * 2.0) * 0.12, "alpha": 0.62 + 0.38 * absf(sin(phase * TAU * 5.0)), "tint": 0.62}
		"feather_fan":
			var arc_side := -1.0 if index % 2 == 0 else 1.0
			return {"position": _target_offset * phase + perpendicular * arc_side * sin(phase * PI) * (68.0 + absf(spread) * 30.0), "rotation": direction.angle() + arc_side * 0.34 * cos(phase * PI), "scale": lerpf(0.78, 1.18, phase), "alpha": fade}
		"frost_rise":
			return {"position": _target_offset + Vector2(spread * 72.0, lerpf(118.0, -8.0, ease(phase, -1.8))), "rotation": -PI * 0.5, "scale": lerpf(0.62, 1.46, phase), "alpha": fade, "tint": phase * 0.52}
		"tide_boomerang":
			return {"position": _target_offset * phase + perpendicular * sin(phase * PI) * (116.0 + spread * 32.0), "rotation": direction.angle() + phase * TAU * 0.72, "scale": lerpf(0.82, 1.28, phase), "alpha": fade, "tint": phase * 0.28}
		"sunfall":
			return {"position": _target_offset + Vector2(spread * 78.0, lerpf(-300.0, 0.0, ease(phase, -2.4))), "rotation": PI * 0.5, "scale": lerpf(0.76, 1.52, phase), "alpha": fade, "tint": phase * 0.72}
		"execution_slam", "lightning_spear", "lance_rain":
			return {"position": _target_offset + Vector2(spread * 80.0, lerpf(-320.0, 0.0, ease(phase, -2.2))), "rotation": PI * 0.5, "scale": lerpf(0.86, 1.38, phase), "alpha": fade, "tint": phase * 0.5}
		"warhorse_charge", "trident_sweep":
			return {"position": Vector2(lerpf(-380.0, _target_offset.x + 50.0, phase), _target_offset.y + spread * 70.0), "rotation": 0.0 if motion == "warhorse_charge" else direction.angle(), "scale": lerpf(0.92, 1.36, phase), "alpha": fade}
		"reaper_harvest", "chakram_orbit", "crown_barrage":
			var angle := lerpf(-PI * 0.92, PI * 0.12, phase) + spread * 0.16
			return {"position": _target_offset * 0.52 + Vector2.from_angle(angle) * 164.0, "rotation": angle + PI * 0.5, "scale": lerpf(0.86, 1.42, phase), "alpha": fade, "tint": phase * 0.55}
		"twin_saber_cross":
			return {"position": _target_offset * phase + perpendicular * spread * 72.0, "rotation": direction.angle() + (-0.64 if index % 2 == 0 else 0.64), "scale": lerpf(0.88, 1.32, phase), "alpha": fade}
		_:
			return {"position": _target_offset * phase, "rotation": direction.angle(), "scale": lerpf(0.8, 1.25, phase), "alpha": fade}


func _safe_direction() -> Vector2:
	var direction := _target_offset.normalized()
	return Vector2.RIGHT if direction.is_zero_approx() else direction
