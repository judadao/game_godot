extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory_script := load("res://scripts/systems/inventory_manager.gd")
	var town_script := load("res://scripts/systems/town_manager.gd")
	var ui_scenes := {
		"MaterialYardUI": load("res://scenes/ui/town/MaterialYardUI.tscn") as PackedScene,
		"PlayerBlacksmithUI": load(
			"res://scenes/ui/town/PlayerBlacksmithUI.tscn"
		) as PackedScene,
		"TownHallUI": load("res://scenes/ui/town/TownHallUI.tscn") as PackedScene,
	}
	_expect(inventory_script != null and town_script != null, "Town runtime services must load.")
	for ui_name in ui_scenes:
		_expect(ui_scenes[ui_name] != null, "%s must load." % ui_name)
	if (
		inventory_script == null
		or town_script == null
		or ui_scenes.values().has(null)
	):
		quit(1)
		return
	var inventory: RefCounted = inventory_script.new()
	var town: RefCounted = town_script.new(inventory)
	_expect(inventory.has_method("upgrade_equipment"), "Inventory must support equipment strengthening.")
	_expect(inventory.has_method("get_equipment_level"), "Inventory must expose equipment levels.")
	if not inventory.has_method("upgrade_equipment"):
		quit(1)
		return

	_expect(inventory.has_method("purchase_equipment"), "Unowned equipment must have a paid acquisition path.")
	var purchase_resources := inventory.call("get_resources") as Dictionary
	_expect(bool(inventory.call("purchase_equipment", &"iron_sword")), "Affordable equipment must be purchasable.")
	_expect(
		int((inventory.call("get_resources") as Dictionary).get("gold", 0)) < int(purchase_resources.get("gold", 0)),
		"Purchasing equipment must spend permanent resources."
	)
	inventory.call("equip", &"iron_sword")
	var resources_before := inventory.call("get_resources") as Dictionary
	_expect(bool(inventory.call("upgrade_equipment", &"iron_sword")), "Owned equipment must be upgradeable in Town.")
	_expect(int(inventory.call("get_equipment_level", &"iron_sword")) == 2, "Equipment upgrade must increase its level.")
	var resources_after := inventory.call("get_resources") as Dictionary
	_expect(int(resources_after["gold"]) < int(resources_before["gold"]), "Equipment strengthening must spend gold.")
	_expect(float((inventory.call("get_effect_totals") as Dictionary).get("attack", 0)) > 4.0, "Equipment level must strengthen its effect.")
	_expect(inventory.has_method("to_dict") and inventory.has_method("apply_dict"), "Inventory progression must be serializable.")
	_expect(town.has_method("to_dict") and town.has_method("apply_dict"), "Town progression must be serializable.")
	if inventory.has_method("to_dict") and town.has_method("to_dict"):
		var inventory_copy: RefCounted = inventory_script.new()
		inventory_copy.call("apply_dict", inventory.call("to_dict"))
		_expect(int(inventory_copy.call("get_equipment_level", &"iron_sword")) == 2, "Equipment levels must survive serialization.")
		var town_copy: RefCounted = town_script.new(inventory_copy)
		town.call("upgrade_building", &"blacksmith")
		town_copy.call("apply_dict", town.call("to_dict"))
		_expect(int(town_copy.call("get_building_level", &"blacksmith")) == 1, "Building levels must survive serialization.")

	for ui_name in ui_scenes:
		var ui := (ui_scenes[ui_name] as PackedScene).instantiate()
		root.add_child(ui)
		ui.call("set_services", town, inventory)
		await process_frame
		var expected_building_actions := 5 if ui_name == "TownHallUI" else 0
		_expect(
			int(ui.call("get_building_button_count")) == expected_building_actions,
			"%s must expose only building actions owned by its current view." % ui_name
		)
		_expect(
			not String(ui.call("get_resource_text")).is_empty(),
			"%s must visibly show permanent resources." % ui_name
		)
		if ui_name == "PlayerBlacksmithUI":
			_expect(
				int(ui.call("get_equipment_button_count")) == 10,
				"Player Blacksmith must show all ten fixed equipment items."
			)
		ui.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
