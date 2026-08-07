class_name SwordRainMaterialVFX2D
extends Node2D

const ENERGY_SHADER := preload("res://shaders/vfx/sword_rain_energy.gdshader")
const TRAIL_SHADER := preload("res://shaders/vfx/sword_rain_trail.gdshader")
const MOTION_PHASES := [
	"summon_stagger", "orbit_gather", "lock_charge", "snap_release",
	"insertion_hold", "afterglow_decay",
]
const IMPACT_ROLES := [
	"compression_wedge", "contact_flash", "directional_shards", "ground_scar",
	"sword_afterglow", "sparks",
]
const TRAIL_LAYER_COUNT := 3

var _core_sprites: Array[Sprite2D] = []
var _blade_layers: Array[Dictionary] = []
var _spark_emitters: Array[GPUParticles2D] = []
var _impact_started: Array[bool] = []
var _palette := [Color("ecfbff"), Color("79cfff"), Color("4546a8")]
var _tier := 1
var _timeline := 0.0
var _active_summon_echo_count := 0
var _active_lock_sheath_count := 0
var _active_trail_count := 0
var _active_impact_count := 0
var _active_ground_scar_count := 0
var _lock_energy := 0.0


func configure(core_sprites: Array, tier_rank: int, palette: Array = []) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	if palette.size() >= 3:
		_palette = [palette[0] as Color, palette[1] as Color, palette[2] as Color]
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			_core_sprites.append(core_variant as Sprite2D)
	if _core_sprites.is_empty():
		return false
	for index in _core_sprites.size():
		_build_blade_layers(index, _core_sprites[index])
		_impact_started.append(false)
	_build_spark_pool(clampi(2 + _tier, 3, 5))
	visible = true
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_blade_layers.clear()
	_spark_emitters.clear()
	_impact_started.clear()
	_reset_counters()
	visible = false


func reset() -> void:
	for layer_data in _blade_layers:
		_set_blade_layers_hidden(layer_data)
	for particles in _spark_emitters:
		particles.emitting = false
	_reset_counters()
	visible = false


func begin_frame(_cadence_phase: String, timeline: float) -> void:
	_timeline = clampf(timeline, 0.0, 1.0)
	_reset_counters()
	for layer_data in _blade_layers:
		_set_blade_layers_hidden(layer_data)
	visible = true


func set_blade_pose(
	index: int,
	position_value: Vector2,
	rotation_value: float,
	scale_value: Vector2,
	alpha: float,
	cadence_phase: String
) -> void:
	if index < 0 or index >= _blade_layers.size():
		return
	var data := _blade_layers[index]
	var core := _core_sprites[index]
	_sync_energy_material(core.material as ShaderMaterial, cadence_phase, 0.88)
	var summon := data["summon"] as Sprite2D
	var lock_sheath := data["lock_sheath"] as Sprite2D
	for ghost in [summon, lock_sheath]:
		ghost.position = position_value
		ghost.rotation = rotation_value
		ghost.scale = scale_value
	if cadence_phase == "orbit_reveal" and alpha > 0.02:
		var pulse := 0.5 + 0.5 * sin(_timeline * 34.0 + float(index) * 0.8)
		summon.scale = scale_value * (1.12 + pulse * 0.12)
		summon.modulate = Color(1.0, 1.0, 1.0, alpha * (0.18 + pulse * 0.16))
		summon.visible = true
		_sync_energy_material(summon.material as ShaderMaterial, cadence_phase, 1.45)
		_active_summon_echo_count += 1
	elif cadence_phase == "target_lock" and alpha > 0.02:
		var charge := 0.64 + 0.36 * sin(_timeline * 24.0 + float(index) * 0.36)
		lock_sheath.scale = scale_value * Vector2(1.34 + charge * 0.10, 1.10 + charge * 0.05)
		lock_sheath.modulate = Color(1.0, 1.0, 1.0, alpha * (0.34 + charge * 0.28))
		lock_sheath.visible = true
		_sync_energy_material(lock_sheath.material as ShaderMaterial, cadence_phase, 1.9)
		_active_lock_sheath_count += 1
		_lock_energy = maxf(_lock_energy, charge)


