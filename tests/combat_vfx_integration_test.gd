extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_script := load("res://scripts/managers/game.gd")
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var database := CardDatabase.new()
	_expect(game_script != null, "Game script must load for combat VFX integration.")
	_expect(game_scene != null, "Game scene must load for combat VFX integration.")
	_expect(database.load_catalog(), "Card catalog must load for combat VFX integration.")
	if game_script == null or game_scene == null:
		quit(1)
		return

	var game: Node = game_script.new()
	_expect(
		game.has_method("_resolve_combat_vfx_profile"),
		"Game must expose one pure card-to-VFX mapping authority."
	)
	if game.has_method("_resolve_combat_vfx_profile"):
		var inferno := game.call(
			"_resolve_combat_vfx_profile",
			database.get_card("inferno_orb")
		) as Dictionary
		_expect(
			String(inferno.get("element", "")) == "flame"
				and bool(inferno.get("ultimate", false))
				and float(inferno.get("radius", 0.0)) >= 180.0,
			"Inferno Orb must map to a reusable wide fire ultimate."
		)

		var frost := game.call(
			"_resolve_combat_vfx_profile",
			database.get_card("frost_bind")
		) as Dictionary
		_expect(
			String(frost.get("element", "")) == "frost"
				and bool(frost.get("ultimate", false))
				and float(frost.get("radius", 0.0)) >= 220.0,
			"Frost Bind must map to a player-centered radial freeze ultimate."
		)

		var flame_imbue := game.call(
			"_resolve_combat_vfx_profile",
			database.get_card("flame_imbue")
		) as Dictionary
		_expect(
			String(flame_imbue.get("element", "")) == "flame"
				and bool(flame_imbue.get("attack_aura", false))
				and not bool(flame_imbue.get("ultimate", false)),
			"Flame Imbue must wrap attacks without masquerading as an ultimate."
		)

	var instance := game_scene.instantiate()
	_expect(
		instance.has_node("SkillCastPresentation"),
		"Game scene must own the single screen-space cast presentation."
	)
	instance.free()
	game.free()
	Engine.time_scale = 1.0
	if _failures == 0:
		print("PASS: fire and frost combat VFX use one reusable integration path")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
