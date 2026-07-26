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
# Legacy card_levels are read only during migration. Runtime progression owns
# each card instance independently in card_instances.
var card_levels: Dictionary = {}
var card_instances: Array[Dictionary] = []
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
	for raw_card in deck_ids:
		var instance := _coerce_card_instance(raw_card)
		if instance.is_empty():
			continue
		card_instances.append(instance)
		starting_deck.append(String(instance.get("card_id", "")))


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


func get_card_instance(instance_id: int) -> Dictionary:
	for instance in card_instances:
		if int(instance.get("instance_id", 0)) == instance_id:
			return instance.duplicate(true)
	return {}


func set_card_instance_level(instance_id: int, level: int) -> bool:
	if level < CardInstance.MIN_LEVEL or level > CardInstance.MAX_LEVEL:
		return false
	for instance in card_instances:
		if int(instance.get("instance_id", 0)) == instance_id:
			instance["level"] = level
			return true
	return false


func remove_card_instances(instance_ids: Array[int]) -> bool:
	if instance_ids.size() != 2 or instance_ids[0] == instance_ids[1]:
		return false
	var wanted: Dictionary = {}
	for instance_id in instance_ids:
		wanted[instance_id] = true
	var retained: Array[Dictionary] = []
	for instance in card_instances:
		if wanted.has(int(instance.get("instance_id", 0))):
			continue
		retained.append(instance)
	if retained.size() != card_instances.size() - instance_ids.size():
		return false
	card_instances = retained
	starting_deck = _card_ids_from_instances(card_instances)
	return true


func add_card_instance(card_id: String, level: int = CardInstance.MIN_LEVEL) -> Dictionary:
	var instance := CardInstance.new(card_id, level).to_dict()
	card_instances.append(instance)
	starting_deck.append(card_id)
	return instance.duplicate(true)


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


func _coerce_card_instance(raw_card: Variant) -> Dictionary:
	if raw_card is Dictionary:
		var restored: Variant = CardInstance.from_dict(raw_card as Dictionary)
		if restored != null:
			return restored.call("to_dict") as Dictionary
	var card_id: String = String(raw_card).strip_edges()
	if card_id.is_empty():
		return {}
	return CardInstance.new(card_id).to_dict()


func _card_ids_from_instances(instances: Array[Dictionary]) -> Array[String]:
	var card_ids: Array[String] = []
	for instance in instances:
		card_ids.append(String(instance.get("card_id", "")))
	return card_ids