func set_blade_trail(index: int, points: PackedVector2Array, alpha: float) -> void:
	if index < 0 or index >= _blade_layers.size() or points.size() < 2 or alpha <= 0.01:
		return
	var trails := (_blade_layers[index].get("trails", []) as Array)
	for layer_index in trails.size():
		var trail := trails[layer_index] as Line2D
		trail.points = points
		trail.modulate = Color(1.0, 1.0, 1.0, alpha * [0.32, 0.72, 1.0][layer_index])
		trail.visible = true
		var material := trail.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("timeline", _timeline)
	_active_trail_count += 1


func set_blade_impact(index: int, position_value: Vector2, impact_progress: float) -> void:
	if index < 0 or index >= _blade_layers.size() or impact_progress <= 0.0:
		return
	var data := _blade_layers[index]
	var impact_root := data["impact"] as Node2D
	var clamped := clampf(impact_progress, 0.0, 1.0)
	var bloom := sin(clamped * PI)
	var hold := 1.0 - smoothstep(0.68, 1.0, clamped)
	impact_root.position = position_value
	impact_root.visible = bloom > 0.01 or hold > 0.01
	var flash := data["flash"] as Polygon2D
	flash.scale = Vector2(lerpf(0.18, 1.82, smoothstep(0.0, 0.34, clamped)), lerpf(0.72, 1.08, clamped))
	flash.color = Color(_palette[0], bloom * 0.92)
	var compression := data["compression"] as Polygon2D
	compression.scale = Vector2(lerpf(0.38, 1.18, clamped), lerpf(1.35, 0.82, clamped))
	compression.color = Color(_palette[2], bloom * 0.52)
	var afterglow := data["afterglow"] as Sprite2D
	afterglow.modulate = Color(1.0, 1.0, 1.0, hold * 0.48)
	afterglow.scale = Vector2.ONE * lerpf(0.82, 1.18, clamped)
	_sync_energy_material(afterglow.material as ShaderMaterial, "insertion_hold", 2.1)
	var shards := data["shards"] as Array
	for shard_index in shards.size():
		var shard := shards[shard_index] as Polygon2D
		var side := -1.0 if shard_index % 2 == 0 else 1.0
		shard.position = Vector2(side * (10.0 + shard_index * 8.0) * clamped, -12.0 - shard_index * 7.0 * clamped)
		shard.rotation = side * (0.35 + clamped * 0.5)
		shard.color = Color(_palette[1 if shard_index < 2 else 0], bloom * (0.8 - shard_index * 0.12))
	var scars := data["scars"] as Array
	for scar_index in scars.size():
		var scar := scars[scar_index] as Line2D
		scar.modulate = Color(1.0, 1.0, 1.0, hold * (0.72 - scar_index * 0.18))
		scar.scale = Vector2(lerpf(0.2, 1.0 + scar_index * 0.18, smoothstep(0.0, 0.34, clamped)), 1.0)
	_active_impact_count += 1
	if hold > 0.01:
		_active_ground_scar_count += 1
	if not _impact_started[index] and clamped >= 0.04:
		_impact_started[index] = true
		_emit_sparks(index, position_value)


func end_frame() -> void:
	pass


func get_debug_state() -> Dictionary:
	return {
		"renderer": "sword_rain_material_cadence",
		"blade_trail_count": _blade_layers.size(),
		"materialized_trail_layer_count": _blade_layers.size() * TRAIL_LAYER_COUNT,
		"blade_aura_count": _blade_layers.size() * 2,
		"impact_stack_count": _blade_layers.size(),
		"impact_roles": IMPACT_ROLES.duplicate(),
		"generic_line_roles": [],
		"uses_core_energy_shader": not _core_sprites.is_empty(),
		"trail_uses_material_shader": not _blade_layers.is_empty(),
		"spark_emitter_count": _spark_emitters.size(),
		"motion_phases": MOTION_PHASES.duplicate(),
		"active_summon_echo_count": _active_summon_echo_count,
		"active_lock_sheath_count": _active_lock_sheath_count,
		"active_trail_count": _active_trail_count,
		"active_impact_count": _active_impact_count,
		"active_ground_scar_count": _active_ground_scar_count,
		"lock_energy": _lock_energy,
		"energy_shader": ENERGY_SHADER.resource_path,
		"trail_shader": TRAIL_SHADER.resource_path,
	}


