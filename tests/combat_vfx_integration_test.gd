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
			String(inferno.get("element", "")) == "fire"
				and bool(inferno.get("ultimate", false))
				and String(inferno.get("ground_trail_profile", "")) == "fire_path"
				and float(inferno.get("radius", 0.0)) >= 180.0,
			"Inferno Orb must map to a reusable wide fire ultimate and authored burning ground path."
		)

		var frost := game.call(
			"_resolve_combat_vfx_profile",
			database.get_card("frost_bind")
		) as Dictionary
		_expect(
			String(frost.get("element", "")) == "ice"
				and bool(frost.get("ultimate", false))
				and String(frost.get("ground_trail_profile", "")) == "ice_path"
				and bool(frost.get("slow_motion", false))
				and float(frost.get("radius", 0.0)) >= 220.0,
			"Frost Bind must map to a player-centered radial freeze ultimate and authored frozen ground path."
		)

		var flame_imbue := game.call(
			"_resolve_combat_vfx_profile",
			database.get_card("flame_imbue")
		) as Dictionary
		_expect(
			String(flame_imbue.get("element", "")) == "fire"
				and bool(flame_imbue.get("attack_aura", false))
				and not bool(flame_imbue.get("ultimate", false))
				and not bool(flame_imbue.get("slow_motion", true))
				and not bool(flame_imbue.get("screen_title", true)),
			"Flame Imbue must use compact player feedback without screen title or slow motion."
		)

		var storm_charge := game.call(
			"_resolve_combat_vfx_profile",
			database.get_card("storm_charge")
		) as Dictionary
		_expect(
			String(storm_charge.get("special_vfx_id", "")) == "storm_charge"
				and bool(storm_charge.get("attack_aura", false))
				and not bool(storm_charge.get("ultimate", false)),
			"Storm Charge must keep its infusion rules while routing cast feedback to the dedicated stationary VFX."
		)

		var thousand_blade := game.call(
			"_resolve_combat_vfx_profile",
			{
				"id": "thousand_blade_kill",
				"name": "千刃殺",
				"type": "attack",
				"effect": {"kind": "damage"},
				"combo_visual_profile": {"finisher": true},
			}
		) as Dictionary
		_expect(
			String(thousand_blade.get("named_vfx_id", "")) == "series:feather"
				and not bool(thousand_blade.get("ultimate", false)),
			"Named Finishers must route to their reusable series object instead of a generic elemental ultimate."
		)

		var run_state: RunState = game.get("run_state") as RunState
		run_state.temporary_buffs["persistent_combo_stacks"] = {
			"fire": 7,
			"power": 4,
		}
		var evolved_named_skill := game.call(
			"_resolve_combat_vfx_profile",
			{
				"id": "inferno_cremation",
				"name": "Inferno Cremation",
				"type": "skill",
				"card_level": 9,
				"tags": ["skill", "fire"],
				"combo_tags": ["combo", "fire", "power"],
				"effect": {"kind": "area_damage", "radius": 260},
			}
		) as Dictionary
		_expect(
			int(evolved_named_skill.get("evolution_level", 0)) == 3
				and int(evolved_named_skill.get("buff_stacks", -1)) == 7,
			"Named skill VFX must receive a clamped card evolution level and the strongest persistent tagged buff stack."
		)

		var taxonomy_profile := game.call(
			"_resolve_combat_vfx_profile",
			{
				"id": "taxonomy_probe",
				"type": "skill",
				"tags": [
					"water", "flame", "earth", "wood", "frost",
					"venom", "storm", "light", "dark", "neutral",
				],
				"effect": {"kind": "area_damage"},
			}
		) as Dictionary
		_expect(
			taxonomy_profile.get("elements", []) == [
				"water", "fire", "wind", "lightning", "ice",
				"poison", "light", "dark", "normal",
			],
			"Combat VFX must normalize compatibility aliases into the formal nine-element taxonomy."
		)
	_expect(
		game.has_method("_build_ultimate_ground_paths"),
		"Game must expose one pure authority for element-specific ultimate ground geometry."
	)
	if game.has_method("_build_ultimate_ground_paths"):
		var fire_paths := game.call(
			"_build_ultimate_ground_paths",
			"fire",
			240.0,
			Vector2.RIGHT
		) as Array
		var ice_paths := game.call(
			"_build_ultimate_ground_paths",
			"ice",
			240.0,
			Vector2.RIGHT
		) as Array
		_expect(
			fire_paths.size() == 2 and ice_paths.size() == 3,
			"Fire must leave two sweeping scars while ice branches into three frozen rifts."
		)
		_expect(
			not fire_paths.is_empty()
				and not ice_paths.is_empty()
				and fire_paths[0] != ice_paths[0],
			"Ultimate ground paths must use element-specific geometry instead of one recolored template."
		)

	var instance := game_scene.instantiate()
	_expect(
		instance.has_node("SkillCastPresentation"),
		"Game scene must own the single screen-space cast presentation."
	)
	_expect(
		instance.get("elemental_ground_trail_scene") is PackedScene,
		"Game must preload the reusable elemental ground-trail presentation scene."
	)
	_expect(
		instance.get("storm_charge_vfx_scene") is PackedScene,
		"Game must preload the dedicated stationary Storm Charge presentation scene."
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
