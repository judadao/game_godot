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
	_test_moving_guard_and_still_barrage()
	_test_gate_network_and_ricochet()
	_test_forward_guard_counter()
	_test_fire_and_lightning_rules()
	_test_tide_and_plant_rules()
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
	_cast(fixture.runner, fixture.caster, fixture.targets, "returning_orbit", {"tier_rank": 1})
	_expect(target.hit_count == 2, "Moon Wheel must damage on both outbound and returning passes.")
	_free_fixture(fixture)


func _test_moving_guard_and_still_barrage() -> void:
	var fixture := _fixture([Vector2(90, 0), Vector2(130, 0)])
	var caster := fixture.caster as TestCaster
	caster.velocity = Vector2(120, 0)
	_cast(fixture.runner, caster, fixture.targets, "moving_guard_still_barrage", {
		"tier_rank": 2, "guard": 7, "projectile_count": 6,
	})
	_expect(caster.block >= 7 and (fixture.targets[0] as TestTarget).damage_taken == 0, "Feather must defend instead of firing while the player moves.")
	caster.velocity = Vector2.ZERO
	_cast(fixture.runner, caster, fixture.targets, "moving_guard_still_barrage", {
		"tier_rank": 2, "guard": 7, "projectile_count": 6,
	})
	_expect((fixture.targets[0] as TestTarget).damage_taken > 0 and (fixture.targets[1] as TestTarget).damage_taken > 0, "Feather must release its barrage when the player stops.")
	_free_fixture(fixture)


func _test_gate_network_and_ricochet() -> void:
	var gates := _fixture([Vector2(60, 0), Vector2(120, 0), Vector2(180, 0)])
	_cast(gates.runner, gates.caster, gates.targets, "sword_aura_gate_network", {
		"tier_rank": 2, "relay_count": 3,
	})
	_expect((gates.targets[2] as TestTarget).damage_taken > (gates.targets[0] as TestTarget).damage_taken, "Ancient Wood relays must amplify later gate hits.")
	_free_fixture(gates)
	var stones := _fixture([Vector2(70, 0), Vector2(130, 0), Vector2(190, 0)])
	_cast(stones.runner, stones.caster, stones.targets, "ricochet_boulders", {
		"tier_rank": 2, "projectile_count": 3, "knockback_multiplier": 1.7,
	})
	_expect((stones.targets[0] as TestTarget).damage_taken > 0 and (stones.targets[2] as TestTarget).damage_taken > 0, "Giant Stone must ricochet through multiple enemies.")
	_expect((stones.targets[1] as TestTarget).last_knockback > 80.0, "Giant Stone ricochets must use their stronger impact.")
	_free_fixture(stones)


func _test_forward_guard_counter() -> void:
	var fixture := _fixture([Vector2(90, 0), Vector2(-90, 0)])
	var caster := fixture.caster as TestCaster
	_cast(fixture.runner, caster, fixture.targets, "forward_guard_counter", {
		"tier_rank": 2, "guard": 15,
	})
	_expect(caster.block >= 15, "Great Shield must grant actual guard.")
	_expect((fixture.targets[0] as TestTarget).damage_taken > 0 and (fixture.targets[1] as TestTarget).damage_taken == 0, "Great Shield counter must only strike in the player's facing direction.")
	_free_fixture(fixture)


func _test_fire_and_lightning_rules() -> void:
	var fire := _fixture([Vector2(70, 0), Vector2(120, 0)])
	var fire_result := _cast(fire.runner, fire.caster, fire.targets, "route_burn_detonation", {
		"tier_rank": 3, "burn_damage": 8, "burn_duration": 5.0, "final_burst": true,
	})
	_expect((fire.targets[0] as TestTarget).statuses.has("burn") and int(fire_result.get("detonated_targets", 0)) == 2, "Fire must leave burn on its route and detonate the enclosed group.")
	_free_fixture(fire)
	var lightning := _fixture([Vector2(60, 0), Vector2(110, 0), Vector2(160, 0)])
	_cast(lightning.runner, lightning.caster, [lightning.targets[0]], "target_switch_chain", {"tier_rank": 2})
	var untouched_before := (lightning.targets[2] as TestTarget).damage_taken
	var lightning_result := _cast(lightning.runner, lightning.caster, [lightning.targets[1], lightning.targets[2]], "target_switch_chain", {"tier_rank": 2, "chain_lightning": true})
	_expect((lightning.targets[2] as TestTarget).damage_taken > untouched_before and int(lightning_result.get("chain_targets", 0)) >= 1, "Lightning must chain when the player switches targets.")
	_free_fixture(lightning)


