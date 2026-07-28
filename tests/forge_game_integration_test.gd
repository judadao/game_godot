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
	for resource_id in inventory.call("get_resource_ids"):
		inventory.call("set_resource_amount", resource_id, 5000)
	_expect(
		bool(town.call("upgrade_building", &"blacksmith")),
		"Forge integration fixture must unlock workshop Tier 1."
	)
	game.call("_refresh_forge_progression")

	for offer_id in [
		&"tool_forging_hammer",
		&"equipment_blueprint_iron_sword",
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

	game.call("_on_blacksmith_craft_requested", &"forge_iron_sword", ui)
	_expect(
		int(inventory.call("get_equipment_count", &"iron_sword")) == 1,
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

	game.call("_on_blacksmith_list_for_sale_requested", &"iron_sword", ui)
	_expect(
		not (inventory.call("get_sale_slot") as Dictionary).is_empty(),
		"Crafted equipment must move into the persistent sales-table escrow."
	)
	var gold_before_sale := int(inventory.call("get_resource_amount", &"gold"))
	game.call("_on_blacksmith_resolve_sale_requested", ui)
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
