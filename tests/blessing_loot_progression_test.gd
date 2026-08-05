extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "Blessing catalog must load for progression checks.")
	_expect(
		gifts.has_method("get_upgrade_choices"),
		"DivineGiftManager must expose owned-only upgrade choices for elite and boss loot."
	)
	var queue := GrowthChoiceQueue.new()
	_expect(
		queue.has_method("enqueue_experience_blessings"),
		"Every character level must enqueue new-or-upgraded Blessing choices."
	)
	_expect(
		queue.has_method("enqueue_combat_blessing_reward"),
		"Elite and boss loot must enqueue upgrade-or-merge Blessing choices."
	)
	if queue.has_method("enqueue_experience_blessings"):
		var initial_rewards := gifts.get_reward_choices(3)
		_expect(
			bool(queue.call("enqueue_experience_blessings", initial_rewards)),
			"A level-up must accept available Blessing choices."
		)
		var level_page := queue.peek()
		_expect(
			String(level_page.get("source", "")) == "experience"
				and _actions(level_page) == {"divine_gift": true},
			"Level-up pages must contain only new or upgraded Blessings, never merges."
		)
		queue.clear()
		var empty_rewards: Array[Dictionary] = []
		_expect(
			bool(queue.call("enqueue_experience_blessings", empty_rewards))
				and _actions(queue.peek()) == {"fallback": true},
			"All-max Blessings must fall back to money or material draws."
		)

	var director := SurvivalWaveDirector.new()
	_expect(
		director.has_signal("reward_bag_spawned")
			and director.has_signal("reward_bag_collected"),
		"Survival rewards must expose physical money and material bag events."
	)
	_expect(
		director.has_signal("boss_defeated"),
		"Every defeated boss must expose its own Blessing loot event."
	)
	_expect(
		director.has_method("roll_reward_bags")
			and director.has_method("get_monster_material"),
		"Reward bag rolls and monster-specific materials must be deterministic and testable."
	)
	if director.has_method("roll_reward_bags"):
		var normal_rewards := director.call(
			"roll_reward_bags", &"normal", 0.0, 0.0, &"sprout", 5
		) as Array
		var elite_rewards := director.call(
			"roll_reward_bags", &"elite", 0.0, 0.0, &"elite", 30
		) as Array
		var boss_rewards := director.call(
			"roll_reward_bags", &"boss", 0.0, 0.0, &"guardian", 120
		) as Array
		_expect(
			_has_kind(normal_rewards, "money") and _has_kind(normal_rewards, "material"),
			"Normal monsters must be able to drop both money and basic material bags."
		)
		_expect(
			_has_kind(elite_rewards, "money") and _has_kind(elite_rewards, "material")
				and _has_kind(boss_rewards, "money") and _has_kind(boss_rewards, "material"),
			"Elite and boss rolls must support both money and monster-material bags."
		)
		_expect(
			_material_quantity(normal_rewards) == 1
				and _material_quantity(elite_rewards) == 2
				and _material_quantity(boss_rewards) == 3,
			"Material bags must scale from normal to elite to boss rewards."
		)
		for reward_variant in elite_rewards + boss_rewards:
			var reward := reward_variant as Dictionary
			if String(reward.get("kind", "")) != "material":
				continue
			_expect(
				not String((reward.get("reward", {}) as Dictionary).keys()[0]).is_empty(),
				"Every material bag must contain an explicit monster-specific material id."
			)
	root.add_child(director)
	var collected_rewards: Array[Dictionary] = []
	director.reward_bag_collected.connect(
		func(kind: StringName, reward: Dictionary) -> void:
			collected_rewards.append({"kind": kind, "reward": reward.duplicate(true)})
	)
	var collector := Node2D.new()
	collector.add_to_group("Player")
	root.add_child(collector)
	var money_pickup := director.call(
		"_spawn_survival_pickup",
		&"money_bag",
		Vector2.ZERO,
		{"gold": 7},
		&"money"
	) as SurvivalPickup
	_expect(money_pickup != null, "Money rewards must instantiate a physical bag pickup.")
	if money_pickup != null:
		money_pickup.collect(collector)
		await process_frame
	_expect(
		collected_rewards == [{"kind": &"money", "reward": {"gold": 7}}],
		"Collecting a physical money bag must emit its exact reward payload once."
	)
	collector.queue_free()
	director.queue_free()
	await process_frame

	if _failures == 0:
		print("PASS: level Blessings, elite/boss merge rewards, and physical reward bags")
	quit(1 if _failures > 0 else 0)


func _actions(page: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for choice_variant in page.get("choices", []) as Array:
		result[String((choice_variant as Dictionary).get("action", ""))] = true
	return result


func _has_kind(rewards: Array, kind: String) -> bool:
	return rewards.any(
		func(reward: Dictionary) -> bool:
			return String(reward.get("kind", "")) == kind
	)


func _material_quantity(rewards: Array) -> int:
	for reward_variant in rewards:
		var reward := reward_variant as Dictionary
		if String(reward.get("kind", "")) != "material":
			continue
		var payload := reward.get("reward", {}) as Dictionary
		if not payload.is_empty():
			return int(payload.values()[0])
	return 0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
