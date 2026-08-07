class_name LayeredSeriesMaterialVFX2D
extends Node2D

@export_enum("fire", "lightning", "water_flow", "dragon_breath", "dawn_vitality", "shared_branch_vitality") var visual_family := "fire"

@onready var energy_contour: Line2D = $EnergyContour
@onready var motion_trail: Line2D = $MotionTrail
@onready var accent_line: Line2D = $AccentLine
@onready var motes: GPUParticles2D = $Motes

var _tier_rank := 1
var _palette: Array[Color] = [Color.WHITE, Color.CYAN, Color.DARK_BLUE]
var _parameters: Dictionary = {}
var _target_positions: Array[Vector2] = []
var _progress := 0.0
var _configured := false
var _source_sprites: Array[Sprite2D] = []


func _ready() -> void:
	clear()


func configure(
	source_sprites: Array,
	tier_rank: int,
	palette_values: Array,
	parameters: Dictionary,
	target_positions: Array = []
) -> void:
	clear()
	_tier_rank = clampi(tier_rank, 1, 3)
	_parameters = parameters.duplicate(true)
	_palette = _resolve_palette(palette_values)
	_target_positions.clear()
	for value in target_positions:
		if value is Vector2:
			_target_positions.append(value)
	_source_sprites.clear()
	for sprite_variant in source_sprites:
		if sprite_variant is Sprite2D:
			var sprite := sprite_variant as Sprite2D
			sprite.visible = false
			_source_sprites.append(sprite)
	_configure_lines()
	_configure_motes()
	_configured = true
	visible = true
	set_progress(0.0)


func clear() -> void:
	_configured = false
	visible = false
	_progress = 0.0
	_target_positions.clear()
	for line in [energy_contour, motion_trail, accent_line]:
		if line != null:
			line.clear_points()
	if motes != null:
		motes.emitting = false
	queue_redraw()


func set_progress(value: float) -> void:
	if not _configured:
		return
	_progress = clampf(value, 0.0, 1.0)
	_update_line_geometry()
	if motes != null:
		motes.modulate.a = sin(_progress * PI) if visual_family not in ["dawn_vitality", "shared_branch_vitality"] else minf(1.0, _progress * 5.0)
	queue_redraw()


func get_active_layer_count() -> int:
	return 5 if _configured else 0


func get_debug_state() -> Dictionary:
	return {
		"visual_family": visual_family,
		"tier_rank": _tier_rank,
		"progress": _progress,
		"layer_count": get_active_layer_count(),
		"procedural_material": true,
		"blessing_mutable": true,
		"target_marker_count": _target_positions.size(),
		"parameters": _parameters.duplicate(true),
	}


func _draw() -> void:
	if not _configured:
		return
	match visual_family:
		"fire": _draw_fire_pillars()
		"lightning": _draw_residual_lightning()
		"water_flow": _draw_tidal_push()
		"dragon_breath": _draw_dragon_breath()
		"dawn_vitality": _draw_healing_zone()
		"shared_branch_vitality": _draw_body_overdrive()


func _configure_lines() -> void:
	energy_contour.default_color = _palette[0]
	motion_trail.default_color = Color(_palette[1], 0.72)
	accent_line.default_color = Color(_palette[2], 0.82)
	energy_contour.width = 7.0 + float(_tier_rank) * 2.0
	motion_trail.width = 16.0 + float(_tier_rank) * 3.0
	accent_line.width = 3.0 + float(_tier_rank)


func _configure_motes() -> void:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = float(_parameters.get("radius", 160.0)) * 0.72
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 42.0
	material.initial_velocity_min = 26.0
	material.initial_velocity_max = 78.0 + _tier_rank * 14.0
	material.gravity = Vector3(0.0, -12.0 if visual_family == "fire" else -4.0, 0.0)
	material.scale_min = 2.0
	material.scale_max = 5.0 + _tier_rank
	material.color = _palette[1]
	motes.process_material = material
	motes.amount = maxi(12, int(_parameters.get("mote_count", _parameters.get("object_count", 8))) * 3)
	motes.lifetime = 1.1
	motes.emitting = true


