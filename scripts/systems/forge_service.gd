class_name ForgeService
extends RefCounted

var _catalog: RefCounted
var _inventory: RefCounted
var _flame_tier := 0
var _blacksmith_level := 0
var _market_level := 0
var _purchase_discount := 0.0
var _sale_multiplier := 1.0
var _processing_fee_discount := 0.0
var _material_yield_multiplier := 1.0
var _quality_bonus := 0.0


func _init(catalog: RefCounted, inventory: RefCounted) -> void:
	_catalog = catalog
	_inventory = inventory
	_quality_rng.randomize()


func is_configured() -> bool:
	return (
		_catalog != null
		and _inventory != null
		and bool(_catalog.call("is_loaded"))
		and bool(_inventory.call("is_loaded"))
	)


var _quality_rng := RandomNumberGenerator.new()


func set_progression_levels(
	flame_tier: int,
	blacksmith_level: int,
	market_level: int = -1
) -> void:
	_flame_tier = maxi(0, flame_tier)
	_blacksmith_level = maxi(0, blacksmith_level)
	_market_level = maxi(0, flame_tier if market_level < 0 else market_level)


func set_economy_modifiers(
	purchase_discount: float,
	sale_multiplier: float,
	processing_fee_discount: float,
	material_yield_multiplier: float = 1.0,
	quality_bonus: float = 0.0
) -> void:
	_purchase_discount = clampf(purchase_discount, 0.0, 0.75)
	_sale_multiplier = clampf(sale_multiplier, 1.0, 3.0)
	_processing_fee_discount = clampf(processing_fee_discount, 0.0, 0.75)
	_material_yield_multiplier = clampf(material_yield_multiplier, 1.0, 3.0)
	_quality_bonus = clampf(quality_bonus, 0.0, 0.25)


func get_shop_offers(
	shop_id: StringName,
	include_locked: bool = false
) -> Array[Dictionary]:
	if not is_configured():
		return []
	var offers := (
		_catalog.call("get_all_offers") as Array
		if include_locked
		else _catalog.call("get_shop_offers", shop_id, _flame_tier, _market_level) as Array
	)
	var result: Array[Dictionary] = []
	for offer_variant in offers:
		var offer := (offer_variant as Dictionary).duplicate(true)
		if StringName(offer.get("shop_id", "")) != shop_id:
			continue
		var base_price := int(offer.get("price", 0))
		offer["base_price"] = base_price
		offer["price"] = _discounted_amount(base_price, _purchase_discount)
		var product_kind := StringName(offer.get("product_kind", ""))
		var product_id := StringName(offer.get("product_id", ""))
		offer["unlocked"] = bool(_catalog.call("is_offer_unlocked", StringName(
			offer.get("id", "")
		), _flame_tier, _market_level))
		if product_kind == &"resource":
			var base_quantity := int(offer.get("quantity", 1))
			offer["base_quantity"] = base_quantity
			offer["quantity"] = _material_quantity(base_quantity)
		if product_kind == &"tool":
			offer["owned"] = bool(_inventory.call("owns_tool", product_id))
		elif product_kind == &"blueprint":
			offer["owned"] = bool(_inventory.call("owns_blueprint", product_id))
		elif product_kind == &"equipment":
			offer["owned"] = int(_inventory.call("get_equipment_count", product_id))
		else:
			offer["owned"] = int(_inventory.call("get_resource_amount", product_id))
		result.append(offer)
	return result


