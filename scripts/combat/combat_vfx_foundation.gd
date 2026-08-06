class_name CombatVFXFoundation
extends Node2D

const BASE_LAYER_IDS := [
	"dark_slash_trail",
	"bright_slash_core",
	"impact_flash",
	"impact_flare",
	"impact_shockwave",
	"impact_sparks",
]
const FIRE_LAYER_IDS := [
	"flame_body",
	"flame_dissolve",
	"fire_smoke",
	"floating_embers",
	"explosion_fire",
	"explosion_smoke",
]
const IMPACT_STYLES := {
	"sword_rain": "vertical_blade_star",
	"moon_wheel": "crescent_cross",
	"feather": "feather_star",
	"ancient_wood": "branching_gate",
	"giant_stone": "ground_burst",
	"great_shield": "frontal_ward",
	"fire": "flame_bloom",
	"lightning": "forked_flash",
	"water_flow": "splash_crown",
	"plant_attack": "thorn_bloom",
	"dragon_breath": "dragon_cone",
	"dawn_vitality": "sun_cross",
	"shared_branch_vitality": "dual_cross",
}
const SERIES_COLORS := {
	"sword_rain": [Color("bde9ff"), Color("f8ffff"), Color("173b62")],
	"moon_wheel": [Color("9ccfff"), Color("fff4ce"), Color("221c56")],
	"feather": [Color("fff1a8"), Color("ffffff"), Color("815c22")],
	"ancient_wood": [Color("82e48b"), Color("f5ffd4"), Color("183f2b")],
	"giant_stone": [Color("d3b783"), Color("fff0bf"), Color("38291f")],
	"great_shield": [Color("78baff"), Color("fff4bd"), Color("18304f")],
	"fire": [Color("ff5b18"), Color("fff09a"), Color("4d0905")],
	"lightning": [Color("8f8cff"), Color("ffffff"), Color("28175c")],
	"water_flow": [Color("45c8ff"), Color("e5ffff"), Color("123c66")],
	"plant_attack": [Color("9be052"), Color("f1ff9b"), Color("284116")],
	"dragon_breath": [Color("c280ff"), Color("fff0ff"), Color("32164f")],
	"dawn_vitality": [Color("ffc44d"), Color("fffbe0"), Color("6b3215")],
	"shared_branch_vitality": [Color("62e3bd"), Color("fff8c9"), Color("173c40")],
}

var _series_id := ""
var _tier_rank := 1
var _progress := 0.0
var _impact_energy := 0.0
var _previous_impact_energy := 0.0
var _source := Vector2.ZERO
var _target := Vector2.ZERO
var _primary := Color.WHITE
var _core := Color.WHITE
var _shadow := Color.BLACK
var _dark_slash: Line2D
var _bright_slash: Line2D
var _flash: Polygon2D
var _flare: Polygon2D
var _shockwave: Line2D
var _sparks: CPUParticles2D
var _flame_body: CPUParticles2D
var _flame_dissolve: Line2D
var _fire_smoke: CPUParticles2D
var _embers: CPUParticles2D
var _explosion_fire: CPUParticles2D
var _explosion_smoke: CPUParticles2D
var _dark_slash_material: ShaderMaterial
var _bright_slash_material: ShaderMaterial
var _flame_material: ShaderMaterial


func _ready() -> void:
	_build_layers()
	reset()


func configure(series_id: String, tier_rank: int) -> void:
	_series_id = series_id
	_tier_rank = clampi(tier_rank, 1, 3)
	var palette := SERIES_COLORS.get(series_id, SERIES_COLORS["sword_rain"]) as Array
	_primary = palette[0] as Color
	_core = palette[1] as Color
	_shadow = palette[2] as Color
	_apply_palette()
	reset()


