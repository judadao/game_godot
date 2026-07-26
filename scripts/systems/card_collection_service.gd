class_name CardCollectionService
extends RefCounted

var _meta_state: MetaState
var _run_state: RunState
var _deck_manager: DeckManager
var _card_database: CardDatabase
var _evolution_manager: EvolutionManager


func _init(
		meta_state: MetaState = null,
		run_state: RunState = null,
		deck_manager: DeckManager = null,
		card_database: CardDatabase = null,
		evolution_manager: EvolutionManager = null
	) -> void:
	_meta_state = meta_state
	_run_state = run_state
	_deck_manager = deck_manager
	_card_database = card_database
	_evolution_manager = evolution_manager


func is_configured() -> bool:
	return (
		_meta_state != null
		and _run_state != null
		and _deck_manager != null
		and _card_database != null
		and _evolution_manager != null
	)


func get_deck_size() -> int:
	return _deck_manager.get_all_instances().size() if is_configured() else 0


func get_copy_count(card_id: String) -> int:
	if not is_configured() or card_id.is_empty():
		return 0
	var count := 0
	for instance in _deck_manager.get_all_instances():
		if instance.card_id == card_id:
			count += 1
	return count


func add_persistent_card(card_id: String) -> CardInstance:
	if (
		not is_configured()
		or not _run_state.active
		or card_id.is_empty()
		or _deck_manager.is_card_protected(card_id)
		or not _card_database.has_card(card_id)
	):
		return null
	var snapshot := capture_state()
	var instance := _meta_state.add_card_instance(card_id, CardInstance.MIN_LEVEL)
	if (
		instance == null
		or not _run_state.add_existing_card_instance(instance)
		or not _deck_manager.add_existing_instance(instance)
	):
		restore_state(snapshot)
		return null
	if not _meta_state.unlocked_cards.has(card_id):
		_meta_state.unlocked_cards.append(card_id)
	_run_state.temporary_cards.append(card_id)
	return instance


func fuse(choice: Dictionary) -> CardInstance:
	if not is_configured() or not _run_state.active:
		return null
	var left_id := str(choice.get("left_instance_id", "")).strip_edges()
	var right_id := str(choice.get("right_instance_id", "")).strip_edges()
	var result_id := str(choice.get("result_card_id", "")).strip_edges()
	if (
		left_id.is_empty()
		or right_id.is_empty()
		or left_id == right_id
		or not _card_database.has_card(result_id)
		or _shared_instance(left_id) == null
		or _shared_instance(right_id) == null
	):
		return null
	var selected_recipe := _find_selected_recipe(left_id, right_id, result_id)
	if selected_recipe.is_empty():
		return null

	var snapshot := capture_state()
	var consumed_ids: Array[String] = [left_id, right_id]
	if (
		not _deck_manager.remove_instances(consumed_ids)
		or not _run_state.remove_card_instances(consumed_ids)
		or not _meta_state.remove_card_instances(consumed_ids)
	):
		restore_state(snapshot)
		return null
	var result := _meta_state.add_card_instance(result_id, CardInstance.MIN_LEVEL)
	if (
		result == null
		or not _run_state.add_existing_card_instance(result)
		or not _deck_manager.add_existing_instance(result)
	):
		restore_state(snapshot)
		return null
	var recipe_id := str(
		selected_recipe.get("id", selected_recipe.get("recipe_id", ""))
	).strip_edges()
	if not recipe_id.is_empty() and not _meta_state.unlocked_evolutions.has(recipe_id):
		_meta_state.unlocked_evolutions.append(recipe_id)
	if not _meta_state.unlocked_cards.has(result_id):
		_meta_state.unlocked_cards.append(result_id)
	return result


func remove_instance(instance_id: String) -> bool:
	if not is_configured() or _shared_instance(instance_id) == null:
		return false
	var snapshot := capture_state()
	var instance_ids: Array[String] = [instance_id]
	if (
		_deck_manager.remove_instances(instance_ids)
		and _run_state.remove_card_instances(instance_ids)
		and _meta_state.remove_card_instances(instance_ids)
	):
		return true
	restore_state(snapshot)
	return false


