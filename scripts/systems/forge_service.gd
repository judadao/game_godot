class_name ForgeService
extends RefCounted

const FORGE_METHODS: Array[Dictionary] = [
	{
		"id": "steady", "name": "穩鍛", "icon": "◆",
		"description": "穩定火候，成本與風險均衡。", "fee_multiplier": 1.0,
		"material_multiplier": 1.0, "success_chance": 0.92, "quality_bonus": 0.0,
	},
	{
		"id": "refine", "name": "精煉", "icon": "◇",
		"description": "多用素材反覆精煉，提高成功率與高品質機會。", "fee_multiplier": 1.25,
		"material_multiplier": 1.25, "success_chance": 0.97, "quality_bonus": 0.10,
	},
	{
		"id": "rush", "name": "急鍛", "icon": "▶",
		"description": "節省處理費，但瑕疵與廢料風險明顯提高。", "fee_multiplier": 0.65,
		"material_multiplier": 0.90, "success_chance": 0.72, "quality_bonus": -0.06,
	},
	{
		"id": "masterwork", "name": "名匠鍛造", "icon": "✦",
		"description": "只對覺醒圖紙開放，追求傳奇與意外神作。", "fee_multiplier": 1.60,
		"material_multiplier": 1.35, "success_chance": 0.88, "quality_bonus": 0.18,
		"requires_awakened": true, "masterpiece_chance": 0.08,
	},
]
const BLUEPRINT_SCHOOLS: Array[Dictionary] = [
	{"id": "balanced", "name": "衡鍛流", "icon": "◆", "description": "提高成功率，適合穩定生產。"},
	{"id": "keen_edge", "name": "銳鋒流", "icon": "▲", "description": "提高稀有與罕見品質機率。"},
	{"id": "efficient_form", "name": "省材流", "icon": "⬡", "description": "減少鍛造使用的素材。"},
	{"id": "merchant_signature", "name": "名印流", "icon": "◇", "description": "成品帶有名匠簽印，販售價提高。"},
	{"id": "elemental_resonance", "name": "共鳴流", "icon": "✦", "description": "提高元素成品與傳奇結果機率。"},
]
const MATERIAL_TRAITS := {
	&"autumn_wood": {"id": "supple", "name": "韌性木紋", "description": "稍微提高成功率與稀有品質。", "success_bonus": 0.03, "quality_bonus": 0.02},
	&"stone": {"id": "grounded", "name": "沉穩石質", "description": "降低失敗時完全化為廢料的機率。", "success_bonus": 0.02, "quality_bonus": 0.0},
	&"magic_shard": {"id": "arcane", "name": "導魔結晶", "description": "提高罕見品質的形成機會。", "success_bonus": 0.0, "quality_bonus": 0.04},
	&"autumn_core": {"id": "volatile", "name": "活性核心", "description": "更容易誕生神作，但火候較難控制。", "success_bonus": -0.03, "quality_bonus": 0.06},
}
const PRICE_STRATEGIES: Array[Dictionary] = [
	{"id": "quick", "name": "快速成交", "icon": "▶", "multiplier": 0.80, "sale_chance": 1.0, "description": "價格較低，普通顧客一定會買。"},
	{"id": "fair", "name": "公道定價", "icon": "◆", "multiplier": 1.0, "sale_chance": 1.0, "description": "按市場行情販售，收入穩定。"},
	{"id": "luxury", "name": "精品標價", "icon": "✦", "multiplier": 1.35, "sale_chance": 0.45, "description": "一般顧客可能離開；符合流言時必定高價成交。"},
]
const RUMORS: Array[Dictionary] = [
	{"id": "frontier_hunt", "title": "流言菲語：北境狩獵隊整裝", "item_kind": "equipment", "item_ids": ["hunter_bow"], "minimum_quality": "rare", "customer_id": "frontier_captain", "customer_name": "Frontier Captain Rhea", "multiplier": 1.80, "hint": "稀有以上獵弓會吸引北境隊長。"},
	{"id": "academy_collection", "title": "流言菲語：學院徵集導魔器", "item_kind": "equipment", "item_ids": ["apprentice_staff", "focus_amulet"], "minimum_quality": "rare", "customer_id": "academy_curator", "customer_name": "Academy Curator Elowen", "multiplier": 1.70, "hint": "稀有以上法杖或專注護符會吸引學院館長。"},
	{"id": "guard_rearmament", "title": "流言菲語：城防隊更新甲冑", "item_kind": "equipment", "item_ids": ["chain_armor"], "minimum_quality": "exceptional", "customer_id": "guard_commander", "customer_name": "Guard Commander Voss", "multiplier": 1.90, "hint": "罕見以上鎖甲會吸引守備隊長。"},
	{"id": "royal_collection", "title": "流言菲語：王室收藏家來訪", "item_kind": "equipment", "item_ids": [], "minimum_quality": "legendary", "customer_id": "royal_collector", "customer_name": "Royal Collector Yselle", "multiplier": 2.20, "hint": "任一傳奇裝備都可能讓王室收藏家親自到訪。"},
]

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


