extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const BASIC_FIRE_ID := "flowing_fire_night"
const MASTER_FIRE_ID := "celestial_wildfire"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var manager := game.get("skill_recipe_manager") as SkillRecipeManager
	var active_catalog_ids: Array[String] = []
	for skill in manager.get_all_skills():
		active_catalog_ids.append(String(skill.get("id", "")))
	_expect(
		manager.configure_loadout(
			active_catalog_ids,
			[BASIC_FIRE_ID, MASTER_FIRE_ID],
			99
		),
		"The fixture must activate two compatible formal skills."
	)
	var database := game.get("card_database") as CardDatabase
	var formula_card := database.get_card("flame_imbue")
	for _index in 6:
		game.call("_record_combo_formula", formula_card)
	var run := game.get("run_state") as RunState
	var queue := run.temporary_buffs.get("finisher_queue", []) as Array
	_expect(
		queue.size() == 2,
		"One six-card formula must queue both compatible basic and master skills."
	)
	_expect(
		(run.temporary_buffs.get("combo_formula_history", []) as Array).size() == 6,
		"The shared formula must remain visible while queued skills are pending."
	)
	game.call("_consume_finisher_formula")
	_expect(
		(run.temporary_buffs.get("finisher_queue", []) as Array).size() == 1
		and (run.temporary_buffs.get("combo_formula_history", []) as Array).size() == 6,
		"Consuming the first of multiple skills must preserve the formula for the remaining queue."
	)
	game.call("_consume_finisher_formula")
	_expect(
		(run.temporary_buffs.get("finisher_queue", []) as Array).is_empty()
		and (run.temporary_buffs.get("combo_formula_history", []) as Array).is_empty()
		and (run.temporary_buffs.get("combo_triggered_skill_ids", []) as Array).is_empty()
		and not bool(run.temporary_buffs.get("finisher_pending", true)),
		"Consuming the final queued skill must reset the formula and per-cycle trigger guard."
	)
	for _index in 3:
		game.call("_record_combo_formula", formula_card)
	queue = run.temporary_buffs.get("finisher_queue", []) as Array
	_expect(
		queue.size() == 1
		and String((queue[0] as Dictionary).get("id", "")) == BASIC_FIRE_ID,
		"After the final reset, the next formula cycle must be able to trigger again."
	)
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: multiple queued skills reset into a reusable formula cycle")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
