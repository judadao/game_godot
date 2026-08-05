extends SceneTree

const InventoryManagerScript = preload("res://scripts/systems/inventory_manager.gd")
const TownManagerScript = preload("res://scripts/systems/town_manager.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_equipment_catalog_and_fixed_effects()
	_test_resource_spending_is_atomic_and_rejects_invalid_input()
	_test_equipping_is_slot_safe_and_requires_ownership()
	_test_town_upgrades_stages_and_visual_projection()
	quit(0 if _failures == 0 else 1)


func _test_equipment_catalog_and_fixed_effects() -> void:
	var inventory = InventoryManagerScript.new()
	_expect(inventory.is_loaded(), "Equipment data must load.")
	_expect(
		inventory.get_resource_ids() == [
			&"gold",
			&"autumn_wood",
			&"stone",
			&"magic_shard",
			&"autumn_core",
		],
		"The economy must expose exactly the five ordered resources."
	)
	_expect(
		inventory.get_equipment_for_slot(&"weapon").size() == 3,
		"The catalog must contain exactly three weapons."
	)
	_expect(
		inventory.get_equipment_for_slot(&"armor").size() == 3,
		"The catalog must contain exactly three armor pieces."
	)
	_expect(
		inventory.get_equipment_for_slot(&"accessory").size() == 4,
		"The catalog must contain exactly four accessories."
	)

	var all_equipment: Array = inventory.get_equipment_catalog()
	_expect(all_equipment.size() == 10, "The catalog must contain ten equipment entries.")
	for item_variant in all_equipment:
		var item := item_variant as Dictionary
		var effects := item.get("effects", {}) as Dictionary
		_expect(not effects.is_empty(), "Every equipment entry must declare fixed effects.")
		for effect_value in effects.values():
			_expect(
				effect_value is int or effect_value is float,
				"Equipment effects must be fixed numeric values."
			)


func _test_resource_spending_is_atomic_and_rejects_invalid_input() -> void:
	var inventory = InventoryManagerScript.new()
	var starting_wood: int = inventory.get_resource_amount(&"autumn_wood")
	var starting_stone: int = inventory.get_resource_amount(&"stone")

	_expect(
		inventory.can_afford({&"autumn_wood": 5, &"stone": 3}),
		"Starting resources must afford a small valid cost."
	)
	_expect(
		inventory.spend_resources({&"autumn_wood": 5, &"stone": 3}),
		"A valid affordable spend must succeed."
	)
	_expect(
		inventory.get_resource_amount(&"autumn_wood") == starting_wood - 5,
		"A successful spend must deduct autumn wood."
	)
	_expect(
		inventory.get_resource_amount(&"stone") == starting_stone - 3,
		"A successful spend must deduct stone."
	)

	var before_failed_spend: Dictionary = inventory.get_resources()
	_expect(
		not inventory.spend_resources({&"autumn_wood": 1, &"stone": 999999}),
		"An unaffordable multi-resource spend must fail."
	)
	_expect(
		inventory.get_resources() == before_failed_spend,
		"A failed spend must not deduct any resource."
	)
	_expect(
		not inventory.add_resource(&"autumn_wood", -1),
		"Negative resource additions must be rejected."
	)
	_expect(
		not inventory.spend_resources({&"unknown_resource": 1}),
		"Unknown resources must be rejected."
	)
	_expect(
		not inventory.spend_resources({&"autumn_wood": 0}),
		"Zero-value costs must be rejected."
	)


func _test_equipping_is_slot_safe_and_requires_ownership() -> void:
	var inventory = InventoryManagerScript.new()
	_expect(
		not inventory.equip(&"iron_sword"),
		"Equipment not owned by the player must not be equipped."
	)
	_expect(inventory.add_equipment(&"iron_sword"), "A catalog item must be addable.")
	_expect(
		not inventory.add_equipment(&"iron_sword"),
		"Duplicate unique equipment must be rejected."
	)
	_expect(inventory.equip(&"iron_sword"), "An owned weapon must equip successfully.")
	_expect(
		inventory.get_equipped(&"weapon") == &"iron_sword",
		"The weapon must occupy only the weapon slot."
	)
	_expect(
		inventory.get_equipped(&"armor") == StringName(),
		"Equipping a weapon must not mutate the armor slot."
	)
	_expect(
		inventory.get_effect_totals().get("attack", 0) == 4,
		"The iron sword must contribute its fixed +4 attack effect."
	)
	_expect(
		not inventory.equip(&"missing_item"),
		"Unknown equipment IDs must be rejected without mutation."
	)
	_expect(
		inventory.get_equipped(&"weapon") == &"iron_sword",
		"A rejected equip must preserve the currently equipped item."
	)
	_expect(
		not inventory.unequip(&"invalid_slot"),
		"Unknown equipment slots must be rejected."
	)
	_expect(inventory.unequip(&"weapon"), "An occupied valid slot must be unequippable.")
	_expect(
		inventory.get_effect_totals().is_empty(),
		"Unequipping the only item must clear its effects."
	)


func _test_town_upgrades_stages_and_visual_projection() -> void:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		_expect(
			inventory.add_resource(resource_id, 1000),
			"Test setup must be able to grant valid resources."
		)
	var town = TownManagerScript.new(inventory)

	_expect(town.is_loaded(), "Town upgrade data must load.")
	_expect(
		String(town.get_next_upgrade(&"blacksmith").get("description", "")).contains("recipe"),
		"Every town upgrade must explain its concrete gameplay effect."
	)
	_expect(
		is_equal_approx(float(town.get_effect_value(&"forge_processing_fee_discount")), 0.0),
		"A new town must not receive unearned upgrade effects."
	)
	_expect(town.get_village_stage() == 0, "A new town must begin at village stage zero.")
	_expect(
		town.get_village_stage_id() == &"settlement",
		"Stage zero must be the settlement stage."
	)
	var initial_projection: Dictionary = town.get_visual_projection()
	_expect(
		bool(initial_projection.get("show_basic_houses", false)),
		"Settlement projection must show basic houses."
	)
	_expect(
		not bool(initial_projection.get("show_market_stalls", false)),
		"Settlement projection must not show growing-village market stalls."
	)

	var resources_before_invalid: Dictionary = inventory.get_resources()
	_expect(
		not town.upgrade_building(&"missing_building"),
		"Unknown buildings must not be upgraded."
	)
	_expect(
		inventory.get_resources() == resources_before_invalid,
		"An invalid upgrade must not spend resources."
	)

	_expect(town.upgrade_building(&"blacksmith"), "Blacksmith level one must upgrade.")
	_expect(
		int(town.get_effect_value(&"forge_recipe_tier")) == 1,
		"Blacksmith level one must expose its recipe-tier effect."
	)
	_expect(town.upgrade_building(&"workshop"), "Workshop level one must upgrade.")
	_expect(
		int(town.get_effect_value(&"material_store_tier")) == 1,
		"Workshop level one must unlock the basic material-store tier."
	)
	_expect(town.upgrade_building(&"market"), "Market level one must upgrade.")
	_expect(
		float(town.get_effect_value(&"market_purchase_discount")) > 0.0
			and float(town.get_effect_value(&"market_sale_bonus")) > 0.0,
		"Market upgrades must improve both buying and selling."
	)
	_expect(town.get_village_stage() == 1, "Three total building levels must reach stage one.")
	_expect(
		town.get_village_stage_id() == &"growing_village",
		"Stage one must be the growing village."
	)
	var growing_projection: Dictionary = town.get_visual_projection()
	_expect(
		bool(growing_projection.get("show_market_stalls", false)),
		"Growing-village projection must show market stalls."
	)
	_expect(
		bool(growing_projection.get("show_blacksmith_level_1", false)),
		"Building projection must expose the blacksmith level-one visual."
	)

	_expect(town.upgrade_building(&"blacksmith"), "Blacksmith level two must upgrade.")
	_expect(town.upgrade_building(&"workshop"), "Workshop level two must upgrade.")
	_expect(town.upgrade_building(&"market"), "Market level two must upgrade.")
	_expect(town.upgrade_building(&"town_hall"), "Town hall level one must upgrade.")
	var discounted_library_cost: Dictionary = town.get_next_upgrade_cost(&"memory_library")
	var raw_library_cost: Dictionary = town.get_raw_next_upgrade_cost(&"memory_library")
	_expect(
		int(discounted_library_cost.get("autumn_wood", 0))
			< int(raw_library_cost.get("autumn_wood", 0)),
		"Town Hall upgrades must lower the cost of other town construction."
	)
	_expect(town.get_village_stage() == 2, "Seven total building levels must reach stage two.")
	_expect(
		town.get_village_stage_id() == &"prosperous_town",
		"Stage two must be the prosperous town."
	)
	var prosperous_projection: Dictionary = town.get_visual_projection()
	_expect(
		bool(prosperous_projection.get("show_stone_walls", false)),
		"Prosperous-town projection must show stone walls."
	)
	_expect(
		bool(prosperous_projection.get("show_blacksmith_level_2", false)),
		"Building projection must expose the blacksmith level-two visual."
	)
	_expect(town.upgrade_building(&"workshop"), "Workshop level three must upgrade.")
	_expect(
		is_equal_approx(float(town.get_effect_value(&"material_bundle_bonus")), 0.25),
		"Master Stockyard must expose its material bundle yield bonus."
	)

	var poor_inventory = InventoryManagerScript.new()
	_expect(
		poor_inventory.spend_resources(poor_inventory.get_resources()),
		"Test setup must be able to exhaust all starting resources."
	)
	var poor_town = TownManagerScript.new(poor_inventory)
	_expect(
		not poor_town.upgrade_building(&"blacksmith"),
		"An unaffordable upgrade must fail."
	)
	_expect(
		poor_town.get_building_level(&"blacksmith") == 0,
		"A failed upgrade must preserve the building level."
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