func set_random_seed(seed_value: int) -> void:
	_quality_rng.seed = seed_value


func get_forge_methods(recipe_id: StringName = StringName()) -> Array[Dictionary]:
	var awakened := false
	if not recipe_id.is_empty():
		var recipe := _catalog.call("get_recipe", recipe_id) as Dictionary
		var state := _inventory.call(
			"get_blueprint_proficiency", StringName(recipe.get("blueprint_id", ""))
		) as Dictionary
		awakened = bool(state.get("awakened", false))
	var result: Array[Dictionary] = []
	for method in FORGE_METHODS:
		var projection := method.duplicate(true)
		projection["unlocked"] = not bool(method.get("requires_awakened", false)) or awakened
		result.append(projection)
	return result


func get_blueprint_schools() -> Array[Dictionary]:
	return BLUEPRINT_SCHOOLS.duplicate(true)


func get_price_strategies() -> Array[Dictionary]:
	return PRICE_STRATEGIES.duplicate(true)


func get_active_rumors() -> Array[Dictionary]:
	return RUMORS.duplicate(true)


func get_sale_preview(
	item_kind: StringName,
	item_id: StringName,
	quality: StringName,
	price_strategy: StringName = &"fair"
) -> Dictionary:
	var strategy := _find_entry(PRICE_STRATEGIES, price_strategy)
	if strategy.is_empty():
		return {}
	var base_value := int(_inventory.call(
		"get_resource_sale_value" if item_kind == &"resource" else "get_equipment_sale_value",
		item_id,
		quality
	))
	if base_value <= 0:
		return {}
	var base_unit_price := roundi(
		float(base_value) * _sale_multiplier * _sale_school_multiplier(item_kind, item_id)
	)
	var rumor := _matching_rumor(item_kind, item_id, quality)
	return {
		"strategy": strategy,
		"rumor": rumor,
		"base_unit_price": base_unit_price,
		"unit_price": roundi(
			float(base_unit_price)
				* float(strategy.get("multiplier", 1.0))
				* float(rumor.get("multiplier", 1.0))
		),
		"sale_chance": 1.0 if not rumor.is_empty() else float(strategy.get("sale_chance", 1.0)),
	}


func get_blueprint_rework_cost(blueprint_id: StringName) -> Dictionary:
	var proficiency := _inventory.call("get_blueprint_proficiency", blueprint_id) as Dictionary
	if not bool(proficiency.get("awakened", false)):
		return {}
	return {"gold": 120, "magic_shard": 8}


