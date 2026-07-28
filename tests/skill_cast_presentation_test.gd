extends SceneTree

const SCENE_PATH := "res://scenes/combat/vfx/SkillCastPresentation.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0
var _presentation: CanvasLayer


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(packed != null, "SkillCastPresentation scene must load.")
	if packed == null:
		quit(1)
		return

	_presentation = packed.instantiate() as CanvasLayer
	_expect(_presentation != null, "SkillCastPresentation root must be a CanvasLayer.")
	if _presentation == null:
		quit(1)
		return

	root.add_child(_presentation)
	await process_frame
	await _test_scene_contract()
	await _test_responsive_centering()
	await _test_combo_cast_keeps_normal_time()
	await _test_fire_cast_uses_real_time()
	await _test_repeated_ice_cast_restores_original_scale()
	await _test_tree_exit_restores_original_scale()
	_cleanup()
	quit(0 if _failures == 0 else 1)


func _test_scene_contract() -> void:
	_expect(_presentation.process_mode == Node.PROCESS_MODE_ALWAYS, "Root must always process.")
	_expect(_presentation.has_method("play_cast"), "Component must expose play_cast().")
	_expect(_presentation.has_method("get_cast_state"), "Component must expose testable state.")
	var overlay := _presentation.get_node_or_null("Overlay") as Control
	var title := _presentation.get_node_or_null("Overlay/SafeMargin/Center/SkillName") as Label
	_expect(overlay != null, "Scene must author a full-screen Overlay Control.")
	_expect(title != null, "Scene must author the centered SkillName Label.")
	if overlay != null:
		_expect(
			overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Presentation overlay must not block gameplay input."
		)


func _test_responsive_centering() -> void:
	for viewport_size in VIEWPORT_SIZES:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var packed := load(SCENE_PATH) as PackedScene
		var presentation := packed.instantiate() as CanvasLayer
		viewport.add_child(presentation)
		presentation.call("play_cast", "RESPONSIVE CAST TITLE", &"neutral", 1.0)
		await process_frame
		await process_frame
		var overlay := presentation.get_node("Overlay") as Control
		var safe_margin := presentation.get_node("Overlay/SafeMargin") as Control
		var center := presentation.get_node("Overlay/SafeMargin/Center") as Control
		var title := presentation.get_node("Overlay/SafeMargin/Center/SkillName") as Label
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_expect(
			viewport_rect.is_equal_approx(overlay.get_global_rect()),
			"Overlay must remain inside viewport at %s." % viewport_size
		)
		var title_center := title.get_global_rect().get_center()
		var expected_center := Vector2(viewport_size) * 0.5
		_expect(
			title_center.distance_to(expected_center) <= 2.0,
			"Skill title must stay centered at %s; got %s (safe=%s center=%s)."
			% [viewport_size, title_center, safe_margin.get_global_rect(), center.get_global_rect()]
		)
		viewport.queue_free()
		await process_frame


func _test_fire_cast_uses_real_time() -> void:
	Engine.time_scale = 1.0
	_presentation.call("play_cast", "EMBER CROWN", &"fire", 1.0)
	await process_frame
	var state := _presentation.call("get_cast_state") as Dictionary
	var title := _presentation.get_node("Overlay/SafeMargin/Center/SkillName") as Label
	_expect(bool(state.get("active", false)), "Fire cast must become active.")
	_expect(String(state.get("cast_name", "")) == "EMBER CROWN", "Cast state must expose its name.")
	_expect(String(state.get("element", "")) == "fire", "Cast state must expose fire element.")
	_expect(Engine.time_scale < 1.0, "Fire cast must temporarily slow Engine.time_scale.")
	_expect(title.visible, "Skill title must be visible while casting.")
	_expect(title.modulate.is_equal_approx(Color(1.0, 0.36, 0.12, 1.0)), "Fire title must use fire color.")
	await create_timer(0.8, true, false, true).timeout
	state = _presentation.call("get_cast_state") as Dictionary
	_expect(not bool(state.get("active", true)), "Cast must finish using unscaled real time.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Finished cast must restore normal time.")


func _test_combo_cast_keeps_normal_time() -> void:
	Engine.time_scale = 1.0
	_presentation.call("play_cast", "FLAME IMBUE", &"fire", 0.85, false)
	await process_frame
	var state := _presentation.call("get_cast_state") as Dictionary
	var title := _presentation.get_node("Overlay/SafeMargin/Center/SkillName") as Label
	_expect(bool(state.get("active", false)), "Combo cast presentation must still become active.")
	_expect(title.visible, "Combo cast must retain its visual title.")
	_expect(
		is_equal_approx(Engine.time_scale, 1.0),
		"Combo cast presentation must not slow Engine.time_scale."
	)
	await create_timer(0.8, true, false, true).timeout
	_expect(
		is_equal_approx(Engine.time_scale, 1.0),
		"Finished Combo presentation must preserve normal time."
	)


func _test_repeated_ice_cast_restores_original_scale() -> void:
	Engine.time_scale = 0.72
	_presentation.call("play_cast", "FROST RING", &"ice", 0.8)
	await create_timer(0.08, true, false, true).timeout
	_presentation.call("play_cast", "ABSOLUTE ZERO", &"ice", 1.4)
	await process_frame
	var state := _presentation.call("get_cast_state") as Dictionary
	var title := _presentation.get_node("Overlay/SafeMargin/Center/SkillName") as Label
	_expect(String(state.get("cast_name", "")) == "ABSOLUTE ZERO", "Repeated cast must replace stale title.")
	_expect(int(state.get("generation", 0)) >= 2, "Repeated cast must advance its generation.")
	_expect(title.modulate.is_equal_approx(Color(0.35, 0.82, 1.0, 1.0)), "Ice title must use ice color.")
	await create_timer(0.9, true, false, true).timeout
	_expect(
		is_equal_approx(Engine.time_scale, 0.72),
		"Repeated casts must restore the scale captured before the first cast."
	)


func _test_tree_exit_restores_original_scale() -> void:
	Engine.time_scale = 0.84
	_presentation.call("play_cast", "GLACIAL WAKE", &"ice", 1.0)
	await process_frame
	_presentation.get_parent().remove_child(_presentation)
	_expect(
		is_equal_approx(Engine.time_scale, 0.84),
		"Leaving the tree during a cast must restore the captured scale."
	)
	root.add_child(_presentation)
	await process_frame


func _cleanup() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_presentation):
		_presentation.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
