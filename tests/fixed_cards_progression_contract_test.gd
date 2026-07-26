extends SceneTree

var _failures := 0


class FailingSaveService:
	extends SaveService

	func save_meta(_path: String, _data: Dictionary) -> bool:
		return false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var valid_ids: Array[String] = []
	for card in database.get_all_cards():
		valid_ids.append(String(card.get("id", "")))

	var migrated: Array[String] = [
		"guard", "cleave", "cleave", "cleave",
		"iron_skin", "healing_light", "frost_bind", "energy_surge",
		"battle_focus", "dash_strike", "flame_imbue", "frostburst_imbue",
		"stoneguard_combo", "battle_rhythm", "ember_bolt", "quickstep",
	]
	var meta := MetaState.new()
	meta.apply_dict({"selected_deck": migrated})
	var normalized := meta.normalize_selected_deck(valid_ids)
	_expect(normalized == migrated, "Normalization must preserve a valid ordinary 16-card backpack.")
	_expect(
		meta.auto_attack_card_id == "ember_bolt",
		"Legacy saves must migrate to Ember Bolt as the default automatic attack."
	)

	var builder := (load("res://scenes/ui/DeckBuilderUI.tscn") as PackedScene).instantiate()
	root.add_child(builder)
	await process_frame
	builder.call("configure", database.get_all_cards(), migrated, "cleave")
	var restored := builder.call("get_selected_deck") as Array
	var restored_all := restored.size() == migrated.size()
	for card_id in migrated:
		restored_all = restored_all and restored.count(card_id) == migrated.count(card_id)
	_expect(
		restored_all,
		"Deck builder must restore every ordinary backpack copy."
	)
	_expect(
		String(builder.call("get_auto_attack_card_id")) == "cleave",
		"Deck builder must restore a separately equipped automatic attack."
	)
	builder.queue_free()
	await process_frame

	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var game_meta := game.get("meta_state") as MetaState
	var before_failed_loadout := game_meta.to_dict()
	game.set("save_service", FailingSaveService.new())
	var failed_deck: Array[String] = ["inferno_orb"]
	game.call(
		"_on_loadout_confirmed",
		failed_deck,
		"inferno_orb",
		null,
		"res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
		&"PlayerSpawn"
	)
	_expect(
		game_meta.to_dict() == before_failed_loadout
		and not (game.get("run_state") as RunState).active,
		"A failed loadout save must roll back Meta and keep the run in preflight."
	)
	game.set("save_service", SaveService.new())
	var illegal_deck: Array[String] = [
		"dash_strike", "dash_strike",
		"cleave", "cleave", "cleave", "cleave",
	]
	var clamped := game.call("_normalize_expedition_deck", illegal_deck) as Array
	_expect(
		clamped.count("dash_strike") == 1 and clamped.count("cleave") == 3,
		"Game normalization must enforce Combo and ordinary copy limits."
	)
	game_meta.selected_deck = migrated.duplicate()
	game_meta.auto_attack_card_id = "cleave"
	game.call("_begin_autumn_run", migrated)
	game.call(
		"load_current_map",
		load("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn") as PackedScene
	)
	await process_frame
	await process_frame

	var run := game.get("run_state") as RunState
	var deck := game.get("deck_manager") as DeckManager
	_expect(run.active, "Autumn run must start before the loadout becomes locked.")
	_expect(deck.hand.size() == 8, "Combat must randomly draw exactly eight ordinary cards.")
	_expect(deck.protected_card_ids.is_empty(), "No combat card may remain globally fixed or pinned.")
	_expect(
		String(game.get("_run_auto_attack_card_id")) == "cleave",
		"Run start must snapshot the chosen automatic attack."
	)
	game_meta.auto_attack_card_id = "inferno_orb"
	_expect(
		String(game.get("_run_auto_attack_card_id")) == "cleave",
		"Changing Meta during combat must not replace the locked automatic attack."
	)

	var player := game.get("player") as Node2D
	game.set_process(false)
	_expect(
		not bool(player.get("direct_dash_enabled")),
		"Direct Shift/controller Dash must be disabled while Dash is owned by the random card hand."
	)
	_expect(
		not InputMap.has_action("basic_attack"),
		"Automatic attacks must not retain a manual Basic Attack input authority."
	)
	var hand_ui := game.get("card_hand_ui") as Control
	_expect(
		int(hand_ui.call("get_card_button_count")) == 8,
		"Combat HUD must project all eight random cards as two switchable groups."
	)
	var targets := game.call("_get_combat_targets") as Array
	_expect(not targets.is_empty(), "The live battle must provide an automatic-attack target.")
	if not targets.is_empty():
		var target := targets[0] as Node2D
		target.global_position = player.global_position + Vector2(24, 0)
		target.set("health", 999)
		var health_before := int(target.get("health"))
		var energy_before := deck.energy
		var hand_before := deck.hand.duplicate()
		game.set("_auto_attack_remaining", 0.0)
		game.call("_process", 0.2)
		_expect(int(target.get("health")) < health_before, "Automatic attack must damage an in-range enemy.")
		_expect(is_equal_approx(deck.energy, energy_before), "Automatic attack must not spend AP.")
		_expect(deck.hand == hand_before, "Automatic attack must not mutate the eight-card hand.")
		var first_hit_health := int(target.get("health"))
		var cadence_before := float(game.get("_auto_attack_remaining"))
		Engine.time_scale = 1.0
		game.call("_process", 0.2)
		_expect(
			is_equal_approx(
				float(game.get("_auto_attack_remaining")),
				cadence_before - 0.2
			),
			"Automatic attack must respect cadence (before %.3f, after %.3f)."
			% [cadence_before, float(game.get("_auto_attack_remaining"))]
		)
		game.call("_process", 1.1)
		_expect(
			int(target.get("health")) < first_hit_health,
			"Automatic attack must fire again after its cadence expires."
		)
		target.global_position = player.global_position + Vector2(1000, 0)
		var out_of_range_health := int(target.get("health"))
		game.set("_auto_attack_remaining", 0.0)
		game.call("_process", 2.0)
		_expect(
			int(target.get("health")) == out_of_range_health,
			"Automatic attack must not hit an out-of-range enemy."
		)
		target.global_position = player.global_position + Vector2(24, 0)
		paused = true
		game.set("_auto_attack_remaining", 0.0)
		game.call("_process", 2.0)
		_expect(
			int(target.get("health")) == out_of_range_health,
			"Automatic attack must stop while the scene tree is paused."
		)
		paused = false

	var locked_deck := deck.hand.duplicate()
	var locked_map := game.get("current_map") as Node
	var combat_replacement: Array[String] = ["inferno_orb"]
	game.call(
		"_on_loadout_confirmed",
		combat_replacement,
		"inferno_orb",
		null,
		"res://scenes/maps/town/TownMap.tscn",
		&"PlayerSpawn"
	)
	_expect(
		deck.hand == locked_deck
		and game.get("current_map") == locked_map
		and String(game.get("_run_auto_attack_card_id")) == "cleave",
		"Active combat must reject loadout confirmation without mutating deck, map, or attack."
	)
	var ordered_instances: Array[CardInstance] = []
	for instance in run.card_instances:
		if instance.card_id == "quickstep":
			ordered_instances.push_front(instance)
		else:
			ordered_instances.append(instance)
	deck.start(ordered_instances, run.max_energy, false)
	var quickstep_index := deck.hand.find("quickstep")
	_expect(quickstep_index >= 0, "Deterministic ordinary hand must contain Quickstep.")
	if quickstep_index >= 0:
		var dash_origin := player.global_position
		var dash_energy := deck.energy
		game.call("_on_card_selected", quickstep_index)
		_expect(
			player.global_position != dash_origin
			and is_equal_approx(deck.energy, dash_energy - 1.0),
			"Quickstep must move the player and spend one AP through normal card play."
		)
		_expect(
			deck.hand.size() == 8 and deck.discard_pile.has("quickstep"),
			"Quickstep must enter ordinary discard routing and draw a replacement."
		)

	var quickstep := database.get_card("quickstep")
	_expect(
		String((quickstep.get("effect", {}) as Dictionary).get("kind", "")) == "dash",
		"Quickstep must remain a normal Dash card available to the random hand."
	)
	for combo_id in ["dash_strike", "gale_lunge"]:
		var effect := database.get_card(combo_id).get("effect", {}) as Dictionary
		_expect(
			String(effect.get("target_card_id", "")) == "quickstep",
			"%s must enhance the ordinary Quickstep card." % combo_id
		)
		_expect(
			not effect.has("target_fixed_card"),
			"%s must not retain the removed fixed-Dash contract." % combo_id
		)

	game.queue_free()
	Engine.time_scale = 1.0
	await process_frame
	if _failures == 0:
		print("PASS: automatic attack loadout lock and ordinary eight-card combat hand")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
