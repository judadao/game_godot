class_name SkillCastPresentation
extends CanvasLayer

signal cast_started(cast_name: String, element: StringName, importance: float)
signal cast_finished(cast_name: String, element: StringName)

const FIRE_COLOR := Color(1.0, 0.36, 0.12, 1.0)
const ICE_COLOR := Color(0.35, 0.82, 1.0, 1.0)
const NEUTRAL_COLOR := Color(1.0, 0.88, 0.48, 1.0)
const MIN_IMPORTANCE := 0.5
const MAX_IMPORTANCE := 2.0
const MAJOR_IMPORTANCE := 1.3
const STANDARD_FLASH_PEAK := 0.14
const MAJOR_FLASH_PEAK := 0.34
const STANDARD_WASH_PEAK := 0.07
const MAJOR_WASH_PEAK := 0.16
const STANDARD_BAND_PEAK := 0.68
const MAJOR_BAND_PEAK := 0.88
const ANTICIPATION_STANDARD := 0.075
const ANTICIPATION_MAJOR := 0.10
const IMPACT_STANDARD := 0.055
const IMPACT_MAJOR := 0.06
const SETTLE_DURATION := 0.11
const EXIT_DURATION := 0.14

@export_range(0.05, 1.0, 0.01) var slow_motion_scale := 0.28
@export_range(0.1, 1.5, 0.01) var visible_duration := 0.34

@onready var _screen_wash: ColorRect = $Overlay/ScreenWash
@onready var _impact_flash: ColorRect = $Overlay/ImpactFlash
@onready var _top_bar: ColorRect = $Overlay/TopBar
@onready var _bottom_bar: ColorRect = $Overlay/BottomBar
@onready var _major_frame: Panel = $Overlay/SafeMargin/Center/MajorFrame
@onready var _cast_band: Panel = $Overlay/SafeMargin/Center/CastBand
@onready var _skill_name: Label = $Overlay/SafeMargin/Center/SkillName

var _active := false
var _cast_name := ""
var _element := &"neutral"
var _importance := 1.0
var _generation := 0
var _restore_time_scale := 1.0
var _cast_tween: Tween
var _presentation_tier := &"standard"
var _timeline_duration := 0.0
var _anticipation_duration := ANTICIPATION_STANDARD
var _impact_duration := IMPACT_STANDARD
var _hold_duration := 0.0
var _flash_peak_alpha := STANDARD_FLASH_PEAK
var _wash_peak_alpha := STANDARD_WASH_PEAK
var _band_peak_alpha := STANDARD_BAND_PEAK


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_skill_name.resized.connect(_update_title_pivot)
	_cast_band.resized.connect(_update_layer_pivots)
	_major_frame.resized.connect(_update_layer_pivots)
	_reset_visuals()
	_update_layer_pivots.call_deferred()


func _exit_tree() -> void:
	_cancel_tween()
	_reset_visuals()
	_restore_time()


func play_cast(
	cast_name: String,
	element: StringName = &"neutral",
	importance: float = 1.0,
	use_slow_motion: bool = true
) -> void:
	if not is_inside_tree():
		push_warning("SkillCastPresentation.play_cast() requires an active SceneTree.")
		return

	if not _active:
		_restore_time_scale = Engine.time_scale
	_active = true
	_generation += 1
	_cast_name = cast_name.strip_edges()
	if _cast_name.is_empty():
		_cast_name = "UNNAMED SKILL"
	_element = _normalize_element(element)
	_importance = clampf(importance, MIN_IMPORTANCE, MAX_IMPORTANCE)
	_configure_timeline()

	_cancel_tween()
	_reset_visuals()
	if use_slow_motion:
		_apply_slow_motion()
	else:
		Engine.time_scale = _restore_time_scale
	_prepare_title()
	_play_timeline(_generation)
	cast_started.emit(_cast_name, _element, _importance)


