extends SceneTree

const GrowthChoiceQueueScript := preload("res://scripts/systems/growth_choice_queue.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var queue := GrowthChoiceQueueScript.new()
	var wave_cards: Array[Dictionary] = [
		{"card_id": "cleave", "name": "Cleave"},
		{"card_id": "frost_bind", "name": "Frost Bind"},
	]
	_expect(queue.enqueue_wave_blessing(wave_cards), "Wave blessings must enqueue new-card choices.")
	var upgrades: Array[Dictionary] = [
		{"instance_id": "card-a", "card_id": "cleave", "level": 1},
	]
	var fusions: Array[Dictionary] = [
		{
			"recipe_id": "gale_lunge",
			"left_instance_id": "card-b",
			"right_instance_id": "card-c",
			"result_card_id": "gale_lunge",
		},
	]
	_expect(queue.enqueue_experience_growth(upgrades, fusions), "EXP growth must enqueue upgrade and fusion choices together.")
	_expect(queue.size() == 2, "Multiple growth events must remain FIFO.")
	var first := queue.peek()
	_expect(String(first.get("source", "")) == "wave", "Wave blessing must stay first.")
	_expect((first.get("choices", []) as Array).all(func(choice: Dictionary) -> bool: return String(choice.get("action", "")) == "new_card"), "Wave blessing must only offer new cards.")
	_expect(queue.resolve("missing").is_empty(), "An invalid choice must not consume the queue.")
	_expect(queue.size() == 2, "Invalid resolution must leave every entry pending.")
	var first_choice_id := String(((first.get("choices", []) as Array)[0] as Dictionary).get("choice_id", ""))
	var wave_resolution := queue.resolve(first_choice_id)
	_expect(String(wave_resolution.get("action", "")) == "new_card", "Wave resolution must select one card.")
	var second := queue.peek()
	var second_actions: Array[String] = []
	for choice in second.get("choices", []) as Array:
		second_actions.append(String((choice as Dictionary).get("action", "")))
	_expect(second_actions.has("upgrade") and second_actions.has("fusion"), "EXP page must combine individual upgrades and full-level fusion.")
	_expect(not second_actions.has("fallback"), "Fallback resources must not appear while growth is possible.")

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
