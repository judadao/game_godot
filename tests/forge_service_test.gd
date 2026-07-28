extends SceneTree

const ForgeCatalogScript = preload("res://scripts/systems/forge_catalog.gd")
const ForgeServiceScript = preload("res://scripts/systems/forge_service.gd")
const InventoryManagerScript = preload("res://scripts/systems/inventory_manager.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_offer_purchase_is_gated_atomic_and_persistent()
	_test_equipment_and_sword_soul_crafting()
	_test_single_sales_table_slot_resolves_once()
	_test_inventory_legacy_migration_and_round_trip()
	quit(0 if _failures == 0 else 1)


func _test_offer_purchase_is_gated_atomic_and_persistent() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 1000)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(0, 1)

	var locked_snapshot: Dictionary = inventory.to_dict()
	var locked_result: Dictionary = service.purchase_offer(&"tool_arcane_calipers")
	_expect(not bool(locked_result.get("ok", false)), "Locked tool purchase must fail.")
	_expect(
		inventory.to_dict() == locked_snapshot,
		"Locked offer failure must preserve the complete inventory snapshot."
	)

	var material_result: Dictionary = service.purchase_offer(&"material_wood_bundle", 2)
	_expect(bool(material_result.get("ok", false)), "Unlocked material purchase must succeed.")
	_expect(
		inventory.get_resource_amount(&"autumn_wood")
			== int((locked_snapshot.get("resources", {}) as Dictionary).get("autumn_wood", 0)) + 20,
		"Buying two wood bundles must grant the exact catalog quantity."
	)
	var hammer_result: Dictionary = service.purchase_offer(&"tool_forging_hammer")
	_expect(bool(hammer_result.get("ok", false)), "Unlocked tool purchase must succeed.")
	_expect(inventory.owns_tool(&"forging_hammer"), "Purchased tool ownership must persist.")
	var duplicate_snapshot: Dictionary = inventory.to_dict()
	_expect(
		not bool(service.purchase_offer(&"tool_forging_hammer").get("ok", false)),
		"A unique tool cannot be purchased twice."
	)
	_expect(
		inventory.to_dict() == duplicate_snapshot,
		"Duplicate purchase rejection must not spend gold."
	)

	var restored = InventoryManagerScript.new()
	restored.apply_dict(inventory.to_dict())
	_expect(restored.owns_tool(&"forging_hammer"), "Tool ownership must round-trip.")


func _test_equipment_and_sword_soul_crafting() -> void:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		inventory.set_resource_amount(resource_id, 1000)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 1)

	_expect(
		bool(service.purchase_offer(&"equipment_blueprint_iron_sword").get("ok", false)),
		"Equipment blueprint purchase must succeed."
	)
	_expect(
		bool(service.purchase_offer(&"tool_forging_hammer").get("ok", false)),
		"Basic tool purchase must succeed."
	)
	var recipes: Array = service.get_available_recipes()
	_expect(
		_has_entry(recipes, &"forge_iron_sword"),
		"Owned blueprint, tool, and blacksmith level must expose the recipe."
	)
	var insufficient = InventoryManagerScript.new()
	insufficient.set_resource_amount(&"gold", 1000)
	insufficient.set_resource_amount(&"autumn_wood", 0)
	insufficient.set_resource_amount(&"stone", 0)
	insufficient.grant_blueprint(&"iron_sword_blueprint")
	insufficient.grant_tool(&"forging_hammer")
	var insufficient_service = ForgeServiceScript.new(ForgeCatalogScript.new(), insufficient)
	insufficient_service.set_progression_levels(3, 1)
	var insufficient_snapshot: Dictionary = insufficient.to_dict()
	_expect(
		not bool(insufficient_service.craft(&"forge_iron_sword").get("ok", false)),
		"An unaffordable recipe must be rejected."
	)
	_expect(
		insufficient.to_dict() == insufficient_snapshot,
		"Failed crafting must preserve resources and equipment exactly."
	)
	var before_count: int = inventory.get_equipment_count(&"iron_sword")
	var crafted: Dictionary = service.craft(&"forge_iron_sword", 2)
	_expect(bool(crafted.get("ok", false)), "Affordable equipment crafting must succeed.")
	_expect(
		inventory.get_equipment_count(&"iron_sword") == before_count + 2,
		"Equipment crafting must add the exact requested count."
	)

	_expect(
		bool(service.purchase_offer(&"sword_soul_blueprint_flame_imbue").get("ok", false)),
		"Sword-soul blueprint purchase must succeed."
	)
	var soul_result: Dictionary = service.craft(&"forge_flame_imbue")
	_expect(bool(soul_result.get("ok", false)), "Sword-soul crafting validation must succeed.")
	_expect(
		String(soul_result.get("intent", "")) == "grant_sword_soul"
			and String(soul_result.get("result_id", "")) == "flame_imbue"
			and int(soul_result.get("quantity", 0)) == 1,
		"Sword-soul crafting must return a deterministic MetaState intent payload."
	)


