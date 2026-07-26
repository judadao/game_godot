class_name RunState
extends RefCounted

var active := false
var level := 1
var experience := 0
var experience_required := 40
var pending_level_ups := 0
var energy := 5.0
var max_energy := 5.0
var starting_deck: Array[String] = []
var temporary_cards: Array[String] = []
# Shared card levels are retained as legacy migration input only.
var card_levels: Dictionary = {}
var card_instances: Array[CardInstance] = []
var combo_count := 0
var temporary_buffs: Dictionary = {}
var gold_earned := 0
var materials_earned: Dictionary = {}
var defeated_enemies := 0
var elite_defeated := false
var boss_defeated := false


func begin_run(deck_ids: Array = []) -> void:
	_reset_transient()
	active = true
	var seen_instance_ids: Dictionary = {}
	for raw_card in deck_ids:
		var instance := _coerce_card_instance(raw_card)
		if instance == null:
			continue
		if seen_instance_ids.has(instance.instance_id):
			instance = CardInstance.new(instance.card_id, instance.level)
		seen_instance_ids[instance.instance_id] = true
		card_instances.append(instance)
		starting_deck.append(instance.card_id)


func finish_run(victory: bool) -> Dictionary:
	var summary := {
		"victory": victory,
		"gold": gold_earned,
		"materials": materials_earned.duplicate(true),
		"defeated_enemies": defeated_enemies,
		"elite_defeated": elite_defeated,
		"boss_defeated": boss_defeated,
	}
	_reset_transient()
	return summary


func add_reward(resource_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if resource_id == "gold":
		gold_earned += amount
	else:
		materials_earned[resource_id] = int(materials_earned.get(resource_id, 0)) + amount


func add_experience(amount: int) -> int:
	if amount <= 0 or not active:
		return 0
	var queued := 0
	experience += amount
	while experience >= experience_required:
		experience -= experience_required
		level += 1
		pending_level_ups += 1
		queued += 1
		experience_required = int(ceil(float(experience_required) * 1.32 + 12.0))
	return queued


func consume_pending_level() -> bool:
	if pending_level_ups <= 0:
		return false
	pending_level_ups -= 1
	return true


func get_card_instance(instance_id: String) -> CardInstance:
	for instance in card_instances:
		if instance.instance_id == instance_id:
			return instance
	return null


func get_card_instance_payloads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in card_instances:
		result.append(instance.to_dict())
	return result


func upgrade_card_instance(instance_id: String) -> bool:
	var instance := get_card_instance(instance_id)
	if instance == null or instance.level >= CardInstance.MAX_LEVEL:
		return false
	instance.level += 1
	return true


func set_card_instance_level(instance_id: String, level: int) -> bool:
	var instance := get_card_instance(instance_id)
	if (
		instance == null
		or level < CardInstance.MIN_LEVEL
		or level > CardInstance.MAX_LEVEL
	):
		return false
	instance.level = level
	return true


func add_card_instance(card_id: String, level: int = CardInstance.MIN_LEVEL) -> CardInstance:
	if card_id.is_empty():
		return null
	var instance := CardInstance.new(card_id, level)
	return instance if add_existing_card_instance(instance) else null


func add_existing_card_instance(instance: CardInstance) -> bool:
	if (
		instance == null
		or not instance.is_valid()
		or get_card_instance(instance.instance_id) != null
	):
		return false
	card_instances.append(instance)
	starting_deck.append(instance.card_id)
	return true


func remove_card_instances(instance_ids: Array[String]) -> bool:
	if instance_ids.is_empty():
		return false
	var wanted: Dictionary = {}
	for instance_id in instance_ids:
		if instance_id.is_empty() or wanted.has(instance_id):
			return false
		var instance := get_card_instance(instance_id)
		if instance == null:
			return false
		wanted[instance_id] = true
	var retained: Array[CardInstance] = []
	for instance in card_instances:
		if not wanted.has(instance.instance_id):
			retained.append(instance)
	card_instances = retained
	_sync_starting_deck()
	return true


func _reset_transient() -> void:
	active = false
	level = 1
	experience = 0
	experience_required = 40
	pending_level_ups = 0
	energy = max_energy
	starting_deck.clear()
	temporary_cards.clear()
	card_levels.clear()
	card_instances.clear()
	combo_count = 0
	temporary_buffs.clear()
	gold_earned = 0
	materials_earned.clear()
	defeated_enemies = 0
	elite_defeated = false
	boss_defeated = false


func _coerce_card_instance(raw_card: Variant) -> CardInstance:
	if raw_card is CardInstance:
		return raw_card
	if raw_card is Dictionary:
		return CardInstance.from_dict(raw_card as Dictionary)
	var card_id := String(raw_card).strip_edges()
	return CardInstance.new(card_id) if not card_id.is_empty() else null


func _sync_starting_deck() -> void:
	starting_deck.clear()
	for instance in card_instances:
		starting_deck.append(instance.card_id)
