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
var card_levels: Dictionary = {}
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
	for card_id in deck_ids:
		starting_deck.append(String(card_id))


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
	combo_count = 0
	temporary_buffs.clear()
	gold_earned = 0
	materials_earned.clear()
	defeated_enemies = 0
	elite_defeated = false
	boss_defeated = false
