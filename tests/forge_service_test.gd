extends SceneTree

const ForgeCatalogScript = preload("res://scripts/systems/forge_catalog.gd")
const ForgeServiceScript = preload("res://scripts/systems/forge_service.gd")
const InventoryManagerScript = preload("res://scripts/systems/inventory_manager.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_offer_purchase_is_gated_atomic_and_persistent()
	_test_basic_equipment_purchase_and_advanced_purchase_rejection()
	_test_equipment_and_sword_soul_crafting()
	_test_single_sales_table_slot_resolves_once()
	_test_market_supports_multiple_persistent_sale_shelves()
	_test_market_fixture_gates_capacity_and_automatic_customers()
	_test_material_quality_directly_changes_forge_outcomes()
	_test_equipment_quality_scales_sale_value()
	_test_material_quality_sales_and_market_equipment_unlock()
	_test_blueprint_proficiency_awakens_legendary_quality()
	_test_town_economy_modifiers_affect_all_forge_transactions()
	_test_inventory_legacy_migration_and_round_trip()
	quit(0 if _failures == 0 else 1)


func _test_offer_purchase_is_gated_atomic_and_persistent() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 1000)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(0, 1)
	_expect(
		service.get_shop_offers(&"material_store", true).size()
			> service.get_shop_offers(&"material_store").size(),
		"Material Yard projection must retain locked stock for upgrade previews."
	)

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


func _test_basic_equipment_purchase_and_advanced_purchase_rejection() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 1000)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 3)
	var direct_result := service.purchase_offer(&"equipment_direct_iron_sword")
	_expect(bool(direct_result.get("ok", false)), "Basic equipment must be purchasable with gold.")
	_expect(
		inventory.get_equipment_count(&"iron_sword") == 1,
		"A direct equipment offer must grant the equipment, not a blueprint."
	)
	_expect(
		not inventory.purchase_equipment(&"focus_amulet"),
		"Advanced equipment must reject every direct-purchase path."
	)


