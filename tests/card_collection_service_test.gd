extends SceneTree

const SERVICE_PATH := "res://scripts/systems/card_collection_service.gd"

var _failures := 0


class FailingRunState:
	extends RunState

	var fail_add := false
	var fail_remove := false

	func add_existing_card_instance(instance: CardInstance) -> bool:
		return false if fail_add else super.add_existing_card_instance(instance)

	func remove_card_instances(instance_ids: Array[String]) -> bool:
		return false if fail_remove else super.remove_card_instances(instance_ids)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(SERVICE_PATH), "Card collection mutations need one dedicated service.")
	if not ResourceLoader.exists(SERVICE_PATH):
		quit(1)
		return

	var database := CardDatabase.new()
	var evolution := EvolutionManager.new(database)
	_expect(database.load_catalog(), "Card catalog must load for collection coordination.")
	_expect(evolution.load_recipes(), "Fusion recipes must load for collection coordination.")

	var meta := MetaState.new()
	meta.apply_dict({
		"schema_version": 2,
		"selected_deck": [
			"ember_bolt",
			"quickstep",
			"guard",
			"iron_skin",
			"cleave",
		],
	})
	var run := FailingRunState.new()
	run.begin_run(meta.selected_card_instances)
	var deck := DeckManager.new(database)
	deck.set_protected_cards([])
	deck.start(run.card_instances, run.max_energy, false)

	var service: RefCounted = load(SERVICE_PATH).new(
		meta,
		run,
		deck,
		database,
		evolution
	)
	_expect(service.call("is_configured"), "Collection service must reject missing authorities at its boundary.")
	var added_attack: CardInstance = service.call("add_persistent_card", "ember_bolt")
	_expect(added_attack != null, "Automatic-attack candidates must remain ordinary collectible cards.")

	var before_failed_add := service.call("capture_state") as Dictionary
	run.fail_add = true
	_expect(
		service.call("add_persistent_card", "verdant_renewal") == null,
		"A Run failure after Meta mutation must reject the reward."
	)
	run.fail_add = false
	_expect(
		_collection_projection(service.call("capture_state"))
		== _collection_projection(before_failed_add),
		"A partial add failure must restore every collection authority."
	)

	var added: CardInstance = service.call("add_persistent_card", "verdant_renewal")
	_expect(added != null, "A valid reward must create one persistent CardInstance.")
	if added != null:
		_expect(
			meta.get_card_instance(added.instance_id) == added
			and run.get_card_instance(added.instance_id) == added
			and deck.find_instance(added.instance_id) == added,
			"Meta, Run, and Deck must share the exact added instance."
		)

	var guard := _first_instance(run.card_instances, "guard")
	var iron_skin := _first_instance(run.card_instances, "iron_skin")
	guard.level = CardInstance.MAX_LEVEL
	iron_skin.level = CardInstance.MAX_LEVEL
	deck.hand_instances.erase(guard)
	deck.hand_instances.erase(iron_skin)
	deck.cooldown_pile.append({
		"instance": guard,
		"remaining_seconds": 4.25,
		"duration_seconds": 6.0,
	})
	deck.cooldown_pile.append({
		"instance": iron_skin,
		"remaining_seconds": 2.5,
		"duration_seconds": 6.0,
	})
	deck.call("_sync_id_views")
	var before_failed_fusion := service.call("capture_state") as Dictionary
	run.fail_remove = true
	_expect(
		service.call("fuse", {
			"left_instance_id": guard.instance_id,
			"right_instance_id": iron_skin.instance_id,
			"result_card_id": "fortress_stance",
		}) == null,
		"A Run failure after Deck mutation must reject fusion."
	)
	run.fail_remove = false
	var restored_fusion := service.call("capture_state") as Dictionary
	_expect(
		_collection_projection(restored_fusion)
		== _collection_projection(before_failed_fusion),
		"Partial fusion failure must restore pile order and cooldown timing."
	)
	_expect(
		(restored_fusion.get("deck_cooldown", []) as Array)[0].get("instance") == guard
		and (restored_fusion.get("deck_cooldown", []) as Array)[1].get("instance") == iron_skin,
		"Fusion rollback must restore the exact material objects."
	)
	var fused: CardInstance = service.call("fuse", {
		"left_instance_id": guard.instance_id,
		"right_instance_id": iron_skin.instance_id,
		"result_card_id": "fortress_stance",
	})
	_expect(fused != null and fused.card_id == "fortress_stance", "A valid recipe must return its result instance.")
	if fused != null:
		_expect(
			meta.get_card_instance(fused.instance_id) == fused
			and run.get_card_instance(fused.instance_id) == fused
			and deck.find_instance(fused.instance_id) == fused,
			"Fusion result identity must stay shared across all authorities."
		)
	_expect(
		meta.get_card_instance(guard.instance_id) == null
		and run.get_card_instance(guard.instance_id) == null
		and deck.find_instance(guard.instance_id) == null,
		"Fusion must remove both material identities everywhere."
	)

	var explicit_restore := service.call("capture_state") as Dictionary
	fused.level = CardInstance.MAX_LEVEL
	meta.unlocked_cards.append("rollback-only-card")
	meta.unlocked_evolutions.append("rollback-only-recipe")
	deck.hand_instances.clear()
	deck.call("_sync_id_views")
	_expect(
		service.call("restore_state", explicit_restore),
		"An explicit collection snapshot must be restorable."
	)
	_expect(
		fused.level == CardInstance.MIN_LEVEL
		and not meta.unlocked_cards.has("rollback-only-card")
		and not meta.unlocked_evolutions.has("rollback-only-recipe")
		and _collection_projection(service.call("capture_state"))
		== _collection_projection(explicit_restore),
		"Restore must recover levels, unlocked fields, object identity, and pile order."
	)

	var before_invalid := service.call("capture_state") as Dictionary
	_expect(
		service.call("fuse", {
			"left_instance_id": fused.instance_id,
			"right_instance_id": fused.instance_id,
			"result_card_id": "fortress_stance",
		}) == null,
		"Invalid fusion must be rejected."
	)
	_expect(
		_collection_projection(service.call("capture_state")) == _collection_projection(before_invalid),
		"Rejected mutations must leave every collection authority unchanged."
	)

	var before_failed_remove := service.call("capture_state") as Dictionary
	run.fail_remove = true
	_expect(
		not service.call("remove_instance", added.instance_id),
		"A Run failure after Deck mutation must reject removal."
	)
	run.fail_remove = false
	_expect(
		_collection_projection(service.call("capture_state"))
		== _collection_projection(before_failed_remove),
		"Partial removal failure must restore every collection authority."
	)
	_expect(service.call("remove_instance", added.instance_id), "A non-fixed instance must be removable by exact identity.")
	_expect(
		meta.get_card_instance(added.instance_id) == null
		and run.get_card_instance(added.instance_id) == null
		and deck.find_instance(added.instance_id) == null,
		"Exact removal must update Meta, Run, and Deck together."
	)
	var attack := _first_instance(run.card_instances, "ember_bolt")
	_expect(service.call("remove_instance", attack.instance_id), "Former fixed attacks must be removable by identity.")

	if _failures == 0:
		print("PASS: card collection service keeps Meta, Run, and Deck atomic")
	quit(1 if _failures > 0 else 0)


func _first_instance(instances: Array[CardInstance], card_id: String) -> CardInstance:
	for instance in instances:
		if instance.card_id == card_id:
			return instance
	return null


func _collection_projection(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in [
		"meta_instances",
		"run_instances",
		"deck_hand",
		"deck_draw",
		"deck_discard",
		"deck_exhaust",
	]:
		var ids: Array[String] = []
		for instance in snapshot.get(key, []) as Array:
			ids.append((instance as CardInstance).instance_id)
		result[key] = ids
	var cooldown: Array[Dictionary] = []
	for entry in snapshot.get("deck_cooldown", []) as Array:
		var instance := entry.get("instance") as CardInstance
		cooldown.append({
			"instance_id": instance.instance_id if instance != null else "",
			"remaining_seconds": float(entry.get("remaining_seconds", 0.0)),
			"duration_seconds": float(entry.get("duration_seconds", 0.0)),
		})
	result["deck_cooldown"] = cooldown
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
