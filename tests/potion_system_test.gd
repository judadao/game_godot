extends SceneTree

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var player: Node = game.get("player")
	var inventory := game.get("player_inventory") as Dictionary

	_expect(int(player.get("health")) == 78, "Player should start with configured health.")
	_expect(bool(game.call("_use_potion", "hp_potion")), "Health potion should work below max HP.")
	_expect(int(player.get("health")) == 100, "Health potion must clamp healing to max HP.")
	_expect(int(inventory.get("hp_potion", 0)) == 1, "Successful healing must consume one potion.")
	_expect(not bool(game.call("_use_potion", "hp_potion")), "Potion must not be consumed at full HP.")
	_expect(int(inventory.get("hp_potion", 0)) == 1, "No-effect use must preserve potion quantity.")

	_expect(bool(game.call("_use_potion", "mp_potion")), "Mana potion should work below max MP.")
	_expect(int(player.get("mana")) == 50, "Mana potion must clamp restoration to max MP.")
	_expect(int(inventory.get("mp_potion", 0)) == 1, "Successful mana restoration must consume one potion.")

	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