func _test_equipment_and_sword_soul_crafting() -> void:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		inventory.set_resource_amount(resource_id, 1000)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 1, 1)

	_expect(
		bool(service.purchase_offer(&"equipment_blueprint_hunter_bow").get("ok", false)),
		"Equipment blueprint purchase must succeed."
	)
	_expect(
		bool(service.purchase_offer(&"tool_forging_hammer").get("ok", false)),
		"Basic tool purchase must succeed."
	)
	var recipes: Array = service.get_available_recipes()
	_expect(
		_has_entry(recipes, &"forge_hunter_bow"),
		"Owned blueprint, tool, and blacksmith level must expose the recipe."
	)
	var insufficient = InventoryManagerScript.new()
	insufficient.set_resource_amount(&"gold", 1000)
	insufficient.set_resource_amount(&"autumn_wood", 0)
	insufficient.set_resource_amount(&"stone", 0)
	insufficient.grant_blueprint(&"hunter_bow_blueprint")
	insufficient.grant_tool(&"forging_hammer")
	var insufficient_service = ForgeServiceScript.new(ForgeCatalogScript.new(), insufficient)
	insufficient_service.set_progression_levels(3, 1)
	var insufficient_snapshot: Dictionary = insufficient.to_dict()
	_expect(
		not bool(insufficient_service.craft(&"forge_hunter_bow").get("ok", false)),
		"An unaffordable recipe must be rejected."
	)
	_expect(
		insufficient.to_dict() == insufficient_snapshot,
		"Failed crafting must preserve resources and equipment exactly."
	)
	var before_count: int = inventory.get_equipment_count(&"hunter_bow")
	var gold_before_craft: int = inventory.get_resource_amount(&"gold")
	var recipe := ForgeCatalogScript.new().get_recipe(&"forge_hunter_bow")
	var crafted: Dictionary = service.craft(&"forge_hunter_bow", 2)
	_expect(bool(crafted.get("ok", false)), "Affordable equipment crafting must succeed.")
	_expect(
		inventory.get_equipment_count(&"hunter_bow") == before_count + 2,
		"Equipment crafting must add the exact requested count."
	)
	_expect(
		inventory.get_resource_amount(&"gold")
			== gold_before_craft - int(recipe.get("processing_fee", 0)) * 2,
		"Crafting must charge the recipe processing fee for every forged item."
	)
	_expect(
		int((crafted.get("quality_counts", {}) as Dictionary).values().reduce(
			func(total: int, count: Variant) -> int: return total + int(count), 0
		)) == 2
			and String(crafted.get("material_tier", "")) == "normal",
		"Craft results must expose their equipment quality and material tier."
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
	service.set_progression_levels(0, 0, 1)
	service.set_sale_shelf_capacity(1)
	var expected_sale_price := int(inventory.get_equipment(&"iron_sword").get("base_sale_value", 0))
	var listed: Dictionary = service.list_for_sale(&"iron_sword", 1)
	_expect(bool(listed.get("ok", false)), "One crafted item must be listable.")
	_expect(
		inventory.get_equipment_count(&"iron_sword") == 1,
		"Listing must escrow the exact equipment quantity."
	)
	_expect(
		not bool(service.list_for_sale(&"iron_sword", 1).get("ok", false)),
		"A second listing must be rejected while the one sales slot is occupied."
	)
	var restored_inventory = InventoryManagerScript.new()
	restored_inventory.apply_dict(inventory.to_dict())
	var restored_service = ForgeServiceScript.new(ForgeCatalogScript.new(), restored_inventory)
	restored_service.set_progression_levels(0, 0, 1)
	restored_service.set_sale_shelf_capacity(1)
	var restored_slot := restored_inventory.get_sale_slot() as Dictionary
	_expect(
		String(restored_slot.get("item_id", "")) == "iron_sword"
			and int(restored_slot.get("quantity", 0)) == 1,
		"An occupied sale slot must survive Inventory DTO round-trip."
	)
	var resolved: Dictionary = restored_service.resolve_sale()
	_expect(bool(resolved.get("ok", false)), "The occupied sale slot must resolve.")
	_expect(
		int(resolved.get("gold", 0)) == expected_sale_price
			and restored_inventory.get_resource_amount(&"gold") == expected_sale_price,
		"Resolving a sale must grant the equipment catalog's quality-based value."
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


func _test_market_supports_multiple_persistent_sale_shelves() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 0)
	inventory.add_equipment_count(&"iron_sword", 4)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(0, 0, 1)
	service.set_sale_shelf_capacity(3)
	for shelf_index in 3:
		var listed := service.list_for_sale(
			&"equipment", &"iron_sword", &"common", 1, &"fair", shelf_index
		) as Dictionary
		_expect(
			bool(listed.get("ok", false))
				and int(listed.get("shelf_index", -1)) == shelf_index,
			"Each unlocked market shelf must accept its own independent listing."
		)
	_expect(
		not bool(service.list_for_sale(
			&"equipment", &"iron_sword", &"common", 1, &"fair", 3
		).get("ok", false)),
		"Listing outside the unlocked shelf capacity must be rejected."
	)
	var restored_inventory = InventoryManagerScript.new()
	restored_inventory.apply_dict(inventory.to_dict())
	var restored_service = ForgeServiceScript.new(
		ForgeCatalogScript.new(), restored_inventory
	)
	restored_service.set_progression_levels(0, 0, 1)
	restored_service.set_sale_shelf_capacity(3)
	_expect(
		(restored_inventory.get_sale_slots() as Array).size() == 3,
		"Every occupied sale shelf must survive the inventory save round-trip."
	)
	var resolved := restored_service.resolve_sale(1) as Dictionary
	var remaining_slots := restored_inventory.get_sale_slots() as Array
	_expect(
		bool(resolved.get("ok", false))
			and (remaining_slots[0] as Dictionary).has("item_id")
			and (remaining_slots[1] as Dictionary).is_empty()
			and (remaining_slots[2] as Dictionary).has("item_id"),
		"Resolving one shelf must not clear or pay out the other shelf listings."
	)


func _test_market_fixture_gates_capacity_and_automatic_customers() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 1000)
	inventory.set_resource_amount(&"autumn_wood", 100)
	inventory.set_resource_amount(&"stone", 100)
	inventory.set_resource_amount(&"autumn_core", 100)
	inventory.add_equipment_count(&"iron_sword", 2)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(0, 0, 0)
	_expect(
		service.get_sale_shelf_capacity() == 2,
		"The basic shop must begin with only two physical counter positions."
	)
	_expect(
		not bool(service.purchase_market_fixture(&"cedar_display").get("ok", false)),
		"A stronger counter must remain unavailable before the shop building is upgraded."
	)
	service.set_progression_levels(0, 0, 1)
	_expect(
		service.get_sale_shelf_capacity() == 2,
		"A building upgrade alone must not create additional counter furniture."
	)
	var fixture_purchase := service.purchase_market_fixture(&"cedar_display") as Dictionary
	_expect(
		bool(fixture_purchase.get("ok", false))
			and service.get_sale_shelf_capacity() == 3
			and inventory.owns_tool(&"cedar_display"),
		"Purchasing an eligible fixture must persist ownership and expand actual shelf capacity."
	)
	var quick_preview := service.get_sale_preview(
		&"equipment", &"iron_sword", &"common", &"quick"
	) as Dictionary
	var luxury_preview := service.get_sale_preview(
		&"equipment", &"iron_sword", &"common", &"luxury"
	) as Dictionary
	_expect(
		int(quick_preview.get("unit_price", 0)) < int(luxury_preview.get("unit_price", 0))
			and float(quick_preview.get("sale_chance", 0.0))
				> float(luxury_preview.get("sale_chance", 1.0)),
		"Low prices must trade unit profit for a much higher automatic purchase chance."
	)
	service.set_random_seed(1)
	_expect(
		bool(service.list_for_sale(
			&"equipment", &"iron_sword", &"common", 1, &"luxury", 0
		).get("ok", false)),
		"The automatic-customer fixture must accept a luxury listing."
	)
	var visit := service.try_customer_purchase(0) as Dictionary
	_expect(
		StringName(visit.get("code", "")) == &"customer_passed"
			and not (inventory.get_sale_slot(0) as Dictionary).is_empty(),
		"A customer rejecting an expensive item must leave it stocked for a later visitor."
	)
	service.set_economy_modifiers(0.0, 1.0, 0.0, 1.0, 0.0, 0.50)
	var improved_preview := service.get_sale_preview(
		&"equipment", &"iron_sword", &"common", &"luxury"
	) as Dictionary
	_expect(
		float(improved_preview.get("sale_chance", 0.0))
			> float(luxury_preview.get("sale_chance", 1.0)),
		"Shop-building and equipment bonuses must improve premium-price acceptance."
	)
	inventory.add_equipment_count(&"merchant_seal", 1, &"exceptional")
	_expect(
		inventory.equip(&"merchant_seal")
			and float(inventory.get_special_ability_totals().get(
				"market_customer_interest_bonus", 0.0
			)) > 0.0,
		"Equipping the Merchant Seal must expose its premium-customer interest bonus."
	)


