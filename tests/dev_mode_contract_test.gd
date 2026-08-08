extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/system/PauseMenu.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		bool(ProjectSettings.get_setting("development/dev_mode_enabled", false)),
		"The current development build must enter dev mode by default."
	)
	ProjectSettings.set_setting("development/force_dev_mode_in_tests", true)
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game.has_method("is_dev_mode_enabled") and bool(game.call("is_dev_mode_enabled")), "Game must expose its centralized dev-mode state.")

	var inventory: RefCounted = game.get("inventory_manager")
	for resource_id in inventory.call("get_resource_ids") as Array[StringName]:
		_expect(int(inventory.call("get_resource_amount", resource_id)) >= 999999, "%s must be stocked in dev mode." % resource_id)
	for item_variant in inventory.call("get_equipment_catalog") as Array:
		var item_id := StringName((item_variant as Dictionary).get("id", ""))
		_expect(bool(inventory.call("has_equipment", item_id)), "%s must be owned in dev mode." % item_id)
	for fixture_id in [&"cedar_display", &"iron_display", &"grand_counter"]:
		_expect(
			bool(inventory.call("owns_tool", fixture_id)),
			"%s must be installed in dev mode." % fixture_id
		)

	var meta := game.get("meta_state") as MetaState
	var card_database: RefCounted = game.get("card_database")
	_expect(meta.unlocked_cards.size() == (card_database.call("get_all_cards") as Array).size(), "Every Sword Soul/card must be unlocked in dev mode.")
	var skill_manager: RefCounted = game.get("skill_recipe_manager")
	_expect(meta.learned_skill_ids.size() == (skill_manager.call("get_all_skills") as Array).size(), "Every named skill must be learned in dev mode.")
	_expect(meta.active_skill_ids.is_empty(), "Dev mode must leave named-skill activation to the expedition selector instead of preselecting every recipe.")

	var entries: Array[Dictionary] = []
	if game.has_method("get_dev_map_entries"):
		entries.assign(game.call("get_dev_map_entries") as Array)
	_expect(entries.size() >= 20, "Dev map select must expose the hub, all routes, and regional Boss rooms.")
	for entry in entries:
		_expect(ResourceLoader.exists(String(entry.get("scene_path", ""))), "Dev map entry must resolve: %s" % entry)

	var pause := game.call("open_ui", "PauseMenu", PAUSE_SCENE, true) as Control
	await process_frame
	var dev_button := pause.get_node_or_null("MenuPanel/Content/ButtonStack/DevMaps") as Button
	_expect(dev_button != null and dev_button.visible, "Pause must expose the dev map selector while dev mode is enabled.")
	var map_options := pause.get_node_or_null("MenuPanel/Content/DevMapPanel/MapOptions") as OptionButton
	_expect(map_options != null and map_options.item_count == entries.size(), "Dev map selector must list every centralized map entry.")

	var crystal_path := ""
	for entry in entries:
		if String(entry.get("variant_id", "")) == "crystal" and not bool(entry.get("is_boss", false)):
			crystal_path = String(entry.get("scene_path", ""))
			break
	_expect(not crystal_path.is_empty(), "Dev map catalog must include the Crystal route.")
	game.call("_on_dev_map_requested", crystal_path, pause)
	await process_frame
	await process_frame
	_expect(
		String(game.get("current_map").scene_file_path).ends_with("CrystalRoute.tscn"),
		"Dev travel must resolve and load the authoritative Crystal route immediately."
	)
	var run := game.get("run_state") as RunState
	_expect(run.active and run.expedition_variant_id == &"crystal", "Dev travel into a combat route must create a playable test Run.")

	var second_pause := game.call("open_ui", "PauseMenu", PAUSE_SCENE, true) as Control
	game.call("_on_dev_map_requested", "res://scenes/maps/town.tscn", second_pause)
	await process_frame
	await process_frame
	_expect(not run.active, "Leaving a dev combat map must discard the test Run without settlement.")
	_expect(
		String(game.get("current_map").scene_file_path).ends_with("TownMap.tscn"),
		"Dev travel must return to the authoritative Town directly."
	)

	game.queue_free()
	await process_frame
	ProjectSettings.set_setting("development/force_dev_mode_in_tests", false)
	paused = false
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
