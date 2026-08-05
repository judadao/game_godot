extends SceneTree

const ForgeCatalogScript = preload("res://scripts/systems/forge_catalog.gd")
const ForgeServiceScript = preload("res://scripts/systems/forge_service.gd")
const InventoryManagerScript = preload("res://scripts/systems/inventory_manager.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_forge_methods_and_material_traits_are_actionable()
	_test_scrapped_sword_soul_does_not_emit_unlock_intent()
	_test_awakened_blueprint_school_can_be_reworked_and_saved()
	_test_schema_four_blueprint_migrates_to_balanced_school()
	_test_rumor_customer_and_price_strategy_change_sale_result()
	_test_declined_luxury_listing_requires_cancel_before_retry()
	await _test_geometry_ui_exposes_the_new_choices()
	quit(0 if _failures == 0 else 1)


func _test_forge_methods_and_material_traits_are_actionable() -> void:
	var inventory = _prepared_inventory()
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 3, 3)
	service.set_random_seed(41)
	var methods: Array = service.get_forge_methods(&"forge_hunter_bow")
	_expect(methods.size() >= 4, "Forge must expose several readable method choices.")
	_expect(_has_id(methods, &"steady"), "Steady forging must be available as the safe default.")
	_expect(_has_id(methods, &"refine"), "Refining must trade extra resources for quality control.")
	_expect(_has_id(methods, &"rush"), "Rush forging must be a cheaper but riskier choice.")
	var preview := service.get_craft_preview(&"forge_hunter_bow", &"refine") as Dictionary
	_expect(
		StringName(preview.get("material_trait", "")) == &"supple"
			and float(preview.get("success_chance", 0.0)) > 0.0
			and (preview.get("outcome_chances", {}) as Dictionary).has("scrap"),
		"Craft preview must explain the recipe material trait, success rate, and failure outcomes."
	)
	_expect_failure_shares(
		preview.get("outcome_chances", {}) as Dictionary,
		0.05,
		0.63,
		0.32,
		"Refine"
	)
	var rush_preview := service.get_craft_preview(&"forge_hunter_bow", &"rush") as Dictionary
	_expect_failure_shares(
		rush_preview.get("outcome_chances", {}) as Dictionary,
		0.45,
		0.23,
		0.32,
		"Rush"
	)
	var crafted := service.craft(&"forge_hunter_bow", 1, &"refine") as Dictionary
	_expect(bool(crafted.get("ok", false)), "A forge attempt must resolve even when its process outcome varies.")
	_expect(
		StringName(crafted.get("forge_method", "")) == &"refine"
			and not (crafted.get("outcome_counts", {}) as Dictionary).is_empty(),
		"Craft result must report the chosen method and readable outcome breakdown."
	)


func _test_awakened_blueprint_school_can_be_reworked_and_saved() -> void:
	var inventory = _prepared_inventory()
	inventory.record_blueprint_craft(&"hunter_bow_blueprint", 5)
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 3, 3)
	var before: Dictionary = inventory.get_blueprint_proficiency(&"hunter_bow_blueprint")
	_expect(
		bool(before.get("awakened", false))
			and StringName(before.get("school", "")) == &"balanced",
		"A newly awakened blueprint must receive the readable balanced school."
	)
	var reworked := service.rework_blueprint_school(
		&"hunter_bow_blueprint", &"merchant_signature"
	) as Dictionary
	_expect(bool(reworked.get("ok", false)), "Blueprint shop must rework an awakened design.")
	_expect(
		StringName(inventory.get_blueprint_proficiency(
			&"hunter_bow_blueprint"
		).get("school", "")) == &"merchant_signature",
		"Rework must replace the blueprint school without resetting proficiency."
	)
	var restored = InventoryManagerScript.new()
	restored.apply_dict(inventory.to_dict())
	_expect(
		restored.get_blueprint_proficiency(&"hunter_bow_blueprint")
			== inventory.get_blueprint_proficiency(&"hunter_bow_blueprint"),
		"Awakened school must survive inventory save round-trip."
	)


