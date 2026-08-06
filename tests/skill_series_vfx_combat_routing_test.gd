extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var skill_catalog := game.get("skill_recipe_manager") as SkillRecipeManager
	var series_catalog := game.get("skill_series_vfx_catalog") as RefCounted
	_expect(bool(series_catalog.call("load_catalog")), "Combat routing needs the production series VFX catalog.")
	var skills := skill_catalog.get_all_skills()
	_expect(skills.size() == 39, "Combat routing must cover all 39 current skills.")
	var all_skill_ids: Array[String] = []
	for skill_variant in skills:
		all_skill_ids.append(String((skill_variant as Dictionary).get("id", "")))
	for skill_variant in skills:
		var skill := skill_variant as Dictionary
		var series_id := String(skill.get("series_id", ""))
		var tier_rank := int(skill.get("tier_rank", 0))
		_expect(
			skill_catalog.configure_loadout(all_skill_ids, [String(skill.get("id", ""))], 99),
			"Combat routing fixture must activate %s." % skill.get("id", "")
		)
		var profile := game.call("_resolve_combat_vfx_profile", skill) as Dictionary
		_expect(
			String(profile.get("named_vfx_id", "")) == "series:%s" % series_id,
			"%s combat cast must route to its own series object." % skill.get("id", "")
		)
		_expect(
			int(profile.get("evolution_level", 0)) == tier_rank,
			"%s combat tier must match its basic/advanced/master rank." % skill.get("id", "")
		)
		var legacy_card := {
			"id": String(skill.get("legacy_vfx_id", "")),
			"name": String(skill.get("name", "")),
			"type": "skill",
			"combo_visual_profile": {"finisher": true},
			"effect": {"kind": "damage"},
		}
		var bridged_profile := game.call(
			"_resolve_combat_vfx_profile", legacy_card
		) as Dictionary
		_expect(
			String(bridged_profile.get("named_vfx_id", "")) == "series:%s" % series_id,
			"%s selected skill must disambiguate its legacy Finisher recipe to %s."
				% [skill.get("id", ""), series_id]
		)
		_expect(
			int(bridged_profile.get("evolution_level", 0)) == tier_rank,
			"%s legacy Finisher bridge must retain its formal tier." % skill.get("id", "")
		)

	_expect(
		skill_catalog.configure_loadout(
			all_skill_ids,
			["eclipse_double_wheel", "wildfire_thunder_tone"],
			99
		),
		"Compatibility fixture must allow two active skills sharing one old recipe."
	)
	var shared_legacy_profile := game.call("_resolve_combat_vfx_profile", {
		"id": "heavenly_wheel_sever",
		"type": "skill",
		"combo_visual_profile": {"finisher": true},
		"effect": {"kind": "damage"},
	}) as Dictionary
	_expect(
		String(shared_legacy_profile.get("named_vfx_id", "")) == "series:lightning"
			and int(shared_legacy_profile.get("evolution_level", 0)) == 2,
		"When a compatibility save activates two skills for one recipe, the last configured skill must deterministically own its series and tier."
	)

	var advanced := skill_catalog.get_skill("shared_pulse_guard")
	skill_catalog.configure_loadout(all_skill_ids, ["shared_pulse_guard"], 99)
	var triggered: Array[Dictionary] = [advanced]
	game.call("_resolve_skill_triggers", triggered)
	await process_frame
	await process_frame
	var effect := _find_active_series_effect(game.get("current_map") as Node)
	_expect(effect != null, "Triggered current skill must spawn a series-object combat effect.")
	if effect != null:
		_expect(
			String(effect.call("get_profile_id")) == "series:great_shield",
			"守一共脈 trigger must spawn the Royal Shield series object."
		)
		_expect(
			int(effect.call("get_evolution_level")) == 2,
			"守一共脈 trigger must play its advanced single-lane tier."
		)
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: all 39 skills route combat casts to shared series-object tiers")
	quit(1 if _failures > 0 else 0)


func _find_active_series_effect(map: Node) -> Node:
	if map == null:
		return null
	for child in map.get_children():
		if (
			child.has_method("get_profile_id")
			and String(child.call("get_profile_id")).begins_with("series:")
		):
			return child
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
