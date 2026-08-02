@tool
extends Node2D

const INITIAL_CAMERA_VIEW := Rect2(0, 0, 1280, 720)
const PREVIEW_COLOR := Color(1.0, 0.78, 0.22, 0.9)
const GOLDEN_HOUR_START := 0.65
const DAY_SKY_TINT := Color.WHITE
const DAY_CLOUD_TINT := Color.WHITE
const DAY_TOWN_TINT := Color.WHITE
const GOLDEN_SKY_TINT := Color(1.55, 1.0, 0.58, 1.0)
const GOLDEN_CLOUD_TINT := Color("ffd8ba")
const GOLDEN_TOWN_TINT := Color("ffd0a3")
const TOWN_LIGHTING_PATHS := [
	NodePath("Buildings"),
	NodePath("Ground"),
	NodePath("Props"),
	NodePath("Portals"),
	NodePath("NPCs"),
	NodePath("EternalForgeIdentity"),
	NodePath("Player"),
]

var _time_of_day_progress := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(INITIAL_CAMERA_VIEW, PREVIEW_COLOR, false, 3.0)
	draw_line(Vector2(640, 0), Vector2(640, 18), PREVIEW_COLOR, 3.0)


func set_time_of_day_progress(progress: float) -> void:
	_time_of_day_progress = clampf(progress, 0.0, 1.0)
	var golden_weight := smoothstep(GOLDEN_HOUR_START, 1.0, _time_of_day_progress)
	var sky_tint := DAY_SKY_TINT.lerp(GOLDEN_SKY_TINT, golden_weight)
	var cloud_tint := DAY_CLOUD_TINT.lerp(GOLDEN_CLOUD_TINT, golden_weight)
	var town_tint := DAY_TOWN_TINT.lerp(GOLDEN_TOWN_TINT, golden_weight)
	var backdrop := get_node_or_null("ParallaxBackground")
	if backdrop != null:
		var sky := backdrop.get_node_or_null("Sky")
		if sky != null and sky.has_method("set_sky_tint"):
			sky.call("set_sky_tint", DAY_SKY_TINT)
			if sky.has_method("set_sky_grade"):
				sky.call("set_sky_grade", sky_tint, golden_weight * 0.88)
		var clouds := backdrop.get_node_or_null("Clouds")
		if clouds != null and clouds.has_method("set_cloud_tint"):
			clouds.call("set_cloud_tint", cloud_tint)
		for child in backdrop.get_children():
			if child == sky or child == clouds:
				continue
			if child is CanvasItem:
				(child as CanvasItem).modulate = town_tint
	for path in TOWN_LIGHTING_PATHS:
		var target := get_node_or_null(path) as CanvasItem
		if target != null:
			target.modulate = town_tint


func set_time_of_day_preset(preset: StringName) -> bool:
	match preset:
		&"day":
			set_time_of_day_progress(0.0)
		&"golden_hour":
			set_time_of_day_progress(1.0)
		_:
			return false
	return true


func get_time_of_day_contract() -> Dictionary:
	return {
		"progress": _time_of_day_progress,
		"golden_hour_start": GOLDEN_HOUR_START,
		"synchronized_targets": TOWN_LIGHTING_PATHS.size(),
	}
