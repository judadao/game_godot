extends SceneTree

const RETIRED_SKILL_IDS := [
	"iron_momentum", "ember_reprise", "battle_tempo", "grand_strategy",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var projection := game.call("_inventory_codex_projection") as Array
	_expect(projection.size() == 39, "Technique codex must use the 39 approved series skills as its only source.")
	var entries_by_id: Dictionary = {}
	var tier_counts := {"basic": 0, "advanced": 0, "master": 0}
	var series_counts: Dictionary = {}
	var vfx_catalog := game.get("skill_series_vfx_catalog") as RefCounted
	_expect(bool(vfx_catalog.call("load_catalog")), "Technique codex needs the production series-object VFX catalog.")
	var projection_index := 0
	for entry_variant in projection:
		var entry := entry_variant as Dictionary
		var entry_id := String(entry.get("id", ""))
		var tier := String(entry.get("tier", ""))
		var series_id := String(entry.get("skill_series_id", ""))
		var series_rank := int(entry.get("skill_series_rank", -1))
		var tier_rank := int(entry.get("tier_rank", 0))
		_expect(not entry_id.is_empty() and not entries_by_id.has(entry_id), "Technique IDs must be stable and unique: %s." % entry_id)
		entries_by_id[entry_id] = entry
		_expect(String(entry.get("catalog_kind", "")) == "skill_series", "%s must identify the new catalog contract." % entry_id)
		_expect(tier_counts.has(tier), "%s must use basic, advanced, or master." % entry_id)
		if tier_counts.has(tier):
			tier_counts[tier] = int(tier_counts[tier]) + 1
		series_counts[series_id] = int(series_counts.get(series_id, 0)) + 1
		_expect(not String(entry.get("skill_series_name", "")).is_empty(), "%s must expose its series name." % entry_id)
		_expect(
			series_rank == projection_index / 3 and tier_rank == projection_index % 3 + 1,
			"%s must project catalog series order and basic/advanced/master tier order; got series=%d tier=%d index=%d."
				% [entry_id, series_rank, tier_rank, projection_index]
		)
		_expect(not String(entry.get("tier_label", "")).is_empty(), "%s must expose its Chinese tier label." % entry_id)
		_expect(not String(entry.get("description", "")).is_empty(), "%s must expose the approved description." % entry_id)
		_expect(not String(entry.get("recipe_summary", "")).is_empty(), "%s must expose its three-Sword-Soul formula." % entry_id)
		_expect(not entry.has("effect_summary"), "%s must not project the removed effect-values section." % entry_id)
		_expect(
			not entry.has("trigger_summary") and not entry.has("identity_elements"),
			"%s must not project removed animation or series-vocabulary description sections." % entry_id
		)
		_expect(not bool(entry.get("legacy_vfx", true)), "%s must use the series-object VFX contract." % entry_id)
		var series_vfx_id := String(entry.get("series_vfx_id", ""))
		var named_vfx_id := String(entry.get("named_vfx_id", ""))
		_expect(bool(vfx_catalog.call("has_profile", series_vfx_id)), "%s maps to a missing series-object VFX profile: %s." % [entry_id, series_vfx_id])
		_expect(named_vfx_id == "series:%s" % series_vfx_id, "%s must route preview and combat through its shared series object." % entry_id)
		projection_index += 1

	_expect(series_counts.size() == 13, "Technique codex must expose all 13 skill series.")
	for count_variant in series_counts.values():
		_expect(int(count_variant) == 3, "Every codex series must contain exactly three tiered moves.")
	_expect(tier_counts == {"basic": 13, "advanced": 13, "master": 13}, "Every tier must contain one skill from each series.")
	for retired_id in RETIRED_SKILL_IDS:
		_expect(not entries_by_id.has(retired_id), "Retired passive skill must not appear in the codex: %s." % retired_id)
	for retired_name in ["天際流光", "天光回羽", "鋼鐵意志"]:
		_expect(not projection.any(func(entry: Dictionary) -> bool: return String(entry.get("name", "")) == retired_name), "Retired skill name must not appear in the codex: %s." % retired_name)

	_expect(String((entries_by_id.get("myriad_blades_descend", {}) as Dictionary).get("name", "")) == "千鋒驟雨", "千鋒驟雨 must be the Sword Rain advanced name.")
	_expect(String((entries_by_id.get("celestial_feather_myriad", {}) as Dictionary).get("name", "")) == "萬翼神臨", "萬翼神臨 must be the Feather master name.")
	_expect(String((entries_by_id.get("thousand_feather_resonance", {}) as Dictionary).get("kind_label", "")).contains("羽毛系列"), "千羽相應 must be classified under the Feather series.")
	var flowing_fire := entries_by_id.get("flowing_fire_night", {}) as Dictionary
	_expect(
		String(flowing_fire.get("recipe_summary", ""))
			== "烈焰灌注 → 烈焰灌注 → 烈焰灌注",
		"流火照夜 must list only its ordered Sword Soul formula without ownership state."
	)

	var preview := InventoryCodexPreview.new()
	preview.size = Vector2(640.0, 320.0)
	root.add_child(preview)
	preview.show_entry(entries_by_id["flowing_fire_night"] as Dictionary)
	await process_frame
	_expect(preview.get_active_named_vfx_id() == "series:fire", "流火照夜 must preview the reusable Fire-series object.")
	preview.queue_free()

	var recipes := (game.get("combo_finisher_catalog") as RefCounted).call("get_all_recipes") as Array
	_expect(_recipe_name(recipes, "horizon_stream") == "萬劍垂天", "Current formula display must use 萬劍垂天.")
	_expect(_recipe_name(recipes, "skyward_returning_feathers") == "天羽萬象", "Current formula display must use 天羽萬象.")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: 39 skill-series codex entries with shared series-object VFX")
	quit(1 if _failures > 0 else 0)


func _recipe_name(recipes: Array, recipe_id: String) -> String:
	for recipe_variant in recipes:
		var recipe := recipe_variant as Dictionary
		if String(recipe.get("id", "")) == recipe_id:
			return String(recipe.get("name", ""))
	return ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
