extends SceneTree

const InventoryManagerScript = preload("res://scripts/systems/inventory_manager.gd")

const EXPECTED_FINISHERS := {
	"battle_rhythm,battle_rhythm,battle_rhythm": "戰律希聲",
	"sweeping_reach,sweeping_reach,sweeping_reach": "天際流光",
	"quickened_cadence,quickened_cadence,quickened_cadence": "驟雨繁音",
	"giant_arc,giant_arc,giant_arc": "月輪垂光",
	"echo_volley,echo_volley,echo_volley": "千羽相應",
	"guard,guard,guard": "靜岳無移",
	"iron_skin,iron_skin,iron_skin": "石環守一",
	"iron_bone,iron_bone,iron_bone": "金骨含章",
	"fleet_footwork,fleet_footwork,fleet_footwork": "扶搖無跡",
	"arcane_breath,arcane_breath,arcane_breath": "綿息若存",
	"deep_reservoir,deep_reservoir,deep_reservoir": "靈泉不窮",
	"stoneguard_combo,stoneguard_combo,stoneguard_combo": "返照歸身",
	"flame_imbue,flame_imbue,flame_imbue": "流火照夜",
	"frostburst_imbue,frostburst_imbue,frostburst_imbue": "履霜凝華",
	"storm_charge,storm_charge,storm_charge": "雷動春醒",
	"venom_edge,venom_edge,venom_edge": "蘭芷成蝕",
	"healing_light,healing_light,healing_light": "朝光載陽",
	"renewal,renewal,renewal": "春靈來復",
	"blood_pact_combo,blood_pact_combo,blood_pact_combo": "同枝共脈",
	"verdant_renewal,verdant_renewal,verdant_renewal": "青庭長春",
	"battle_rhythm,quickened_cadence,echo_volley": "希聲繁羽",
	"sweeping_reach,giant_arc,echo_volley": "天光回羽",
	"guard,iron_skin,stoneguard_combo": "守一返照",
	"fleet_footwork,arcane_breath,deep_reservoir": "扶搖泉湧",
	"flame_imbue,frostburst_imbue,storm_charge": "水火既濟",
	"flame_imbue,echo_volley,storm_charge": "流火雷音",
	"frostburst_imbue,venom_edge,flame_imbue": "霜蘭流火",
	"healing_light,renewal,verdant_renewal": "春庭載陽",
	"blood_pact_combo,healing_light,renewal": "同脈來復",
	"guard,blood_pact_combo,stoneguard_combo": "守一共脈",
	"fleet_footwork,sweeping_reach,giant_arc": "扶搖月輪",
	"arcane_breath,storm_charge,echo_volley": "綿息雷音",
}

