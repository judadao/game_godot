extends SceneTree

var _failures := 0


class CooldownDatabase extends RefCounted:
	func has_card(card_id: String) -> bool:
		return card_id in ["ember_bolt", "quickstep", "guard", "cooling_guard"]


	func get_card(card_id: String) -> Dictionary:
		if not has_card(card_id):
			return {}
		return {
			"id": card_id,
			"cost": 0,
			"type": "attack",
			"cooldown": 2.0 if card_id == "cooling_guard" else 0.0,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var instance_script := load("res://scripts/systems/card_instance.gd") as GDScript
	var deck_script := load("res://scripts/systems/deck_manager.gd") as GDScript
	_expect(instance_script != null, "CardInstance must provide validated instance values.")
	_expect(deck_script != null, "DeckManager must load for instance-pile coverage.")
	if instance_script == null or deck_script == null:
		quit(1)
		return

	var low_level: Variant = instance_script.new("guard", 1, 101)
	var high_level: Variant = instance_script.new("guard", 3, 102)
	_expect(
		low_level.call("to_dict") == {"instance_id": 101, "card_id": "guard", "level": 1},
		"CardInstance serialization must preserve a hand-checked instance payload."
	)
	var restored: Variant = instance_script.call("from_dict", high_level.call("to_dict"))
	_expect(restored != null and restored.call("to_dict") == high_level.call("to_dict"), "CardInstance deserialization must round-trip exactly.")
	var allocated_after_restore: Variant = instance_script.new("guard")
	_expect(int(allocated_after_restore.get("instance_id")) > 102, "Instance IDs allocated after restoration must increase monotonically.")

	var deck: RefCounted = deck_script.new(CooldownDatabase.new())
	deck.set("hand_size", 2)
	deck.call("start", [low_level.call("to_dict"), high_level.call("to_dict")], 5.0)
	var opening_hand := deck.get("hand_instances") as Array
	_expect(opening_hand.size() == 2, "Both duplicate card IDs must enter the deck as separate instances.")
	_expect(
		int((opening_hand[0] as Dictionary).get("instance_id", 0)) == 101
		and int((opening_hand[1] as Dictionary).get("instance_id", 0)) == 102
		and int((opening_hand[0] as Dictionary).get("level", 0)) == 1
		and int((opening_hand[1] as Dictionary).get("level", 0)) == 3,
		"Duplicate card IDs must retain distinct IDs and levels while drawn into hand."
	)
	deck.call("play_from_hand", 0)
	var discard := deck.get("discard_instances") as Array
	_expect(
		discard.size() == 1 and int((discard[0] as Dictionary).get("instance_id", 0)) == 101,
		"Playing one duplicate must move only that exact instance to discard."
	)

	deck.call("set_protected_cards", ["ember_bolt", "quickstep"])
	deck.set("hand_size", 4)
	deck.call("start", ["guard", "ember_bolt", "quickstep", "guard"], 5.0, true)
	var protected_hand := deck.get("hand_instances") as Array
	var ember_instance := protected_hand[0] as Dictionary
	var quickstep_instance := protected_hand[1] as Dictionary
	_expect(
		String(ember_instance.get("card_id", "")) == "ember_bolt"
		and String(quickstep_instance.get("card_id", "")) == "quickstep",
		"Legacy string decks must pin one protected instance for each fixed card."
	)
	deck.call("play_from_hand", 0)
	deck.call("play_from_hand", 1)
	var retained_hand := deck.get("hand_instances") as Array
	_expect(
		int((retained_hand[0] as Dictionary).get("instance_id", 0)) == int(ember_instance.get("instance_id", -1))
		and int((retained_hand[1] as Dictionary).get("instance_id", 0)) == int(quickstep_instance.get("instance_id", -1)),
		"Protected cards must retain their exact stable instances after play."
	)
	_expect(bool(deck.call("is_card_protected", ember_instance)), "Protection must recognize the pinned instance.")
	_expect(not bool(deck.call("is_card_protected", {"instance_id": 999, "card_id": "ember_bolt", "level": 1})), "A different fixed-card-shaped instance must not inherit protection.")

	deck.set("hand_size", 1)
	deck.call("start", ["cooling_guard"], 5.0)
	deck.call("play_from_hand", 0)
	var cooldown_pile := deck.get("cooldown_pile") as Array
	_expect(cooldown_pile.size() == 1, "Reusable cards with a cooldown must leave hand for the cooldown pile.")
	deck.call("tick_cooldowns", 1.25)
	_expect((deck.get("cooldown_pile") as Array).size() == 1, "Cooldown cards must stay unavailable until their full remaining duration elapses.")
	deck.call("tick_cooldowns", 0.75)
	var cooled_discard := deck.get("discard_instances") as Array
	_expect(
		(deck.get("cooldown_pile") as Array).is_empty()
		and cooled_discard.size() == 1
		and String((cooled_discard[0] as Dictionary).get("card_id", "")) == "cooling_guard",
		"A completed cooldown must release the same instance to discard."
	)

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
