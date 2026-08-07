class_name FeatherHaloMaterialVFX2D
extends Node2D

const ENERGY_SHADER := preload("res://shaders/vfx/feather_halo_energy.gdshader")
const TRAIL_SHADER := preload("res://shaders/vfx/feather_halo_trail.gdshader")
const TRAIL_LAYER_COUNT := 2

@export_range(0.5, 12.0, 0.05) var lifetime_seconds := 4.8
@export_range(0.1, 4.0, 0.05) var fade_seconds := 1.45
@export_range(0.1, 1.5, 0.05) var feather_dissolve_seconds := 0.7
@export_range(0.0, 0.5, 0.005) var summon_stagger_seconds := 0.075
@export_range(0.05, 3.0, 0.01) var orbit_speed := 0.82
@export_range(48.0, 260.0, 1.0) var basic_radius := 104.0
@export_range(48.0, 300.0, 1.0) var advanced_radius := 132.0
@export_range(48.0, 340.0, 1.0) var master_radius := 158.0
@export_range(1.0, 1.8, 0.01) var readability_scale := 1.22

var _core_sprites: Array[Sprite2D] = []
var _layers: Array[Dictionary] = []
var _remaining: Array[float] = []
var _summon_delays: Array[float] = []
var _arrival_progress: Array[float] = []
var _mote_emitters: Array[GPUParticles2D] = []
var _halo_rings: Array[Line2D] = []
var _palette: Array[Color] = [Color("fffce8"), Color("f6d982"), Color("9a72e8")]
var _tier := 1
var _orbit_angle := 0.0
var _timeline := 0.0
var _refill_generation := 0
var _last_refill_count := 0
var _visible_count := 0
var _fading_count := 0
var _pending_count := 0
var _expired_count := 0
var _max_root_alignment_error := 0.0
var _contact_impact_count := 0