func capture_state() -> Dictionary:
	if not is_configured():
		return {}
	var instance_levels: Dictionary = {}
	for instance in (
		_meta_state.selected_card_instances
		+ _run_state.card_instances
		+ _deck_manager.get_all_instances()
	):
		instance_levels[instance.instance_id] = instance.level
	var cooldown_snapshot: Array[Dictionary] = []
	for entry in _deck_manager.cooldown_pile:
		cooldown_snapshot.append(entry.duplicate())
	return {
		"meta_instances": _meta_state.selected_card_instances.duplicate(),
		"meta_unlocked_cards": _meta_state.unlocked_cards.duplicate(),
		"meta_unlocked_evolutions": _meta_state.unlocked_evolutions.duplicate(),
		"run_instances": _run_state.card_instances.duplicate(),
		"run_starting_deck": _run_state.starting_deck.duplicate(),
		"run_card_levels": _run_state.card_levels.duplicate(true),
		"run_temporary_cards": _run_state.temporary_cards.duplicate(),
		"deck_hand": _deck_manager.hand_instances.duplicate(),
		"deck_draw": _deck_manager.draw_instances.duplicate(),
		"deck_discard": _deck_manager.discard_instances.duplicate(),
		"deck_exhaust": _deck_manager.exhaust_instances.duplicate(),
		"deck_cooldown": cooldown_snapshot,
		"instance_levels": instance_levels,
	}


func restore_state(snapshot: Dictionary) -> bool:
	if not is_configured() or snapshot.is_empty():
		return false
	var instance_levels := snapshot.get("instance_levels", {}) as Dictionary
	for instance in (
		(snapshot.get("meta_instances", []) as Array)
		+ (snapshot.get("run_instances", []) as Array)
		+ (snapshot.get("deck_hand", []) as Array)
		+ (snapshot.get("deck_draw", []) as Array)
		+ (snapshot.get("deck_discard", []) as Array)
		+ (snapshot.get("deck_exhaust", []) as Array)
	):
		if instance is CardInstance and instance_levels.has(instance.instance_id):
			instance.level = int(instance_levels[instance.instance_id])
	_meta_state.selected_card_instances.assign(snapshot.get("meta_instances", []) as Array)
	_meta_state.selected_deck = _meta_state.get_selected_card_ids()
	_meta_state.unlocked_cards.assign(snapshot.get("meta_unlocked_cards", []) as Array)
	_meta_state.unlocked_evolutions.assign(
		snapshot.get("meta_unlocked_evolutions", []) as Array
	)
	_run_state.card_instances.assign(snapshot.get("run_instances", []) as Array)
	_run_state.starting_deck.assign(snapshot.get("run_starting_deck", []) as Array)
	_run_state.card_levels = (
		snapshot.get("run_card_levels", {}) as Dictionary
	).duplicate(true)
	_run_state.temporary_cards.assign(snapshot.get("run_temporary_cards", []) as Array)
	_deck_manager.hand_instances.assign(snapshot.get("deck_hand", []) as Array)
	_deck_manager.draw_instances.assign(snapshot.get("deck_draw", []) as Array)
	_deck_manager.discard_instances.assign(snapshot.get("deck_discard", []) as Array)
	_deck_manager.exhaust_instances.assign(snapshot.get("deck_exhaust", []) as Array)
	_deck_manager.cooldown_pile.assign(snapshot.get("deck_cooldown", []) as Array)
	_deck_manager.call("_sync_id_views")
	return true


func _shared_instance(instance_id: String) -> CardInstance:
	if instance_id.is_empty():
		return null
	var deck_instance := _deck_manager.find_instance(instance_id)
	var run_instance := _run_state.get_card_instance(instance_id)
	var meta_instance := _meta_state.get_card_instance(instance_id)
	if (
		deck_instance == null
		or run_instance == null
		or meta_instance == null
		or deck_instance != run_instance
		or run_instance != meta_instance
		or deck_instance.is_fixed()
	):
		return null
	return deck_instance


func _find_selected_recipe(
		left_id: String,
		right_id: String,
		result_id: String
	) -> Dictionary:
	for fusion in _evolution_manager.find_available_fusions(_run_state.card_instances):
		if (
			str(fusion.get("left_instance_id", "")) == left_id
			and str(fusion.get("right_instance_id", "")) == right_id
			and str(fusion.get("result_card_id", "")) == result_id
		):
			return fusion
	return {}
