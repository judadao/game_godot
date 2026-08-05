class_name RunState
extends RefCounted

const INITIAL_EXPERIENCE_REQUIRED := 40
const EXPERIENCE_REQUIREMENT_MULTIPLIER := 1.20
const EXPERIENCE_REQUIREMENT_FLAT_GROWTH := 12.0
const CLEAR_BONUS_RATE := 0.15
const DEATH_RETENTION_RATE := 0.65
const OUTCOME_VICTORY := &"victory"
const OUTCOME_SAFE_RETREAT := &"safe_retreat"
const OUTCOME_DEATH := &"death"
const OUTCOME_ABANDON := &"abandon"

var active := false
var level := 1
var experience := 0
var experience_required := INITIAL_EXPERIENCE_REQUIRED
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
var material_quality_earned: Dictionary = {}
var defeated_enemies := 0
var elite_defeated := false
var boss_defeated := false
var expedition_variant_id: StringName = &""
var expedition_power_tier := 1
var is_boss_run := false


func begin_run(
	deck_ids: Array = [],
	variant_id: StringName = &"",
	power_tier: int = 1,
	boss_run: bool = false
) -> void:
	_reset_transient()
	active = true
	expedition_variant_id = variant_id
	expedition_power_tier = maxi(1, power_tier)
	is_boss_run = boss_run
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


func finish_run(victory: bool, requested_outcome: StringName = &"") -> Dictionary:
	var outcome := requested_outcome
	if outcome not in [OUTCOME_VICTORY, OUTCOME_SAFE_RETREAT, OUTCOME_DEATH, OUTCOME_ABANDON]:
		outcome = OUTCOME_VICTORY if victory else OUTCOME_DEATH
	var settled_victory := outcome == OUTCOME_VICTORY
	var retention_rate := 1.0
	if outcome == OUTCOME_DEATH:
		retention_rate = DEATH_RETENTION_RATE
	elif outcome == OUTCOME_ABANDON:
		retention_rate = 0.0
	var retained_gold := roundi(float(gold_earned) * retention_rate)
	var retained_materials: Dictionary = {}
	for resource_id in materials_earned:
		var retained_amount := roundi(float(materials_earned[resource_id]) * retention_rate)
		if retained_amount > 0:
			retained_materials[resource_id] = retained_amount
	if settled_victory:
		retained_gold = roundi(float(retained_gold) * (1.0 + CLEAR_BONUS_RATE))
		for resource_id in retained_materials:
			retained_materials[resource_id] = roundi(
				float(retained_materials[resource_id]) * (1.0 + CLEAR_BONUS_RATE)
			)
	var retained_material_qualities: Dictionary = {}
	for resource_id in retained_materials:
		var source_qualities := material_quality_earned.get(resource_id, {}) as Dictionary
		if source_qualities.is_empty() and int(materials_earned.get(resource_id, 0)) > 0:
			source_qualities = {"common": int(materials_earned[resource_id])}
		var retained_qualities := _distribute_quality_total(
			source_qualities,
			int(retained_materials[resource_id])
		)
		if not retained_qualities.is_empty():
			retained_material_qualities[resource_id] = retained_qualities
	var summary := {
		"victory": settled_victory,
		"outcome": String(outcome),
		"base_gold": gold_earned,
		"base_materials": materials_earned.duplicate(true),
		"gold": retained_gold,
		"materials": retained_materials,
		"material_qualities": retained_material_qualities,
		"retention_rate": retention_rate,
		"completion_bonus_rate": CLEAR_BONUS_RATE if settled_victory else 0.0,
		"chest_reward": (
			(temporary_buffs.get("completion_chest_reward", {}) as Dictionary).duplicate(true)
			if settled_victory
			else {}
		),
		"defeated_enemies": defeated_enemies,
		"elite_defeated": elite_defeated,
		"boss_defeated": boss_defeated,
		"expedition_variant_id": String(expedition_variant_id),
		"expedition_power_tier": expedition_power_tier,
		"is_boss_run": is_boss_run,
	}
	_reset_transient()
	return summary


func add_reward(
	resource_id: String,
	amount: int,
	quality: StringName = &"common"
) -> void:
	if amount <= 0:
		return
	if resource_id == "gold":
		gold_earned += amount
	else:
		materials_earned[resource_id] = int(materials_earned.get(resource_id, 0)) + amount
		if not material_quality_earned.has(resource_id):
			material_quality_earned[resource_id] = {}
		var quality_counts := material_quality_earned[resource_id] as Dictionary
		quality_counts[String(quality)] = int(
			quality_counts.get(String(quality), 0)
		) + amount


func _distribute_quality_total(source: Dictionary, target_total: int) -> Dictionary:
	if source.is_empty() or target_total <= 0:
		return {}
	var source_total := 0
	for count_variant in source.values():
		source_total += maxi(0, int(count_variant))
	if source_total <= 0:
		return {}
	var result: Dictionary = {}
	var remainders: Array[Dictionary] = []
	var assigned := 0
	for quality_variant in source:
		var exact := float(maxi(0, int(source[quality_variant]))) * float(target_total) / float(source_total)
		var base := floori(exact)
		if base > 0:
			result[String(quality_variant)] = base
		assigned += base
		remainders.append({"quality": String(quality_variant), "fraction": exact - float(base)})
	remainders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.get("fraction", 0.0)) > float(right.get("fraction", 0.0))
	)
	var remainder_index := 0
	while assigned < target_total and not remainders.is_empty():
		var quality := String(remainders[remainder_index % remainders.size()].get("quality", "common"))
		result[quality] = int(result.get(quality, 0)) + 1
		assigned += 1
		remainder_index += 1
	return result


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
		experience_required = int(ceil(
			float(experience_required) * EXPERIENCE_REQUIREMENT_MULTIPLIER
				+ EXPERIENCE_REQUIREMENT_FLAT_GROWTH
		))
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
	if (
		instance == null
		or instance.is_growth_locked()
		or instance.level >= CardInstance.MAX_LEVEL
	):
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
	experience_required = INITIAL_EXPERIENCE_REQUIRED
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
	material_quality_earned.clear()
	defeated_enemies = 0
	elite_defeated = false
	boss_defeated = false
	expedition_variant_id = &""
	expedition_power_tier = 1
	is_boss_run = false


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
