extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	var enemy := (load("res://scenes/monsters/AutumnEnemy.tscn") as PackedScene).instantiate()
	root.add_child(player)
	root.add_child(enemy)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(40.0, 0.0)
	await process_frame
	enemy.set("target", player)

	var health_before := int(player.get("health"))
	enemy.call("_begin_attack")
	await process_frame
	var feedback := enemy.get_node_or_null("AttackFeedback")
	_expect(feedback != null, "Every damaging enemy must own visible attack feedback.")
	_expect(
		feedback != null and bool(feedback.call("is_telegraph_visible")),
		"Enemy damage must show its range during the entire wind-up."
	)
	_expect(int(player.get("health")) == health_before, "Telegraph wind-up must not deal invisible early damage.")

	var telegraph_time := float((enemy.get("archetype") as Resource).get("telegraph_time"))
	await create_timer(telegraph_time + 0.03).timeout
	_expect(int(player.get("health")) < health_before, "The visible enemy attack must resolve after its telegraph.")
	_expect(
		feedback != null and bool(feedback.call("is_impact_visible")),
		"Enemy attack resolution must show a visible impact even when several enemies overlap."
	)
	player.call("_clear_invulnerability")
	var health_after_visible_hit := int(player.get("health"))
	player.global_position = enemy.global_position + Vector2(-40.0, 0.0)
	enemy.call("_begin_attack")
	await process_frame
	player.global_position = enemy.global_position + Vector2(40.0, 0.0)
	await create_timer(telegraph_time + 0.03).timeout
	_expect(
		int(player.get("health")) == health_after_visible_hit,
		"Moving behind the displayed attack area must evade damage instead of receiving an invisible radial hit."
	)

	enemy.queue_free()
	player.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