func get_active_layer_count() -> int:
	return _blade_layers.size() * (2 + TRAIL_LAYER_COUNT + 6) + _spark_emitters.size()


func _build_blade_layers(index: int, core: Sprite2D) -> void:
	core.material = _make_energy_material(0.9)
	core.use_parent_material = false
	var root := Node2D.new()
	root.name = "BladeMaterial%02d" % (index + 1)
	add_child(root)
	var trail_root := Node2D.new()
	trail_root.name = "TrailStack"
	root.add_child(trail_root)
	var trails: Array[Line2D] = []
	var widths := [18.0 + _tier * 2.0, 9.0 + _tier * 1.2, 3.0 + _tier * 0.5]
	var alphas := [0.28, 0.70, 1.0]
	for layer_index in TRAIL_LAYER_COUNT:
		var line := Line2D.new()
		line.name = ["OuterEnergy", "ColoredBody", "WhiteCore"][layer_index]
		line.width = widths[layer_index]
		line.default_color = Color(_palette[0 if layer_index == 2 else 1], alphas[layer_index])
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = false
		line.z_index = -4 + layer_index
		line.material = _make_trail_material(layer_index)
		line.visible = false
		trail_root.add_child(line)
		trails.append(line)
	var summon := _make_ghost_sprite(core, "SummonEcho", 0.52)
	summon.z_index = core.z_index - 2
	root.add_child(summon)
	var lock_sheath := _make_ghost_sprite(core, "LockSheath", 0.72)
	lock_sheath.z_index = core.z_index - 1
	root.add_child(lock_sheath)
	var impact := Node2D.new()
	impact.name = "InsertionImpact"
	impact.z_index = 8 + index % 3
	impact.visible = false
	root.add_child(impact)
	var flash := Polygon2D.new()
	flash.name = "ContactFlash"
	flash.polygon = PackedVector2Array([
		Vector2(-4.0, -44.0), Vector2(1.0, -11.0), Vector2(28.0, -5.0),
		Vector2(8.0, 0.0), Vector2(34.0, 7.0), Vector2(4.0, 5.0),
		Vector2(0.0, 19.0), Vector2(-4.0, 5.0), Vector2(-34.0, 7.0),
		Vector2(-8.0, 0.0), Vector2(-28.0, -5.0), Vector2(-1.0, -11.0),
	])
	impact.add_child(flash)
	var compression := Polygon2D.new()
	compression.name = "CompressionWedge"
	compression.polygon = PackedVector2Array([
		Vector2(-6.0, -58.0), Vector2(6.0, -58.0),
		Vector2(24.0, 4.0), Vector2(-24.0, 4.0),
	])
	compression.z_index = -1
	impact.add_child(compression)
	var afterglow := _make_ghost_sprite(core, "SwordAfterglow", 0.64)
	afterglow.position = Vector2(0.0, -28.0)
	afterglow.rotation = PI * 0.5
	impact.add_child(afterglow)
	var shards: Array[Polygon2D] = []
	for shard_index in 3:
		var shard := Polygon2D.new()
		shard.name = "DirectionalShard%d" % (shard_index + 1)
		shard.polygon = PackedVector2Array([
			Vector2(-3.0, 0.0), Vector2(3.0, 0.0), Vector2(0.0, -14.0 - shard_index * 4.0),
		])
		impact.add_child(shard)
		shards.append(shard)
	var scars: Array[Line2D] = []
	for scar_index in 2:
		var scar := Line2D.new()
		scar.name = "GroundScar%d" % (scar_index + 1)
		scar.width = 5.0 - scar_index * 2.0
		scar.default_color = _palette[1 if scar_index == 0 else 0]
		scar.points = PackedVector2Array([
			Vector2(-34.0 - scar_index * 8.0, scar_index * 3.0),
			Vector2(-8.0, -2.0),
			Vector2(38.0 + scar_index * 10.0, scar_index * 2.0),
		])
		scar.begin_cap_mode = Line2D.LINE_CAP_ROUND
		scar.end_cap_mode = Line2D.LINE_CAP_ROUND
		impact.add_child(scar)
		scars.append(scar)
	_blade_layers.append({
		"root": root,
		"trails": trails,
		"summon": summon,
		"lock_sheath": lock_sheath,
		"impact": impact,
		"flash": flash,
		"compression": compression,
		"afterglow": afterglow,
		"shards": shards,
		"scars": scars,
	})