func rework_blueprint_school(blueprint_id: StringName, school: StringName) -> Dictionary:
	var current := _inventory.call("get_blueprint_proficiency", blueprint_id) as Dictionary
	if not bool(current.get("awakened", false)):
		return _result(false, &"blueprint_not_awakened")
	if _find_entry(BLUEPRINT_SCHOOLS, school).is_empty():
		return _result(false, &"unknown_blueprint_school")
	if StringName(current.get("school", "balanced")) == school:
		return _result(false, &"blueprint_school_unchanged")
	var cost := get_blueprint_rework_cost(blueprint_id)
	if not bool(_inventory.call("spend_resources", cost)):
		return _result(false, &"insufficient_resources")
	if not bool(_inventory.call("set_blueprint_school", blueprint_id, school)):
		_refund(cost)
		return _result(false, &"blueprint_rework_failed")
	return _result(true, &"blueprint_reworked", {
		"blueprint_id": String(blueprint_id), "school": String(school), "cost": cost,
	})


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
		projection["blueprint_school"] = String(proficiency.get("school", "balanced"))
		projection["blueprint_school_profile"] = _find_entry(
			BLUEPRINT_SCHOOLS, StringName(proficiency.get("school", "balanced"))
		)
		projection["forge_methods"] = get_forge_methods(StringName(projection.get("id", "")))
		projection["material_trait_profile"] = _material_trait_for_recipe(projection)
		projection["quality_chances"] = _quality_chances(
			StringName(projection.get("quality", "common")),
			int(proficiency.get("level", 0)),
			bool(proficiency.get("awakened", false)),
			_school_quality_bonus(StringName(proficiency.get("school", "balanced")))
		)
		result.append(projection)
	return result


func get_craft_preview(recipe_id: StringName, method_id: StringName = &"steady") -> Dictionary:
	if not is_configured():
		return {}
	var recipe := _catalog.call("get_recipe", recipe_id) as Dictionary
	var method := _method_by_id(method_id)
	if recipe.is_empty() or method.is_empty():
		return {}
	var blueprint_id := StringName(recipe.get("blueprint_id", ""))
	var proficiency := _inventory.call("get_blueprint_proficiency", blueprint_id) as Dictionary
	var awakened := bool(proficiency.get("awakened", false))
	var unlocked := not bool(method.get("requires_awakened", false)) or awakened
	var school := StringName(proficiency.get("school", "balanced"))
	var material_trait := _material_trait_for_recipe(recipe)
	var material_multiplier := float(method.get("material_multiplier", 1.0))
	if school == &"efficient_form":
		material_multiplier *= 0.85
	var cost := _scaled_cost(recipe.get("cost", {}) as Dictionary, material_multiplier)
	var fee := _discounted_amount(
		ceili(float(recipe.get("processing_fee", 0)) * float(method.get("fee_multiplier", 1.0))),
		_processing_fee_discount
	)
	cost["gold"] = fee
	var success_chance := clampf(
		float(method.get("success_chance", 0.9))
			+ float(material_trait.get("success_bonus", 0.0))
			+ (0.04 if school == &"balanced" else 0.0),
		0.35,
		0.995
	)
	var quality_bonus := (
		float(method.get("quality_bonus", 0.0))
		+ float(material_trait.get("quality_bonus", 0.0))
		+ _school_quality_bonus(school)
	)
	var masterpiece_chance := float(method.get("masterpiece_chance", 0.0))
	if school == &"elemental_resonance":
		masterpiece_chance += 0.03
	success_chance = minf(success_chance, 1.0 - masterpiece_chance)
	return {
		"recipe_id": String(recipe_id),
		"method_id": String(method_id),
		"method": method,
		"unlocked": unlocked,
		"cost": cost,
		"processing_fee": fee,
		"success_chance": success_chance,
		"quality_chances": _quality_chances(
			StringName(recipe.get("quality", "common")),
			int(proficiency.get("level", 0)),
			awakened,
			quality_bonus
		),
		"outcome_chances": _process_outcome_chances(method_id, success_chance, masterpiece_chance),
		"material_trait": String(material_trait.get("id", "")),
		"material_trait_profile": material_trait,
		"blueprint_school": String(school),
		"blueprint_school_profile": _find_entry(BLUEPRINT_SCHOOLS, school),
	}