func configure(
	core_sprites: Array,
	tier_rank: int,
	palette: Array = [],
	parameters: Dictionary = {}
) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_apply_parameters(parameters)
	if palette.size() >= 3:
		_palette.assign([
			palette[0] as Color,
			palette[1] as Color,
			palette[2] as Color,
		])
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			_core_sprites.append(core_variant as Sprite2D)
	if _core_sprites.is_empty():
		return false
	var core_count := _core_sprites.size()
	for index in core_count:
		_build_feather_layers(index, _core_sprites[index])
		_remaining.append(_feather_lifetime(index, core_count))
		_summon_delays.append(float(index) * summon_stagger_seconds)
		_arrival_progress.append(0.0)
	_build_halo_rings()
	_build_mote_pool(clampi(2 + _tier, 3, 5))
	visible = true
	_update_layers(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_layers.clear()
	_remaining.clear()
	_summon_delays.clear()
	_arrival_progress.clear()
	_mote_emitters.clear()
	_halo_rings.clear()
	_orbit_angle = 0.0
	_timeline = 0.0
	_refill_generation = 0
	_last_refill_count = 0
	_contact_impact_count = 0
	_reset_counters()
	visible = false


func reset() -> void:
	for core in _core_sprites:
		core.visible = false
	for data in _layers:
		(data["aura"] as Sprite2D).visible = false
		for trail_variant in data["trails"] as Array:
			(trail_variant as Line2D).visible = false
	for emitter in _mote_emitters:
		emitter.emitting = false
	for ring in _halo_rings:
		ring.visible = false
	_reset_counters()
	visible = false


func advance(delta: float) -> void:
	if _core_sprites.is_empty():
		return
	var safe_delta := maxf(0.0, delta)
	_timeline += safe_delta
	_orbit_angle = fmod(_orbit_angle + safe_delta * orbit_speed, TAU)
	for index in _remaining.size():
		if _summon_delays[index] > 0.0:
			_summon_delays[index] = maxf(0.0, _summon_delays[index] - safe_delta)
		else:
			_arrival_progress[index] = minf(
				1.0, _arrival_progress[index] + safe_delta / 0.16
			)
			var before := _remaining[index]
			_remaining[index] = maxf(0.0, before - safe_delta)
			if before > 0.0 and _remaining[index] <= 0.0:
				_emit_motes(index)
	_update_layers(safe_delta)


func refill() -> int:
	_refill_generation += 1
	_last_refill_count = 0
	var core_count := _remaining.size()
	var missing_order := 0
	for index in core_count:
		var refreshed_lifetime := _feather_lifetime(index, core_count)
		var was_missing := _remaining[index] <= 0.0 and _summon_delays[index] <= 0.0
		if _remaining[index] < refreshed_lifetime or _summon_delays[index] > 0.0:
			_last_refill_count += 1
		_remaining[index] = refreshed_lifetime
		if was_missing:
			_summon_delays[index] = float(missing_order) * summon_stagger_seconds
			_arrival_progress[index] = 0.0
			missing_order += 1
	_update_layers(0.0)
	visible = true
	return _last_refill_count


func is_empty() -> bool:
	for index in _remaining.size():
		if _remaining[index] > 0.0 or _summon_delays[index] > 0.0:
			return false
	return true


func get_debug_state() -> Dictionary:
	var minimum_remaining := lifetime_seconds
	var maximum_remaining := 0.0
	for remaining in _remaining:
		minimum_remaining = minf(minimum_remaining, remaining)
		maximum_remaining = maxf(maximum_remaining, remaining)
	return {
		"renderer": "persistent_feather_halo",
		"attack_mode": "orbit_contact",
		"feather_count": _core_sprites.size(),
		"visible_feather_count": _visible_count,
		"fading_feather_count": _fading_count,
		"refill_pending_count": _pending_count,
		"expired_feather_count": _expired_count,
		"material_trail_layer_count": _layers.size() * TRAIL_LAYER_COUNT,
		"aura_layer_count": _layers.size(),
		"halo_ring_layer_count": _halo_rings.size(),
		"uses_energy_shader": not _core_sprites.is_empty(),
		"uses_dissolve_particles": not _mote_emitters.is_empty(),
		"max_root_alignment_error": _max_root_alignment_error,
		"lifetime_seconds": lifetime_seconds,
		"fade_start_seconds": lifetime_seconds - fade_seconds,
		"summon_stagger_seconds": summon_stagger_seconds,
		"orbit_speed": orbit_speed,
		"readability_scale": readability_scale,
		"orbit_angle": _orbit_angle,
		"refill_generation": _refill_generation,
		"last_refill_count": _last_refill_count,
		"minimum_remaining_seconds": minimum_remaining,
		"maximum_remaining_seconds": maximum_remaining,
		"contact_impact_count": _contact_impact_count,
		"energy_shader": ENERGY_SHADER.resource_path,
		"trail_shader": TRAIL_SHADER.resource_path,
	}


func get_active_layer_count() -> int:
	return (
		_layers.size() * (1 + TRAIL_LAYER_COUNT)
		+ _mote_emitters.size()
		+ _halo_rings.size()
	)


func _update_layers(_delta: float) -> void:
	_reset_counters()
	var count := _core_sprites.size()
	var radius: float = [basic_radius, advanced_radius, master_radius][_tier - 1]
	for index in count:
		var core := _core_sprites[index]
		var data := _layers[index]
		var aura := data["aura"] as Sprite2D
		var trails := data["trails"] as Array
		var pending := _summon_delays[index] > 0.0
		var remaining := _remaining[index]
		var spawn_progress := 0.0 if pending else _arrival_progress[index]
		if pending:
			_pending_count += 1
		var fade_alpha := clampf(remaining / feather_dissolve_seconds, 0.0, 1.0)
		var alpha := fade_alpha if not pending else 0.0
		var angle := _orbit_angle + TAU * float(index) / maxf(1.0, float(count))
		var orbit_radius: float = radius + sin(float(index) * 1.73) * 6.0
		var position_value: Vector2 = Vector2.from_angle(angle) * orbit_radius
		var base_scale := float(core.get_meta("base_scale", 1.0))
		var arrival := smoothstep(0.0, 1.0, spawn_progress)
		var pulse := 1.0 + sin(_timeline * 3.4 + float(index) * 0.52) * 0.035
		core.position = position_value
		core.rotation = angle
		core.scale = (
			Vector2.ONE * base_scale * readability_scale
			* lerpf(0.72, 1.0, arrival) * pulse
		)
		core.modulate = Color(1.0, 1.0, 1.0, alpha)
		core.visible = alpha > 0.01
		_sync_energy_material(core.material as ShaderMaterial, fade_alpha, 1.0)
		aura.position = position_value
		aura.rotation = angle
		aura.scale = core.scale * (1.10 + (1.0 - fade_alpha) * 0.12)
		aura.modulate = Color(1.0, 1.0, 1.0, alpha * (0.24 + pulse * 0.08))
		aura.visible = alpha > 0.01
		_sync_energy_material(aura.material as ShaderMaterial, fade_alpha, 1.55)
		_update_trails(trails, angle, orbit_radius, alpha)
		if alpha > 0.01:
			_visible_count += 1
		if remaining > 0.0 and remaining < feather_dissolve_seconds and not pending:
			_fading_count += 1
		elif remaining <= 0.0 and not pending:
			_expired_count += 1
		if not position_value.is_zero_approx():
			var root_direction := Vector2.LEFT.rotated(core.rotation)
			var inward: Vector2 = -position_value.normalized()
			_max_root_alignment_error = maxf(
				_max_root_alignment_error,
				1.0 - root_direction.dot(inward)
			)
	_update_halo_rings(radius)


func _apply_parameters(parameters: Dictionary) -> void:
	lifetime_seconds = maxf(0.5, float(parameters.get(
		"halo_lifetime_seconds", lifetime_seconds
	)))
	fade_seconds = clampf(float(parameters.get(
		"halo_fade_seconds", fade_seconds
	)), 0.1, lifetime_seconds)
	feather_dissolve_seconds = clampf(float(parameters.get(
		"halo_feather_dissolve_seconds", feather_dissolve_seconds
	)), 0.1, fade_seconds)
	lifetime_seconds = maxf(0.5, float(parameters.get(
		"halo_duration_seconds", lifetime_seconds
	)))
	summon_stagger_seconds = maxf(0.0, float(parameters.get(
		"halo_summon_stagger_seconds", summon_stagger_seconds
	)))
	orbit_speed = maxf(0.05, float(parameters.get(
		"halo_orbit_speed", orbit_speed
	)))
	basic_radius = maxf(48.0, float(parameters.get(
		"halo_basic_radius", basic_radius
	)))
	advanced_radius = maxf(48.0, float(parameters.get(
		"halo_advanced_radius", advanced_radius
	)))
	master_radius = maxf(48.0, float(parameters.get(
		"halo_master_radius", master_radius
	)))
	readability_scale = maxf(1.0, float(parameters.get(
		"halo_readability_scale", readability_scale
	)))


func _update_trails(trails: Array, angle: float, radius: float, alpha: float) -> void:
	for layer_index in trails.size():
		var trail := trails[layer_index] as Line2D
		var points := PackedVector2Array()
		var arc_length := 0.26 + float(layer_index) * 0.10
		for sample_index in 9:
			var ratio := float(sample_index) / 8.0
			var sample_angle := angle - arc_length * (1.0 - ratio)
			points.append(Vector2.from_angle(sample_angle) * (radius - float(layer_index) * 4.0))
		trail.points = points
		trail.modulate = Color(1.0, 1.0, 1.0, alpha * [0.32, 0.78][layer_index])
		trail.visible = alpha > 0.01
		var material := trail.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("timeline", _timeline)


func _feather_lifetime(index: int, count: int) -> float:
	if count <= 1:
		return lifetime_seconds
	var sequence_span := maxf(0.0, fade_seconds - feather_dissolve_seconds)
	return (
		lifetime_seconds - sequence_span
		+ sequence_span * float(index) / float(count - 1)
	)


func _build_halo_rings() -> void:
	for layer_index in 2:
		var ring := Line2D.new()
		ring.name = ["HaloOuterEnergy", "HaloBrightCore"][layer_index]
		ring.closed = true
		ring.width = [13.0, 4.0][layer_index]
		ring.default_color = _palette[2 if layer_index == 0 else 0]
		ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ring.end_cap_mode = Line2D.LINE_CAP_ROUND
		ring.joint_mode = Line2D.LINE_JOINT_ROUND
		ring.antialiased = false
		ring.z_index = -6 + layer_index
		ring.material = _make_trail_material(layer_index)
		ring.visible = false
		add_child(ring)
		_halo_rings.append(ring)


func _update_halo_rings(radius: float) -> void:
	var visible_ratio := (
		float(_visible_count) / float(_core_sprites.size())
		if not _core_sprites.is_empty()
		else 0.0
	)
	for layer_index in _halo_rings.size():
		var ring := _halo_rings[layer_index]
		var points := PackedVector2Array()
		var ring_radius := radius - 8.0 - float(layer_index) * 3.0
		for sample_index in 48:
			points.append(
				Vector2.from_angle(TAU * float(sample_index) / 48.0) * ring_radius
			)
		ring.points = points
		ring.modulate = Color(
			1.0, 1.0, 1.0,
			visible_ratio * ([0.38, 0.72][layer_index])
				* (0.92 + sin(_timeline * 3.0) * 0.08)
		)
		ring.visible = visible_ratio > 0.01
		var material := ring.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("timeline", _timeline)


func play_contact_impact(world_position: Vector2) -> void:
	_contact_impact_count += 1
	var local_position := to_local(world_position)
	var burst := Node2D.new()
	burst.name = "FeatherContactImpact%d" % _contact_impact_count
	burst.position = local_position
	burst.z_index = 12
	add_child(burst)
	for layer_index in 2:
		var arc := Line2D.new()
		arc.width = [16.0, 5.0][layer_index]
		arc.default_color = _palette[1 if layer_index == 0 else 0]
		arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arc.end_cap_mode = Line2D.LINE_CAP_ROUND
		arc.antialiased = false
		arc.material = _make_trail_material(layer_index)
		var points := PackedVector2Array()
		for sample_index in 9:
			var ratio := float(sample_index) / 8.0
			var angle := lerpf(-0.72, 0.72, ratio)
			points.append(Vector2.from_angle(angle) * (28.0 + float(layer_index) * 4.0))
		arc.points = points
		arc.rotation = _orbit_angle + PI * 0.5
		burst.add_child(arc)
	var emitter := _mote_emitters[_contact_impact_count % _mote_emitters.size()] if not _mote_emitters.is_empty() else null
	if emitter != null:
		emitter.position = local_position
		emitter.restart()
		emitter.emitting = true
	burst.scale = Vector2.ONE * 0.62
	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2.ONE * 1.28, 0.18)
	tween.tween_property(burst, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(burst.queue_free)


func _build_feather_layers(index: int, core: Sprite2D) -> void:
	core.material = _make_energy_material(1.0)
	core.use_parent_material = false
	var aura := Sprite2D.new()
	aura.name = "FeatherAura%02d" % (index + 1)
	aura.texture = core.texture
	aura.texture_filter = core.texture_filter
	aura.material = _make_energy_material(1.55)
	aura.z_index = core.z_index - 1
	aura.visible = false
	add_child(aura)
	var trails: Array[Line2D] = []
	for layer_index in TRAIL_LAYER_COUNT:
		var trail := Line2D.new()
		trail.name = ["OuterArc", "BrightArc"][layer_index] + "%02d" % (index + 1)
		trail.width = [15.0, 5.0][layer_index]
		trail.default_color = _palette[1 if layer_index == 0 else 0]
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.joint_mode = Line2D.LINE_JOINT_ROUND
		trail.antialiased = false
		trail.z_index = core.z_index - 3 + layer_index
		trail.material = _make_trail_material(layer_index)
		trail.visible = false
		add_child(trail)
		trails.append(trail)
	_layers.append({"aura": aura, "trails": trails})


func _build_mote_pool(count: int) -> void:
	var texture := _make_mote_texture()
	for index in count:
		var particles := GPUParticles2D.new()
		particles.name = "FeatherDissolveMotes%d" % (index + 1)
		particles.amount = 18 + _tier * 5
		particles.lifetime = 0.72
		particles.one_shot = true
		particles.explosiveness = 0.88
		particles.randomness = 0.48
		particles.local_coords = true
		particles.visibility_rect = Rect2(-96.0, -96.0, 192.0, 192.0)
		particles.texture = texture
		particles.emitting = false
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.0, -1.0, 0.0)
		process.spread = 180.0
		process.gravity = Vector3(0.0, -14.0, 0.0)
		process.initial_velocity_min = 18.0
		process.initial_velocity_max = 64.0
		process.damping_min = 8.0
		process.damping_max = 22.0
		process.scale_min = 0.45
		process.scale_max = 1.10
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			Color(_palette[0], 0.92), Color(_palette[1], 0.62), Color(_palette[2], 0.0),
		])
		gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		process.color_ramp = ramp
		particles.process_material = process
		add_child(particles)
		_mote_emitters.append(particles)


