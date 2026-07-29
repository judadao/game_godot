extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Power-fantasy balance test requires the production card catalog.")
	var energy_cycle := database.get_card("energy_surge")
	_expect(
		String(energy_cycle.get("type", "")) == "combo"
			and bool(energy_cycle.get("growth_locked", false))
			and int(energy_cycle.get("max_level", 0)) == 1
			and int(energy_cycle.get("cost", 0)) == 1
			and int((energy_cycle.get("effect", {}) as Dictionary).get("amount", 0)) == 2,
		"Energy Cycle must be a one-AP, fixed-growth Combo that restores two base AP."
	)
	var locked_instance := CardInstance.new("energy_surge", 1, "energy-cycle")
	_expect(
		locked_instance.has_method("is_growth_locked")
			and bool(locked_instance.call("is_growth_locked")),
		"Energy Cycle instances must declare that they cannot upgrade or fuse."
	)
	var lock_meta := MetaState.new()
	var persisted_cycle := lock_meta.add_card_instance("energy_surge", 1)
	_expect(
		persisted_cycle != null
			and not lock_meta.upgrade_card_instance(persisted_cycle.instance_id),
		"Permanent progression must reject Energy Cycle upgrades."
	)
	var flow_deck := DeckManager.new(database)
	flow_deck.start([
		"flame_imbue", "storm_charge", "stoneguard_combo", "blood_pact_combo",
		"energy_surge",
	], 5.0)
	_expect(
		flow_deck.hand_instances.any(
			func(instance: CardInstance) -> bool: return instance.card_id == "energy_surge"
		),
		"A high-cost deck must surface its stable flow card instead of opening with a brick hand."
	)
	var evolution := EvolutionManager.new(database)
	_expect(evolution.load_recipes(), "Fusion recipes must load for growth-lock testing.")
	var locked_fusions := evolution.find_available_fusions([
		CardInstance.new("energy_surge", 3, "locked-lv3"),
		CardInstance.new("guard", 3, "guard-lv3"),
	])
	_expect(locked_fusions.is_empty(), "Energy Cycle must never enter generic or recipe fusion.")

	var director := SurvivalWaveDirector.new()
	_expect(
		is_equal_approx(director.survival_duration, 600.0)
			and is_equal_approx(director.final_rush_duration, 60.0),
		"Autumn survival must last ten minutes with a one-minute Final Rush."
	)
	_expect(
		not director.scheduled_elite_times.is_empty()
			and is_equal_approx(director.scheduled_elite_times[0], 90.0),
		"The first Elite blessing opportunity must arrive at about ninety seconds."
	)
	_expect(
		director.base_density_cap >= 30
			and director.maximum_density_cap >= 120
			and director.base_spawn_batch >= 5
			and director.maximum_spawn_batch >= 12
			and director.final_rush_density_bonus >= 40
			and director.base_spawn_interval <= 0.55
			and director.minimum_spawn_interval <= 0.15,
		"Survival countdown must begin dense, grow continuously, and spike during Final Rush."
	)
	_expect(
		director.normal_enemy_unlocks.size() >= 6
			and not director.normal_enemy_unlocks.has("elite"),
		"Autumn survival must mix six normal archetypes while scheduling elites separately."
	)
	director.free()

	var enemy_catalog := EnemyArchetype.autumn_catalog()
	var normal_enemy_ids: Array[StringName] = [
		&"sprout", &"hopper", &"moth_swarm", &"thornling", &"charger", &"grove_shaman",
	]
	var maximum_normal_health := 0
	for enemy_id in normal_enemy_ids:
		var normal_archetype := enemy_catalog[enemy_id] as EnemyArchetype
		maximum_normal_health = maxi(maximum_normal_health, normal_archetype.max_health)
		_expect(
			normal_archetype.defense == 0,
			"Normal horde enemies must not pad their low health with defense."
		)
		_expect(
			normal_archetype.experience_reward >= 1
				and normal_archetype.experience_reward <= 3,
			"Every normal enemy must drop one low-value gem so crowd kills create the XP payoff."
		)
	var fire_ultimate := database.get_card("concussive_shout")
	var frost_ultimate := database.get_card("frost_bind")
	var fire_effect := fire_ultimate.get("effect", {}) as Dictionary
	var frost_effect := frost_ultimate.get("effect", {}) as Dictionary
	_expect(
		int(fire_effect.get("amount", 0)) >= maximum_normal_health
			and int(frost_effect.get("amount", 0)) >= maximum_normal_health,
		"Every base ultimate must wipe normal horde enemies caught in its area."
	)
	_expect(
		(enemy_catalog[&"elite"] as EnemyArchetype).max_health
			> maxi(int(fire_effect.get("amount", 0)), int(frost_effect.get("amount", 0))),
		"Elite enemies must survive one base ultimate so blessings retain a combat gate."
	)

	var navigation_enemy := EnemyBase.new()
	_expect(
		navigation_enemy.has_method("get_navigation_jump_reason"),
		"Normal enemies must expose deterministic stuck and platform jump recovery."
	)
	if navigation_enemy.has_method("get_navigation_jump_reason"):
		_expect(
			navigation_enemy.call(
				"get_navigation_jump_reason",
				Vector2(90.0, -100.0),
				0.0,
				false
			) == &"platform",
			"Enemies pursuing a player above them must jump toward reachable platforms."
		)
		_expect(
			navigation_enemy.call(
				"get_navigation_jump_reason",
				Vector2(180.0, 0.0),
				0.4,
				false
			) == &"stuck",
			"Enemies that stop making horizontal progress must jump free."
		)
		_expect(
			navigation_enemy.call(
				"get_navigation_jump_reason",
				Vector2(180.0, 0.0),
				0.0,
				true
			) == &"obstacle",
			"Enemies walking into route relief must jump over the obstacle."
		)
	navigation_enemy.free()

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"energy_surge", "guard", "healing_light", "flame_imbue",
	])
	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	var inventory := game.get("inventory_manager") as RefCounted
	var town := game.get("town_manager") as RefCounted

	town.call("apply_dict", {"building_levels": {"memory_library": 4}})
	inventory.call("add_equipment", &"apprentice_staff")
	inventory.call("equip", &"apprentice_staff")
	var projected_cycle := game.call("_card_for_cast", locked_instance) as Dictionary
	_expect(
		int((projected_cycle.get("effect", {}) as Dictionary).get("amount", 0)) >= 8,
		"Town and equipment progression must multiply Energy Cycle beyond its two-AP base."
	)

	deck.start([
		CardInstance.new("energy_surge", 1, "live-cycle"),
		CardInstance.new("guard", 1, "guard-a"),
		CardInstance.new("healing_light", 1, "heal-a"),
		CardInstance.new("flame_imbue", 1, "flame-a"),
	], 10.0)
	deck.energy = 1.0
	game.call("_on_card_selected", 0)
	_expect(
		deck.energy >= 8.0,
		"Playing Energy Cycle from one AP must produce its progression-scaled AP plus tempo refund."
	)

	run.temporary_buffs["combo_chain_count"] = 12
	var catastrophic_attack := game.call(
		"_apply_combo_infusions_to_card",
		database.get_card("ember_bolt")
	) as Dictionary
	var catastrophic_effect := catastrophic_attack.get("effect", {}) as Dictionary
	_expect(
		int(catastrophic_effect.get("target_count", 1)) == 1
			and int(catastrophic_effect.get("projectile_count", 1)) == 1
			and float(catastrophic_attack.get("attack_size_multiplier", 1.0)) >= 2.0,
		"High Combo Chain must amplify spectacle without granting free directions or projectiles."
	)

	run.temporary_buffs["combo_chain_count"] = 0
	run.temporary_buffs["combo_chain_remaining"] = 0.0
	var flame := database.get_card("flame_imbue")
	_expect(bool(game.call("_resolve_combo_card", flame)), "Flame Combo must prepare charged attacks.")
	var prepared_effects := run.temporary_buffs.get("infusion_effects", []) as Array
	_expect(
		prepared_effects.size() == 1
			and not bool((prepared_effects[0] as Dictionary).get("persistent", true)),
		"Combo power must use a finite per-card effect timer."
	)
	for _attack in 3:
		game.call("_consume_combo_attack_charges")
	_expect(
		not (run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(),
		"Automatic attacks must not consume Combo power before its timer expires."
	)
	game.call("_tick_combo_effects", 1.51)
	_expect(
		(run.temporary_buffs.get("infusion_effects", []) as Array).is_empty(),
		"Idle time must remove Combo power after 1.5 seconds."
	)

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
