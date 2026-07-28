extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")

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
	var contracts := {
		"MaterialYard": {"ui": "TownProgressUI", "context": &"material_yard"},
		"PlayerBlacksmith": {"ui": "TownProgressUI", "context": &"player_blacksmith"},
		"TownHall": {"ui": "TownProgressUI", "context": &"town_hall"},
		"SwordSoulShop": {"ui": "ShopUI", "context": &"sword_soul_shop"},
		"BlueprintResearch": {"ui": "DeckBuilderUI", "context": &"blueprint_research"},
		"SoulRefinery": {"ui": "TownProgressUI", "context": &"soul_refinery"},
	}
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
		if ui_name == "TownProgressUI" and ui != null:
			_expect(
				int(ui.call("get_building_button_count")) == 1,
				"%s must focus its own building upgrade controls." % entrance_name
			)
		if entrance_name == "SwordSoulShop":
			var catalog := game.call("_catalog_for_shop", &"sword_soul_shop") as Array
			_expect(
				not catalog.is_empty() and String((catalog[0] as Dictionary).get("id", "")) == "soul_edge",
				"Sword Soul Shop must expose its own shop catalog."
			)
		if entrance_name == "BlueprintResearch" and ui != null:
			ui.emit_signal(
				"loadout_confirmed",
				ui.call("get_selected_deck"),
				ui.call("get_auto_attack_card_id")
			)
			await process_frame
			await process_frame
			_expect(not bool(game.get("run_state").active), "Blueprint Research must not start a run.")
			_expect(
				game.get("current_map") == town,
				"Blueprint Research must keep the player in Town."
			)
			_expect(
				game.call("get_open_ui", "DeckBuilderUI") == null,
				"Blueprint Research must save and close after confirmation."
			)
			ui = null
		if is_instance_valid(ui):
			game.call("close_ui", ui)
		game.call("_on_interaction_unavailable", entrance, player)
		await process_frame

	for npc in town.get_node("NPCs").get_children():
		_expect(not npc.is_in_group("Interactives"), "%s must be display-only." % npc.name)

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
