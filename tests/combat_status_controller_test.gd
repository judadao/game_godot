extends SceneTree


class HealthOwner:
	extends Node

	var health := 10
	var max_health := 100

	func restore_health(amount: int) -> int:
		var restored := mini(maxi(0, amount), max_health - health)
		health += restored
		return restored


var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller_script := load("res://scripts/combat/combat_status_controller.gd")
	_expect(controller_script != null, "Combat status controller must provide player status authority.")
	if controller_script == null:
		quit(1)
		return

	var owner := HealthOwner.new()
	var controller: Node = controller_script.new()
	owner.add_child(controller)
	root.add_child(owner)
	await process_frame

	controller.call("apply_reduction", &"stone_form", 0.30, 2.0)
	controller.call("tick", 1.5, false)
	controller.call("apply_reduction", &"stone_form", 0.30, 2.0)
	controller.call("tick", 0.75, false)
	_expect(
		is_equal_approx(float(controller.call("get_damage_reduction")), 0.30),
		"Refreshing one reduction source must retain one source contribution until the refreshed duration expires."
	)

	controller.call("apply_armor", &"iron_will", 1, 4.0)
	controller.call("apply_armor", &"unbreakable_stance", 2, 4.0)
	_expect(
		int(controller.call("get_strongest_armor_tier")) == 2,
		"Simultaneous armor sources must expose only the strongest armor tier."
	)

	controller.call("apply_reduction", &"counterguard", 0.40, 4.0)
	var reduced := controller.call("resolve_incoming_damage", 100, false) as Dictionary
	_expect(int(reduced.get("damage", -1)) == 40, "Damage reductions must cap at 60 percent across sources.")
	_expect(int(reduced.get("armor_tier", 0)) == 2, "A normal hit must report the strongest active armor tier.")
	var unblockable := controller.call("resolve_incoming_damage", 100, true) as Dictionary
	_expect(int(unblockable.get("damage", -1)) == 100, "Unblockable damage must bypass reductions.")
	_expect(int(unblockable.get("armor_tier", -1)) == 0, "Unblockable damage must bypass super armor.")

	controller.call("apply_retaliation", &"counterguard", 12, 0.0, 4.0)
	var retaliating := controller.call("resolve_incoming_damage", 10, false) as Dictionary
	_expect(int(retaliating.get("retaliation_damage", 0)) == 12, "Retaliation must be available while its source is active.")
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	var enemy := (load("res://scenes/monsters/AutumnSlime.tscn") as PackedScene).instantiate()
	enemy.global_position = Vector2(180.0, 0.0)
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	var player_status := player.call("get_combat_status_controller") as Node
	player_status.call("apply_retaliation", &"stoneguard_combo", 12, 0.0, 4.0)
	player_status.call("apply_armor", &"iron_will", 1, 4.0)
	var enemy_health := int(enemy.get("health"))
	player.call("take_hit", 10, enemy.global_position, 0.0)
	_expect(
		int(enemy.get("health")) < enemy_health,
		"Retaliation must damage the real attacker while armor prevents knockback."
	)
	var effect_runner := CardEffectRunner.new()
	_expect(effect_runner.supports_effect("super_armor"), "Card runner must support the catalog super-armor effect kind.")
	_expect(effect_runner.supports_effect("damage_reduction"), "Card runner must support the catalog damage-reduction effect kind.")
	_expect(effect_runner.supports_effect("fortress"), "Card runner must support the catalog combined fortress effect kind.")
	_expect(effect_runner.supports_effect("counterguard"), "Card runner must support the catalog reduction-and-retaliation effect kind.")
	var fortress_result := effect_runner.cast({
		"id": "fortress_stance",
		"effect": {"kind": "fortress", "tier": 2, "ratio": 0.40, "duration": 4.0},
	}, player, [])
	_expect(int(fortress_result.get("affected", 0)) == 1, "Fortress cards must install their combined timed statuses.")
	_expect(
		int(player_status.call("get_strongest_armor_tier")) == 2
		and is_equal_approx(float(player_status.call("get_damage_reduction")), 0.40),
		"Fortress must apply strong armor and its configured damage reduction together."
	)
	var counterguard_result := effect_runner.cast({
		"id": "stoneguard_combo",
		"effect": {"kind": "counterguard", "ratio": 0.25, "retaliation_damage": 6, "duration": 6.0},
	}, player, [])
	_expect(int(counterguard_result.get("affected", 0)) == 1, "Counterguard cards must install their combined timed statuses.")
	var counterguard_hit := player_status.call("resolve_incoming_damage", 100, false) as Dictionary
	_expect(
		int(counterguard_hit.get("damage", -1)) == 40 and int(counterguard_hit.get("retaliation_damage", 0)) == 6,
		"Counterguard must add capped reduction and retaliation through the status authority."
	)
	effect_runner.free()
	enemy.queue_free()
	player.queue_free()

	controller.call("apply_regeneration", &"verdant_renewal", 7, 1.0, 2.0)
	controller.call("tick", 1.0, true)
	_expect(owner.health == 10, "Paused status ticking must not advance regeneration pulses.")
	controller.call("tick", 1.0, false)
	_expect(owner.health == 17, "Regeneration must restore health on its configured pulse interval.")

	controller.call("apply_lifesteal", &"blood_pact", 0.25, 2.0)
	_expect(int(controller.call("restore_from_damage", 20)) == 5, "Timed lifesteal must restore its percentage of positive dealt damage.")
	_expect(owner.health == 22, "Timed lifesteal must restore health through the status owner.")

	controller.call("tick", 4.1, false)
	_expect(
		is_zero_approx(float(controller.call("get_damage_reduction")))
		and int(controller.call("get_strongest_armor_tier")) == 0
		and int(controller.call("restore_from_damage", 20)) == 0,
		"Expired statuses must no longer affect damage, armor, or lifesteal."
	)

	owner.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
