extends SceneTree

const ForgeCatalogScript = preload("res://scripts/systems/forge_catalog.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_loads_valid_cross_referenced_content()
	_test_shop_offers_are_partitioned_and_flame_gated()
	_test_recipes_are_blacksmith_gated()
	quit(0 if _failures == 0 else 1)


func _test_catalog_loads_valid_cross_referenced_content() -> void:
	var catalog = ForgeCatalogScript.new()
	_expect(catalog.is_loaded(), "Forge catalog must load its validated default data.")
	_expect(
		not catalog.get_offer(&"material_wood_bundle").is_empty(),
		"Forge catalog must expose stable offer IDs."
	)
	_expect(
		not catalog.get_recipe(&"forge_iron_sword").is_empty(),
		"Forge catalog must expose stable recipe IDs."
	)
	for offer in catalog.get_all_offers():
		_expect(
			ResourceLoader.exists(String(offer.get("icon_path", ""))),
			"Every commerce offer must reference an existing icon."
		)


func _test_shop_offers_are_partitioned_and_flame_gated() -> void:
	var catalog = ForgeCatalogScript.new()
	var material_tier_zero: Array = catalog.get_shop_offers(&"material_store", 0)
	var material_tier_two: Array = catalog.get_shop_offers(&"material_store", 2)
	_expect(
		_has_entry(material_tier_zero, &"material_wood_bundle"),
		"Material store tier zero must sell basic forging resources."
	)
	_expect(
		_has_entry(material_tier_zero, &"tool_forging_hammer"),
		"Material store tier zero must sell a basic forging tool."
	)
	_expect(
		not _has_entry(material_tier_zero, &"tool_arcane_calipers"),
		"High-tier forging tools must remain locked at flame tier zero."
	)
	_expect(
		_has_entry(material_tier_two, &"tool_arcane_calipers"),
		"Flame tier two must unlock the advanced forging tool."
	)
	_expect(
		material_tier_two.size() > material_tier_zero.size(),
		"Raising flame tier must only expand the material-store catalog."
	)

	var soul_offers: Array = catalog.get_shop_offers(&"sword_soul_shop", 3)
	var equipment_offers: Array = catalog.get_shop_offers(&"equipment_blueprint_shop", 3)
	_expect(not soul_offers.is_empty(), "Sword Soul Shop must sell blueprint offers.")
	_expect(not equipment_offers.is_empty(), "Equipment merchant must sell blueprint offers.")
	for offer in soul_offers:
		_expect(
			String(offer.get("product_kind", "")) == "blueprint"
				and String(offer.get("target_kind", "")) == "sword_soul",
			"Sword Soul Shop must contain only sword-soul blueprints."
		)
	for offer in equipment_offers:
		_expect(
			String(offer.get("product_kind", "")) == "blueprint"
				and String(offer.get("target_kind", "")) == "equipment",
			"Equipment merchant must contain only equipment blueprints."
		)


func _test_recipes_are_blacksmith_gated() -> void:
	var catalog = ForgeCatalogScript.new()
	var level_one: Array = catalog.get_recipes_for_blacksmith_level(1)
	var level_three: Array = catalog.get_recipes_for_blacksmith_level(3)
	_expect(
		_has_entry(level_one, &"forge_iron_sword"),
		"Blacksmith level one must expose the basic iron sword recipe."
	)
	_expect(
		not _has_entry(level_one, &"forge_merchant_seal"),
		"Blacksmith level one must not expose a tier-three recipe."
	)
	_expect(
		_has_entry(level_three, &"forge_merchant_seal"),
		"Blacksmith level three must expose the tier-three recipe."
	)
	_expect(
		level_three.size() > level_one.size(),
		"Blacksmith upgrades must expand the recipe projection."
	)


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
