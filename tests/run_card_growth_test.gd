extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"guard", "guard", "iron_skin", "healing_light",
		"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
	])
	var run := game.get("run_state") as RunState
	var meta := game.get("meta_state") as MetaState
	var deck := game.get("deck_manager") as DeckManager
	for instance in run.card_instances:
		instance.level = 1

	var guards := _instances_for_card(run.card_instances, "guard")
	_expect(guards.size() >= 2, "Default run must contain distinct Iron Will instances.")
	var upgraded := guards[0] as CardInstance
	var untouched := guards[1] as CardInstance
	_expect(game.call("_apply_growth_resolution", {
		"action": "upgrade",
		"instance_id": upgraded.instance_id,
	}), "An eligible individual instance must upgrade.")
	_expect(upgraded.level == 2, "The selected instance must gain exactly one level.")
	_expect(untouched.level == 1, "Another copy of the same card must keep its own level.")
	_expect(
		deck.find_instance(upgraded.instance_id) == upgraded
		and meta.get_card_instance(upgraded.instance_id) == upgraded,
		"Upgrade must remain visible through shared Meta, Run, and Deck identity."
	)
	_expect(
		_first_instance(run.card_instances, "ember_bolt") == null,
		"Automatic attacks must remain outside the Combo backpack."
	)

	var guard := upgraded
	var stone := _first_instance(run.card_instances, "iron_skin")
	guard.level = 3
	stone.level = 3
	var before_fusion_count := run.card_instances.size()
	_expect(game.call("_apply_growth_resolution", {
		"action": "fusion",
		"left_instance_id": guard.instance_id,
		"right_instance_id": stone.instance_id,
		"result_card_id": "fortress_stance",
	}), "Two matching distinct Lv3 instances must fuse.")
	_expect(run.card_instances.size() == before_fusion_count - 1, "Fusion must consume two and add one, for net minus one.")
	_expect(run.get_card_instance(guard.instance_id) == null and run.get_card_instance(stone.instance_id) == null, "Both selected materials must be consumed.")
	var fortress := _first_instance(run.card_instances, "fortress_stance")
	_expect(fortress != null and fortress.level == 1, "Fusion result must be one new Lv1 instance.")
	_expect(deck.find_instance(fortress.instance_id) == fortress and meta.get_card_instance(fortress.instance_id) == fortress, "Fusion result identity must be shared everywhere.")

	var before_reward_count := run.card_instances.size()
	_expect(game.call("_apply_growth_resolution", {
		"action": "new_card",
		"card_id": "renewal",
	}), "Wave blessing must add a Healing card instance.")
	_expect(run.card_instances.size() == before_reward_count + 1, "New card reward must add exactly one instance.")
	var renewal := _first_instance(run.card_instances, "renewal")
	_expect(renewal != null and deck.find_instance(renewal.instance_id) == renewal, "New reward must share identity with Deck.")

	var meta_gold_before := int(meta.resources.get("gold", 0))
	var inventory := game.get("inventory_manager") as RefCounted
	var inventory_gold_before := int(inventory.call("get_resource_amount", &"gold"))
	_expect(game.call("_apply_growth_resolution", {
		"action": "fallback",
		"reward": {"gold": 75},
	}), "Fallback gold bundle must resolve.")
	_expect(int(meta.resources.get("gold", 0)) == meta_gold_before + 75, "Fallback gold must enter permanent Meta resources.")
	_expect(int(inventory.call("get_resource_amount", &"gold")) == inventory_gold_before + 75, "Fallback gold must update live inventory.")
	_expect(
		int((meta.inventory_state.get("resources", {}) as Dictionary).get("gold", 0))
		== inventory_gold_before + 75,
		"Immediate fallback persistence must synchronize the authoritative inventory payload."
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: individual card upgrades, Lv3 fusion, rewards, and fallback resources")
	quit(1 if _failures > 0 else 0)


func _instances_for_card(instances: Array[CardInstance], card_id: String) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for instance in instances:
		if instance.card_id == card_id:
			result.append(instance)
	return result


func _first_instance(instances: Array[CardInstance], card_id: String) -> CardInstance:
	for instance in instances:
		if instance.card_id == card_id:
			return instance
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
