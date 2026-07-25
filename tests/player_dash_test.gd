extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(InputMap.has_action("dash"), "Project must define a dash input action.")
	_expect(InputMap.has_action("card_focus"), "Project must define tactical card-focus input.")
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	_expect(player.has_method("try_dash"), "Player must expose dash behavior.")
	if not player.has_method("try_dash"):
		player.queue_free()
		await process_frame
		quit(1)
		return
	var start: Vector2 = player.global_position
	_expect(bool(player.call("try_dash", 1)), "Ready player must be able to dash.")
	_expect(player.global_position.x > start.x, "Dash must move the player in the requested direction.")
	_expect(not bool(player.call("try_dash", 1)), "Dash cooldown must prevent immediate repeated dashes.")
	player.call("_tick_dash_cooldown", float(player.get("dash_cooldown")))
	_expect(bool(player.call("try_dash", -1)), "Dash must become available after cooldown.")
	_expect(player.get("facing_direction") == -1, "Dash direction must update facing.")
	var defeat_events: Array[bool] = []
	player.defeated.connect(func() -> void: defeat_events.append(true))
	player.call("take_damage", 99999)
	_expect(defeat_events.size() == 1, "Direct card self-damage must emit defeat exactly once at zero health.")
	player.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
