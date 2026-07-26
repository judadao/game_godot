class_name DeckManager
extends RefCounted

const FIXED_CARD_IDS: Array[String] = ["ember_bolt", "quickstep"]

var hand_size: int = 8
var max_energy: float = 5.0
var energy: float = 5.0

# Legacy ID views remain available to existing callers. The corresponding
# instance arrays below are the runtime authority.
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var draw_instances: Array[Dictionary] = []
var hand_instances: Array[Dictionary] = []
var discard_instances: Array[Dictionary] = []
var exhaust_instances: Array[Dictionary] = []
var cooldown_pile: Array[Dictionary] = []
var protected_card_id := "ember_bolt"
var protected_card_ids: Array[String] = FIXED_CARD_IDS.duplicate()
var last_play_retained := false

var _card_database: RefCounted
var _protected_instance_ids: Dictionary = {}


func _init(card_database: RefCounted = null) -> void:
	_card_database = card_database


func set_protected_cards(_card_ids: Array) -> void:
	protected_card_ids = FIXED_CARD_IDS.duplicate()
	protected_card_id = FIXED_CARD_IDS[0]


func is_card_protected(card_or_instance: Variant) -> bool:
	if card_or_instance is Dictionary:
		var instance := card_or_instance as Dictionary
		return _protected_instance_ids.has(int(instance.get("instance_id", 0)))
	return _effective_protected_ids().has(String(card_or_instance))


func start(deck_ids: Array, starting_energy: float = 5.0, shuffle_deck: bool = false) -> void:
	draw_instances.clear()
	hand_instances.clear()
	discard_instances.clear()
	exhaust_instances.clear()
	cooldown_pile.clear()
	_protected_instance_ids.clear()
	var protected_instances: Dictionary = {}
	for raw_card in deck_ids:
		var instance := _coerce_card_instance(raw_card)
		if instance.is_empty() or not _has_card(String(instance.get("card_id", ""))):
			continue
		var card_id: String = String(instance.get("card_id", ""))
		if _effective_protected_ids().has(card_id):
			if not protected_instances.has(card_id):
				instance["level"] = 1
				protected_instances[card_id] = instance
			continue
		draw_instances.append(instance)
	for fixed_id in FIXED_CARD_IDS:
		if not protected_instances.has(fixed_id) and _has_card(fixed_id):
			protected_instances[fixed_id] = CardInstance.new(fixed_id, 1).to_dict()
	max_energy = maxf(0.0, starting_energy)
	energy = max_energy
	if shuffle_deck:
		draw_instances.shuffle()
	for protected_id in _effective_protected_ids():
		if hand_instances.size() >= hand_size:
			break
		if protected_instances.has(protected_id):
			var protected_instance := protected_instances[protected_id] as Dictionary
			hand_instances.append(protected_instance)
			_protected_instance_ids[int(protected_instance.get("instance_id", 0))] = true
	_sync_legacy_piles()
	draw_cards(hand_size - hand_instances.size())


func draw_cards(count: int) -> Array[Dictionary]:
	_sync_instances_from_legacy()
	var drawn: Array[Dictionary] = []
	for _draw_index in range(maxi(0, count)):
		if draw_instances.is_empty():
			_reshuffle_discard()
		if draw_instances.is_empty():
			break
		var instance: Dictionary = draw_instances.pop_front()
		hand_instances.append(instance)
		drawn.append(instance)
	_sync_legacy_piles()
	return drawn


func play_from_hand(index: int, cost_override: int = -1) -> Dictionary:
	_sync_instances_from_legacy()
	last_play_retained = false
	if index < 0 or index >= hand_instances.size() or _card_database == null:
		return {}
	var instance := hand_instances[index]
	var card_id: String = String(instance.get("card_id", ""))
	var card := _card_database.call("get_card", card_id) as Dictionary
	if card.is_empty():
		return {}
	var cost: int = maxi(0, cost_override if cost_override >= 0 else int(card.get("cost", 0)))
	if cost > energy:
		return {}
	energy -= cost
	if is_card_protected(instance):
		last_play_retained = true
		return card
	hand_instances.remove_at(index)
	var cooldown_seconds: float = maxf(0.0, float(card.get("cooldown", 0.0)))
	if bool(card.get("exhaust_on_play", false)) or String(card.get("type", "")) == "combo":
		exhaust_instances.append(instance)
	elif cooldown_seconds > 0.0:
		cooldown_pile.append({"instance": instance, "remaining_seconds": cooldown_seconds})
	else:
		discard_instances.append(instance)
	_sync_legacy_piles()
	return card