const OB_COMBO_IDS := [
	"battle_rhythm", "sweeping_reach", "quickened_cadence", "giant_arc", "echo_volley",
	"guard", "iron_skin", "iron_bone", "fleet_footwork", "arcane_breath",
	"deep_reservoir", "stoneguard_combo", "flame_imbue", "frostburst_imbue",
	"storm_charge", "venom_edge", "healing_light", "renewal", "blood_pact_combo",
	"verdant_renewal",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_complete_finisher_catalog()
	_test_chinese_combo_and_equipment_copy()
	_test_equipment_level_fifteen_contract()
	quit(0 if _failures == 0 else 1)


func _test_complete_finisher_catalog() -> void:
	var catalog := ComboFinisherCatalog.new()
	_expect(catalog.load_catalog(), "終結技資料必須可載入。")
	var recipes := catalog.get_all_recipes()
	_expect(recipes.size() == 32, "OB 的 20 組同卡與 12 組跨卡終結技必須全部進入 runtime。")
	for recipe in recipes:
		var sequence_entries := recipe.get("sequence", []) as Array
		var sequence := ",".join(PackedStringArray(sequence_entries))
		_expect(EXPECTED_FINISHERS.has(sequence), "終結技配方必須精確符合 OB：%s" % sequence)
		_expect(
			String(recipe.get("name", "")) == String(EXPECTED_FINISHERS.get(sequence, "")),
			"終結技必須使用 OB 定案中文名：%s" % sequence
		)
		_expect(not String(recipe.get("description", "")).is_empty(), "終結技必須有中文說明。")
		_expect(String(recipe.get("description", "")).contains("的") or _contains_han(String(recipe.get("description", ""))), "終結技說明不可保留全英文。")
		var required_entries := recipe.get("required_skills", []) as Array
		var expected_required := _string_set(sequence_entries)
		var actual_required := _string_set(required_entries)
		_expect(
			actual_required == expected_required
				and required_entries.size() == actual_required.size(),
			"終結技 required_skills 必須精確等於 sequence 的去重集合：%s" % sequence
		)
	for sequence in EXPECTED_FINISHERS:
		_expect(not catalog.match_sequence(String(sequence).split(",")).is_empty(), "每個 OB 配方都必須能依順序命中：%s" % sequence)


func _test_chinese_combo_and_equipment_copy() -> void:
	var cards := CardDatabase.new()
	_expect(cards.load_catalog(), "卡牌資料必須可載入。")
	for card in cards.get_all_cards():
		var card_id := String(card.get("id", ""))
		_expect(_contains_han(String(card.get("name_zh", ""))), "卡牌必須提供中文顯示名：%s" % card_id)
		_expect(_contains_han(String(card.get("description_zh", ""))), "卡牌必須提供中文顯示說明：%s" % card_id)
		for upgrade_variant in card.get("upgrade_effects", []) as Array:
			var upgrade := upgrade_variant as Dictionary
			_expect(
				_contains_han(String(upgrade.get("description_zh", ""))),
				"卡牌升級說明必須使用中文：%s Lv.%d" % [card_id, int(upgrade.get("level", 0))]
			)
	for card_id in OB_COMBO_IDS:
		_expect(not cards.get_card(card_id).is_empty(), "OB Combo 必須存在：%s" % card_id)
	var skills := SkillRecipeManager.new()
	_expect(skills.load_catalog("res://data/skills.json"), "招式資料必須可載入。")
	var skill_document := _read_json_dictionary("res://data/skills.json")
	for skill_variant in skill_document.get("skills", []) as Array:
		var skill_id := String((skill_variant as Dictionary).get("id", ""))
		var skill := skills.get_recipe(skill_id)
		_expect(not skill.is_empty(), "招式必須能由玩家資料庫讀取：%s" % skill_id)
		_expect(_contains_han(String(skill.get("name_zh", ""))), "招式必須提供中文顯示名：%s" % skill_id)
	var inventory = InventoryManagerScript.new()
	for item_variant in inventory.get_equipment_catalog():
		var item := item_variant as Dictionary
		_expect(_contains_han(String(item.get("name_zh", ""))), "裝備必須提供中文顯示名：%s" % item.get("id", ""))
		_expect(_contains_han(String(item.get("description_zh", ""))), "裝備必須有中文物品敘述：%s" % item.get("id", ""))
		_expect(_contains_han(String((item.get("special_ability", {}) as Dictionary).get("description_zh", ""))), "裝備能力必須有中文顯示說明：%s" % item.get("id", ""))


func _test_equipment_level_fifteen_contract() -> void:
	var inventory = InventoryManagerScript.new()
	_expect(inventory.has_method("get_max_equipment_level"), "裝備系統必須公開正式等級上限。")
	_expect(inventory.has_method("get_implemented_effect_level_cap"), "裝備系統必須公開目前已實作效果上限。")
	var max_level := int(inventory.call("get_max_equipment_level")) if inventory.has_method("get_max_equipment_level") else 0
	_expect(max_level == 15, "現行裝備的正式 runtime 上限必須補至 Lv.15。")
	var implemented_cap := int(inventory.call("get_implemented_effect_level_cap", &"iron_sword")) if inventory.has_method("get_implemented_effect_level_cap") else 0
	_expect(implemented_cap == 3, "未定案的 Lv.4–15 效果與成本不得假裝已實作。")
	var serialized := inventory.to_dict()
	serialized["equipment_counts"] = {"iron_sword": 1}
	serialized["equipped"] = {"weapon": "iron_sword", "armor": "", "accessory": ""}
	serialized["equipment_levels"] = {"iron_sword": implemented_cap}
	var level_three = InventoryManagerScript.new()
	level_three.apply_dict(serialized)
	var level_three_snapshot := level_three.to_dict()
	_expect(
		level_three.get_equipment_upgrade_cost(&"iron_sword").is_empty(),
		"Lv.3 後不得虛構尚未定案的逐級素材成本。"
	)
	_expect(
		not level_three.upgrade_equipment(&"iron_sword")
			and level_three.to_dict() == level_three_snapshot,
		"沒有正式 Lv.4 配方時，升級必須失敗且不得改動資源或裝備。"
	)
	var level_three_effects := level_three.get_effect_totals()
	serialized["equipment_levels"] = {"iron_sword": 15}
	var restored = InventoryManagerScript.new()
	restored.apply_dict(serialized)
	_expect(restored.get_equipment_level(&"iron_sword") == 15, "Lv.15 裝備必須能安全存讀。")
	_expect(
		restored.get_effect_totals() == level_three_effects,
		"Lv.15 存檔在後續效果未實作前，戰鬥數值必須維持 Lv.3 上限。"
	)
	serialized["equipment_levels"] = {"iron_sword": 99}
	restored.apply_dict(serialized)
	_expect(restored.get_equipment_level(&"iron_sword") == 15, "超出上限的舊存檔必須安全限制在 Lv.15。")


func _contains_han(value: String) -> bool:
	for character in value:
		var code := character.unicode_at(0)
		if code >= 0x3400 and code <= 0x9fff:
			return true
	return false


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value_variant in values:
		var value := String(value_variant)
		if not value.is_empty():
			result[value] = true
	return result


func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
