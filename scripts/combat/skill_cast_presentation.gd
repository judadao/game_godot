class_name SkillCastPresentation
extends CanvasLayer

signal cast_started(cast_name: String, element: StringName, importance: float)
signal cast_finished(cast_name: String, element: StringName)

const FIRE_COLOR := Color(1.0, 0.36, 0.12, 1.0)
const ICE_COLOR := Color(0.35, 0.82, 1.0, 1.0)
const NEUTRAL_COLOR := Color(1.0, 0.88, 0.48, 1.0)
const MIN_IMPORTANCE := 0.5
const MAX_IMPORTANCE := 2.0

@export_range(0.05, 1.0, 0.01) var slow_motion_scale := 0.28
@export_range(0.1, 1.5, 0.01) var visible_duration := 0.34

@onready var _skill_name: Label = $Overlay/SafeMargin/Center/SkillName

var _active := false
var _cast_name := ""
var _element := &"neutral"
var _importance := 1.0
var _generation := 0
var _restore_time_scale := 1.0
var _cast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_skill_name.visible = false
	_skill_name.resized.connect(_update_title_pivot)
	_update_title_pivot()


func _exit_tree() -> void:
	_cancel_tween()
	_restore_time()


func play_cast(
	cast_name: String,
	element: StringName = &"neutral",
	importance: float = 1.0
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

	_cancel_tween()
	_apply_slow_motion()
	_prepare_title()
	_play_title_tween(_generation)
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
	_skill_name.text = _cast_name
	_skill_name.modulate = _color_for_element(_element)
	_skill_name.scale = Vector2.ONE * lerpf(0.82, 0.66, inverse_lerp(
		MIN_IMPORTANCE,
		MAX_IMPORTANCE,
		_importance
	))
	_skill_name.visible = true
	_update_title_pivot()


func _play_title_tween(generation: int) -> void:
	var peak_scale := lerpf(1.08, 1.24, inverse_lerp(
		MIN_IMPORTANCE,
		MAX_IMPORTANCE,
		_importance
	))
	var hold_duration := visible_duration + ((_importance - 1.0) * 0.08)
	_cast_tween = create_tween()
	_cast_tween.set_ignore_time_scale(true)
	_cast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cast_tween.tween_property(
		_skill_name,
		"scale",
		Vector2.ONE * peak_scale,
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cast_tween.tween_property(
		_skill_name,
		"scale",
		Vector2.ONE,
		0.10
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cast_tween.tween_interval(maxf(0.1, hold_duration))
	_cast_tween.tween_property(
		_skill_name,
		"modulate:a",
		0.0,
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_cast_tween.finished.connect(_finish_cast.bind(generation), CONNECT_ONE_SHOT)


func _finish_cast(generation: int) -> void:
	if generation != _generation:
		return
	var finished_name := _cast_name
	var finished_element := _element
	_cast_tween = null
	_skill_name.visible = false
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
