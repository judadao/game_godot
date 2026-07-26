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
	var floor_collision := map.get_node("WorldCollision/FloorCollision") as CollisionShape2D
	var event_ledge := map.get_node("WorldCollision/EventLookoutCollision") as CollisionShape2D
	var arena_west := map.get_node("WorldCollision/ArenaWestCollision") as CollisionShape2D
	var arena_bridge := map.get_node("WorldCollision/ArenaCenterBridgeCollision") as CollisionShape2D
	var arena_east := map.get_node("WorldCollision/ArenaEastCollision") as CollisionShape2D
	var merchant_ledge := map.get_node("WorldCollision/MerchantAwningCollision") as CollisionShape2D
	var floor_top := _shape_top(floor_collision)
	var event_top := _shape_top(event_ledge)
	var arena_west_top := _shape_top(arena_west)
	var arena_bridge_top := _shape_top(arena_bridge)
	var arena_east_top := _shape_top(arena_east)
	var merchant_top := _shape_top(merchant_ledge)
	var maximum_jump_height := pow(float(player.get("jump_velocity")), 2.0) / (2.0 * float(player.get("gravity")))
	_expect(floor_top - event_top < maximum_jump_height, "Event lookout must be reachable from ground.")
	_expect(floor_top - arena_west_top < maximum_jump_height, "Arena west platform must be reachable from ground.")
	_expect(arena_west_top - arena_bridge_top < maximum_jump_height, "Arena bridge must be reachable from the west platform.")
	_expect(floor_top - arena_east_top < maximum_jump_height, "Arena east platform must be reachable from ground.")
	_expect(floor_top - merchant_top < maximum_jump_height, "Merchant platform must be reachable from ground.")
	_expect(event_ledge.one_way_collision, "Event lookout must allow jumping through from below.")
	_expect(arena_bridge.one_way_collision and merchant_ledge.one_way_collision, "Raised platforms must be one-way.")
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


func _shape_top(collision: CollisionShape2D) -> float:
	var rectangle := collision.shape as RectangleShape2D
	return collision.position.y - rectangle.size.y * 0.5
