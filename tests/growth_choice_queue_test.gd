extends SceneTree

const GrowthChoiceQueueScript := preload("res://scripts/systems/growth_choice_queue.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var queue := GrowthChoiceQueueScript.new()
	var wave_cards: Array[Dictionary] = [
		{"card_id": "cleave", "name": "Cleave", "description": "Deal area damage.", "type": "attack", "cost": 2},
		{"card_id": "frost_bind", "name": "Frost Bind", "description": "Slow nearby enemies.", "type": "status", "cost": 2},
	]
	_expect(queue.enqueue_wave_blessing(wave_cards), "Wave blessings must enqueue new-card choices.")
	var upgrades: Array[Dictionary] = [
		{"instance_id": "card-a", "card_id": "cleave", "name": "Crescent Cleave", "level": 1, "description": "Deal area damage.", "upgrade_description": "Damage increases."},
		{"instance_id": "card-a", "card_id": "cleave", "name": "Duplicate Cleave", "level": 1},
	]
	var fusions: Array[Dictionary] = [
		{
			"recipe_id": "gale_lunge",
			"left_instance_id": "card-b",
			"right_instance_id": "card-c",
			"left_card_id": "dash_strike",
			"right_card_id": "cleave",
			"left_name": "Dash Strike",
			"right_name": "Crescent Cleave",
			"result_card_id": "gale_lunge",
			"result_name": "Gale Lunge",
		},
	]
	_expect(queue.enqueue_experience_growth(upgrades, fusions), "EXP growth must accept upgrade and fusion candidates.")
	_expect(queue.size() == 2, "Multiple growth events must remain FIFO.")
	var first := queue.peek()
	_expect(String(first.get("source", "")) == "wave", "Wave blessing must stay first.")
	_expect((first.get("choices", []) as Array).all(func(choice: Dictionary) -> bool: return String(choice.get("action", "")) == "new_card"), "Wave blessing must only offer new cards.")
	_expect(
		String(((first.get("choices", []) as Array)[0] as Dictionary).get("description", ""))
			== "Deal area damage.",
		"Wave choices must preserve production descriptions for the modal."
	)
	_expect(queue.resolve("missing").is_empty(), "An invalid choice must not consume the queue.")
	_expect(queue.size() == 2, "Invalid resolution must leave every entry pending.")
	var skipped_wave := queue.skip_wave_reward()
	_expect(
		String(skipped_wave.get("action", "")) == "skip"
			and String(skipped_wave.get("source", "")) == "wave"
			and queue.size() == 1,
		"Wave new-card rewards must be skippable without adding a card."
	)
	_expect(queue.skip_wave_reward().is_empty(), "Experience growth must never be skipped through the wave reward API.")
	queue.clear()
	_expect(queue.enqueue_wave_blessing(wave_cards), "Wave choice resolution setup must enqueue again.")
	var replayed_wave := queue.peek()
	var first_choice_id := String(
		((replayed_wave.get("choices", []) as Array)[0] as Dictionary).get("choice_id", "")
	)
	var wave_resolution := queue.resolve(first_choice_id)
	_expect(String(wave_resolution.get("action", "")) == "new_card", "Wave resolution must select one card.")
	_expect(queue.enqueue_experience_growth(upgrades, fusions), "Upgrade choice resolution setup must enqueue after the wave.")
	var second := queue.peek()
	var second_actions: Array[String] = []
	for choice in second.get("choices", []) as Array:
		second_actions.append(String((choice as Dictionary).get("action", "")))
	_expect(second_actions.has("upgrade") and not second_actions.has("fusion"), "EXP upgrade pages must stay limited to unfinished cards.")
	_expect(not second_actions.has("fallback"), "Fallback resources must not appear while growth is possible.")
	_expect(second_actions.count("upgrade") == 1, "Duplicate instance candidates must not create ambiguous choice IDs.")
	var upgrade_choice := (second.get("choices", []) as Array).filter(
		func(choice: Dictionary) -> bool: return String(choice.get("action", "")) == "upgrade"
	)[0] as Dictionary
	_expect(String(upgrade_choice.get("name", "")) == "Crescent Cleave", "Upgrade choices must preserve display names for the modal.")
	_expect(
		String(upgrade_choice.get("description", "")) == "Deal area damage."
			and String(upgrade_choice.get("upgrade_description", "")) == "Damage increases.",
		"Upgrade choices must preserve current and next-level descriptions."
	)
	queue.clear()
	_expect(queue.enqueue_experience_growth([], fusions), "Fusion must receive its own page when no card can upgrade.")
	var fusion_choice := (queue.peek().get("choices", []) as Array)[0] as Dictionary
	_expect(
		String(fusion_choice.get("left_card_id", "")) == "dash_strike"
		and String(fusion_choice.get("right_card_id", "")) == "cleave"
		and String(fusion_choice.get("result_name", "")) == "Gale Lunge",
		"Fusion choices must preserve material and result display identity."
	)
	queue.clear()
	_expect(queue.enqueue_optional_fusions(fusions), "A new Lv3 pair must enqueue an optional fusion follow-up.")
	_expect(
		String(queue.peek().get("source", "")) == "fusion_followup",
		"Post-upgrade fusion must use a distinct optional page."
	)
	_expect(
		not queue.skip_optional_reward().is_empty() and queue.is_empty(),
		"Players must be able to keep both Lv3 cards by skipping the fusion follow-up."
	)

	queue.clear()
	var dense_upgrades: Array[Dictionary] = []
	for index in 9:
		dense_upgrades.append({
			"instance_id": "dense-%d" % index,
			"card_id": "card-%d" % index,
			"name": "Card %d" % index,
			"level": 1 + index % 2,
		})
	_expect(
		queue.enqueue_experience_growth(dense_upgrades, fusions),
		"Dense EXP growth must enqueue a bounded choice page."
	)
	var dense_choices := queue.peek().get("choices", []) as Array
	var all_dense_choices_are_upgrades := true
	for choice in dense_choices:
		all_dense_choices_are_upgrades = (
			all_dense_choices_are_upgrades
			and String((choice as Dictionary).get("action", "")) == "upgrade"
		)
	_expect(
		dense_choices.size() == 5
			and all_dense_choices_are_upgrades,
		"EXP growth must sample exactly five unfinished cards before offering fusion."
	)

	queue.clear()
	_expect(queue.enqueue_experience_growth([], []), "An EXP event with no growth must enqueue fallback rewards.")
	var fallback_page := queue.peek()
	var bundles: Array = (fallback_page.get("choices", []) as Array).map(
		func(choice: Dictionary) -> Variant: return choice.get("reward", {})
	)
	_expect(bundles.has({"gold": 75}), "Fallback must include exactly 75 gold.")
	_expect(bundles.has({"autumn_wood": 12, "stone": 8}), "Fallback must include exactly 12 wood and 8 stone.")
	_expect(bundles.has({"magic_shard": 4}), "Fallback must include exactly 4 magic shards.")

	_expect(not queue.enqueue_wave_blessing([]), "An empty wave reward must not create an unresolvable modal.")
	if _failures == 0:
		print("PASS: FIFO growth choice queue and fallback gating")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
