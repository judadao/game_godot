class_name CardEffectRunner
extends Node

signal effect_resolved(card_id: String, result: Dictionary)

const SUPPORTED_EFFECTS := [
	"damage", "area_damage", "block", "heal", "dash_impact",
	"slow", "area_slow", "stun", "attack_power", "damage_aura",
	"gain_energy", "summon", "projectile_burst", "overdrive",
	"infusion", "combat_status", "healing_pulses", "regeneration",
]
const ELEMENT_TAXONOMY_SCRIPT := preload(
	"res://scripts/systems/element_taxonomy.gd"
)
const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

var _element_taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()


func supports_effect(kind: String) -> bool:
	return SUPPORTED_EFFECTS.has(kind)


func cast(card: Dictionary, caster: Node, targets: Array) -> Dictionary:
	if card.is_empty() or caster == null:
		return {}
	var effect := (card.get("effect", {}) as Dictionary).duplicate(true)
	var kind := String(effect.get("kind", ""))
	if _is_damage_effect(effect):
		var attack_elements := _resolve_attack_elements(card, effect)
		effect = _element_taxonomy.call(
			"apply_attack_side_effects", effect, attack_elements
		) as Dictionary
	var hit_presentation := _resolve_hit_presentation(card, effect)
	var result := {
		"card_id": String(card.get("id", "")),
		"instance_id": String(card.get("instance_id", "")),
		"card_level": int(card.get("card_level", card.get("level", 1))),
		"kind": kind,
		"affected": 0,
		"total": 0,
		"play_destination": String(card.get("play_destination", "discard")),
		"cooldown_seconds": float(card.get("cooldown_seconds", 0.0)),
		"elements": (effect.get("elements", []) as Array).duplicate(),
		"element_side_effects": (
			effect.get("element_side_effects", []) as Array
		).duplicate(),
	}
	var knockback_multiplier := maxf(
		0.0, float(effect.get("knockback_multiplier", 1.0))
	)
	if (
		_is_damage_effect(effect)
		and randf() <= clampf(float(effect.get("critical_chance", 0.0)), 0.0, 1.0)
	):
		effect["amount"] = maxi(
			1,
			roundi(
				float(effect.get("amount", 0))
				* maxf(1.0, float(effect.get("critical_multiplier", 1.5)))
			)
		)
		result["critical"] = true
	else:
		result["critical"] = false

	match kind:
		"damage":
			var projectile_count := maxi(
				1,
				int(effect.get("projectile_count", effect.get("projectiles", 1)))
			)
			var direction_count := maxi(1, int(effect.get("direction_count", projectile_count)))
			var directional_sweep := (
				String(effect.get("damage_mode", "")) == "directional_sweep_once"
			)
			var selected := (
				targets.duplicate()
				if directional_sweep
				else _nearest_targets(
					caster,
					targets,
					maxi(1, int(effect.get("target_count", direction_count)))
				)
			)
			var resolved_projectile_count := mini(projectile_count, selected.size())
			var series_family := String(effect.get("series_gameplay_family", ""))
			if not series_family.is_empty():
				_resolve_series_damage(
					series_family,
					caster,
					selected,
					effect,
					result,
					hit_presentation
				)
			elif directional_sweep:
				_damage_targets(
					caster,
					selected,
					int(effect.get("amount", 0)),
					result,
					1,
					80.0 * knockback_multiplier,
					hit_presentation
				)
			else:
				_damage_projectile_volley(
					caster,
					selected,
					int(effect.get("amount", 0)),
					result,
					resolved_projectile_count,
					hit_presentation,
					80.0 * knockback_multiplier
				)
			_apply_infused_statuses(selected, effect)
			_apply_finisher_mutations(
				caster,
				selected,
				effect,
				result,
				hit_presentation
			)
		"area_damage":
			var selected := _targets_in_radius(caster, targets, float(effect.get("radius", 150.0)))
			_damage_targets(
				caster,
				selected,
				int(effect.get("amount", 0)),
				result,
				1,
				float(effect.get("knockback", 180.0)) * knockback_multiplier,
				hit_presentation
			)
			_apply_infused_statuses(selected, effect)
		"block":
			if caster.has_method("add_block"):
				caster.call("add_block", int(effect.get("amount", 0)))
				result["affected"] = 1
				result["total"] = int(effect.get("amount", 0))
		"heal":
			if caster.has_method("restore_health"):
				result["total"] = int(caster.call("restore_health", int(effect.get("amount", 0))))
				result["affected"] = 1 if int(result["total"]) > 0 else 0
		"dash_impact":
			var selected := _targets_in_radius(
				caster,
				targets,
				float(effect.get("radius", 170.0))
			)
			_damage_targets(
				caster,
				selected,
				int(effect.get("amount", 0)),
				result,
				1,
				80.0 * knockback_multiplier,
				hit_presentation
			)
			_apply_infused_statuses(selected, effect)
			_pull_targets(caster, selected, float(effect.get("pull_strength", 0.0)))
		"slow":
			_apply_status(_nearest_targets(caster, targets, 1), kind, effect, result)
		"area_slow", "stun":
			var status_id := "slow" if kind == "area_slow" else kind
			var selected := _targets_in_radius(
				caster,
				targets,
				float(effect.get("radius", 170.0))
			)
			var status_damage := int(effect.get("amount", 0)) if kind == "area_slow" else 0
			if status_damage > 0:
				_damage_targets(
					caster,
					selected,
					status_damage,
					result,
					1,
					float(effect.get("knockback", 180.0)) * knockback_multiplier,
					hit_presentation
				)
			_apply_status(
				selected,
				status_id,
				effect,
				result,
				status_damage <= 0
			)
			if status_damage > 0:
				_apply_infused_statuses(selected, effect)
		"attack_power":
			var current: Variant = caster.get("attack_power")
			if current != null:
				var health_cost := maxi(0, int(effect.get("health_cost", 0)))
				if health_cost > 0 and caster.has_method("take_damage"):
					caster.call("take_damage", health_cost)
				caster.set("attack_power", int(current) + int(effect.get("amount", 0)))
				result["affected"] = 1
		"damage_aura":
			var selected := _targets_in_radius(
				caster,
				targets,
				float(effect.get("radius", 110.0))
			)
			_damage_targets(
				caster,
				selected,
				int(effect.get("amount", 0)),
				result,
				1,
				80.0 * knockback_multiplier,
				hit_presentation
			)
			_apply_infused_statuses(selected, effect)
		"summon":
			_resolve_summon(caster, effect, result)
		"overdrive":
			var current_power: Variant = caster.get("attack_power")
			if current_power != null:
				caster.set("attack_power", int(current_power) + int(effect.get("attack_power", 0)))
				if caster.has_method("take_damage"):
					caster.call("take_damage", maxi(0, int(effect.get("health_cost", 0))))
				caster.set_meta("overdrive_duration", float(effect.get("duration", 0.0)))
				result["affected"] = 1
		"combat_status", "healing_pulses", "regeneration":
			if caster.has_method("apply_combat_status"):
				result["affected"] = 1 if bool(caster.call(
					"apply_combat_status",
					String(card.get("id", "")),
					String(card.get("name", "")),
					effect
				)) else 0
		"gain_energy", "projectile_burst", "infusion":
			result["affected"] = 1

	if int(result.get("total", 0)) > 0:
		var lifesteal_restored := 0
		if caster.has_method("resolve_lifesteal"):
			lifesteal_restored += int(caster.call("resolve_lifesteal", int(result["total"])))
		lifesteal_restored += _restore_fractional_health(
			caster,
			&"element_dark_lifesteal_remainder",
			int(result["total"]),
			float(effect.get("lifesteal_ratio", 0.0))
		)
		var element_heal_restored := _restore_fractional_health(
			caster,
			&"element_light_heal_remainder",
			int(result["total"]),
			float(effect.get("heal_on_hit_ratio", 0.0))
		)
		result["lifesteal_restored"] = lifesteal_restored
		result["element_heal_restored"] = element_heal_restored

	effect_resolved.emit(String(card.get("id", "")), result)
	return result


