extends SceneTree

var _failures := 0


class NoOpSaveService:
	extends RefCounted
	func save_meta(_path: String, _data: Dictionary) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("save_service", NoOpSaveService.new())
	var run := game.get("run_state") as RunState
	var inventory := game.get("inventory_manager") as RefCounted
	inventory.call("apply_dict", {})
	game.call("_begin_autumn_run")
	run.defeated_enemies = 20
	game.call("_on_boss_stage_completed")
	var pending := run.temporary_buffs.get("completion_chest_reward", {}) as Dictionary
	_expect(
		not pending.is_empty()
			and not inventory.owns_blueprint(StringName(pending.get("item_id", ""))),
		"Survival completion must stage the chest without granting it before settlement."
	)
	var summary := game.call("_finish_run", true, RunState.OUTCOME_VICTORY) as Dictionary
	var chest := summary.get("chest_reward", {}) as Dictionary
	_expect(
		String(chest.get("kind", "")) == "sword_soul_blueprint"
			and inventory.owns_blueprint(StringName(chest.get("item_id", ""))),
		"A completed survival run must grant its staged Sword Soul blueprint chest."
	)
	_expect(
		int(summary.get("gold", 0)) >= 276
			and int((summary.get("materials", {}) as Dictionary).get("autumn_core", 0)) >= 3,
		"Surviving Final Rush must add a large reward package before the clear bonus."
	)

	game.call("_begin_autumn_run")
	run.defeated_enemies = 21
	game.call("_on_boss_stage_completed")
	pending = run.temporary_buffs.get("completion_chest_reward", {}) as Dictionary
	var abandoned_item := StringName(pending.get("item_id", ""))
	var abandon_summary := game.call(
		"_finish_run",
		false,
		RunState.OUTCOME_ABANDON
	) as Dictionary
	_expect(
		(abandon_summary.get("chest_reward", {}) as Dictionary).is_empty()
			and int(abandon_summary.get("gold", -1)) == 0
			and not inventory.has_equipment(abandoned_item),
		"Exit Combat after reaching the finale must still discard the staged chest and run loot."
	)

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