func _test_single_sales_table_slot_resolves_once() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 0)
	inventory.add_equipment_count(&"iron_sword", 2)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	var listed: Dictionary = service.list_for_sale(&"iron_sword", 1, 45)
	_expect(bool(listed.get("ok", false)), "One crafted item must be listable.")
	_expect(
		inventory.get_equipment_count(&"iron_sword") == 1,
		"Listing must escrow the exact equipment quantity."
	)
	_expect(
		not bool(service.list_for_sale(&"iron_sword", 1, 45).get("ok", false)),
		"A second listing must be rejected while the one sales slot is occupied."
	)
	var restored_inventory = InventoryManagerScript.new()
	restored_inventory.apply_dict(inventory.to_dict())
	var restored_service = ForgeServiceScript.new(ForgeCatalogScript.new(), restored_inventory)
	var restored_slot := restored_inventory.get_sale_slot() as Dictionary
	_expect(
		String(restored_slot.get("item_id", "")) == "iron_sword"
			and int(restored_slot.get("quantity", 0)) == 1,
		"An occupied sale slot must survive Inventory DTO round-trip."
	)
	var resolved: Dictionary = restored_service.resolve_sale()
	_expect(bool(resolved.get("ok", false)), "The occupied sale slot must resolve.")
	_expect(
		int(resolved.get("gold", 0)) == 45
			and restored_inventory.get_resource_amount(&"gold") == 45,
		"Resolving a sale must grant the exact escrow value."
	)
	var resolved_snapshot: Dictionary = restored_inventory.to_dict()
	_expect(
		not bool(restored_service.resolve_sale().get("ok", false)),
		"An empty sale slot cannot resolve twice."
	)
	_expect(
		restored_inventory.to_dict() == resolved_snapshot,
		"Duplicate sale resolution must preserve inventory and gold."
	)


func _test_inventory_legacy_migration_and_round_trip() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.apply_dict({
		"resources": {"gold": 77},
		"owned_equipment": ["iron_sword"],
		"equipment_levels": {"iron_sword": 2},
		"owned_blueprints": ["iron_sword_blueprint"],
		"owned_tools": ["forging_hammer"],
	})
	_expect(
		inventory.get_equipment_count(&"iron_sword") == 1,
		"Legacy owned_equipment must migrate to one equipment count."
	)
	_expect(inventory.get_equipment_level(&"iron_sword") == 2, "Legacy level must survive migration.")
	_expect(inventory.owns_blueprint(&"iron_sword_blueprint"), "Blueprint ownership must apply.")
	_expect(inventory.owns_tool(&"forging_hammer"), "Tool ownership must apply.")

	var dto: Dictionary = inventory.to_dict()
	_expect(
		int((dto.get("equipment_counts", {}) as Dictionary).get("iron_sword", 0)) == 1,
		"Current DTO must persist equipment counts."
	)
	var restored = InventoryManagerScript.new()
	restored.apply_dict(dto)
	_expect(restored.to_dict() == dto, "Current Inventory DTO must round-trip idempotently.")


func _has_entry(entries: Array, entry_id: StringName) -> bool:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if StringName(entry.get("id", "")) == entry_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
