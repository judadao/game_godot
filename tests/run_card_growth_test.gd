extends SceneTree

class FailingSaveService extends SaveService:
	func save_meta(_path: String, _data: Dictionary) -> bool:
		return false


var _failures := 0
var _save_requests := 0
var _save_failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", ["dash_strike", "cleave", "cleave", "guard", "iron_skin"])
	_expect(game.has_method("_confirm_growth_action"), "Growth actions must be confirmed through Game's queue authority.")
	_expect(game.has_method("_enqueue_pending_experience_growth"), "EXP levels must enqueue growth entries instead of opening LevelUpUI.")
	_expect(game.has_signal("growth_save_requested"), "Permanent fallback rewards must request an immediate save.")
	if not game.has_method("_confirm_growth_action") or not game.has_method("_enqueue_pending_experience_growth"):
		game.queue_free()
		await process_frame
		quit(1)
		return
	if game.has_signal("growth_save_requested"):
		game.connect("growth_save_requested", _on_growth_save_requested)

	var queue: GrowthChoiceQueue = game.get("growth_choice_queue") as GrowthChoiceQueue
	_expect(queue != null, "Game must own the growth choice queue.")
	if queue == null:
		game.queue_free()
		await process_frame
		quit(1)
		return

	game.call("_show_card_reward_choices", 2)
	var wave_entry := queue.peek()
	_expect(wave_entry.get("source", "") == GrowthChoiceQueue.WAVE_BLESSING_SOURCE, "Wave blessings must enqueue a wave source entry.")
	_expect(wave_entry.get("allowed_pages", []) == ["new_card"], "Wave blessings must expose New Card only.")
	_expect(not queue.close(), "Closing a growth choice must not consume it.")
	_expect(queue.get_queue_count() == 1, "An invalid close must retain the wave choice.")
	var rewarded_card_id := String((wave_entry.get("payload", {}) as Dictionary).get("card_options", [""])[0])
	_expect(not DeckManager.FIXED_CARD_IDS.has(rewarded_card_id), "Wave choices must not reward fixed cards.")
	var instances_before := (game.get("run_state") as RunState).card_instances.size()
	_expect(
		bool(game.call("_confirm_growth_action", {"page": "new_card", "kind": "new_card", "card_id": rewarded_card_id})),
		"A declared wave card reward must confirm once."
	)
	var run := game.get("run_state") as RunState
	_expect(run.card_instances.size() == instances_before + 1, "A New Card reward must add one level-one instance.")
	_expect(_find_latest_instance(run.card_instances, rewarded_card_id).get("level", 0) == 1, "New Card rewards must always start at level one.")
	_expect(queue.is_empty(), "A confirmed wave action must dequeue exactly one entry.")

	var target := _find_latest_instance(run.card_instances, "cleave")
	var sibling := _find_other_instance(run.card_instances, "cleave", int(target.get("instance_id", 0)))
	_expect(not target.is_empty() and not sibling.is_empty(), "The fixture requires distinct Cleave instances.")
	run.pending_level_ups = 1
	game.call("_enqueue_pending_experience_growth")
	var exp_entry := queue.peek()
	_expect(exp_entry.get("source", "") == GrowthChoiceQueue.EXP_LEVEL_SOURCE, "EXP must enqueue an EXP growth entry.")
	_expect((exp_entry.get("allowed_pages", []) as Array).has("upgrade"), "A nonfixed instance below level three must expose Upgrade.")
	var upgrade_projection := _find_upgrade_projection(
		(exp_entry.get("payload", {}) as Dictionary).get("upgradeable_instances", []) as Array,
		int(target.get("instance_id", 0))
	)
	_expect(
		upgrade_projection == {
			"instance_id": int(target.get("instance_id", 0)),
			"card_id": "cleave",
			"level": 1,
			"name": "Cleave",
			"before": 1,
			"after": 2,
		},
		"EXP upgrade payloads must project the exact UI comparison for each candidate."
	)
	_expect(
		bool(game.call("_confirm_growth_action", {"page": "upgrade", "kind": "upgrade", "instance_id": int(target.get("instance_id", 0))})),
		"EXP must upgrade the exact selected nonfixed instance."
	)
	_expect(_find_instance(run.card_instances, int(target.get("instance_id", 0))).get("level", 0) == 2, "Only the selected instance may gain a level.")
	_expect(_find_instance(run.card_instances, int(sibling.get("instance_id", 0))).get("level", 0) == 1, "Sibling instances must keep their own level.")
	_expect(
		not bool(game.call("_apply_growth_action", {"page": "upgrade", "kind": "upgrade", "instance_id": _find_latest_instance(run.card_instances, "ember_bolt").get("instance_id", 0)})),
		"Fixed-card instances must reject upgrades."
	)

	_set_instance_level(run.card_instances, "dash_strike", 3)
	_set_instance_level(run.card_instances, "cleave", 3)
	game.call("_synchronize_growth_instances")
	var dash := _find_latest_instance(run.card_instances, "dash_strike")
	var cleave := _find_latest_instance(run.card_instances, "cleave")
	var run_size_before_fusion := run.card_instances.size()
	run.pending_level_ups = 1
	game.call("_enqueue_pending_experience_growth")
	_expect(
		(queue.peek().get("allowed_pages", []) as Array).has("fusion"),
		"Two selected distinct level-three recipe materials must expose Fusion."
	)
	_expect(
		bool(game.call("_confirm_growth_action", {
			"page": "fusion",
			"kind": "fusion",
			"recipe_id": "fuse_gale_lunge",
			"material_instance_ids": [int(dash.get("instance_id", 0)), int(cleave.get("instance_id", 0))],
		})),
		"Fusion must consume the exact selected level-three recipe pair."
	)
	_expect(run.card_instances.size() == run_size_before_fusion - 1, "Fusion must have net deck size minus one.")
	_expect(_find_latest_instance(run.card_instances, "gale_lunge").get("level", 0) == 1, "Fusion must create a level-one result instance.")
	var game_source := FileAccess.get_file_as_string("res://scripts/managers/game.gd")
	_expect(
		not game_source.contains("_try_evolve_combo_abilities"),
		"Game must not retain an automatic passive combo-evolution authority."
	)

	var fallback_game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(fallback_game)
	await process_frame
	await process_frame
	_save_requests = 0
	fallback_game.connect("growth_save_requested", _on_growth_save_requested)
	fallback_game.call("_begin_autumn_run", ["dash_strike"])
	var fallback_run := fallback_game.get("run_state") as RunState
	_set_instance_level(fallback_run.card_instances, "dash_strike", 2)
	fallback_game.call("_synchronize_growth_instances")
	var fallback_queue: GrowthChoiceQueue = fallback_game.get("growth_choice_queue") as GrowthChoiceQueue
	fallback_run.pending_level_ups = 4
	fallback_game.call("_enqueue_pending_experience_growth")
	_expect(fallback_queue.get_queue_count() == 1, "Only the next pending EXP level may materialize into the queue.")
	var fallback_dash := _find_latest_instance(fallback_run.card_instances, "dash_strike")
	_expect(
		bool(fallback_game.call("_confirm_growth_action", {
			"page": "upgrade",
			"kind": "upgrade",
			"instance_id": int(fallback_dash.get("instance_id", 0)),
		})),
		"The first pending EXP level must resolve its currently valid upgrade."
	)
	var fallback_entry := fallback_queue.peek()
	_expect(fallback_entry.get("allowed_pages", []) == ["reward"], "The next EXP level must re-evaluate and expose fallback only after upgrades disappear.")
	_expect(
		(fallback_entry.get("payload", {}) as Dictionary).get("fallback_rewards", []) == [
			{"resource_id": "gold", "amount": 75},
			{"resources": {"autumn_wood": 12, "stone": 8}},
			{"resource_id": "magic_shard", "amount": 4},
		],
		"Fallback rewards must use the exact configured values."
	)
	var inventory: RefCounted = fallback_game.get("inventory_manager") as RefCounted
	var gold_before := int(inventory.call("get_resource_amount", &"gold"))
	var wood_before := int(inventory.call("get_resource_amount", &"autumn_wood"))
	var stone_before := int(inventory.call("get_resource_amount", &"stone"))
	var shards_before := int(inventory.call("get_resource_amount", &"magic_shard"))
	_expect(
		bool(fallback_game.call("_confirm_growth_action", {"page": "reward", "kind": "reward", "resource_id": "gold", "amount": 75})),
		"The gold fallback must confirm through the queue."
	)
	_expect(
		bool(fallback_game.call("_confirm_growth_action", {
			"page": "reward",
			"kind": "reward",
			"resources": {"autumn_wood": 12, "stone": 8},
		})),
		"The wood-and-stone fallback must confirm through the queue."
	)
	_expect(
		bool(fallback_game.call("_confirm_growth_action", {"page": "reward", "kind": "reward", "resource_id": "magic_shard", "amount": 4})),
		"The shard fallback must confirm through the queue."
	)
	_expect(int(inventory.call("get_resource_amount", &"gold")) == gold_before + 75, "Fallback gold must update persistent inventory immediately.")
	_expect(int(inventory.call("get_resource_amount", &"autumn_wood")) == wood_before + 12, "Fallback wood must be granted exactly once.")
	_expect(int(inventory.call("get_resource_amount", &"stone")) == stone_before + 8, "Fallback stone must be granted exactly once.")
	_expect(int(inventory.call("get_resource_amount", &"magic_shard")) == shards_before + 4, "Fallback shards must be granted exactly once.")
	_expect(int((fallback_game.get("meta_state") as MetaState).resources.get("gold", 0)) == gold_before + 75, "Fallback gold must synchronize into meta state immediately.")
	_expect(int((fallback_game.get("meta_state") as MetaState).resources.get("autumn_wood", 0)) == wood_before + 12, "Fallback wood must synchronize into meta state.")
	_expect(int((fallback_game.get("meta_state") as MetaState).resources.get("stone", 0)) == stone_before + 8, "Fallback stone must synchronize into meta state.")
	_expect(int((fallback_game.get("meta_state") as MetaState).resources.get("magic_shard", 0)) == shards_before + 4, "Fallback shards must synchronize into meta state.")
	_expect(_save_requests == 3, "Each permanent fallback must request exactly one immediate save.")
	_expect(fallback_queue.is_empty(), "Four pending levels must resolve one upgrade plus three re-evaluated fallbacks.")
	var persisted_resources := (SaveService.new().load_meta("user://saves/meta_progress.json").get("resources", {}) as Dictionary)
	_expect(int(persisted_resources.get("gold", 0)) == gold_before + 75, "Persisted fallback gold must be written exactly once.")
	_expect(int(persisted_resources.get("autumn_wood", 0)) == wood_before + 12, "Persisted fallback wood must be written exactly once.")
	_expect(int(persisted_resources.get("stone", 0)) == stone_before + 8, "Persisted fallback stone must be written exactly once.")
	_expect(int(persisted_resources.get("magic_shard", 0)) == shards_before + 4, "Persisted fallback shards must be written exactly once.")

	var failure_game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(failure_game)
	await process_frame
	await process_frame
	failure_game.set("save_service", FailingSaveService.new())
	_expect(failure_game.has_signal("growth_save_failed"), "Game must surface permanent growth save failures.")
	if failure_game.has_signal("growth_save_failed"):
		failure_game.connect("growth_save_failed", _on_growth_save_failed)
	failure_game.call("_begin_autumn_run", ["dash_strike"])
	var failure_run := failure_game.get("run_state") as RunState
	_set_instance_level(failure_run.card_instances, "dash_strike", 3)
	failure_game.call("_synchronize_growth_instances")
	failure_run.pending_level_ups = 1
	failure_game.call("_enqueue_pending_experience_growth")
	var failure_queue: GrowthChoiceQueue = failure_game.get("growth_choice_queue") as GrowthChoiceQueue
	var failure_inventory := failure_game.get("inventory_manager") as RefCounted
	var failure_gold_before := int(failure_inventory.call("get_resource_amount", &"gold"))
	_expect(
		not bool(failure_game.call("_confirm_growth_action", {"page": "reward", "kind": "reward", "resource_id": "gold", "amount": 75})),
		"A failed permanent save must reject fallback confirmation."
	)
	_expect(failure_queue.get_queue_count() == 1, "A failed permanent save must retain the fallback choice.")
	_expect(int(failure_inventory.call("get_resource_amount", &"gold")) == failure_gold_before, "A failed permanent save must roll back inventory resources.")
	_expect(int((failure_game.get("meta_state") as MetaState).resources.get("gold", 0)) == failure_gold_before, "A failed permanent save must roll back meta resources.")
	_expect(_save_failures == 1, "A failed permanent save must surface exactly one failure signal.")

	game.queue_free()
	fallback_game.queue_free()
	failure_game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _on_growth_save_requested() -> void:
	_save_requests += 1


func _on_growth_save_failed(_message: String) -> void:
	_save_failures += 1


func _find_instance(instances: Array[Dictionary], instance_id: int) -> Dictionary:
	for instance in instances:
		if int(instance.get("instance_id", 0)) == instance_id:
			return instance
	return {}


func _find_latest_instance(instances: Array[Dictionary], card_id: String) -> Dictionary:
	for index in range(instances.size() - 1, -1, -1):
		var instance := instances[index]
		if String(instance.get("card_id", "")) == card_id:
			return instance
	return {}


func _find_other_instance(instances: Array[Dictionary], card_id: String, excluded_instance_id: int) -> Dictionary:
	for instance in instances:
		if String(instance.get("card_id", "")) == card_id and int(instance.get("instance_id", 0)) != excluded_instance_id:
			return instance
	return {}


func _find_upgrade_projection(projections: Array, instance_id: int) -> Dictionary:
	for projection in projections:
		if projection is Dictionary and int((projection as Dictionary).get("instance_id", 0)) == instance_id:
			return projection as Dictionary
	return {}


func _set_instance_level(instances: Array[Dictionary], card_id: String, level: int) -> void:
	for instance in instances:
		if String(instance.get("card_id", "")) == card_id:
			instance["level"] = level


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
