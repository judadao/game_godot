extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")

class InMemorySaveService:
	extends SaveService

	var saved_payload: Dictionary = {}

	func save_meta(_path: String, data: Dictionary) -> bool:
		saved_payload = data.duplicate(true)
		return true


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var town := game.get("current_map") as Node
	var player := game.get("player") as Node
	var save_spy := InMemorySaveService.new()
	game.set("save_service", save_spy)
	var contracts := {
		"MaterialYard": {"ui": "MaterialYardUI", "context": &"material_yard"},
		"PlayerBlacksmith": {"ui": "PlayerBlacksmithUI", "context": &"player_blacksmith"},
		"TownHall": {"ui": "TownHallUI", "context": &"town_hall"},
		"SwordSoulShop": {"ui": "ShopUI", "context": &"sword_soul_shop"},
		"EquipmentBlueprintShop": {
			"ui": "ShopUI",
			"context": &"equipment_blueprint_shop",
		},
		"FarEastResidence": {"ui": "TownResidenceUI", "context": &"far_east_residence"},
	}
	var material_yard := town.get_node("BuildingEntrances/MaterialYard")
	var player_blacksmith := town.get_node("BuildingEntrances/PlayerBlacksmith")
	game.call("_on_interaction_available", material_yard, player)
	game.call("_on_interaction_available", player_blacksmith, player)
	(player as Node2D).global_position.x = 355.0
	_expect(
		game.call("_nearest_interaction_candidate") == material_yard,
		"Shared foundation boundary must select the nearest Material Yard."
	)
	(player as Node2D).global_position.x = 400.0
	_expect(
		game.call("_nearest_interaction_candidate") == player_blacksmith,
		"Shared foundation boundary must select the nearest Player Blacksmith."
	)
	game.call("_on_interaction_unavailable", material_yard, player)
	game.call("_on_interaction_unavailable", player_blacksmith, player)
	(player as Node2D).global_position = Vector2(220, 702)

	for entrance_name in contracts:
		var contract: Dictionary = contracts[entrance_name]
		var entrance := town.get_node_or_null("BuildingEntrances/%s" % entrance_name)
		_expect(entrance != null, "%s building entrance must exist." % entrance_name)
		if entrance == null:
			continue
		game.call("_on_interaction_available", entrance, player)
		var prompt_label := game.get("hud").get_node(
			"InteractionPanel/PromptRow/PromptText"
		) as Label
		_expect(
			prompt_label.text == "Open",
			"%s prompt must show only the action because its building label is already visible."
			% entrance_name
		)
		game.call("_try_interact")
		await process_frame
		await process_frame

		var ui_name := String(contract["ui"])
		var ui := game.call("get_open_ui", ui_name) as Control
		_expect(ui != null, "%s entrance must open %s." % [entrance_name, ui_name])
		_expect(
			game.call("get_open_ui", "DialogueUI") == null,
			"%s entrance must not route through NPC dialogue." % entrance_name
		)
		if ui != null and ui.has_method("get_context_id"):
			_expect(
				String(ui.call("get_context_id")) == String(contract["context"]),
				"%s UI must receive its building context." % entrance_name
			)
		if ui_name in ["MaterialYardUI", "PlayerBlacksmithUI", "TownHallUI"] and ui != null:
			var expected_button_count := 1 if ui_name == "TownHallUI" else 0
			_expect(
				int(ui.call("get_building_button_count")) == expected_button_count,
				"%s must expose only controls owned by its current service." % entrance_name
			)
		if entrance_name == "MaterialYard" and ui != null:
			var inventory_manager: RefCounted = game.get("inventory_manager")
			for resource_id in inventory_manager.call("get_resource_ids"):
				inventory_manager.call("set_resource_amount", resource_id, 5000)
			var wood_before := int(
				inventory_manager.call("get_resource_amount", &"autumn_wood")
			)
			game.call(
				"_on_material_offer_requested",
				&"material_wood_bundle",
				1,
				ui
			)
			_expect(
				int(inventory_manager.call("get_resource_amount", &"autumn_wood"))
					== wood_before + 10,
				"Material Yard must deliver purchased forge materials."
			)
			var cancel_event := InputEventAction.new()
			cancel_event.action = &"ui_cancel"
			cancel_event.pressed = true
			game.call("_input", cancel_event)
			await process_frame
			await process_frame
			var meta_state: RefCounted = game.get("meta_state")
			_expect(
				game.call("get_open_ui", "MaterialYardUI") == null,
				"Game ui_cancel must close the active building screen."
			)
			_expect(
				int(
					(meta_state.get("inventory_state") as Dictionary)
						.get("resources", {})
						.get("autumn_wood", -1)
				) == wood_before + 10,
				"Material purchases must synchronize to meta inventory state."
			)
			_expect(
				not save_spy.saved_payload.is_empty(),
				"Game ui_cancel must request a meta save without touching developer user data."
			)
			_expect(
				not paused,
				"Game ui_cancel must restore gameplay pause state after closing a building screen."
			)
			ui = null
		if entrance_name == "SwordSoulShop":
			var catalog := game.call("_catalog_for_shop", &"sword_soul_shop") as Array
			_expect(
				not catalog.is_empty()
					and String((catalog[0] as Dictionary).get("product_kind", ""))
						== "blueprint"
					and String((catalog[0] as Dictionary).get("target_kind", ""))
						== "sword_soul",
				"Sword Soul Shop must expose permanent Sword Soul blueprints."
			)
		if entrance_name == "PlayerBlacksmith" and ui != null:
			_expect(
				ui.has_method("select_blacksmith_service"),
				"Player Blacksmith UI must own its combined services."
			)
			ui.call("select_blacksmith_service", &"sales_table")
			_expect(
				String(ui.call("get_blacksmith_service")) == "sales_table",
				"Player Blacksmith must expose its crafted-equipment sales table."
			)
		if entrance_name == "EquipmentBlueprintShop":
			var catalog := game.call(
				"_catalog_for_shop",
				&"equipment_blueprint_shop"
			) as Array
			_expect(
				_catalog_has_product(catalog, &"equipment")
					and _catalog_has_product(catalog, &"blueprint", &"equipment"),
				"The equipment residence must sell basic gear and advanced blueprints."
			)
		if ui_name == "TownResidenceUI" and ui != null:
			var close_button := ui.get_node(
				"Shade/Center/ResidencePanel/PanelMargin/Content/CloseButton"
			) as Button
			close_button.pressed.emit()
			await process_frame
			_expect(
				game.call("get_open_ui", "TownResidenceUI") == null,
				"%s residence close button must close its UI." % entrance_name
			)
			ui = null
		if is_instance_valid(ui):
			game.call("close_ui", ui)
		game.call("_on_interaction_unavailable", entrance, player)
		await process_frame

	for npc in town.get_node("NPCs").get_children():
		_expect(not npc.is_in_group("Interactives"), "%s must be display-only." % npc.name)
	_expect(
		not town.has_node("BuildingEntrances/BlueprintResearch")
			and not town.has_node("BuildingEntrances/SoulRefinery"),
		"East residences must not retain their former functional identities."
	)

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _catalog_has_product(
	catalog: Array,
	product_kind: StringName,
	target_kind: StringName = StringName()
) -> bool:
	for item_variant in catalog:
		var item := item_variant as Dictionary
		if StringName(item.get("product_kind", "")) != product_kind:
			continue
		if target_kind.is_empty() or StringName(item.get("target_kind", "")) == target_kind:
			return true
	return false