func purchase_offer(offer_id: StringName, quantity: int = 1) -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	if quantity <= 0:
		return _result(false, &"invalid_quantity")
	var offer := _catalog.call("get_offer", offer_id) as Dictionary
	if offer.is_empty():
		return _result(false, &"unknown_offer")
	if not bool(_catalog.call("is_offer_unlocked", offer_id, _flame_tier, _market_level)):
		return _result(false, &"offer_locked")
	var product_kind := StringName(offer.get("product_kind", ""))
	var product_id := StringName(offer.get("product_id", ""))
	if product_kind != &"resource" and quantity != 1:
		return _result(false, &"unique_quantity")
	if product_kind == &"tool" and bool(_inventory.call("owns_tool", product_id)):
		return _result(false, &"already_owned")
	if product_kind == &"blueprint" and bool(_inventory.call("owns_blueprint", product_id)):
		return _result(false, &"already_owned")
	if product_kind == &"resource" and not (_inventory.call("get_resource_ids") as Array).has(product_id):
		return _result(false, &"invalid_product")
	var total_price := _discounted_amount(
		int(offer.get("price", 0)),
		_purchase_discount
	) * quantity
	if not bool(_inventory.call("spend_resources", {&"gold": total_price})):
		return _result(false, &"insufficient_gold")
	var granted := false
	match product_kind:
		&"resource":
			granted = bool(_inventory.call(
				"add_resource",
				product_id,
				_material_quantity(int(offer.get("quantity", 1))) * quantity
			))
		&"tool":
			granted = bool(_inventory.call("grant_tool", product_id))
		&"blueprint":
			granted = bool(_inventory.call("grant_blueprint", product_id))
		&"equipment":
			var equipment := _inventory.call("get_equipment", product_id) as Dictionary
			if bool(equipment.get("direct_purchase", false)):
				granted = bool(_inventory.call(
					"add_equipment_count",
					product_id,
					int(offer.get("quantity", 1))
				))
	if not granted:
		_inventory.call("add_resource", &"gold", total_price)
		return _result(false, &"grant_failed")
	return _result(true, &"purchased", {
		"offer_id": String(offer_id),
		"product_kind": String(product_kind),
		"product_id": String(product_id),
		"quantity": (
			_material_quantity(int(offer.get("quantity", 1)))
			if product_kind == &"resource"
			else int(offer.get("quantity", 1))
		) * quantity,
		"gold_spent": total_price,
	})


func get_available_recipes() -> Array[Dictionary]:
	if not is_configured():
		return []
	var recipes := _catalog.call(
		"get_recipes_for_blacksmith_level",
		_blacksmith_level
	) as Array
	var result: Array[Dictionary] = []
	for recipe_variant in recipes:
		var recipe := recipe_variant as Dictionary
		if not bool(_inventory.call(
			"owns_blueprint",
			StringName(recipe.get("blueprint_id", ""))
		)):
			continue
		if not _owns_required_tools(recipe):
			continue
		var projection := recipe.duplicate(true)
		var base_fee := int(projection.get("processing_fee", 0))
		projection["base_processing_fee"] = base_fee
		projection["processing_fee"] = _discounted_amount(
			base_fee,
			_processing_fee_discount
		)
		var blueprint_id := StringName(projection.get("blueprint_id", ""))
		var proficiency := _inventory.call(
			"get_blueprint_proficiency", blueprint_id
		) as Dictionary
		projection["proficiency_level"] = int(proficiency.get("level", 0))
		projection["proficiency_count"] = int(proficiency.get("craft_count", 0))
		projection["blueprint_awakened"] = bool(proficiency.get("awakened", false))
		projection["quality_chances"] = _quality_chances(
			StringName(projection.get("quality", "common")),
			int(proficiency.get("level", 0)),
			bool(proficiency.get("awakened", false))
		)
		result.append(projection)
	return result


