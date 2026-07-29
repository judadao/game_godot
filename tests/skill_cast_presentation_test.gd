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
const CAPTURE_DIRECTORY_ENV := "SKILL_CAST_PRESENTATION_CAPTURE_DIR"

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
	await _test_standard_cast_stays_readable()
	await _test_major_cast_uses_brief_screen_layers()
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
	var screen_wash := _presentation.get_node_or_null("Overlay/ScreenWash") as ColorRect
	var impact_flash := _presentation.get_node_or_null("Overlay/ImpactFlash") as ColorRect
	var top_bar := _presentation.get_node_or_null("Overlay/TopBar") as ColorRect
	var bottom_bar := _presentation.get_node_or_null("Overlay/BottomBar") as ColorRect
	var cast_band := _presentation.get_node_or_null(
		"Overlay/SafeMargin/Center/CastBand"
	) as Panel
	var major_frame := _presentation.get_node_or_null(
		"Overlay/SafeMargin/Center/MajorFrame"
	) as Panel
	var title := _presentation.get_node_or_null("Overlay/SafeMargin/Center/SkillName") as Label
	_expect(overlay != null, "Scene must author a full-screen Overlay Control.")
	_expect(screen_wash != null, "Scene must author a full-screen elemental wash.")
	_expect(impact_flash != null, "Scene must author a short impact flash.")
	_expect(top_bar != null and bottom_bar != null, "Scene must author major-cast edge bars.")
	_expect(cast_band != null, "Scene must author the focused cast band.")
	_expect(major_frame != null, "Scene must author a distinct major-cast frame.")
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
		presentation.call(
			"play_cast",
			"ABSOLUTE ZERO OF THE TEN THOUSAND AUTUMN BLADES",
			&"ice",
			1.8
		)
		await create_timer(0.145, true, false, true).timeout
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
		_expect(
			viewport_rect.encloses(title.get_global_rect()),
			"Long skill title must remain inside viewport at %s; got %s."
			% [viewport_size, title.get_global_rect()]
		)
		_expect(
			title.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
			"Long skill titles must wrap instead of using ellipsis at %s." % viewport_size
		)
		_expect(
			title.get_line_count() >= 2,
			"Long skill title must use readable multiline layout at %s." % viewport_size
		)
		var major_frame := presentation.get_node(
			"Overlay/SafeMargin/Center/MajorFrame"
		) as Control
		_expect(
			major_frame.get_global_rect().encloses(title.get_global_rect()),
			"Major frame must contain the scaled title at %s; title=%s frame=%s."
			% [viewport_size, title.get_global_rect(), major_frame.get_global_rect()]
		)
		for node_path in [
			"Overlay/SafeMargin/Center/CastBand",
			"Overlay/SafeMargin/Center/MajorFrame",
		]:
			var layer := presentation.get_node(node_path) as Control
			_expect(
				viewport_rect.encloses(layer.get_global_rect()),
				"%s must remain inside viewport at %s; got %s."
				% [node_path, viewport_size, layer.get_global_rect()]
			)
		await _capture_viewport_if_requested(viewport, viewport_size)
		viewport.queue_free()
		await process_frame


func _test_standard_cast_stays_readable() -> void:
	Engine.time_scale = 1.0
	_presentation.call("play_cast", "EMBER STEP", &"fire", 0.9, false)
	await create_timer(0.14, true, false, true).timeout
	var state := _presentation.call("get_cast_state") as Dictionary
	var screen_wash := _presentation.get_node("Overlay/ScreenWash") as ColorRect
	var impact_flash := _presentation.get_node("Overlay/ImpactFlash") as ColorRect
	var top_bar := _presentation.get_node("Overlay/TopBar") as ColorRect
	var bottom_bar := _presentation.get_node("Overlay/BottomBar") as ColorRect
	_expect(String(state.get("presentation_tier", "")) == "standard", "Importance 0.9 must use standard tier.")
	_expect(float(state.get("flash_peak_alpha", 1.0)) <= 0.18, "Standard casts must cap flash opacity.")
	_expect(float(state.get("wash_peak_alpha", 1.0)) <= 0.10, "Standard casts must cap screen wash opacity.")
	_expect(screen_wash.modulate.a <= 0.10, "Standard screen wash must stay transparent.")
	_expect(impact_flash.modulate.a <= 0.18, "Standard impact flash must stay transparent.")
	_expect(top_bar.modulate.a <= 0.01, "Standard casts must not show the top cinematic bar.")
	_expect(bottom_bar.modulate.a <= 0.01, "Standard casts must not show the bottom cinematic bar.")
	await create_timer(0.75, true, false, true).timeout


