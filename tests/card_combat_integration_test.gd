extends SceneTree

var _failures := 0
var _selected_index := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runner_script := load("res://scripts/combat/card_effect_runner.gd")
	var hand_scene := load("res://scenes/ui/cards/CardHandUI.tscn") as PackedScene
	_expect(runner_script != null, "Card effect runner must load.")
	_expect(hand_scene != null, "Card hand UI scene must load.")
	if runner_script == null or hand_scene == null:
		quit(1)
		return

	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card database must load for combat.")
	var deck := DeckManager.new(database)
	deck.start(["ember_bolt", "guard", "cleave", "shockwave", "healing_light"], 3)
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	var enemy := (load("res://tests/fixtures/scenes/AutumnSlime.tscn") as PackedScene).instantiate()
	var second_enemy := (load("res://scenes/monsters/AutumnEnemy.tscn") as PackedScene).instantiate()
	var runner: Node = runner_script.new()
	root.add_child(player)
	root.add_child(enemy)
	root.add_child(second_enemy)
	root.add_child(runner)
	await process_frame
	_expect(runner.has_method("supports_effect"), "Card runner must declare supported effect kinds.")
	if runner.has_method("supports_effect"):
		for catalog_card in database.get_all_cards():
			var effect := catalog_card.get("effect", {}) as Dictionary
			_expect(
				bool(runner.call("supports_effect", String(effect.get("kind", "")))),
				"Card runner must support '%s' used by %s." % [effect.get("kind", ""), catalog_card.get("id", "")]
			)

	var enemy_health := int(enemy.get("health"))
	var second_health := int(second_enemy.get("health"))
	var attack_card := deck.play_from_hand(0)
	var result := runner.call("cast", attack_card, player, [enemy, second_enemy]) as Dictionary
	_expect(int(enemy.get("health")) < enemy_health, "Attack card must damage a real enemy.")
	_expect(int(second_enemy.get("health")) == second_health, "A single-target card must not damage every enemy on the map.")
	_expect(int(result.get("affected", 0)) == 1, "Card result must report affected targets.")
	_expect(deck.energy == 2, "Playing a one-cost card must spend one energy.")
	_expect(
		not deck.hand_instances.any(
			func(instance: CardInstance) -> bool: return instance.card_id == "ember_bolt"
		)
		and deck.discard_instances.any(
			func(instance: CardInstance) -> bool: return instance.card_id == "ember_bolt"
		),
		"Manual Attack cards must leave the hand and follow ordinary discard routing."
	)
	var critical_card := database.get_card("ember_bolt")
	var critical_effect := (critical_card.get("effect", {}) as Dictionary).duplicate(true)
	critical_effect["critical_chance"] = 1.0
	critical_effect["critical_multiplier"] = 2.0
	critical_card["effect"] = critical_effect
	var critical_health_before := int(second_enemy.get("health"))
	var critical_result := runner.call("cast", critical_card, player, [second_enemy]) as Dictionary
	_expect(
		bool(critical_result.get("critical", false))
			and critical_health_before - int(second_enemy.get("health")) > 12,
		"Guaranteed critical projection must deal the configured doubled damage."
	)
	_expect(
		float((second_enemy.call("get_status_snapshot") as Dictionary).get("burn_remaining", 0.0)) > 0.0,
		"Fire attacks must apply the configured Burn instead of only describing it."
	)

	var guard_index := deck.hand.find("guard")
	var guard_card := deck.play_from_hand(guard_index)
	runner.call("cast", guard_card, player, [])
	var status_controller := player.get_node("CombatStatusController") as CombatStatusController
	_expect(
		status_controller.get_super_armor_tier() >= 1
		and deck.cooldown_pile.is_empty()
		and deck.discard_pile.has("guard"),
		"Iron Will must grant timed super armor and recycle through discard."
	)
	player.set("velocity", Vector2.ZERO)
	player.call("take_hit", 10, enemy.global_position, 0.0)
	_expect(
		(player.get("velocity") as Vector2).x == 0.0,
		"Timed super armor must prevent incoming-hit knockback."
	)

	var frost_card := database.get_card("frost_bind")
	runner.call("cast", frost_card, player, [enemy, second_enemy])
	_expect(
		second_enemy.has_method("get_status_snapshot")
			and float((second_enemy.call("get_status_snapshot") as Dictionary).get("slow_remaining", 0.0)) > 0.0,
		"Glacial Dominion must apply a real timed slow to nearby enemies."
	)
	_expect(
		String(enemy.get_meta("card_status", "")) == "slow",
		"Glacial Dominion must affect multiple enemies inside its gameplay radius."
	)

	var skills := SkillRecipeManager.new()
	_expect(skills.load_catalog("res://data/skills.json"), "Passive Skill catalog must load.")
	_expect(skills.configure_loadout(["iron_momentum"], ["iron_momentum"], 10), "Initial Skill must equip.")
	for index in 4:
		_expect(skills.record_card(database.get_card("ember_bolt")).is_empty(), "Skill must wait for five attacks.")
	var fifth_attack := skills.record_card(database.get_card("inferno_orb"))
	_expect(
		fifth_attack.size() == 1
		and String(fifth_attack[0].get("id", "")) == "iron_momentum",
		"Five attack cards must trigger the visible Iron Momentum result."
	)

	var hand_ui := hand_scene.instantiate()
	root.add_child(hand_ui)
	hand_ui.connect("card_selected", _on_card_selected)
	hand_ui.call("set_cards", deck.hand.map(func(card_id: String) -> Dictionary: return database.get_card(card_id)), deck.energy)
	await process_frame
	_expect(int(hand_ui.call("get_card_button_count")) == deck.hand.size(), "Hand UI must render every card in hand.")
	hand_ui.call("select_card", 0)
	_expect(_selected_index == 0, "Hand UI selection must emit the chosen card index.")

	hand_ui.queue_free()
	runner.queue_free()
	enemy.queue_free()
	second_enemy.queue_free()
	player.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _on_card_selected(index: int) -> void:
	_selected_index = index


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
