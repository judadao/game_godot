extends SceneTree

const CARD_EFFECT_RUNNER_SCRIPT := preload("res://scripts/combat/card_effect_runner.gd")
const ALL_ELEMENTS := [
	"water", "fire", "wind", "lightning", "ice",
	"poison", "light", "dark", "normal",
]

var _failures := 0


class TestCaster:
	extends Node2D

	var restored_health := 0


	func restore_health(amount: int) -> int:
		var restored := maxi(0, amount)
		restored_health += restored
		return restored


class TestTarget:
	extends Node2D

	var damage_taken := 0
	var last_knockback := 0.0
	var statuses: Dictionary = {}


	func take_hit(raw_damage: int, _source_position: Vector2, knockback: float = 0.0) -> int:
		damage_taken += raw_damage
		last_knockback = knockback
		return raw_damage


	func apply_status(status_id: String, effect: Dictionary) -> void:
		statuses[status_id] = effect.duplicate(true)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(7)
	var caster := TestCaster.new()
	root.add_child(caster)
	var first_target := TestTarget.new()
	first_target.position = Vector2(40.0, 0.0)
	root.add_child(first_target)
	var second_target := TestTarget.new()
	second_target.position = Vector2(80.0, 0.0)
	root.add_child(second_target)
	var runner = CARD_EFFECT_RUNNER_SCRIPT.new()
	root.add_child(runner)
	var result := runner.cast({
		"id": "all_element_contract",
		"type": "attack",
		"effect": {
			"kind": "damage",
			"amount": 10,
			"target_count": 1,
			"elements": ALL_ELEMENTS,
		},
	}, caster, [first_target, second_target]) as Dictionary
	_expect(
		first_target.damage_taken > 0 and second_target.damage_taken > 0,
		"Water side effect must turn one-target damage into a readable two-target splash."
	)
	_expect(
		first_target.last_knockback >= 100.0 and second_target.last_knockback >= 100.0,
		"Wind side effect must strengthen runtime knockback."
	)
	for target in [first_target, second_target]:
		_expect(
			target.statuses.has("burn")
				and target.statuses.has("stun")
				and target.statuses.has("slow")
				and target.statuses.has("poison"),
			"Fire, lightning, ice, and poison must apply independent statuses on hit."
		)
	_expect(
		result.has("lifesteal_restored") and result.has("element_heal_restored"),
		"Light and dark must expose independent restoration results."
	)
	_expect(
		(result.get("elements", []) as Array).size() == ALL_ELEMENTS.size()
			and (result.get("element_side_effects", []) as Array).size() == ALL_ELEMENTS.size(),
		"Combat result must expose all active elements and their standalone side effects."
	)
	var lone_target := TestTarget.new()
	lone_target.position = Vector2(40.0, 0.0)
	root.add_child(lone_target)
	var lone_result := runner.cast({
		"id": "water_single_target_contract",
		"type": "attack",
		"effect": {
			"kind": "damage",
			"amount": 10,
			"target_count": 1,
			"elements": ["water"],
		},
	}, caster, [lone_target]) as Dictionary
	_expect(
		lone_target.damage_taken == 10
			and int(lone_result.get("affected", 0)) == 1,
		"Water splash must add another target without duplicating damage on a lone enemy."
	)
	var sweep_first := TestTarget.new()
	var sweep_second := TestTarget.new()
	sweep_first.position = Vector2(35.0, 0.0)
	sweep_second.position = Vector2(65.0, 0.0)
	root.add_child(sweep_first)
	root.add_child(sweep_second)
	var sweep_result := runner.cast({
		"id": "water_directional_sweep_contract",
		"type": "attack",
		"effect": {
			"kind": "damage",
			"amount": 10,
			"target_count": 1,
			"damage_mode": "directional_sweep_once",
			"elements": ["water"],
		},
	}, caster, [sweep_first, sweep_second]) as Dictionary
	_expect(
		sweep_first.damage_taken == 10
		and sweep_second.damage_taken == 10
			and int(sweep_result.get("affected", 0)) == 2,
		"Water must preserve the directional sword wave's full corridor pierce."
	)
	var aura_target := TestTarget.new()
	aura_target.position = Vector2(50.0, 0.0)
	root.add_child(aura_target)
	runner.cast({
		"id": "elemental_aura_contract",
		"type": "power",
		"effect": {
			"kind": "damage_aura",
			"amount": 5,
			"radius": 100.0,
			"elements": ["fire", "lightning"],
		},
	}, caster, [aura_target])
	_expect(
		aura_target.statuses.has("burn") and aura_target.statuses.has("stun"),
		"Damage auras must apply their fire and lightning standalone effects."
	)
	var domain_target := TestTarget.new()
	domain_target.position = Vector2(50.0, 0.0)
	root.add_child(domain_target)
	runner.cast({
		"id": "elemental_domain_contract",
		"type": "skill",
		"effect": {
			"kind": "area_slow",
			"amount": 5,
			"radius": 100.0,
			"ratio": 0.45,
			"duration": 4.0,
			"elements": ["ice", "poison"],
		},
	}, caster, [domain_target])
	_expect(
		domain_target.statuses.has("poison")
			and float((domain_target.statuses.get("slow", {}) as Dictionary).get(
				"ratio", 0.0
			)) >= 0.45,
		"Elemental area-control must add statuses without weakening its native slow."
	)
	var ratio_caster := TestCaster.new()
	root.add_child(ratio_caster)
	var ratio_target := TestTarget.new()
	ratio_target.position = Vector2(30.0, 0.0)
	root.add_child(ratio_target)
	for hit_index in 5:
		runner.cast({
			"id": "fractional_restore_%d" % hit_index,
			"type": "attack",
			"effect": {
				"kind": "damage",
				"amount": 10,
				"elements": ["light", "dark"],
			},
		}, ratio_caster, [ratio_target])
	_expect(
		ratio_caster.restored_health == 3,
		"Light 3% and dark 4% must accumulate fractional healing without rounding every low hit up to one."
	)
	var restored_before_heal := caster.restored_health
	var healing_result := runner.cast({
		"id": "light_healing_contract",
		"type": "healing",
		"tags": ["light"],
		"effect": {"kind": "heal", "amount": 10},
	}, caster, []) as Dictionary
	_expect(
		caster.restored_health - restored_before_heal == 10
			and (healing_result.get("element_side_effects", []) as Array).is_empty(),
		"Attack side effects must not recursively trigger from healing or utility cards."
	)
	await _test_game_projects_weapon_and_blessing_elements()
	quit(0 if _failures == 0 else 1)