func _build_spark_pool(count: int) -> void:
	var spark_texture := _make_spark_texture()
	for index in count:
		var particles := GPUParticles2D.new()
		particles.name = "ImpactSparks%d" % (index + 1)
		particles.amount = 28 + _tier * 8
		particles.lifetime = 0.50
		particles.one_shot = true
		particles.explosiveness = 0.94
		particles.randomness = 0.34
		particles.local_coords = true
		particles.visibility_rect = Rect2(-96.0, -112.0, 192.0, 176.0)
		particles.texture = spark_texture
		particles.emitting = false
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.0, -1.0, 0.0)
		process.spread = 72.0
		process.gravity = Vector3(0.0, 210.0, 0.0)
		process.initial_velocity_min = 120.0
		process.initial_velocity_max = 285.0
		process.damping_min = 12.0
		process.damping_max = 36.0
		process.angular_velocity_min = -240.0
		process.angular_velocity_max = 240.0
		process.scale_min = 0.55
		process.scale_max = 1.35
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			Color(_palette[0], 1.0), Color(_palette[1], 0.82), Color(_palette[2], 0.0),
		])
		gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		process.color_ramp = ramp
		particles.process_material = process
		add_child(particles)
		_spark_emitters.append(particles)


func _emit_sparks(blade_index: int, position_value: Vector2) -> void:
	if _spark_emitters.is_empty():
		return
	var emitter := _spark_emitters[blade_index % _spark_emitters.size()]
	emitter.position = position_value
	emitter.restart()
	emitter.emitting = true


func _make_ghost_sprite(core: Sprite2D, node_name: String, ghost_alpha: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = core.texture
	sprite.texture_filter = core.texture_filter
	sprite.material = _make_energy_material(1.4, ghost_alpha)
	sprite.visible = false
	return sprite


func _make_energy_material(energy: float, ghost_alpha: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ENERGY_SHADER
	material.set_shader_parameter("edge_color", _palette[1])
	material.set_shader_parameter("core_color", _palette[0])
	material.set_shader_parameter("shadow_color", _palette[2])
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("ghost_alpha", ghost_alpha)
	return material


func _make_trail_material(layer_index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TRAIL_SHADER
	material.set_shader_parameter("head_color", _palette[0 if layer_index == 2 else 1])
	material.set_shader_parameter("tail_color", Color(_palette[2], 0.0))
	material.set_shader_parameter("layer_energy", [0.52, 0.92, 1.35][layer_index])
	material.set_shader_parameter("edge_softness", [0.42, 0.24, 0.10][layer_index])
	return material


func _sync_energy_material(material: ShaderMaterial, cadence_phase: String, energy_value: float) -> void:
	if material == null:
		return
	material.set_shader_parameter("timeline", _timeline)
	material.set_shader_parameter("energy", energy_value)
	material.set_shader_parameter("lock_amount", 1.0 if cadence_phase == "target_lock" else 0.0)


func _set_blade_layers_hidden(data: Dictionary) -> void:
	(data["summon"] as Sprite2D).visible = false
	(data["lock_sheath"] as Sprite2D).visible = false
	(data["impact"] as Node2D).visible = false
	for trail_variant in data["trails"] as Array:
		var trail := trail_variant as Line2D
		trail.visible = false
		trail.clear_points()


func _reset_counters() -> void:
	_active_summon_echo_count = 0
	_active_lock_sheath_count = 0
	_active_trail_count = 0
	_active_impact_count = 0
	_active_ground_scar_count = 0
	_lock_energy = 0.0


func _make_spark_texture() -> Texture2D:
	var image := Image.create(7, 3, false, Image.FORMAT_RGBA8)
	for x in 7:
		for y in 3:
			var center_distance := absf(float(y) - 1.0)
			var length_fade := 1.0 - absf(float(x) - 3.0) / 4.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(0.0, length_fade - center_distance * 0.38)))
	return ImageTexture.create_from_image(image)