func craft(recipe_id: StringName, quantity: int = 1) -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	if quantity <= 0:
		return _result(false, &"invalid_quantity")
	var recipe := _catalog.call("get_recipe", recipe_id) as Dictionary
	if recipe.is_empty():
		return _result(false, &"unknown_recipe")
	if int(recipe.get("required_blacksmith_level", 1)) > _blacksmith_level:
		return _result(false, &"blacksmith_level_locked")
	if not bool(_inventory.call(
		"owns_blueprint",
		StringName(recipe.get("blueprint_id", ""))
	)):
		return _result(false, &"blueprint_required")
	if not _owns_required_tools(recipe):
		return _result(false, &"tool_required")
	var total_cost := _multiply_cost(recipe.get("cost", {}) as Dictionary, quantity)
	var processing_fee := _discounted_amount(
		int(recipe.get("processing_fee", 0)),
		_processing_fee_discount
	) * quantity
	total_cost["gold"] = processing_fee
	if not bool(_inventory.call("spend_resources", total_cost)):
		return _result(false, &"insufficient_resources")
	var result_kind := StringName(recipe.get("result_kind", ""))
	var result_id := StringName(recipe.get("result_id", ""))
	var blueprint_id := StringName(recipe.get("blueprint_id", ""))
	var proficiency := _inventory.call(
		"get_blueprint_proficiency", blueprint_id
	) as Dictionary
	var chances := _quality_chances(
		StringName(recipe.get("quality", "common")),
		int(proficiency.get("level", 0)),
		bool(proficiency.get("awakened", false))
	)
	var quality_counts: Dictionary = {}
	for _craft_index in quantity:
		var rolled_quality := _roll_quality(chances)
		quality_counts[String(rolled_quality)] = int(
			quality_counts.get(String(rolled_quality), 0)
		) + 1
	if result_kind == &"equipment":
		for quality_variant in quality_counts:
			if not bool(_inventory.call(
				"add_equipment_count",
				result_id,
				int(quality_counts[quality_variant]),
				StringName(quality_variant)
			)):
				_refund(total_cost)
				return _result(false, &"craft_failed")
		var updated_proficiency := _inventory.call(
			"record_blueprint_craft", blueprint_id, quantity
		) as Dictionary
		return _result(true, &"crafted", {
			"result_kind": "equipment",
			"result_id": String(result_id),
			"quantity": quantity,
			"quality": String(_highest_quality_in(quality_counts)),
			"quality_counts": quality_counts,
			"proficiency": updated_proficiency,
			"blueprint_awakened_now": bool(updated_proficiency.get("awakened_now", false)),
			"material_tier": String(recipe.get("material_tier", "normal")),
			"processing_fee": processing_fee,
		})
	if result_kind == &"sword_soul":
		var updated_proficiency := _inventory.call(
			"record_blueprint_craft", blueprint_id, quantity
		) as Dictionary
		return _result(true, &"intent_ready", {
			"intent": "grant_sword_soul",
			"result_kind": "sword_soul",
			"result_id": String(result_id),
			"quantity": quantity,
			"quality": String(_highest_quality_in(quality_counts)),
			"quality_counts": quality_counts,
			"proficiency": updated_proficiency,
			"blueprint_awakened_now": bool(updated_proficiency.get("awakened_now", false)),
			"material_tier": String(recipe.get("material_tier", "normal")),
			"processing_fee": processing_fee,
		})
	_refund(total_cost)
	return _result(false, &"invalid_result")


func get_sale_candidates() -> Array[Dictionary]:
	if not is_configured():
		return []
	var result: Array[Dictionary] = []
	for resource_id in _inventory.call("get_resource_ids") as Array:
		if StringName(resource_id) == &"gold":
			continue
		for quality in [&"common", &"rare", &"exceptional", &"legendary"]:
			var count := int(_inventory.call(
				"get_resource_quality_amount", StringName(resource_id), quality
			))
			if count <= 0:
				continue
			result.append(_sale_candidate(&"resource", StringName(resource_id), quality, count))
	if _market_level >= 1:
		for item_variant in _inventory.call("get_equipment_catalog") as Array:
			var item := item_variant as Dictionary
			var item_id := StringName(item.get("id", ""))
			for quality in [&"common", &"rare", &"exceptional", &"legendary"]:
				var count := int(_inventory.call(
					"get_equipment_quality_count", item_id, quality
				))
				var slot := StringName(item.get("slot", ""))
				if (
					StringName(_inventory.call("get_equipped", slot)) == item_id
					and StringName(_inventory.call("get_equipped_quality", slot)) == quality
				):
					count -= 1
				if count <= 0:
					continue
				result.append(_sale_candidate(&"equipment", item_id, quality, count))
	return result


func list_for_sale(
	item_kind_or_id: StringName,
	item_id_or_quantity: Variant,
	quality_or_legacy_price: Variant = 0,
	quantity: int = 1
) -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	var item_kind := item_kind_or_id
	var item_id: StringName
	var quality: StringName
	if item_id_or_quantity is int:
		item_kind = &"equipment"
		item_id = item_kind_or_id
		quantity = int(item_id_or_quantity)
		quality = StringName(_inventory.call("get_highest_equipment_quality", item_id))
	else:
		item_id = StringName(String(item_id_or_quantity))
		quality = StringName(String(quality_or_legacy_price))
	if item_kind == &"equipment" and _market_level < 1:
		return _result(false, &"equipment_sales_locked")
	if not [&"resource", &"equipment"].has(item_kind) or quantity <= 0:
		return _result(false, &"listing_rejected")
	var base_value := int(_inventory.call(
		"get_resource_sale_value" if item_kind == &"resource" else "get_equipment_sale_value",
		item_id,
		quality
	))
	var unit_price := roundi(float(base_value) * _sale_multiplier)
	if unit_price <= 0:
		return _result(false, &"listing_rejected")
	var method := &"list_resource_for_sale" if item_kind == &"resource" else &"list_equipment_for_sale"
	if not bool(_inventory.call(method, item_id, quantity, unit_price, quality)):
		return _result(false, &"listing_rejected")
	return _result(true, &"listed", {
		"sale_slot": _inventory.call("get_sale_slot") as Dictionary,
	})