func get_cast_state() -> Dictionary:
	return {
		"active": _active,
		"cast_name": _cast_name,
		"element": String(_element),
		"importance": _importance,
		"generation": _generation,
		"restore_time_scale": _restore_time_scale,
		"current_time_scale": Engine.time_scale,
		"presentation_tier": String(_presentation_tier),
		"timeline_duration": _timeline_duration,
		"flash_peak_alpha": _flash_peak_alpha,
		"wash_peak_alpha": _wash_peak_alpha,
	}


func is_cast_active() -> bool:
	return _active


func _apply_slow_motion() -> void:
	var importance_weight := lerpf(1.12, 0.78, inverse_lerp(
		MIN_IMPORTANCE,
		MAX_IMPORTANCE,
		_importance
	))
	var target_scale := clampf(slow_motion_scale * importance_weight, 0.08, 1.0)
	Engine.time_scale = minf(_restore_time_scale, target_scale)


func _prepare_title() -> void:
	var element_color := _color_for_element(_element)
	_skill_name.text = _cast_name
	_skill_name.add_theme_font_size_override(
		"font_size",
		_title_font_size()
	)
	_skill_name.modulate = element_color
	_skill_name.visible = true
	_cast_band.modulate = element_color
	_cast_band.visible = true
	_major_frame.modulate = element_color.lightened(0.18)
	_major_frame.visible = _presentation_tier == &"major"
	_screen_wash.color = element_color.darkened(0.56)
	_impact_flash.color = element_color.lightened(0.58)
	_update_title_pivot()
	_update_layer_pivots()
	_apply_timeline(0.0)


func _configure_timeline() -> void:
	var is_major := _importance >= MAJOR_IMPORTANCE
	_presentation_tier = &"major" if is_major else &"standard"
	_anticipation_duration = ANTICIPATION_MAJOR if is_major else ANTICIPATION_STANDARD
	_impact_duration = IMPACT_MAJOR if is_major else IMPACT_STANDARD
	_flash_peak_alpha = MAJOR_FLASH_PEAK if is_major else STANDARD_FLASH_PEAK
	_wash_peak_alpha = MAJOR_WASH_PEAK if is_major else STANDARD_WASH_PEAK
	_band_peak_alpha = MAJOR_BAND_PEAK if is_major else STANDARD_BAND_PEAK
	_hold_duration = maxf(
		0.10,
		visible_duration + clampf(_importance - 1.0, -0.5, 1.0) * 0.08
	)
	_timeline_duration = (
		_anticipation_duration
		+ _impact_duration
		+ SETTLE_DURATION
		+ _hold_duration
		+ EXIT_DURATION
	)


func _play_timeline(generation: int) -> void:
	_cast_tween = create_tween()
	_cast_tween.set_ignore_time_scale(true)
	_cast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cast_tween.tween_method(
		_apply_timeline,
		0.0,
		_timeline_duration,
		_timeline_duration
	)
	_cast_tween.finished.connect(_finish_cast.bind(generation), CONNECT_ONE_SHOT)


