@tool
extends Node2D

const INITIAL_CAMERA_VIEW := Rect2(0, 0, 1280, 720)
const PREVIEW_COLOR := Color(1.0, 0.78, 0.22, 0.9)
const HOURS_PER_DAY := 24.0
const DEFAULT_TOWN_HOUR := 17.0
const GOLDEN_HOUR_START := 15.0 / HOURS_PER_DAY
const GOLDEN_HOUR_PEAK := 16.0 / HOURS_PER_DAY
const GOLDEN_HOUR_PLATEAU_END := 17.5 / HOURS_PER_DAY
const GOLDEN_HOUR_END := 18.0 / HOURS_PER_DAY
const DUSK_START := 17.5 / HOURS_PER_DAY
const DUSK_PEAK := 18.0 / HOURS_PER_DAY
const DUSK_END := 20.0 / HOURS_PER_DAY
const NIGHT_START := 21.0 / HOURS_PER_DAY
const DAY_SKY_TINT := Color.WHITE
const DAY_CLOUD_TINT := Color.WHITE
const DAY_TOWN_TINT := Color.WHITE
const GOLDEN_SKY_ZENITH := Color("6f8fbd")
const GOLDEN_SKY_HORIZON := Color("ff9f59")
const GOLDEN_SKY_GLOW := Color("ffd28b")
const DUSK_SKY_ZENITH := Color("657daa")
const DUSK_SKY_HORIZON := Color("e99b78")
const DUSK_SKY_GLOW := Color("ffc080")
const GOLDEN_CLOUD_TINT := Color("fff0df")
const GOLDEN_CLOUD_SHADOW := Color("cba8b4")
const GOLDEN_CLOUD_LIGHT := Color("ffe2b8")
const DUSK_CLOUD_TINT := Color("f0d8d0")
const DUSK_CLOUD_SHADOW := Color("aaa0bc")
const DUSK_CLOUD_LIGHT := Color("f6c09f")
const GOLDEN_SCENERY_TINT := Color("fff3e8")
const GOLDEN_ACTOR_TINT := Color("fff8f2")
const GOLDEN_EMISSIVE_TINT := Color("fffdf9")
const DUSK_SCENERY_TINT := Color("eee7e4")
const DUSK_ACTOR_TINT := Color("f4ecea")
const DUSK_EMISSIVE_TINT := Color("fff8f0")
const GOLDEN_HIGHLIGHT_TINT := Color(1.045, 1.012, 0.975, 1.0)
const GOLDEN_SHADOW_TINT := Color(0.94, 0.965, 1.02, 1.0)
const DUSK_HIGHLIGHT_TINT := Color(1.025, 0.99, 0.975, 1.0)
const DUSK_SHADOW_TINT := Color(0.92, 0.94, 1.025, 1.0)
const GOLDEN_HAZE_COLOR := Color("e9a76e")
const DUSK_HAZE_COLOR := Color("c78682")
const SUNSET_LIGHT_COLOR := Color("ffe0a8")
const SUN_DIRECTION := Vector2(1.0, 0.18)
const CLOUD_SHADOW_SOURCE_INDICES := [0, 3, 6]
const CLOUD_SHADOW_CENTER_OFFSETS := [0.56, 0.41, 0.32]
const CLOUD_SHADOW_CENTER_YS := [0.62, 0.76, 0.68]
const CLOUD_SHADOW_WIDTHS := [0.36, 0.31, 0.42]
const CLOUD_SHADOW_HEIGHTS := [0.075, 0.065, 0.09]
const CLOUD_SHADOW_SKEWS := [0.08, 0.31, -0.16]
const CLOUD_SHADOW_PHASES := [0.7, 2.9, 5.2]
const CLOUD_SHADOW_SOFTNESS := [0.04, 0.1, 0.07]
const CLOUD_SHADOW_OPACITIES := [0.46, 0.42, 0.5]
const SCENERY_LIGHTING_PATHS := [
	NodePath("Buildings"),
	NodePath("Ground"),
	NodePath("Props"),
]
const ACTOR_LIGHTING_PATHS := [
	NodePath("NPCs"),
	NodePath("Player"),
]
const EMISSIVE_LIGHTING_PATHS := [
	NodePath("Portals"),
	NodePath("EternalForgeIdentity"),
]

var _time_of_day_progress := DEFAULT_TOWN_HOUR / HOURS_PER_DAY
var _time_transition: Tween