func _update_line_geometry() -> void:
	var radius := float(_parameters.get("radius", 280.0))
	match visual_family:
		"fire":
			var count := maxi(5, int(_parameters.get("pillar_count", 5)))
			_set_line_points(energy_contour, [Vector2(-radius, 0), Vector2(radius, 0)])
			_set_line_points(motion_trail, [Vector2(-radius * 0.75, -8), Vector2(radius * 0.75, -8)])
			_set_line_points(accent_line, [Vector2(-radius, 6), Vector2(-radius + radius * 2.0 * minf(1.0, _progress * float(count) / maxf(1.0, float(count))), 6)])
		"lightning":
			var points: Array[Vector2] = [Vector2.ZERO]
			for target_position in _resolved_target_positions(8 + _tier_rank * 6):
				points.append(target_position)
			_set_line_points(energy_contour, _jagged(points, 12.0))
			_set_line_points(motion_trail, points)
			_set_line_points(accent_line, _jagged(points, 5.0))
		"water_flow":
			_set_line_points(energy_contour, _arc_points(radius, -22.0, 18))
			_set_line_points(motion_trail, _arc_points(radius * 0.86, -4.0, 16))
			_set_line_points(accent_line, _arc_points(radius * 0.70, -36.0, 14))
		"dragon_breath":
			var sweep := sin(minf(1.0, _progress * 3.2) * PI * 0.5)
			_set_line_points(energy_contour, [Vector2.ZERO, Vector2(cos(PI * (1.0 - sweep)) * radius, -64.0 - sin(PI * sweep) * 55.0)])
			_set_line_points(motion_trail, [Vector2.ZERO, Vector2(cos(PI * sweep) * radius, -20.0)])
			_set_line_points(accent_line, _arc_points(radius * 0.78, -58.0, 20))
		"dawn_vitality", "shared_branch_vitality":
			_set_line_points(energy_contour, _ring_points(radius * (0.88 + sin(_progress * TAU * 3.0) * 0.04), 40))
			_set_line_points(motion_trail, _ring_points(radius * 0.68, 32))
			_set_line_points(accent_line, _ring_points(radius * 0.46, 28))


func _draw_fire_pillars() -> void:
	var count := maxi(5, int(_parameters.get("pillar_count", 5)))
	var radius := float(_parameters.get("radius", 320.0))
	var visible_count := clampi(floori(_progress * float(count + 3)), 0, count)
	for index in visible_count:
		var ratio := (float(index) + 0.5) / float(count)
		var x := lerpf(-radius, radius, ratio) + sin(float(index) * 4.17) * 34.0
		var phase := fposmod(_progress * 5.0 - float(index) * 0.17, 1.0)
		var height := (90.0 + float(index % 3) * 28.0) * sin(phase * PI)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 22, 0), Vector2(x, -height), Vector2(x + 22, 0)]), Color(_palette[1], 0.68))
		draw_circle(Vector2(x, -height * 0.45), 8.0 + 9.0 * sin(phase * PI), Color(_palette[0], 0.82))


func _draw_residual_lightning() -> void:
	var strike_phase := smoothstep(0.70, 0.92, _progress)
	for index in _resolved_target_positions(int(_parameters.get("target_limit", 10))).size():
		var point := _resolved_target_positions(int(_parameters.get("target_limit", 10)))[index]
		draw_arc(point, 13.0 + sin(_progress * TAU * 5.0 + index) * 3.0, 0, TAU, 16, Color(_palette[1], 0.8), 3.0)
		if strike_phase > 0.0:
			draw_line(point + Vector2(0, -310), point, Color(_palette[0], strike_phase), 7.0)
			draw_line(point + Vector2(-9, -210), point + Vector2(5, -128), Color(_palette[1], strike_phase), 4.0)


func _draw_tidal_push() -> void:
	var radius := float(_parameters.get("radius", 260.0))
	for layer in 4:
		var phase := fposmod(_progress * 2.2 + float(layer) * 0.22, 1.0)
		var x := lerpf(20.0, radius, phase)
		draw_arc(Vector2(x, -10), 42.0 + layer * 10.0, PI, TAU, 18, Color(_palette[layer % _palette.size()], 0.58 * (1.0 - phase)), 8.0 - layer)
		draw_arc(Vector2(-x, -10), 42.0 + layer * 10.0, PI, TAU, 18, Color(_palette[layer % _palette.size()], 0.58 * (1.0 - phase)), 8.0 - layer)


