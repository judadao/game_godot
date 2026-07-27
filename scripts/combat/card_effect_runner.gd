class_name CardEffectRunner
extends Node

signal effect_resolved(card_id: String, result: Dictionary)

const SUPPORTED_EFFECTS := [
	"damage", "area_damage", "block", "heal", "dash_impact",
	"slow", "area_slow", "stun", "attack_power", "damage_aura",
	"gain_energy", "summon", "projectile_burst", "overdrive",
	"infusion", "combat_status", "healing_pulses", "regeneration",
]


func supports_effect(kind: String) -> bool:
	return SUPPORTED_EFFECTS.has(kind)


func cast(card: Dictionary, caster: Node, targets: Array) -> Dictionary:
	if card.is_empty() or caster == null:
		return {}
	var effect := (card.get("effect", {}) as Dictionary).duplicate(true)
	var kind := String(effect.get("kind", ""))
	var result := {
		"card_id": String(card.get("id", "")),
		"instance_id": String(card.get("instance_id", "")),
		"card_level": int(card.get("card_level", card.get("level", 1))),
		"kind": kind,
		"affected": 0,
		"total": 0,
		"play_destination": String(card.get("play_destination", "discard")),
		"cooldown_seconds": float(card.get("cooldown_seconds", 0.0)),
	}
	if (
		kind in ["damage", "area_damage", "dash_impact", "damage_aura"]
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
			var selected := _nearest_targets(caster, targets, 1)
			_damage_targets(caster, selected, int(effect.get("amount", 0)), result, maxi(1, int(effect.get("projectiles", 1))))
			_apply_infused_statuses(selected, effect)
		"area_damage":
			var selected := _targets_in_radius(caster, targets, float(effect.get("radius", 150.0)))
			_damage_targets(caster, selected, int(effect.get("amount", 0)), result)
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
			_damage_targets(caster, selected, int(effect.get("amount", 0)), result)
			_apply_infused_statuses(selected, effect)
			_pull_targets(caster, selected, float(effect.get("pull_strength", 0.0)))
		"slow":
			_apply_status(_nearest_targets(caster, targets, 1), kind, effect, result)
		"area_slow", "stun":
			_apply_status(_targets_in_radius(caster, targets, float(effect.get("radius", 170.0))), kind, effect, result)
		"attack_power":
			var current: Variant = caster.get("attack_power")
			if current != null:
				var health_cost := maxi(0, int(effect.get("health_cost", 0)))
				if health_cost > 0 and caster.has_method("take_damage"):
					caster.call("take_damage", health_cost)
				caster.set("attack_power", int(current) + int(effect.get("amount", 0)))
				result["affected"] = 1
		"damage_aura":
			_damage_targets(caster, _targets_in_radius(caster, targets, float(effect.get("radius", 110.0))), int(effect.get("amount", 0)), result)
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
		if float(effect.get("lifesteal_ratio", 0.0)) > 0.0 and caster.has_method("restore_health"):
			lifesteal_restored += int(caster.call(
				"restore_health",
				maxi(1, int(round(float(result["total"]) * float(effect["lifesteal_ratio"]))))
			))
		result["lifesteal_restored"] = lifesteal_restored

	effect_resolved.emit(String(card.get("id", "")), result)
	return result


func _damage_targets(caster: Node, targets: Array, raw_damage: int, result: Dictionary, hits: int = 1) -> void:
	for target in targets:
		if not target is Node or not is_instance_valid(target):
			continue
		var target_total := 0
		for _hit in hits:
			if not is_instance_valid(target):
				break
			if target.has_method("take_hit"):
				var source := (caster as Node2D).global_position if caster is Node2D else Vector2.ZERO
				target_total += int(target.call("take_hit", raw_damage, source, 80.0))
			elif target.has_method("take_damage"):
				target_total += int(target.call("take_damage", raw_damage))
		if target_total > 0:
			result["affected"] = int(result["affected"]) + 1
			result["total"] = int(result["total"]) + target_total


func _apply_status(targets: Array, status_id: String, effect: Dictionary, result: Dictionary) -> void:
	for target in targets:
		if not target is Node or not is_instance_valid(target):
			continue
		if target.has_method("apply_status"):
			target.call("apply_status", status_id, effect)
		else:
			target.set_meta("card_status", status_id)
			target.set_meta("card_status_duration", float(effect.get("duration", 0.0)))
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
			target.call("apply_status", "slow", {
				"duration": float(effect["frost_duration"]),
				"ratio": float(effect.get("frost_ratio", 0.25)),
			})
		if float(effect.get("poison_duration", 0.0)) > 0.0:
			target.call("apply_status", "poison", {
				"duration": float(effect["poison_duration"]),
				"damage": int(effect.get("poison_damage", 1)),
			})
		if float(effect.get("combo_stun", 0.0)) > 0.0:
			target.call("apply_status", "stun", {"duration": float(effect["combo_stun"])})


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
			if (caster as Node2D).global_position.distance_to((target as Node2D).global_position) <= radius:
				result.append(target)
	return result
