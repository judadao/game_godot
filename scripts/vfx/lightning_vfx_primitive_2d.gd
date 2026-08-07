class_name LightningVFXPrimitive2D
extends LayeredVFXPrimitive2D

const REFRESH_INTERVAL := 0.026
const SKY_STRIKE_MIN_HEIGHT := 620.0
const SKY_STRIKE_SCREEN_MARGIN := 72.0

var _lightning_progress := 0.0
var _refresh_generation := -1
var _main_path := PackedVector2Array()
var _branch_path := PackedVector2Array()
var _ground_path := PackedVector2Array()
var _spark_triggered := false
var _spark_trigger_count := 0
var _spark_trigger_progress := -1.0
var _sky_strike_vertical_span := 0.0


func play(origin: Variant = null, target: Variant = null) -> void:
	_spark_triggered = false
	_spark_trigger_count = 0
	_spark_trigger_progress = -1.0
	super.play(origin, target)
	var sparks := get_node_or_null("Sparks") as GPUParticles2D
	if sparks != null:
		sparks.emitting = false


func get_quality_state() -> Dictionary:
	var state := super.get_quality_state()
	state["electricity_motion"] = "sky_strike" if effect_id == &"lightning_impact" else "conductive_head"
	state["energy_layer_count"] = 3
	state["impact_layer_count"] = 7 if effect_id == &"lightning_impact" else 5
	state["transparent_additive_energy"] = true
	state["procedural_refresh_interval"] = REFRESH_INTERVAL
	state["persistent_route_line"] = false
	state["spark_trigger_count"] = _spark_trigger_count
	state["spark_trigger_progress"] = _spark_trigger_progress
	if effect_id == &"lightning_impact":
		state["sky_origin_mode"] = "viewport_top"
		state["strike_direction"] = "top_to_bottom"
		state["descending_reveal"] = true
		state["sky_strike_vertical_span"] = _sky_strike_vertical_span
	return state


func _configure_layers() -> void:
	super._configure_layers()
	for index in _line_layers.size():
		var line := _line_layers[index]
		line.antialiased = false
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var shader_material := line.material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter("phase_offset", float(index) * 1.73)
	if effect_id == &"lightning_impact":
		_set_line_widths(30.0, 7.5, 4.0, 3.0)
	else:
		_set_line_widths(22.0, 6.0, 3.2, 2.4)


func _configure_particle_layer(particles: GPUParticles2D) -> void:
	super._configure_particle_layer(particles)
	var process := particles.process_material as ParticleProcessMaterial
	if process == null:
		return
	if effect_id == &"lightning_impact":
		process.direction = Vector3(0.0, -1.0, 0.0)
		process.spread = 78.0
		process.initial_velocity_min = 92.0
		process.initial_velocity_max = 248.0
		process.gravity = Vector3(0.0, 185.0, 0.0)
		process.scale_min = 0.55 * effect_scale
		process.scale_max = 1.35 * effect_scale
	else:
		process.spread = 34.0
		process.initial_velocity_min = 118.0
		process.initial_velocity_max = 226.0
		process.gravity = Vector3(0.0, 34.0, 0.0)


func _update_visuals(progress: float) -> void:
	_lightning_progress = progress
	var next_generation := floori(_time / REFRESH_INTERVAL)
	if next_generation != _refresh_generation:
		_refresh_generation = next_generation
		_regenerate_paths()
	if effect_id == &"lightning_impact":
		_update_sky_strike(progress)
	else:
		_update_conductive_bolt(progress)
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	if effect_id == &"lightning_impact":
		_draw_sky_strike_layers(_lightning_progress)
	else:
		_draw_chain_contact_layers(_lightning_progress)


func _update_conductive_bolt(progress: float) -> void:
	var head := clampf(progress / 0.34, 0.0, 1.0)
	var tail := maxf(0.0, head - 0.48)
	if progress >= 0.25:
		head = 1.0
		tail = 0.0
	var visible_main := _path_window(_main_path, tail, head)
	var visible_branch := _path_window(_branch_path, maxf(0.0, tail - 0.12), head)
	_set_line_points("Glow", visible_main)
	_set_line_points("MainBolt", visible_main)
	_set_line_points("BranchBolts", visible_branch)
	_set_line_points("ImpactFlash", PackedVector2Array())
	var discharge := smoothstep(0.0, 0.055, progress) * (1.0 - smoothstep(0.54, 1.0, progress))
	var core_flash := smoothstep(0.12, 0.25, progress) * (1.0 - smoothstep(0.44, 0.76, progress))
	_set_line_alpha("Glow", discharge * 0.54)
	_set_line_alpha("MainBolt", discharge)
	_set_line_alpha("BranchBolts", core_flash * 0.82)
	var sparks := get_node_or_null("Sparks") as GPUParticles2D
	if sparks != null and not _main_path.is_empty():
		sparks.position = _main_path[-1]
	if progress >= 0.22:
		_trigger_sparks_once(progress)