func _test_tide_and_plant_rules() -> void:
	var tide := _fixture([Vector2(120, 0)])
	var tide_target := tide.targets[0] as TestTarget
	_cast(tide.runner, tide.caster, tide.targets, "outbound_returning_tide", {
		"tier_rank": 2, "pull_strength": 60.0,
	})
	_expect(tide_target.hit_count == 2 and tide_target.velocity.x < 0.0, "Water Flow must hit outward, return, and pull enemies back toward the attack line.")
	_free_fixture(tide)
	var plants := _fixture([Vector2(60, 0), Vector2(100, 0), Vector2(140, 0)])
	var host := plants.targets[0] as TestTarget
	host.health = 12
	var plant_result := _cast(plants.runner, plants.caster, plants.targets, "host_growth_harvest", {
		"tier_rank": 3, "poison_damage": 8, "poison_duration": 6.0, "death_spread": true,
	})
	_expect(host.has_meta("plant_series_host") and int(plant_result.get("harvest_spread_targets", 0)) == 2, "Plant must designate a host and spread its harvest when that host dies.")
	_free_fixture(plants)


func _test_crossfire_and_vitality_rules() -> void:
	var dragon := _fixture([Vector2(100, 0), Vector2(160, 0)])
	_cast(dragon.runner, dragon.caster, dragon.targets, "crossfire_lane", {"tier_rank": 2})
	var first_damage := (dragon.targets[0] as TestTarget).damage_taken
	(dragon.caster as TestCaster).position = Vector2(220, 0)
	_cast(dragon.runner, dragon.caster, dragon.targets, "crossfire_lane", {"tier_rank": 2})
	_expect((dragon.targets[0] as TestTarget).damage_taken - first_damage > 10, "Dragon Breath must add a second attack origin after the player changes position.")
	_free_fixture(dragon)
	var dawn := _fixture([Vector2(90, 0)])
	var dawn_caster := dawn.caster as TestCaster
	_cast(dawn.runner, dawn_caster, dawn.targets, "risk_heal_judgment", {"tier_rank": 2, "heal": 18})
	var healed_near := dawn_caster.health
	var damage_near := (dawn.targets[0] as TestTarget).damage_taken
	dawn_caster.position = Vector2(300, 0)
	_cast(dawn.runner, dawn_caster, dawn.targets, "risk_heal_judgment", {"tier_rank": 2, "heal": 18})
	_expect(healed_near > 40 and (dawn.targets[0] as TestTarget).damage_taken - damage_near > damage_near, "Dawn must heal near its light and deal stronger judgment damage at range.")
	_free_fixture(dawn)
	var shared := _fixture([Vector2(110, 0)])
	_cast(shared.runner, shared.caster, shared.targets, "dual_origin_crossfire", {"tier_rank": 2, "echoes": 2})
	var first_shared := (shared.targets[0] as TestTarget).damage_taken
	var caster_position := (shared.caster as TestCaster).position
	(shared.caster as TestCaster).position = Vector2(180, 0)
	_cast(shared.runner, shared.caster, shared.targets, "dual_origin_crossfire", {"tier_rank": 2, "echoes": 2})
	_expect((shared.targets[0] as TestTarget).damage_taken - first_shared >= 20 and (shared.caster as TestCaster).position == Vector2(180, 0), "Shared Branch must attack from its saved echo without moving the player.")
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
