extends SceneTree

const INVENTORY_SCRIPT := preload("res://scripts/systems/inventory_manager.gd")
const TOWN_SCRIPT := preload("res://scripts/systems/town_manager.gd")
const FRAME_THEME_PATH := "res://scenes/ui/town/TownServiceFrameTheme.tres"
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]
const UI_LAYOUTS := [
	{
		"name": "MaterialYardUI",
		"path": "res://scenes/ui/town/MaterialYardUI.tscn",
		"window": "Window",
		"header": "Header",
		"content": "Content",
		"identity": "ShopkeeperPanel",
		"title": "Title",
		"close": "CloseButton",
		"terms": ["MATERIAL", "FORGE TOOLS", "BUY"],
		"minimum_icons": 3,
	},
	{
		"name": "PlayerBlacksmithUI",
		"path": "res://scenes/ui/town/PlayerBlacksmithUI.tscn",
		"window": "PlayerBlacksmithWindow",
		"header": "Header",
		"content": "MainContent",
		"identity": "ServiceRail",
		"title": "TitleLabel",
		"close": "CloseButton",
		"terms": ["FORGE", "WORKBENCH", "MARKET DOOR"],
		"minimum_icons": 1,
		"minimum_icon_paths": 1,
	},
	{
		"name": "TownHallUI",
		"path": "res://scenes/ui/town/TownHallUI.tscn",
		"window": "TownHallWindow",
		"header": "Header",
		"content": "Content",
		"identity": "MayorPanel",
		"title": "TitleText",
		"close": "CloseButton",
		"terms": ["TOWN HALL", "VILLAGE"],
		"minimum_icons": 3,
	},
	{
		"name": "ShopUI",
		"path": "res://scenes/ui/shop/ShopUI.tscn",
		"window": "ShopWindow",
		"header": "Title",
		"content": "Content",
		"identity": "MerchantPanel",
		"title": "TitleText",
		"close": "CancelButton",
		"terms": ["BLUEPRINT", "GOLD"],
		"minimum_icons": 4,
	},
]

var _failures := 0
var _capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("TOWN_BUILDING_UI_CAPTURE_DIR")
	var available_layouts: Array[Dictionary] = []
	for descriptor in UI_LAYOUTS:
		var path := String(descriptor["path"])
		_expect(
			ResourceLoader.exists(path, "PackedScene"),
			"%s must exist before six-viewport layout checks can run."
			% descriptor["name"]
		)
		if ResourceLoader.exists(path, "PackedScene"):
			available_layouts.append(descriptor)

	for viewport_size in VIEWPORT_SIZES:
		for descriptor in available_layouts:
			await _check_layout(descriptor, viewport_size)
	quit(1 if _failures > 0 else 0)


