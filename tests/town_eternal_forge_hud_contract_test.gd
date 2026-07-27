extends SceneTree

const HUD_PATH := "res://scenes/ui/town/TownEternalForgeHUD.tscn"
const HAND_PATH := "res://scenes/ui/town/TownCardHandUI.tscn"
const REFERENCE_PATH := "res://scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn"
const TOWN_MAP_PATH := "res://scenes/maps/town/TownMap.tscn"
const VIEWPORTS := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in [HUD_PATH, HAND_PATH, REFERENCE_PATH, TOWN_MAP_PATH]:
		_expect(ResourceLoader.exists(scene_path), "%s must exist." % scene_path)
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

	if _failures == 0:
		print("PASS: Town Eternal Forge HUD contract at all six required viewports")
	quit(1 if _failures > 0 else 0)


func _verify_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(hud)
	await process_frame
	await process_frame

	_expect(hud.name == "HUD", "Town HUD must retain the exact adoption name at %s." % viewport_size)
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
	_expect(not bottom_hud.visible, "Unused Town status/commission/ledger HUD must stay hidden at %s." % viewport_size)
	_expect(not (hud.get_node("LeftCrest") as Control).visible, "Unused Flame Keeper crest must stay hidden.")
	_expect(not (hud.get_node("RightCrest") as Control).visible, "Unused Soul Network crest must stay hidden.")
	_expect(prompt.visible, "Interaction prompt must become visible at %s." % viewport_size)
	_expect(prompt.size.x <= 420.0, "Interaction prompt must remain compact at %s." % viewport_size)
	_expect(prompt.get_global_rect().position.y >= float(viewport_size.y) - 72.0, "Prompt must use the compact bottom safe area at %s." % viewport_size)
	for node_path in ["AreaPanel", "InteractionPanel"]:
		var control := hud.get_node(node_path) as Control
		_expect(_inside_viewport(control, viewport_size), "%s must stay inside %s." % [node_path, viewport_size])

	hud.queue_free()
	viewport.queue_free()
	await process_frame


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
