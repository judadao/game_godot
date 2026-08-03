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
	_capture_path = OS.get_environment("DECK_BUILDER_CAPTURE_PATH")
	_capture_size = _parse_capture_size(
		OS.get_environment("DECK_BUILDER_CAPTURE_SIZE")
	)
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	for viewport_size in VIEWPORT_SIZES:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = (
			SubViewport.UPDATE_ONCE
			if viewport_size == _capture_size and not _capture_path.is_empty()
			else SubViewport.UPDATE_DISABLED
		)
		root.add_child(viewport)
		var builder := (
			load("res://scenes/ui/cards/DeckBuilderUI.tscn") as PackedScene
		).instantiate()
		viewport.add_child(builder)
		await process_frame
		builder.call("configure", database.get_all_cards(), [
			"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		])
		builder.call("select_slot", 1)
		await process_frame
		var panel := builder.get_node("Shade/LoadoutPanel") as Control
		var panel_rect := _canvas_rect(panel)
		var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_expect(
			screen.encloses(panel_rect),
			"Four-slot loadout panel must remain on-screen at %s." % viewport_size
		)
		var slots := builder.get_node(
			"Shade/LoadoutPanel/Margin/Column/LoadoutSlots"
		) as HBoxContainer
		_expect(
			slots.get_child_count() == 4,
			"Exactly four loadout slots must render at %s." % viewport_size
		)
		for slot in slots.get_children():
			_expect(
				panel_rect.encloses(_canvas_rect(slot as Control)),
				"Every skill slot must remain inside the panel at %s." % viewport_size
			)
			var slot_control := slot as Control
			var icon := slot_control.get_node("Visual/Icon") as TextureRect
			_expect(
				_canvas_rect(slot_control).encloses(_canvas_rect(icon)),
				"Every iconified slot image must stay inside its card at %s." % viewport_size
			)
		var scroll := builder.get_node(
			"Shade/LoadoutPanel/Margin/Column/SkillChoiceScroll"
		) as ScrollContainer
		_expect(
			panel_rect.encloses(_canvas_rect(scroll)),
			"Filtered skill choices must remain inside the panel at %s." % viewport_size
		)
		if viewport_size == _capture_size and not _capture_path.is_empty():
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(
				viewport.get_texture().get_image().save_png(_capture_path) == OK,
				"Deck Builder visual capture must save."
			)
		viewport.queue_free()
		await process_frame
	if _failures == 0:
		print("PASS: four-slot portal loadout at six viewport sizes")
	quit(1 if _failures > 0 else 0)


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
