class_name EvolvedBackgroundAttack
extends Node2D

const ENERGY_GLOW_WIDTH := 26.0
const ENERGY_BODY_WIDTH := 10.0
const ENERGY_CORE_WIDTH := 4.5
const SACRED_BEATS := 3
const SUPPORTED_BLESSING_MOTIFS: Array[String] = [
	"pulse_ring",
	"echo_arc",
	"venom_orb",
	"bolt_chain",
	"gale_spiral",
	"crystal_shard",
	"tidal_wave",
	"radiant_cross",
]

var _profile: Dictionary = {}
var _local_targets: Array[Vector2] = []
var _elapsed := 0.0
var _duration := 0.96
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
	_duration = clampf(
		0.96 / maxf(1.0, float(_profile.get("rhythm_speed", 1.0))),
		0.32,
		0.96
	)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func get_pattern() -> StringName:
	return StringName(_profile.get("pattern", ""))


func get_energy_line_widths() -> PackedFloat32Array:
	return PackedFloat32Array([ENERGY_GLOW_WIDTH, ENERGY_BODY_WIDTH, ENERGY_CORE_WIDTH])


func get_cadence_profile() -> Dictionary:
	return {
		"beats": SACRED_BEATS,
		"duration": _duration,
		"sacred_halo": true,
	}


func get_supported_blessing_motifs() -> Array[String]:
	return SUPPORTED_BLESSING_MOTIFS.duplicate()


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
	return mini(4, maxi(1, int(_profile.get("instance_count", 1)))) if _subject_texture != null else 0


func debug_set_progress(progress: float) -> void:
	_elapsed = clampf(progress, 0.0, 0.999) * _duration
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if _profile.is_empty():
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var beat_progress := fmod(progress * float(SACRED_BEATS), 1.0)
	var beat_pulse := pow(1.0 - beat_progress, 2.0)
	var alpha := clampf(sin(progress * PI) * 0.76 + beat_pulse * 0.48, 0.0, 1.0)
	var color := Color(_accent, alpha)
	_draw_sacred_cadence(progress, alpha)
	match String(_profile.get("pattern", "")):
		"chain_barrage":
			_draw_chain_barrage(color, progress)
		"abyss_nova":
			_draw_abyss_nova(color, progress)
		"venom_gale":
			_draw_venom_gale(color, progress)
		"prismatic_orbit":
			_draw_prismatic_orbit(color, progress)
	_draw_geometry_modules(progress, alpha)
	_draw_concrete_subjects(progress, alpha)


