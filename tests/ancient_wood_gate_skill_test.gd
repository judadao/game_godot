extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "Skill catalog must load.")
	var expected := {
		"ancient_roots_pursuit": ["兩座古木", "入口", "出口", "重新射出"],
		"growth_ring_guard": ["四座古木", "傳送網路", "連續穿越", "增幅"],
		"eternal_forest_manifest": ["六座古木", "依序穿越", "太古神木", "巨型劍氣"],
	}
	for skill_id in expected:
		var skill := catalog.get_skill(skill_id)
		var description := String(skill.get("description", ""))
		for phrase in expected[skill_id]:
			_expect(description.contains(String(phrase)), "%s codex description must explain %s." % [skill_id, phrase])
		_expect(not (skill.get("gameplay_effect", {}) as Dictionary).is_empty(), "%s must provide executable gate modifiers." % skill_id)

	var file := FileAccess.open("res://data/skill_series_vfx.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	var profile := _find_profile((parsed as Dictionary).get("profiles", []) as Array, "ancient_wood") if parsed is Dictionary else {}
	_expect(String(profile.get("motion_family", "")) == "wood_gate_relay", "Ancient Wood VFX must use the gate-relay motion family.")
	var tiers := profile.get("tiers", []) as Array
	_expect(tiers.size() == 3, "Ancient Wood needs three gate tiers.")
	if tiers.size() == 3:
		_expect(
			[int((tiers[0] as Dictionary).get("node_count", 0)), int((tiers[1] as Dictionary).get("node_count", 0)), int((tiers[2] as Dictionary).get("node_count", 0))] == [2, 4, 6],
			"Ancient Wood tiers must assemble 2/4/6 gate nodes."
		)

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var projection := game.call("_inventory_codex_projection") as Array
	for skill_id in expected:
		var entry := _find_entry(projection, skill_id)
		_expect(not entry.is_empty(), "%s must appear in the technique codex." % skill_id)
		_expect(String(entry.get("description", "")).contains(String(catalog.get_skill(skill_id).get("description", ""))), "%s codex must retain the full tier explanation after its gameplay rule." % skill_id)
	var meta := game.get("meta_state") as MetaState
	var runtime_catalog := game.get("skill_recipe_manager") as SkillRecipeManager
	if not meta.learned_skill_ids.has("ancient_roots_pursuit"):
		meta.learned_skill_ids.append("ancient_roots_pursuit")
	if not meta.unlocked_cards.has("blood_pact_combo"):
		meta.unlocked_cards.append("blood_pact_combo")
	_expect(runtime_catalog.configure_loadout(meta.learned_skill_ids, ["ancient_roots_pursuit"], 99), "Ancient Wood basic skill must be configurable.")
	var database := game.get("card_database") as CardDatabase
	for _step in 3:
		game.call("_record_combo_formula", database.get_card("blood_pact_combo"))
	var run := game.get("run_state") as RunState
	var queue := run.temporary_buffs.get("finisher_queue", []) as Array
	_expect(queue.size() == 1, "The three-step Ancient Wood route must queue one formal skill.")
	if not queue.is_empty():
		var finisher := game.call("_build_formula_finisher", database.get_card("ember_bolt"), queue[0] as Dictionary) as Dictionary
		var effect := finisher.get("effect", {}) as Dictionary
		_expect(bool(effect.get("sword_aura_gate_chain", false)), "Ancient Wood must resolve as an executable sword-aura gate chain.")
		_expect(int(effect.get("gate_count", 0)) == 2 and int(effect.get("direction_count", 0)) == 1, "Basic Ancient Wood must use two gates and one relay strike.")
		_expect(int(effect.get("amount", 0)) > int((database.get_card("ember_bolt").get("effect", {}) as Dictionary).get("amount", 0)), "Gate relay must increase real attack damage.")
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Ancient Wood uses 2/4/6 sword-aura relay gates with codex explanations")
	quit(1 if _failures > 0 else 0)


func _find_profile(profiles: Array, profile_id: String) -> Dictionary:
	for profile_variant in profiles:
		var profile := profile_variant as Dictionary
		if String(profile.get("id", "")) == profile_id:
			return profile
	return {}


func _find_entry(entries: Array, entry_id: String) -> Dictionary:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if String(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
