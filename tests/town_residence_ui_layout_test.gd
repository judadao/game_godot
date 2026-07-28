extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0
var _capture_path := ""
var _capture_size := Vector2i.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_path = OS.get_environment("TOWN_RESIDENCE_CAPTURE_PATH")
	_capture_size = _parse_capture_size(
		OS.get_environment("TOWN_RESIDENCE_CAPTURE_SIZE")
	)
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	if _failures == 0:
		print("PASS: Town residence UI at six viewport sizes")
	quit(1 if _failures > 0 else 0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ONCE
		if viewport_size == _capture_size and not _capture_path.is_empty()
		else SubViewport.UPDATE_DISABLED
	)
	root.add_child(viewport)
	var ui := (
		load("res://scenes/ui/town/TownResidenceUI.tscn") as PackedScene
	).instantiate()
	viewport.add_child(ui)
	ui.call("set_context", &"east_residence")
	await process_frame

	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var panel := ui.get_node("Shade/Center/ResidencePanel") as Control
	var title := panel.get_node("PanelMargin/Content/ResidenceName") as Control
	var message := panel.get_node("PanelMargin/Content/Message") as Control
	var close_button := panel.get_node("PanelMargin/Content/CloseButton") as Control
	var panel_rect := _canvas_rect(panel)
	_expect(
		screen.encloses(panel_rect),
		"Residence panel must remain on-screen at %s." % viewport_size
	)
	for control in [title, message, close_button]:
		_expect(
			panel_rect.encloses(_canvas_rect(control)),
			"%s must remain inside the residence panel at %s."
			% [control.name, viewport_size]
		)

	if viewport_size == _capture_size and not _capture_path.is_empty():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(
			viewport.get_texture().get_image().save_png(_capture_path) == OK,
			"Town residence visual capture must save."
		)
	viewport.queue_free()
	await process_frame


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _parse_capture_size(raw_size: String) -> Vector2i:
	var parts := raw_size.to_lower().split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
