extends SceneTree

const TownManagerScript := preload("res://scripts/systems/town_manager.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town = TownManagerScript.new()
	_expect(town.is_loaded(), "Town upgrades must load with the Memory Library.")
	_expect(town.get_max_building_level(&"memory_library") == 4, "Memory Library must have four purchased upgrades.")
	_expect(town.get_skill_memory_capacity() == 10, "Unupgraded Memory Library must provide 10 memory.")
	town.apply_dict({"building_levels": {"memory_library": 1}})
	_expect(town.get_skill_memory_capacity() == 14, "Memory Library level one must provide 14 memory.")
	town.apply_dict({"building_levels": {"memory_library": 2}})
	_expect(town.get_skill_memory_capacity() == 18, "Memory Library level two must provide 18 memory.")
	town.apply_dict({"building_levels": {"memory_library": 3}})
	_expect(town.get_skill_memory_capacity() == 24, "Memory Library level three must provide 24 memory.")
	town.apply_dict({"building_levels": {"memory_library": 4}})
	_expect(town.get_skill_memory_capacity() == 30, "Memory Library level four must provide 30 memory.")
	if _failures == 0:
		print("PASS: Town Memory Library skill capacity")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
