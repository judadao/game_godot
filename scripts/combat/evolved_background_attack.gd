class_name EvolvedBackgroundAttack
extends Node2D

var _profile: Dictionary = {}
var _local_targets: Array[Vector2] = []
var _elapsed := 0.0
var _duration := 0.72
var _accent := Color(0.94, 0.36, 1.0, 1.0)


func play(profile: Dictionary, world_targets: Array[Vector2]) -> void:
	_profile = profile.duplicate(true)
	_accent = Color.from_string(String(profile.get("accent_color", "#f05cff")), _accent)
	_local_targets.clear()
	for world_position in world_targets:
		_local_targets.append(to_local(world_position))
	_elapsed = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func get_pattern() -> StringName:
	return StringName(_profile.get("pattern", ""))


func _draw() -> void:
	if _profile.is_empty():
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var alpha := sin(progress * PI)
	var color := Color(_accent, alpha)
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
	for index in modules.size():
		var module := modules[index] as Dictionary
		var module_color := Color.from_string(
			String(module.get("color", _accent.to_html(false))),
			_accent
		)
		var motif := String(module.get("motif", "pulse_ring"))
		var radius := lerpf(58.0 + index * 22.0, 142.0 + index * 34.0, progress)
		var angle := _elapsed * (3.8 if index % 2 == 0 else -3.1) + index * PI
		_draw_motif(motif, Color(module_color, alpha * 0.16), radius, angle, 14.0)
		_draw_motif(motif, Color(module_color.lightened(0.28), alpha * 0.92), radius, angle, 3.2)


func _draw_motif(motif: String, color: Color, radius: float, angle: float, width: float) -> void:
	match motif:
		"pulse_ring", "drum_pulse", "crown_spokes":
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
		"crystal_shard", "mirror_shards", "iron_polygon", "void_diamond":
			var sides := 4 if motif != "iron_polygon" else 6
			var polygon := PackedVector2Array()
			for side in sides:
				var side_radius := radius if side % 2 == 0 else radius * 0.62
				polygon.append(Vector2.from_angle(angle + TAU * float(side) / float(sides)) * side_radius)
			polygon.append(polygon[0])
			draw_polyline(polygon, color, width, true)
		"tidal_wave", "moon_waves", "gale_spiral":
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
