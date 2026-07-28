extends SceneTree

const INVENTORY_SCRIPT := preload("res://scripts/systems/inventory_manager.gd")
const TOWN_SCRIPT := preload("res://scripts/systems/town_manager.gd")
const SCENE_PATHS := {
	"material_yard": "res://scenes/ui/town/MaterialYardUI.tscn",
	"player_blacksmith": "res://scenes/ui/town/PlayerBlacksmithUI.tscn",
	"town_hall": "res://scenes/ui/town/TownHallUI.tscn",
	"shop": "res://scenes/ui/shop/ShopUI.tscn",
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_material_yard()
	await _test_player_blacksmith()
	await _test_town_hall()
	await _test_shop()
	quit(1 if _failures > 0 else 0)


func _test_material_yard() -> void:
	var ui := await _instantiate_ui("material_yard")
	if ui == null:
		return
	if not _require_methods(
		ui,
		["open", "set_services", "set_context", "get_context_id", "get_resource_text"],
		"MaterialYardUI"
	):
		await _free_ui(ui)
		return
	var services := _new_services()
	var town: RefCounted = services["town"]
	ui.call("set_services", town, services["inventory"])
	ui.call("set_context", &"material_yard")
	ui.call("open")
	await process_frame

	_expect(
		StringName(ui.call("get_context_id")) == &"material_yard",
		"MaterialYardUI must preserve its building routing context."
	)
	_expect(
		String(ui.call("get_resource_text")).contains("Autumn Wood")
			and String(ui.call("get_resource_text")).contains("Stone"),
		"MaterialYardUI must project the materials used by its upgrade."
	)
	var upgrade_button := ui.find_child("WorkshopUpgradeButton", true, false) as Button
	_expect(
		upgrade_button != null,
		"MaterialYardUI must expose its authored workshop upgrade action."
	)
	if upgrade_button != null:
		upgrade_button.pressed.emit()
		await process_frame
	_expect(
		int(town.call("get_building_level", &"workshop")) == 1,
		"MaterialYardUI must upgrade workshop and no other building."
	)
	await _free_ui(ui)


func _test_player_blacksmith() -> void:
	var ui := await _instantiate_ui("player_blacksmith")
	if ui == null:
		return
	if not _require_methods(
		ui,
		[
			"set_services",
			"set_context",
			"get_context_id",
			"select_blacksmith_service",
			"get_blacksmith_service",
			"upgrade_service_building",
			"request_blueprint_research",
			"select_equipment",
			"purchase_selected_equipment",
			"equip_selected_equipment",
			"strengthen_selected_equipment",
		],
		"PlayerBlacksmithUI"
	):
		await _free_ui(ui)
		return
	var services := _new_services()
	var town: RefCounted = services["town"]
	ui.call("set_services", town, services["inventory"])
	ui.call("set_context", &"player_blacksmith")
	ui.call("open")
	await process_frame

	_expect(
		StringName(ui.call("get_context_id")) == &"player_blacksmith",
		"PlayerBlacksmithUI must preserve its building routing context."
	)
	_expect(
		String(ui.call("get_resource_text")).contains("Gold 5,000")
			and String(ui.call("get_resource_text")).contains("Shards 5,000"),
		"PlayerBlacksmithUI must project current persistent resource amounts."
	)
	_expect(
		StringName(ui.call("get_blacksmith_service")) == &"forge",
		"PlayerBlacksmithUI must open on Forge."
	)
	ui.call("upgrade_service_building")
	_expect(
		int(town.call("get_building_level", &"blacksmith")) == 1,
		"Forge service must target the blacksmith building."
	)

	ui.call("select_blacksmith_service", &"soul_refinery")
	_expect(
		StringName(ui.call("get_blacksmith_service")) == &"soul_refinery",
		"PlayerBlacksmithUI must expose the moved Soul Refinery service."
	)
	ui.call("upgrade_service_building")
	_expect(
		int(town.call("get_building_level", &"memory_library")) == 1,
		"Soul Refinery must target memory_library progression."
	)

	var research_requests := [0]
	ui.connect(
		"blueprint_research_requested",
		func() -> void: research_requests[0] += 1
	)
	ui.call("request_blueprint_research")
	_expect(
		research_requests[0] == 1,
		"Design Research must emit exactly one routing intent for its external screen."
	)
	_expect(
		_visible_text(ui).contains("Forge")
			and _visible_text(ui).contains("Design Research")
			and _visible_text(ui).contains("Soul Refinery"),
		"PlayerBlacksmithUI must keep all three moved services discoverable."
	)
	var inventory: RefCounted = services["inventory"]
	ui.call("select_blacksmith_service", &"forge")
	ui.call("select_equipment", &"iron_sword")
	ui.call("purchase_selected_equipment")
	_expect(
		bool(inventory.call("has_equipment", &"iron_sword")),
		"Forge must purchase the selected equipment through InventoryManager."
	)
	ui.call("equip_selected_equipment")
	_expect(
		StringName(inventory.call("get_equipped", &"weapon")) == &"iron_sword",
		"Forge must equip the selected owned item."
	)
	ui.call("strengthen_selected_equipment")
	_expect(
		int(inventory.call("get_equipment_level", &"iron_sword")) == 2,
		"Forge must strengthen the selected equipment exactly once."
	)
	await _free_ui(ui)


func _test_town_hall() -> void:
	var ui := await _instantiate_ui("town_hall")
	if ui == null:
		return
	if not _require_methods(
		ui,
		["open", "set_services", "set_context", "get_context_id", "get_resource_text"],
		"TownHallUI"
	):
		await _free_ui(ui)
		return
	var services := _new_services()
	var town: RefCounted = services["town"]
	ui.call("set_services", town, services["inventory"])
	ui.call("set_context", &"town_hall")
	ui.call("open")
	await process_frame

	_expect(
		StringName(ui.call("get_context_id")) == &"town_hall",
		"TownHallUI must preserve its building routing context."
	)
	_expect(
		_visible_text(ui).contains("Village")
			or _visible_text(ui).contains("Settlement"),
		"TownHallUI must project the current village stage."
	)
	var upgrade_button := ui.find_child("UpgradeButton", true, false) as Button
	_expect(upgrade_button != null, "TownHallUI must expose its authored upgrade action.")
	if upgrade_button != null:
		upgrade_button.pressed.emit()
		await process_frame
	_expect(
		int(town.call("get_building_level", &"town_hall")) == 1,
		"TownHallUI must upgrade town_hall and no other building."
	)
	await _free_ui(ui)


func _test_shop() -> void:
	var ui := await _instantiate_ui("shop")
	if ui == null:
		return
	if not _require_methods(
		ui,
		[
			"open",
			"set_merchant_name",
			"set_shop_context",
			"set_wallet",
			"set_mode",
			"set_items",
			"set_quantity",
		],
		"ShopUI"
	):
		await _free_ui(ui)
		return
	_expect(ui.has_signal("confirmed"), "ShopUI must expose confirmed transaction intent.")
	if not ui.has_signal("confirmed"):
		await _free_ui(ui)
		return
	var icon := load(
		"res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png"
	) as Texture2D
	var item := {
		"id": "soul_edge",
		"name": "Soul Edge",
		"description": "A blade tempered for sword souls.",
		"price": 120,
		"sell_price": 60,
		"stock": 4,
		"owned_count": 3,
		"texture": icon,
	}
	var confirmations: Array[Dictionary] = []
	ui.connect(
		"confirmed",
		func(
			confirmed_item: Dictionary,
			quantity: int,
			mode: String
		) -> void:
			confirmations.append({
				"id": confirmed_item.get("id", ""),
				"quantity": quantity,
				"mode": mode,
			})
	)
	ui.call("set_merchant_name", "Sword Soul Merchant")
	ui.call("set_shop_context", &"sword_soul_shop")
	ui.call("set_wallet", 999)
	ui.call("set_items", [item])
	ui.call("open")
	ui.call("set_quantity", 99)
	_expect(
		int(ui.get("quantity")) == 4,
		"ShopUI must clamp buy quantity to available stock."
	)
	var confirm_button := ui.find_child("ConfirmButton", true, false) as Button
	_expect(confirm_button != null, "ShopUI must expose its authored confirm action.")
	if confirm_button != null:
		confirm_button.pressed.emit()
	_expect(
		confirmations.size() == 1
			and confirmations[0]["id"] == "soul_edge"
			and confirmations[0]["quantity"] == 4
			and confirmations[0]["mode"] == "buy",
		"ShopUI must emit the selected item, clamped quantity, and buy mode."
	)

	ui.call("set_mode", "sell")
	ui.call("set_quantity", 99)
	_expect(
		int(ui.get("quantity")) == 3,
		"ShopUI must clamp sell quantity to owned count."
	)
	if confirm_button != null:
		confirm_button.pressed.emit()
	_expect(
		confirmations.size() == 2
			and confirmations[1]["quantity"] == 3
			and confirmations[1]["mode"] == "sell",
		"ShopUI must preserve the sell transaction intent contract."
	)
	_expect(
		_visible_text(ui).contains("SWORD SOUL SHOP")
			and _visible_text(ui).contains("Sword Soul Merchant")
			and _visible_text(ui).contains("999"),
		"ShopUI must project building identity, merchant identity, and wallet balance."
	)
	var long_catalog: Array[Dictionary] = []
	for index in 10:
		var catalog_item := item.duplicate(true)
		catalog_item["id"] = "catalog_%d" % index
		catalog_item["name"] = "Catalog Item %d" % (index + 1)
		long_catalog.append(catalog_item)
	ui.call("set_items", long_catalog)
	ui.call("set_selected_item", 9)
	var item_rows := ui.find_child("ItemRows", true, false) as VBoxContainer
	_expect(
		item_rows != null and item_rows.get_child_count() >= 10,
		"ShopUI must create reachable rows for catalogs larger than eight items."
	)
	_expect(
		int(ui.get("selected_index")) == 9
			and _visible_text(ui).contains("Catalog Item 10"),
		"ShopUI must allow selecting the tenth catalog item."
	)
	await process_frame
	var tenth_row := item_rows.get_child(9) as Button if item_rows != null else null
	if tenth_row != null:
		tenth_row.grab_focus()
		await process_frame
		await process_frame
	var item_scroll := ui.find_child("ItemScroll", true, false) as ScrollContainer
	_expect(
		tenth_row != null
			and tenth_row.has_focus()
			and item_scroll != null
			and item_scroll.scroll_vertical > 0,
		"Keyboard focus must scroll a catalog row beyond the initial viewport into view."
	)
	await _free_ui(ui)


func _new_services() -> Dictionary:
	var inventory: RefCounted = INVENTORY_SCRIPT.new()
	for resource_id in inventory.call("get_resource_ids"):
		inventory.call("set_resource_amount", resource_id, 5000)
	var town: RefCounted = TOWN_SCRIPT.new(inventory)
	return {"town": town, "inventory": inventory}


func _instantiate_ui(key: String) -> Control:
	var path := String(SCENE_PATHS[key])
	_expect(
		ResourceLoader.exists(path, "PackedScene"),
		"%s must exist before its standalone behavior contract can run." % path
	)
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed := load(path) as PackedScene
	var ui := packed.instantiate() as Control if packed != null else null
	_expect(ui != null, "%s must instantiate as Control." % path)
	if ui == null:
		return null
	root.add_child(ui)
	await process_frame
	return ui


func _require_methods(
	ui: Control,
	method_names: Array,
	ui_name: String
) -> bool:
	var complete := true
	for method_name in method_names:
		if ui.has_method(StringName(method_name)):
			continue
		complete = false
		_expect(
			false,
			"%s must expose %s() for standalone behavior checks."
			% [ui_name, method_name]
		)
	return complete


func _visible_text(node: Node) -> String:
	var text_parts: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.is_visible_in_tree():
			text_parts.append(label.text)
	for child in node.find_children("*", "RichTextLabel", true, false):
		var rich_text := child as RichTextLabel
		if rich_text.is_visible_in_tree():
			text_parts.append(rich_text.text)
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree():
			text_parts.append(button.text)
	return "\n".join(text_parts)


func _free_ui(ui: Control) -> void:
	ui.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