func _draw_dragon_breath() -> void:
	var radius := float(_parameters.get("radius", 420.0))
	var sweep_alpha := minf(1.0, _progress * 6.0) * (1.0 - smoothstep(0.55, 0.75, _progress))
	draw_arc(Vector2.ZERO, radius * 0.42, PI, TAU, 32, Color(_palette[1], sweep_alpha), 32.0)
	draw_arc(Vector2.ZERO, radius * 0.56, PI, TAU, 32, Color(_palette[0], sweep_alpha), 9.0)
	var rain_count := int(_parameters.get("rain_emitter_count", 0))
	if rain_count <= 0 or _progress < 0.38:
		return
	for index in rain_count:
		var x := lerpf(-radius, radius, (float(index) + 0.5) / float(rain_count))
		var pulse := 0.55 + 0.45 * sin(_progress * TAU * 8.0 + float(index) * 0.7)
		draw_circle(Vector2(x, -250), 9.0, Color(_palette[2], 0.9))
		draw_line(Vector2(x, -238), Vector2(x, -40), Color(_palette[1], 0.55 * pulse), 12.0)
		draw_line(Vector2(x, -238), Vector2(x, -40), Color(_palette[0], 0.80 * pulse), 4.0)


func _draw_healing_zone() -> void:
	var radius := float(_parameters.get("radius", 150.0))
	var pulse := 0.92 + sin(_progress * TAU * 5.0) * 0.08
	draw_circle(Vector2.ZERO, radius * pulse, Color(_palette[2], 0.13))
	draw_arc(Vector2.ZERO, radius * pulse, 0, TAU, 64, Color(_palette[1], 0.76), 7.0)
	for index in 8 + _tier_rank * 4:
		var angle := TAU * float(index) / float(8 + _tier_rank * 4)
		var distance := radius * (0.28 + 0.62 * fposmod(_progress * 1.7 + float(index) * 0.137, 1.0))
		draw_circle(Vector2(cos(angle) * distance, -16.0 - fposmod(_progress * 190.0 + index * 23.0, 120.0)), 3.5, Color(_palette[index % _palette.size()], 0.82))


func _draw_body_overdrive() -> void:
	var radius := 72.0 + float(_tier_rank) * 12.0
	var pulse := 0.88 + sin(_progress * TAU * 7.0) * 0.10
	for layer in 3:
		draw_arc(Vector2(0, -54), radius * pulse + layer * 9.0, 0, TAU, 48, Color(_palette[layer], 0.54 - layer * 0.10), 7.0 - layer)
	var afterimage_count := int(_parameters.get("afterimage_count", 3))
	for index in afterimage_count:
		var distance := 24.0 + float(index) * 18.0
		var alpha := 0.34 * (1.0 - float(index) / float(maxi(1, afterimage_count)))
		var offset := Vector2(-distance, -54.0 + sin(_progress * TAU * 9.0 + index) * 5.0)
		draw_circle(offset, 25.0, Color(_palette[index % _palette.size()], alpha))
		draw_rect(Rect2(offset + Vector2(-14, 18), Vector2(28, 50)), Color(_palette[index % _palette.size()], alpha * 0.72), true)


func _resolved_target_positions(limit: int) -> Array[Vector2]:
	if not _target_positions.is_empty():
		return _target_positions.slice(0, mini(limit, _target_positions.size()))
	var result: Array[Vector2] = []
	for index in maxi(1, mini(limit, 8)):
		var angle := TAU * float(index) / float(maxi(1, mini(limit, 8)))
		result.append(Vector2(cos(angle) * 210.0, -40.0 + sin(angle) * 72.0))
	return result


func _ring_points(radius: float, segments: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in segments + 1:
		var angle := TAU * float(index) / float(segments)
		result.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.34))
	return result


func _arc_points(radius: float, y: float, segments: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in segments + 1:
		var ratio := float(index) / float(segments)
		result.append(Vector2(lerpf(-radius, radius, ratio), y - sin(ratio * PI) * radius * 0.28))
	return result


func _jagged(points: Array[Vector2], amount: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if points.is_empty():
		return result
	result.append(points[0])
	for index in range(1, points.size()):
		var start := points[index - 1]
		var finish := points[index]
		for subdivision in range(1, 4):
			var ratio := float(subdivision) / 4.0
			var normal := (finish - start).orthogonal().normalized()
			result.append(start.lerp(finish, ratio) + normal * sin(float(index * 13 + subdivision * 7)) * amount)
		result.append(finish)
	return result


func _set_line_points(line: Line2D, values: Array[Vector2]) -> void:
	line.points = PackedVector2Array(values)


func _resolve_palette(values: Array) -> Array[Color]:
	var result: Array[Color] = []
	for value in values:
		if value is Color:
			result.append(value)
		else:
			result.append(Color(String(value)))
	while result.size() < 3:
		result.append([Color.WHITE, Color.CYAN, Color.DARK_BLUE][result.size()])
	return result.slice(0, 3)
