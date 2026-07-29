extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/combat/ExperienceGem.tscn") as PackedScene
	_expect(scene != null, "Experience gem scene must exist.")
	if scene == null:
		quit(1)
		return
	var player := Node2D.new()
	player.add_to_group("Player")
	player.position = Vector2(80, 0)
	root.add_child(player)
	var gem := scene.instantiate()
	root.add_child(gem)
	gem.call("configure", 37, player)
	var collected: Array[int] = []
	gem.connect("collected", func(value: int) -> void: collected.append(value))
	var start_x := (gem as Node2D).position.x
	gem.call("advance_pickup", 0.1)
	_expect((gem as Node2D).position.x > start_x, "Nearby gem must move toward the player.")
	gem.call("collect")
	gem.call("collect")
	_expect(collected == [37], "Experience gem must emit its exact value only once.")
	gem.queue_free()

	var burst_gem := scene.instantiate()
	root.add_child(burst_gem)
	burst_gem.call("configure", 2, player)
	_expect(
		burst_gem.has_method("launch"),
		"Experience gems need a short launch burst so area kills visibly spill many rewards."
	)
	if burst_gem.has_method("launch"):
		burst_gem.call("launch", Vector2(-120.0, -160.0), 0.25)
		var burst_start := (burst_gem as Node2D).position
		burst_gem.call("advance_pickup", 0.1)
		_expect(
			(burst_gem as Node2D).position.x < burst_start.x
				and (burst_gem as Node2D).position.y < burst_start.y,
			"A launched XP gem must scatter before attraction takes over."
		)
	burst_gem.queue_free()

	var collision_player := CharacterBody2D.new()
	collision_player.add_to_group("Player")
	collision_player.collision_layer = 1
	var player_shape := CollisionShape2D.new()
	var player_rectangle := RectangleShape2D.new()
	player_rectangle.size = Vector2(32, 64)
	player_shape.shape = player_rectangle
	collision_player.add_child(player_shape)
	root.add_child(collision_player)
	var collision_gem := scene.instantiate()
	collision_gem.set_physics_process(false)
	root.add_child(collision_gem)
	collision_gem.call("configure", 9, collision_player)
	var collision_collected: Array[int] = []
	collision_gem.connect("collected", func(value: int) -> void: collision_collected.append(value))
	await physics_frame
	await process_frame
	_expect(
		collision_collected == [9],
		"Physics body entry must collect once without mutating Area state inside the signal."
	)
	collision_player.queue_free()
	player.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