func _apply_timeline(elapsed: float) -> void:
	var anticipation_end := _anticipation_duration
	var impact_end := anticipation_end + _impact_duration
	var settle_end := impact_end + SETTLE_DURATION
	var hold_end := settle_end + _hold_duration
	var is_major := _presentation_tier == &"major"
	var peak_scale := 1.24 if is_major else 1.10
	var start_scale := 0.62 if is_major else 0.74
	var title_alpha := 1.0
	var title_scale := 1.0
	var envelope := 1.0
	var flash_alpha := 0.0
	var wash_alpha := _wash_peak_alpha
	var band_alpha := _band_peak_alpha
	var frame_alpha := 0.78 if is_major else 0.0
	var bar_alpha := 0.72 if is_major else 0.0

	if elapsed < anticipation_end:
		var progress := _smooth_progress(elapsed, anticipation_end)
		title_alpha = lerpf(0.12, 0.72, progress)
		title_scale = lerpf(start_scale, 0.88, progress)
		wash_alpha *= progress * 0.56
		band_alpha *= progress
		frame_alpha *= progress
		bar_alpha *= progress * 0.72
	elif elapsed < impact_end:
		var progress := _smooth_progress(elapsed - anticipation_end, _impact_duration)
		title_alpha = lerpf(0.72, 1.0, progress)
		title_scale = lerpf(0.88, peak_scale, _back_out(progress))
		flash_alpha = _flash_peak_alpha * sin(progress * PI)
		frame_alpha *= lerpf(0.72, 1.0, progress)
	elif elapsed < settle_end:
		var progress := _smooth_progress(elapsed - impact_end, SETTLE_DURATION)
		title_scale = lerpf(peak_scale, 1.0, progress)
		flash_alpha = _flash_peak_alpha * 0.28 * pow(1.0 - progress, 2.0)
	elif elapsed >= hold_end:
		envelope = 1.0 - _smooth_progress(elapsed - hold_end, EXIT_DURATION)
		title_alpha = envelope
		title_scale = lerpf(1.0, 1.04, 1.0 - envelope)
		flash_alpha = 0.0

	_skill_name.modulate.a = title_alpha
	_skill_name.scale = Vector2.ONE * title_scale
	_screen_wash.modulate.a = wash_alpha * envelope
	_impact_flash.modulate.a = flash_alpha
	_cast_band.modulate.a = band_alpha * envelope
	_cast_band.scale = Vector2(lerpf(0.76, 1.0, minf(1.0, title_alpha)), 1.0)
	_major_frame.modulate.a = frame_alpha * envelope
	_major_frame.scale = Vector2(lerpf(0.88, 1.0, minf(1.0, title_alpha)), 1.0)
	_top_bar.modulate.a = bar_alpha * envelope
	_bottom_bar.modulate.a = bar_alpha * envelope


func _finish_cast(generation: int) -> void:
	if generation != _generation:
		return
	var finished_name := _cast_name
	var finished_element := _element
	_cast_tween = null
	_reset_visuals()
	_restore_time()
	cast_finished.emit(finished_name, finished_element)


func _restore_time() -> void:
	if not _active:
		return
	Engine.time_scale = _restore_time_scale
	_active = false


func _cancel_tween() -> void:
	if _cast_tween == null:
		return
	if _cast_tween.is_valid():
		_cast_tween.kill()
	_cast_tween = null


func _update_title_pivot() -> void:
	if not is_instance_valid(_skill_name):
		return
	_skill_name.pivot_offset = _skill_name.size * 0.5


func _update_layer_pivots() -> void:
	if is_instance_valid(_cast_band):
		_cast_band.pivot_offset = _cast_band.size * 0.5
	if is_instance_valid(_major_frame):
		_major_frame.pivot_offset = _major_frame.size * 0.5


func _title_font_size() -> int:
	var title_length := _cast_name.length()
	if _presentation_tier == &"major":
		if title_length > 56:
			return 38
		if title_length > 34:
			return 42
		return 58
	if title_length > 48:
		return 38
	if title_length > 32:
		return 42
	return 50


func _reset_visuals() -> void:
	if not is_node_ready():
		return
	_skill_name.visible = false
	_skill_name.modulate.a = 0.0
	_skill_name.scale = Vector2.ONE
	_cast_band.visible = false
	_cast_band.modulate.a = 0.0
	_cast_band.scale = Vector2.ONE
	_major_frame.visible = false
	_major_frame.modulate.a = 0.0
	_major_frame.scale = Vector2.ONE
	_screen_wash.modulate.a = 0.0
	_impact_flash.modulate.a = 0.0
	_top_bar.modulate.a = 0.0
	_bottom_bar.modulate.a = 0.0


func _smooth_progress(elapsed: float, duration: float) -> float:
	var progress := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	return smoothstep(0.0, 1.0, progress)


func _back_out(progress: float) -> float:
	var shifted := progress - 1.0
	return 1.0 + 2.70158 * pow(shifted, 3.0) + 1.70158 * pow(shifted, 2.0)


func _normalize_element(element: StringName) -> StringName:
	match String(element).strip_edges().to_lower():
		"fire":
			return &"fire"
		"ice":
			return &"ice"
		_:
			return &"neutral"


func _color_for_element(element: StringName) -> Color:
	match element:
		&"fire":
			return FIRE_COLOR
		&"ice":
			return ICE_COLOR
		_:
			return NEUTRAL_COLOR