func _check_layout(descriptor: Dictionary, viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	var should_capture := not _capture_directory.is_empty()
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if should_capture else SubViewport.UPDATE_DISABLED
	)
	root.add_child(viewport)
	var ui := (
		load(String(descriptor["path"])) as PackedScene
	).instantiate() as Control
	viewport.add_child(ui)
	await process_frame
	_expect(
		ui.has_method("open"),
		"%s must expose open() before geometry checks." % descriptor["name"]
	)
	if not ui.has_method("open") or not _configure_ui(ui, String(descriptor["name"])):
		viewport.queue_free()
		await process_frame
		return
	ui.call("open")
	await process_frame
	await process_frame

	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var root_rect := _canvas_rect(ui)
	_expect(
		_rect_approximately_equal(root_rect, screen),
		"%s root must fill %s." % [descriptor["name"], viewport_size]
	)
	var window := ui.find_child(String(descriptor["window"]), true, false) as Control
	_expect(
		window != null,
		"%s must expose %s at %s."
		% [descriptor["name"], descriptor["window"], viewport_size]
	)
	if window == null:
		viewport.queue_free()
		await process_frame
		return
	var window_rect := _canvas_rect(window)
	_expect(
		screen.encloses(window_rect),
		"%s window must remain fully on-screen at %s."
		% [descriptor["name"], viewport_size]
	)
	_expect(
		window_rect.position.x >= 8.0
			and window_rect.position.y >= 8.0
			and window_rect.end.x <= float(viewport_size.x) - 8.0
			and window_rect.end.y <= float(viewport_size.y) - 8.0,
		"%s window must preserve an 8px viewport margin at %s."
		% [descriptor["name"], viewport_size]
	)
	_check_unified_building_frame(ui, descriptor, viewport_size)

	var all_text := _visible_text(ui).to_upper()
	for required_term in descriptor["terms"]:
		_expect(
			all_text.contains(String(required_term)),
			"%s must visibly present '%s' at %s."
			% [descriptor["name"], required_term, viewport_size]
		)

	for child in window.find_children("*", "Button", true, false):
		var button := child as Button
		if not button.is_visible_in_tree():
			continue
		var button_rect := _canvas_rect(button)
		var button_scroll := _nearest_scroll_container(button)
		if button_scroll == null:
			_expect(
				screen.encloses(button_rect) and window_rect.encloses(button_rect),
				"%s visible button %s must remain inside its window at %s."
				% [descriptor["name"], button.name, viewport_size]
			)
		_expect(
			button_rect.size.x >= 32.0 and button_rect.size.y >= 32.0,
			"%s button %s must retain a usable target at %s."
			% [descriptor["name"], button.name, viewport_size]
		)
		_expect(
			not button.text.strip_edges().is_empty()
				or button.icon != null
				or not button.tooltip_text.strip_edges().is_empty(),
			"%s button %s needs text, an icon, or an accessible tooltip at %s."
			% [descriptor["name"], button.name, viewport_size]
		)
		_check_text_minimum(button, String(descriptor["name"]), viewport_size)

	for child in window.find_children("*", "Label", true, false):
		var label := child as Label
		if label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			var label_rect := _canvas_rect(label)
			var label_scroll := _nearest_scroll_container(label)
			if label_scroll == null:
				_expect(
					window_rect.encloses(label_rect),
					"%s visible label %s must remain inside its window at %s."
					% [descriptor["name"], label.name, viewport_size]
				)
				_check_text_minimum(label, String(descriptor["name"]), viewport_size)

	for child in window.find_children("*", "RichTextLabel", true, false):
		var rich_text := child as RichTextLabel
		if rich_text.is_visible_in_tree() and not rich_text.text.strip_edges().is_empty():
			var rich_rect := _canvas_rect(rich_text)
			var rich_scroll := _nearest_scroll_container(rich_text)
			if rich_scroll == null:
				_expect(
					window_rect.encloses(rich_rect),
					"%s visible rich text %s must remain inside its window at %s."
					% [descriptor["name"], rich_text.name, viewport_size]
				)

	for child in window.find_children("*", "TextureRect", true, false):
		var texture_rect := child as TextureRect
		if texture_rect.is_visible_in_tree() and texture_rect.texture != null:
			var texture_scroll := _nearest_scroll_container(texture_rect)
			if texture_scroll == null:
				_expect(
					window_rect.encloses(_canvas_rect(texture_rect)),
					"%s visible texture %s must remain inside its window at %s."
					% [descriptor["name"], texture_rect.name, viewport_size]
				)

	for child in window.find_children("*", "ScrollContainer", true, false):
		var scroll := child as ScrollContainer
		if not scroll.is_visible_in_tree():
			continue
		_expect(
			window_rect.encloses(_canvas_rect(scroll)) and scroll.clip_contents,
			"%s scroll region %s must clip inside its window at %s."
			% [descriptor["name"], scroll.name, viewport_size]
		)

	var icon_summary := _visible_icon_summary(window)
	_expect(
		int(icon_summary["count"]) >= int(descriptor["minimum_icons"]),
		"%s must show at least %d functional icons at %s; got %d."
		% [
			descriptor["name"],
			descriptor["minimum_icons"],
			viewport_size,
			icon_summary["count"],
		]
	)
	var minimum_icon_paths := int(descriptor.get("minimum_icon_paths", 3))
	_expect(
		(icon_summary["paths"] as Dictionary).size() >= minimum_icon_paths,
		"%s must use at least %d distinct icon textures at %s."
		% [descriptor["name"], minimum_icon_paths, viewport_size]
	)

	if should_capture:
		await _capture_viewport(
			viewport,
			String(descriptor["name"]).to_snake_case(),
			viewport_size
		)
		if descriptor["name"] == "PlayerBlacksmithUI":
			ui.call("select_blacksmith_service", &"sales_table")
			await process_frame
			await _capture_viewport(viewport, "player_blacksmith_sales_table", viewport_size)
		elif descriptor["name"] == "ShopUI":
			ui.call("set_shop_context", &"equipment_blueprint_shop")
			await process_frame
			await _capture_viewport(viewport, "equipment_blueprint_shop", viewport_size)

	await _check_alternate_states(ui, String(descriptor["name"]), window_rect, viewport_size)
	viewport.queue_free()
	await process_frame


