extends SceneTree

var _failures := 0


func _initialize() -> void:
	var queue := GrowthChoiceQueue.new()
	_expect(
		not queue.has_method("enqueue_experience_growth")
			and not queue.has_method("enqueue_optional_fusions"),
		"Legacy EXP card-upgrade/fusion entry points must stay unreachable."
	)
	var wave_cards: Array[Dictionary] = [{
		"card_id": "cleave",
		"name": "Cleave",
		"description": "Deal area damage.",
		"type": "combo",
		"cost": 2,
	}]
	_expect(queue.enqueue_wave_blessing(wave_cards), "Wave reward must enqueue.")

	var blessing_rewards: Array[Dictionary] = [
		{
			"gift_id": "resonant_grace",
			"name": "煉獄恩典",
			"description": "強化連段與終結技。",
			"level": 0,
			"next_level": 1,
			"element": "fire",
			"next_effects": {"finisher_damage_multiplier": 1.1},
		},
		{
			"gift_id": "boundless_font",
			"name": "萬毒源泉",
			"description": "使連段回復能量。",
			"level": 1,
			"next_level": 2,
			"element": "poison",
			"current_effects": {"combo_ap_refund": 0.1},
			"next_effects": {"combo_ap_refund": 0.2},
		},
	]
	_expect(
		queue.enqueue_experience_blessings(blessing_rewards),
		"EXP level-up must enqueue new-or-upgraded Blessings."
	)
	_expect(queue.size() == 2, "Growth events must retain FIFO order.")
	var wave_choice := (queue.peek().get("choices", []) as Array)[0] as Dictionary
	_expect(
		String(queue.resolve(String(wave_choice.get("choice_id", ""))).get("source", "")) == "wave",
		"Resolving the first page must reveal the queued EXP page."
	)
	var experience_page := queue.peek()
	_expect(
		String(experience_page.get("source", "")) == "experience"
			and _actions(experience_page) == {"divine_gift": true},
		"EXP pages must contain only new or upgraded Blessings and never merges."
	)
	var experience_choice := (experience_page.get("choices", []) as Array)[0] as Dictionary
	queue.resolve(String(experience_choice.get("choice_id", "")))

	var empty_rewards: Array[Dictionary] = []
	_expect(
		queue.enqueue_experience_blessings(empty_rewards),
		"An all-max EXP event must remain resolvable."
	)
	var fallback_page := queue.peek()
	var bundles: Array = (fallback_page.get("choices", []) as Array).map(
		func(choice: Dictionary) -> Variant: return choice.get("reward", {})
	)
	_expect(
		_actions(fallback_page) == {"fallback": true}
			and bundles.has({"gold": 75})
			and bundles.has({"autumn_wood": 12, "stone": 8})
			and bundles.has({"magic_shard": 4}),
		"All-max Blessings must offer the exact money/material fallback draws."
	)
	queue.clear()

	var fusions: Array[Dictionary] = []
	for index in 6:
		fusions.append({
			"left_gift_id": "left_%d" % index,
			"right_gift_id": "right_%d" % index,
			"name": "融合型態 %d" % index,
			"description": "融合兩項滿級神賜。",
		})
	var owned_upgrades: Array[Dictionary] = [
		blessing_rewards[1],
		blessing_rewards[1].merged({"gift_id": "upgrade_two", "name": "升級二"}, true),
		blessing_rewards[1].merged({"gift_id": "upgrade_three", "name": "升級三"}, true),
	]
	_expect(
		queue.enqueue_combat_blessing_reward("elite", owned_upgrades, fusions),
		"Elite loot must accept owned upgrades and Blessing merges."
	)
	_expect(
		String(queue.peek().get("source", "")) == "elite"
			and _actions(queue.peek()) == {
				"divine_gift": true,
				"divine_fusion": true,
			},
		"Elite loot must contain only owned upgrade and merge actions."
	)
	var elite_choices := queue.peek().get("choices", []) as Array
	_expect(
		elite_choices.size() == 5
			and _action_count(queue.peek(), "divine_fusion") == 3,
		"合法融合多於三種時，戰利品頁必須優先隨機保留三種，再用升級補滿五個選項。"
	)
	_expect(
		queue.skip_optional_reward().is_empty(),
		"Elite and boss loot choices must remain mandatory."
	)
	queue.clear()
	_expect(
		queue.enqueue_combat_blessing_reward("boss", owned_upgrades, fusions)
			and String(queue.peek().get("source", "")) == "boss",
		"Boss defeat must use the same upgrade-or-merge contract."
	)
	_expect(
		not queue.enqueue_combat_blessing_reward("experience", owned_upgrades, fusions),
		"A non-elite/boss source must never expose merge choices."
	)

	if _failures == 0:
		print("PASS: FIFO level Blessings, all-max fallback, and elite/boss merge gating")
	quit(1 if _failures > 0 else 0)


func _actions(page: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for choice_variant in page.get("choices", []) as Array:
		result[String((choice_variant as Dictionary).get("action", ""))] = true
	return result


func _action_count(page: Dictionary, action: String) -> int:
	var result := 0
	for choice_variant in page.get("choices", []) as Array:
		if String((choice_variant as Dictionary).get("action", "")) == action:
			result += 1
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
