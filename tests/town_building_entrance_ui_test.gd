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
		"EastResidence": {"ui": "TownResidenceUI", "context": &"east_residence"},
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
			_expect(
				int(ui.call("get_building_button_count")) == 1,
				"%s must focus its own building upgrade controls." % entrance_name
			)
		if entrance_name == "MaterialYard" and ui != null:
			var inventory_manager: RefCounted = game.get("inventory_manager")
			var town_manager: RefCounted = game.get("town_manager")
			for resource_id in inventory_manager.call("get_resource_ids"):
				inventory_manager.call("set_resource_amount", resource_id, 5000)
			_expect(
				bool(ui.call("request_upgrade")),
				"Material Yard fixture must change progression before the production close path."
			)
			var upgraded_level := int(town_manager.call("get_building_level", &"workshop"))
			var cancel_event := InputEventAction.new()
			cancel_event.action = &"ui_cancel"
			cancel_event.pressed = true
			game.call("_input", cancel_event)
			await process_frame
			await process_frame
			var meta_state: RefCounted = game.get("meta_state")
			var saved_town := meta_state.get("town_state") as Dictionary
			var saved_levels := saved_town.get("building_levels", {}) as Dictionary
			_expect(
				game.call("get_open_ui", "MaterialYardUI") == null,
				"Game ui_cancel must close the active building screen."
			)
			_expect(
				int(saved_levels.get("workshop", -1)) == upgraded_level,
				"Game ui_cancel must synchronize changed building progression to meta state."
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
				not catalog.is_empty() and String((catalog[0] as Dictionary).get("id", "")) == "soul_edge",
				"Sword Soul Shop must expose its own shop catalog."
			)
		if entrance_name == "PlayerBlacksmith" and ui != null:
			_expect(
				ui.has_method("select_blacksmith_service"),
				"Player Blacksmith UI must own its combined services."
			)
			ui.call("select_blacksmith_service", &"soul_refinery")
			_expect(
				String(ui.call("get_blacksmith_service")) == "soul_refinery",
				"Player Blacksmith must expose Soul Refinery service."
			)
			ui.call("request_blueprint_research")
			await process_frame
			await process_frame
			var deck_ui := game.call("get_open_ui", "DeckBuilderUI") as Control
			_expect(deck_ui != null, "Player Blacksmith must open Blueprint Research.")
			_expect(
				deck_ui != null and String(deck_ui.call("get_context_id")) == "blueprint_research",
				"Blacksmith Blueprint Research must preserve its UI context."
			)
			_expect(
				deck_ui != null
					and (deck_ui.find_child("Title", true, false) as Label).text
						== "DESIGN RESEARCH"
					and (deck_ui.find_child("Footer", true, false) as Container)
						.find_children("*", "Button", true, false)
						.any(func(button: Button) -> bool: return button.text == "SAVE DESIGN"),
				"Blacksmith research must use save-design language instead of expedition language."
			)
			if deck_ui != null:
				deck_ui.emit_signal(
					"loadout_confirmed",
					deck_ui.call("get_selected_deck"),
					deck_ui.call("get_auto_attack_card_id")
				)
			await process_frame
			await process_frame
			_expect(not bool(game.get("run_state").active), "Blacksmith research must not start a run.")
			_expect(
				game.get("current_map") == town,
				"Blacksmith research must keep the player in Town."
			)
			_expect(
				game.call("get_open_ui", "DeckBuilderUI") == null,
				"Blacksmith research must save and close after confirmation."
			)
			ui = null
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