func _emit_motes(feather_index: int) -> void:
	if _mote_emitters.is_empty() or feather_index >= _core_sprites.size():
		return
	var emitter := _mote_emitters[feather_index % _mote_emitters.size()]
	emitter.position = _core_sprites[feather_index].position
	emitter.restart()
	emitter.emitting = true


func _make_energy_material(energy_value: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ENERGY_SHADER
	material.set_shader_parameter("edge_color", _palette[1])
	material.set_shader_parameter("core_color", _palette[0])
	material.set_shader_parameter("shadow_color", _palette[2])
	material.set_shader_parameter("energy", energy_value)
	return material


func _make_trail_material(layer_index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TRAIL_SHADER
	material.set_shader_parameter("head_color", _palette[0 if layer_index == 1 else 1])
	material.set_shader_parameter("tail_color", Color(_palette[2], 0.0))
	material.set_shader_parameter("energy", 1.28 if layer_index == 1 else 0.72)
	return material


func _sync_energy_material(material: ShaderMaterial, alpha: float, energy_value: float) -> void:
	if material == null:
		return
	material.set_shader_parameter("timeline", _timeline)
	material.set_shader_parameter("energy", energy_value)
	material.set_shader_parameter("fade_amount", 1.0 - alpha)
	material.set_shader_parameter("aura_alpha", alpha)


func _reset_counters() -> void:
	_visible_count = 0
	_fading_count = 0
	_pending_count = 0
	_expired_count = 0
	_max_root_alignment_error = 0.0


func _make_mote_texture() -> Texture2D:
	var image := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for x in 5:
		for y in 5:
			var distance := Vector2(float(x - 2), float(y - 2)).length()
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - distance / 2.8, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