func _ready() -> void:
	set_time_of_day_progress(_time_of_day_progress)
	if Engine.is_editor_hint():
		queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	refresh_cloud_shadows()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(INITIAL_CAMERA_VIEW, PREVIEW_COLOR, false, 3.0)
	draw_line(Vector2(640, 0), Vector2(640, 18), PREVIEW_COLOR, 3.0)


func set_time_of_day_progress(progress: float) -> void:
	_time_of_day_progress = clampf(progress, 0.0, 1.0)
	var golden_weight := _window_weight(
		_time_of_day_progress,
		GOLDEN_HOUR_START,
		GOLDEN_HOUR_PEAK,
		GOLDEN_HOUR_PLATEAU_END,
		GOLDEN_HOUR_END
	)
	var dusk_weight := smoothstep(DUSK_START, DUSK_PEAK, _time_of_day_progress)
	dusk_weight *= 1.0 - smoothstep(DUSK_END, NIGHT_START, _time_of_day_progress)
	var sky_zenith := DAY_SKY_TINT.lerp(GOLDEN_SKY_ZENITH, golden_weight)
	sky_zenith = sky_zenith.lerp(DUSK_SKY_ZENITH, dusk_weight)
	var sky_horizon := DAY_SKY_TINT.lerp(GOLDEN_SKY_HORIZON, golden_weight)
	sky_horizon = sky_horizon.lerp(DUSK_SKY_HORIZON, dusk_weight)
	var sky_glow := GOLDEN_SKY_GLOW.lerp(DUSK_SKY_GLOW, dusk_weight)
	var sky_strength := maxf(golden_weight * 0.92, dusk_weight * 0.86)
	var cloud_tint := DAY_CLOUD_TINT.lerp(GOLDEN_CLOUD_TINT, golden_weight)
	cloud_tint = cloud_tint.lerp(DUSK_CLOUD_TINT, dusk_weight)
	var cloud_shadow := Color.WHITE.lerp(GOLDEN_CLOUD_SHADOW, golden_weight)
	cloud_shadow = cloud_shadow.lerp(DUSK_CLOUD_SHADOW, dusk_weight)
	var cloud_light := Color.WHITE.lerp(GOLDEN_CLOUD_LIGHT, golden_weight)
	cloud_light = cloud_light.lerp(DUSK_CLOUD_LIGHT, dusk_weight)
	var cloud_lighting_strength := maxf(golden_weight * 0.72, dusk_weight * 0.82)
	var scenery_tint := DAY_TOWN_TINT.lerp(GOLDEN_SCENERY_TINT, golden_weight)
	scenery_tint = scenery_tint.lerp(DUSK_SCENERY_TINT, dusk_weight)
	var actor_tint := DAY_TOWN_TINT.lerp(GOLDEN_ACTOR_TINT, golden_weight)
	actor_tint = actor_tint.lerp(DUSK_ACTOR_TINT, dusk_weight)
	var emissive_tint := DAY_TOWN_TINT.lerp(GOLDEN_EMISSIVE_TINT, golden_weight)
	emissive_tint = emissive_tint.lerp(DUSK_EMISSIVE_TINT, dusk_weight)
	var phase_strength := maxf(golden_weight, dusk_weight)
	var current_hour := _time_of_day_progress * HOURS_PER_DAY
	var sun_x := lerpf(0.2, -0.08, clampf((current_hour - 15.0) / 3.0, 0.0, 1.0))
	var backdrop := get_node_or_null("ParallaxBackground")
	if backdrop != null:
		var sky := backdrop.get_node_or_null("Sky")
		if sky != null and sky.has_method("set_sky_tint"):
			sky.call("set_sky_tint", DAY_SKY_TINT)
			if sky.has_method("set_sky_atmosphere"):
				sky.call(
					"set_sky_atmosphere",
					sky_zenith,
					sky_horizon,
					sky_strength,
					sky_glow,
					phase_strength * 0.96,
					sun_x
				)
		var clouds := backdrop.get_node_or_null("Clouds")
		if clouds != null and clouds.has_method("set_cloud_tint"):
			clouds.call("set_cloud_tint", cloud_tint)
			if clouds.has_method("set_cloud_lighting"):
				clouds.call("set_cloud_lighting", cloud_shadow, cloud_light, cloud_lighting_strength)
		var ambient_animation := backdrop.get_node_or_null("AmbientAnimation")
		if ambient_animation != null and ambient_animation.has_method("set_sunset_lighting_strength"):
			ambient_animation.call(
				"set_sunset_lighting_strength",
				maxf(golden_weight, dusk_weight * 0.72)
			)
		for child in backdrop.get_children():
			if child == sky or child == clouds:
				continue
			if child is CanvasItem:
				var child_tint := emissive_tint if child.name in [&"EternalFlameAnimation", &"BattlePortalAnimation"] else scenery_tint
				(child as CanvasItem).modulate = child_tint
	_apply_tint_to_paths(SCENERY_LIGHTING_PATHS, scenery_tint)
	_apply_tint_to_paths(ACTOR_LIGHTING_PATHS, actor_tint)
	_apply_tint_to_paths(EMISSIVE_LIGHTING_PATHS, emissive_tint)
	_apply_atmosphere_grade(golden_weight, dusk_weight)
	refresh_cloud_shadows()