func _draw_concrete_subjects(progress: float, alpha: float) -> void:
	if _subject_texture == null:
		return
	var motion := String(_profile.get("subject_motion", "composite_orbit"))
	var count := mini(4, maxi(1, int(_profile.get("instance_count", 1))))
	var size_scale := clampf(float(_profile.get("size_scale", 0.72)), 0.5, 2.4)
	var base_width := clampf(90.0 * size_scale, 64.0, 216.0)
	var texture_aspect := float(_subject_texture.get_height()) / maxf(1.0, float(_subject_texture.get_width()))
	var subject_size := Vector2(base_width, base_width * texture_aspect)
	var rhythmic_alpha := clampf(alpha * (0.72 + 0.28 * sin(progress * PI)), 0.0, 1.0)
	for index in count:
		var phase := fmod(progress - float(index) * 0.055 + 1.0, 1.0)
		var target := _local_targets[index % _local_targets.size()] if not _local_targets.is_empty() else Vector2.ZERO
		var transform := _subject_transform(motion, phase, index, count, target, size_scale)
		var subject_position := transform.get("position", Vector2.ZERO) as Vector2
		var subject_rotation := float(transform.get("rotation", 0.0))
		var pulse_scale := float(transform.get("scale", 1.0)) * (0.86 + 0.14 * sin(phase * PI))
		var subject_alpha := rhythmic_alpha * float(transform.get("alpha", 1.0))
		draw_set_transform(subject_position, subject_rotation, Vector2.ONE * pulse_scale)
		draw_texture_rect(
			_subject_texture,
			Rect2(-subject_size * 0.5, subject_size),
			false,
			Color(1.0, 1.0, 1.0, subject_alpha)
		)
		if int(_profile.get("destruction_tier", 0)) >= 2:
			draw_set_transform(subject_position - Vector2.from_angle(subject_rotation) * 22.0, subject_rotation - 0.06, Vector2.ONE * pulse_scale * 1.06)
			draw_texture_rect(
				_subject_texture,
				Rect2(-subject_size * 0.5, subject_size),
				false,
				Color(_accent, subject_alpha * 0.12)
			)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _subject_transform(
	motion: String,
	phase: float,
	index: int,
	count: int,
	target: Vector2,
	size_scale: float
) -> Dictionary:
	var spread := (float(index) - float(count - 1) * 0.5)
	match motion:
		"chakram_orbit":
			return {"position": target * phase + Vector2.from_angle(phase * TAU * 1.8 + index) * 72.0 * size_scale, "rotation": phase * TAU * 3.0 + index, "scale": 0.82}
		"execution_slam":
			return {"position": target + Vector2(spread * 34.0, lerpf(-330.0, 12.0, ease(phase, -2.4))), "rotation": PI * 0.5 + spread * 0.05, "scale": 1.05}
		"feather_fan":
			var fan_angle := -0.72 + TAU * 0.23 * float(index) / float(maxi(1, count - 1))
			return {"position": Vector2.from_angle(fan_angle) * lerpf(30.0, 250.0, phase) + target * phase * 0.35, "rotation": fan_angle, "scale": 0.72}
		"trident_sweep":
			return {"position": Vector2(lerpf(-300.0, target.x, phase), target.y + spread * 34.0), "rotation": target.angle(), "scale": 0.86}
		"twin_saber_cross":
			return {"position": target * phase + Vector2(0.0, spread * 26.0), "rotation": target.angle() + (-0.62 if index % 2 == 0 else 0.62), "scale": 0.82}
		"crown_barrage":
			return {"position": target * 0.72 + Vector2.from_angle(phase * TAU + index * TAU / float(count)) * 82.0 * size_scale, "rotation": sin(phase * TAU) * 0.16, "scale": 0.72}
		"lightning_spear", "lance_rain":
			return {"position": target + Vector2(spread * 44.0, lerpf(-380.0 - absf(spread) * 44.0, 0.0, ease(phase, -3.0))), "rotation": PI * 0.5, "scale": 0.82}
		"warhorse_charge":
			return {"position": Vector2(lerpf(-420.0 - index * 70.0, target.x + 90.0, phase), target.y + spread * 30.0), "rotation": 0.0, "scale": 1.12}
		"reaper_harvest":
			var harvest_angle := lerpf(-PI * 0.92, PI * 0.18, phase) + spread * 0.08
			return {"position": target * 0.45 + Vector2.from_angle(harvest_angle) * 155.0 * size_scale, "rotation": harvest_angle + PI * 0.48, "scale": 1.0}
		_:
			return {"position": target * phase + Vector2.from_angle(phase * TAU + index) * 48.0 * size_scale, "rotation": phase * TAU, "scale": 0.9}


func _draw_sacred_cadence(progress: float, alpha: float) -> void:
	var beat_position := progress * float(SACRED_BEATS)
	var beat_index := mini(SACRED_BEATS - 1, floori(beat_position))
	var beat_progress := fmod(beat_position, 1.0)
	var pulse := pow(1.0 - beat_progress, 2.0)
	var radius := lerpf(44.0 + beat_index * 18.0, 132.0 + beat_index * 22.0, beat_progress)
	var rotation := -PI * 0.5 + beat_index * PI * 0.125
	var sacred_color := _accent.lightened(0.52)
	var beat_alpha := alpha * (0.24 + pulse * 0.24)
	_draw_energy_arc(radius, rotation, rotation + TAU, sacred_color, beat_alpha, 0.72)
	_draw_energy_arc(radius * 0.66, -rotation, -rotation + TAU * 0.92, sacred_color, beat_alpha * 0.72, 0.42)
	for node_index in 8:
		var direction := Vector2.from_angle(rotation + TAU * float(node_index) / 8.0)
		var node_position := direction * radius
		draw_circle(node_position, 13.0 + pulse * 5.0, Color(_accent, beat_alpha * 0.20))
		draw_circle(node_position, 6.0 + pulse * 2.0, Color(sacred_color, beat_alpha * 0.88))
		draw_circle(node_position, 2.5 + pulse, Color(1.0, 0.98, 0.88, beat_alpha))
	for ray_index in 4:
		var direction := Vector2.from_angle(rotation + TAU * float(ray_index) / 4.0)
		_draw_energy_line(
			direction * radius * 0.22,
			direction * radius * (0.78 + pulse * 0.16),
			sacred_color,
			beat_alpha * (0.52 + pulse * 0.38),
			0.34
		)


func _draw_energy_arc(
	radius: float,
	from_angle: float,
	to_angle: float,
	color: Color,
	alpha: float,
	width_scale: float
) -> void:
	draw_arc(Vector2.ZERO, radius, from_angle, to_angle, 56, Color(color, alpha * 0.24), ENERGY_GLOW_WIDTH * width_scale, true)
	draw_arc(Vector2.ZERO, radius, from_angle, to_angle, 56, Color(color, alpha * 0.88), ENERGY_BODY_WIDTH * width_scale, true)
	draw_arc(Vector2.ZERO, radius, from_angle, to_angle, 56, Color(color.lightened(0.82), alpha), ENERGY_CORE_WIDTH * width_scale, true)


