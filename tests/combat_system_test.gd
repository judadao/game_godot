extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load("res://scenes/maps/autumn_forest.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame

	var player := map.get_node("Player")
	var zone := map.get_node("AutumnRunDirector") as EncounterDirector
	zone.start_encounter()
	var enemy := (zone.get_active_enemies() as Array)[0] as Node
	_expect(player.is_in_group("Player"), "Player must be discoverable by combat AI.")
	_expect((zone.get_active_enemies() as Array).size() >= 3, "Survival battle must open with an initial enemy group and continue replenishing it.")
	var floor_collision := map.get_node("WorldCollision/FloorCollision") as CollisionShape2D
	var west_ledge := map.get_node("WorldCollision/WestLowCollision") as CollisionShape2D
	var west_high := map.get_node("WorldCollision/WestHighCollision") as CollisionShape2D
	var arena_low := map.get_node("WorldCollision/ArenaLowCollision") as CollisionShape2D
	var arena_high := map.get_node("WorldCollision/ArenaHighCollision") as CollisionShape2D
	var east_mid := map.get_node("WorldCollision/EastMidCollision") as CollisionShape2D
	var floor_top := floor_collision.position.y - 30.0
	var west_top := west_ledge.position.y - 12.0
	var west_high_top := west_high.position.y - 9.0
	var arena_low_top := arena_low.position.y - 9.0
	var arena_high_top := arena_high.position.y - 9.0
	var east_mid_top := east_mid.position.y - 9.0
	var bridge_ledge := map.get_node("WorldCollision/EastBridgeCollision") as CollisionShape2D
	var bridge_top := bridge_ledge.position.y - 12.0
	var maximum_jump_height := pow(float(player.get("jump_velocity")), 2.0) / (2.0 * float(player.get("gravity")))
	_expect(floor_top - west_top < maximum_jump_height, "First forest platform must be reachable from ground.")
	_expect(west_top - west_high_top < maximum_jump_height, "West high platform must be reachable from west low.")
	_expect(floor_top - arena_low_top < maximum_jump_height, "Arena low platform must be reachable from ground.")
	_expect(arena_low_top - arena_high_top < maximum_jump_height, "Arena high platform must be reachable from arena low.")
	_expect(floor_top - east_mid_top < maximum_jump_height, "East middle platform must be reachable from ground.")
	_expect(floor_top - bridge_top < maximum_jump_height, "Bridge platform must be reachable from ground.")
	_expect(west_ledge.one_way_collision, "First forest platform must allow jumping through from below.")
	_expect(west_high.one_way_collision and arena_high.one_way_collision, "High platforms must be one-way.")
	_expect(map.get_node_or_null("Barriers") == null, "Forest must not contain invisible barrier bodies.")
	_expect(map.get_node_or_null("Collectibles") == null, "Legacy floating collectible art must be removed.")

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