func _test_scrapped_sword_soul_does_not_emit_unlock_intent() -> void:
	var scrap_result: Dictionary = {}
	for seed_value in 100:
		var inventory = _prepared_inventory()
		inventory.grant_blueprint(&"flame_imbue_blueprint")
		var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
		service.set_progression_levels(3, 3, 3)
		service.set_random_seed(seed_value)
		var result := service.craft(&"forge_flame_imbue", 1, &"rush") as Dictionary
		if int(result.get("quantity", 1)) == 0:
			scrap_result = result
			break
	_expect(not scrap_result.is_empty(), "Seeded rush forging must cover the all-scrap branch.")
	_expect(
		StringName(scrap_result.get("code", "")) == &"craft_scrap"
			and String(scrap_result.get("intent", "")).is_empty()
			and not bool(scrap_result.get("proficiency_advanced", true)),
		"An all-scrap sword-soul attempt must not emit an unlock intent or raise proficiency."
	)


func _test_schema_four_blueprint_migrates_to_balanced_school() -> void:
	var inventory = _prepared_inventory()
	inventory.record_blueprint_craft(&"hunter_bow_blueprint", 5)
	var legacy_save: Dictionary = inventory.to_dict()
	legacy_save["schema_version"] = 4
	(legacy_save["blueprint_proficiency"] as Dictionary)["hunter_bow_blueprint"].erase("school")
	var restored = InventoryManagerScript.new()
	restored.apply_dict(legacy_save)
	_expect(
		StringName(restored.get_blueprint_proficiency(
			&"hunter_bow_blueprint"
		).get("school", "")) == &"balanced",
		"Schema 4 blueprints without a school must migrate to the balanced school."
	)


func _test_rumor_customer_and_price_strategy_change_sale_result() -> void:
	var inventory = _prepared_inventory()
	inventory.add_equipment_count(&"hunter_bow", 1, &"rare")
	var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
	service.set_progression_levels(3, 3, 3)
	service.set_random_seed(7)
	var rumors: Array = service.get_active_rumors()
	_expect(not rumors.is_empty(), "Sales table must publish readable rumor leads.")
	var listed := service.list_for_sale(
		&"equipment", &"hunter_bow", &"rare", 1, &"luxury"
	) as Dictionary
	var slot := listed.get("sale_slot", {}) as Dictionary
	_expect(
		bool(listed.get("ok", false))
			and StringName(slot.get("price_strategy", "")) == &"luxury"
			and StringName(slot.get("rumor_id", "")) == &"frontier_hunt",
		"Matching display goods must activate their rumor and preserve the chosen price strategy."
	)
	var sold := service.resolve_sale() as Dictionary
	_expect(bool(sold.get("ok", false)), "A matching rumor customer must always complete the purchase.")
	_expect(
		String(sold.get("customer_name", "")).contains("Captain")
			and float(sold.get("rumor_multiplier", 1.0)) > 1.0
			and int(sold.get("gold", 0)) > int(slot.get("base_unit_price", 0)),
		"Rumor customer must be named and pay a visible premium over the base sale value."
	)


func _test_declined_luxury_listing_requires_cancel_before_retry() -> void:
	var declined_result: Dictionary = {}
	var declined_service: RefCounted
	var declined_inventory: RefCounted
	for seed_value in 100:
		var inventory = _prepared_inventory()
		inventory.add_equipment_count(&"hunter_bow", 1, &"common")
		var service = ForgeServiceScript.new(ForgeCatalogScript.new(), inventory)
		service.set_progression_levels(3, 3, 3)
		service.set_random_seed(seed_value)
		service.list_for_sale(&"equipment", &"hunter_bow", &"common", 1, &"luxury")
		var result := service.resolve_sale() as Dictionary
		if StringName(result.get("code", "")) == &"customer_declined":
			declined_result = result
			declined_service = service
			declined_inventory = inventory
			break
	_expect(not declined_result.is_empty(), "Seeded luxury pricing must cover customer refusal.")
	var retry := declined_service.call("resolve_sale") as Dictionary
	_expect(
		StringName(retry.get("code", "")) == &"customer_declined_locked",
		"A refused luxury quote must lock repeat checkout instead of allowing click-spam retries."
	)
	var canceled := declined_service.call("cancel_sale") as Dictionary
	_expect(
		bool(canceled.get("ok", false))
			and int(declined_inventory.call(
				"get_equipment_quality_count", &"hunter_bow", &"common"
			)) == 1,
		"Canceling a refused listing must return the item so the player can choose another price."
	)