func _draw_energy_line(
	from: Vector2,
	to: Vector2,
	color: Color,
	alpha: float,
	width_scale: float
) -> void:
	draw_line(from, to, Color(color, alpha * 0.22), ENERGY_GLOW_WIDTH * width_scale, true)
	draw_line(from, to, Color(color, alpha * 0.88), ENERGY_BODY_WIDTH * width_scale, true)
	draw_line(from, to, Color(color.lightened(0.82), alpha), ENERGY_CORE_WIDTH * width_scale, true)


func _draw_chain_barrage(color: Color, progress: float) -> void:
	var previous := Vector2.ZERO
	for point in _local_targets:
		var bend := (previous + point) * 0.5 + Vector2(0.0, -42.0 - 18.0 * progress)
		draw_polyline(PackedVector2Array([previous, bend, point]), color, 5.0, true)
		draw_circle(point, 12.0 + 18.0 * progress, Color(color, color.a * 0.55), false, 3.0)
		previous = point


func _draw_abyss_nova(color: Color, progress: float) -> void:
	var radius := lerpf(36.0, 270.0, progress)
	draw_circle(Vector2.ZERO, radius, Color(color, color.a * 0.32), false, 9.0)
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.08, 0.04, 0.18, color.a * 0.58), false, 12.0)
	for point in _local_targets:
		draw_line(Vector2.ZERO, point, Color(color, color.a * 0.35), 2.0)


func _draw_venom_gale(color: Color, progress: float) -> void:
	for index in _local_targets.size():
		var point := _local_targets[index]
		var tangent := Vector2(-point.y, point.x).normalized() * (24.0 + index * 5.0)
		draw_polyline(
			PackedVector2Array([Vector2.ZERO, point * 0.5 + tangent, point]),
			color,
			7.0 - 3.0 * progress,
			true
		)


func _draw_prismatic_orbit(color: Color, progress: float) -> void:
	var radius := lerpf(52.0, 150.0, progress)
	draw_arc(Vector2.ZERO, radius, _elapsed * 5.0, _elapsed * 5.0 + TAU * 0.78, 48, color, 6.0, true)
	for point in _local_targets:
		draw_line(Vector2.ZERO, point, Color(color, color.a * 0.42), 3.0)
		draw_circle(point, 9.0, color)


