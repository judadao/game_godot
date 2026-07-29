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

	var forward_health := forward_target.health
	var off_axis_health := off_axis_target.health
	game.set("_auto_attack_remaining", 0.0)
	game.call("_tick_auto_attack", 0.0)
	_expect(
		forward_target.health < forward_health
			and off_axis_target.health == off_axis_health,
		"Automatic attacks must damage only targets inside the forward horizontal corridor."
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

	var database := game.get("card_database") as CardDatabase
	for card_id in ["flame_imbue", "echo_volley", "storm_charge"]:
		game.call("_record_combo_formula", database.get_card(card_id))
	var run := game.get("run_state") as RunState
	_expect(
		bool(run.temporary_buffs.get("finisher_pending", false)),
		"A learned three-Combo recipe must queue its named Finisher."
	)
	var before_finisher := forward_target.health
	var off_axis_before_finisher := off_axis_target.health
	game.set("_auto_attack_remaining", 0.0)
	game.call("_tick_auto_attack", 0.0)
	_expect(
		forward_target.health < before_finisher
			and off_axis_target.health == off_axis_before_finisher
			and not bool(run.temporary_buffs.get("finisher_pending", false)),
		"The next automatic horizontal shot must release and consume the queued Finisher."
	)

	for enemy in get_nodes_in_group("Enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame
	for card_id in ["echo_volley", "echo_volley", "echo_volley"]:
		game.call("_record_combo_formula", database.get_card(card_id))
	_expect(
		bool(run.temporary_buffs.get("finisher_pending", false)),
		"A second Finisher must queue for no-target retry coverage."
	)
	var presentation := game.get_node("SkillCastPresentation") as CanvasLayer
	var presentation_before := presentation.call("get_cast_state") as Dictionary
	var animation_before_retry: StringName = player.call("get_active_animation")
	Engine.time_scale = 1.0
	game.set("_auto_attack_remaining", 0.0)
	var fired_without_target := bool(game.call("_try_basic_attack"))
	var presentation_after := presentation.call("get_cast_state") as Dictionary
	_expect(
		not fired_without_target
			and int(presentation_after.get("generation", -1))
				== int(presentation_before.get("generation", -2))
			and is_equal_approx(Engine.time_scale, 1.0),
		"A queued Finisher with no legal target must not start or restart presentation slow motion."
	)
	_expect(
		player.call("get_active_animation") == animation_before_retry,
		"An automatic attack retry with no legal target must not start an attack animation."
	)

	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	if _failures == 0:
		print("PASS: automatic horizontal attack and formula Finisher flow")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
