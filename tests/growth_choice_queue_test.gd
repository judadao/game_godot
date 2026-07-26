extends SceneTree

var _failures := 0
var _queue_counts: Array[int] = []
var _current_entries: Array[Dictionary] = []
var _confirmed_actions: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var queue_script := load("res://scripts/systems/growth_choice_queue.gd") as GDScript
	_expect(queue_script != null, "Growth choices require a queue authority.")
	if queue_script == null:
		quit(1)
		return

	var queue: RefCounted = queue_script.new()
	queue.connect("queue_changed", _on_queue_changed)
	queue.connect("current_changed", _on_current_changed)
	queue.connect("action_confirmed", _on_action_confirmed)
	_expect(int(queue.call("get_queue_count")) == 0, "A new queue must be empty.")
	_expect((queue.call("peek") as Dictionary).is_empty(), "Peeking an empty queue must be safe.")
	_expect(not bool(queue.call("confirm", {"page": "new_card", "kind": "new_card"})), "An empty queue must reject confirmation.")
	_expect(not bool(queue.call("close")), "Closing a growth choice must never consume it.")

	_expect(
		not bool(queue.call("enqueue", {"source": "wave_blessing", "allowed_pages": ["upgrade"], "payload": {}})),
		"Wave blessings must reject every page except New Card."
	)
	_expect(
		not bool(queue.call("enqueue", {"source": "exp_level", "allowed_pages": ["new_card"], "payload": {}})),
		"Experience choices must reject wave-only New Card pages."
	)
	_expect(
		not bool(queue.call("enqueue", {"source": "exp_level", "allowed_pages": ["upgrade"]})),
		"Growth entries must include a dictionary payload."
	)

	var wave_entry := {
		"source": "wave_blessing",
		"allowed_pages": ["new_card"],
		"payload": {"card_options": ["ember_bolt"]},
	}
	var upgrade_entry := {
		"source": "exp_level",
		"allowed_pages": ["upgrade"],
		"payload": {"upgradeable_instance_ids": [101]},
	}
	var fusion_entry := {
		"source": "exp_level",
		"allowed_pages": ["fusion"],
		"payload": {"fusion_recipes": ["evolve_dash_strike"]},
	}
	var reward_entry := {
		"source": "exp_level",
		"allowed_pages": ["reward"],
		"payload": {"fallback_rewards": [{"resource_id": "gold", "amount": 75}]},
	}
	_expect(bool(queue.call("enqueue", wave_entry)), "A New Card wave blessing must enqueue.")
	_expect(bool(queue.call("enqueue", upgrade_entry)), "An EXP upgrade choice must enqueue behind the wave blessing.")
	_expect(bool(queue.call("enqueue", fusion_entry)), "An EXP fusion choice must enqueue.")
	_expect(bool(queue.call("enqueue", reward_entry)), "An EXP declared fallback reward must enqueue.")
	_expect(int(queue.call("get_queue_count")) == 4, "Each accepted entry must retain FIFO order.")
	wave_entry["payload"]["card_options"] = ["mutated"]
	_expect(
		(queue.call("peek") as Dictionary).get("payload", {}).get("card_options", []) == ["ember_bolt"],
		"Enqueued entries must not share mutable payloads with their callers."
	)
	_expect(
		not bool(queue.call("confirm", {"page": "upgrade", "kind": "upgrade", "instance_id": 101})),
		"A page not declared by the current wave entry must not consume it."
	)
	_expect(not bool(queue.call("close")), "Invalid close must retain the current growth entry.")
	_expect(int(queue.call("get_queue_count")) == 4, "Rejected actions and close must not dequeue entries.")
	_expect(
		bool(queue.call("confirm", {"page": "new_card", "kind": "new_card", "card_id": "ember_bolt"})),
		"The declared wave New Card action must confirm once."
	)
	_expect(int(queue.call("get_queue_count")) == 3, "A valid confirmation must dequeue exactly its current entry.")
	_expect(
		not bool(queue.call("confirm", {"page": "upgrade", "kind": "fusion"})),
		"An action kind that disagrees with its page must not consume an EXP entry."
	)
	_expect(
		bool(queue.call("confirm", {"page": "upgrade", "kind": "upgrade", "instance_id": 101})),
		"The declared EXP upgrade action must confirm."
	)
	_expect(
		bool(queue.call("confirm", {"page": "fusion", "kind": "fusion", "recipe_id": "evolve_dash_strike"})),
		"The declared EXP fusion action must confirm."
	)
	_expect(
		bool(queue.call("confirm", {"page": "reward", "kind": "reward", "resource_id": "gold"})),
		"The declared EXP fallback reward must confirm."
	)
	_expect(int(queue.call("get_queue_count")) == 0, "Confirming each queued choice must empty the queue.")
	_expect(_confirmed_actions.size() == 4, "Exactly one action_confirmed signal must emit for each valid confirmation.")
	_expect(
		_current_entries.size() == 5 and (_current_entries.back() as Dictionary).is_empty(),
		"Current-change signals must advance through FIFO entries and clear when empty."
	)
	_expect(
		_queue_counts == [1, 2, 3, 4, 3, 2, 1, 0],
		"Queue-change signals must report every accepted enqueue and valid dequeue once."
	)
	quit(0 if _failures == 0 else 1)


func _on_queue_changed(queue_count: int) -> void:
	_queue_counts.append(queue_count)


func _on_current_changed(entry: Dictionary) -> void:
	_current_entries.append(entry.duplicate(true))


func _on_action_confirmed(_entry: Dictionary, action: Dictionary) -> void:
	_confirmed_actions.append(action.duplicate(true))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
