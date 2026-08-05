extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const CATALOG_SCRIPT := preload("res://scripts/systems/expedition_region_catalog.gd")

var _failures := 0

class NoOpSaveService:
	extends RefCounted
	func save_meta(_path: String, _data: Dictionary) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("save_service", NoOpSaveService.new())
	var meta := game.get("meta_state") as MetaState
	var run := game.get("run_state") as RunState
	var catalog := CATALOG_SCRIPT.new()
	var selector_portal := Node.new()
	selector_portal.set_meta("expedition_variant_id", &"autumn")
	selector_portal.set_meta("expedition_variant_options", [
		{
			"variant_id": "autumn",
			"display_name": "秋季戰場",
			"target_scene_path": catalog.get_route_scene_path(&"autumn"),
		},
		{
			"variant_id": "hell_autumn",
			"display_name": "地獄秋季",
			"target_scene_path": catalog.get_route_scene_path(&"hell_autumn"),
		},
	])
	game.call(
		"_on_portal_entered",
		selector_portal,
		catalog.get_route_scene_path(&"autumn"),
		&"PlayerSpawn",
		game.get("player")
	)
	var selector := game.call("get_open_ui", "ExpeditionVariantSelectUI") as Control
	_expect(selector != null, "A portal with multiple unlocked worlds must open the direct-button selector first.")
	if selector != null:
		selector.emit_signal("variant_selected", selector_portal.get_meta("expedition_variant_options")[1])
		await process_frame
	selector_portal.free()
	var selected_deck_builder := game.call("get_open_ui", "DeckBuilderUI") as Control
	_expect(
		selected_deck_builder != null
			and String(selected_deck_builder.get_meta("expedition_target_scene_path", ""))
				== catalog.get_route_scene_path(&"hell_autumn"),
		"Selecting Hell Autumn must carry that exact route into the existing loadout flow."
	)
	if selected_deck_builder != null:
		game.call("close_ui", selected_deck_builder)
	meta.story_state["chapter_id"] = "chapter_03"
	for variant_id in catalog.get_active_variant_ids("chapter_03"):
		meta.region_clear_counts[String(variant_id)] = 0
		meta.region_boss_defeated[String(variant_id)] = false

	for _clear_index in 4:
		game.call("_begin_expedition_run", [], &"hell_autumn", false)
		_expect(run.active and run.expedition_power_tier == 3, "Hell-corrupted routes must start at power tier 3.")
		game.call("_finish_run", true)
	_expect(meta.get_region_clear_count(&"hell_autumn") == 4, "Four successful exits must record four clears for that exact variant.")
	_expect(meta.is_region_boss_ready(&"hell_autumn"), "The matching central boss seal must become eligible after four clears.")

	game.call("_begin_expedition_run", [], &"hell_crystal", false)
	game.call("_finish_run", true)
	_expect(
		meta.get_region_clear_count(&"hell_crystal") == 1,
		"Every route must keep earning its own passage fragments while another Boss key is ready."
	)
	for _clear_index in 3:
		game.call("_begin_expedition_run", [], &"hell_crystal", false)
		game.call("_finish_run", true)
	_expect(meta.has_region_boss_key(&"hell_crystal"), "Hell Crystal must assemble its own Boss key independently.")

	game.call("_begin_expedition_run", [], &"hell_autumn", true)
	_expect(run.is_boss_run, "Central-gate travel must create a boss run, not another route clear.")
	run.boss_defeated = true
	game.call("_finish_run", true)
	_expect(meta.get_region_clear_count(&"hell_autumn") == 4, "Boss victory must not add a fifth route clear.")
	_expect(meta.is_region_boss_defeated(&"hell_autumn"), "Boss victory must permanently mark that variant boss defeated.")
	_expect(not meta.is_region_boss_ready(&"hell_autumn"), "A completed boss must return to a closed completed state.")
	_expect(meta.has_region_boss_key(&"hell_crystal"), "Clearing one Boss must not consume another variant's assembled key.")

	game.call("_begin_expedition_run", [], &"heaven", false)
	_expect(run.expedition_power_tier == catalog.get_power_tier(&"heaven"), "Heaven must use the highest expedition reward tier.")
	var reward_before := int(run.materials_earned.get("magic_shard", 0))
	game.call("_on_reward_bag_collected", &"material", {"magic_shard": 2})
	_expect(int(run.materials_earned.get("magic_shard", 0)) == reward_before + 8, "Tier 4 routes must multiply material bag rewards fourfold.")
	game.call("_finish_run", false)

	game.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
