extends SceneTree

const INVENTORY_MANAGER_SCRIPT := preload("res://scripts/systems/inventory_manager.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var meta := MetaState.new()
	var meta_supports_unlock := _has_property(meta, "dash_upgrade_unlocked")
	_expect(meta_supports_unlock, "Meta progression must expose the Dash story unlock.")
	if meta_supports_unlock:
		_expect(not bool(meta.get("dash_upgrade_unlocked")), "Dash equipment growth must start story-locked.")
		meta.set("dash_upgrade_unlocked", true)
		var restored := MetaState.new()
		restored.apply_dict(meta.to_dict())
		_expect(bool(restored.get("dash_upgrade_unlocked")), "Dash story unlock must survive save serialization.")

	var inventory: RefCounted = INVENTORY_MANAGER_SCRIPT.new()
	_expect(inventory.has_method("set_progression_unlocks"), "Inventory must accept progression unlocks.")
	_expect(bool(inventory.call("add_equipment", &"swift_ring")), "Swift Ring must be ownable for the contract test.")
	_expect(bool(inventory.call("equip", &"swift_ring")), "Swift Ring must equip.")
	for resource_id in [&"gold", &"autumn_wood", &"magic_shard"]:
		inventory.call("set_resource_amount", resource_id, 999)
	if inventory.has_method("set_progression_unlocks"):
		inventory.call("set_progression_unlocks", {"dash_upgrade_unlocked": false})
	_expect(
		bool(inventory.call("upgrade_equipment", &"swift_ring")),
		"一般裝備的素材強化不得被可選共鳴劇情鎖住。"
	)
	_expect(
		not (inventory.call("get_special_ability_totals") as Dictionary).has("dash_distance_bonus"),
		"Locked Dash equipment bonuses must not apply."
	)
	if inventory.has_method("set_progression_unlocks"):
		inventory.call("set_progression_unlocks", {"dash_upgrade_unlocked": true})
	_expect(bool(inventory.call("upgrade_equipment", &"swift_ring")), "劇情解鎖後仍可繼續強化迅捷戒。")
	var unlocked_totals := inventory.call("get_special_ability_totals") as Dictionary
	_expect(float(unlocked_totals.get("dash_distance_bonus", 0.0)) > 0.0, "Unlocked equipment must add Dash distance.")
	_expect(float(unlocked_totals.get("dash_evasion_bonus", 0.0)) > 0.0, "Unlocked equipment must add evasion time.")

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var game_inventory := game.get("inventory_manager") as RefCounted
	game_inventory.call("add_equipment", &"swift_ring")
	game_inventory.call("equip", &"swift_ring")
	if game_inventory.has_method("set_progression_unlocks"):
		game_inventory.call("set_progression_unlocks", {"dash_upgrade_unlocked": true})
		(game.get("meta_state") as MetaState).dash_upgrade_unlocked = true
		var player := game.get("player") as Node
		var base_distance := float(player.get("dash_distance"))
		var base_evasion := float(player.get("dash_evasion_seconds"))
		game.call("_apply_intrinsic_dash_upgrades")
		_expect(
			float(player.get("dash_distance")) > base_distance,
			"Swift Ring must project equipment distance onto intrinsic Dash."
		)
		_expect(
			float(player.get("dash_evasion_seconds")) > base_evasion,
			"Swift Ring must project equipment evasion onto intrinsic Dash."
		)
	game.queue_free()
	await process_frame

	if _failures == 0:
		print("PASS: Equipment growth is material-driven while Dash ability remains story-gated")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _has_property(target: Object, property_name: String) -> bool:
	for property in target.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