func set_time_of_day_hour(hour: float) -> void:
	set_time_of_day_progress(clampf(hour, 0.0, HOURS_PER_DAY) / HOURS_PER_DAY)


func transition_to_time_of_day_hour(hour: float, duration: float = 8.0) -> void:
	if _time_transition != null and _time_transition.is_valid():
		_time_transition.kill()
	var target_progress := clampf(hour, 0.0, HOURS_PER_DAY) / HOURS_PER_DAY
	if duration <= 0.0:
		set_time_of_day_progress(target_progress)
		return
	_time_transition = create_tween()
	_time_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_time_transition.tween_method(set_time_of_day_progress, _time_of_day_progress, target_progress, duration)


func set_time_of_day_preset(preset: StringName) -> bool:
	match preset:
		&"day":
			set_time_of_day_hour(12.0)
		&"golden_hour":
			set_time_of_day_hour(DEFAULT_TOWN_HOUR)
		&"evening":
			set_time_of_day_hour(18.0)
		_:
			return false
	return true


func get_time_of_day_contract() -> Dictionary:
	return {
		"progress": _time_of_day_progress,
		"hour": _time_of_day_progress * HOURS_PER_DAY,
		"golden_hour_start": GOLDEN_HOUR_START,
		"golden_hour_peak": GOLDEN_HOUR_PEAK,
		"golden_hour_plateau_end": GOLDEN_HOUR_PLATEAU_END,
		"golden_hour_end": GOLDEN_HOUR_END,
		"golden_weight": _window_weight(
			_time_of_day_progress,
			GOLDEN_HOUR_START,
			GOLDEN_HOUR_PEAK,
			GOLDEN_HOUR_PLATEAU_END,
			GOLDEN_HOUR_END
		),
		"dusk_weight": smoothstep(DUSK_START, DUSK_PEAK, _time_of_day_progress)
			* (1.0 - smoothstep(DUSK_END, NIGHT_START, _time_of_day_progress)),
		"dynamic_transition": true,
		"affects_all_world_objects": true,
		"cozy_palette_unification": true,
		"excluded_canvas_layer": 10,
		"golden_plateau_hours": (GOLDEN_HOUR_PLATEAU_END - GOLDEN_HOUR_PEAK) * HOURS_PER_DAY,
		"golden_transition_hours": maxf(
			GOLDEN_HOUR_PEAK - GOLDEN_HOUR_START,
			GOLDEN_HOUR_END - GOLDEN_HOUR_PLATEAU_END
		) * HOURS_PER_DAY,
		"sun_direction": SUN_DIRECTION,
		"cloud_shadow_count": _cloud_shadow_count(),
		"synchronized_targets": (
			SCENERY_LIGHTING_PATHS.size()
			+ ACTOR_LIGHTING_PATHS.size()
			+ EMISSIVE_LIGHTING_PATHS.size()
		),
	}


func _window_weight(
	value: float,
	start: float,
	peak_start: float,
	peak_end: float,
	end: float
) -> float:
	var rise := smoothstep(start, peak_start, value)
	var fall := 1.0 - smoothstep(peak_end, end, value)
	return minf(rise, fall)


func _apply_tint_to_paths(paths: Array, tint: Color) -> void:
	for path in paths:
		var target := get_node_or_null(path) as CanvasItem
		if target != null:
			target.modulate = tint


