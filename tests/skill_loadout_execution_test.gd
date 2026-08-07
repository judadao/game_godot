extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const LOADOUT_FILLERS := [
	"healing_light",
	"flame_imbue",
	"echo_volley",
	"storm_charge",
	"guard",
	"renewal",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("development/force_dev_mode_in_tests", true)
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run")
	await process_frame
	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	deck.energy = 0.0
	run.energy = 0.0
	Engine.time_scale = 0.22
	game.call("_process", 0.22)
	_expect(
		is_equal_approx(deck.energy, 0.95),
		"Tactical slowdown must not make AP regenerate slower than the real-time Combo clock."
	)
	Engine.time_scale = 1.0
	var skill_manager := game.get("skill_recipe_manager") as SkillRecipeManager
	var skills := skill_manager.get_all_skills()
	var all_skill_ids: Array[String] = []
	for skill_variant in skills:
		all_skill_ids.append(String((skill_variant as Dictionary).get("id", "")))
	_expect(skills.size() == 39, "The execution regression must exercise all 39 formal skills.")
	for skill_variant in skills:
		var skill := skill_variant as Dictionary
		var skill_id := String(skill.get("id", ""))
		var routes := skill.get("combo_routes", []) as Array
		var route := routes[0] as Array if not routes.is_empty() else []
		var loadout := _loadout_for_route(game, route)
		_expect(loadout.size() == 4, "%s must fit the fixed Healing plus three Sword Soul slots." % skill_id)
		if loadout.size() != 4:
			continue
		_expect(
			skill_manager.configure_loadout(all_skill_ids, [skill_id], 99),
			"%s must be activatable in the production skill manager." % skill_id
		)
		(game.get("deck_manager") as DeckManager).start_fixed_hand(loadout, 5.0)
		_expect(
			await _execute_route(game, route, skill_id),
			"%s must execute through its real fixed hand, AP clock, and Combo countdown." % skill_id
		)

	game.queue_free()
	await process_frame
	ProjectSettings.set_setting("development/force_dev_mode_in_tests", false)
	if _failures == 0:
		print("PASS: all 39 formal skills execute from their real combat loadouts")
	quit(1 if _failures > 0 else 0)


func _loadout_for_route(game: Node, route: Array) -> Array[String]:
	var database := game.get("card_database") as CardDatabase
	var loadout: Array[String] = []
	for card_id_variant in route:
		var card_id := String(card_id_variant)
		if (
			String(database.get_card(card_id).get("type", "")) == "healing"
			and not loadout.has(card_id)
		):
			loadout.append(card_id)
			break
	if loadout.is_empty():
		loadout.append("healing_light")
	for card_id_variant in route:
		var card_id := String(card_id_variant)
		if not loadout.has(card_id):
			loadout.append(card_id)
	for filler in LOADOUT_FILLERS:
		if loadout.size() >= 4:
			break
		if not loadout.has(filler):
			loadout.append(filler)
	return loadout.slice(0, 4)


func _execute_route(game: Node, route: Array, expected_skill_id: String) -> bool:
	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	Engine.time_scale = 1.0
	game.call("_set_tactical_slowdown", false)
	run.temporary_buffs["combo_formula_history"] = []
	run.temporary_buffs["combo_triggered_skill_ids"] = []
	run.temporary_buffs["finisher_queue"] = []
	run.temporary_buffs["finisher_pending"] = false
	run.temporary_buffs["combo_chain_count"] = 0
	run.temporary_buffs["combo_chain_remaining"] = 0.0
	run.temporary_buffs["combo_chain_skills"] = {}
	run.temporary_buffs["combo_chain_order"] = []
	run.temporary_buffs["active_infusions"] = []
	run.temporary_buffs["combo_levels"] = {}
	run.temporary_buffs["infusion_effects"] = []
	run.temporary_buffs["card_tempo_stacks"] = 0
	run.temporary_buffs["card_tempo_remaining"] = 0.0
	deck.energy = deck.max_energy
	run.energy = deck.energy
	for card_id_variant in route:
		var card_id := String(card_id_variant)
		var slot_index := -1
		for index in deck.hand_instances.size():
			if deck.hand_instances[index].card_id == card_id:
				slot_index = index
				break
		if slot_index < 0:
			return false
		var waited := 0.0
		var projected := game.call("_card_for_cast", deck.hand_instances[slot_index]) as Dictionary
		var cost := float(projected.get("cost", 0))
		while deck.energy < cost and waited < 3.0:
			game.call("_process", 0.05 * Engine.time_scale)
			waited += 0.05
		game.call("_on_card_selected", slot_index)
		await process_frame
	var queue := run.temporary_buffs.get("finisher_queue", []) as Array
	for queued_variant in queue:
		if String((queued_variant as Dictionary).get("id", "")) == expected_skill_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
