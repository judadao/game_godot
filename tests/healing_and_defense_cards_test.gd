extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Redesigned card catalog must load.")
	var cards := database.get_all_cards()
	_expect(
		not cards.any(func(card: Dictionary) -> bool: return String(card.get("type", "")) == "defense"),
		"The defense card type must be removed from the catalog."
	)

	_expect_card(database, "guard", "Iron Will", "combo", 1, "cooldown", 8.0)
	_expect_card(database, "iron_skin", "Stone Form", "combo", 2, "cooldown", 12.0)
	_expect_card(database, "fortress_stance", "Unbreakable Stance", "combo", 4, "cooldown", 18.0)
	_expect_card(database, "stoneguard_combo", "Counterguard", "combo", 3, "cooldown", 14.0)
	_expect_card(database, "healing_light", "Healing Light", "healing", 1, "exhaust", 0.0)
	_expect_healing_card(database, "renewal")
	_expect_healing_card(database, "blood_pact_combo")
	_expect_healing_card(database, "verdant_renewal")
	var runner := CardEffectRunner.new()
	for card in cards:
		_expect(
			runner.supports_effect(String((card.get("effect", {}) as Dictionary).get("kind", ""))),
			"CardEffectRunner must support %s." % String(card.get("id", ""))
		)

	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	root.add_child(runner)
	await process_frame

	var status_controller := player.get_node_or_null("CombatStatusController")
	_expect(status_controller != null, "Player must own its CombatStatusController.")
	if status_controller != null:
		runner.cast(database.get_card("fortress_stance"), player, [])
		_expect(int(status_controller.call("get_super_armor_tier")) == 2, "Unbreakable Stance must grant strong super armor.")
		_expect(
			is_equal_approx(float(status_controller.call("get_damage_reduction")), 0.40),
			"Unbreakable Stance must grant 40 percent reduction."
		)

		player.set("health", 50)
		runner.cast(database.get_card("renewal"), player, [])
		_expect(int(player.get("health")) == 50, "Renewal Spirit must heal in pulses, not all at cast time.")
		status_controller.call("advance", 1.0)
		_expect(int(player.get("health")) > 50, "Renewal Spirit must produce a timed healing pulse.")

		player.set("health", 50)
		runner.cast(database.get_card("blood_pact_combo"), player, [])
		var restored := int(player.call("resolve_lifesteal", 40))
		_expect(restored > 0, "Blood Pact must restore health from dealt damage while active.")

		player.set("health", 100)
		var normal_damage := int(player.call("take_hit", 20, Vector2.ZERO, 0.0))
		player.call("_clear_invulnerability")
		player.set("health", 100)
		var unblockable_damage := int(player.call("take_hit", 20, Vector2.ZERO, 0.0, true))
		_expect(unblockable_damage > normal_damage, "Unblockable damage must bypass timed damage reduction.")

	runner.queue_free()
	player.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect_card(
	database: CardDatabase,
	card_id: String,
	expected_name: String,
	expected_type: String,
	expected_cost: int,
	expected_destination: String,
	expected_cooldown: float
) -> void:
	var card := database.get_card(card_id)
	_expect(not card.is_empty(), "%s must exist." % card_id)
	_expect(String(card.get("name", "")) == expected_name, "%s must use its redesigned name." % card_id)
	_expect(String(card.get("type", "")) == expected_type, "%s must use the redesigned type." % card_id)
	_expect(int(card.get("cost", -1)) == expected_cost, "%s must use the redesigned AP cost." % card_id)
	_expect(
		String(card.get("play_destination", "")) == expected_destination,
		"%s must expose its post-play destination." % card_id
	)
	_expect(
		is_equal_approx(float(card.get("cooldown_seconds", 0.0)), expected_cooldown),
		"%s must expose its cooldown." % card_id
	)


func _expect_healing_card(database: CardDatabase, card_id: String) -> void:
	var card := database.get_card(card_id)
	_expect(not card.is_empty(), "%s must exist." % card_id)
	_expect(String(card.get("type", "")) == "healing", "%s must be a green healing card." % card_id)
	_expect(String(card.get("card_color", "")) == "green", "%s must expose green presentation metadata." % card_id)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