func _test_major_cast_uses_brief_screen_layers() -> void:
	Engine.time_scale = 1.0
	_presentation.call("play_cast", "GLACIAL CATASTROPHE", &"ice", 1.8)
	await create_timer(0.15, true, false, true).timeout
	var state := _presentation.call("get_cast_state") as Dictionary
	var title := _presentation.get_node("Overlay/SafeMargin/Center/SkillName") as Label
	var major_frame := _presentation.get_node("Overlay/SafeMargin/Center/MajorFrame") as Panel
	_expect(String(state.get("presentation_tier", "")) == "major", "Importance 1.8 must use major tier.")
	_expect(float(state.get("flash_peak_alpha", 0.0)) >= 0.26, "Major casts need a stronger impact flash.")
	_expect(float(state.get("wash_peak_alpha", 0.0)) >= 0.12, "Major casts need a readable elemental wash.")
	_expect(float(state.get("timeline_duration", 2.0)) <= 0.95, "Major screen presentation must remain brief.")
	_expect(title.visible and title.modulate.a > 0.6, "Major title must be readable at impact.")
	_expect(major_frame.visible and major_frame.modulate.a > 0.1, "Major casts must reveal their frame.")
	await create_timer(0.9, true, false, true).timeout
	state = _presentation.call("get_cast_state") as Dictionary
	_expect(not bool(state.get("active", true)), "Major presentation must clean itself up.")
	for node_path in [
		"Overlay/ScreenWash",
		"Overlay/ImpactFlash",
		"Overlay/TopBar",
		"Overlay/BottomBar",
		"Overlay/SafeMargin/Center/CastBand",
		"Overlay/SafeMargin/Center/MajorFrame",
	]:
		var layer := _presentation.get_node(node_path) as CanvasItem
		_expect(layer.modulate.a <= 0.001, "%s must be transparent after cleanup." % node_path)
	_expect(not title.visible, "Skill title must hide after cleanup.")


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
	_expect(
		Vector3(title.modulate.r, title.modulate.g, title.modulate.b).is_equal_approx(
			Vector3(1.0, 0.36, 0.12)
		),
		"Fire title must use fire color."
	)
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
	_expect(
		Vector3(title.modulate.r, title.modulate.g, title.modulate.b).is_equal_approx(
			Vector3(0.35, 0.82, 1.0)
		),
		"Ice title must use ice color."
	)
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


func _capture_viewport_if_requested(viewport: SubViewport, viewport_size: Vector2i) -> void:
	var capture_directory := OS.get_environment(CAPTURE_DIRECTORY_ENV).strip_edges()
	if capture_directory.is_empty():
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(capture_directory)
	_expect(
		directory_error == OK,
		"Could not create SkillCastPresentation capture directory: %s." % capture_directory
	)
	if directory_error != OK:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_expect(not image.is_empty(), "Presentation capture must contain rendered pixels.")
	if image.is_empty():
		return
	var output_path := capture_directory.path_join(
		"skill_cast_%dx%d.png" % [viewport_size.x, viewport_size.y]
	)
	_expect(
		image.save_png(output_path) == OK,
		"Could not save SkillCastPresentation capture: %s." % output_path
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