func set_progress(
	progress: float,
	source: Vector2,
	target: Vector2,
	impact_ratio: float,
	impact_end: float
) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_dark_slash_material.set_shader_parameter("phase", _progress)
	_bright_slash_material.set_shader_parameter("phase", _progress)
	_flame_material.set_shader_parameter("phase", _progress)
	_source = source
	_target = target
	var execution := smoothstep(0.08, impact_ratio, _progress)
	_previous_impact_energy = _impact_energy
	_impact_energy = _window(_progress, impact_ratio - 0.025, impact_ratio + 0.035, impact_end + 0.10)
	_update_slash(execution, impact_end)
	_update_impact()
	_update_fire(execution, impact_end)
	if _impact_energy > 0.05 and _previous_impact_energy <= 0.05:
		_restart_impact_particles()


func reset() -> void:
	_progress = 0.0
	_impact_energy = 0.0
	_previous_impact_energy = 0.0
	for item in [_dark_slash, _bright_slash, _flash, _flare, _shockwave, _flame_dissolve]:
		if item != null:
			(item as CanvasItem).visible = false
	for particles in [_sparks, _flame_body, _fire_smoke, _embers, _explosion_fire, _explosion_smoke]:
		if particles != null:
			(particles as CPUParticles2D).emitting = false
			(particles as CPUParticles2D).visible = false


func get_active_layer_count() -> int:
	return BASE_LAYER_IDS.size() + (FIRE_LAYER_IDS.size() if _series_id == "fire" else 0)


func get_debug_state() -> Dictionary:
	return {
		"series_id": _series_id,
		"tier_rank": _tier_rank,
		"layers": get_layer_ids(),
		"impact_style": String(IMPACT_STYLES.get(_series_id, "directional_flash")),
		"impact_energy": _impact_energy,
		"attachment_mode": "object_outline" if _series_id == "fire" else "attack_path",
		"slash_layer_count": 2,
		"impact_layer_count": 4,
		"fire_layer_count": FIRE_LAYER_IDS.size() if _series_id == "fire" else 0,
		"slash_scroll_shader": true,
		"flame_dissolve_shader": _series_id == "fire",
	}


func get_layer_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(BASE_LAYER_IDS)
	if _series_id == "fire":
		result.append_array(FIRE_LAYER_IDS)
	return result


func _build_layers() -> void:
	if _dark_slash != null:
		return
	_dark_slash = _line_layer("DarkSlashTrail", 13.0, -4)
	_bright_slash = _line_layer("BrightSlashCore", 4.2, -3)
	_dark_slash_material = _slash_material(false)
	_bright_slash_material = _slash_material(true)
	_dark_slash.material = _dark_slash_material
	_bright_slash.material = _bright_slash_material
	_flash = _polygon_layer("ImpactFlash", 5)
	_flare = _polygon_layer("ImpactFlare", 4)
	_shockwave = _line_layer("ImpactShockwave", 5.0, 2)
	_sparks = _particle_layer("ImpactSparks", 18, 0.32, 160.0, 260.0, Vector2(0, 85), 4)
	_flame_body = _particle_layer("FlameBody", 22, 0.58, 24.0, 62.0, Vector2(0, -46), -2)
	_flame_dissolve = _line_layer("FlameDissolve", 7.0, -1)
	_flame_material = _flame_dissolve_material()
	_flame_dissolve.material = _flame_material
	_fire_smoke = _particle_layer("FireSmoke", 10, 0.82, 15.0, 38.0, Vector2(0, -30), -3)
	_embers = _particle_layer("FloatingEmbers", 14, 0.72, 40.0, 96.0, Vector2(0, -18), 1)
	_explosion_fire = _particle_layer("ExplosionFire", 16, 0.38, 90.0, 185.0, Vector2(0, 20), 2)
	_explosion_smoke = _particle_layer("ExplosionSmoke", 11, 0.72, 34.0, 82.0, Vector2(0, -18), 1)


func _line_layer(node_name: String, width: float, layer_z: int) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.width = width
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = layer_z
	line.material = _additive_material()
	add_child(line)
	return line


