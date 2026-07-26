extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "The production card catalog must load.")

	var deck := DeckManager.new(database)
	deck.hand_size = 5
	deck.start([
		CardInstance.new("ember_bolt", 1, "fixed-ember"),
		CardInstance.new("quickstep", 1, "fixed-dash"),
		CardInstance.new("flame_imbue", 2, "flame-two"),
		CardInstance.new("guard", 1, "guard-one"),
		CardInstance.new("healing_light", 1, "heal-one"),
	], 10.0)

	var flame := deck.play_from_hand(deck.find_hand_index("flame-two"))
	_expect(
		deck.exhaust_instances.any(
			func(instance: CardInstance) -> bool: return instance.instance_id == "flame-two"
		),
		"Legacy infusion Combo cards must retain their exhaust-on-play lifecycle."
	)

	var caster := Node.new()
	root.add_child(caster)
	var runner := CardEffectRunner.new()
	root.add_child(runner)
	var cast_result := runner.cast(flame, caster, [])
	_expect(
		String(cast_result.get("instance_id", "")) == "flame-two"
		and int(cast_result.get("card_level", 0)) == 2,
		"CardEffectRunner results must preserve the exact card instance identity and level."
	)
	_expect(
		String(cast_result.get("play_destination", "")) == "exhaust"
		and is_zero_approx(float(cast_result.get("cooldown_seconds", -1.0))),
		"CardEffectRunner results must preserve the authoritative post-play routing metadata."
	)

	var guard := deck.play_from_hand(deck.find_hand_index("guard-one"))
	_expect(
		not guard.is_empty()
		and deck.cooldown_pile.size() == 1
		and String(guard.get("instance_id", "")) == "guard-one",
		"Timed Combo cards must enter cooldown without flattening instance identity."
	)
	deck.set_cooldowns_paused(true)
	var remaining_before := float(deck.cooldown_pile[0].get("remaining_seconds", 0.0))
	deck.tick_cooldowns(999.0)
	_expect(
		is_equal_approx(
			float(deck.cooldown_pile[0].get("remaining_seconds", 0.0)),
			remaining_before
		),
		"Paused cooldown clocks must remain frozen at the production catalog boundary."
	)

	var reward_instance := CardInstance.new("cleave", 2, "reward-cleave")
	var has_deck_insertion := deck.has_method("add_existing_instance")
	_expect(
		has_deck_insertion,
		"DeckManager must expose validated existing-instance insertion."
	)
	if has_deck_insertion:
		_expect(
			bool(deck.call("add_existing_instance", reward_instance)),
			"DeckManager must accept a validated existing reward instance."
		)
		_expect(
			is_same(deck.find_instance("reward-cleave"), reward_instance),
			"Adding a reward must preserve the RunState-owned object instead of creating a copy."
		)
		_expect(
			not bool(deck.call("add_existing_instance", reward_instance))
			and bool(deck.call(
				"add_existing_instance",
				CardInstance.new("ember_bolt", 1, "illegal-fixed")
			)),
			"Existing-instance insertion must reject duplicate IDs but accept ordinary attacks."
		)

	var run := RunState.new()
	run.begin_run([])
	var has_run_insertion := run.has_method("add_existing_card_instance")
	_expect(
		has_run_insertion,
		"RunState must expose validated existing-instance insertion."
	)
	if has_run_insertion:
		_expect(
			bool(run.call("add_existing_card_instance", reward_instance)),
			"RunState must accept the MetaState-owned reward instance."
		)
		_expect(
			is_same(run.get_card_instance("reward-cleave"), reward_instance)
			and is_same(deck.find_instance("reward-cleave"), reward_instance),
			"MetaState, RunState, and DeckManager integration must be able to share one object."
		)
		_expect(
			not bool(run.call("add_existing_card_instance", reward_instance))
			and bool(run.call(
				"add_existing_card_instance",
				CardInstance.new("quickstep", 1, "illegal-run-fixed")
			)),
			"RunState existing-instance insertion must reject duplicate IDs but accept ordinary Dash cards."
		)

	var meta := MetaState.new()
	meta.apply_dict({
		"schema_version": 3,
		"selected_card_instances": [
			{"instance_id": "ember-a", "card_id": "ember_bolt", "level": 1},
			{"instance_id": "ember-b", "card_id": "ember_bolt", "level": 1},
			{"instance_id": "dash-a", "card_id": "quickstep", "level": 1},
			{"instance_id": "dash-b", "card_id": "quickstep", "level": 1},
			{"instance_id": "guard-a", "card_id": "guard", "level": 2},
		],
	})
	var payloads := meta.get_selected_card_payloads()
	_expect(
		_count_card(payloads, "ember_bolt") == 2
		and _count_card(payloads, "quickstep") == 2,
		"Modern saves must retain duplicate ordinary Attack and Dash instances."
	)
	_expect(
		payloads.any(
			func(payload: Dictionary) -> bool: return (
				String(payload.get("instance_id", "")) == "guard-a"
				and int(payload.get("level", 0)) == 2
			)
		),
		"Ordinary-card migration must not alter unrelated card identity or levels."
	)

	runner.queue_free()
	caster.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _count_card(payloads: Array[Dictionary], card_id: String) -> int:
	var count := 0
	for payload in payloads:
		if String(payload.get("card_id", "")) == card_id:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
