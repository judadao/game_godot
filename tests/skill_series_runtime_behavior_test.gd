extends SceneTree

const RUNNER_SCRIPT := preload("res://scripts/combat/card_effect_runner.gd")

var _failures := 0


class TestCaster:
	extends Node2D

	var velocity := Vector2.ZERO
	var facing_direction := 1
	var health := 40
	var max_health := 100
	var block := 0


	func add_block(amount: int) -> int:
		block += maxi(0, amount)
		return amount


	func restore_health(amount: int) -> int:
		var before := health
		health = mini(max_health, health + maxi(0, amount))
		return health - before


class TestTarget:
	extends CharacterBody2D

	var health := 500
	var damage_taken := 0
	var hit_count := 0
	var last_knockback := 0.0
	var statuses: Dictionary = {}


	func take_hit(raw_damage: int, _source_position: Vector2, knockback: float = 0.0) -> int:
		var dealt := mini(health, maxi(0, raw_damage))
		health -= dealt
		damage_taken += dealt
		hit_count += 1
		last_knockback = knockback
		return dealt


	func apply_status(status_id: String, effect: Dictionary) -> void:
		statuses[status_id] = effect.duplicate(true)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_marked_execution()
	_test_returning_orbit()
	_test_orbiting_feather_contact_field()
	_test_thorn_field()
	_test_singularity_pull_detonation()
	_test_fire_and_lightning_rules()
	_test_tide_and_swamp_rules()
	_test_crossfire_and_vitality_rules()
	if _failures == 0:
		print("PASS: all skill series execute distinct runtime combat rules")
	quit(1 if _failures > 0 else 0)


func _test_marked_execution() -> void:
	var fixture := _fixture([Vector2(70, 0)])
	var caster := fixture.caster as TestCaster
	var target := fixture.targets[0] as TestTarget
	_cast(fixture.runner, caster, fixture.targets, "marked_execution", {
		"tier_rank": 2, "projectile_count": 5,
	})
	_expect(target.has_meta("sword_rain_marks"), "Sword Rain must place executable sword marks at close range.")
	var damage_before := target.damage_taken
	caster.position = Vector2(-260, 0)
	var result := _cast(fixture.runner, caster, fixture.targets, "marked_execution", {
		"tier_rank": 2, "projectile_count": 5,
	})
	_expect(target.damage_taken - damage_before > 20, "Sword Rain must execute stored marks after the player creates distance.")
	_expect(String(result.get("series_rule", "")) == "mark_execution", "Sword Rain result must report the executed rule.")
	_free_fixture(fixture)


func _test_returning_orbit() -> void:
	var fixture := _fixture([Vector2(100, 0)])
	var target := fixture.targets[0] as TestTarget
	var result := _cast(fixture.runner, fixture.caster, fixture.targets, "bouncing_moon_wheel_field", {"tier_rank": 1, "wheel_count": 5, "round_trip_count": 1})
	var bounce := result.get("moon_wheel_bounce", {}) as Dictionary
	_expect(target.hit_count == 0 and int(bounce.get("wheel_count", 0)) == 5 and int(bounce.get("round_trip_count", 0)) == 1, "Moon Wheel must defer five wheels and one round trip to its timed bounce controller.")
	_free_fixture(fixture)


func _test_orbiting_feather_contact_field() -> void:
	var fixture := _fixture([Vector2(90, 0), Vector2(130, 0)])
	var caster := fixture.caster as TestCaster
	caster.velocity = Vector2(120, 0)
	var result := _cast(fixture.runner, caster, fixture.targets, "orbiting_feather_contact_field", {
		"tier_rank": 2, "feathers": 7, "halo_duration": 6.4,
		"halo_radius": 204.0, "tick_interval": 0.18,
		"damage_per_tick_multiplier": 0.10, "knockback": 125.0,
	})
	var halo := result.get("feather_halo_attack", {}) as Dictionary
	_expect(
		String(result.get("series_rule", "")) == "orbiting_feather_contact_field"
			and int(halo.get("feather_count", 0)) == 7
			and float(halo.get("duration", 0.0)) >= 6.4,
		"Feather must create one long-lived orbit contact field regardless of player movement."
	)
	_expect(
		(fixture.targets[0] as TestTarget).damage_taken == 0
			and (fixture.targets[1] as TestTarget).damage_taken == 0,
		"Feather cast resolution must not fake a homing projectile volley."
	)
	_free_fixture(fixture)