func tick_cooldowns(delta: float) -> Array[Dictionary]:
	var released: Array[Dictionary] = []
	if delta <= 0.0:
		return released
	var remaining_entries: Array[Dictionary] = []
	for entry in cooldown_pile:
		var remaining_seconds: float = maxf(0.0, float(entry.get("remaining_seconds", 0.0)) - delta)
		var instance := _coerce_card_instance(entry.get("instance"))
		if instance.is_empty():
			continue
		if remaining_seconds <= 0.0:
			discard_instances.append(instance)
			released.append(instance)
		else:
			remaining_entries.append({"instance": instance, "remaining_seconds": remaining_seconds})
	cooldown_pile = remaining_entries
	_sync_legacy_piles()
	return released


func regenerate_energy(delta: float, rate: float) -> float:
	if delta <= 0.0 or rate <= 0.0 or energy >= max_energy:
		return 0.0
	var previous := energy
	energy = minf(max_energy, energy + delta * rate)
	return energy - previous


func redraw_hand_for_all_energy() -> bool:
	_sync_instances_from_legacy()
	if energy < max_energy or hand_instances.is_empty():
		return false
	energy = 0.0
	var retained := _extract_protected_hand()
	hand_instances.clear()
	hand_instances.append_array(retained)
	_sync_legacy_piles()
	draw_cards(hand_size - hand_instances.size())
	return not hand_instances.is_empty()


func end_turn() -> void:
	_sync_instances_from_legacy()
	var retained := _extract_protected_hand()
	hand_instances.clear()
	hand_instances.append_array(retained)
	energy = max_energy
	_sync_legacy_piles()
	draw_cards(hand_size - hand_instances.size())


func _reshuffle_discard() -> void:
	if discard_instances.is_empty():
		return
	draw_instances.assign(discard_instances)
	discard_instances.clear()


func _extract_protected_hand() -> Array[Dictionary]:
	var retained: Array[Dictionary] = []
	for instance in hand_instances:
		if is_card_protected(instance):
			retained.append(instance)
		else:
			discard_instances.append(instance)
	return retained


func _effective_protected_ids() -> Array[String]:
	return FIXED_CARD_IDS


func _has_card(card_id: String) -> bool:
	return _card_database == null or bool(_card_database.call("has_card", card_id))


func _sync_legacy_piles() -> void:
	draw_pile = _card_ids_from_instances(draw_instances)
	hand = _card_ids_from_instances(hand_instances)
	discard_pile = _card_ids_from_instances(discard_instances)
	exhaust_pile = _card_ids_from_instances(exhaust_instances)


func _sync_instances_from_legacy() -> void:
	draw_instances = _match_legacy_ids(draw_instances, draw_pile)
	hand_instances = _match_legacy_ids(hand_instances, hand)
	discard_instances = _match_legacy_ids(discard_instances, discard_pile)
	exhaust_instances = _match_legacy_ids(exhaust_instances, exhaust_pile)


func _match_legacy_ids(existing: Array[Dictionary], legacy_ids: Array[String]) -> Array[Dictionary]:
	if legacy_ids == _card_ids_from_instances(existing):
		return existing
	var matched: Array[Dictionary] = []
	var remaining := existing.duplicate(true)
	for card_id in legacy_ids:
		var matched_index := -1
		for index in remaining.size():
			if String(remaining[index].get("card_id", "")) == card_id:
				matched_index = index
				break
		if matched_index >= 0:
			matched.append(remaining[matched_index])
			remaining.remove_at(matched_index)
		else:
			matched.append(CardInstance.new(card_id).to_dict())
	return matched


func _card_ids_from_instances(instances: Array[Dictionary]) -> Array[String]:
	var card_ids: Array[String] = []
	for instance in instances:
		card_ids.append(String(instance.get("card_id", "")))
	return card_ids


func _coerce_card_instance(raw_card: Variant) -> Dictionary:
	if raw_card is Dictionary:
		var dictionary_card := raw_card as Dictionary
		var restored: Variant = CardInstance.from_dict(dictionary_card)
		if restored != null:
			return restored.to_dict()
		var legacy_card_id: String = String(dictionary_card.get("card_id", ""))
		if legacy_card_id.is_empty():
			return {}
		var legacy_level: int = clampi(int(dictionary_card.get("level", 1)), 1, 3)
		if FIXED_CARD_IDS.has(legacy_card_id):
			legacy_level = 1
		return CardInstance.new(legacy_card_id, legacy_level).to_dict()
	var card_id: String = String(raw_card).strip_edges()
	if card_id.is_empty():
		return {}
	return CardInstance.new(card_id).to_dict()
