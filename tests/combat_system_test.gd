extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame

	var player := map.get_node("Player")
	var zone := map.get_node("AutumnRunDirector") as EncounterDirector
	zone.start_encounter()
	var enemy := (zone.get_active_enemies() as Array)[0] as Node
	_expect(player.is_in_group("Player"), "Player must be discoverable by combat AI.")
	_expect((zone.get_active_enemies() as Array).size() >= 3, "Survival battle must open with an initial enemy group and continue replenishing it.")
	var route := map.get_node("GeneratedRoute")
	_expect(route.get_child_count() >= 24, "Combat route must instantiate all traversal chunks.")
	var previous_floor_right := 0.0
	var one_way_platform_count := 0
	for chunk_index in route.get_child_count():
		var chunk := route.get_child(chunk_index) as Node2D
		var modular_floor := chunk.get_node("ModularFloor")
		var floor_bodies := modular_floor.find_children(
			"FloorCollision*",
			"StaticBody2D",
			false,
			false
		)
		_expect(
			floor_bodies.size() >= 8,
			"Every generated chunk must assemble detailed reusable floor collisions."
		)
		_expect(
			modular_floor.find_children("TerrainCap*", "Sprite2D", false, false).size()
				== floor_bodies.size(),
			"Every floor collision must have a seamless terrain cap."
		)
		_expect(
			modular_floor.find_children("TerrainFill*", "Node2D", false, false).size()
				== floor_bodies.size(),
			"Every floor collision must have a vertical fill module."
		)
		for floor_body in floor_bodies:
			var floor_collision := floor_body.get_node("FloorShape") as CollisionShape2D
			var floor_rectangle := floor_collision.shape as RectangleShape2D
			var floor_left := (
				chunk.position.x
				+ floor_collision.position.x
				- floor_rectangle.size.x * 0.5
			)
			var floor_right := (
				chunk.position.x
				+ floor_collision.position.x
				+ floor_rectangle.size.x * 0.5
			)
			_expect(
				floor_left <= previous_floor_right + 1.0,
				"Generated floor segments must overlap instead of exposing a fall-through seam."
			)
			previous_floor_right = floor_right
		for platform in chunk.get_node("OneWayPlatforms").get_children():
			if not platform is StaticBody2D:
				continue
			var collision := platform.get_node("OneWayShape") as CollisionShape2D
			one_way_platform_count += 1
			_expect(collision.one_way_collision, "Every optional platform must allow jumping through from below.")
			_expect(
				collision.position.y < AutumnRouteChunk.FLOOR_Y,
				"Optional platforms must remain above the continuous route."
			)
	_expect(one_way_platform_count > 0, "Generated combat route must include optional platform variety.")
	_expect(map.get_node_or_null("Barriers") == null, "Forest must not contain invisible barrier bodies.")
	_expect(map.get_node_or_null("Collectibles") == null, "Legacy floating collectible art must be removed.")

	_expect(
		enemy.call("configure_archetype", &"elite"),
		"Defense verification must use a durable elite target."
	)
	var enemy_start_health := int(enemy.get("health"))
	var defense := int((enemy.get("archetype") as Resource).get("defense"))
	var applied := int(enemy.call("take_hit", 16, player.global_position, 0.0))
	_expect(applied == maxi(1, 16 - defense), "Enemy defense must reduce incoming player damage.")
	_expect(int(enemy.get("health")) == enemy_start_health - applied, "Enemy health must update after a hit.")

	_expect(not player.has_method("attack"), "Legacy basic attack must be removed in card-only combat.")
	_expect(not player.has_method("use_skill"), "Legacy mana skill must be removed in card-only combat.")

	var health_before := int(player.get("health"))
	var player_damage := int(player.call("take_hit", 12, enemy.global_position, 0.0))
	_expect(player_damage == 9, "Player defense must reduce incoming enemy damage.")
	_expect(int(player.get("health")) == health_before - player_damage, "Player health must update after enemy hit.")

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
