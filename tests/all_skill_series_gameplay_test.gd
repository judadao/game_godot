extends SceneTree

const EXPECTED_FAMILIES := {
	"sword_rain": "marked_execution",
	"moon_wheel": "bouncing_moon_wheel_field",
	"feather": "orbiting_feather_contact_field",
	"thorn": "blooming_thorn_barrage",
	"dr_stone": "persistent_stone_drone_squad",
	"black_hole": "singularity_pull_detonation",
	"fire": "staggered_fire_pillars",
	"lightning": "residual_chain_sky_strike",
	"water_flow": "damaging_tidal_push",
	"arcane_swamp": "arcane_swamp_entanglement",
	"dragon_breath": "dragon_breath_sweep",
	"dawn_vitality": "player_healing_zone",
	"shared_branch_vitality": "body_overdrive_afterimage",
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
	_expect(game.has_method("_activate_black_hole_field"), "Game must install the Black Hole field from combat resolution.")
	_expect(game.has_method("_activate_caster_target_controller"), "Game must install timed Fire, Lightning, Water, and Dragon controllers.")
	_expect(game.has_method("_activate_player_controller"), "Game must install player-owned Dawn and Shared Branch controllers.")
	var impact_router := game.get("series_impact_vfx_router") as Node
	_expect(impact_router != null and impact_router.get_parent() == game, "Game must own one reusable controller-signal-to-impact-VFX router.")
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
	game.call("_on_card_effect_resolved", "shared_branch_fixture", {
		"body_overdrive": {
			"duration": 7.0, "move_speed_multiplier": 1.8,
			"attack_speed_multiplier": 1.75, "afterimage_count": 8,
			"tier_rank": 3,
		},
	})
	_expect(player.get_node_or_null("ActiveBodyOverdriveController") != null, "Shared Branch combat resolution must create one player-owned body overdrive.")
	_expect(is_equal_approx(float(game.call("_effective_auto_attack_interval", 1.0)), 1.0 / 1.75), "Shared Branch attack speed must shorten the real automatic attack interval.")
	if impact_router != null:
		var router_state := impact_router.call("get_debug_state") as Dictionary
		_expect(int(router_state.get("spawn_count", 0)) >= 1, "Body Overdrive activation must immediately produce a shared layered Burst primitive.")
	game.call("_on_card_effect_resolved", "dawn_fixture", {
		"healing_zone": {
			"duration": 8.0, "radius": 280.0, "pulse_interval": 0.64,
			"heal_per_pulse": 12, "tier_rank": 3,
		},
	})
	_expect(player.get_node_or_null("ActiveHealingZoneController") != null, "Dawn combat resolution must create one player-following healing field.")
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
