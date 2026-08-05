extends SceneTree

const BASE_GIFT_COUNT := 8

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "神賜資料必須可載入。")
	var rewards := gifts.get_reward_choices(20)
	_expect(rewards.size() == BASE_GIFT_COUNT, "未持有神賜時必須投影全部八個 base gift 選項。")
	var chinese_names: Dictionary = {}
	var motifs: Dictionary = {}
	var status_ids: Dictionary = {}
	for reward in rewards:
		var gift_id := String(reward.get("gift_id", ""))
		var name := String(reward.get("name", "")).strip_edges()
		var description := String(reward.get("description", "")).strip_edges()
		var current_effects := reward.get("current_effects", {}) as Dictionary
		var next_effects := reward.get("next_effects", {}) as Dictionary
		var mutations := reward.get("finisher_mutations", {}) as Dictionary
		_expect(String(reward.get("kind", "")) == "base", "初始神賜獎勵必須都是 base gift：%s" % gift_id)
		_expect(not String(reward.get("element", "")).is_empty(), "神賜選項必須投影元素：%s" % gift_id)
		_expect(reward.has("current_effects") and current_effects.is_empty(), "未持有神賜的目前效果必須明確投影為空：%s" % gift_id)
		_expect(
			reward.has("next_effects") and _numeric_value_count(next_effects) >= 2,
			"每個 base gift 的下一級必須至少提供兩項可解釋數值：%s" % gift_id
		)
		_expect(
			reward.has("finisher_mutations")
				and mutations.size() >= 2
				and _has_interpretable_mechanic(mutations),
			"每個 base gift 必須提供可解釋的終結技 mechanics：%s" % gift_id
		)
		_expect(_contains_han(name), "神賜選項名稱不得退回英文：%s" % gift_id)
		_expect(_contains_han(description), "神賜選項說明不得退回英文：%s" % gift_id)
		_expect(not chinese_names.has(name), "神賜中文名稱必須唯一：%s" % name)
		chinese_names[name] = gift_id
		var motif := String(reward.get("fusion_motif", ""))
		var basic_statuses := reward.get("basic_attack_statuses", []) as Array
		var fusion_hints := reward.get("fusion_hints", []) as Array
		_expect(not motif.is_empty() and not motifs.has(motif), "Each Blessing needs a unique geometry motif: %s" % gift_id)
		_expect(basic_statuses.size() == 1, "Each base Blessing needs one normal-attack status: %s" % gift_id)
		_expect(not fusion_hints.is_empty(), "Each Blessing card must expose at least one authored fusion hint: %s" % gift_id)
		if basic_statuses.size() == 1:
			var status_id := String((basic_statuses[0] as Dictionary).get("effect_id", ""))
			_expect(not status_id.is_empty() and not status_ids.has(status_id), "Each Blessing needs a distinct normal-attack status: %s" % gift_id)
			status_ids[status_id] = true
		motifs[motif] = true
		_expect(_queue_preserves_projection(reward), "GrowthChoiceQueue 必須原樣保留 base gift 顯示欄位：%s" % gift_id)

	_expect(gifts.add_or_upgrade("resonant_grace"), "測試必須能取得煉獄恩典。")
	_expect(motifs.size() == BASE_GIFT_COUNT and status_ids.size() == BASE_GIFT_COUNT, "All eight Blessings must remain visually and mechanically distinct.")
	var recommended := gifts.get_reward_choices(3)
	var has_merge_route := false
	for reward in recommended:
		if bool(reward.get("merge_with_owned", false)):
			has_merge_route = true
			break
	_expect(
		has_merge_route,
		"Three-choice rewards must include an authored fusion partner whenever one is available."
	)
	var owned_reward := _find_reward(gifts.get_reward_choices(20), "resonant_grace")
	_expect(not owned_reward.is_empty(), "未滿級既有神賜必須進入升級獎勵池。")
	if not owned_reward.is_empty():
		var owned := gifts.get_gift("resonant_grace")
		_expect(
			(owned_reward.get("current_effects", {}) as Dictionary)
				== (owned.get("effects", {}) as Dictionary)
				and not (owned_reward.get("next_effects", {}) as Dictionary).is_empty(),
			"既有神賜選項必須投影現級實效與下一級實效。"
		)
		_expect(_queue_preserves_projection(owned_reward), "Queue 必須保留既有神賜的現級與下一級投影。")

	var evolved_manager := DivineGiftManager.new()
	_expect(evolved_manager.load_catalog(), "昇華投影測試必須可載入神賜資料。")
	for gift_id in ["resonant_grace", "boundless_font"]:
		for _level in 3:
			_expect(evolved_manager.add_or_upgrade(gift_id), "融合素材必須能升至滿級：%s" % gift_id)
	evolved_manager.set_equipped_item_ids(["iron_sword"])
	var evolved := evolved_manager.fuse_max_level("resonant_grace", "boundless_font")
	var composed_attack := evolved.get("background_attack", {}) as Dictionary
	var geometry_modules := composed_attack.get("geometry_modules", []) as Array
	_expect(
		geometry_modules.size() == 2
			and String((geometry_modules[0] as Dictionary).get("motif", "")) == "pulse_ring"
			and String((geometry_modules[1] as Dictionary).get("motif", "")) == "venom_orb"
			and (composed_attack.get("glow_colors", []) as Array).size() == 2,
		"進化 Blessing 的背景攻擊必須融合兩個來源的幾何 motif 與發光色。"
	)
	var evolved_id := String(evolved.get("id", ""))
	var evolved_reward := _find_reward(evolved_manager.get_reward_choices(20), evolved_id)
	_expect(not evolved_reward.is_empty(), "未滿級昇華神賜必須投影升級選項。")
	if not evolved_reward.is_empty():
		var evolved_current := evolved_reward.get("current_effects", {}) as Dictionary
		var evolved_next := evolved_reward.get("next_effects", {}) as Dictionary
		var evolved_mutations := evolved_reward.get("finisher_mutations", {}) as Dictionary
		_expect(
			String(evolved_reward.get("kind", "")) == "evolved"
				and not String(evolved_reward.get("element", "")).is_empty()
				and not (evolved_reward.get("elements", []) as Array).is_empty(),
			"昇華選項必須保留主元素與組成元素。"
		)
		_expect(
			evolved_current == (evolved.get("effects", {}) as Dictionary)
				and _numeric_value_count(evolved_next) >= 2
				and evolved_next != evolved_current,
			"昇華選項必須投影實際現級效果與實際下一級效果。"
		)
		_expect(
			bool(evolved_mutations.get("chain_lightning", false)),
			"Lv.1 昇華神賜的下一級 mechanics 必須包含實際解鎖的連鎖雷擊。"
		)
		_expect(_contains_han(String(evolved_reward.get("name", ""))), "昇華神賜名稱不得退回英文。")
		_expect(_contains_han(String(evolved_reward.get("description", ""))), "昇華神賜說明不得退回英文。")
		_expect(_queue_preserves_projection(evolved_reward), "Queue 必須原樣保留昇華神賜的效果與 mechanics。")
		var choice_scene := load(
			"res://scenes/ui/cards/DivineGiftChoiceCard.tscn"
		) as PackedScene
		var choice_card := choice_scene.instantiate()
		root.add_child(choice_card)
		choice_card.call("configure", evolved_reward, ["測試效果"] as Array[String])
		var class_text := String(choice_card.get_node(
			"CardContent/Header/Identity/EffectClass"
		).get("text"))
		_expect(
			class_text.contains("火") and class_text.contains("毒"),
			"雙屬性昇華神賜卡必須同時顯示兩個實際生效的屬性效果。"
		)
		choice_card.queue_free()

	if _failures == 0:
		print("PASS: Divine Gift reward projections preserve Chinese copy, effects, elements, and mechanics")
	quit(1 if _failures > 0 else 0)


