class_name EvolvedBackgroundAttack
extends Node2D

const MAX_SUBJECTS := 2
const MIN_DURATION := 1.25
const MAX_DURATION := 1.65

var _profile: Dictionary = {}
var _local_targets: Array[Vector2] = []
var _elapsed := 0.0
var _duration := MAX_DURATION
var _accent := Color(0.94, 0.36, 1.0, 1.0)
var _subject_texture: Texture2D


func play(profile: Dictionary, world_targets: Array[Vector2]) -> void:
	_profile = profile.duplicate(true)
	_accent = Color.from_string(String(profile.get("accent_color", "#f05cff")), _accent)
	_subject_texture = null
	var subject_path := String(profile.get("subject_asset_path", ""))
	if not subject_path.is_empty() and ResourceLoader.exists(subject_path):
		_subject_texture = load(subject_path) as Texture2D
	_local_targets.clear()
	for world_position in world_targets:
		_local_targets.append(to_local(world_position))
	_elapsed = 0.0
	var rhythm_speed := clampf(float(_profile.get("rhythm_speed", 1.0)), 1.0, 3.5)
	_duration = clampf(MAX_DURATION / (0.82 + rhythm_speed * 0.18), MIN_DURATION, MAX_DURATION)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func get_pattern() -> StringName:
	return StringName(_profile.get("pattern", ""))


func get_runtime_escalation() -> Dictionary:
	return {
		"size_scale": float(_profile.get("size_scale", 0.72)),
		"instance_count": int(_profile.get("instance_count", 1)),
		"rhythm_speed": float(_profile.get("rhythm_speed", 1.0)),
		"destruction_tier": int(_profile.get("destruction_tier", 0)),
	}


func get_subject_asset_path() -> String:
	return String(_profile.get("subject_asset_path", ""))


func get_subject_motion() -> StringName:
	return StringName(_profile.get("subject_motion", ""))


func get_subject_instance_count() -> int:
	return mini(MAX_SUBJECTS, maxi(1, int(_profile.get("instance_count", 1)))) if _subject_texture != null else 0


func get_attack_duration() -> float:
	return _duration


func uses_abstract_geometry() -> bool:
	return false


func debug_set_progress(progress: float) -> void:
	_elapsed = clampf(progress, 0.0, 0.999) * _duration
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if _profile.is_empty() or _subject_texture == null:
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var motion := String(_profile.get("subject_motion", "composite_orbit"))
	var count := get_subject_instance_count()
	var size_scale := clampf(float(_profile.get("size_scale", 0.72)), 0.5, 2.4)
	var base_width := clampf(154.0 * size_scale, 124.0, 320.0)
	var aspect := float(_subject_texture.get_height()) / maxf(1.0, float(_subject_texture.get_width()))
	var subject_size := Vector2(base_width, base_width * aspect)
	for index in count:
		var delayed := clampf((progress - float(index) * 0.14) / (1.0 - float(index) * 0.14), 0.0, 1.0)
		var target := _local_targets[index % _local_targets.size()] if not _local_targets.is_empty() else Vector2(220.0, 0.0)
		var pose := _subject_pose(motion, delayed, index, count, target, size_scale)
		var subject_alpha := float(pose.get("alpha", sin(delayed * PI)))
		var tint_strength := float(pose.get("tint", 0.0))
		var tint := Color.WHITE.lerp(_accent.lightened(0.28), tint_strength)
		draw_set_transform(
			pose.get("position", Vector2.ZERO) as Vector2,
			float(pose.get("rotation", 0.0)),
			Vector2.ONE * float(pose.get("scale", 1.0))
		)
		draw_texture_rect(
			_subject_texture,
			Rect2(-subject_size * 0.5, subject_size),
			false,
			Color(tint, clampf(subject_alpha, 0.0, 1.0))
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _subject_pose(
	motion: String,
	phase: float,
	index: int,
	count: int,
	target: Vector2,
	size_scale: float
) -> Dictionary:
	var spread := float(index) - float(count - 1) * 0.5
	var fade := sin(clampf(phase, 0.0, 1.0) * PI)
	match motion:
		"chakram_orbit":
			return {"position": target * 0.72 + Vector2.from_angle(phase * TAU * 0.85 + index * PI) * lerpf(120.0, 34.0, phase) * size_scale, "rotation": phase * TAU * 1.7, "scale": lerpf(0.76, 1.28, phase), "alpha": fade, "tint": phase * 0.32}
		"execution_slam":
			return {"position": target + Vector2(spread * 88.0, lerpf(-430.0, 16.0, ease(phase, -2.2))), "rotation": PI * 0.5, "scale": lerpf(1.18, 1.52, phase), "alpha": fade, "tint": phase * 0.46}
		"feather_fan":
			var angle := lerpf(-0.82, 0.24, float(index) / float(maxi(1, count - 1)))
			return {"position": Vector2.from_angle(angle) * lerpf(28.0, 330.0, phase) + target * phase * 0.24, "rotation": angle + sin(phase * PI) * 0.22, "scale": lerpf(0.82, 1.22, phase), "alpha": fade}
		"trident_sweep":
			return {"position": Vector2(lerpf(-390.0, target.x + 55.0, phase), target.y + spread * 86.0 - sin(phase * PI) * 54.0), "rotation": target.angle() + 0.10, "scale": 1.20, "alpha": fade}
		"twin_saber_cross":
			return {"position": target * phase + Vector2(0.0, spread * 86.0), "rotation": target.angle() + (-0.72 if index % 2 == 0 else 0.72), "scale": lerpf(0.92, 1.32, phase), "alpha": fade, "tint": phase * 0.28}
		"crown_barrage":
			return {"position": target * 0.74 + Vector2.from_angle(phase * TAU * 0.55 + index * PI) * lerpf(130.0, 62.0, phase), "rotation": sin(phase * TAU) * 0.14, "scale": lerpf(0.88, 1.38, phase), "alpha": fade, "tint": phase * 0.52}
		"lightning_spear", "lance_rain":
			return {"position": target + Vector2(spread * 92.0, lerpf(-480.0 - absf(spread) * 70.0, 8.0, ease(phase, -2.6))), "rotation": PI * 0.5, "scale": lerpf(0.98, 1.46, phase), "alpha": fade, "tint": phase * 0.40}
		"warhorse_charge":
			return {"position": Vector2(lerpf(-520.0 - index * 140.0, target.x + 130.0, phase), target.y + spread * 84.0), "rotation": 0.0, "scale": lerpf(1.18, 1.52, phase), "alpha": fade}
		"reaper_harvest":
			var harvest_angle := lerpf(-PI * 0.95, PI * 0.14, phase) + spread * 0.14
			return {"position": target * 0.48 + Vector2.from_angle(harvest_angle) * 210.0 * size_scale, "rotation": harvest_angle + PI * 0.48, "scale": lerpf(1.0, 1.48, phase), "alpha": fade, "tint": phase * 0.62}
		_:
			return {"position": target * phase, "rotation": target.angle(), "scale": lerpf(0.9, 1.3, phase), "alpha": fade}
