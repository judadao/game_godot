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

	var inventory: RefCounted = game.get("inventory_manager")
	var town: RefCounted = game.get("town_manager")
	var forge: RefCounted = game.get("forge_service")
	var meta: MetaState = game.get("meta_state")
	var save_spy := InMemorySaveService.new()
	game.set("save_service", save_spy)
	town.call("apply_dict", {"building_levels": {"blacksmith": 0, "market": 0}})
	var clean_resources: Dictionary = {}
	for resource_id in inventory.call("get_resource_ids"):
		clean_resources[String(resource_id)] = 5000
	inventory.call("apply_dict", {"resources": clean_resources})
	_expect(
		bool(town.call("upgrade_building", &"blacksmith")),
		"Forge integration fixture must unlock workshop Tier 1."
	)
	_expect(
		bool(town.call("upgrade_building", &"market")),
		"Forge integration fixture must expand the market before selling equipment."
	)
	game.call("_refresh_forge_progression")
	_expect(
		int(forge.call("get_sale_shelf_capacity")) == 2,
		"Market Level 1 must unlock furniture without granting free counter space."
	)
	_expect(
		float((forge.call(
			"get_sale_preview", &"resource", &"autumn_wood", &"common", &"luxury"
		) as Dictionary).get("sale_chance", 0.0)) > 0.0,
		"Market decoration upgrades must establish some demand for premium prices."
	)
	_expect(
		bool(forge.call("purchase_market_fixture", &"cedar_display").get("ok", false))
			and int(forge.call("get_sale_shelf_capacity")) == 3,
		"An eligible purchased display must expand the workshop to three sale shelves."
	)

	for offer_id in [
		&"tool_forging_hammer",
		&"equipment_blueprint_hunter_bow",
		&"sword_soul_blueprint_flame_imbue",
	]:
		var purchase := forge.call("purchase_offer", offer_id, 1) as Dictionary
		_expect(
			bool(purchase.get("ok", false)),
			"Forge integration must purchase %s." % offer_id
		)

	game.call("_open_town_service_ui", &"player_blacksmith")
	await process_frame
	var ui := game.call("get_open_ui", "PlayerBlacksmithUI") as Control
	_expect(ui != null, "Player workshop must open for the integrated forge flow.")
	if ui == null:
		game.queue_free()
		await process_frame
		quit(1)
		return
	_expect(
		int(ui.call("get_equipment_button_count")) == 2,
		"Owned Tier 1 equipment and Sword Soul blueprints must become forge recipes."
	)

	game.call("_on_blacksmith_craft_requested", &"forge_hunter_bow", ui)
	_expect(
		int(inventory.call("get_equipment_count", &"hunter_bow")) == 1,
		"Forging an equipment blueprint must create crafted inventory."
	)

	var sword_soul_count_before := _card_count(meta, &"flame_imbue")
	game.call("_on_blacksmith_craft_requested", &"forge_flame_imbue", ui)
	_expect(
		_card_count(meta, &"flame_imbue") == sword_soul_count_before + 1,
		"Forging a Sword Soul blueprint must create a persistent card instance."
	)
	game.call("_on_blacksmith_upgrade_sword_soul_requested", &"flame_imbue", ui)
	_expect(
		_highest_card_level(meta, &"flame_imbue") == 2,
		"Player workshop must upgrade a forged Sword Soul."
	)

	game.call(
		"_on_blacksmith_list_for_sale_requested",
		&"equipment",
		&"hunter_bow",
		inventory.call("get_highest_equipment_quality", &"hunter_bow"),
		&"quick",
		0,
		ui
	)
	_expect(
		not (inventory.call("get_sale_slot") as Dictionary).is_empty(),
		"Crafted equipment must move into the persistent sales-table escrow."
	)
	var gold_before_sale := int(inventory.call("get_resource_amount", &"gold"))
	forge.call("set_random_seed", 1)
	game.call("_on_market_customer_purchase_check_requested", 0, ui)
	_expect(
		(inventory.call("get_sale_slot") as Dictionary).is_empty(),
		"Customer checkout must clear the sales table."
	)
	_expect(
		int(inventory.call("get_resource_amount", &"gold")) > gold_before_sale,
		"Customer checkout must add gold."
	)
	_expect(
		not save_spy.saved_payload.is_empty()
			and (
				save_spy.saved_payload.get("inventory_state", {}) as Dictionary
			).has("owned_blueprints"),
		"Forge actions must immediately persist blueprint and inventory state."
	)

	game.call("close_ui", ui)
	await process_frame
	town.call("apply_dict", {"building_levels": {"market": 0}})
	save_spy.saved_payload.clear()
	game.call("_open_town_service_ui", &"town_hall")
	await process_frame
	var hall_ui := game.call("get_open_ui", "TownHallUI") as Control
	_expect(hall_ui != null, "Town Hall must open for integrated development management.")
	if hall_ui != null:
		hall_ui.call("select_upgrade_building", &"market")
		var upgraded := bool(hall_ui.call("request_upgrade"))
		_expect(upgraded, "Town Hall must complete the selected market project.")
		_expect(
			int(town.call("get_building_level", &"market")) == 1
				and not save_spy.saved_payload.is_empty(),
			"Town Hall upgrades must persist immediately through Game authority."
		)
		var discounted_offers := forge.call("get_shop_offers", &"material_store") as Array
		var discounted_wood := _find_offer(discounted_offers, &"material_wood_bundle")
		var base_wood := game.get("forge_catalog").call(
			"get_offer", &"material_wood_bundle"
		) as Dictionary
		_expect(
			int(discounted_wood.get("price", 0)) < int(base_wood.get("price", 0)),
			"A persisted market upgrade must immediately refresh live forge prices."
		)
		var current_map := game.get("current_map") as Node
		var modular_visuals := current_map.get_node_or_null(
			"ParallaxBackground/ModularVisuals"
		) if current_map != null else null
		var market_visual := _find_object_visual(
			modular_visuals,
			"equipment_blueprint_shop"
		)
		_expect(
			market_visual != null
				and int(market_visual.get_meta("town_upgrade_level", -1)) == 1,
			"Town upgrades must immediately project onto the authoritative modular building."
		)

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _card_count(meta: MetaState, card_id: StringName) -> int:
	var count := 0
	for instance in meta.selected_card_instances:
		if StringName(instance.card_id) == card_id:
			count += 1
	return count


func _highest_card_level(meta: MetaState, card_id: StringName) -> int:
	var level := 0
	for instance in meta.selected_card_instances:
		if StringName(instance.card_id) == card_id:
			level = maxi(level, int(instance.level))
	return level


func _find_offer(offers: Array, offer_id: StringName) -> Dictionary:
	for offer_variant in offers:
		var offer := offer_variant as Dictionary
		if StringName(offer.get("id", "")) == offer_id:
			return offer
	return {}


func _find_object_visual(root_node: Node, object_id: String) -> Node:
	if root_node == null:
		return null
	if String(root_node.get_meta("object_id", "")) == object_id:
		return root_node
	for child in root_node.get_children():
		var found := _find_object_visual(child, object_id)
		if found != null:
			return found
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
