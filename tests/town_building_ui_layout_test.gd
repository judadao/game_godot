extends SceneTree

const INVENTORY_SCRIPT := preload("res://scripts/systems/inventory_manager.gd")
const TOWN_SCRIPT := preload("res://scripts/systems/town_manager.gd")
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
		"terms": ["MATERIAL", "UPGRADE"],
		"minimum_icons": 3,
	},
	{
		"name": "PlayerBlacksmithUI",
		"path": "res://scenes/ui/town/PlayerBlacksmithUI.tscn",
		"window": "PlayerBlacksmithWindow",
		"terms": ["FORGE", "DESIGN RESEARCH", "SOUL REFINERY"],
		"minimum_icons": 3,
	},
	{
		"name": "TownHallUI",
		"path": "res://scenes/ui/town/TownHallUI.tscn",
		"window": "TownHallWindow",
		"terms": ["TOWN HALL", "VILLAGE"],
		"minimum_icons": 3,
	},
	{
		"name": "ShopUI",
		"path": "res://scenes/ui/shop/ShopUI.tscn",
		"window": "ShopWindow",
		"terms": ["BUY", "SELL", "GOLD"],
		"minimum_icons": 4,
	},
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	_expect(
		(icon_summary["paths"] as Dictionary).size() >= 3,
		"%s must use at least three distinct icon textures at %s."
		% [descriptor["name"], viewport_size]
	)

	viewport.queue_free()
	await process_frame


func _configure_ui(ui: Control, ui_name: String) -> bool:
	if ui_name == "ShopUI":
		var required_methods := ["set_merchant_name", "set_wallet", "set_items"]
		for method_name in required_methods:
			_expect(
				ui.has_method(StringName(method_name)),
				"ShopUI must expose %s() for layout fixtures." % method_name
			)
			if not ui.has_method(StringName(method_name)):
				return false
		var icon_paths := [
			"res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png",
			"res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0001_Shield.png",
			"res://assets/curated/game_own/items/oga_rpg_item_icons/Potions/PotionHp_Small.png",
			"res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png",
		]
		var items: Array[Dictionary] = []
		for index in 8:
			items.append({
				"id": "fixture_%d" % index,
				"name": "Sword Soul Item %d" % (index + 1),
				"description": "Readable transaction fixture with a useful item icon.",
				"price": 25 + index,
				"stock": 9,
				"owned_count": 3,
				"texture": load(icon_paths[index % icon_paths.size()]),
			})
		ui.call("set_merchant_name", "Sword Soul Merchant")
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