func _update_sky_strike(progress: float) -> void:
	var descent_head := smoothstep(0.07, 0.21, progress)
	var branch_head := smoothstep(0.12, 0.23, progress)
	var strike := smoothstep(0.07, 0.12, progress) * (1.0 - smoothstep(0.48, 0.70, progress))
	var branch := smoothstep(0.12, 0.20, progress) * (1.0 - smoothstep(0.54, 0.78, progress))
	var residue := smoothstep(0.20, 0.30, progress) * (1.0 - smoothstep(0.74, 1.0, progress))
	_set_line_points("Glow", _path_window(_main_path, 0.0, descent_head))
	_set_line_points("MainBolt", _path_window(_main_path, 0.0, descent_head))
	_set_line_points("BranchBolts", _path_window(_branch_path, 0.0, branch_head))
	_set_line_points("ImpactFlash", _ground_path)
	_set_line_alpha("Glow", strike * 0.62)
	_set_line_alpha("MainBolt", strike)
	_set_line_alpha("BranchBolts", branch * 0.88)
	_set_line_alpha("ImpactFlash", residue * 0.72)
	if progress >= 0.20:
		_trigger_sparks_once(progress)


func _trigger_sparks_once(progress: float) -> void:
	if _spark_triggered:
		return
	var sparks := get_node_or_null("Sparks") as GPUParticles2D
	if sparks == null:
		return
	_spark_triggered = true
	_spark_trigger_count += 1
	_spark_trigger_progress = progress
	sparks.restart()
	sparks.emitting = true


func _regenerate_paths() -> void:
	var seed := int(effect_id.hash()) + _refresh_generation * 104729
	if effect_id == &"lightning_impact":
		var top := _sky_strike_origin(seed)
		_sky_strike_vertical_span = absf(top.y)
		_main_path = _displaced_path(top, Vector2.ZERO, 24, 46.0 * noise_amount, seed)
		_branch_path = _displaced_path(
			top.lerp(Vector2.ZERO, 0.18) + Vector2(-86.0, 0.0),
			Vector2(5.0, -18.0),
			18,
			30.0 * noise_amount,
			seed + 79
		)
		_ground_path = _displaced_path(Vector2(-112.0, 5.0), Vector2(118.0, 8.0), 14, 15.0 * noise_amount, seed + 193)
	else:
		var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
		var half_length := _bounds.x * 0.5 * effect_scale
		var thickness_scale := clampf(sqrt(maxf(effect_scale, 0.01)), 0.65, 1.35)
		var start := -safe_direction * half_length
		var finish := safe_direction * half_length
		_main_path = _displaced_path(start, finish, 18, _bounds.y * 0.16 * noise_amount * thickness_scale, seed)
		_branch_path = _displaced_path(
			start.lerp(finish, 0.28),
			start.lerp(finish, 0.88),
			11,
			_bounds.y * 0.11 * noise_amount * thickness_scale,
			seed + 67
		)
		_ground_path = PackedVector2Array()


func _sky_strike_origin(seed: int) -> Vector2:
	var origin := Vector2(0.0, -SKY_STRIKE_MIN_HEIGHT)
	var viewport := get_viewport()
	if viewport != null:
		var visible_rect := viewport.get_visible_rect()
		var canvas_transform := viewport.get_canvas_transform()
		if visible_rect.size.y > 0.0 and absf(canvas_transform.determinant()) > 0.0001:
			var target_screen := canvas_transform * global_position
			var sky_screen := Vector2(
				target_screen.x,
				visible_rect.position.y - SKY_STRIKE_SCREEN_MARGIN
			)
			origin = to_local(canvas_transform.affine_inverse() * sky_screen)
	origin.y = minf(origin.y, -SKY_STRIKE_MIN_HEIGHT)
	origin.x += _signed_hash(seed + 17) * 18.0
	return origin


