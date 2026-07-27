extends SceneTree

var _failures := 0


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
	var deck := game.get("deck_manager") as DeckManager
	var hand_before := deck.hand.duplicate()
	var energy_before := deck.energy
	game.set_process(false)
	for _step in 10:
		game.call("_process", 1.0)
	_expect(
		deck.hand == hand_before and is_equal_approx(deck.energy, energy_before),
		"Combat processing must never auto-play Combo or Healing skills."
	)
	_expect(
		not game.has_method("_tick_auto_use")
			and not game.has_method("_choose_auto_use_card_index"),
		"Removed Auto Use strategy must not remain reachable in Game."
	)
	var hud := (
		load("res://scenes/ui/autumn/AutumnHUD.tscn") as PackedScene
	).instantiate() as Control
	root.add_child(hud)
	await process_frame
	var toggle := hud.get_node(
		"BottomStage/CardStage/ActionStrip/AutoUse"
	) as Control
	_expect(
		toggle != null and not toggle.visible,
		"The combat HUD must not expose an Auto Use control."
	)

	hud.queue_free()
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: fixed skills remain manual and Auto Use is unreachable")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