func craft(
	recipe_id: StringName,
	quantity: int = 1,
	method_id: StringName = &"steady"
) -> Dictionary:
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
	var preview := get_craft_preview(recipe_id, method_id)
	if preview.is_empty():
		return _result(false, &"unknown_forge_method")
	if not bool(preview.get("unlocked", false)):
		return _result(false, &"forge_method_locked")
	var total_cost := _multiply_cost(preview.get("cost", {}) as Dictionary, quantity)
	var processing_fee := int(preview.get("processing_fee", 0)) * quantity
	if not bool(_inventory.call("spend_resources", total_cost)):
		return _result(false, &"insufficient_resources")
	var result_kind := StringName(recipe.get("result_kind", ""))
	var result_id := StringName(recipe.get("result_id", ""))
	var blueprint_id := StringName(recipe.get("blueprint_id", ""))
	var chances := preview.get("quality_chances", {}) as Dictionary
	var success_chance := float(preview.get("success_chance", 0.9))
	var method := preview.get("method", {}) as Dictionary
	var masterpiece_chance := float(method.get("masterpiece_chance", 0.0))
	if StringName(preview.get("blueprint_school", "")) == &"elemental_resonance":
		masterpiece_chance += 0.03
	var quality_counts: Dictionary = {}
	var outcome_counts: Dictionary = {}
	var produced_quantity := 0
	for _craft_index in quantity:
		var outcome := _roll_process_outcome(method_id, success_chance, masterpiece_chance)
		outcome_counts[String(outcome)] = int(outcome_counts.get(String(outcome), 0)) + 1
		if outcome == &"scrap":
			continue
		var rolled_quality := (
			&"legendary" if outcome == &"accidental_masterpiece"
			else &"common" if outcome == &"flawed"
			else _roll_quality(chances)
		)
		quality_counts[String(rolled_quality)] = int(
			quality_counts.get(String(rolled_quality), 0)
		) + 1
		produced_quantity += 1
	if int(outcome_counts.get("scrap", 0)) > 0:
		_grant_scrap_return(recipe.get("cost", {}) as Dictionary, int(outcome_counts["scrap"]))
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
		var updated_proficiency := (
			_inventory.call("record_blueprint_craft", blueprint_id, produced_quantity) as Dictionary
			if produced_quantity > 0 else _inventory.call("get_blueprint_proficiency", blueprint_id) as Dictionary
		)
		return _result(true, &"crafted", {
			"result_kind": "equipment",
			"result_id": String(result_id),
			"quantity": produced_quantity,
			"quality": String(_highest_quality_in(quality_counts)),
			"quality_counts": quality_counts,
			"outcome_counts": outcome_counts,
			"forge_method": String(method_id),
			"material_trait": preview.get("material_trait", ""),
			"proficiency": updated_proficiency,
			"blueprint_awakened_now": bool(updated_proficiency.get("awakened_now", false)),
			"material_tier": String(recipe.get("material_tier", "normal")),
			"processing_fee": processing_fee,
			"proficiency_advanced": produced_quantity > 0,
		})
	if result_kind == &"sword_soul":
		var updated_proficiency := (
			_inventory.call("record_blueprint_craft", blueprint_id, produced_quantity) as Dictionary
			if produced_quantity > 0 else _inventory.call("get_blueprint_proficiency", blueprint_id) as Dictionary
		)
		var payload := {
			"result_kind": "sword_soul",
			"result_id": String(result_id),
			"quantity": produced_quantity,
			"quality": String(_highest_quality_in(quality_counts)),
			"quality_counts": quality_counts,
			"outcome_counts": outcome_counts,
			"forge_method": String(method_id),
			"material_trait": preview.get("material_trait", ""),
			"proficiency": updated_proficiency,
			"blueprint_awakened_now": bool(updated_proficiency.get("awakened_now", false)),
			"material_tier": String(recipe.get("material_tier", "normal")),
			"processing_fee": processing_fee,
			"proficiency_advanced": produced_quantity > 0,
		}
		if produced_quantity > 0:
			payload["intent"] = "grant_sword_soul"
		return _result(
			true,
			&"intent_ready" if produced_quantity > 0 else &"craft_scrap",
			payload
		)
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
	quantity: int = 1,
	price_strategy: StringName = &"fair"
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
	var strategy := _find_entry(PRICE_STRATEGIES, price_strategy)
	if strategy.is_empty():
		return _result(false, &"unknown_price_strategy")
	var base_unit_price := roundi(
		float(base_value) * _sale_multiplier * _sale_school_multiplier(item_kind, item_id)
	)
	var rumor := _matching_rumor(item_kind, item_id, quality)
	var rumor_multiplier := float(rumor.get("multiplier", 1.0))
	var unit_price := roundi(
		float(base_unit_price)
			* float(strategy.get("multiplier", 1.0))
			* rumor_multiplier
	)
	if unit_price <= 0:
		return _result(false, &"listing_rejected")
	var method := &"list_resource_for_sale" if item_kind == &"resource" else &"list_equipment_for_sale"
	var metadata := {
		"base_unit_price": base_unit_price,
		"price_strategy": String(price_strategy),
		"price_multiplier": float(strategy.get("multiplier", 1.0)),
		"sale_chance": 1.0 if not rumor.is_empty() else float(strategy.get("sale_chance", 1.0)),
		"rumor_id": String(rumor.get("id", "")),
		"rumor_title": String(rumor.get("title", "")),
		"customer_id": String(rumor.get("customer_id", "ordinary_customer")),
		"customer_name": String(rumor.get("customer_name", "Town Customer")),
		"customer_state": "ready",
		"rumor_multiplier": rumor_multiplier,
	}
	if not bool(_inventory.call(method, item_id, quantity, unit_price, quality, metadata)):
		return _result(false, &"listing_rejected")
	return _result(true, &"listed", {
		"sale_slot": _inventory.call("get_sale_slot") as Dictionary,
	})