func _check_unified_building_frame(
	ui: Control,
	descriptor: Dictionary,
	viewport_size: Vector2i
) -> void:
	var ui_name := String(descriptor["name"])
	var window := ui.find_child(String(descriptor["window"]), true, false) as Control
	var header := ui.find_child(String(descriptor["header"]), true, false) as Control
	var content := ui.find_child(String(descriptor["content"]), true, false) as Control
	var identity := ui.find_child(String(descriptor["identity"]), true, false) as Control
	var title := ui.find_child(String(descriptor["title"]), true, false) as Label
	var close_button := ui.find_child(String(descriptor["close"]), true, false) as Button
	var header_icon_name := "HallIcon" if ui_name == "TownHallUI" else "HeaderIcon"
	var header_icon := ui.find_child(header_icon_name, true, false) as TextureRect
	var title_banner := ui.find_child("TitleBanner", true, false) as TextureRect
	var portrait := ui.find_child("PortraitFrame", true, false) as Control
	var middle_name: String = {
		"MaterialYardUI": "CatalogPanel",
		"PlayerBlacksmithUI": "RecipePanel",
		"TownHallUI": "AgendaPanel",
		"ShopUI": "ItemListPanel",
	}.get(ui_name, "")
	var middle := ui.find_child(String(middle_name), true, false) as Control
	var header_rect := _canvas_rect(header) if header != null else Rect2()
	var content_rect := _canvas_rect(content) if content != null else Rect2()
	var identity_rect := _canvas_rect(identity) if identity != null else Rect2()
	var portrait_rect := _canvas_rect(portrait) if portrait != null else Rect2()
	var middle_rect := _canvas_rect(middle) if middle != null else Rect2()
	_expect(
		window != null
			and window.custom_minimum_size.is_equal_approx(Vector2(1040.0, 640.0))
			and window.size.x <= 1040.5
			and window.size.y <= 640.5
			and window.theme_type_variation == &"TownServiceWindow",
		"%s must use the shared 1040x640 Town service window at %s; got %s."
		% [ui_name, viewport_size, window.size if window != null else Vector2.ZERO]
	)
	_expect(
		ui.theme != null and ui.theme.resource_path == FRAME_THEME_PATH,
		"%s must reference the shared Town service frame Theme at %s."
		% [ui_name, viewport_size]
	)
	_expect(
		header != null
			and header.custom_minimum_size.y == 58.0
			and is_equal_approx(header.size.y, 58.0)
			and content != null
			and is_equal_approx(header_rect.position.x, content_rect.position.x)
			and is_equal_approx(header_rect.size.x, content_rect.size.x),
		"%s must use the shared 58px building header at %s."
		% [ui_name, viewport_size]
	)
	_expect(
		content != null
			and header != null
			and is_equal_approx(content_rect.position.y, header_rect.end.y + 10.0),
		"%s content must begin 10px below the shared header at %s."
		% [ui_name, viewport_size]
	)
	if ui_name == "PlayerBlacksmithUI":
		var workshop_interior := ui.find_child("WorkshopInterior", true, false) as Control
		_expect(
			workshop_interior != null
				and workshop_interior.is_visible_in_tree()
				and content_rect.encloses(_canvas_rect(workshop_interior))
				and not (ui.find_child("WorkspaceHolder", true, false) as Control).visible,
			"PlayerBlacksmithUI must open on one full-width geometric workshop floor at %s."
			% viewport_size
		)
	else:
		_expect(
			identity != null
				and identity.custom_minimum_size.x == 218.0
				and content != null
				and is_equal_approx(identity_rect.position.x, content_rect.position.x),
			"%s must use the shared 218px identity column at %s."
			% [ui_name, viewport_size]
		)
		_expect(
			portrait != null
				and portrait.custom_minimum_size == Vector2(218.0, 252.0)
				and portrait.theme_type_variation == &"TownServicePortrait"
				and identity != null
				and is_equal_approx(portrait_rect.position.x, identity_rect.position.x),
			"%s must use the shared 218x252 Town portrait frame at %s."
			% [ui_name, viewport_size]
		)
		_expect(
			middle != null
				and middle.custom_minimum_size.x == 270.0
				and identity != null
				and is_equal_approx(middle_rect.position.x, identity_rect.end.x + 12.0),
			"%s must use the shared 270px middle column at %s."
			% [ui_name, viewport_size]
		)
	_expect(
		close_button != null
			and close_button.custom_minimum_size == Vector2(104.0, 42.0)
			and close_button.icon != null
			and close_button.text == "Close"
			and not close_button.disabled
			and close_button.modulate.a > 0.99
			and close_button.self_modulate.a > 0.99,
		"%s must use the shared icon-and-text Close action at %s."
		% [ui_name, viewport_size]
	)
	_expect(
		title != null
			and title.theme_type_variation == &"TownServiceTitle"
			and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
			and title.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
			and title.get_minimum_size().x <= title.size.x + 0.5
			and title_banner != null
			and _canvas_rect(title_banner).encloses(_canvas_rect(title)),
		"%s must center its title in the shared header title region at %s."
		% [ui_name, viewport_size]
	)
	_expect(
		close_button != null
			and close_button.theme_type_variation == &"TownServiceCloseButton",
		"%s must use the shared Close button Theme variation at %s."
		% [ui_name, viewport_size]
	)
	_expect(
		header_icon != null
			and header_icon.custom_minimum_size == Vector2(46.0, 46.0)
			and header_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s must use the shared filtered 46px header icon at %s."
		% [ui_name, viewport_size]
	)
	var window_style := window.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(
		window_style != null
			and window_style.border_width_left == 4
			and window_style.border_color.is_equal_approx(Color(0.67, 0.49, 0.24, 1.0)),
		"%s must resolve the shared Town service window StyleBox at %s."
		% [ui_name, viewport_size]
	)


