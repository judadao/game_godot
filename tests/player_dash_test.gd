extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(InputMap.has_action("dash"), "Project must define a dash input action.")
	_expect(_has_physical_key("dash", KEY_SPACE), "Dash must be bound to Space.")
	_expect(not _has_physical_key("jump", KEY_SPACE), "Space must not also trigger Jump.")
	_expect(_has_physical_key("jump", KEY_UP), "Jump must be bound to the Up arrow.")
	_expect(InputMap.has_action("move_down"), "Project must define platform drop input.")
	_expect(_has_physical_key("move_down", KEY_DOWN), "Platform drop must be bound to the Down arrow.")
	_expect(InputMap.has_action("card_focus"), "Project must define tactical card-focus input.")
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	_expect(player.has_method("try_dash"), "Player must expose dash behavior.")
	_expect(player.has_method("try_drop_through_platform"), "Player must expose one-way platform drop behavior.")
	if not player.has_method("try_dash"):
		player.queue_free()
		await process_frame
		quit(1)
		return
	var start: Vector2 = player.global_position
	var original_collision_layer: int = player.collision_layer
	_expect(bool(player.call("try_dash", 1)), "Ready player must be able to dash.")
	_expect(bool(player.call("is_invulnerable")), "Dash must grant invulnerability immediately.")
	_expect(player.collision_layer == 0, "Dash must temporarily phase through enemy body collisions.")
	player.call("_advance_dash", float(player.get("dash_duration")))
	_expect(player.global_position.x > start.x, "Dash must move the player in the requested direction.")
	_expect(player.collision_layer == original_collision_layer, "Dash must restore the player collision layer after movement.")
	_expect(bool(player.call("is_invulnerable")), "Post-dash evasion must remain active after movement ends.")
	player.call("grant_invulnerability", 0.8)
	player.call("grant_invulnerability", 0.1)
	player.call("_tick_invulnerability", 0.2)
	_expect(bool(player.call("is_invulnerable")), "A shorter evasion source must not cancel a longer invulnerability window.")
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


func _has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false
