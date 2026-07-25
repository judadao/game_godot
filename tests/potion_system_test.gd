extends SceneTree

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var inventory := game.get("player_inventory") as Dictionary

	_expect(not game.has_method("_use_potion"), "Legacy potion combat method must be removed.")
	_expect(not InputMap.has_action("use_hp_potion"), "HP potion hotkey must be removed.")
	_expect(not InputMap.has_action("use_mp_potion"), "MP potion hotkey must be removed.")
	_expect(not inventory.has("hp_potion") and not inventory.has("mp_potion"), "New sessions must not carry legacy combat potions.")
	var hud := game.get("hud") as Control
	_expect(hud.get_node("HUDHotbar").visible == false, "Legacy potion hotbar must remain hidden.")

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