func _test_game_projects_weapon_and_blessing_elements() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var inventory := game.get("inventory_manager") as RefCounted
	if not bool(inventory.call("has_equipment", &"hunter_bow")):
		inventory.call("add_equipment", &"hunter_bow")
	_expect(
		bool(inventory.call("equip", &"hunter_bow")),
		"Element contract setup must equip the wind primal weapon."
	)
	var gift_manager := game.get("divine_gift_manager") as RefCounted
	gift_manager.call("add_or_upgrade", "resonant_grace")
	gift_manager.call("add_or_upgrade", "boundless_font")
	gift_manager.call("add_or_upgrade", "eternal_memory")
	var card_database := game.get("card_database") as RefCounted
	var attack := card_database.call("get_card", "ember_bolt") as Dictionary
	var infused := game.call("_apply_combo_infusions_to_card", attack) as Dictionary
	var elements := (
		(infused.get("effect", {}) as Dictionary).get("elements", []) as Array
	)
	_expect(
		elements.has("wind") and elements.has("fire") and elements.has("poison") and elements.has("ice"),
		"Normal attacks must carry the equipped weapon plus all three active Blessing states."
	)
	var skill := card_database.call("get_card", "frost_bind") as Dictionary
	var infused_skill := game.call("_apply_combo_infusions_to_card", skill) as Dictionary
	var skill_elements := (
		(infused_skill.get("effect", {}) as Dictionary).get("elements", []) as Array
	)
	_expect(
		skill_elements.has("wind") and skill_elements.has("fire") and skill_elements.has("poison") and skill_elements.has("ice"),
		"Every damaging skill must inherit the equipped weapon plus all three active Blessing states."
	)
	_expect(
		(gift_manager.call("get_basic_attack_status_profiles") as Array).size() == 3,
		"Three Blessing slots must project three explicit normal-attack status profiles."
	)
	if not bool(inventory.call("has_equipment", &"apprentice_staff")):
		inventory.call("add_equipment", &"apprentice_staff")
	_expect(
		bool(inventory.call("equip", &"apprentice_staff")),
		"Water auto-attack setup must equip the water primal weapon."
	)
	var water_attack := game.call(
		"_apply_combo_infusions_to_card", attack
	) as Dictionary
	_expect(
		float(water_attack.get("attack_size_multiplier", 1.0)) >= 1.20,
		"Water must widen a piercing sword wave instead of disabling its corridor pierce."
	)
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