func _displaced_path(
	start: Vector2,
	finish: Vector2,
	segments: int,
	displacement: float,
	seed: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var tangent := (finish - start).normalized()
	var normal := tangent.orthogonal()
	for index in segments + 1:
		var ratio := float(index) / float(segments)
		var envelope := sin(ratio * PI)
		var primary_noise := _signed_hash(seed + index * 41) * displacement
		var fine_noise := sin(float(index) * 4.37 + float(seed % 97)) * displacement * 0.26
		points.append(start.lerp(finish, ratio) + normal * (primary_noise + fine_noise) * envelope)
	return points


func _path_window(path: PackedVector2Array, from_ratio: float, to_ratio: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if path.size() < 2 or to_ratio <= from_ratio:
		return result
	var maximum_index := path.size() - 1
	var from_index := clampi(floori(from_ratio * float(maximum_index)), 0, maximum_index - 1)
	var to_index := clampi(ceili(to_ratio * float(maximum_index)), from_index + 1, maximum_index)
	for index in range(from_index, to_index + 1):
		result.append(path[index])
	return result


func _draw_chain_contact_layers(progress: float) -> void:
	if _main_path.is_empty():
		return
	var impact := smoothstep(0.22, 0.30, progress) * (1.0 - smoothstep(0.58, 0.88, progress))
	if impact <= 0.0:
		return
	var point := _main_path[-1]
	draw_circle(point, 10.0 + impact * 8.0, Color(primary_color, 0.74 * impact))
	draw_circle(point, 27.0 + impact * 12.0, Color(secondary_color, 0.18 * impact))
	_draw_radial_electricity(point, 5, 24.0, 48.0, impact, _refresh_generation + 311)


func _draw_sky_strike_layers(progress: float) -> void:
	var anticipation := smoothstep(0.0, 0.07, progress) * (1.0 - smoothstep(0.16, 0.25, progress))
	var contact := smoothstep(0.18, 0.22, progress) * (1.0 - smoothstep(0.48, 0.70, progress))
	var residue := smoothstep(0.24, 0.34, progress) * (1.0 - smoothstep(0.78, 1.0, progress))
	if anticipation > 0.0:
		for fragment in 4:
			var start_angle := float(fragment) * TAU / 4.0 + _time * 7.0
			draw_arc(Vector2.ZERO, 28.0 + float(fragment) * 7.0, start_angle, start_angle + 0.58, 8, Color(secondary_color, 0.46 * anticipation), 2.5)
	if contact > 0.0:
		draw_circle(Vector2.ZERO, 16.0 + contact * 13.0, Color(primary_color, 0.92 * contact))
		draw_circle(Vector2.ZERO, 44.0 + contact * 24.0, Color(secondary_color, 0.28 * contact))
		draw_circle(Vector2.ZERO, 82.0 + contact * 32.0, Color(secondary_color, 0.09 * contact))
	if residue > 0.0:
		_draw_radial_electricity(Vector2.ZERO, 9, 34.0, 112.0, residue, _refresh_generation + 719)


func _draw_radial_electricity(
	center: Vector2,
	branch_count: int,
	minimum_length: float,
	maximum_length: float,
	alpha: float,
	seed: int
) -> void:
	for branch_index in branch_count:
		var angle := TAU * float(branch_index) / float(branch_count) + _signed_hash(seed + branch_index * 13) * 0.32
		var length := lerpf(minimum_length, maximum_length, 0.5 + _signed_hash(seed + branch_index * 29) * 0.5)
		var finish := center + Vector2.from_angle(angle) * length
		var path := _displaced_path(center, finish, 5, 7.0, seed + branch_index * 97)
		draw_polyline(path, Color(secondary_color, 0.24 * alpha), 7.0, false)
		draw_polyline(path, Color(primary_color, 0.82 * alpha), 1.6, false)


func _set_line_widths(glow_width: float, core_width: float, branch_width: float, residue_width: float) -> void:
	var width_scale := (
		clampf(sqrt(maxf(effect_scale, 0.01)), 0.72, 1.35)
		if effect_id == &"lightning_impact"
		else 1.0
	)
	var widths := {
		"Glow": glow_width * width_scale,
		"MainBolt": core_width * width_scale,
		"BranchBolts": branch_width * width_scale,
		"ImpactFlash": residue_width * width_scale,
	}
	for node_name in widths:
		var line := get_node_or_null(NodePath(node_name)) as Line2D
		if line != null:
			line.width = float(widths[node_name])


func _set_line_points(node_name: String, points: PackedVector2Array) -> void:
	var line := get_node_or_null(NodePath(node_name)) as Line2D
	if line == null:
		return
	line.points = points
	line.scale = Vector2.ONE


func _set_line_alpha(node_name: String, alpha: float) -> void:
	var line := get_node_or_null(NodePath(node_name)) as Line2D
	if line != null:
		line.modulate = Color(1.0, 1.0, 1.0, clampf(alpha * intensity, 0.0, 1.0))


func _signed_hash(value: int) -> float:
	var hashed := sin(float(value) * 12.9898 + 78.233) * 43758.5453
	return fposmod(hashed, 1.0) * 2.0 - 1.0
