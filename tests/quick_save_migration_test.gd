extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var player := game.get("player") as Node
	var health_before := int(player.get("health"))
	_expect(
		bool(game.call("_apply_quick_save_payload", {
			"wallet_gold": 7,
			"inventory": "legacy-invalid",
			"merchant_catalogs": [],
			"player": "legacy-invalid",
		})),
		"Malformed legacy nested fields must be sanitized without aborting load."
	)
	_expect(game.get("player_inventory") is Dictionary, "Malformed legacy inventory must preserve safe defaults.")
	_expect(int(player.get("health")) == health_before, "Malformed legacy player data must preserve current stats.")
	_expect(
		bool(game.call("_apply_quick_save_payload", {
			"player": {"health": 55, "position": "legacy-invalid"},
		})),
		"Malformed legacy position must not block valid player fields."
	)
	_expect(int(player.get("health")) == 55, "Valid legacy player fields must still migrate.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