func _check_alternate_states(
	ui: Control,
	ui_name: String,
	window_rect: Rect2,
	viewport_size: Vector2i
) -> void:
	match ui_name:
		"MaterialYardUI":
			(ui.find_child("ForgeToolsButton", true, false) as Button).pressed.emit()
			await process_frame
			_expect(
				_visible_text(ui).to_upper().contains("FORGING HAMMER"),
				"MaterialYardUI Forge Tools state must remain reachable at %s."
				% viewport_size
			)
		"PlayerBlacksmithUI":
			(ui.find_child("UpgradeObjectButton", true, false) as Button).pressed.emit()
			await process_frame
			_expect(
				_visible_text(ui).contains("Workshop Level"),
				"PlayerBlacksmithUI upgrade state must remain readable at %s."
				% viewport_size
			)
			ui.call("select_blacksmith_service", &"sales_table")
			await process_frame
			_expect(
				_visible_text(ui).contains("PLAYER MARKET")
					and _visible_text(ui).contains("主角")
					and _visible_text(ui).contains("顧客")
					and _visible_text(ui).contains("待補貨"),
				"PlayerBlacksmithUI must enter the readable geometric shop interior at %s."
				% viewport_size
			)
			var ledger := ui.find_child("MarketResourceSummary", true, false) as Label
			_expect(
				ledger != null
					and ledger.is_visible_in_tree()
					and ledger.text.contains("GOLD")
					and ledger.text.contains("貨架"),
				"Player market must keep gold and shelf capacity visible at %s."
				% viewport_size
			)
			var market_window := ui.find_child("PlayerMarketWindow", true, false) as Control
			var store_interior := ui.find_child("StoreInterior", true, false) as Control
			var market_content := market_window.find_child("Content", true, false) as HBoxContainer
			var inventory_panel := market_window.find_child("InventoryPanel", true, false) as Control
			var shelves_panel := market_window.find_child("ShelvesPanel", true, false) as Control
			var rumor_panel := market_window.find_child("RumorPanel", true, false) as Control
			_expect(
				market_window.custom_minimum_size == Vector2(1040.0, 640.0)
					and market_window.size.x <= 1040.5
					and market_window.size.y <= 640.5
					and absf(_canvas_rect(market_window).get_center().x - float(viewport_size.x) * 0.5) <= 1.0
					and absf(_canvas_rect(market_window).get_center().y - float(viewport_size.y) * 0.5) <= 1.0,
				"Player market must use the centered 1040x640 service frame at %s."
				% viewport_size
			)
			_expect(
				store_interior != null
					and store_interior.size.y >= 300.0
					and market_content != null
					and not market_content.visible
					and not inventory_panel.visible
					and not shelves_panel.visible
					and not rumor_panel.visible,
				"Player market must open on the geometric shop floor with management panels folded away at %s."
				% viewport_size
			)
			(ui.find_child("Product1InteractButton", true, false) as Button).pressed.emit()
			await process_frame
			_expect(
				market_content.is_visible_in_tree()
					and inventory_panel.is_visible_in_tree()
					and shelves_panel.is_visible_in_tree()
					and not rumor_panel.visible
					and _canvas_rect(inventory_panel).end.x <= _canvas_rect(shelves_panel).position.x,
				"Selecting a counter object must reveal only its non-overlapping stock interaction at %s."
				% viewport_size
			)
		"TownHallUI":
			(ui.find_child("HallUpgradeButton", true, false) as Button).pressed.emit()
			await process_frame
			var upgrade_content := ui.find_child("UpgradeContent", true, false) as Control
			var overview_content := ui.find_child("OverviewContent", true, false) as Control
			var detail_title := ui.find_child("DetailTitle", true, false) as Label
			_expect(
				upgrade_content != null
					and upgrade_content.is_visible_in_tree()
					and overview_content != null
					and not overview_content.visible
					and detail_title != null
					and detail_title.text == "Town Development",
				"TownHallUI upgrade state must remain readable at %s." % viewport_size
			)
		"ShopUI":
			ui.call("set_shop_context", &"equipment_blueprint_shop")
			await process_frame
			_expect(
				(ui.find_child("TitleText", true, false) as Label).text
					== "BASIC EQUIPMENT & BLUEPRINTS",
				"ShopUI equipment blueprint state must retain its title at %s."
				% viewport_size
			)
	var active_window_rect := window_rect
	if ui_name == "PlayerBlacksmithUI":
		var market_window := ui.find_child("PlayerMarketWindow", true, false) as Control
		if market_window != null and market_window.is_visible_in_tree():
			active_window_rect = _canvas_rect(market_window)
	_check_visible_non_scroll_controls_inside(ui, ui_name, active_window_rect, viewport_size)