func _test_thorn_field() -> void:
	var thorns := _fixture([Vector2(60, 0), Vector2(120, 0), Vector2(180, 0)])
	var thorn_result := _cast(thorns.runner, thorns.caster, thorns.targets, "blooming_thorn_barrage", {
		"tier_rank": 2, "thorn_count": 6, "field_radius": 240.0,
		"field_duration": 3.0, "spikes_per_volley": 6,
		"damage_per_spike_multiplier": 0.42,
	})
	var thorn_field := thorn_result.get("thorn_bloom_field", {}) as Dictionary
	_expect(int(thorn_field.get("thorn_count", 0)) == 6 and int(thorn_field.get("spikes_per_volley", 0)) == 6, "Thorn cast must create the advanced blooming barrage field.")
	_expect((thorns.targets[0] as TestTarget).damage_taken == 0, "Thorn cast must wait for its emerge and bloom phases before dealing damage.")
	_free_fixture(thorns)


func _test_singularity_pull_detonation() -> void:
	var fixture := _fixture([Vector2(90, 0), Vector2(-90, 0)])
	var result := _cast(fixture.runner, fixture.caster, fixture.targets, "singularity_pull_detonation", {
		"tier_rank": 2, "field_radius": 240.0, "field_duration": 3.0,
		"tick_interval": 0.22, "damage_per_tick_multiplier": 0.09,
		"burst_damage_multiplier": 2.5, "pull_strength": 125.0,
	})
	var field := result.get("black_hole_field", {}) as Dictionary
	_expect(String(result.get("series_rule", "")) == "singularity_pull_detonation", "Black Hole must route to its persistent field controller.")
	_expect(float(field.get("radius", 0.0)) == 240.0 and float(field.get("duration", 0.0)) == 3.0, "Black Hole advanced tier must project its authored range and duration.")
	_expect((fixture.targets[0] as TestTarget).damage_taken == 0 and (fixture.targets[1] as TestTarget).damage_taken == 0, "Black Hole cast resolution must not fake its delayed field damage immediately.")
	_free_fixture(fixture)


func _test_fire_and_lightning_rules() -> void:
	var fire := _fixture([Vector2(70, 0), Vector2(120, 0)])
	var fire_result := _cast(fire.runner, fire.caster, fire.targets, "staggered_fire_pillars", {
		"tier_rank": 3, "pillar_count": 20, "eruption_interval": 0.13,
	})
	var fire_field := fire_result.get("fire_pillar_field", {}) as Dictionary
	_expect(int(fire_field.get("pillar_count", 0)) == 20 and (fire.targets[0] as TestTarget).damage_taken == 0, "Fire must defer its twenty staggered eruptions to the field controller.")
	_free_fixture(fire)
	var lightning := _fixture([Vector2(60, 0), Vector2(110, 0), Vector2(160, 0)])
	var lightning_result := _cast(lightning.runner, lightning.caster, lightning.targets, "residual_chain_sky_strike", {"tier_rank": 3, "marked_target_limit": 30})
	var residual := lightning_result.get("residual_lightning", {}) as Dictionary
	_expect(int(residual.get("marked_target_limit", 0)) == 30 and int(residual.get("final_strike_damage", 0)) > int(residual.get("residual_damage", 0)), "Lightning must author thirty residual marks and a stronger delayed sky strike.")
	_free_fixture(lightning)


