extends SceneTree

var _failures := 0
var _triggered: Array[String] = []
var _discovered: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager_script := load("res://scripts/systems/skill_recipe_manager.gd")
	_expect(manager_script != null, "Skill recipes require a runtime manager.")
	_expect(ResourceLoader.exists("res://data/skills.json"), "Skill recipes require an authored catalog.")
	if manager_script == null:
		quit(1)
		return

	var manager: RefCounted = manager_script.new()
	_expect(bool(manager.call("is_loaded")), "The authored skill catalog must validate and load.")
	manager.connect("skill_triggered", _on_skill_triggered)
	manager.connect("skill_discovered", _on_skill_discovered)

	_expect(
		bool(manager.call("is_learned", &"iron_momentum")),
		"A new profile must begin with Iron Momentum learned."
	)
	_expect(
		bool(manager.call("set_active_loadout", [&"iron_momentum"], true)),
		"A learned skill must be equipable in a safe area."
	)
	_expect(
		not bool(manager.call("set_active_loadout", [], false)),
		"Skill loadouts must not be editable outside a safe area."
	)
	var empty_restore: RefCounted = manager_script.new()
	empty_restore.call("apply_dict", {})
	_expect(
		bool(empty_restore.call("is_learned", &"iron_momentum")),
		"Restoring a profile without saved skill state must seed Iron Momentum."
	)
	_expect(bool(manager.call("learn_skill", &"ember_crescendo")), "The exact recipe fixture must be learnable.")
	_expect(
		bool(manager.call("set_active_loadout", [&"iron_momentum", &"ember_crescendo"], true)),
		"Two learned skills must be equipable before serialization."
	)
	var round_trip: RefCounted = manager_script.new()
	round_trip.call("apply_dict", manager.call("to_dict"))
	_expect(
		bool(round_trip.call("is_learned", &"iron_momentum"))
		and bool(round_trip.call("is_learned", &"ember_crescendo")),
		"Learned skills must survive manager serialization."
	)
	_expect(
		round_trip.call("get_active_skill_ids") == [&"iron_momentum", &"ember_crescendo"],
		"The active skill loadout must survive manager serialization."
	)
	manager.call("set_active_loadout", [&"iron_momentum"], true)

	for index in 5:
		manager.call("record_successful_attack", &"ember_bolt", float(index))
	_expect(
		_triggered.count("iron_momentum") == 1,
		"Five successful attacks inside the refreshed window must trigger Iron Momentum once."
	)
	var ignored_non_attack := manager.call("record_successful_attack", &"quickstep", 5.0) as Array
	_expect(ignored_non_attack.is_empty(), "Non-attack cards must never contribute a successful attack event.")

	manager.call("advance_time", 10.0)
	for index in 4:
		manager.call("record_successful_attack", &"cleave", 20.0 + float(index))
	manager.call("record_successful_attack", &"cleave", 33.1)
	_expect(
		_triggered.count("iron_momentum") == 1,
		"A count recipe must reset after its refreshed window expires."
	)
	manager.call("record_successful_attack", &"cleave", 34.0)
	manager.call("record_successful_attack", &"cleave", 35.0)
	manager.call("record_successful_attack", &"cleave", 36.0)
	manager.call("record_successful_attack", &"cleave", 37.0)
	_expect(
		_triggered.count("iron_momentum") == 2,
		"A count recipe must refresh its window after every successful attack."
	)

	_expect(
		bool(manager.call("set_active_loadout", [&"ember_crescendo"], true)),
		"An exact recipe must be equipable when learned."
	)
	manager.call("record_successful_attack", &"ember_bolt", 50.0)
	manager.call("record_successful_attack", &"cleave", 51.0)
	manager.call("record_successful_attack", &"ember_bolt", 52.0)
	_expect(_triggered.count("ember_crescendo") == 1, "A matching exact attack sequence must trigger its skill.")
	manager.call("record_successful_attack", &"ember_bolt", 53.0)
	manager.call("record_successful_attack", &"inferno_orb", 54.0)
	manager.call("record_successful_attack", &"ember_bolt", 55.0)
	_expect(_triggered.count("ember_crescendo") == 1, "A wrong attack must reset an exact recipe.")
	manager.call("record_successful_attack", &"ember_bolt", 56.0)
	manager.call("record_played_non_attack")
	manager.call("record_successful_attack", &"cleave", 57.0)
	manager.call("record_successful_attack", &"ember_bolt", 58.0)
	_expect(_triggered.count("ember_crescendo") == 1, "A successful non-attack must reset exact recipe progress.")
	manager.call("advance_time", 6.0)
	manager.call("record_successful_attack", &"ember_bolt", 59.0)
	manager.call("record_successful_attack", &"ember_bolt", 60.0)
	manager.call("record_successful_attack", &"cleave", 61.0)
	manager.call("record_successful_attack", &"ember_bolt", 62.0)
	_expect(
		_triggered.count("ember_crescendo") == 2,
		"A mismatch matching step one must restart an exact recipe at step one."
	)

	manager.call("record_successful_attack", &"inferno_orb", 70.0)
	manager.call("record_successful_attack", &"cleave", 71.0)
	_expect(_discovered.count("hidden_flame") == 1, "Hidden discovery must emit once.")
	_expect(bool(manager.call("is_learned", &"hidden_flame")), "Discovered skills must join the learned set.")
	_expect(bool(manager.call("learn_skill", &"combustion_loop")), "Parallel recipe fixture must be learnable.")
	_expect(
		bool(manager.call("set_active_loadout", [&"iron_momentum", &"combustion_loop"], true)),
		"Parallel recipes must fit in the starting memory capacity."
	)
	manager.call("advance_time", 10.0)
	for index in 5:
		manager.call("record_successful_attack", &"ember_bolt", 80.0 + float(index))
	_expect(
		_triggered.count("iron_momentum") == 3 and _triggered.count("combustion_loop") == 1,
		"One attack event must trigger every completed parallel recipe."
	)
	manager.call("advance_time", 10.0)
	for index in 5:
		manager.call("record_successful_attack", &"ember_bolt", 100.0 + float(index))
	_expect(
		_triggered.count("iron_momentum") == 4 and _triggered.count("combustion_loop") == 2,
		"Each skill cooldown must expire independently without consuming other recipe progress."
	)
	var invalid_path := "user://invalid_skill_recipe.json"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string('{"skills":[{"id":"invalid","name":"Invalid","memory_cost":1,"hidden":false,"recipe":{"kind":"exact","steps":["quickstep"]},"effect":{"kind":"noop"},"cooldown_seconds":0}]}')
	invalid_file.close()
	var invalid_manager: RefCounted = manager_script.new(invalid_path)
	_expect(not bool(invalid_manager.call("is_loaded")), "Catalog validation must reject non-attack recipe steps.")
	DirAccess.remove_absolute(invalid_path)
	quit(0 if _failures == 0 else 1)


func _on_skill_triggered(skill_id: StringName, _effect: Dictionary) -> void:
	_triggered.append(String(skill_id))


func _on_skill_discovered(skill_id: StringName) -> void:
	_discovered.append(String(skill_id))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