func _queue_preserves_projection(reward: Dictionary) -> bool:
	var queue := GrowthChoiceQueue.new()
	if not queue.enqueue_divine_gifts([reward], []):
		return false
	var choices := queue.peek().get("choices", []) as Array
	if choices.size() != 1:
		return false
	var queued := choices[0] as Dictionary
	if (
		String(queued.get("name", "")) != String(reward.get("name", ""))
		or String(queued.get("description", "")) != String(reward.get("description", ""))
		or not _contains_han(String(queued.get("name", "")))
		or not _contains_han(String(queued.get("description", "")))
	):
		return false
	for field in ["element", "current_effects", "next_effects", "finisher_mutations", "basic_attack_statuses", "fusion_hints", "merge_with_owned"]:
		if not queued.has(field) or queued[field] != reward.get(field):
			return false
	if String(reward.get("kind", "base")) == "base":
		for trait_field in ["fusion_stem", "fusion_motif", "accent_color"]:
			if queued.get(trait_field) != reward.get(trait_field):
				return false
	if reward.has("elements") and queued.get("elements", []) != reward.get("elements", []):
		return false
	return true


func _find_reward(rewards: Array[Dictionary], gift_id: String) -> Dictionary:
	for reward in rewards:
		if String(reward.get("gift_id", "")) == gift_id:
			return reward
	return {}


func _numeric_value_count(values: Dictionary) -> int:
	var result := 0
	for value in values.values():
		if value is int or value is float:
			result += 1
	return result


func _has_interpretable_mechanic(values: Dictionary) -> bool:
	for value in values.values():
		if value is bool or value is int or value is float:
			return true
	return false


func _contains_han(value: String) -> bool:
	for character in value:
		var code := character.unicode_at(0)
		if code >= 0x3400 and code <= 0x9fff:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
