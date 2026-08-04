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
	meta.story_state["chapter_id"] = "chapter_03"
	for variant_id in catalog.get_active_variant_ids("chapter_03"):
		meta.region_clear_counts[String(variant_id)] = 0
		meta.region_boss_defeated[String(variant_id)] = false

	for _clear_index in 4:
		game.call("_begin_expedition_run", [], &"hell_autumn", false)
		_expect(run.active and run.expedition_power_tier == 2, "Hell-corrupted routes must start at power tier 2.")
		game.call("_finish_run", true)
	_expect(meta.get_region_clear_count(&"hell_autumn") == 4, "Four successful exits must record four clears for that exact variant.")
	_expect(meta.is_region_boss_ready(&"hell_autumn"), "The matching central boss seal must become eligible after four clears.")

	game.call("_begin_expedition_run", [], &"hell_crystal", false)
	game.call("_finish_run", true)
	_expect(
		meta.get_region_clear_count(&"hell_crystal") == 0,
		"Other routes must remain farmable without accumulating clears while a regional boss is pending."
	)

	game.call("_begin_expedition_run", [], &"hell_autumn", true)
	_expect(run.is_boss_run, "Central-gate travel must create a boss run, not another route clear.")
	run.boss_defeated = true
	game.call("_finish_run", true)
	_expect(meta.get_region_clear_count(&"hell_autumn") == 4, "Boss victory must not add a fifth route clear.")
	_expect(meta.is_region_boss_defeated(&"hell_autumn"), "Boss victory must permanently mark that variant boss defeated.")
	_expect(not meta.is_region_boss_ready(&"hell_autumn"), "A completed boss must return to a closed completed state.")

	game.call("_begin_expedition_run", [], &"hell_crystal", false)
	game.call("_finish_run", true)
	_expect(meta.get_region_clear_count(&"hell_crystal") == 1, "Route clear accumulation must resume after the pending boss is defeated.")

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