func _test_material_quality_directly_changes_forge_outcomes() -> void:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		inventory.set_resource_amount(resource_id, 0)
	inventory.set_resource_amount(&"gold", 1000)
	inventory.add_resource(&"autumn_wood", 20, &"common")
	inventory.add_resource(&"stone", 10, &"common")
	inventory.add_resource(&"autumn_wood", 20, &"exceptional")
	inventory.add_resource(&"stone", 10, &"exceptional")
	inventory.grant_blueprint(&"hunter_bow_blueprint")
	inventory.grant_tool(&"forging_hammer")
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 1, 1)
	var common_preview := service.get_craft_preview(
		&"forge_hunter_bow", &"steady", &"common"
	) as Dictionary
	var exceptional_preview := service.get_craft_preview(
		&"forge_hunter_bow", &"steady", &"exceptional"
	) as Dictionary
	_expect(
		bool(exceptional_preview.get("materials_available", false))
			and float(exceptional_preview.get("success_chance", 0.0))
				> float(common_preview.get("success_chance", 0.0))
			and float((exceptional_preview.get("quality_chances", {}) as Dictionary).get(
				"exceptional", 0.0
			)) > float((common_preview.get("quality_chances", {}) as Dictionary).get(
				"exceptional", 0.0
			)),
		"Choosing exceptional materials must visibly improve success and output quality odds."
	)
	var common_wood_before := inventory.get_resource_quality_amount(
		&"autumn_wood", &"common"
	)
	var exceptional_wood_before := inventory.get_resource_quality_amount(
		&"autumn_wood", &"exceptional"
	)
	var crafted := service.craft(
		&"forge_hunter_bow", 1, &"steady", &"exceptional"
	) as Dictionary
	_expect(
		bool(crafted.get("ok", false))
			and StringName(crafted.get("material_quality", "")) == &"exceptional"
			and inventory.get_resource_quality_amount(&"autumn_wood", &"common")
				== common_wood_before
			and inventory.get_resource_quality_amount(&"autumn_wood", &"exceptional")
				< exceptional_wood_before,
		"Forge must consume the selected material-quality stacks instead of aggregate stock."
	)
