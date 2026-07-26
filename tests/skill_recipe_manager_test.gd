extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := SkillRecipeManager.new()
	_expect(manager.load_catalog("res://data/skills.json"), "Skill catalog must load.")
	_expect(manager.get_memory_capacity_for_library_level(0) == 10, "Base memory capacity must be 10.")
	_expect(manager.get_memory_capacity_for_library_level(4) == 30, "Maximum library capacity must be 30.")
	_expect(manager.configure_loadout(["iron_momentum"], ["iron_momentum"], 10), "The initial learned skill must fit the base loadout.")

	var utility := {"id": "quickstep", "type": "utility", "effect": {"dash": 180}}
	var healing := {"id": "healing_light", "type": "healing", "effect": {"amount": 18}}
	var zero_damage_attack := {"id": "setup_slash", "type": "attack", "effect": {"amount": 0}}
	var multi_hit_attack := {"id": "cleave", "type": "attack", "effect": {"amount": 5, "hits": 4}}
	for ignored_card in [utility, healing, zero_damage_attack]:
		_expect(manager.record_card(ignored_card).is_empty(), "Non-damaging cards must not advance count recipes.")
	for index in 4:
		_expect(manager.record_card(multi_hit_attack).is_empty(), "Iron Momentum must not trigger before five attack cards.")
	var count_triggers := manager.record_card(multi_hit_attack)
	_expect(count_triggers.size() == 1, "Five damaging attack cards must trigger Iron Momentum exactly once.")
	_expect(String(count_triggers[0].get("id", "")) == "iron_momentum", "The initial trigger must identify Iron Momentum.")
	var iron_effect := count_triggers[0].get("effect", {}) as Dictionary
	_expect(
		String(iron_effect.get("kind", "")) == "combat_status"
		and String(iron_effect.get("status_id", "")) == "super_armor"
		and int(iron_effect.get("tier", 0)) == 1
		and is_equal_approx(float(iron_effect.get("duration", 0.0)), 3.0),
		"Iron Momentum must grant weak super armor for three seconds."
	)
	_expect(manager.record_card(multi_hit_attack).is_empty(), "A skill on cooldown must not retrigger.")
	manager.tick(10.0)

	_expect(manager.configure_loadout(
		["iron_momentum", "ember_reprise", "battle_tempo"],
		["iron_momentum", "ember_reprise", "battle_tempo"],
		10
	), "Multiple learned skills that fit memory must equip together.")
	var ember := {"id": "ember_bolt", "type": "attack", "effect": {"amount": 12}}
	var cleave := {"id": "cleave", "type": "attack", "effect": {"amount": 8}}
	manager.record_card(ember)
	manager.record_card(healing)
	_expect(manager.record_card(cleave).is_empty(), "A successful non-attack card must reset exact attack sequences.")
	manager.record_card(ember)
	manager.record_card(ember)
	var restarted := manager.record_card(cleave)
	_expect(restarted.any(func(skill: Dictionary) -> bool: return String(skill.get("id", "")) == "ember_reprise"), "A wrong first-step attack must restart an exact sequence from step one.")

	manager.reset_runtime()
	manager.record_card(multi_hit_attack)
	manager.tick(8.1)
	for index in 4:
		manager.record_card(multi_hit_attack)
	_expect(manager.get_progress("iron_momentum") == 4, "An expired count window must discard old progress.")
	var simultaneous := manager.record_card(multi_hit_attack)
	_expect(simultaneous.size() == 2, "Parallel active skills must be able to trigger on the same attack.")
	_expect(simultaneous.any(func(skill: Dictionary) -> bool: return String(skill.get("id", "")) == "iron_momentum"), "Simultaneous triggers must include Iron Momentum.")
	_expect(simultaneous.any(func(skill: Dictionary) -> bool: return String(skill.get("id", "")) == "battle_tempo"), "Simultaneous triggers must include the parallel recipe.")

	_expect(not manager.configure_loadout(["grand_strategy"], ["grand_strategy"], 10), "A loadout over memory capacity must be rejected.")
	_expect(not manager.configure_loadout([], ["iron_momentum"], 10), "An unlearned skill must not be equipped.")

	if _failures == 0:
		print("PASS: passive attack-only skill recipes and memory loadouts")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