func _test_geometry_ui_exposes_the_new_choices() -> void:
	var shop := (load("res://scenes/ui/shop/ShopUI.tscn") as PackedScene).instantiate() as Control
	root.add_child(shop)
	await process_frame
	shop.call("set_shop_context", &"equipment_blueprint_shop")
	shop.call("set_items", [{
		"id": "equipment_blueprint_hunter_bow",
		"product_id": "hunter_bow_blueprint",
		"name": "Hunter Bow Blueprint",
		"description": "A practiced design.",
		"price": 80,
		"stock": 0,
		"owned_count": 1,
		"blueprint_awakened": true,
		"blueprint_school": "balanced",
		"blueprint_schools": ForgeServiceScript.new(
			ForgeCatalogScript.new(), _prepared_inventory()
		).get_blueprint_schools(),
		"blueprint_rework_cost": {"gold": 120, "magic_shard": 8},
	}])
	await process_frame
	var school_panel := shop.find_child("BlueprintSchoolPanel", true, false) as Control
	var school_selector := shop.find_child("BlueprintSchoolSelector", true, false) as OptionButton
	var rework_button := shop.find_child("BlueprintReworkButton", true, false) as Button
	_expect(
		school_panel != null and school_panel.visible and school_selector.item_count == 5,
		"Owned awakened blueprints must reveal a five-school rework panel in the blueprint shop."
	)
	_expect(
		rework_button != null and rework_button.tooltip_text.contains("熟練度"),
		"Blueprint rework action must explain its irreversible choice and preserved proficiency."
	)
	shop.queue_free()
	await process_frame

	var blacksmith := (
		load("res://scenes/ui/town/PlayerBlacksmithUI.tscn") as PackedScene
	).instantiate() as Control
	root.add_child(blacksmith)
	await process_frame
	for control_name in [
		"SteadyMethodButton", "RefineMethodButton", "RushMethodButton",
		"MasterworkMethodButton", "QuickPriceButton", "FairPriceButton",
		"LuxuryPriceButton", "RumorLabel", "CancelListingButton",
	]:
		_expect(
			blacksmith.find_child(control_name, true, false) != null,
			"Blacksmith UI must expose the authored %s control." % control_name
		)
	blacksmith.call("set_sale_state", {
		"status": "customer_ready",
		"item_id": "hunter_bow",
		"item_name": "Hunter Bow · Rare",
		"crafted_count": 1,
		"rumor_id": "frontier_hunt",
		"rumor_title": "流言菲語：北境狩獵隊整裝",
		"customer_name": "Frontier Captain Rhea",
		"rumor_multiplier": 1.8,
		"candidates": [],
	})
	await process_frame
	var active_rumor := blacksmith.find_child("RumorLabel", true, false) as Label
	var cancel_button := blacksmith.find_child("CancelListingButton", true, false) as Button
	_expect(
		active_rumor.text.contains("Captain") and not active_rumor.text.contains("不符合"),
		"An escrowed rumor item must keep showing its named customer after leaving candidates."
	)
	_expect(
		cancel_button.visible and not cancel_button.disabled,
		"An active listing must expose a clear cancel-and-reprice action."
	)
	blacksmith.queue_free()
	await process_frame


func _prepared_inventory() -> RefCounted:
	var inventory = InventoryManagerScript.new()
	for resource_id in inventory.get_resource_ids():
		inventory.set_resource_amount(resource_id, 10000)
	inventory.grant_blueprint(&"hunter_bow_blueprint")
	inventory.grant_tool(&"forging_hammer")
	inventory.grant_tool(&"tempering_tongs")
	inventory.grant_tool(&"arcane_calipers")
	return inventory


func _has_id(entries: Array, target_id: StringName) -> bool:
	for entry_variant in entries:
		if StringName((entry_variant as Dictionary).get("id", "")) == target_id:
			return true
	return false


func _expect_failure_shares(
	chances: Dictionary,
	expected_scrap: float,
	expected_flawed: float,
	expected_prototype: float,
	method_name: String
) -> void:
	var failure_total := (
		float(chances.get("scrap", 0.0))
		+ float(chances.get("flawed", 0.0))
		+ float(chances.get("prototype", 0.0))
	)
	_expect(failure_total > 0.0, "%s preview must include failure outcomes." % method_name)
	if failure_total <= 0.0:
		return
	_expect(
		is_equal_approx(float(chances.get("scrap", 0.0)) / failure_total, expected_scrap)
			and is_equal_approx(float(chances.get("flawed", 0.0)) / failure_total, expected_flawed)
			and is_equal_approx(
				float(chances.get("prototype", 0.0)) / failure_total,
				expected_prototype
			),
		"%s preview must match the runtime scrap/flawed/prototype thresholds." % method_name
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
