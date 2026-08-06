extends SceneTree

const BASE_COUNT := 8
const EVOLVED_COUNT := 10
const VIEWPORT_SIZES := [
	Vector2i(1152, 720), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(2560, 1440),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var compendium := game.call("_inventory_compendium_projection") as Array
	var blessings: Array[Dictionary] = []
	for entry_variant in compendium:
		var entry := entry_variant as Dictionary
		if String(entry.get("section", "")) == "blessings":
			blessings.append(entry)
	var base_entries := blessings.filter(
		func(entry: Dictionary) -> bool: return String(entry.get("catalog_kind", "")) == "blessing_base"
	)
	var evolved_entries := blessings.filter(
		func(entry: Dictionary) -> bool: return String(entry.get("catalog_kind", "")) == "blessing_evolved"
	)
	_expect(
		blessings.size() == BASE_COUNT + EVOLVED_COUNT
			and base_entries.size() == BASE_COUNT
			and evolved_entries.size() == EVOLVED_COUNT,
		"The Codex must project all 8 base and 10 evolved Blessings."
	)
	var ids: Dictionary = {}
	for entry in blessings:
		var entry_id := String(entry.get("id", ""))
		var icon_path := String(entry.get("icon_path", ""))
		_expect(not entry_id.is_empty() and not ids.has(entry_id), "Blessing Codex IDs must be stable and unique: %s." % entry_id)
		ids[entry_id] = true
		_expect(
			not String(entry.get("name", "")).is_empty()
				and not String(entry.get("description", "")).is_empty()
				and not String(entry.get("effect_summary", "")).is_empty()
				and not String(entry.get("trigger_summary", "")).is_empty()
				and not String(entry.get("meta_summary", "")).is_empty()
				and not String(entry.get("growth_summary", "")).is_empty(),
			"Every Blessing Codex entry needs complete Chinese detail copy: %s." % entry_id
		)
		_expect(ResourceLoader.exists(icon_path), "Blessing Codex art must load: %s." % icon_path)
	_expect(ids.has("blessing:resonant_grace"), "Base Blessings must use namespaced stable IDs.")
	_expect(ids.has("blessing_evolved:thunderflame_wheel"), "Evolved Blessings must use recipe IDs instead of runtime evolution IDs.")
	var thunderflame := evolved_entries.filter(
		func(entry: Dictionary) -> bool: return String(entry.get("id", "")) == "blessing_evolved:thunderflame_wheel"
	)
	_expect(
		thunderflame.size() == 1
			and String(thunderflame[0].get("trigger_summary", "")).contains("共鳴恩典")
			and String(thunderflame[0].get("trigger_summary", "")).contains("稜光誓約")
			and String(thunderflame[0].get("effect_summary", "")).contains("天輪脈衝"),
		"Evolved entries must explain their component Blessings and unique background attack."
	)

	var capture_dir := OS.get_environment("INVENTORY_BLESSING_CODEX_CAPTURE_DIR").strip_edges()
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	for viewport_size in VIEWPORT_SIZES:
		await _check_ui_size(blessings, viewport_size, capture_dir)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: base and evolved Blessings appear in the Inventory Codex at six sizes")
	quit(_failures)


func _check_ui_size(blessings: Array[Dictionary], viewport_size: Vector2i, capture_dir: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui := (load("res://scenes/ui/inventory/InventoryUI.tscn") as PackedScene).instantiate()
	viewport.add_child(ui)
	await process_frame
	ui.call("set_codex_entries", blessings)
	ui.call("set_mode", &"codex")
	ui.call("set_codex_section", "blessings")
	ui.call("open")
	await process_frame
	await process_frame
	var blessings_button := ui.find_child("Blessings", true, false) as Button
	_expect(
		blessings_button != null
			and blessings_button.button_pressed
			and ui.call("get_codex_section") == "blessings"
			and int(ui.call("get_visible_codex_count")) == BASE_COUNT + EVOLVED_COUNT,
		"The Codex needs a directly selectable Blessings category with all 18 entries at %s." % viewport_size
	)
	ui.call("select_codex_entry", "blessing_evolved:thunderflame_wheel")
	await process_frame
	var static_icon := ui.find_child("StaticIcon", true, false) as TextureRect
	var effect_label := ui.get_node(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Effect"
	) as Label
	var panel := ui.get_node("Center/MainPanel") as Control
	var browser := panel.get_node("Margin/Layout/Pages/CodexPage/Browser") as Control
	var details := panel.get_node("Margin/Layout/Pages/CodexPage/Details") as Control
	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	_expect(
		ui.call("get_selected_codex_id") == "blessing_evolved:thunderflame_wheel"
			and static_icon != null
			and static_icon.visible
			and static_icon.texture != null
			and effect_label != null
			and effect_label.text.contains("天輪脈衝"),
		"Selecting an evolved Blessing must show its concrete subject and dedicated attack details at %s." % viewport_size
	)
	_expect(
		screen.encloses(_canvas_rect(panel))
			and not _canvas_rect(browser).intersects(_canvas_rect(static_icon))
			and _canvas_rect(static_icon).end.y <= _canvas_rect(details).end.y
			and blessings_button.size.y >= 30.0,
		"Blessing list, filter, art, and details must remain non-overlapping and on-screen at %s." % viewport_size
	)
	if not capture_dir.is_empty():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		_expect(
			image != null
				and not image.is_empty()
				and image.save_png(capture_dir.path_join(
					"blessing_codex_evolved_%dx%d.png" % [viewport_size.x, viewport_size.y]
				)) == OK,
			"Evolved Blessing Codex visual capture must save at %s." % viewport_size
		)
		ui.call("select_codex_entry", "blessing:resonant_grace")
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var base_image := viewport.get_texture().get_image()
		_expect(
			base_image != null
				and not base_image.is_empty()
				and base_image.save_png(capture_dir.path_join(
					"blessing_codex_base_%dx%d.png" % [viewport_size.x, viewport_size.y]
				)) == OK,
			"Base Blessing Codex visual capture must save at %s." % viewport_size
		)

	ui.queue_free()
	viewport.queue_free()
	await process_frame


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
