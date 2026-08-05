extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "神賜資料必須可載入。")
	_expect(gifts.get_reward_choices(20).size() == 20, "有空位時，二十種未持有神賜都能進入獎勵池。")

	for gift_id in ["resonant_grace", "prismatic_oath", "boundless_font", "eternal_memory"]:
		_expect(gifts.add_or_upgrade(gift_id), "四項不同神賜必須能依序取得：%s" % gift_id)
	_expect(
		_inventory_ids(gifts.get_inventory())
			== ["resonant_grace", "prismatic_oath", "boundless_font", "eternal_memory"],
		"四個神賜欄必須保留取得順序。"
	)
	_expect(
		gifts.get_epithet_prefix() == "煉獄業火・天罰雷霆・萬毒蝕心・絕對零度的",
		"四個持有神賜的前綴與能力必須全部生效。"
	)

	var full_snapshot := gifts.get_inventory()
	_expect(
		not gifts.add_or_upgrade("celestial_momentum")
			and gifts.get_inventory() == full_snapshot,
		"四格滿載後不得加入第五項，也不得改動既有神賜。"
	)
	_expect(
		_string_set(_choice_ids(gifts.get_reward_choices(20)))
			== _string_set(["resonant_grace", "prismatic_oath", "boundless_font", "eternal_memory"]),
		"四格滿載時，獎勵只能提供已持有且未滿級的神賜。"
	)

	_expect(gifts.add_or_upgrade("resonant_grace"), "選到既有神賜必須升級。")
	_expect(gifts.add_or_upgrade("resonant_grace"), "煉獄恩典必須能升至 Lv.3。")
	_expect(gifts.add_or_upgrade("prismatic_oath"), "雷霆誓約必須能升至 Lv.2。")
	_expect(gifts.add_or_upgrade("prismatic_oath"), "雷霆誓約必須能升至 Lv.3。")
	var stacked := gifts.get_global_effects()
	_expect(
		int(stacked.get("combo_stack_bonus", 0)) >= 2
			and int(stacked.get("combo_element_bonus", 0)) >= 3
			and is_equal_approx(float(stacked.get("combo_ap_refund", 0.0)), 0.10)
			and int(stacked.get("combo_stack_cap_bonus", 0)) == 2,
		"四格內所有神賜效果必須同時完整疊加。"
	)

	var evolved := gifts.fuse_max_level("resonant_grace", "prismatic_oath")
	var evolved_id := String(evolved.get("id", ""))
	_expect(
		not evolved_id.is_empty()
			and _inventory_ids(gifts.get_inventory()) == ["boundless_font", "eternal_memory", evolved_id],
		"融合必須消耗兩項滿級神賜、產生一項昇華神賜並釋出一格。"
	)
	var reopened_choice_ids := _choice_ids(gifts.get_reward_choices(20))
	_expect(
		reopened_choice_ids.has("echoing_will")
			and reopened_choice_ids.has("celestial_momentum")
			and not reopened_choice_ids.has("resonant_grace")
			and not reopened_choice_ids.has("prismatic_oath"),
		"融合後新品必須重回獎勵池，已消耗素材則永久離開。"
	)
	_expect(gifts.add_or_upgrade("echoing_will"), "融合釋出空位後必須能取得新神賜。")
	_expect(gifts.add_or_upgrade(evolved_id), "四格滿載時仍必須能升級既有昇華神賜。")
	_expect(
		_inventory_ids(gifts.get_inventory()) == ["boundless_font", "eternal_memory", evolved_id, "echoing_will"]
			and int(gifts.get_gift(evolved_id).get("level", 0)) == 2,
		"昇華神賜升級不得覆蓋、重排或遺失其他神賜。"
	)
	_verify_three_fusions()

	if _failures == 0:
		print("PASS: four active Divine Gift slots can resolve all three fusions")
	quit(1 if _failures > 0 else 0)


func _verify_three_fusions() -> void:
	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "三融合進度測試必須能載入神賜資料。")
	var pairs := [
		["resonant_grace", "prismatic_oath"],
		["echoing_will", "eternal_memory"],
		["boundless_font", "celestial_momentum"],
	]
	for pair_variant in pairs:
		var pair := pair_variant as Array
		for gift_id_variant in pair:
			var gift_id := String(gift_id_variant)
			for _level in 3:
				_expect(gifts.add_or_upgrade(gift_id), "融合素材必須可升滿：%s" % gift_id)
		var evolved := gifts.fuse_max_level(String(pair[0]), String(pair[1]))
		_expect(not evolved.is_empty(), "每一組滿級素材都必須能完成融合。")
	_expect(
		gifts.get_inventory().size() == 3
			and gifts.get_background_attack_profiles().size() == 3,
		"選定的六個基礎 Blessing 必須能收束成三個具專屬背景攻擊的進化 Blessing。"
	)
	for gift in gifts.get_inventory():
		_expect(
			String(gift.get("kind", "")) == "evolved"
				and int(gift.get("level", 0)) == 1,
			"八分鐘進度只保證完成三次融合，不強制進化結果升滿。"
		)


func _inventory_ids(inventory: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for gift in inventory:
		result.append(String(gift.get("id", "")))
	return result


func _choice_ids(choices: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for choice in choices:
		result.append(String(choice.get("gift_id", "")))
	return result


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[String(value)] = true
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
