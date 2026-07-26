class_name DeckManager
extends RefCounted

const FIXED_CARD_IDS: Array[String] = ["ember_bolt", "quickstep"]

var hand_size: int = 8
var max_energy: float = 5.0
var energy: float = 5.0
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var draw_instances: Array[CardInstance] = []
var hand_instances: Array[CardInstance] = []
var discard_instances: Array[CardInstance] = []
var exhaust_instances: Array[CardInstance] = []
var cooldown_pile: Array[Dictionary] = []
var protected_card_id := "ember_bolt"
var protected_card_ids: Array[String] = FIXED_CARD_IDS.duplicate()
var last_play_retained := false

var _card_database: RefCounted
var _protected_instance_ids: Dictionary = {}
var _cooldowns_paused := false


func _init(card_database: RefCounted = null) -> void:
	_card_database = card_database


func set_protected_cards(_card_ids: Array) -> void:
	protected_card_ids = FIXED_CARD_IDS.duplicate()
	protected_card_id = FIXED_CARD_IDS[0]


func is_card_protected(card_or_instance: Variant) -> bool:
	if card_or_instance is CardInstance:
		return _protected_instance_ids.has((card_or_instance as CardInstance).instance_id)
	return FIXED_CARD_IDS.has(String(card_or_instance))


func start(deck_ids: Array, starting_energy: float = 5.0, shuffle_deck: bool = false) -> void:
	draw_instances.clear()
	hand_instances.clear()
	discard_instances.clear()
	exhaust_instances.clear()
	cooldown_pile.clear()
	_protected_instance_ids.clear()
	var fixed_instances: Dictionary = {}
	var seen_instance_ids: Dictionary = {}
	for raw_card in deck_ids:
		var instance := _coerce_card_instance(raw_card)
		if instance == null or not _has_card(instance.card_id):
			continue
		if seen_instance_ids.has(instance.instance_id):
			instance = CardInstance.new(instance.card_id, instance.level)
		seen_instance_ids[instance.instance_id] = true
		if FIXED_CARD_IDS.has(instance.card_id):
			if not fixed_instances.has(instance.card_id):
				instance.level = CardInstance.MIN_LEVEL
				fixed_instances[instance.card_id] = instance
			continue
		draw_instances.append(instance)
	max_energy = maxf(0.0, starting_energy)
	energy = max_energy
	if shuffle_deck:
		draw_instances.shuffle()
	for fixed_id in FIXED_CARD_IDS:
		if hand_instances.size() >= hand_size:
			break
		if fixed_instances.has(fixed_id):
			var fixed_instance := fixed_instances[fixed_id] as CardInstance
			hand_instances.append(fixed_instance)
			_protected_instance_ids[fixed_instance.instance_id] = true
	_sync_id_views()
	draw_cards(hand_size - hand_instances.size())


func draw_cards(count: int) -> Array[String]:
	var drawn_instances := draw_card_instances(count)
	return _card_ids(drawn_instances)


