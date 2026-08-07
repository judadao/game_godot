class_name SkillVFXComposer2D
extends Node2D

const MUTATION_CATALOG := preload("res://scripts/vfx/blessing_vfx_mutation_catalog.gd")
const CORE_SHADER := preload("res://shaders/vfx/skill_vfx_stack.gdshader")
const PRIMITIVE_SCENES := {
	"fire_burst": preload("res://scenes/vfx/primitives/fire/fire_burst.tscn"),
	"lightning_impact": preload("res://scenes/vfx/primitives/lightning/lightning_impact.tscn"),
	"water_splash": preload("res://scenes/vfx/primitives/water/water_splash.tscn"),
	"poison_splash": preload("res://scenes/vfx/primitives/poison/poison_splash.tscn"),
	"ice_shatter": preload("res://scenes/vfx/primitives/ice/ice_shatter.tscn"),
	"wind_burst": preload("res://scenes/vfx/primitives/wind/wind_burst.tscn"),
}
const IMPACT_PROGRESS := 0.62

var _recipe: Dictionary = {}
var _tier := 1
var _mutations: Array[Dictionary] = []
var _palette: Array[Color] = []
var _visual_count_bonus := 0
var _trajectory_variation := 0.0
var _impact_primitive := ""
var _specialized_renderer := ""
var _suppressed_generic_roles: Array[String] = []
var _role_layers: Dictionary = {}
var _impact_effect: Node2D
var _impact_started := false
var _progress := 0.0
var _source := Vector2.ZERO
var _target := Vector2(260.0, 0.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(recipe: Dictionary, tier_rank: int, blessing_overlays: Array = []) -> bool:
	clear()
	if recipe.is_empty() or not (recipe.get("grammar", []) as Array).has("core"):
		return false
	_recipe = recipe.duplicate(true)
	_tier = clampi(tier_rank, 1, 3)
	_specialized_renderer = String(_recipe.get("specialized_renderer", ""))
	if _specialized_renderer == "sword_rain_material_cadence":
		_suppressed_generic_roles.assign([
			"rain", "projectile", "trail", "ring", "impact",
		])
	elif _specialized_renderer == "persistent_feather_halo":
		_suppressed_generic_roles.assign([
			"projectile", "trail", "afterimage", "ring", "impact",
		])
	_resolve_mutations(blessing_overlays)
	_build_role_layers()
	_build_impact_primitive()
	visible = true
	return true


func configure_core_sprites(core_sprites: Array) -> void:
	for sprite_variant in core_sprites:
		if not sprite_variant is Sprite2D:
			continue
		var sprite := sprite_variant as Sprite2D
		var material := ShaderMaterial.new()
		material.shader = CORE_SHADER
		_apply_core_shader_parameters(material)
		sprite.material = material
		sprite.use_parent_material = false


func set_progress(
	value: float,
	source: Vector2,
	target: Vector2,
	core_positions: Array = [],
	impact_progress: float = IMPACT_PROGRESS
) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_source = source
	_target = target
	_update_core_materials()
	for role_variant in _role_layers:
		_update_role_layer(String(role_variant), _role_layers[role_variant] as CanvasItem, core_positions, impact_progress)
	if _impact_effect != null and is_instance_valid(_impact_effect):
		_impact_effect.position = _target
		if not _impact_started and _progress >= impact_progress:
			_impact_started = true
			_impact_effect.call("play")


func clear() -> void:
	for layer_variant in _role_layers.values():
		var layer := layer_variant as CanvasItem
		if layer != null and is_instance_valid(layer):
			remove_child(layer)
			layer.free()
	_role_layers.clear()
	if _impact_effect != null and is_instance_valid(_impact_effect):
		remove_child(_impact_effect)
		_impact_effect.free()
	_impact_effect = null
	_impact_started = false
	_recipe.clear()
	_mutations.clear()
	_palette.clear()
	_visual_count_bonus = 0
	_trajectory_variation = 0.0
	_impact_primitive = ""
	_specialized_renderer = ""
	_suppressed_generic_roles.clear()


func get_debug_state() -> Dictionary:
	return {
		"presentation_mode": "procedural_vfx_recipe",
		"recipe_id": String(_recipe.get("id", "")),
		"grammar": (_recipe.get("grammar", []) as Array).duplicate(),
		"real_visual_layer_count": _role_layers.size() + (1 if _impact_effect != null else 0) + 1,
		"mutation_count": _mutations.size(),
		"visual_count_bonus": _visual_count_bonus,
		"trajectory_variation": _trajectory_variation,
		"impact_primitive": _impact_primitive,
		"resolved_palette": _palette.duplicate(),
		"uses_existing_core_asset": not String(_recipe.get("asset_path", "")).is_empty(),
		"legacy_fallback_retained": true,
		"specialized_renderer": _specialized_renderer,
		"suppressed_generic_roles": _suppressed_generic_roles.duplicate(),
	}


func get_active_layer_count() -> int:
	return int(get_debug_state().get("real_visual_layer_count", 0))


func _resolve_mutations(blessing_overlays: Array) -> void:
	_palette = _colors_from_hex(_recipe.get("base_palette", []) as Array)
	_impact_primitive = String(_recipe.get("impact_primitive", "wind_burst"))
	for overlay_variant in blessing_overlays:
		if not overlay_variant is Dictionary:
			continue
		var overlay := overlay_variant as Dictionary
		var elements := overlay.get("elements", [overlay.get("element", "")]) as Array
		var resolved_element := ""
		for element_variant in elements:
			var candidate := String(element_variant).to_lower()
			if not MUTATION_CATALOG.get_mutation(candidate).is_empty():
				resolved_element = candidate
				break
		var mutation := MUTATION_CATALOG.get_mutation(resolved_element)
		if mutation.is_empty():
			continue
		var level := clampi(int(overlay.get("level", 1)), 1, 3)
		_mutations.append(mutation)
		_visual_count_bonus += int(mutation.get("count_bonus", 0)) * level
		_trajectory_variation += float(mutation.get("trajectory", 0.0)) * (0.7 + float(level) * 0.3)
		_impact_primitive = String(mutation.get("impact", _impact_primitive))
		var mutation_palette := _colors_from_hex(mutation.get("palette", []) as Array)
		if mutation_palette.size() == 3:
			if _palette.size() != 3:
				_palette = mutation_palette
			else:
				for color_index in 3:
					_palette[color_index] = _palette[color_index].lerp(mutation_palette[color_index], 0.46)
	_visual_count_bonus = mini(_visual_count_bonus, 12)
	_trajectory_variation = minf(_trajectory_variation, 1.4)
	if _palette.size() != 3:
		_palette = [Color.WHITE, Color("7fcfff"), Color("6855ba")]


func _build_role_layers() -> void:
	for role_variant in _recipe.get("grammar", []) as Array:
		var role := String(role_variant)
		if role in ["core", "impact"] or _suppressed_generic_roles.has(role):
			continue
		var layer: CanvasItem
		if role in ["burst", "distortion"]:
			var polygon := Polygon2D.new()
			polygon.polygon = _star_points(12, 34.0, 10.0)
			layer = polygon
		else:
			var line := Line2D.new()
			line.width = 4.0
			line.antialiased = false
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			layer = line
		layer.name = "%sLayer" % role.capitalize().replace(" ", "")
		layer.z_index = -2 if role in ["ground_zone", "aura"] else 2
		add_child(layer)
		_role_layers[role] = layer


func _build_impact_primitive() -> void:
	if _suppressed_generic_roles.has("impact"):
		_impact_primitive = "sword_rain_contact_stack"
		return
	var packed := PRIMITIVE_SCENES.get(_impact_primitive) as PackedScene
	if packed == null:
		packed = PRIMITIVE_SCENES["wind_burst"] as PackedScene
		_impact_primitive = "wind_burst"
	_impact_effect = packed.instantiate() as Node2D
	if _impact_effect == null:
		return
	_impact_effect.name = "ImpactPrimitive"
	_impact_effect.set("auto_play", false)
	_impact_effect.set("auto_free", false)
	_impact_effect.set("effect_scale", 0.58 + float(_tier) * 0.16)
	_impact_effect.set("intensity", 0.75 + float(_tier) * 0.18)
	add_child(_impact_effect)


func _update_role_layer(
	role: String,
	layer: CanvasItem,
	core_positions: Array,
	impact_progress: float
) -> void:
	var contact := clampf((_progress - impact_progress) / 0.18, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.78, 1.0, _progress)
	var role_alpha := _role_alpha(role, impact_progress) * fade
	var primary := _palette[0]
	var secondary := _palette[1]
	if layer is Line2D:
		var line := layer as Line2D
		line.default_color = secondary
		line.modulate = Color(1.0, 1.0, 1.0, role_alpha)
		line.width = (3.0 + float(_tier) * 1.4) * (1.4 if role in ["beam", "arc"] else 1.0)
		line.points = _role_points(role, core_positions)
	elif layer is Polygon2D:
		var polygon := layer as Polygon2D
		polygon.position = (
			_source.lerp(_target, smoothstep(0.08, impact_progress, _progress))
			if role == "distortion"
			else _target
		)
		var polygon_energy := role_alpha if role == "distortion" else sin(contact * PI) * role_alpha
		polygon.color = Color(primary, polygon_energy * 0.48)
		polygon.scale = Vector2.ONE * (
			0.72 + sin(_progress * PI) * 0.28
			if role == "distortion"
			else lerpf(0.2, 1.8 + float(_tier) * 0.18, contact)
		)


func _role_alpha(role: String, impact_progress: float) -> float:
	match role:
		"aura", "orbit":
			return smoothstep(0.0, 0.12, _progress) * (1.0 - smoothstep(impact_progress * 0.82, impact_progress, _progress))
		"ring":
			return maxf(
				smoothstep(0.0, 0.12, _progress) * (1.0 - smoothstep(0.32, impact_progress, _progress)),
				sin(clampf((_progress - impact_progress) / 0.2, 0.0, 1.0) * PI)
			)
		"ground_zone":
			return smoothstep(impact_progress, impact_progress + 0.08, _progress)
		"burst":
			return sin(clampf((_progress - impact_progress) / 0.2, 0.0, 1.0) * PI)
		"distortion":
			return smoothstep(0.08, 0.2, _progress) * (1.0 - smoothstep(impact_progress, impact_progress + 0.08, _progress))
		_:
			return smoothstep(0.05, 0.18, _progress) * (1.0 - smoothstep(impact_progress, impact_progress + 0.14, _progress))


func _role_points(role: String, core_positions: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var displacement := _target - _source
	var normal := displacement.normalized().orthogonal() if not displacement.is_zero_approx() else Vector2.UP
	var bend := (28.0 + _trajectory_variation * 42.0) * sin(_progress * PI)
	match role:
		"ring", "aura", "orbit", "ground_zone":
			var center := _target if role in ["ring", "ground_zone"] else _source.lerp(_target, 0.35)
			var radius := (30.0 + float(_tier) * 10.0) * (1.45 if role == "ground_zone" else 1.0)
			for index in 33:
				var angle := TAU * float(index) / 32.0
				points.append(center + Vector2(cos(angle), sin(angle) * (0.34 if role == "ground_zone" else 1.0)) * radius)
		"rain":
			var lanes := 3 + _tier + mini(_visual_count_bonus, 4)
			for index in lanes:
				var ratio := float(index) / maxf(1.0, float(lanes - 1)) - 0.5
				points.append(_target + Vector2(ratio * 150.0, -160.0))
				points.append(_target + Vector2(ratio * 72.0, 0.0))
		"bolt":
			for index in 11:
				var ratio := float(index) / 10.0
				var jitter := sin(float(index) * 9.7 + _progress * 42.0) * (8.0 + _trajectory_variation * 14.0)
				points.append(_source.lerp(_target, ratio) + normal * jitter * sin(ratio * PI))
		"afterimage":
			for position_variant in core_positions:
				if position_variant is Vector2:
					points.append(position_variant as Vector2)
			if points.size() < 2:
				points = PackedVector2Array([_source, _source.lerp(_target, _progress)])
		_:
			for index in 13:
				var ratio := float(index) / 12.0
				var curve := normal * sin(ratio * PI) * bend
				if role == "trail":
					curve += normal * sin(ratio * TAU * 2.0 + _progress * 8.0) * 5.0
				points.append(_source.lerp(_target, ratio) + curve)
	return points


func _update_core_materials() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is Sprite2D and String(child.name).begins_with("SeriesObject"):
			var material := (child as Sprite2D).material as ShaderMaterial
			if material != null and material.shader == CORE_SHADER:
				material.set_shader_parameter("timeline", _progress)
				material.set_shader_parameter("dissolve_progress", smoothstep(0.82, 1.0, _progress))


func _apply_core_shader_parameters(material: ShaderMaterial) -> void:
	material.set_shader_parameter("primary_tint", _palette[0])
	material.set_shader_parameter("secondary_tint", _palette[1])
	material.set_shader_parameter("shadow_tint", _palette[2])
	material.set_shader_parameter("mutation_mix", clampf(0.18 + float(_mutations.size()) * 0.08, 0.18, 0.72))
	material.set_shader_parameter("distortion_strength", minf(0.055, _trajectory_variation * 0.025))
	material.set_shader_parameter("noise_amount", clampf(0.18 + float(_mutations.size()) * 0.08, 0.18, 0.82))
	material.set_shader_parameter("glow_strength", 0.8 + float(_tier) * 0.22)


func _colors_from_hex(values: Array) -> Array[Color]:
	var colors: Array[Color] = []
	for value in values:
		colors.append(Color(String(value)))
	return colors


func _star_points(count: int, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count * 2:
		var angle := -PI * 0.5 + TAU * float(index) / float(count * 2)
		var radius := outer_radius if index % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