func _test_equipment_quality_scales_sale_value() -> void:
	var inventory = InventoryManagerScript.new()
	var common := inventory.get_equipment(&"hunter_bow")
	var rare := inventory.get_equipment(&"apprentice_staff")
	var exceptional := inventory.get_equipment(&"focus_amulet")
	_expect(
		String(common.get("quality", "")) == "common"
			and String(rare.get("quality", "")) == "rare"
			and String(exceptional.get("quality", "")) == "exceptional",
		"Equipment must expose the common, rare, and exceptional quality ladder."
	)
	_expect(
		inventory.get_equipment_sale_value(&"hunter_bow", &"legendary")
			> inventory.get_equipment_sale_value(&"hunter_bow", &"exceptional"),
		"Awakened legendary equipment must sell for more than exceptional equipment."
	)
	_expect(
		int(common.get("base_sale_value", 0)) < int(rare.get("base_sale_value", 0))
			and int(rare.get("base_sale_value", 0)) < int(exceptional.get("base_sale_value", 0)),
		"Higher-quality equipment must have a higher catalog sale value."
	)
	inventory.add_equipment_count(&"hunter_bow", 1, &"common")
	_expect(inventory.equip(&"hunter_bow"), "Quality fixture equipment must equip.")
	inventory.add_equipment_count(&"hunter_bow", 1, &"legendary")
	_expect(
		inventory.get_equipped_quality(&"weapon") == &"legendary"
			and float(inventory.get_effect_totals().get("attack", 0.0)) > 3.0
			and float(inventory.get_special_ability_totals().get("card_damage_bonus", 0.0)) > 1.0,
		"A newly forged higher-quality copy must improve the equipped effects and numeric abilities."
	)


func _test_material_quality_sales_and_market_equipment_unlock() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.set_resource_amount(&"gold", 0)
	inventory.set_resource_amount(&"magic_shard", 0)
	_expect(
		inventory.add_resource(&"magic_shard", 2, &"rare"),
		"Monster materials must be storable as an explicit quality stack."
	)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(0, 0, 0)
	var candidates: Array = service.get_sale_candidates()
	_expect(
		_has_sale_candidate(candidates, &"resource", &"magic_shard", &"rare"),
		"A new market must let the player sell quality monster materials before forging unlocks."
	)
	var material_sale := service.list_for_sale(
		&"resource", &"magic_shard", &"rare", 1
	) as Dictionary
	_expect(bool(material_sale.get("ok", false)), "A quality material must be listable for sale.")
	var material_slot := inventory.get_sale_slot()
	_expect(
		StringName(material_slot.get("item_kind", "")) == &"resource"
			and StringName(material_slot.get("quality", "")) == &"rare",
		"Sales escrow must preserve material kind and quality."
	)
	var material_result := service.resolve_sale()
	_expect(
		bool(material_result.get("ok", false))
			and int(material_result.get("gold", 0))
				== inventory.get_resource_sale_value(&"magic_shard", &"rare"),
		"A rare material sale must pay its quality-adjusted value."
	)

	inventory.add_equipment_count(&"iron_sword", 1, &"common")
	var locked_sale := service.list_for_sale(
		&"equipment", &"iron_sword", &"common", 1
	) as Dictionary
	_expect(
		StringName(locked_sale.get("code", "")) == &"equipment_sales_locked",
		"Equipment sales must remain locked until the market is expanded."
	)
	service.set_progression_levels(0, 0, 1)
	_expect(
		bool(service.list_for_sale(
			&"equipment", &"iron_sword", &"common", 1
		).get("ok", false)),
		"The first market expansion must unlock equipment sales."
	)


func _test_blueprint_proficiency_awakens_legendary_quality() -> void:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		inventory.set_resource_amount(resource_id, 10000)
	inventory.grant_blueprint(&"hunter_bow_blueprint")
	inventory.grant_tool(&"forging_hammer")
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 3, 3)
	var initial_recipe := _find_entry(service.get_available_recipes(), &"forge_hunter_bow")
	var initial_chances := initial_recipe.get("quality_chances", {}) as Dictionary
	_expect(
		int(initial_recipe.get("proficiency_level", -1)) == 0
			and not bool(initial_recipe.get("blueprint_awakened", true))
			and is_zero_approx(float(initial_chances.get("legendary", 0.0))),
		"A new blueprint must begin at proficiency zero with legendary quality locked."
	)

	for _craft_index in 5:
		var crafted := service.craft(&"forge_hunter_bow") as Dictionary
		_expect(bool(crafted.get("ok", false)), "Proficiency setup crafts must succeed.")
	var proficiency := inventory.get_blueprint_proficiency(&"hunter_bow_blueprint")
	_expect(
		int(proficiency.get("level", 0)) == 5
			and bool(proficiency.get("awakened", false)),
		"Five successful crafts must trigger the protagonist's blueprint improvement awakening."
	)
	var awakened_recipe := _find_entry(service.get_available_recipes(), &"forge_hunter_bow")
	var awakened_chances := awakened_recipe.get("quality_chances", {}) as Dictionary
	_expect(
		bool(awakened_recipe.get("blueprint_awakened", false))
			and float(awakened_chances.get("legendary", 0.0)) > 0.0
			and float(awakened_chances.get("rare", 0.0))
				> float(initial_chances.get("rare", 0.0)),
		"Blueprint awakening must unlock legendary results and repeated crafting must improve rare odds."
	)
	var dto := inventory.to_dict()
	var restored = InventoryManagerScript.new()
	restored.apply_dict(dto)
	_expect(
		restored.get_blueprint_proficiency(&"hunter_bow_blueprint") == proficiency,
		"Blueprint proficiency and awakening must survive Inventory DTO round-trip."
	)


