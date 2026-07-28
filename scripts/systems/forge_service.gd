class_name ForgeService
extends RefCounted

var _catalog: RefCounted
var _inventory: RefCounted
var _flame_tier := 0
var _blacksmith_level := 0


func _init(catalog: RefCounted, inventory: RefCounted) -> void:
	_catalog = catalog
	_inventory = inventory


func is_configured() -> bool:
	return (
		_catalog != null
		and _inventory != null
		and bool(_catalog.call("is_loaded"))
		and bool(_inventory.call("is_loaded"))
	)


func set_progression_levels(flame_tier: int, blacksmith_level: int) -> void:
	_flame_tier = maxi(0, flame_tier)
	_blacksmith_level = maxi(0, blacksmith_level)


func get_shop_offers(shop_id: StringName) -> Array[Dictionary]:
	if not is_configured():
		return []
	var offers := _catalog.call("get_shop_offers", shop_id, _flame_tier) as Array
	var result: Array[Dictionary] = []
	for offer_variant in offers:
		var offer := (offer_variant as Dictionary).duplicate(true)
		var product_kind := StringName(offer.get("product_kind", ""))
		var product_id := StringName(offer.get("product_id", ""))
		if product_kind == &"tool":
			offer["owned"] = bool(_inventory.call("owns_tool", product_id))
		elif product_kind == &"blueprint":
			offer["owned"] = bool(_inventory.call("owns_blueprint", product_id))
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
	if not bool(_catalog.call("is_offer_unlocked", offer_id, _flame_tier)):
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
	var total_price := int(offer.get("price", 0)) * quantity
	if not bool(_inventory.call("spend_resources", {&"gold": total_price})):
		return _result(false, &"insufficient_gold")
	var granted := false
	match product_kind:
		&"resource":
			granted = bool(_inventory.call(
				"add_resource",
				product_id,
				int(offer.get("quantity", 1)) * quantity
			))
		&"tool":
			granted = bool(_inventory.call("grant_tool", product_id))
		&"blueprint":
			granted = bool(_inventory.call("grant_blueprint", product_id))
	if not granted:
		_inventory.call("add_resource", &"gold", total_price)
		return _result(false, &"grant_failed")
	return _result(true, &"purchased", {
		"offer_id": String(offer_id),
		"product_kind": String(product_kind),
		"product_id": String(product_id),
		"quantity": int(offer.get("quantity", 1)) * quantity,
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
		result.append(recipe.duplicate(true))
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
	if not bool(_inventory.call("spend_resources", total_cost)):
		return _result(false, &"insufficient_resources")
	var result_kind := StringName(recipe.get("result_kind", ""))
	var result_id := StringName(recipe.get("result_id", ""))
	if result_kind == &"equipment":
		if not bool(_inventory.call("add_equipment_count", result_id, quantity)):
			_refund(total_cost)
			return _result(false, &"craft_failed")
		return _result(true, &"crafted", {
			"result_kind": "equipment",
			"result_id": String(result_id),
			"quantity": quantity,
		})
	if result_kind == &"sword_soul":
		return _result(true, &"intent_ready", {
			"intent": "grant_sword_soul",
			"result_kind": "sword_soul",
			"result_id": String(result_id),
			"quantity": quantity,
		})
	_refund(total_cost)
	return _result(false, &"invalid_result")


func list_for_sale(item_id: StringName, quantity: int, unit_price: int) -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	if not bool(_inventory.call("list_equipment_for_sale", item_id, quantity, unit_price)):
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


func _multiply_cost(cost: Dictionary, quantity: int) -> Dictionary:
	var result: Dictionary = {}
	for resource_variant in cost:
		result[String(resource_variant)] = int(cost[resource_variant]) * quantity
	return result


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
