extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (
		load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	).instantiate()
	root.add_child(map)
	await process_frame
	var player := map.get_node("Player") as CharacterBody2D
	var platform_shape := _find_one_way_platform(map.get_node("GeneratedRoute"))
	_expect(platform_shape != null, "Generated route must provide a one-way platform for drop testing.")
	if platform_shape == null:
		map.queue_free()
		quit(1)
		return

	var platform_top := platform_shape.global_position.y - 9.0
	player.global_position = Vector2(platform_shape.global_position.x + 50.0, platform_top + 30.0)
	player.velocity = Vector2.ZERO
	for _frame in 4:
		await physics_frame
	_expect(player.is_on_floor(), "Player must settle on the one-way platform before dropping.")
	var before_drop_y := player.global_position.y
	_expect(
		player.try_drop_through_platform(),
		"Pressing Down on a one-way platform must start a platform drop."
	)
	await physics_frame
	await physics_frame
	_expect(
		player.global_position.y > before_drop_y + 12.0,
		"Platform drop must move the player below the one-way surface."
	)

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _find_one_way_platform(route: Node) -> CollisionShape2D:
	for chunk in route.get_children():
		var platforms := chunk.get_node_or_null("OneWayPlatforms")
		if platforms == null:
			continue
		for body in platforms.get_children():
			if not body is StaticBody2D:
				continue
			var shape := body.get_node_or_null("OneWayShape") as CollisionShape2D
			if shape != null and shape.one_way_collision:
				return shape
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
