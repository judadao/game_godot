extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory_script := load("res://scripts/systems/inventory_manager.gd")
	var town_script := load("res://scripts/systems/town_manager.gd")
	_expect(inventory_script != null and town_script != null, "Memory Library requires town and inventory services.")
	if inventory_script == null or town_script == null:
		quit(1)
		return
	var inventory: RefCounted = inventory_script.new()
	for resource_id in inventory.call("get_resource_ids") as Array:
		inventory.call("add_resource", resource_id, 1000)
	var town: RefCounted = town_script.new(inventory)
	_expect(town.has_method("get_memory_capacity"), "Town must project Memory Library capacity.")
	_expect(town.has_method("upgrade_memory_library"), "Town must validate Memory Library purchases.")
	if not town.has_method("get_memory_capacity"):
		quit(1)
		return
	var capacities := [10, 14, 18, 24, 30]
	for expected_capacity in capacities:
		_expect(
			int(town.call("get_memory_capacity")) == expected_capacity,
			"Memory Library capacity must follow 10, 14, 18, 24, 30."
		)
		if expected_capacity != 30:
			_expect(bool(town.call("upgrade_memory_library")), "An affordable Memory Library upgrade must succeed.")
	_expect(not bool(town.call("upgrade_memory_library")), "Memory Library upgrades must stop at maximum capacity.")
	var saved := town.call("to_dict") as Dictionary
	var restored: RefCounted = town_script.new(inventory)
	restored.call("apply_dict", saved)
	_expect(int(restored.call("get_memory_capacity")) == 30, "Memory Library progress must survive town serialization.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
