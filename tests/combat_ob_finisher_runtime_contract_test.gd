extends SceneTree

const STABLE_FINISHER_SEQUENCES := {
	"thousand_blade_kill": ["echo_volley", "echo_volley", "echo_volley"],
	"inferno_cremation": ["flame_imbue", "flame_imbue", "flame_imbue"],
	"thunder_prison_pierce": ["storm_charge", "storm_charge", "storm_charge"],
	"heavenly_wheel_sever": ["flame_imbue", "echo_volley", "storm_charge"],
	"frozen_burial": ["frostburst_imbue", "frostburst_imbue", "frostburst_imbue"],
}


class DamageTarget:
	extends Node2D

	var health := 1000

	func take_damage(amount: int) -> int:
		var dealt := mini(health, maxi(0, amount))
		health -= dealt
		return dealt


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := ComboFinisherCatalog.new()
	_expect(catalog.load_catalog(), "OB Finisher runtime contract requires a loadable catalog.")
	_test_stable_recipe_ids(catalog)
	_test_exact_order_matching(catalog)
	await _test_healing_and_defense_runtime(catalog)
	quit(1 if _failures > 0 else 0)


func _test_stable_recipe_ids(catalog: ComboFinisherCatalog) -> void:
	for recipe_id in STABLE_FINISHER_SEQUENCES:
		var recipe := catalog.get_recipe(recipe_id)
		_expect(not recipe.is_empty(), "Existing Finisher ID must remain stable: %s." % recipe_id)
		_expect(
			(recipe.get("sequence", []) as Array) == STABLE_FINISHER_SEQUENCES[recipe_id],
			"Stable Finisher ID must retain its canonical sequence: %s." % recipe_id
		)


func _test_exact_order_matching(catalog: ComboFinisherCatalog) -> void:
	var exact := catalog.match_sequence([
		"healing_light", "renewal", "verdant_renewal",
	])
	var wrong_order := catalog.match_sequence([
		"renewal", "healing_light", "verdant_renewal",
	])
	_expect(
		String(exact.get("name", "")) == "春庭載陽",
		"The exact Healing sequence must resolve to 春庭載陽."
	)
	_expect(wrong_order.is_empty(), "The same cards in the wrong order must not match a Finisher.")


func _test_healing_and_defense_runtime(catalog: ComboFinisherCatalog) -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"healing_light", "guard", "renewal", "verdant_renewal",
	])
	var database := game.get("card_database") as CardDatabase
	var run := game.get("run_state") as RunState
	var meta := game.get("meta_state") as MetaState
	var player := game.get("player") as Node2D
	var current_map := game.get("current_map") as Node
	for card_id in ["healing_light", "guard", "renewal", "verdant_renewal"]:
		if not meta.unlocked_cards.has(card_id):
			meta.unlocked_cards.append(card_id)
	var target := DamageTarget.new()
	target.add_to_group("Enemies")
	current_map.add_child(target)
	player.call("set_facing_direction", 1)
	target.global_position = player.global_position + Vector2(24.0, 0.0)

	_reset_formula(run)
	game.call("_record_combo_formula", database.get_card("healing_light"))
	var healing_history := run.temporary_buffs.get("combo_formula_history", []) as Array
	_expect(
		healing_history.size() == 1
			and String((healing_history[0] as Dictionary).get("id", "")) == "healing_light",
		"Healing cards must enter the same ordered three-card Finisher formula."
	)
	for _repeat in 2:
		game.call("_record_combo_formula", database.get_card("healing_light"))
	var healing_queue := run.temporary_buffs.get("finisher_queue", []) as Array
	_expect(
		healing_queue.size() == 1
			and String((healing_queue[0] as Dictionary).get("name", "")) == "朝光載陽",
		"Healing Light three times must queue 朝光載陽."
	)
	var healing_recipe := catalog.match_sequence([
		"healing_light", "healing_light", "healing_light",
	])
	_expect(
		String(healing_recipe.get("role", "")) == "healing"
			and is_zero_approx(float(
				(healing_recipe.get("base_effect", {}) as Dictionary).get("damage_scale", 1.0)
			)),
		"Healing Finishers must explicitly declare a zero-damage role."
	)
	if not healing_queue.is_empty():
		var healing_finisher := game.call(
			"_build_formula_finisher",
			database.get_card("ember_bolt")
		) as Dictionary
		var healing_effect := healing_finisher.get("effect", {}) as Dictionary
		_expect(
			int(healing_effect.get("amount", -1)) == 0
				and int(healing_effect.get("finisher_heal", 0)) > 0,
			"朝光載陽 must resolve as healing without forced Basic Attack damage."
		)
		var target_health_before := target.health
		var maximum_health := int(player.get("max_health"))
		player.set("health", maxi(1, maximum_health - 50))
		var player_health_before := int(player.get("health"))
		game.set("_auto_attack_remaining", 0.0)
		_expect(bool(game.call("_try_basic_attack")), "朝光載陽 must execute through the real automatic Finisher path.")
		_expect(target.health == target_health_before, "朝光載陽 must not damage the enemy target.")
		_expect(int(player.get("health")) > player_health_before, "朝光載陽 must actually restore player health.")

	_reset_formula(run)
	for _repeat in 3:
		game.call("_record_combo_formula", database.get_card("guard"))
	var guard_queue := run.temporary_buffs.get("finisher_queue", []) as Array
	_expect(
		guard_queue.size() == 1
			and String((guard_queue[0] as Dictionary).get("name", "")) == "靜岳無移",
		"Iron Will three times must queue 靜岳無移."
	)
	var guard_recipe := catalog.match_sequence(["guard", "guard", "guard"])
	_expect(
		String(guard_recipe.get("role", "")) == "defense"
			and is_zero_approx(float(
				(guard_recipe.get("base_effect", {}) as Dictionary).get("damage_scale", 1.0)
			)),
		"Defensive Finishers must explicitly declare a zero-damage role."
	)
	if not guard_queue.is_empty():
		var guard_finisher := game.call(
			"_build_formula_finisher",
			database.get_card("ember_bolt")
		) as Dictionary
		var guard_effect := guard_finisher.get("effect", {}) as Dictionary
		_expect(
			int(guard_effect.get("amount", -1)) == 0
				and int(guard_effect.get("finisher_guard", 0)) > 0,
			"靜岳無移 must resolve as defense without forced Basic Attack damage."
		)
		var target_health_before := target.health
		var block_before := int(player.call("get_block"))
		game.set("_auto_attack_remaining", 0.0)
		_expect(bool(game.call("_try_basic_attack")), "靜岳無移 must execute through the real automatic Finisher path.")
		_expect(target.health == target_health_before, "靜岳無移 must not damage the enemy target.")
		_expect(int(player.call("get_block")) > block_before, "靜岳無移 must actually grant player Block.")

	target.queue_free()
	game.queue_free()
	await process_frame


func _reset_formula(run: RunState) -> void:
	run.temporary_buffs["combo_formula_history"] = []
	run.temporary_buffs["finisher_queue"] = []
	run.temporary_buffs["finisher_pending"] = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
