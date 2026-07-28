extends SceneTree

const UI_CONTRACTS := [
	{
		"name": "MaterialYardUI",
		"path": "res://scenes/ui/town/MaterialYardUI.tscn",
		"class_name": "MaterialYardUI",
		"window": "Window",
		"methods": [
			"open",
			"close",
			"toggle",
			"set_services",
			"set_context",
			"get_context_id",
			"get_building_id",
			"request_upgrade",
			"get_building_button_count",
			"get_resource_text",
		],
		"signals": ["opened", "closed", "toggled", "canceled"],
		"nodes": ["Title", "WorkshopUpgradeButton", "CloseButton"],
	},
	{
		"name": "PlayerBlacksmithUI",
		"path": "res://scenes/ui/town/PlayerBlacksmithUI.tscn",
		"class_name": "PlayerBlacksmithUI",
		"window": "PlayerBlacksmithWindow",
		"methods": [
			"open",
			"close",
			"toggle",
			"set_services",
			"set_context",
			"get_context_id",
			"get_building_id",
			"request_upgrade",
			"select_blacksmith_service",
			"select_service",
			"get_blacksmith_service",
			"get_selected_service",
			"request_blueprint_research",
			"upgrade_service_building",
			"select_equipment",
			"purchase_selected_equipment",
			"equip_selected_equipment",
			"strengthen_selected_equipment",
			"get_building_button_count",
			"get_equipment_button_count",
			"get_resource_text",
		],
		"signals": [
			"opened",
			"closed",
			"toggled",
			"canceled",
			"blueprint_research_requested",
		],
		"nodes": [
			"TitleLabel",
			"ForgeServiceButton",
			"ResearchServiceButton",
			"RefineryServiceButton",
			"UpgradeButton",
			"SoulUpgradeButton",
			"CloseButton",
		],
	},
	{
		"name": "TownHallUI",
		"path": "res://scenes/ui/town/TownHallUI.tscn",
		"class_name": "TownHallUI",
		"window": "TownHallWindow",
		"methods": [
			"open",
			"close",
			"toggle",
			"set_services",
			"set_context",
			"get_context_id",
			"get_building_id",
			"request_upgrade",
			"get_building_button_count",
			"get_resource_text",
		],
		"signals": ["opened", "closed", "toggled", "canceled"],
		"nodes": ["TitleText", "UpgradeButton", "CloseButton"],
	},
	{
		"name": "ShopUI",
		"path": "res://scenes/ui/shop/ShopUI.tscn",
		"class_name": "ShopUI",
		"window": "ShopWindow",
		"methods": [
			"open",
			"close",
			"toggle",
			"set_merchant_name",
			"set_shop_context",
			"set_wallet",
			"set_mode",
			"set_items",
			"set_selected_item",
			"set_quantity",
			"set_transaction_feedback",
		],
		"signals": [
			"opened",
			"closed",
			"toggled",
			"mode_changed",
			"item_selected",
			"quantity_changed",
			"confirmed",
			"canceled",
		],
		"nodes": ["TitleText", "BuyButton", "SellButton", "ConfirmButton", "CancelButton"],
	},
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for contract in UI_CONTRACTS:
		await _check_contract(contract)
	quit(1 if _failures > 0 else 0)


func _check_contract(contract: Dictionary) -> void:
	var path := String(contract["path"])
	_expect(
		ResourceLoader.exists(path, "PackedScene"),
		"%s scene must exist at %s." % [contract["name"], path]
	)
	if not ResourceLoader.exists(path, "PackedScene"):
		return

	var packed := load(path) as PackedScene
	_expect(packed != null, "%s must load as a PackedScene." % contract["name"])
	if packed == null:
		return
	var ui := packed.instantiate() as Control
	_expect(ui != null, "%s root must be a Control." % contract["name"])
	if ui == null:
		return
	root.add_child(ui)
	await process_frame

	var script := ui.get_script() as Script
	_expect(script != null, "%s must have a controller script." % contract["name"])
	if script != null:
		_expect(
			script.get_global_name() == StringName(contract["class_name"]),
			"%s controller must expose class_name %s."
			% [contract["name"], contract["class_name"]]
		)
	_expect(
		ui.anchor_left == 0.0
			and ui.anchor_top == 0.0
			and ui.anchor_right == 1.0
			and ui.anchor_bottom == 1.0,
		"%s must use a Full Rect root." % contract["name"]
	)
	_expect(
		ui.process_mode == Node.PROCESS_MODE_ALWAYS,
		"%s must remain operable while the menu stack pauses gameplay." % contract["name"]
	)

	for method_name in contract["methods"]:
		_expect(
			ui.has_method(StringName(method_name)),
			"%s must expose public method %s()." % [contract["name"], method_name]
		)
	for signal_name in contract["signals"]:
		_expect(
			ui.has_signal(StringName(signal_name)),
			"%s must expose signal %s." % [contract["name"], signal_name]
		)

	var window := ui.find_child(String(contract["window"]), true, false)
	_expect(
		window is PanelContainer,
		"%s must author semantic PanelContainer %s."
		% [contract["name"], contract["window"]]
	)
	for node_name in contract["nodes"]:
		_expect(
			ui.find_child(String(node_name), true, false) != null,
			"%s must author stable semantic node %s."
			% [contract["name"], node_name]
		)

	ui.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