func _draw_geometry_modules(progress: float, alpha: float) -> void:
	var modules := _profile.get("geometry_modules", []) as Array
	if modules.is_empty():
		return
	var size_scale := clampf(float(_profile.get("size_scale", 0.72)), 0.5, 4.2)
	var instance_count := clampi(int(_profile.get("instance_count", 1)), 1, 12)
	var rhythm_speed := clampf(float(_profile.get("rhythm_speed", 1.0)), 1.0, 3.5)
	for instance_index in instance_count:
		var instance_angle := TAU * float(instance_index) / float(instance_count)
		var orbit_radius := 0.0 if instance_count == 1 else 34.0 * size_scale * sqrt(float(instance_index + 1))
		var origin := Vector2.from_angle(instance_angle + _elapsed * rhythm_speed * 0.55) * orbit_radius
		var instance_scale := 0.82 + 0.18 * sin(progress * PI + instance_index * 0.7)
		draw_set_transform(origin, instance_angle * 0.25, Vector2.ONE * instance_scale)
		for index in modules.size():
			var module := modules[index] as Dictionary
			var module_color := Color.from_string(
				String(module.get("color", _accent.to_html(false))),
				_accent
			)
			var motif := String(module.get("motif", "pulse_ring"))
			var radius := lerpf(58.0 + index * 22.0, 142.0 + index * 34.0, progress) * size_scale
			var angle := _elapsed * rhythm_speed * (3.8 if index % 2 == 0 else -3.1) + index * PI
			_draw_motif(motif, Color(module_color, alpha * 0.30), radius, angle, ENERGY_GLOW_WIDTH)
			_draw_motif(motif, Color(module_color.lightened(0.18), alpha * 0.92), radius, angle, ENERGY_BODY_WIDTH)
			_draw_motif(motif, Color(module_color.lightened(0.78), alpha), radius, angle, ENERGY_CORE_WIDTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_motif(motif: String, color: Color, radius: float, angle: float, width: float) -> void:
	match motif:
		"pulse_ring":
			for band in 3:
				var band_radius := radius * (0.58 + float(band) * 0.21)
				draw_arc(Vector2.ZERO, band_radius, angle + band * 0.18, angle + TAU * (0.62 + band * 0.08), 42, color, maxf(1.0, width - band * 0.8), true)
			for spoke in 6:
				var direction := Vector2.from_angle(angle + TAU * float(spoke) / 6.0)
				draw_line(direction * radius * 0.78, direction * radius * 1.08, color, width * 0.72, true)
		"echo_arc":
			for echo_index in 4:
				var echo_radius := radius * (0.48 + echo_index * 0.16)
				var echo_angle := angle - echo_index * 0.24
				draw_arc(Vector2(-radius * 0.16 + echo_index * radius * 0.10, 0.0).rotated(angle), echo_radius, echo_angle - 0.82, echo_angle + 0.82, 28, color, maxf(1.0, width - echo_index * 0.7), true)
		"drum_pulse", "crown_spokes":
			draw_arc(Vector2.ZERO, radius, angle, angle + TAU * 0.82, 40, color, width, true)
			var spoke_count := 8 if motif == "crown_spokes" else 5
			for spoke in spoke_count:
				var direction := Vector2.from_angle(angle + TAU * float(spoke) / float(spoke_count))
				draw_line(direction * radius * 0.72, direction * radius, color, width * 0.66, true)
		"bolt_chain", "choir_bolts", "dawn_blades":
			var points := PackedVector2Array()
			for step in 6:
				var direction := Vector2.from_angle(angle + (0.18 if step % 2 == 0 else -0.12))
				points.append(direction * radius * float(step) / 5.0 + Vector2.from_angle(angle + PI * 0.5) * (12.0 if step % 2 == 0 else -12.0))
			draw_polyline(points, color, width, true)
		"crystal_shard":
			for shard_index in 4:
				var direction := Vector2.from_angle(angle + TAU * float(shard_index) / 4.0)
				var tangent := direction.rotated(PI * 0.5)
				var shard := PackedVector2Array([
					direction * radius,
					tangent * radius * 0.16,
					-direction * radius * 0.34,
					-tangent * radius * 0.16,
					direction * radius,
				])
				draw_polyline(shard, color, width, true)
		"mirror_shards", "iron_polygon", "void_diamond":
			var sides := 4 if motif != "iron_polygon" else 6
			var polygon := PackedVector2Array()
			for side in sides:
				var side_radius := radius if side % 2 == 0 else radius * 0.62
				polygon.append(Vector2.from_angle(angle + TAU * float(side) / float(sides)) * side_radius)
			polygon.append(polygon[0])
			draw_polyline(polygon, color, width, true)
		"tidal_wave":
			for band in 3:
				var center := Vector2(0.0, radius * (float(band) - 1.0) * 0.18).rotated(angle)
				draw_arc(center, radius * (0.58 + band * 0.18), angle - 0.18 + band * 0.12, angle + PI * 1.08 + band * 0.12, 30, color, maxf(1.0, width - band), true)
		"gale_spiral":
			for arm_index in 3:
				var points := PackedVector2Array()
				for step in 18:
					var step_ratio := float(step) / 17.0
					points.append(Vector2.from_angle(angle + arm_index * TAU / 3.0 + step_ratio * PI * 1.55) * radius * step_ratio)
				draw_polyline(points, color, maxf(1.0, width - arm_index * 0.6), true)
		"moon_waves":
			for band in 3:
				draw_arc(Vector2.ZERO, radius * (0.58 + band * 0.2), angle + band * 0.35, angle + PI * 1.18 + band * 0.35, 28, color, maxf(1.0, width - band), true)
		"radiant_cross":
			for axis in 2:
				var direction := Vector2.from_angle(angle + axis * PI * 0.5)
				draw_line(-direction * radius, direction * radius, color, width, true)
		"venom_orb", "venom_petals":
			var petals := 7 if motif == "venom_petals" else 5
			for petal in petals:
				var center := Vector2.from_angle(angle + TAU * float(petal) / float(petals)) * radius * 0.62
				draw_circle(center, radius * 0.20, color, false, width, true)
		"feather_fan":
			for feather in 7:
				var direction := Vector2.from_angle(angle - 0.7 + feather * 0.23)
				draw_line(direction * radius * 0.28, direction * radius, color, width, true)
		"abyss_eye":
			var eye := PackedVector2Array()
			for point_index in 33:
				var theta := TAU * float(point_index) / 32.0
				eye.append(Vector2(cos(theta) * radius, sin(theta) * radius * 0.42).rotated(angle))
			draw_polyline(eye, color, width, true)
			draw_circle(Vector2.ZERO, radius * 0.22, color, false, width, true)
		"star_compass":
			var star := PackedVector2Array()
			for point_index in 9:
				var point_radius := radius if point_index % 2 == 0 else radius * 0.42
				star.append(Vector2.from_angle(angle + TAU * float(point_index) / 8.0) * point_radius)
			draw_polyline(star, color, width, true)
		_:
			draw_arc(Vector2.ZERO, radius, angle, angle + TAU * 0.75, 36, color, width, true)
