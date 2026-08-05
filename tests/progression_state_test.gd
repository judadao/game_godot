extends SceneTree

const TEST_SAVE_PATH := "user://saves/progression_state_test.json"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run_script := load("res://scripts/systems/run_state.gd")
	var meta_script := load("res://scripts/systems/meta_state.gd")
	var save_script := load("res://scripts/systems/save_service.gd")
	_expect(run_script != null, "RunState script must load.")
	_expect(meta_script != null, "MetaState script must load.")
	_expect(save_script != null, "SaveService script must load.")
	if run_script == null or meta_script == null or save_script == null:
		quit(1)
		return

	var run: RefCounted = run_script.new()
	var meta: RefCounted = meta_script.new()
	var save: RefCounted = save_script.new()
	run.call("begin_run", ["ember_bolt", "guard"])
	run.set("level", 7)
	run.set("temporary_cards", ["inferno_orb", "shockwave"])
	run.set("combo_count", 9)
	run.set("temporary_buffs", {"haste": 2})
	run.set("gold_earned", 120)
	run.set("materials_earned", {"autumn_wood": 8, "magic_shard": 3})
	meta.call("add_resource", "gold", 50)
	meta.call("add_resource", "autumn_core", 1)
	meta.set("village_level", 2)
	var unlocked_cards: Array[String] = ["ember_bolt", "inferno_orb"]
	meta.set("unlocked_cards", unlocked_cards)
	meta.set("equipment", {"weapon": "iron_sword"})
	meta.set("shortcuts", {"forest_gate": true})
	meta.set("inventory_state", {"owned_equipment": ["iron_sword"], "equipment_levels": {"iron_sword": 2}})
	meta.set("town_state", {"building_levels": {"blacksmith": 2}})

	var summary := run.call("finish_run", false, &"death") as Dictionary
	meta.call("apply_run_summary", summary)
	_expect(int(summary.get("gold", 0)) == 78, "Death must retain 65 percent of collected gold bags.")
	_expect(
		(summary.get("materials", {}) as Dictionary) == {"autumn_wood": 5, "magic_shard": 2},
		"Death must retain 65 percent of collected material bags."
	)
	_expect(
		is_zero_approx(float(summary.get("completion_bonus_rate", -1.0))),
		"A defeated run must not receive the clear bonus."
	)
	_expect(int(run.get("level")) == 1, "Finishing a run must reset run level.")
	_expect((run.get("temporary_cards") as Array).is_empty(), "Finishing a run must clear temporary cards.")
	_expect(int(run.get("combo_count")) == 0, "Finishing a run must clear combo progress.")
	_expect((run.get("temporary_buffs") as Dictionary).is_empty(), "Finishing a run must clear temporary buffs.")
	_expect(int((meta.get("resources") as Dictionary).get("gold", 0)) == 128, "Death must apply the 35 percent loss once.")
	_expect(int((meta.get("resources") as Dictionary).get("autumn_wood", 0)) == 5, "Death must apply the material penalty once.")
	_expect(int(meta.get("village_level")) == 2, "Death must retain Town progression.")
	_expect((meta.get("equipment") as Dictionary).get("weapon") == "iron_sword", "Death must retain equipment.")
	_expect(bool((meta.get("shortcuts") as Dictionary).get("forest_gate", false)), "Death must retain shortcuts.")

	var victory_run: RefCounted = run_script.new()
	victory_run.call("begin_run")
	victory_run.call("add_reward", "gold", 100)
	victory_run.call("add_reward", "autumn_wood", 20)
	var victory_summary := victory_run.call("finish_run", true) as Dictionary
	_expect(
		int(victory_summary.get("gold", 0)) == 115
			and int((victory_summary.get("materials", {}) as Dictionary).get("autumn_wood", 0)) == 23,
		"A successful clear must add exactly 15 percent to bagged gold and materials."
	)
	_expect(
		is_equal_approx(float(victory_summary.get("completion_bonus_rate", 0.0)), 0.15),
		"Victory summaries must expose the 15 percent clear bonus contract."
	)

	var retreat_run: RefCounted = run_script.new()
	retreat_run.call("begin_run")
	retreat_run.call("add_reward", "gold", 101)
	retreat_run.call("add_reward", "stone", 7)
	var retreat_summary := retreat_run.call("finish_run", false, &"safe_retreat") as Dictionary
	_expect(
		int(retreat_summary.get("gold", 0)) == 101
			and (retreat_summary.get("materials", {}) as Dictionary) == {"stone": 7},
		"A physical extraction portal must retain the full collected haul."
	)
	var abandon_run: RefCounted = run_script.new()
	abandon_run.call("begin_run")
	abandon_run.call("add_reward", "gold", 101)
	abandon_run.call("add_reward", "stone", 7)
	var abandon_summary := abandon_run.call("finish_run", false, &"abandon") as Dictionary
	_expect(
		int(abandon_summary.get("gold", -1)) == 0
			and (abandon_summary.get("materials", {}) as Dictionary).is_empty(),
		"Exit Combat must discard every reward collected during the current run."
	)

	_expect(bool(save.call("save_meta", TEST_SAVE_PATH, meta.call("to_dict"))), "Meta save must succeed.")
	var loaded := save.call("load_meta", TEST_SAVE_PATH) as Dictionary
	_expect(int(loaded.get("schema_version", 0)) >= 1, "Loaded saves must contain a schema version.")
	_expect(int((loaded.get("resources", {}) as Dictionary).get("autumn_core", 0)) == 1, "Boss cores must survive save/load.")
	_expect(int(loaded.get("village_level", 0)) == 2, "Village level must survive save/load.")
	_expect((loaded.get("unlocked_cards", []) as Array).has("inferno_orb"), "Unlocked cards must survive save/load.")
	_expect(
		int(((loaded.get("inventory_state", {}) as Dictionary).get("equipment_levels", {}) as Dictionary).get("iron_sword", 0)) == 2,
		"Equipment progression must survive save/load."
	)
	_expect(
		int(((loaded.get("town_state", {}) as Dictionary).get("building_levels", {}) as Dictionary).get("blacksmith", 0)) == 2,
		"Building progression must survive save/load."
	)

	var malformed_path := "user://saves/progression_state_malformed.json"
	var malformed := FileAccess.open(malformed_path, FileAccess.WRITE)
	malformed.store_string('{"resources":"invalid","settings":null}')
	malformed = null
	var recovered := save.call("load_meta", malformed_path) as Dictionary
	_expect(recovered.get("resources") is Dictionary, "Malformed nested save fields must recover to defaults.")
	_expect(recovered.get("settings") is Dictionary, "Missing or malformed settings must recover to defaults.")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(malformed_path))
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