func draw_card_instances(count: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for _draw_index in range(maxi(0, count)):
		if draw_instances.is_empty():
			_reshuffle_discard()
		if draw_instances.is_empty():
			break
		var instance := draw_instances.pop_front() as CardInstance
		hand_instances.append(instance)
		drawn.append(instance)
	_sync_id_views()
	return drawn


func play_from_hand(index: int, cost_override: int = -1) -> Dictionary:
	last_play_retained = false
	if index < 0 or index >= hand_instances.size() or _card_database == null:
		return {}
	var instance := hand_instances[index]
	var card := _card_database.call("get_card", instance.card_id) as Dictionary
	if card.is_empty():
		return {}
	var cost := maxi(0, cost_override if cost_override >= 0 else int(card.get("cost", 0)))
	if cost > energy:
		return {}
	energy -= cost
	if is_card_protected(instance):
		last_play_retained = true
		return _project_played_card(card, instance)
	hand_instances.remove_at(index)
	var destination := String(card.get("play_destination", "")).strip_edges()
	if destination.is_empty():
		if bool(card.get("exhaust_on_play", false)):
			destination = "exhaust"
		elif float(card.get("cooldown_seconds", 0.0)) > 0.0:
			destination = "cooldown"
		else:
			destination = "discard"
	match destination:
		"exhaust":
			exhaust_instances.append(instance)
		"cooldown":
			var duration := maxf(0.0, float(card.get("cooldown_seconds", 0.0)))
			if duration > 0.0:
				cooldown_pile.append({
					"instance": instance,
					"remaining_seconds": duration,
					"duration_seconds": duration,
				})
			else:
				discard_instances.append(instance)
		_:
			discard_instances.append(instance)
	_sync_id_views()
	return _project_played_card(card, instance)


func set_cooldowns_paused(paused: bool) -> void:
	_cooldowns_paused = paused


func tick_cooldowns(delta: float) -> Array[CardInstance]:
	var released: Array[CardInstance] = []
	if delta <= 0.0 or _cooldowns_paused:
		return released
	var pending: Array[Dictionary] = []
	for entry in cooldown_pile:
		var instance := entry.get("instance") as CardInstance
		if instance == null:
			continue
		var remaining := maxf(0.0, float(entry.get("remaining_seconds", 0.0)) - delta)
		if is_zero_approx(remaining):
			discard_instances.append(instance)
			released.append(instance)
			continue
		pending.append({
			"instance": instance,
			"remaining_seconds": remaining,
			"duration_seconds": float(entry.get("duration_seconds", remaining)),
		})
	cooldown_pile = pending
	_sync_id_views()
	return released


func regenerate_energy(delta: float, rate: float) -> float:
	if delta <= 0.0 or rate <= 0.0 or energy >= max_energy:
		return 0.0
	var previous := energy
	energy = minf(max_energy, energy + delta * rate)
	return energy - previous


func redraw_hand_for_all_energy() -> bool:
	if energy < max_energy or hand_instances.is_empty():
		return false
	energy = 0.0
	var retained := _extract_protected_hand()
	hand_instances.clear()
	hand_instances.append_array(retained)
	_sync_id_views()
	draw_cards(hand_size - hand_instances.size())
	return not hand_instances.is_empty()


func end_turn() -> void:
	var retained := _extract_protected_hand()
	hand_instances.clear()
	hand_instances.append_array(retained)
	energy = max_energy
	_sync_id_views()
	draw_cards(hand_size - hand_instances.size())


func _reshuffle_discard() -> void:
	if discard_instances.is_empty():
		return
	draw_instances.assign(discard_instances)
	discard_instances.clear()


func _extract_protected_hand() -> Array[CardInstance]:
	var retained: Array[CardInstance] = []
	for instance in hand_instances:
		if is_card_protected(instance):
			retained.append(instance)
		else:
			discard_instances.append(instance)
	return retained


func _effective_protected_ids() -> Array[String]:
	return FIXED_CARD_IDS


func find_hand_index(instance_id: String) -> int:
	for index in hand_instances.size():
		if hand_instances[index].instance_id == instance_id:
			return index
	return -1


func find_instance(instance_id: String) -> CardInstance:
	for instance in get_all_instances():
		if instance.instance_id == instance_id:
			return instance
	return null


func get_all_instances() -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var seen: Dictionary = {}
	for pile in [hand_instances, draw_instances, discard_instances, exhaust_instances]:
		for instance in pile:
			if not seen.has(instance.instance_id):
				seen[instance.instance_id] = true
				result.append(instance)
	for entry in cooldown_pile:
		var instance := entry.get("instance") as CardInstance
		if instance != null and not seen.has(instance.instance_id):
			seen[instance.instance_id] = true
			result.append(instance)
	return result


func upgrade_instance(instance_id: String) -> bool:
	var instance := find_instance(instance_id)
	if instance == null or instance.is_fixed() or instance.level >= CardInstance.MAX_LEVEL:
		return false
	instance.level += 1
	return true


func add_instance(card_id: String, level: int = CardInstance.MIN_LEVEL) -> CardInstance:
	if card_id.is_empty() or FIXED_CARD_IDS.has(card_id) or not _has_card(card_id):
		return null
	var instance := CardInstance.new(card_id, level)
	discard_instances.append(instance)
	_sync_id_views()
	return instance


func remove_instances(instance_ids: Array[String]) -> bool:
	var wanted := _validated_removal_set(instance_ids)
	if wanted.is_empty():
		return false
	hand_instances = _without_instances(hand_instances, wanted)
	draw_instances = _without_instances(draw_instances, wanted)
	discard_instances = _without_instances(discard_instances, wanted)
	exhaust_instances = _without_instances(exhaust_instances, wanted)
	var retained_cooldowns: Array[Dictionary] = []
	for entry in cooldown_pile:
		var instance := entry.get("instance") as CardInstance
		if instance == null or not wanted.has(instance.instance_id):
			retained_cooldowns.append(entry)
	cooldown_pile = retained_cooldowns
	_sync_id_views()
	return true


func _validated_removal_set(instance_ids: Array[String]) -> Dictionary:
	if instance_ids.is_empty():
		return {}
	var wanted: Dictionary = {}
	for instance_id in instance_ids:
		if instance_id.is_empty() or wanted.has(instance_id):
			return {}
		var instance := find_instance(instance_id)
		if instance == null or instance.is_fixed():
			return {}
		wanted[instance_id] = true
	return wanted


func _without_instances(
		source: Array[CardInstance],
		wanted: Dictionary
	) -> Array[CardInstance]:
	var retained: Array[CardInstance] = []
	for instance in source:
		if not wanted.has(instance.instance_id):
			retained.append(instance)
	return retained


func _coerce_card_instance(raw_card: Variant) -> CardInstance:
	if raw_card is CardInstance:
		return raw_card
	if raw_card is Dictionary:
		return CardInstance.from_dict(raw_card as Dictionary)
	var card_id := String(raw_card).strip_edges()
	return CardInstance.new(card_id) if not card_id.is_empty() else null


func _has_card(card_id: String) -> bool:
	return _card_database == null or bool(_card_database.call("has_card", card_id))


func _sync_id_views() -> void:
	draw_pile = _card_ids(draw_instances)
	hand = _card_ids(hand_instances)
	discard_pile = _card_ids(discard_instances)
	exhaust_pile = _card_ids(exhaust_instances)


func _card_ids(instances: Array[CardInstance]) -> Array[String]:
	var result: Array[String] = []
	for instance in instances:
		result.append(instance.card_id)
	return result


func _project_played_card(card: Dictionary, instance: CardInstance) -> Dictionary:
	var result := card.duplicate(true)
	result["instance_id"] = instance.instance_id
	result["card_level"] = instance.level
	result["card_instance"] = instance
	return result
