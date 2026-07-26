extends SceneTree

var _failures := 0


class RoutingCatalog extends RefCounted:
	func has_card(card_id: String) -> bool:
		return card_id in [
			"ember_bolt",
			"quickstep",
			"guard",
			"healing_light",
			"blood_pact",
		]


	func get_card(card_id: String) -> Dictionary:
		var cards := {
			"ember_bolt": {
				"id": "ember_bolt",
				"cost": 0,
				"play_destination": "exhaust",
				"cooldown_seconds": 99.0,
			},
			"quickstep": {
				"id": "quickstep",
				"cost": 0,
				"play_destination": "cooldown",
				"cooldown_seconds": 99.0,
			},
			"guard": {
				"id": "guard",
				"cost": 1,
				"play_destination": "cooldown",
				"cooldown_seconds": 2.0,
			},
			"healing_light": {
				"id": "healing_light",
				"cost": 1,
				"play_destination": "exhaust",
			},
			"blood_pact": {
				"id": "blood_pact",
				"cost": 1,
				"play_destination": "discard",
			},
		}
		return (cards.get(card_id, {}) as Dictionary).duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var instance_script := load("res://scripts/systems/card_instance.gd") as GDScript
	var deck_script := load("res://scripts/systems/deck_manager.gd") as GDScript
	var run_script := load("res://scripts/systems/run_state.gd") as GDScript
	_expect(instance_script != null, "CardInstance must be loadable.")
	_expect(deck_script != null, "DeckManager must be loadable.")
	_expect(run_script != null, "RunState must be loadable.")
	if instance_script == null or deck_script == null or run_script == null:
		quit(1)
		return

	var low: CardInstance = instance_script.new("guard", 1, "guard-low")
	var high: CardInstance = instance_script.new("guard", 3, "guard-high")
	_expect(low.is_valid() and high.is_valid(), "Instances must validate string IDs, card IDs, and levels.")
	_expect(
		CardInstance.from_dict(high.to_dict()).to_dict() == high.to_dict(),
		"CardInstance dictionaries must round-trip without changing identity."
	)

	var deck: DeckManager = deck_script.new(RoutingCatalog.new())
	deck.hand_size = 6
	deck.start([
		CardInstance.new("ember_bolt", 3, "fixed-ember"),
		CardInstance.new("quickstep", 2, "fixed-dash"),
		low,
		high,
		CardInstance.new("healing_light", 2, "heal-once"),
		CardInstance.new("blood_pact", 2, "blood-reuse"),
	], 9.0)
	_expect(
		deck.hand_instances[0].instance_id == "fixed-ember"
		and deck.hand_instances[0].level == 1
		and deck.hand_instances[1].instance_id == "fixed-dash"
		and deck.hand_instances[1].level == 1,
		"Exactly one stable level-one instance of each fixed card must be pinned."
	)
	var pile_instances: Array = (
		deck.hand_instances
		+ deck.draw_instances
		+ deck.discard_instances
		+ deck.exhaust_instances
	)
	var unique_ids: Dictionary = {}
	for instance in pile_instances:
		unique_ids[instance.instance_id] = true
	_expect(
		unique_ids.size() == pile_instances.size(),
		"Every runtime pile entry must have one globally unique instance ID."
	)

	var low_index := deck.find_hand_index("guard-low")
	deck.play_from_hand(low_index)
	_expect(
		deck.cooldown_pile.size() == 1
		and (deck.cooldown_pile[0].get("instance") as CardInstance).instance_id == "guard-low",
		"Cooldown routing must move the selected duplicate without flattening identity."
	)
	deck.tick_cooldowns(1.0)
	deck.set_cooldowns_paused(true)
	deck.tick_cooldowns(50.0)
	_expect(
		is_equal_approx(float(deck.cooldown_pile[0].get("remaining_seconds")), 1.0),
		"Paused cooldown clocks must not advance."
	)
	deck.set_cooldowns_paused(false)
	deck.tick_cooldowns(1.0)
	_expect(
		deck.cooldown_pile.is_empty()
		and deck.discard_instances.size() == 1
		and deck.discard_instances[0].instance_id == "guard-low"
		and deck.discard_instances[0].level == 1,
		"Cooldown completion must release the exact instance to discard."
	)

	var heal_index := deck.find_hand_index("heal-once")
	deck.play_from_hand(heal_index)
	_expect(
		deck.exhaust_instances.size() == 1
		and deck.exhaust_instances[0].instance_id == "heal-once",
		"Exhaust routing must preserve the exact played instance."
	)
	var blood_index := deck.find_hand_index("blood-reuse")
	deck.play_from_hand(blood_index)
	_expect(
		deck.discard_instances.any(func(card: CardInstance) -> bool: return card.instance_id == "blood-reuse"),
		"Discard routing must keep reusable cards in the draw cycle."
	)

	var fixed_ember_id := deck.hand_instances[0].instance_id
	deck.play_from_hand(0)
	_expect(
		deck.hand_instances[0].instance_id == fixed_ember_id
		and not deck.exhaust_instances.any(
			func(card: CardInstance) -> bool: return card.card_id == "ember_bolt"
		)
		and deck.cooldown_pile.is_empty(),
		"Fixed cards must ignore catalog exhaust/cooldown routing and retain their stable instances."
	)

	var run: RunState = run_script.new()
	run.begin_run(deck.get_all_instances())
	_expect(
		not run.upgrade_card_instance(fixed_ember_id),
		"Fixed cards must reject per-instance upgrades."
	)
	_expect(run.upgrade_card_instance("guard-low"), "A non-fixed instance below level three must upgrade.")
	_expect(
		run.get_card_instance("guard-low").level == 2
		and run.get_card_instance("guard-high").level == 3,
		"Upgrading one duplicate must not alter another duplicate."
	)
	_expect(not run.upgrade_card_instance("guard-high"), "Level-three instances must reject further upgrades.")
	var before_failed_remove := run.get_card_instance_payloads()
	_expect(
		not run.remove_card_instances(["guard-low", "missing"]),
		"Multi-instance removal must fail atomically when any target is missing."
	)
	_expect(
		run.get_card_instance_payloads() == before_failed_remove,
		"A failed atomic removal must not partially remove cards."
	)
	_expect(
		not run.remove_card_instances([fixed_ember_id]),
		"Fixed instances must reject removal."
	)

	var atomic_deck: DeckManager = deck_script.new(RoutingCatalog.new())
	atomic_deck.start([
		CardInstance.new("guard", 1, "deck-remove"),
		CardInstance.new("blood_pact", 1, "deck-keep"),
	], 5.0)
	_expect(
		not atomic_deck.remove_instances(["deck-remove", "missing"])
		and atomic_deck.find_instance("deck-remove") != null,
		"Deck removal must fail atomically without mutating any pile."
	)
	_expect(
		atomic_deck.remove_instances(["deck-remove"])
		and atomic_deck.find_instance("deck-remove") == null
		and atomic_deck.find_instance("deck-keep") != null,
		"Deck removal must target one exact non-fixed instance across all piles."
	)

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
