extends SceneTree

const HUD_PATH := "res://scenes/ui/town/TownEternalForgeHUD.tscn"
const HAND_PATH := "res://scenes/ui/town/TownCardHandUI.tscn"
const REFERENCE_PATH := "res://scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn"
const TOWN_MAP_PATH := "res://scenes/maps/town/TownMap.tscn"
const GAME_PATH := "res://scenes/game/game.tscn"
const AREA_FRAME_PATH := "res://assets/town/modular_v2/ui/town_area_frame_v3.png"
const INTERACTION_FRAME_PATH := "res://assets/town/modular_v2/ui/town_interaction_frame_v2.png"
const VIEWPORTS := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0
var _capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("TOWN_HUD_CAPTURE_DIR").strip_edges()
	if not _capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_directory)
	for scene_path in [HUD_PATH, HAND_PATH, REFERENCE_PATH, TOWN_MAP_PATH, GAME_PATH]:
		_expect(ResourceLoader.exists(scene_path), "%s must exist." % scene_path)
	for texture_path in [AREA_FRAME_PATH, INTERACTION_FRAME_PATH]:
		_expect(ResourceLoader.exists(texture_path), "%s must exist." % texture_path)
	if _failures > 0:
		quit(1)
		return

	var town := (load(TOWN_MAP_PATH) as PackedScene).instantiate()
	root.add_child(town)
	await process_frame
	var reference := town.get_node_or_null("EditorHUDReference") as CanvasLayer
	var map_hud := town.get_node_or_null("EditorHUDReference/HUD") as Control
	var map_hand := town.get_node_or_null("EditorHUDReference/CardHandUI") as Control
	_expect(reference != null and reference.scene_file_path == REFERENCE_PATH, "Town must use its dedicated editor HUD reference.")
	_expect(map_hud != null and map_hud.scene_file_path == HUD_PATH, "Town must author the Eternal Forge HUD.")
	_expect(map_hand != null and map_hand.scene_file_path == HAND_PATH, "Town must author one sibling Eternal Forge hand.")
	_expect(map_hand is CardHandUI, "Town hand must retain the CardHandUI runtime contract.")
	town.queue_free()
	await process_frame

	for viewport_size in VIEWPORTS:
		await _verify_viewport(viewport_size)
	if not _capture_directory.is_empty():
		await _capture_runtime_town()

	if _failures == 0:
		print("PASS: Town Eternal Forge HUD contract at all six required viewports")
	quit(1 if _failures > 0 else 0)