func _test_town_economy_modifiers_affect_all_forge_transactions() -> void:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		inventory.set_resource_amount(resource_id, 1000)
	inventory.grant_blueprint(&"hunter_bow_blueprint")
	inventory.grant_tool(&"forging_hammer")
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(2, 1, 1)
	service.set_economy_modifiers(0.10, 1.20, 0.10, 1.25)

	var offer := ForgeCatalogScript.new().get_offer(&"material_wood_bundle")
	var gold_before_purchase: int = inventory.get_resource_amount(&"gold")
	var wood_before_purchase: int = inventory.get_resource_amount(&"autumn_wood")
	var purchase: Dictionary = service.purchase_offer(&"material_wood_bundle")
	_expect(bool(purchase.get("ok", false)), "Discounted material purchase must succeed.")
	_expect(
		int(purchase.get("gold_spent", 0)) < int(offer.get("price", 0))
			and inventory.get_resource_amount(&"gold")
				== gold_before_purchase - int(purchase.get("gold_spent", 0)),
		"Market discount must reduce the actual gold charged for purchases."
	)
	_expect(
		inventory.get_resource_amount(&"autumn_wood") == wood_before_purchase + 13,
		"Master stockyard bonus must increase the actual material bundle yield."
	)

	var recipe := ForgeCatalogScript.new().get_recipe(&"forge_hunter_bow")
	var crafted: Dictionary = service.craft(&"forge_hunter_bow")
	_expect(bool(crafted.get("ok", false)), "Discounted forge recipe must remain craftable.")
	_expect(
		int(crafted.get("processing_fee", 0)) < int(recipe.get("processing_fee", 0)),
		"Blacksmith discount must reduce the actual processing fee."
	)
	var base_sale_value := int(inventory.get_equipment_sale_value(&"hunter_bow"))
	var listed: Dictionary = service.list_for_sale(
		&"equipment", &"hunter_bow", inventory.get_highest_equipment_quality(&"hunter_bow"), 1
	)
	var sale_slot := listed.get("sale_slot", {}) as Dictionary
	_expect(
		bool(listed.get("ok", false))
			and int(sale_slot.get("unit_price", 0)) > base_sale_value,
		"Market sale bonus must raise the value placed in sales-table escrow."
	)


func _test_inventory_legacy_migration_and_round_trip() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.apply_dict({
		"resources": {"gold": 77},
		"owned_equipment": ["iron_sword"],
		"equipment_levels": {"iron_sword": 2},
		"owned_blueprints": ["iron_sword_blueprint"],
		"owned_tools": ["forging_hammer"],
		"sale_slot": {
			"item_kind": "equipment",
			"item_id": "iron_sword",
			"quality": "common",
			"quantity": 1,
			"unit_price": 25,
		},
	})
	_expect(
		inventory.get_equipment_count(&"iron_sword") == 1,
		"Legacy owned_equipment must migrate to one equipment count."
	)
	_expect(inventory.get_equipment_level(&"iron_sword") == 2, "Legacy level must survive migration.")
	_expect(inventory.owns_blueprint(&"iron_sword_blueprint"), "Blueprint ownership must apply.")
	_expect(inventory.owns_tool(&"forging_hammer"), "Tool ownership must apply.")
	_expect(
		StringName(inventory.get_sale_slot(0).get("item_id", "")) == &"iron_sword",
		"Legacy single-slot listings must migrate into the first multi-shelf slot."
	)

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


func _find_entry(entries: Array, entry_id: StringName) -> Dictionary:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if StringName(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _has_sale_candidate(
	entries: Array,
	item_kind: StringName,
	item_id: StringName,
	quality: StringName
) -> bool:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if (
			StringName(entry.get("item_kind", "")) == item_kind
			and StringName(entry.get("item_id", "")) == item_id
			and StringName(entry.get("quality", "")) == quality
		):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