func resolve_sale() -> Dictionary:
	if not is_configured():
		return _result(false, &"not_configured")
	var slot := _inventory.call("get_sale_slot") as Dictionary
	if slot.is_empty():
		return _result(false, &"no_active_listing")
	if StringName(slot.get("customer_state", "ready")) == &"declined":
		return _result(false, &"customer_declined_locked")
	if _quality_rng.randf() > float(slot.get("sale_chance", 1.0)):
		_inventory.call("mark_sale_declined")
		return _result(false, &"customer_declined", {
			"customer_name": "Town Customer",
			"price_strategy": slot.get("price_strategy", "fair"),
		})
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
	awakened: bool,
	extra_quality_bonus: float = 0.0
) -> Dictionary:
	var level := clampi(proficiency_level, 0, 5)
	var upgrade_chance := clampf(
		0.12 + 0.04 * float(level) + _quality_bonus + extra_quality_bonus,
		0.01,
		0.72
	)
	var exceptional_chance := clampf(
		0.02 + 0.015 * float(level) + _quality_bonus * 0.5 + extra_quality_bonus * 0.45,
		0.0,
		0.35
	)
	var legendary_chance := clampf(
		(0.03 + maxf(0.0, extra_quality_bonus) * 0.15) if awakened else 0.0,
		0.0,
		0.18
	)
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
			var rare_upgrade := minf(0.80, upgrade_chance + extra_quality_bonus * 0.25)
			return {
				"common": 0.0,
				"rare": maxf(0.0, 1.0 - rare_upgrade - legendary_chance),
				"exceptional": rare_upgrade,
				"legendary": legendary_chance,
			}
		_:
			var total_upgrade := upgrade_chance + exceptional_chance + legendary_chance
			if total_upgrade > 0.92:
				var scale := 0.92 / total_upgrade
				upgrade_chance *= scale
				exceptional_chance *= scale
				legendary_chance *= scale
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


func _method_by_id(method_id: StringName) -> Dictionary:
	return _find_entry(FORGE_METHODS, method_id)


