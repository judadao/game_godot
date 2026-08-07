extends SceneTree

const EXPECTED_FAMILIES := {
	"sword_rain": "marked_execution",
	"moon_wheel": "returning_orbit",
	"feather": "orbiting_feather_contact_field",
	"ancient_wood": "sword_aura_gate_network",
	"giant_stone": "ricochet_boulders",
	"great_shield": "forward_guard_counter",
	"fire": "route_burn_detonation",
	"lightning": "target_switch_chain",
	"water_flow": "outbound_returning_tide",
	"plant_attack": "host_growth_harvest",
	"dragon_breath": "crossfire_lane",
	"dawn_vitality": "risk_heal_judgment",
	"shared_branch_vitality": "dual_origin_crossfire",
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "Skill catalog must load.")
	var seen_families: Dictionary = {}
	for series_variant in catalog.get_all_series():
		var series := series_variant as Dictionary
		var series_id := String(series.get("id", ""))
		var family := String(series.get("gameplay_family", ""))
		_expect(family == String(EXPECTED_FAMILIES.get(series_id, "")), "%s must use its approved gameplay family." % series_id)
		_expect(not seen_families.has(family), "%s must not duplicate another series gameplay family." % series_id)
		seen_families[family] = true
		_expect(String(series.get("gameplay_summary", "")).contains("玩家"), "%s must explain the player's decision, not only its VFX." % series_id)
		var skills := series.get("skills", []) as Array
		for tier_index in skills.size():
			var skill := skills[tier_index] as Dictionary
			var gameplay := skill.get("gameplay_effect", {}) as Dictionary
			_expect(String(skill.get("gameplay_family", "")) == family, "%s must inherit its series gameplay family." % skill.get("id", ""))
			_expect(not gameplay.is_empty(), "%s must have executable tier gameplay modifiers." % skill.get("id", ""))
			_expect(int(gameplay.get("tier_rank", 0)) == tier_index + 1, "%s gameplay must match its tier." % skill.get("id", ""))

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	for entry_variant in game.call("_inventory_codex_projection") as Array:
		var entry := entry_variant as Dictionary
		_expect(String(entry.get("description", "")).contains("玩法："), "%s codex must lead with its gameplay rule." % entry.get("id", ""))
	var database := game.get("card_database") as CardDatabase
	var legacy_catalog := game.get("combo_finisher_catalog") as RefCounted
	var runtime_catalog := game.get("skill_recipe_manager") as SkillRecipeManager
	var base_attack := database.get_card("ember_bolt")
	var player := game.get("player") as Node2D
	var player_position := player.global_position
	for series_variant in runtime_catalog.get_all_series():
		var series := series_variant as Dictionary
		var master := (series.get("skills", []) as Array)[2] as Dictionary
		var recipe := legacy_catalog.call("get_recipe", String(master.get("legacy_vfx_id", ""))) as Dictionary
		recipe["id"] = String(master.get("id", ""))
		recipe["name"] = String(master.get("name", ""))
		recipe["series_id"] = String(master.get("series_id", ""))
		recipe["gameplay_family"] = String(master.get("gameplay_family", ""))
		recipe["gameplay_effect"] = (master.get("gameplay_effect", {}) as Dictionary).duplicate(true)
		var finisher := game.call("_build_formula_finisher", base_attack, recipe) as Dictionary
		var effect := finisher.get("effect", {}) as Dictionary
		_expect(String(effect.get("series_gameplay_family", "")) == String(series.get("gameplay_family", "")), "%s master must reach real combat resolution." % series.get("id", ""))
		_expect(int(effect.get("tier_rank", 0)) == 3, "%s must deliver its tier to runtime behavior, not only its catalog." % series.get("id", ""))
	_expect(game.has_method("_activate_feather_halo_contact_field"), "Game must install the Feather contact field from combat resolution.")
	if game.has_method("_activate_feather_halo_contact_field"):
		var feather_profile := {
			"duration": 4.8, "radius": 176.0, "tick_interval": 0.18,
			"damage_per_tick": 2, "knockback": 105.0, "feather_count": 3,
		}
		game.call("_activate_feather_halo_contact_field", feather_profile)
		var controller := player.get_node_or_null("ActiveFeatherHaloDamageController")
		_expect(controller != null, "Feather combat resolution must create one player-owned contact field.")
		var controller_id := controller.get_instance_id() if controller != null else 0
		feather_profile["duration"] = 6.4
		feather_profile["feather_count"] = 7
		game.call("_activate_feather_halo_contact_field", feather_profile)
		controller = player.get_node_or_null("ActiveFeatherHaloDamageController")
		_expect(
			controller != null and controller.get_instance_id() == controller_id,
			"Fast Feather recasts must refresh the same controller instead of stacking fields."
		)
	_expect(player.global_position == player_position, "Automatic series resolution must never move the player.")
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: all 13 series expose distinct executable gameplay and codex rules")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
