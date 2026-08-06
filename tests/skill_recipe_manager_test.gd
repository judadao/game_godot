extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "Skill-series catalog must load.")
	_expect(catalog.get_memory_capacity_for_library_level(0) == 10, "Legacy Memory Library projection must stay readable during migration.")
	_expect(catalog.get_memory_capacity_for_library_level(4) == 30, "Maximum legacy memory projection must stay readable.")

	var basic := catalog.get_skill("silent_war_cadence")
	var advanced := catalog.get_skill("myriad_blades_descend")
	var master := catalog.get_skill("sudden_rain_polyphony")
	_expect(String(basic.get("series_id", "")) == "sword_rain" and String(basic.get("tier", "")) == "basic", "戰律希聲 must be the Sword Rain basic skill.")
	_expect(String(advanced.get("tier", "")) == "advanced", "萬劍垂天 must be the Sword Rain advanced skill.")
	_expect(String(master.get("tier", "")) == "master", "驟雨繁音 must be the Sword Rain master skill.")
	_expect(catalog.get_legacy_vfx_id("myriad_blades_descend") == "horizon_stream", "萬劍垂天 must preserve its Horizon recipe compatibility ID.")

	_expect(catalog.configure_loadout(["silent_war_cadence"], ["silent_war_cadence"], 10), "Known new skill IDs may round-trip through the compatibility loadout boundary.")
	_expect(not catalog.configure_loadout(["iron_momentum"], ["iron_momentum"], 10), "Retired passive skills must be rejected.")
	_expect(catalog.record_card({"id": "ember_bolt", "type": "attack", "effect": {"amount": 99}}).is_empty(), "The retired card-count recipe engine must no longer trigger old skills.")

	var meta := MetaState.new()
	meta.apply_dict({
		"schema_version": 7,
		"learned_skill_ids": ["iron_momentum", "silent_war_cadence", "silent_war_cadence"],
		"active_skill_ids": ["iron_momentum", "silent_war_cadence", "unknown_skill"],
	})
	_expect(meta.learned_skill_ids == ["silent_war_cadence"], "Skill save migration must remove retired IDs and preserve new stable IDs uniquely.")
	_expect(meta.active_skill_ids == ["silent_war_cadence"], "Active skills must remain a subset of learned new-series IDs.")
	_expect(int(meta.get_last_migration_report().get("retired_skills_removed", 0)) == 1, "Migration report must record retired skill removal.")

	if _failures == 0:
		print("PASS: new skill-series catalog and retired recipe compatibility")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