func _find_entry(entries: Array, target_id: StringName) -> Dictionary:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if StringName(entry.get("id", "")) == target_id:
			return entry.duplicate(true)
	return {}


func _material_trait_for_recipe(recipe: Dictionary) -> Dictionary:
	var cost := recipe.get("cost", {}) as Dictionary
	var primary_id: StringName
	var primary_amount := -1
	for resource_variant in cost:
		var amount := int(cost[resource_variant])
		if amount > primary_amount:
			primary_id = StringName(resource_variant)
			primary_amount = amount
	return (MATERIAL_TRAITS.get(primary_id, {}) as Dictionary).duplicate(true)


func _school_quality_bonus(school: StringName) -> float:
	match school:
		&"keen_edge":
			return 0.08
		&"elemental_resonance":
			return 0.05
		_:
			return 0.0


func _scaled_cost(cost: Dictionary, multiplier: float) -> Dictionary:
	var result: Dictionary = {}
	for resource_variant in cost:
		result[String(resource_variant)] = maxi(
			1, ceili(float(cost[resource_variant]) * multiplier)
		)
	return result


func _process_outcome_chances(
	method_id: StringName,
	success_chance: float,
	masterpiece_chance: float
) -> Dictionary:
	var failure := maxf(0.0, 1.0 - success_chance - masterpiece_chance)
	var scrap_share := 0.45 if method_id == &"rush" else (0.05 if method_id == &"refine" else 0.0)
	var flawed_share := maxf(0.0, 0.68 - scrap_share)
	var prototype_share := 1.0 - scrap_share - flawed_share
	return {
		"success": success_chance,
		"accidental_masterpiece": masterpiece_chance,
		"flawed": failure * flawed_share,
		"prototype": failure * prototype_share,
		"scrap": failure * scrap_share,
	}


func _roll_process_outcome(
	method_id: StringName,
	success_chance: float,
	masterpiece_chance: float
) -> StringName:
	var roll := _quality_rng.randf()
	if roll < masterpiece_chance:
		return &"accidental_masterpiece"
	if roll < masterpiece_chance + success_chance:
		return &"success"
	var failure_roll := _quality_rng.randf()
	if method_id == &"rush" and failure_roll < 0.45:
		return &"scrap"
	if method_id == &"refine" and failure_roll < 0.05:
		return &"scrap"
	return &"flawed" if failure_roll < 0.68 else &"prototype"


func _grant_scrap_return(base_cost: Dictionary, scrap_count: int) -> void:
	if scrap_count <= 0:
		return
	for resource_variant in base_cost:
		var returned := floori(float(base_cost[resource_variant]) * 0.25) * scrap_count
		if returned > 0:
			_inventory.call("add_resource", StringName(resource_variant), returned)


func _matching_rumor(
	item_kind: StringName,
	item_id: StringName,
	quality: StringName
) -> Dictionary:
	for rumor in RUMORS:
		if StringName(rumor.get("item_kind", "")) != item_kind:
			continue
		var item_ids := rumor.get("item_ids", []) as Array
		if not item_ids.is_empty() and not item_ids.has(String(item_id)):
			continue
		if _quality_rank(quality) < _quality_rank(StringName(rumor.get("minimum_quality", "common"))):
			continue
		return rumor.duplicate(true)
	return {}


func _quality_rank(quality: StringName) -> int:
	return [&"common", &"rare", &"exceptional", &"legendary"].find(quality)


func _sale_school_multiplier(item_kind: StringName, item_id: StringName) -> float:
	if item_kind != &"equipment":
		return 1.0
	for recipe_variant in _catalog.call("get_all_recipes") as Array:
		var recipe := recipe_variant as Dictionary
		if StringName(recipe.get("result_id", "")) != item_id:
			continue
		var state := _inventory.call(
			"get_blueprint_proficiency", StringName(recipe.get("blueprint_id", ""))
		) as Dictionary
		return 1.15 if StringName(state.get("school", "")) == &"merchant_signature" else 1.0
	return 1.0


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