func _apply_atmosphere_grade(golden_weight: float, dusk_weight: float) -> void:
	var color_grade := get_node_or_null("TownAtmosphere/ColorGrade") as ColorRect
	if color_grade == null:
		return
	var shader_material := color_grade.material as ShaderMaterial
	if shader_material == null:
		return
	var highlight_tint := Color.WHITE.lerp(GOLDEN_HIGHLIGHT_TINT, golden_weight)
	highlight_tint = highlight_tint.lerp(DUSK_HIGHLIGHT_TINT, dusk_weight)
	var shadow_tint := Color.WHITE.lerp(GOLDEN_SHADOW_TINT, golden_weight)
	shadow_tint = shadow_tint.lerp(DUSK_SHADOW_TINT, dusk_weight)
	var haze_color := GOLDEN_HAZE_COLOR.lerp(DUSK_HAZE_COLOR, dusk_weight)
	var grade_strength := maxf(golden_weight * 0.18, dusk_weight * 0.16)
	var haze_strength := maxf(golden_weight * 0.08, dusk_weight * 0.1)
	shader_material.set_shader_parameter("warm_highlight_tint", highlight_tint)
	shader_material.set_shader_parameter("cool_shadow_tint", shadow_tint)
	shader_material.set_shader_parameter("horizon_haze_color", haze_color)
	shader_material.set_shader_parameter("grade_strength", grade_strength)
	shader_material.set_shader_parameter("haze_strength", haze_strength)
	shader_material.set_shader_parameter("sun_reach", 0.84)
	shader_material.set_shader_parameter("sunset_light_color", SUNSET_LIGHT_COLOR)
	shader_material.set_shader_parameter("sun_direction", SUN_DIRECTION)
	shader_material.set_shader_parameter(
		"sunlight_strength",
		maxf(golden_weight * 0.88, dusk_weight * 0.42)
	)
	shader_material.set_shader_parameter(
		"cozy_palette_strength",
		maxf(golden_weight * 0.16, dusk_weight * 0.14)
	)
	shader_material.set_shader_parameter(
		"cloud_shadow_strength",
		maxf(golden_weight * 0.18, dusk_weight * 0.11)
	)


func refresh_cloud_shadows() -> void:
	var color_grade := get_node_or_null("TownAtmosphere/ColorGrade") as ColorRect
	var clouds := get_node_or_null("ParallaxBackground/Clouds")
	if color_grade == null or clouds == null:
		return
	var shader_material := color_grade.material as ShaderMaterial
	if shader_material == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1942.0, 720.0)
	var canvas_transform := get_viewport().get_canvas_transform()
	var canvas_scale := canvas_transform.get_scale()
	shader_material.set_shader_parameter(
		"ray_world_offset",
		-canvas_transform.origin / viewport_size
	)
	shader_material.set_shader_parameter(
		"ray_canvas_scale",
		Vector2(absf(canvas_scale.x), absf(canvas_scale.y))
	)
	var shadows := PackedVector4Array()
	var shapes := PackedVector4Array()
	for field_index in range(CLOUD_SHADOW_SOURCE_INDICES.size()):
		var source_index: int = CLOUD_SHADOW_SOURCE_INDICES[field_index]
		if source_index >= clouds.get_child_count():
			continue
		var cloud := clouds.get_child(source_index) as Sprite2D
		if cloud == null or cloud.texture == null:
			continue
		var screen_position := canvas_transform * cloud.global_position
		var projected_x_ratio := fposmod(
			screen_position.x / viewport_size.x + CLOUD_SHADOW_CENTER_OFFSETS[field_index],
			1.6
		) - 0.3
		var projected_y_ratio: float = CLOUD_SHADOW_CENTER_YS[field_index]
		var opacity: float = CLOUD_SHADOW_OPACITIES[field_index]
		shadows.append(Vector4(
			projected_x_ratio,
			projected_y_ratio,
			CLOUD_SHADOW_WIDTHS[field_index],
			opacity
		))
		shapes.append(Vector4(
			CLOUD_SHADOW_HEIGHTS[field_index],
			CLOUD_SHADOW_SKEWS[field_index],
			CLOUD_SHADOW_PHASES[field_index],
			CLOUD_SHADOW_SOFTNESS[field_index]
		))
	shader_material.set_shader_parameter("cloud_shadows", shadows)
	shader_material.set_shader_parameter("cloud_shadow_shapes", shapes)
	shader_material.set_shader_parameter("cloud_shadow_count", shadows.size())


func _cloud_shadow_count() -> int:
	return CLOUD_SHADOW_SOURCE_INDICES.size()
