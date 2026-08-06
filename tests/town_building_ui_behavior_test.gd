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
		[
			"open",
			"set_services",
			"set_offers",
			"set_context",
			"get_context_id",
			"get_resource_text",
			"get_offer_button_count",
		],
		"MaterialYardUI"
	):
		await _free_ui(ui)
		return
	var services := _new_services()
	var town: RefCounted = services["town"]
	ui.call("set_services", town, services["inventory"])
	ui.call("set_offers", [
		{
			"id": "material_wood_bundle",
			"name": "Autumn Wood Bundle",
			"description": "Basic timber for forge recipes.",
			"product_kind": "resource",
			"product_id": "autumn_wood",
			"price": 18,
			"required_flame_tier": 0,
		},
		{
			"id": "tool_forging_hammer",
			"name": "Forging Hammer",
			"description": "Permanent basic forging tool.",
			"product_kind": "tool",
			"product_id": "forging_hammer",
			"price": 60,
			"required_flame_tier": 0,
		},
	])
	ui.call("set_context", &"material_yard")
	ui.call("open")
	await process_frame

	_expect(
		StringName(ui.call("get_context_id")) == &"material_yard",
		"MaterialYardUI must preserve its building routing context."
	)
	_expect(
		String(ui.call("get_resource_text")).contains("5,000 G"),
		"MaterialYardUI must project the persistent forge wallet."
	)
	_expect(
		int(ui.call("get_offer_button_count")) == 1,
		"MaterialYardUI must show the active Materials filter."
	)
	var purchase_requests: Array[Dictionary] = []
	ui.connect(
		"purchase_requested",
		func(offer_id: StringName, quantity: int) -> void:
			purchase_requests.append({"offer_id": offer_id, "quantity": quantity})
	)
	var buy_button := ui.find_child("BuyButton", true, false) as Button
	_expect(
		buy_button != null,
		"MaterialYardUI must expose its authored purchase action."
	)
	if buy_button != null:
		buy_button.pressed.emit()
		await process_frame
	_expect(
		purchase_requests.size() == 1
			and purchase_requests[0]["offer_id"] == &"material_wood_bundle"
			and purchase_requests[0]["quantity"] == 1,
		"MaterialYardUI must emit the selected offer and quantity."
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
			"set_recipes",
			"set_sale_state",
			"craft_selected_recipe",
			"request_list_for_sale",
			"request_resolve_sale",
		],
		"PlayerBlacksmithUI"
	):
		await _free_ui(ui)
		return
	var services := _new_services()
	var town: RefCounted = services["town"]
	ui.call("set_services", town, services["inventory"])
	ui.call("set_recipes", [
		{
			"id": "forge_iron_sword",
			"result_id": "iron_sword",
			"result_kind": "equipment",
			"name": "Iron Sword",
			"description": "A basic forged weapon.",
			"kind": "weapon",
			"tier": 1,
			"cost": {"autumn_wood": 5, "stone": 3},
			"proficiency_level": 5,
			"blueprint_awakened": true,
			"quality_chances": {"rare": 0.30, "exceptional": 0.10, "legendary": 0.03},
			"unlocked": true,
		},
	])
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
		"PlayerBlacksmithUI must retain Forge as its default context."
	)
	var workshop_interior := ui.find_child("WorkshopInterior", true, false) as Control
	var workspace_holder := ui.find_child("WorkspaceHolder", true, false) as Control
	_expect(
		workshop_interior != null
			and workshop_interior.is_visible_in_tree()
			and workspace_holder != null
			and not workspace_holder.visible,
		"Entering the blacksmith must show the geometric workshop floor before any function panel."
	)
	(ui.find_child("ForgeObjectButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(
		not workshop_interior.visible
			and workspace_holder.visible
			and (ui.find_child("ForgeWorkspace", true, false) as Control).visible,
		"Selecting the furnace object must open only the forge workspace."
	)
	(ui.find_child("WorkshopBackButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(workshop_interior.visible and not workspace_holder.visible, "Closing a forge interaction must return to the workshop floor.")
	(ui.find_child("UpgradeObjectButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(
		(ui.find_child("UpgradeWorkspace", true, false) as Control).visible
			and not (ui.find_child("ForgeWorkspace", true, false) as Control).visible,
		"Selecting the workbench object must open only workshop improvement controls."
	)
	var workshop_upgrade_requests := [0]
	ui.connect(
		"workshop_upgraded",
		func() -> void: workshop_upgrade_requests[0] += 1
	)
	ui.call("upgrade_service_building")
	_expect(
		int(town.call("get_building_level", &"blacksmith")) == 1,
		"Forge service must target the blacksmith building."
	)
	_expect(
		workshop_upgrade_requests[0] == 1,
		"Workshop upgrade must request an immediate projection and save refresh."
	)

	ui.call("select_blacksmith_service", &"sales_table")
	ui.call("set_sale_state", {
		"status": "empty",
		"equipment_sales_unlocked": false,
		"candidates": [{
			"item_kind": "resource",
			"item_id": "magic_shard",
			"item_name": "魔力碎片",
			"quality": "rare",
			"quality_label": "稀有",
			"count": 4,
			"unit_price": 8,
		}],
		"fixture_state": {
			"active": {"id": "basic_counter", "name": "木製交易台", "capacity": 2},
			"next": {
				"id": "cedar_display",
				"name": "雪松展示櫃",
				"capacity": 3,
				"required_market_level": 1,
				"building_ready": true,
				"can_purchase": true,
				"cost": {"gold": 90, "autumn_wood": 12},
			},
		},
	})
	_expect(
		StringName(ui.call("get_blacksmith_service")) == &"sales_table",
		"PlayerBlacksmithUI must expose quality material and equipment sales."
	)
	var market_ui := ui.find_child("PlayerMarketUI", true, false) as Control
	var market_content := ui.find_child("Content", true, false) as Control
	var context_dock := ui.find_child("ContextDock", true, false) as Control
	_expect(
		market_content != null
			and not market_content.visible
			and (ui.find_child("StoreInterior", true, false) as Control).size.y >= 300.0,
		"The market must open on the shop floor without listing its management functions."
	)
	(ui.find_child("Product1InteractButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(
		market_content.visible
			and context_dock.visible
			and (ui.find_child("InventoryPanel", true, false) as Control).visible
			and not (ui.find_child("ShelvesPanel", true, false) as Control).visible
			and not (ui.find_child("RumorPanel", true, false) as Control).visible
			and _visible_text(ui).contains("魔力碎片")
			and _visible_text(ui).contains("稀有")
			and _visible_text(ui).contains("8 GOLD"),
		"Clicking an empty display position must open only its stock and price controls."
	)
	var candidate_list := ui.find_child("MarketCandidateList", true, false) as VBoxContainer
	var candidate_button: Button
	for child in candidate_list.get_children():
		if child is Button and (child as Button).visible:
			candidate_button = child as Button
			break
	_expect(
		market_ui != null
			and market_ui.visible
			and candidate_button != null
			and _visible_text(ui).contains("主角")
			and _visible_text(ui).contains("顧客")
			and _visible_text(ui).contains("待補貨"),
		"Entering the market must show a warm authored shop interior with owner, browsing customers, counter goods, and contextual management controls."
	)
	if candidate_button != null:
		candidate_button.pressed.emit()
		await process_frame
	_expect(
		ui.find_child("MarketItemName", true, false).get("text") == "魔力碎片",
		"Selecting a shop product must rebuild its row safely and update the counter detail."
	)
	var fixture_requests: Array[StringName] = []
	ui.connect(
		"market_fixture_purchase_requested",
		func(fixture_id: StringName) -> void: fixture_requests.append(fixture_id)
	)
	(ui.find_child("ShelfInteractButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(
		market_content.visible
			and not (ui.find_child("InventoryPanel", true, false) as Control).visible
			and (ui.find_child("ShelvesPanel", true, false) as Control).visible
			and not (ui.find_child("RumorPanel", true, false) as Control).visible,
		"Selecting the physical wall shelf must expose only shelf management."
	)
	(ui.find_child("MarketFixtureButton", true, false) as Button).pressed.emit()
	_expect(
		fixture_requests == [&"cedar_display"],
		"The physical display shelf must expose the next eligible furniture purchase."
	)
	var customer_checks: Array[int] = []
	ui.connect(
		"customer_purchase_check_requested",
		func(shelf_index: int) -> void: customer_checks.append(shelf_index)
	)
	ui.call("set_sale_state", {
		"capacity": 2,
		"shelves": [{
			"shelf_index": 0,
			"status": "customer_ready",
			"item_name": "魔力碎片 · 稀有",
			"sale_chance": 0.70,
		}],
		"candidates": [],
	})
	market_ui.call("_process", 3.0)
	_expect(
		customer_checks == [0]
			and ui.find_child("MarketResolveButton", true, false) == null,
		"Customers must initiate checkout automatically without a manual resolve-sale action."
	)
	(ui.find_child("BackButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(
		not market_ui.visible
			and workshop_interior.visible,
		"Leaving the shop scene must return to the geometric workshop floor."
	)
	(ui.find_child("ForgeObjectButton", true, false) as Button).pressed.emit()
	await process_frame
	var craft_requests: Array[StringName] = []
	ui.connect(
		"craft_requested",
		func(recipe_id: StringName) -> void: craft_requests.append(recipe_id)
	)
	_expect(
		_visible_text(ui).contains("圖紙已覺醒")
			and _visible_text(ui).contains("傳奇 3%"),
		"Forge detail must show blueprint proficiency awakening and legendary odds."
	)
	ui.call("craft_selected_recipe")
	_expect(
		craft_requests == [&"forge_iron_sword"],
		"Forge must emit the selected blueprint recipe."
	)
	(ui.find_child("WorkshopBackButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(
		_visible_text(ui).contains("ARCANE FORGE")
			and _visible_text(ui).contains("WORKBENCH")
			and _visible_text(ui).contains("MARKET DOOR"),
		"PlayerBlacksmithUI must keep Forge, workshop upgrade, and sales discoverable as physical objects."
	)
	await _free_ui(ui)


func _test_town_hall() -> void:
	var ui := await _instantiate_ui("town_hall")
	if ui == null:
		return
	if not _require_methods(
		ui,
		[
			"open",
			"set_services",
			"set_context",
			"get_context_id",
			"get_resource_text",
			"select_upgrade_building",
			"get_selected_upgrade_building",
		],
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
	var completed: Array[Dictionary] = []
	ui.connect(
		"building_upgraded",
		func(building_id: StringName, level: int) -> void:
			completed.append({"building_id": building_id, "level": level})
	)
	ui.call("select_upgrade_building", &"workshop")
	_expect(
		StringName(ui.call("get_selected_upgrade_building")) == &"workshop",
		"TownHallUI must expose the selected development project."
	)
	var upgrade_button := ui.find_child("UpgradeButton", true, false) as Button
	_expect(upgrade_button != null, "TownHallUI must expose its authored upgrade action.")
	if upgrade_button != null:
		upgrade_button.pressed.emit()
		await process_frame
	_expect(
		int(town.call("get_building_level", &"workshop")) == 1
			and int(town.call("get_building_level", &"town_hall")) == 0,
		"TownHallUI must upgrade the selected building and no other building."
	)
	_expect(
		completed == [{"building_id": &"workshop", "level": 1}],
		"TownHallUI must report the exact completed project for immediate persistence."
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
	ui.call("set_shop_context", &"general_store")
	ui.call("set_merchant_name", "Sword Soul Merchant")
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
		(ui.find_child("TitleText", true, false) as Label).text == "TRADE COUNTER"
			and (ui.find_child("GoldBalance", true, false) as Label).text
				== "Wallet: 999 gold",
		"ShopUI must project building identity and wallet balance."
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
	ui.call("set_shop_context", &"sword_soul_shop")
	ui.call("set_items", [{
		"id": "sword_soul_blueprint_flame_imbue",
		"name": "Flame Imbue Blueprint",
		"description": "Permanent Sword Soul design.",
		"price": 100,
		"stock": 1,
		"owned_count": 0,
		"product_kind": "blueprint",
		"target_kind": "sword_soul",
		"texture": icon,
	}])
	var sell_button := ui.find_child("SellButton", true, false) as Button
	_expect(
		sell_button != null and (not sell_button.visible or sell_button.disabled),
		"Sword Soul blueprint merchants must be buy-only."
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
