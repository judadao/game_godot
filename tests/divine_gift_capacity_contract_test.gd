extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "神賜資料必須可載入。")
	_expect(gifts.get_reward_choices(20).size() == 6, "有空位時，所有未持有神賜都能進入獎勵池。")

	for gift_id in ["resonant_grace", "prismatic_oath", "boundless_font"]:
		_expect(gifts.add_or_upgrade(gift_id), "前三項不同神賜必須能依序取得：%s" % gift_id)
	_expect(
		_inventory_ids(gifts.get_inventory())
			== ["resonant_grace", "prismatic_oath", "boundless_font"],
		"神賜持有清單必須保留取得順序。"
	)
	_expect(
		gifts.get_epithet_prefix() == "煉獄業火・天罰雷霆・萬毒蝕心的",
		"所有持有神賜前綴必須依取得順序自然累加。"
	)

	var full_snapshot := gifts.get_inventory()
	_expect(
		not gifts.add_or_upgrade("echoing_will")
			and gifts.get_inventory() == full_snapshot,
		"持有三項神賜後不得直接加入第四項，失敗也不得改動既有神賜。"
	)
	var full_choice_ids := _choice_ids(gifts.get_reward_choices(20))
	_expect(
		_string_set(full_choice_ids)
			== _string_set(["resonant_grace", "prismatic_oath", "boundless_font"]),
		"三格滿載時，獎勵只能提供已持有且未滿級的神賜。"
	)

	_expect(gifts.add_or_upgrade("resonant_grace"), "選到既有神賜必須升級。")
	_expect(
		_inventory_ids(gifts.get_inventory())
			== ["resonant_grace", "prismatic_oath", "boundless_font"]
			and int(gifts.get_gift("resonant_grace").get("level", 0)) == 2
			and int(gifts.get_gift("prismatic_oath").get("level", 0)) == 1
			and int(gifts.get_gift("boundless_font").get("level", 0)) == 1,
		"升級同項神賜不得覆蓋、重排或遺失其他持有項。"
	)
	var stacked := gifts.get_global_effects()
	_expect(
		int(stacked.get("combo_stack_bonus", 0)) == 1
			and int(stacked.get("combo_element_bonus", 0)) == 1
			and is_equal_approx(float(stacked.get("combo_ap_refund", 0.0)), 0.10)
			and is_equal_approx(float(stacked.get("finisher_damage_multiplier", 1.0)), 1.20),
		"所有持有神賜的不同效果必須同時完整疊加。"
	)

	_expect(gifts.add_or_upgrade("resonant_grace"), "煉獄恩典必須能升至 Lv.3。")
	_expect(gifts.add_or_upgrade("prismatic_oath"), "雷霆誓約必須能升至 Lv.2。")
	_expect(gifts.add_or_upgrade("prismatic_oath"), "雷霆誓約必須能升至 Lv.3。")
	_expect(
		_choice_ids(gifts.get_reward_choices(20)) == ["boundless_font"],
		"滿載時，滿級神賜必須離開升級獎勵池。"
	)

	var evolved := gifts.fuse_max_level("resonant_grace", "prismatic_oath")
	var evolved_id := String(evolved.get("id", ""))
	_expect(
		not evolved_id.is_empty()
			and _inventory_ids(gifts.get_inventory()) == ["boundless_font", evolved_id],
		"融合必須消耗兩項滿級神賜、產生一項昇華神賜並釋出一格。"
	)
	_expect(
		gifts.get_epithet_prefix() == "萬毒蝕心・天火雷劫的",
		"融合後必須以仍持有項與昇華神賜的取得順序組成合理中文前綴。"
	)
	var reopened_choice_ids := _choice_ids(gifts.get_reward_choices(20))
	_expect(
		reopened_choice_ids.has("echoing_will")
			and reopened_choice_ids.has("boundless_font")
			and reopened_choice_ids.has(evolved_id)
			and not reopened_choice_ids.has("resonant_grace")
			and not reopened_choice_ids.has("prismatic_oath"),
		"融合釋出空位後，未持有神賜與既有升級必須重回獎勵池，融合素材則永久離開。"
	)

	_expect(gifts.add_or_upgrade("echoing_will"), "融合釋出空位後必須能取得新神賜。")
	_expect(
		_inventory_ids(gifts.get_inventory()) == ["boundless_font", evolved_id, "echoing_will"]
			and gifts.get_epithet_prefix() == "萬毒蝕心・天火雷劫・無盡迴響的",
		"融合後新增神賜必須接續在取得順序與累加前綴末端。"
	)
	_expect(gifts.add_or_upgrade(evolved_id), "滿載時仍必須能升級既有昇華神賜。")
	_expect(
		_inventory_ids(gifts.get_inventory()) == ["boundless_font", evolved_id, "echoing_will"]
			and int(gifts.get_gift(evolved_id).get("level", 0)) == 2,
		"昇華神賜升級不得覆蓋、重排或遺失其他神賜。"
	)
	var post_fusion_stack := gifts.get_global_effects()
	_expect(
		float(post_fusion_stack.get("combo_ap_refund", 0.0)) > 0.0
			and int(post_fusion_stack.get("finisher_element_damage", 0)) > 0
			and float(post_fusion_stack.get("finisher_damage_multiplier", 1.0)) > 1.0,
		"融合後仍須完整疊加每一項現存神賜的效果。"
	)

	if _failures == 0:
		print("PASS: three-slot Divine Gift rewards, upgrades, fusion, stacking, and epithets")
	quit(1 if _failures > 0 else 0)


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
