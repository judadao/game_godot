extends SceneTree

var _failures := 0


class DamageTarget:
	extends Node2D

	var health := 500

	func take_damage(amount: int) -> int:
		var dealt := mini(health, maxi(0, amount))
		health -= dealt
		return dealt


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])
	game.set_process(false)

	_expect(
		not InputMap.has_action("basic_attack"),
		"Horizontal Basic Attack must be automatic and have no manual fire input."
	)
	_expect(
		not InputMap.has_action("attack_down"),
		"Vertical attack input must stay removed from horizontal combat."
	)

	var player := game.get("player") as Node2D
	player.call("set_facing_direction", 1)
	var horizontal := game.call("_auto_attack_direction_vector", 0, 4, 180.0) as Vector2
	_expect(
		horizontal.is_equal_approx(Vector2.RIGHT),
		"Every projectile in the battle must remain horizontal."
	)

	var current_map := game.get("current_map") as Node
	var forward_target := DamageTarget.new()
	forward_target.add_to_group("Enemies")
	current_map.add_child(forward_target)
	forward_target.global_position = player.global_position + Vector2(100.0, 0.0)
	var off_axis_target := DamageTarget.new()
	off_axis_target.add_to_group("Enemies")
	current_map.add_child(off_axis_target)
	off_axis_target.global_position = player.global_position + Vector2(100.0, 100.0)
	var middle_target := DamageTarget.new()
	middle_target.add_to_group("Enemies")
	current_map.add_child(middle_target)
	middle_target.global_position = player.global_position + Vector2(170.0, 0.0)
	var far_target := DamageTarget.new()
	far_target.add_to_group("Enemies")
	current_map.add_child(far_target)
	far_target.global_position = player.global_position + Vector2(240.0, 0.0)

	var forward_health := forward_target.health
	var off_axis_health := off_axis_target.health
	var middle_health := middle_target.health
	var far_health := far_target.health
	game.set("_auto_attack_remaining", 0.0)
	game.call("_tick_auto_attack", 0.0)
	_expect(
		forward_target.health < forward_health
			and middle_target.health < middle_health
			and far_target.health < far_health
			and off_axis_target.health == off_axis_health,
		"A visible sword wave must pierce every enemy along its forward corridor without hitting off-axis targets."
	)
	_expect(
		player.call("get_active_animation") == &"attack",
		"A successful automatic attack must play the player attack animation."
	)
	player.call("_update_character_animation", 0.6)
	_expect(
		player.call("get_active_animation") != &"attack",
		"Attack animation must return to the current movement animation after one cycle."
	)
	var health_after_first := forward_target.health
	game.call("_tick_auto_attack", 0.01)
	_expect(
		forward_target.health == health_after_first,
		"Automatic fire must respect its cooldown."
	)
	game.call("_tick_auto_attack", 5.0)
	_expect(
		forward_target.health < health_after_first,
		"Automatic fire must repeat after its cooldown while a horizontal target exists."
	)
	forward_target.queue_free()
	off_axis_target.queue_free()
	middle_target.queue_free()
	far_target.queue_free()
	await process_frame

	var run := game.get("run_state") as RunState
	run.temporary_buffs["combo_chain_count"] = 12
	var widened_target := DamageTarget.new()
	widened_target.add_to_group("Enemies")
	current_map.add_child(widened_target)
	widened_target.global_position = player.global_position + Vector2(160.0, 40.0)
	var widened_health := widened_target.health
	game.set("_auto_attack_remaining", 0.0)
	game.call("_tick_auto_attack", 0.0)
	_expect(
		widened_target.health < widened_health,
		"A target visibly swept by a doubled Combo attack must take damage in the full automatic-fire flow."
	)
	widened_target.queue_free()
	await process_frame
	run.temporary_buffs["combo_chain_count"] = 0

	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	if _failures == 0:
		print("PASS: automatic horizontal attack cadence, corridor, and Combo width")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
