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
	player.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