func _polygon_layer(node_name: String, layer_z: int) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.z_index = layer_z
	polygon.material = _additive_material()
	add_child(polygon)
	return polygon


func _particle_layer(
	node_name: String,
	amount: int,
	lifetime: float,
	velocity_min: float,
	velocity_max: float,
	gravity: Vector2,
	layer_z: int
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.48
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.gravity = gravity
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.25
	particles.z_index = layer_z
	particles.material = _additive_material()
	particles.texture = _particle_texture()
	add_child(particles)
	return particles


func _particle_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 10
	texture.height = 4
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	return texture


func _additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return material


func _slash_material(is_core: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 trail_color : source_color = vec4(1.0);
uniform float phase = 0.0;
uniform float core_pass = 0.0;
void fragment() {
	float moving = fract(UV.x * mix(3.0, 6.0, core_pass) - phase * mix(4.0, 8.0, core_pass));
	float head = smoothstep(0.02, 0.22, moving) * (1.0 - smoothstep(0.68, 1.0, moving));
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	float alpha = mix(0.32 + head * 0.54, 0.58 + head * 0.42, core_pass) * smoothstep(0.0, 0.34, edge);
	COLOR = vec4(trail_color.rgb, trail_color.a * alpha) * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("core_pass", 1.0 if is_core else 0.0)
	return material


func _flame_dissolve_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 flame_color : source_color = vec4(1.0, 0.3, 0.02, 1.0);
uniform vec4 flame_core : source_color = vec4(1.0, 0.95, 0.5, 1.0);
uniform float phase = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 cell = floor(UV * vec2(14.0, 7.0) + vec2(0.0, -phase * 16.0));
	float noise = hash(cell);
	float tongue = smoothstep(0.22, 0.82, noise + (1.0 - UV.y) * 0.42);
	float pulse = 0.78 + 0.22 * sin((UV.x * 5.0 - phase * 3.0) * 6.28318);
	vec3 color = mix(flame_color.rgb, flame_core.rgb, tongue * pulse);
	COLOR = vec4(color, flame_color.a * tongue) * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _apply_palette() -> void:
	_dark_slash.default_color = Color(_shadow, 0.72)
	_bright_slash.default_color = Color(_core, 0.96)
	_dark_slash_material.set_shader_parameter("trail_color", Color(_shadow, 0.86))
	_bright_slash_material.set_shader_parameter("trail_color", Color(_core, 1.0))
	_flash.color = Color(_core, 0.92)
	_flare.color = Color(_primary, 0.78)
	_shockwave.default_color = Color(_primary, 0.70)
	_flame_dissolve.default_color = Color(_primary, 0.84)
	_flame_material.set_shader_parameter("flame_color", Color(_primary, 0.92))
	_flame_material.set_shader_parameter("flame_core", Color(_core, 1.0))
	_sparks.color = _core
	_flame_body.color = _primary
	_fire_smoke.color = Color(_shadow.lightened(0.18), 0.56)
	_embers.color = _core
	_explosion_fire.color = _primary
	_explosion_smoke.color = Color(_shadow.lightened(0.12), 0.62)


func _update_slash(execution: float, impact_end: float) -> void:
	var fade := 1.0 - smoothstep(impact_end, 1.0, _progress)
	var axis := _target - _source
	var normal := axis.normalized().orthogonal()
	var current_target := _source.lerp(_target, execution)
	var bend := normal * (28.0 + 10.0 * _tier_rank) * sin(execution * PI)
	var points := _bezier_points(_source, _source.lerp(current_target, 0.52) + bend, current_target, 18)
	_dark_slash.points = points
	_bright_slash.points = points
	_dark_slash.width = (11.0 + _tier_rank * 3.0) * (0.72 + execution * 0.28)
	_bright_slash.width = (2.6 + _tier_rank * 0.9) * (0.82 + execution * 0.18)
	_dark_slash.modulate.a = execution * fade * 0.62
	_bright_slash.modulate.a = execution * fade
	_dark_slash.visible = execution > 0.01 and fade > 0.01
	_bright_slash.visible = _dark_slash.visible


func _update_impact() -> void:
	var energy := _impact_energy
	var ray_count := 4 + _tier_rank * 2
	if _series_id in ["feather", "dawn_vitality"]:
		ray_count += 2
	elif _series_id in ["lightning", "plant_attack"]:
		ray_count += 1
	_flash.polygon = _star_points(10.0 + energy * (25.0 + 8.0 * _tier_rank), ray_count, 0.18)
	_flare.polygon = _star_points(8.0 + energy * (42.0 + 10.0 * _tier_rank), maxi(4, ray_count - 2), 0.08)
	_flash.position = _target
	_flare.position = _target
	_flash.rotation = _progress * (0.18 if _series_id != "lightning" else -0.32)
	_flare.rotation = -_flash.rotation * 1.7 + PI * 0.25
	_flash.modulate.a = energy
	_flare.modulate.a = energy * 0.72
	_flash.visible = energy > 0.01
	_flare.visible = energy > 0.01
	_shockwave.position = _target
	_shockwave.points = _circle_points(12.0 + energy * (54.0 + 12.0 * _tier_rank), 34)
	_shockwave.width = lerpf(7.0, 1.4, energy)
	_shockwave.modulate.a = energy * 0.76
	_shockwave.visible = energy > 0.01
	_sparks.position = _target
	_sparks.visible = energy > 0.01


func _update_fire(execution: float, impact_end: float) -> void:
	var enabled := _series_id == "fire"
	for particles in [_flame_body, _fire_smoke, _embers, _explosion_fire, _explosion_smoke]:
		(particles as CPUParticles2D).visible = enabled
	_flame_dissolve.visible = enabled
	if not enabled:
		return
	var anchor := _source.lerp(_target, execution)
	_flame_body.position = anchor
	_fire_smoke.position = anchor + Vector2(0, -12)
	_embers.position = anchor
	_flame_body.emitting = _progress < impact_end
	_fire_smoke.emitting = _progress < impact_end
	_embers.emitting = _progress < impact_end
	var flame_radius := 18.0 + 7.0 * _tier_rank
	var flame_points := PackedVector2Array()
	for index in 18:
		var ratio := float(index) / 17.0
		var angle := ratio * TAU
		var noise := 0.78 + 0.22 * sin(angle * 5.0 + _progress * TAU * 3.0)
		flame_points.append(anchor + Vector2(cos(angle), sin(angle)) * flame_radius * noise)
	flame_points.append(flame_points[0])
	_flame_dissolve.points = flame_points
	_flame_dissolve.modulate.a = (1.0 - smoothstep(impact_end, 1.0, _progress)) * 0.74
	_explosion_fire.position = _target
	_explosion_smoke.position = _target
	_explosion_fire.visible = _impact_energy > 0.01
	_explosion_smoke.visible = _impact_energy > 0.01


func _restart_impact_particles() -> void:
	_sparks.restart()
	if _series_id == "fire":
		_explosion_fire.restart()
		_explosion_smoke.restart()


func _bezier_points(start: Vector2, control: Vector2, finish: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count:
		var ratio := float(index) / float(count - 1)
		var inverse := 1.0 - ratio
		points.append(start * inverse * inverse + control * 2.0 * inverse * ratio + finish * ratio * ratio)
	return points


func _star_points(radius: float, rays: int, inner_ratio: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in rays * 2:
		var point_radius := radius if index % 2 == 0 else radius * inner_ratio
		var angle := TAU * float(index) / float(rays * 2)
		points.append(Vector2(cos(angle), sin(angle)) * point_radius)
	return points


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count + 1:
		var angle := TAU * float(index) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _window(value: float, start: float, peak: float, finish: float) -> float:
	if value <= start or value >= finish:
		return 0.0
	return smoothstep(start, peak, value) * (1.0 - smoothstep(peak, finish, value))