func _test_tide_and_swamp_rules() -> void:
	var tide := _fixture([Vector2(120, 0)])
	var tide_target := tide.targets[0] as TestTarget
	var tide_result := _cast(tide.runner, tide.caster, tide.targets, "damaging_tidal_push", {
		"tier_rank": 3, "push_distance": 120.0, "push_duration": 2.4,
	})
	var tidal_field := tide_result.get("tidal_push_field", {}) as Dictionary
	_expect(tide_target.hit_count == 0 and float(tidal_field.get("push_distance", 0.0)) == 120.0, "Water Flow must defer its damaging capped push to the field controller.")
	_free_fixture(tide)
	var swamp := _fixture([Vector2(60, 0), Vector2(100, 0), Vector2(140, 0)])
	var swamp_result := _cast(swamp.runner, swamp.caster, swamp.targets, "arcane_swamp_entanglement", {
		"tier_rank": 1, "target_limit": 10, "field_radius": 260.0,
		"field_duration": 3.0, "tick_interval": 0.32, "damage_per_tick_multiplier": 0.10,
	})
	var swamp_field := swamp_result.get("arcane_swamp_field", {}) as Dictionary
	_expect(int(swamp_field.get("target_limit", 0)) == 10 and float(swamp_field.get("duration", 0.0)) == 3.0, "Arcane Swamp must create its ten-target entanglement field.")
	_expect((swamp.targets[0] as TestTarget).damage_taken == 0, "Arcane Swamp must defer damage to its persistent field controller.")
	_free_fixture(swamp)


func _test_crossfire_and_vitality_rules() -> void:
	var dragon := _fixture([Vector2(100, 0), Vector2(160, 0)])
	var dragon_result := _cast(dragon.runner, dragon.caster, dragon.targets, "dragon_breath_sweep", {"tier_rank": 3, "side_sweep_count": 2, "rain_emitter_count": 20})
	var breath := dragon_result.get("dragon_breath_sweep", {}) as Dictionary
	_expect(int(breath.get("side_sweep_count", 0)) == 2 and int(breath.get("rain_emitter_count", 0)) == 20, "Master Dragon Breath must resolve two side sweeps followed by twenty downward emitters.")
	_free_fixture(dragon)
	var dawn := _fixture([Vector2(90, 0)])
	var dawn_result := _cast(dawn.runner, dawn.caster, dawn.targets, "player_healing_zone", {"tier_rank": 3, "field_radius": 280.0, "field_duration": 8.0, "heal_per_pulse": 12})
	var healing_zone := dawn_result.get("healing_zone", {}) as Dictionary
	_expect(float(healing_zone.get("radius", 0.0)) == 280.0 and float(healing_zone.get("duration", 0.0)) == 8.0, "Master Dawn must create the largest and longest player-following healing zone.")
	_free_fixture(dawn)
	var shared := _fixture([Vector2(110, 0)])
	var shared_result := _cast(shared.runner, shared.caster, shared.targets, "body_overdrive_afterimage", {"tier_rank": 3, "buff_duration": 7.0, "body_move_speed_multiplier": 1.8, "body_attack_speed_multiplier": 1.75, "afterimage_count": 8})
	var overdrive := shared_result.get("body_overdrive", {}) as Dictionary
	_expect(float(overdrive.get("move_speed_multiplier", 0.0)) == 1.8 and float(overdrive.get("attack_speed_multiplier", 0.0)) == 1.75 and int(overdrive.get("afterimage_count", 0)) == 8, "Master Shared Branch must author its strongest body speed and afterimage state.")
	_free_fixture(shared)


func _fixture(positions: Array[Vector2]) -> Dictionary:
	var caster := TestCaster.new()
	root.add_child(caster)
	var runner := RUNNER_SCRIPT.new()
	root.add_child(runner)
	var targets: Array = []
	for position in positions:
		var target := TestTarget.new()
		target.position = position
		root.add_child(target)
		targets.append(target)
	return {"caster": caster, "runner": runner, "targets": targets}


func _cast(runner: Node, caster: Node, targets: Array, family: String, extra: Dictionary) -> Dictionary:
	var effect := {
		"kind": "damage",
		"amount": 10,
		"projectile_count": 1,
		"target_count": maxi(1, targets.size()),
		"series_gameplay_family": family,
	}
	effect.merge(extra, true)
	return runner.call("cast", {"id": family, "effect": effect}, caster, targets) as Dictionary


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.runner as Node).queue_free()
	(fixture.caster as Node).queue_free()
	for target in fixture.targets as Array:
		(target as Node).queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