func _resolve_series_damage(
	family: String,
	caster: Node,
	targets: Array,
	effect: Dictionary,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	var amount := maxi(0, int(effect.get("amount", 0)))
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	var knockback := 80.0 * maxf(0.0, float(effect.get("knockback_multiplier", 1.0)))
	match family:
		"marked_execution":
			_resolve_marked_execution(caster, targets, amount, tier_rank, result, hit_presentation)
		"returning_orbit":
			_damage_targets(caster, targets, amount, result, 2, knockback, hit_presentation)
			_pull_targets(caster, targets, float(effect.get("pull_strength", 0.0)))
			result["series_rule"] = "outbound_return"
			result["return_passes"] = 1
		"moving_guard_still_barrage":
			_resolve_feather_stance(caster, targets, effect, amount, result, hit_presentation)
		"sword_aura_gate_network":
			_resolve_gate_network(caster, targets, effect, amount, result, hit_presentation)
		"ricochet_boulders":
			_resolve_ricochet(caster, targets, effect, amount, result, hit_presentation)
		"forward_guard_counter":
			_resolve_guard_counter(caster, targets, effect, amount, result, hit_presentation)
		"route_burn_detonation":
			_damage_targets(caster, targets, amount, result, 1, knockback, hit_presentation)
			if targets.size() >= 2:
				_damage_targets(caster, targets, maxi(1, roundi(amount * (0.35 + tier_rank * 0.10))), result, 1, 40.0, hit_presentation)
				result["detonated_targets"] = targets.size()
			result["series_rule"] = "burn_route_detonation"
		"target_switch_chain":
			_resolve_target_switch_chain(caster, targets, effect, amount, result, hit_presentation)
		"outbound_returning_tide":
			_damage_targets(caster, targets, amount, result, 2, knockback, hit_presentation)
			_pull_targets(caster, targets, maxf(24.0, float(effect.get("pull_strength", 0.0))))
			result["series_rule"] = "returning_tide_pull"
			result["return_passes"] = 1
		"host_growth_harvest":
			_resolve_host_harvest(caster, targets, effect, amount, result, hit_presentation)
		"crossfire_lane":
			_resolve_saved_origin_attack(caster, targets, amount, result, hit_presentation, &"dragon_breath_origin", 1, "dragon_crossfire")
		"risk_heal_judgment":
			_resolve_dawn_judgment(caster, targets, effect, amount, result, hit_presentation)
		"dual_origin_crossfire":
			_resolve_saved_origin_attack(caster, targets, amount, result, hit_presentation, &"shared_branch_origin", maxi(1, int(effect.get("finisher_echoes", effect.get("echoes", 1)))), "echo_crossfire")
		_:
			_damage_projectile_volley(caster, targets, amount, result, maxi(1, int(effect.get("projectile_count", 1))), hit_presentation, knockback)
			result["series_rule"] = "fallback_volley"


func _resolve_marked_execution(
	caster: Node,
	targets: Array,
	amount: int,
	tier_rank: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	if targets.is_empty():
		return
	var target := targets[0] as Node
	var distance := _distance_between(caster, target)
	var marks := int(target.get_meta(&"sword_rain_marks", 0))
	if distance <= 150.0 or marks <= 0:
		marks = mini(3 + tier_rank * 2, marks + tier_rank + 1)
		target.set_meta(&"sword_rain_marks", marks)
		_damage_targets(caster, [target], amount, result, 1, 60.0, hit_presentation)
		result["series_rule"] = "mark_storage"
		result["stored_marks"] = marks
		return
	var execution_damage := amount + roundi(float(amount) * float(marks) * 0.42)
	_damage_targets(caster, [target], execution_damage, result, 1, 95.0, hit_presentation)
	target.remove_meta(&"sword_rain_marks")
	result["series_rule"] = "mark_execution"
	result["executed_marks"] = marks


func _resolve_feather_stance(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	var speed := _node_velocity(caster).length()
	if speed > 18.0:
		var guard := maxi(1, int(effect.get("finisher_guard", effect.get("guard", 4))))
		if caster.has_method("add_block"):
			caster.call("add_block", guard)
		result["affected"] = int(result.get("affected", 0)) + 1
		result["guard_gained"] = guard
		result["series_rule"] = "moving_feather_guard"
		return
	_damage_projectile_volley(caster, targets, amount, result, maxi(targets.size(), int(effect.get("projectile_count", 1))), hit_presentation, 55.0)
	result["series_rule"] = "still_feather_barrage"


func _resolve_gate_network(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	var relay_count := mini(targets.size(), maxi(1, int(effect.get("relay_count", effect.get("projectile_count", 1)))))
	for relay_index in relay_count:
		var relay_damage := maxi(1, roundi(float(amount) * (1.0 + float(relay_index) * 0.22)))
		_damage_targets(caster, [targets[relay_index]], relay_damage, result, 1, 65.0, hit_presentation)
	result["series_rule"] = "gate_relay_amplification"
	result["relay_hits"] = relay_count


func _resolve_ricochet(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	if targets.is_empty():
		return
	var bounce_count := maxi(1, int(effect.get("projectile_count", 1)))
	var impact := 80.0 * maxf(1.0, float(effect.get("knockback_multiplier", 1.0)))
	if amount <= 0:
		result["series_rule"] = "stone_guard"
		result["ricochet_count"] = 0
		return
	for bounce_index in bounce_count:
		var target: Variant = targets[bounce_index % targets.size()]
		var bounce_damage := maxi(1, roundi(float(amount) * maxf(0.55, 1.0 - 0.08 * bounce_index)))
		_damage_targets(caster, [target], bounce_damage, result, 1, impact, hit_presentation)
	result["series_rule"] = "boulder_ricochet"
	result["ricochet_count"] = bounce_count


func _resolve_guard_counter(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	var guard := maxi(1, int(effect.get("finisher_guard", effect.get("guard", 4))))
	if caster.has_method("add_block"):
		caster.call("add_block", guard)
	var facing := _facing_direction(caster)
	var forward_targets: Array = []
	if caster is Node2D:
		for target in targets:
			if target is Node2D and (((target as Node2D).global_position.x - (caster as Node2D).global_position.x) * facing) >= 0.0:
				forward_targets.append(target)
	_damage_targets(caster, forward_targets, amount + roundi(guard * 0.35), result, 1, 105.0, hit_presentation)
	result["guard_gained"] = guard
	result["series_rule"] = "forward_guard_counter"


func _resolve_target_switch_chain(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	if targets.is_empty():
		return
	var primary := targets[0] as Node
	var last_target_id := int(caster.get_meta(&"lightning_last_target_id", 0))
	var switched := last_target_id != 0 and last_target_id != primary.get_instance_id()
	_damage_targets(caster, [primary], amount, result, 1, 45.0, hit_presentation)
	var chain_targets := 0
	if switched:
		for index in range(1, mini(targets.size(), 1 + maxi(1, int(effect.get("tier_rank", 1))))):
			_damage_targets(caster, [targets[index]], maxi(1, roundi(amount * 0.70)), result, 1, 35.0, hit_presentation)
			chain_targets += 1
	elif last_target_id == primary.get_instance_id():
		_damage_targets(caster, [primary], maxi(1, roundi(amount * 0.45)), result, 1, 35.0, hit_presentation)
		result["repeated_target_charge"] = true
	caster.set_meta(&"lightning_last_target_id", primary.get_instance_id())
	result["chain_targets"] = chain_targets
	result["series_rule"] = "switch_chain" if switched else "repeat_charge"


func _resolve_host_harvest(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	if targets.is_empty():
		return
	var host := targets[0] as Node
	host.set_meta(&"plant_series_host", true)
	var host_damage := amount
	if bool(effect.get("death_spread", false)):
		host_damage = maxi(amount, roundi(amount * 1.4))
	_damage_targets(caster, [host], host_damage, result, 1, 35.0, hit_presentation)
	var linked := targets.slice(1)
	if not linked.is_empty():
		_damage_targets(caster, linked, maxi(1, roundi(amount * 0.55)), result, 1, 25.0, hit_presentation)
	var spread_count := 0
	if bool(effect.get("death_spread", false)) and _node_health(host) <= 0:
		_damage_targets(caster, linked, maxi(1, roundi(amount * 0.8)), result, 1, 45.0, hit_presentation)
		spread_count = linked.size()
	result["harvest_spread_targets"] = spread_count
	result["series_rule"] = "host_growth_harvest"


func _resolve_saved_origin_attack(
	caster: Node,
	targets: Array,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary,
	meta_key: StringName,
	extra_origin_hits: int,
	rule_name: String
) -> void:
	var current_position := (caster as Node2D).global_position if caster is Node2D else Vector2.ZERO
	var has_origin := caster.has_meta(meta_key)
	var origin: Vector2 = caster.get_meta(meta_key, current_position) as Vector2
	if not has_origin:
		caster.set_meta(meta_key, current_position)
	_damage_targets(caster, targets, amount, result, 1, 55.0, hit_presentation)
	var origin_count := 1
	if has_origin and origin.distance_to(current_position) >= 48.0:
		_damage_targets(caster, targets, maxi(1, roundi(amount * 0.75)), result, extra_origin_hits, 40.0, hit_presentation)
		origin_count += extra_origin_hits
		caster.set_meta(meta_key, current_position)
	result["attack_origins"] = origin_count
	result["series_rule"] = rule_name


func _resolve_dawn_judgment(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	hit_presentation: Dictionary
) -> void:
	var current_position := (caster as Node2D).global_position if caster is Node2D else Vector2.ZERO
	var light_origin: Vector2 = caster.get_meta(&"dawn_light_origin", current_position) as Vector2
	if not caster.has_meta(&"dawn_light_origin"):
		caster.set_meta(&"dawn_light_origin", current_position)
	var far_from_light := light_origin.distance_to(current_position) >= 140.0
	if far_from_light:
		_damage_targets(caster, targets, maxi(1, roundi(amount * 1.8)), result, 1, 75.0, hit_presentation)
		result["series_rule"] = "distant_judgment"
		return
	_damage_targets(caster, targets, amount, result, 1, 45.0, hit_presentation)
	var heal := maxi(1, int(effect.get("finisher_heal", effect.get("heal", 6))))
	if caster.has_method("restore_health"):
		result["dawn_healed"] = int(caster.call("restore_health", heal))
	result["series_rule"] = "near_light_heal"


func _distance_between(first: Node, second: Node) -> float:
	if first is Node2D and second is Node2D:
		return (first as Node2D).global_position.distance_to((second as Node2D).global_position)
	return INF


func _node_velocity(node: Node) -> Vector2:
	if node is CharacterBody2D:
		return (node as CharacterBody2D).velocity
	var velocity_variant: Variant = node.get("velocity")
	return velocity_variant as Vector2 if velocity_variant is Vector2 else Vector2.ZERO


func _facing_direction(node: Node) -> float:
	var facing_variant: Variant = node.get("facing_direction")
	return -1.0 if facing_variant != null and int(facing_variant) < 0 else 1.0


func _node_health(node: Node) -> int:
	var health_variant: Variant = node.get("health")
	return int(health_variant) if health_variant != null else 1


func _is_damage_effect(effect: Dictionary) -> bool:
	var kind := String(effect.get("kind", ""))
	return (
		kind in ["damage", "area_damage", "dash_impact", "damage_aura"]
		or (kind == "area_slow" and int(effect.get("amount", 0)) > 0)
	)


func _restore_fractional_health(
	caster: Node,
	remainder_key: StringName,
	damage_total: int,
	ratio: float
) -> int:
	if damage_total <= 0 or ratio <= 0.0 or not caster.has_method("restore_health"):
		return 0
	var accumulated := (
		float(caster.get_meta(remainder_key, 0.0))
		+ float(damage_total) * ratio
	)
	var whole_health := floori(accumulated + 0.000001)
	caster.set_meta(remainder_key, accumulated - float(whole_health))
	if whole_health <= 0:
		return 0
	return int(caster.call("restore_health", whole_health))


func _damage_targets(
	caster: Node,
	targets: Array,
	raw_damage: int,
	result: Dictionary,
	hits: int = 1,
	knockback: float = 80.0,
	hit_presentation: Dictionary = {}
) -> void:
	for target in targets:
		if not target is Node or not is_instance_valid(target):
			continue
		var target_total := 0
		for _hit in hits:
			if not is_instance_valid(target):
				break
			if target.has_method("take_hit"):
				_prepare_target_hit_presentation(target, hit_presentation)
				var source := (caster as Node2D).global_position if caster is Node2D else Vector2.ZERO
				target_total += int(target.call("take_hit", raw_damage, source, knockback))
			elif target.has_method("take_damage"):
				target_total += int(target.call("take_damage", raw_damage))
		if target_total > 0:
			result["affected"] = int(result["affected"]) + 1
			result["total"] = int(result["total"]) + target_total


func _damage_projectile_volley(
	caster: Node,
	targets: Array,
	raw_damage: int,
	result: Dictionary,
	projectile_count: int,
	hit_presentation: Dictionary = {},
	knockback: float = 80.0
) -> void:
	if targets.is_empty():
		return
	var damaged_target_ids := {}
	for projectile_index in projectile_count:
		var target_variant: Variant = targets[projectile_index % targets.size()]
		if not target_variant is Node:
			continue
		var target := target_variant as Node
		if not is_instance_valid(target):
			continue
		var dealt := 0
		if target.has_method("take_hit"):
			_prepare_target_hit_presentation(target, hit_presentation)
			var source := (caster as Node2D).global_position if caster is Node2D else Vector2.ZERO
			dealt = int(target.call("take_hit", raw_damage, source, knockback))
		elif target.has_method("take_damage"):
			dealt = int(target.call("take_damage", raw_damage))
		if dealt <= 0:
			continue
		damaged_target_ids[target.get_instance_id()] = true
		result["total"] = int(result["total"]) + dealt
	result["affected"] = int(result["affected"]) + damaged_target_ids.size()


func _prepare_target_hit_presentation(
	target: Node,
	hit_presentation: Dictionary
) -> void:
	if (
		hit_presentation.is_empty()
		or not target.has_method("prepare_hit_presentation")
	):
		return
	target.call(
		"prepare_hit_presentation",
		hit_presentation.duplicate(true)
	)


func _resolve_attack_elements(card: Dictionary, effect: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var candidates: Array = []
	candidates.append_array(effect.get("elements", []) as Array)
	candidates.append_array(card.get("tags", []) as Array)
	var visual_profile := card.get("combo_visual_profile", {}) as Dictionary
	candidates.append_array(visual_profile.get("elements", []) as Array)
	for candidate_variant in candidates:
		var element := String(_element_taxonomy.call(
			"normalize", String(candidate_variant)
		))
		if element.is_empty() or result.has(element):
			continue
		result.append(element)
	return result


func _resolve_hit_presentation(
	card: Dictionary,
	effect: Dictionary
) -> Dictionary:
	var tags := card.get("tags", []) as Array
	var visual_profile := card.get("combo_visual_profile", {}) as Dictionary
	var is_ultimate := (
		String(card.get("type", "")) == "ultimate"
		or bool(visual_profile.get("finisher", false))
		or String(card.get("id", "")) == "inferno_orb"
	)
	for tag_variant in tags:
		if String(tag_variant).strip_edges().to_lower() == "ultimate":
			is_ultimate = true
			break
	if (
		not is_ultimate
		or String(effect.get("kind", "")) not in [
			"damage", "area_damage", "area_slow", "damage_aura",
		]
	):
		return {}
	var element := "normal"
	for tag_variant in tags:
		var normalized := String(
			_element_taxonomy.call("normalize", String(tag_variant))
		)
		if normalized.is_empty() or normalized == "normal":
			continue
		element = normalized
		break
	if element == "normal":
		for element_variant in visual_profile.get("elements", []) as Array:
			var normalized := String(
				_element_taxonomy.call("normalize", String(element_variant))
			)
			if normalized.is_empty() or normalized == "normal":
				continue
			element = normalized
			break
	var skill_id := String(card.get("id", ""))
	return {
		"kind": "ultimate",
		"timeline": "hit_dissolve_burst",
		"element": element,
		"skill_id": skill_id,
		"impact_delay_seconds": _ultimate_impact_delay(skill_id),
		"skill_level": clampi(
			int(card.get("card_level", card.get("level", 1))),
			1,
			3
		),
		"stack_count": maxi(0, int(visual_profile.get("stack_count", 0))),
	}


func _ultimate_impact_delay(skill_id: String) -> float:
	match skill_id:
		"concussive_shout", "inferno_orb":
			return 0.56
		"frost_bind":
			return 0.96
		_:
			return 0.44


func _apply_status(
	targets: Array,
	status_id: String,
	effect: Dictionary,
	result: Dictionary,
	count_affected: bool = true
) -> void:
	for target in targets:
		if not target is Node or not is_instance_valid(target):
			continue
		if target.has_method("apply_status"):
			target.call("apply_status", status_id, effect)
		else:
			target.set_meta("card_status", status_id)
			target.set_meta("card_status_duration", float(effect.get("duration", 0.0)))
		if count_affected:
			result["affected"] = int(result["affected"]) + 1


func _apply_infused_statuses(targets: Array, effect: Dictionary) -> void:
	for target in targets:
		if not target is Node or not is_instance_valid(target) or not target.has_method("apply_status"):
			continue
		if float(effect.get("burn_duration", 0.0)) > 0.0:
			target.call("apply_status", "burn", {
				"duration": float(effect["burn_duration"]),
				"damage": int(effect.get("burn_damage", 1)),
			})
		if float(effect.get("frost_duration", 0.0)) > 0.0:
			var slow_duration := float(effect["frost_duration"])
			var slow_ratio := float(effect.get("frost_ratio", 0.25))
			if String(effect.get("kind", "")) == "area_slow":
				slow_duration = maxf(
					slow_duration,
					float(effect.get("duration", 0.0))
				)
				slow_ratio = maxf(
					slow_ratio,
					float(effect.get("ratio", 0.0))
				)
			target.call("apply_status", "slow", {
				"duration": slow_duration,
				"ratio": slow_ratio,
			})
		if float(effect.get("poison_duration", 0.0)) > 0.0:
			target.call("apply_status", "poison", {
				"duration": float(effect["poison_duration"]),
				"damage": int(effect.get("poison_damage", 1)),
			})
		if float(effect.get("combo_stun", 0.0)) > 0.0:
			target.call("apply_status", "stun", {"duration": float(effect["combo_stun"])})


func _apply_finisher_mutations(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	result: Dictionary,
	hit_presentation: Dictionary = {}
) -> void:
	var bonus_ratio := 0.0
	var mutation_ids: Array[String] = []
	if bool(effect.get("shatter", false)):
		bonus_ratio += 0.35
		mutation_ids.append("shatter")
	if bool(effect.get("final_burst", false)):
		bonus_ratio += 0.30
		mutation_ids.append("final_burst")
	if bool(effect.get("chain_lightning", false)):
		bonus_ratio += 0.25
		mutation_ids.append("chain_lightning")
	if bonus_ratio <= 0.0:
		return
	var mutation_damage := maxi(
		1,
		roundi(float(effect.get("amount", 0)) * bonus_ratio)
	)
	var total_before := int(result.get("total", 0))
	_damage_targets(
		caster,
		targets,
		mutation_damage,
		result,
		1,
		80.0,
		hit_presentation
	)
	result["mutation_damage"] = int(result.get("total", 0)) - total_before
	result["mutations_triggered"] = mutation_ids


func _pull_targets(caster: Node, targets: Array, strength: float) -> void:
	if not caster is Node2D or strength <= 0.0:
		return
	for target in targets:
		if not target is CharacterBody2D or not is_instance_valid(target):
			continue
		var direction := (
			(caster as Node2D).global_position
			- (target as CharacterBody2D).global_position
		).normalized()
		(target as CharacterBody2D).velocity = direction * strength


func _resolve_summon(caster: Node, effect: Dictionary, result: Dictionary) -> void:
	var unit_id := String(effect.get("unit_id", "summon"))
	if unit_id == "renewal_spirit" and caster.has_method("restore_health"):
		result["total"] = int(caster.call(
			"restore_health",
			int(effect.get("heal", 0)) * maxi(1, int(effect.get("pulses", 1)))
		))
	caster.set_meta("active_summon", unit_id)
	if caster is Node2D and caster.get_parent() != null:
		var visual := Polygon2D.new()
		visual.name = "Summon_%s" % unit_id
		visual.polygon = PackedVector2Array([
			Vector2(0, -14), Vector2(12, -4), Vector2(8, 10),
			Vector2(-8, 10), Vector2(-12, -4),
		])
		visual.color = Color(0.35, 0.90, 1.0, 0.82) if unit_id == "energy_wisp" else Color(0.55, 1.0, 0.48, 0.82)
		caster.get_parent().add_child(visual)
		visual.global_position = (caster as Node2D).global_position + Vector2(0, -115)
		var timer := visual.get_tree().create_timer(1.2)
		timer.timeout.connect(visual.queue_free, CONNECT_ONE_SHOT)
	result["affected"] = 1


func _nearest_targets(caster: Node, targets: Array, count: int) -> Array:
	var candidates := targets.filter(func(target: Variant) -> bool:
		return target is Node and is_instance_valid(target)
	)
	if caster is Node2D:
		candidates.sort_custom(func(a: Node, b: Node) -> bool:
			if not a is Node2D:
				return false
			if not b is Node2D:
				return true
			return (caster as Node2D).global_position.distance_squared_to((a as Node2D).global_position) < (caster as Node2D).global_position.distance_squared_to((b as Node2D).global_position)
		)
	return candidates.slice(0, mini(count, candidates.size()))


func _targets_in_radius(caster: Node, targets: Array, radius: float) -> Array:
	if not caster is Node2D:
		return targets
	var result: Array = []
	for target in targets:
		if target is Node2D and is_instance_valid(target):
			if ATTACK_GEOMETRY.radial_contains(
				(caster as Node2D).global_position,
				ATTACK_GEOMETRY.target_center(target as Node2D),
				ATTACK_GEOMETRY.target_radius(target as Node2D),
				radius
			):
				result.append(target)
	return result
