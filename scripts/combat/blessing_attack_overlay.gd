class_name BlessingAttackOverlay
extends Node2D

const MAX_TOTAL_OBJECTS := 12

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
	var growth_count := (
		1
		+ level - 1
		+ floori(float(_combo_tier) / 2.0)
		+ floori(float(_stack_count) / 6.0)
	)
	var per_profile_limit := maxi(
		1,
		floori(float(MAX_TOTAL_OBJECTS) / maxf(1.0, _profiles.size()))
	)
	return clampi(growth_count, 1, per_profile_limit)


func _draw_object(
	profile: Dictionary,
	texture: Texture2D,
	profile_index: int,
	copy_index: int,
	copy_count: int
) -> void:
	var level := clampi(int(profile.get("level", 1)), 1, 3)
	var delay := float(copy_index) * (0.045 + float(profile_index) * 0.008)
	var motion := clampf((_travel_progress - delay) / maxf(0.35, 1.0 - delay), 0.0, 1.0)
	var side := -1.0 if copy_index % 2 == 0 else 1.0
	var lane := side * (10.0 + float((copy_index + 1) / 2) * 12.0)
	var perpendicular := _target_offset.normalized().orthogonal()
	var arc := perpendicular * lane * sin(motion * PI)
	var start_offset := perpendicular * lane * 0.35 - _target_offset.normalized() * float(copy_index) * 5.0
	var object_position := start_offset.lerp(_target_offset, motion) + arc
	if _impact_progress > 0.0:
		var burst_angle := TAU * float(copy_index) / float(maxi(1, copy_count))
		object_position = _target_offset + Vector2.from_angle(burst_angle) * (
			18.0 + 42.0 * _impact_progress
		)
	var direction_angle := _target_offset.angle()
	var spin := (motion * TAU * (0.30 + level * 0.13)) * side
	if String(profile.get("element", "")) in ["wind", "water", "ice"]:
		spin *= 0.32
	var scale_growth := 1.0 + float(level - 1) * 0.10 + float(_combo_tier) * 0.06
	# Stack/combo escalation is expressed mainly through count and cadence. A hard
	# silhouette cap keeps the basic attack, wielder and contact point readable.
	var width := clampf(42.0 * minf(_attack_scale, 1.5) * scale_growth, 36.0, 96.0)
	var aspect := float(texture.get_height()) / maxf(1.0, float(texture.get_width()))
	var size := Vector2(width, width * aspect)
	var alpha := sin(motion * PI) if _impact_progress <= 0.0 else 1.0 - _impact_progress
	var accent := Color.from_string(String(profile.get("accent_color", "#ffffff")), Color.WHITE)
	var modulate := Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 0.94))
	draw_set_transform(object_position, direction_angle + spin, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, modulate)
	if level >= 2 or _combo_tier >= 1:
		var ghost_alpha := modulate.a * (0.10 + float(level - 1) * 0.035)
		draw_set_transform(object_position - _target_offset.normalized() * 14.0, direction_angle + spin - side * 0.08, Vector2.ONE * 1.08)
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(accent, ghost_alpha))