func resolve_sale() -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	var sale_result := _inventory.call("resolve_sale") as Dictionary
	if sale_result.is_empty():
		return _result(false, &"no_active_listing")
	return _result(true, &"sold", sale_result)


func cancel_sale() -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	if not bool(_inventory.call("cancel_sale")):
		return _result(false, &"no_active_listing")
	return _result(true, &"listing_canceled")


func _owns_required_tools(recipe: Dictionary) -> bool:
	for tool_variant in recipe.get("required_tools", []):
		if not bool(_inventory.call("owns_tool", StringName(tool_variant))):
			return false
	return true


func _quality_chances(
	base_quality: StringName,
	proficiency_level: int,
	awakened: bool
) -> Dictionary:
	var level := clampi(proficiency_level, 0, 5)
	var upgrade_chance := 0.12 + 0.04 * float(level) + _quality_bonus
	var exceptional_chance := 0.02 + 0.015 * float(level) + _quality_bonus * 0.5
	var legendary_chance := 0.03 if awakened else 0.0
	match base_quality:
		&"legendary":
			return {"common": 0.0, "rare": 0.0, "exceptional": 0.0, "legendary": 1.0}
		&"exceptional":
			return {
				"common": 0.0, "rare": 0.0,
				"exceptional": 1.0 - legendary_chance,
				"legendary": legendary_chance,
			}
		&"rare":
			return {
				"common": 0.0,
				"rare": 1.0 - upgrade_chance - legendary_chance,
				"exceptional": upgrade_chance,
				"legendary": legendary_chance,
			}
		_:
			return {
				"common": 1.0 - upgrade_chance - exceptional_chance - legendary_chance,
				"rare": upgrade_chance,
				"exceptional": exceptional_chance,
				"legendary": legendary_chance,
			}


func _roll_quality(chances: Dictionary) -> StringName:
	var roll := _quality_rng.randf()
	var cumulative := 0.0
	for quality in [&"common", &"rare", &"exceptional", &"legendary"]:
		cumulative += float(chances.get(String(quality), 0.0))
		if roll <= cumulative:
			return quality
	return &"legendary"


func _highest_quality_in(quality_counts: Dictionary) -> StringName:
	for quality in [&"legendary", &"exceptional", &"rare", &"common"]:
		if int(quality_counts.get(String(quality), 0)) > 0:
			return quality
	return &"common"


func _sale_candidate(
	item_kind: StringName,
	item_id: StringName,
	quality: StringName,
	count: int
) -> Dictionary:
	var base_value := int(_inventory.call(
		"get_resource_sale_value" if item_kind == &"resource" else "get_equipment_sale_value",
		item_id,
		quality
	))
	return {
		"item_kind": String(item_kind),
		"item_id": String(item_id),
		"quality": String(quality),
		"count": count,
		"unit_price": roundi(float(base_value) * _sale_multiplier),
	}


func _multiply_cost(cost: Dictionary, quantity: int) -> Dictionary:
	var result: Dictionary = {}
	for resource_variant in cost:
		result[String(resource_variant)] = int(cost[resource_variant]) * quantity
	return result


func _discounted_amount(base_amount: int, discount: float) -> int:
	if base_amount <= 0:
		return 0
	return maxi(1, floori(float(base_amount) * (1.0 - discount)))


func _material_quantity(base_quantity: int) -> int:
	return maxi(1, ceili(float(base_quantity) * _material_yield_multiplier))


func _refund(cost: Dictionary) -> void:
	for resource_variant in cost:
		_inventory.call(
			"add_resource",
			StringName(resource_variant),
			int(cost[resource_variant])
		)


func _result(ok: bool, code: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := payload.duplicate(true)
	result["ok"] = ok
	result["code"] = String(code)
	return result
