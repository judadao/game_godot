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
			if series_family != "orbiting_feather_contact_field":
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
		"bouncing_moon_wheel_field":
			_resolve_moon_wheel_bounce(effect, amount, result)
		"orbiting_feather_contact_field":
			_resolve_feather_stance(caster, targets, effect, amount, result, hit_presentation)
		"blooming_thorn_barrage":
			_resolve_thorn_bloom_field(caster, targets, effect, amount, result)
		"persistent_stone_drone_squad":
			_resolve_dr_stone_squad(caster, effect, amount, result)
		"singularity_pull_detonation":
			_resolve_black_hole_field(caster, targets, effect, amount, result)
		"staggered_fire_pillars":
			_resolve_fire_pillar_field(effect, amount, result)
		"residual_chain_sky_strike":
			_resolve_residual_lightning(effect, amount, result)
		"damaging_tidal_push":
			_resolve_tidal_push(effect, amount, result)
		"arcane_swamp_entanglement":
			_resolve_arcane_swamp_field(caster, targets, effect, amount, result)
		"dragon_breath_sweep":
			_resolve_dragon_breath_sweep(effect, amount, result)
		"player_healing_zone":
			_resolve_healing_zone(effect, amount, result)
		"body_overdrive_afterimage":
			_resolve_body_overdrive(effect, result)
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
	_targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary,
	_hit_presentation: Dictionary
) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	var feather_count := maxi(1, int(effect.get("feathers", [3, 7, 15][tier_rank - 1])))
	var damage_multiplier := maxf(0.01, float(effect.get("damage_per_tick_multiplier", 0.08)))
	result["feather_halo_attack"] = {
		"duration": maxf(0.5, float(effect.get("halo_duration", [4.8, 6.4, 8.8][tier_rank - 1]))),
		"radius": maxf(48.0, float(effect.get("halo_radius", [176.0, 204.0, 236.0][tier_rank - 1]))),
		"tick_interval": maxf(0.08, float(effect.get("tick_interval", 0.18))),
		"damage_per_tick": maxi(1, roundi(float(maxi(1, amount)) * damage_multiplier)),
		"knockback": (
			maxf(0.0, float(effect.get("knockback", [105.0, 125.0, 145.0][tier_rank - 1])))
			* maxf(0.0, float(effect.get("knockback_multiplier", 1.0)))
		),
		"feather_count": feather_count,
		"tier_rank": tier_rank,
		"center_offset": Vector2(0.0, -54.0),
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "orbiting_feather_contact_field"


func _resolve_moon_wheel_bounce(effect: Dictionary, amount: int, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["moon_wheel_bounce"] = {
		"wheel_count": maxi(5, int(effect.get("wheel_count", [5, 8, 12][tier_rank - 1]))),
		"round_trip_count": maxi(1, int(effect.get("round_trip_count", [1, 2, 3][tier_rank - 1]))),
		"duration": maxf(0.4, float(effect.get("bounce_duration", [1.4, 2.2, 3.1][tier_rank - 1]))),
		"range": maxf(120.0, float(effect.get("attack_range", [420.0, 470.0, 540.0][tier_rank - 1]))),
		"damage_per_contact": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("damage_per_contact_multiplier", [0.28, 0.24, 0.22][tier_rank - 1])))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "bouncing_moon_wheel_field"


func _resolve_thorn_bloom_field(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary
) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	var thorn_count := maxi(1, int(effect.get("thorn_count", [3, 6, 10][tier_rank - 1])))
	var damage_multiplier := maxf(0.01, float(effect.get("damage_per_spike_multiplier", [0.28, 0.40, 0.54][tier_rank - 1])))
	result["thorn_bloom_field"] = {
		"center": _resolve_field_center(caster, targets, 360.0),
		"duration": maxf(0.2, float(effect.get("field_duration", [2.4, 3.0, 3.8][tier_rank - 1]))),
		"radius": maxf(48.0, float(effect.get("field_radius", [180.0, 240.0, 310.0][tier_rank - 1]))),
		"emerge_duration": maxf(0.05, float(effect.get("emerge_duration", [0.45, 0.42, 0.38][tier_rank - 1]))),
		"bloom_delay": maxf(0.05, float(effect.get("bloom_delay", [0.70, 0.64, 0.58][tier_rank - 1]))),
		"volley_interval": maxf(0.08, float(effect.get("volley_interval", [0.42, 0.34, 0.26][tier_rank - 1]))),
		"thorn_count": thorn_count,
		"spikes_per_volley": maxi(1, int(effect.get("spikes_per_volley", thorn_count))),
		"damage_per_spike": maxi(1, roundi(float(maxi(1, amount)) * damage_multiplier)),
		"knockback": maxf(0.0, float(effect.get("knockback", 35.0))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "blooming_thorn_barrage"


func _resolve_black_hole_field(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary
) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	var tick_multiplier := maxf(0.01, float(effect.get("damage_per_tick_multiplier", [0.07, 0.09, 0.12][tier_rank - 1])))
	var burst_multiplier := maxf(1.0, float(effect.get("burst_damage_multiplier", [1.8, 2.5, 3.4][tier_rank - 1])))
	result["black_hole_field"] = {
		"center": _resolve_field_center(caster, targets, 360.0),
		"duration": maxf(0.2, float(effect.get("field_duration", [2.4, 3.0, 3.6][tier_rank - 1]))),
		"radius": maxf(48.0, float(effect.get("field_radius", [180.0, 240.0, 320.0][tier_rank - 1]))),
		"tick_interval": maxf(0.08, float(effect.get("tick_interval", [0.24, 0.22, 0.20][tier_rank - 1]))),
		"damage_per_tick": maxi(1, roundi(float(maxi(1, amount)) * tick_multiplier)),
		"burst_damage": maxi(1, roundi(float(maxi(1, amount)) * burst_multiplier)),
		"pull_strength": maxf(0.0, float(effect.get("pull_strength", [90.0, 125.0, 165.0][tier_rank - 1]))),
		"burst_knockback": maxf(0.0, float(effect.get("burst_knockback", 80.0))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "singularity_pull_detonation"


func _resolve_dr_stone_squad(
	_caster: Node,
	effect: Dictionary,
	amount: int,
	result: Dictionary
) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	var damage_multiplier := maxf(0.01, float(effect.get("damage_per_shot_multiplier", [0.30, 0.40, 0.52][tier_rank - 1])))
	result["dr_stone_squad"] = {
		"drone_count": maxi(3, int(effect.get("drone_count", [3, 6, 10][tier_rank - 1]))),
		"duration": maxf(0.5, float(effect.get("drone_duration", [5.0, 7.0, 9.0][tier_rank - 1]))),
		"attack_interval": maxf(0.08, float(effect.get("attack_interval", [0.65, 0.50, 0.38][tier_rank - 1]))),
		"attack_range": maxf(96.0, float(effect.get("attack_range", [300.0, 360.0, 430.0][tier_rank - 1]))),
		"damage_per_shot": maxi(1, roundi(float(maxi(1, amount)) * damage_multiplier)),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "persistent_stone_drone_squad"


func _resolve_arcane_swamp_field(
	caster: Node,
	targets: Array,
	effect: Dictionary,
	amount: int,
	result: Dictionary
) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	var damage_multiplier := maxf(0.01, float(effect.get("damage_per_tick_multiplier", [0.10, 0.14, 0.20][tier_rank - 1])))
	result["arcane_swamp_field"] = {
		"center": _resolve_field_center(caster, targets, 380.0),
		"duration": maxf(0.2, float(effect.get("field_duration", [3.0, 3.8, 4.8][tier_rank - 1]))),
		"radius": maxf(48.0, float(effect.get("field_radius", [260.0, 320.0, 390.0][tier_rank - 1]))),
		"tick_interval": maxf(0.08, float(effect.get("tick_interval", [0.32, 0.28, 0.24][tier_rank - 1]))),
		"damage_per_tick": maxi(1, roundi(float(maxi(1, amount)) * damage_multiplier)),
		"target_limit": maxi(10, int(effect.get("target_limit", [10, 14, 20][tier_rank - 1]))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "arcane_swamp_entanglement"


func _resolve_fire_pillar_field(effect: Dictionary, amount: int, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["fire_pillar_field"] = {
		"pillar_count": maxi(5, int(effect.get("pillar_count", [5, 10, 20][tier_rank - 1]))),
		"field_radius": maxf(120.0, float(effect.get("field_radius", [320.0, 390.0, 480.0][tier_rank - 1]))),
		"eruption_interval": maxf(0.08, float(effect.get("eruption_interval", [0.22, 0.18, 0.13][tier_rank - 1]))),
		"damage_per_pillar": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("damage_per_pillar_multiplier", [0.72, 0.86, 1.05][tier_rank - 1])))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "staggered_fire_pillars"


func _resolve_residual_lightning(effect: Dictionary, amount: int, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["residual_lightning"] = {
		"marked_target_limit": maxi(1, int(effect.get("marked_target_limit", [10, 20, 30][tier_rank - 1]))),
		"residual_duration": maxf(0.2, float(effect.get("residual_duration", [1.6, 2.0, 2.4][tier_rank - 1]))),
		"chain_interval": maxf(0.06, float(effect.get("chain_interval", [0.18, 0.14, 0.10][tier_rank - 1]))),
		"residual_damage": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("residual_damage_multiplier", [0.16, 0.23, 0.32][tier_rank - 1])))),
		"final_strike_damage": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("final_strike_multiplier", [1.6, 2.2, 3.0][tier_rank - 1])))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "residual_chain_sky_strike"


func _resolve_tidal_push(effect: Dictionary, amount: int, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["tidal_push_field"] = {
		"duration": maxf(0.2, float(effect.get("push_duration", [1.2, 1.8, 2.4][tier_rank - 1]))),
		"radius": maxf(96.0, float(effect.get("field_radius", [250.0, 300.0, 340.0][tier_rank - 1]))),
		"tick_interval": maxf(0.08, float(effect.get("tick_interval", 0.20))),
		"push_distance": clampf(float(effect.get("push_distance", [55.0, 88.0, 120.0][tier_rank - 1])), 0.0, 140.0),
		"damage_per_tick": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("damage_per_tick_multiplier", [0.16, 0.22, 0.30][tier_rank - 1])))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "damaging_tidal_push"


func _resolve_dragon_breath_sweep(effect: Dictionary, amount: int, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["dragon_breath_sweep"] = {
		"side_sweep_count": clampi(int(effect.get("side_sweep_count", [1, 2, 2][tier_rank - 1])), 1, 2),
		"side_sweep_duration": maxf(0.2, float(effect.get("side_sweep_duration", [0.85, 0.95, 1.05][tier_rank - 1]))),
		"rain_emitter_count": maxi(0, int(effect.get("rain_emitter_count", [0, 0, 20][tier_rank - 1]))),
		"rain_duration": maxf(0.0, float(effect.get("rain_duration", 1.5 if tier_rank == 3 else 0.0))),
		"range": maxf(96.0, float(effect.get("attack_range", [390.0, 450.0, 540.0][tier_rank - 1]))),
		"damage_per_sweep": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("sweep_damage_multiplier", [1.0, 0.88, 1.05][tier_rank - 1])))),
		"damage_per_rain_hit": maxi(1, roundi(float(maxi(1, amount)) * float(effect.get("rain_damage_multiplier", 0.28)))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "dragon_breath_sweep"


func _resolve_healing_zone(effect: Dictionary, amount: int, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["healing_zone"] = {
		"duration": maxf(0.5, float(effect.get("field_duration", [4.0, 6.0, 8.0][tier_rank - 1]))),
		"radius": maxf(48.0, float(effect.get("field_radius", [150.0, 210.0, 280.0][tier_rank - 1]))),
		"pulse_interval": maxf(0.1, float(effect.get("pulse_interval", [0.80, 0.72, 0.64][tier_rank - 1]))),
		"heal_per_pulse": maxi(1, int(effect.get("heal_per_pulse", maxi(1, roundi(float(maxi(1, amount)) * [0.42, 0.55, 0.72][tier_rank - 1]))))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "player_healing_zone"


func _resolve_body_overdrive(effect: Dictionary, result: Dictionary) -> void:
	var tier_rank := clampi(int(effect.get("tier_rank", 1)), 1, 3)
	result["body_overdrive"] = {
		"duration": maxf(0.2, float(effect.get("buff_duration", [3.5, 5.0, 7.0][tier_rank - 1]))),
		"move_speed_multiplier": maxf(1.0, float(effect.get("body_move_speed_multiplier", [1.35, 1.55, 1.80][tier_rank - 1]))),
		"attack_speed_multiplier": maxf(1.0, float(effect.get("body_attack_speed_multiplier", [1.25, 1.45, 1.75][tier_rank - 1]))),
		"afterimage_count": maxi(1, int(effect.get("afterimage_count", [3, 5, 8][tier_rank - 1]))),
		"tier_rank": tier_rank,
	}
	result["affected"] = int(result.get("affected", 0)) + 1
	result["series_rule"] = "body_overdrive_afterimage"


func _resolve_field_center(caster: Node, targets: Array, placement_range: float) -> Vector2:
	if not caster is Node2D:
		return Vector2.ZERO
	var caster_2d := caster as Node2D
	var center := caster_2d.global_position
	var nearest_distance := INF
	for target_variant in targets:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		var candidate := target_variant as Node2D
		var candidate_center := ATTACK_GEOMETRY.target_center(candidate)
		var distance := caster_2d.global_position.distance_squared_to(candidate_center)
		if distance < nearest_distance:
			nearest_distance = distance
			center = candidate_center
	var displacement := center - caster_2d.global_position
	if displacement.length() > placement_range:
		center = caster_2d.global_position + displacement.normalized() * placement_range
	return center


func _distance_between(first: Node, second: Node) -> float:
	if first is Node2D and second is Node2D:
		return (first as Node2D).global_position.distance_to((second as Node2D).global_position)
	return INF


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