func _check_visible_non_scroll_controls_inside(
	ui: Control,
	ui_name: String,
	window_rect: Rect2,
	viewport_size: Vector2i
) -> void:
	for type_name in ["Button", "Label", "RichTextLabel", "TextureRect"]:
		for child in ui.find_children("*", type_name, true, false):
			var control := child as Control
			if (
				control == null
				or not control.is_visible_in_tree()
				or _nearest_scroll_container(control) != null
			):
				continue
			_expect(
				window_rect.encloses(_canvas_rect(control)),
				"%s alternate state control %s must remain inside the window at %s."
				% [ui_name, control.name, viewport_size]
			)
			if control is Label or control is Button:
				_check_text_minimum(control, ui_name, viewport_size)


func _check_text_minimum(
	control: Control,
	ui_name: String,
	viewport_size: Vector2i
) -> void:
	if control is Label:
		var label := control as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return
		if label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			return
	var minimum := control.get_minimum_size()
	_expect(
		minimum.x <= control.size.x + 0.5 and minimum.y <= control.size.y + 0.5,
		"%s text control %s must fit its allocated rect at %s; minimum=%s size=%s."
		% [ui_name, control.name, viewport_size, minimum, control.size]
	)


func _capture_viewport(viewport: SubViewport, file_stem: String, viewport_size: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(_capture_directory)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for child in viewport.find_children("*", "CanvasItem", true, false):
		(child as CanvasItem).queue_redraw()
	for _frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var capture_path := _capture_directory.path_join(
		"%s_%dx%d.png" % [file_stem, viewport_size.x, viewport_size.y]
	)
	_expect(
		viewport.get_texture().get_image().save_png(capture_path) == OK,
		"Visual capture must save to %s." % capture_path
	)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _configure_ui(ui: Control, ui_name: String) -> bool:
	if ui_name == "ShopUI":
		var required_methods := [
			"set_merchant_name",
			"set_shop_context",
			"set_wallet",
			"set_items",
		]
		for method_name in required_methods:
			_expect(
				ui.has_method(StringName(method_name)),
				"ShopUI must expose %s() for layout fixtures." % method_name
			)
			if not ui.has_method(StringName(method_name)):
				return false
		var icon_paths := [
			"res://assets/ui/autumn/cards/generated/flame_imbue.png",
			"res://assets/ui/autumn/cards/generated/frostburst_imbue.png",
			"res://assets/ui/equipment/generated/iron_sword.png",
			"res://assets/ui/equipment/generated/vitality_charm.png",
		]
		var blueprint_names := [
			"Flame Imbue Blueprint",
			"Frostburst Imbue Blueprint",
			"Storm Charge Blueprint",
			"Venom Edge Blueprint",
			"Iron Sword Blueprint",
			"Hunter Bow Blueprint",
			"Leather Armor Blueprint",
			"Vitality Charm Blueprint",
			"Apprentice Staff Blueprint",
			"Chain Armor Blueprint",
		]
		var items: Array[Dictionary] = []
		for index in 10:
			items.append({
				"id": "fixture_%d" % index,
				"name": blueprint_names[index],
				"description": "Readable transaction fixture with a useful item icon.",
				"price": 25 + index,
				"stock": 9,
				"owned_count": 3,
				"texture": load(icon_paths[index % icon_paths.size()]),
			})
		ui.call("set_merchant_name", "Sword Soul Merchant")
		ui.call("set_shop_context", &"sword_soul_shop")
		ui.call("set_wallet", 123456)
		ui.call("set_items", items)
		return true

	_expect(
		ui.has_method("set_services"),
		"%s must expose set_services() for layout fixtures." % ui_name
	)
	if not ui.has_method("set_services"):
		return false
	var inventory: RefCounted = INVENTORY_SCRIPT.new()
	for resource_id in inventory.call("get_resource_ids"):
		inventory.call("set_resource_amount", resource_id, 5000)
	var town: RefCounted = TOWN_SCRIPT.new(inventory)
	ui.call("set_services", town, inventory)
	if ui_name == "MaterialYardUI":
		ui.call("set_offers", [
			{
				"id": "material_wood_bundle",
				"name": "Autumn Wood Bundle",
				"description": "Forge stock.",
				"product_kind": "resource",
				"product_id": "autumn_wood",
				"price": 18,
				"required_flame_tier": 0,
			},
			{
				"id": "tool_forging_hammer",
				"name": "Forging Hammer",
				"description": "Permanent forge tool.",
				"product_kind": "tool",
				"product_id": "forging_hammer",
				"price": 60,
				"required_flame_tier": 0,
			},
		])
	return true


func _visible_icon_summary(node: Node) -> Dictionary:
	var count := 0
	var paths := {}
	for child in node.find_children("*", "BaseButton", true, false):
		var button := child as BaseButton
		if button.is_visible_in_tree() and button.icon != null:
			count += 1
			paths[_texture_identity(button.icon)] = true
	for child in node.find_children("*", "TextureRect", true, false):
		var texture_rect := child as TextureRect
		if (
			texture_rect.is_visible_in_tree()
			and texture_rect.texture != null
			and String(texture_rect.name).to_lower().contains("icon")
		):
			count += 1
			paths[_texture_identity(texture_rect.texture)] = true
	return {"count": count, "paths": paths}


func _texture_identity(texture: Texture2D) -> String:
	if not texture.resource_path.is_empty():
		return texture.resource_path
	return str(texture.get_rid())


func _visible_text(node: Node) -> String:
	var parts: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.is_visible_in_tree():
			parts.append(label.text)
	for child in node.find_children("*", "RichTextLabel", true, false):
		var rich_text := child as RichTextLabel
		if rich_text.is_visible_in_tree():
			parts.append(rich_text.text)
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree():
			parts.append(button.text)
	return "\n".join(parts)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _nearest_scroll_container(control: Control) -> ScrollContainer:
	var current := control.get_parent()
	while current != null:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null


func _rect_approximately_equal(left: Rect2, right: Rect2) -> bool:
	return left.position.distance_to(right.position) <= 0.5 and left.size.distance_to(
		right.size
	) <= 0.5


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