func _verify_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	if not _capture_directory.is_empty():
		var capture_backdrop := ColorRect.new()
		capture_backdrop.color = Color(0.28, 0.59, 0.75, 1.0)
		capture_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport.add_child(capture_backdrop)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(hud)
	await process_frame
	await process_frame

	_expect(hud.name == "HUD", "Town HUD must retain the exact adoption name at %s." % viewport_size)
	_expect(
		bool(hud.get_meta("interaction_prompt_action_only", false)),
		"Town HUD must request action-only interaction copy at %s." % viewport_size
	)
	_expect(hud.position.is_equal_approx(Vector2.ZERO), "Town HUD must begin at viewport origin at %s." % viewport_size)
	_expect(hud.size.is_equal_approx(Vector2(viewport_size)), "Town HUD must fill %s; got %s." % [viewport_size, hud.size])
	for method_name in [
		"set_health", "set_mana", "set_stamina", "set_player_level", "set_player_class",
		"set_currency", "set_experience", "set_potion_counts", "show_potion_feedback",
		"set_area_name", "set_objective", "set_interaction_prompt", "clear_interaction_prompt",
		"set_interaction_visible", "open", "close", "toggle",
	]:
		_expect(hud.has_method(method_name), "Town HUD must expose %s at %s." % [method_name, viewport_size])
	_expect(hud.has_signal("interaction_prompt_accepted"), "Town HUD must preserve the interaction signal.")

	hud.call("set_health", 987654, 999999)
	hud.call("set_mana", 456789, 999999)
	hud.call("set_stamina", 123456, 999999)
	hud.call("set_player_level", 999)
	hud.call("set_player_class", "永恆熔爐首席鍛造師 Eternal Forge Grandmaster")
	hud.call("set_currency", 2147483647)
	hud.call("set_experience", 2147483000, 2147483647)
	hud.call("set_area_name", "永恆熔爐 · ETERNAL FORGE")
	hud.call("set_objective", "完成八個城鎮區域的重鑄工程 Complete all eight district reforging commissions", "7 / 8")
	hud.call("set_interaction_prompt", "按下以啟動永恆之火並開啟跨區傳送門", "F")
	await process_frame

	_expect(
		(hud.get_node("BottomHUD/HUDGrid/ProgressColumn/ProgressCenter/ProgressProxy/HUDProgressPanel/Rows/GoldRow/CurrencyValue") as Label).text
			== "2,147,483,647",
		"Town HUD must project large currency values."
	)
	var bottom_hud := hud.get_node("BottomHUD") as Control
	var prompt := hud.get_node("InteractionPanel") as Control
	var area_panel := hud.get_node("AreaPanel") as PanelContainer
	var interaction_panel := hud.get_node("InteractionPanel") as PanelContainer
	var keycap := hud.get_node("InteractionPanel/PromptRow/Keycap") as PanelContainer
	var prompt_text := hud.get_node("InteractionPanel/PromptRow/PromptText") as Label
	_expect(not bottom_hud.visible, "Unused Town status/commission/ledger HUD must stay hidden at %s." % viewport_size)
	_expect(not (hud.get_node("LeftCrest") as Control).visible, "Unused Flame Keeper crest must stay hidden.")
	_expect(not (hud.get_node("RightCrest") as Control).visible, "Unused Soul Network crest must stay hidden.")
	_expect(prompt.visible, "Interaction prompt must become visible at %s." % viewport_size)
	_expect(prompt.size.x <= 420.0, "Interaction prompt must remain compact at %s." % viewport_size)
	_expect(prompt.get_global_rect().position.y >= float(viewport_size.y) - 72.0, "Prompt must use the compact bottom safe area at %s." % viewport_size)
	_expect_texture_style(area_panel, AREA_FRAME_PATH, "Town area label")
	_expect_texture_style(interaction_panel, INTERACTION_FRAME_PATH, "Town interaction prompt")
	var area_style := area_panel.get_theme_stylebox("panel") as StyleBoxTexture
	_expect(
		area_style.texture_margin_left >= 32.0
			and area_style.texture_margin_right >= 32.0,
		"Town area label must preserve generated end caps while stretching only its center."
	)
	var long_area_width := area_panel.size.x
	if not _capture_directory.is_empty() and viewport_size == Vector2i(1280, 720):
		hud.call("set_interaction_prompt", "Open", "F")
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await create_timer(0.05).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(
			viewport.get_texture().get_image().save_png(
				_capture_directory.path_join("town_hud_long_1280x720.png")
			) == OK,
			"Town HUD long-location visual capture must save."
		)
	hud.call("set_area_name", "Town")
	await process_frame
	var short_area_width := area_panel.size.x
	_expect(
		long_area_width >= short_area_width + 48.0,
		"Town area label must expand for longer location names at %s." % viewport_size
	)
	_expect(
		short_area_width >= 220.0 and long_area_width <= 520.0,
		"Town area label adaptive width must stay readable at %s." % viewport_size
	)
	_expect(
		absf(area_panel.get_global_rect().get_center().x - float(viewport_size.x) * 0.5) <= 1.0,
		"Town area label must remain centered after text-driven resizing at %s." % viewport_size
	)
	_expect(
		keycap.get_theme_stylebox("panel") is StyleBoxEmpty,
		"Generated interaction frame must own the key socket without a second keycap border."
	)
	var prompt_rect := prompt.get_global_rect()
	var keycap_rect := keycap.get_global_rect()
	var prompt_text_rect := prompt_text.get_global_rect()
	_expect(
		absf(keycap_rect.get_center().x - (prompt_rect.position.x + 56.0)) <= 1.0,
		"Interaction key must remain centered in the generated left socket at %s." % viewport_size
	)
	_expect(
		absf(keycap_rect.get_center().y - prompt_rect.get_center().y) <= 1.0,
		"Interaction key must remain vertically centered at %s." % viewport_size
	)
	_expect(
		prompt_text_rect.position.x >= prompt_rect.position.x + 104.0,
		"Interaction text must begin after the generated key socket at %s." % viewport_size
	)
	for node_path in ["AreaPanel", "InteractionPanel"]:
		var control := hud.get_node(node_path) as Control
		_expect(_inside_viewport(control, viewport_size), "%s must stay inside %s." % [node_path, viewport_size])

	if not _capture_directory.is_empty():
		hud.call("set_area_name", "Town")
		hud.call("set_interaction_prompt", "Open", "F")
		await process_frame
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await create_timer(0.05).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		var capture_path := _capture_directory.path_join(
			"town_hud_%dx%d.png" % [viewport_size.x, viewport_size.y]
		)
		_expect(
			viewport.get_texture().get_image().save_png(capture_path) == OK,
			"Town HUD visual capture must save at %s." % viewport_size
		)

	hud.queue_free()
	viewport.queue_free()
	await process_frame


func _capture_runtime_town() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var game := (load(GAME_PATH) as PackedScene).instantiate()
	viewport.add_child(game)
	for _frame in 4:
		await process_frame

	var current_map: Node = game.call("get_current_map")
	var player: Node2D = game.call("get_player")
	var town_hall := (
		current_map.get_node_or_null("BuildingEntrances/TownHall")
		if current_map != null
		else null
	)
	_expect(current_map != null and player != null and town_hall != null, "Town runtime capture fixture must resolve.")
	if current_map != null and player != null and town_hall != null:
		player.global_position = Vector2(1120.0, 672.0)
		game.call("_on_interaction_available", town_hall, player)
		for _frame in 4:
			await process_frame

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await create_timer(0.05).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var capture_path := _capture_directory.path_join("town_hud_runtime_1280x720.png")
	_expect(
		viewport.get_texture().get_image().save_png(capture_path) == OK,
		"Town runtime HUD visual capture must save."
	)
	viewport.queue_free()
	await process_frame


func _expect_texture_style(panel: PanelContainer, expected_path: String, context: String) -> void:
	var style := panel.get_theme_stylebox("panel")
	_expect(style is StyleBoxTexture, "%s must use generated pixel-art framing." % context)
	if style is not StyleBoxTexture:
		return
	var texture := (style as StyleBoxTexture).texture
	_expect(texture != null, "%s generated frame must resolve." % context)
	if texture != null:
		_expect(texture.resource_path == expected_path, "%s must use %s." % [context, expected_path])


func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	var rect := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	return (
		rect.position.x >= -0.5
		and rect.position.y >= -0.5
		and rect.end.x <= float(viewport_size.x) + 0.5
		and rect.end.y <= float(viewport_size.y) + 0.5
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
