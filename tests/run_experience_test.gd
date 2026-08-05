extends SceneTree

var _failures := 0


func _init() -> void:
	var run := RunState.new()
	run.begin_run(["ember_bolt"])
	_expect(run.experience_required == 40, "Run XP threshold must start at 40 for a fast opening growth cadence.")
	_expect(int(run.call("add_experience", 39)) == 0, "Sub-threshold XP must not queue a level.")
	_expect(int(run.call("add_experience", 1)) == 1, "Crossing the threshold must queue one level.")
	_expect(run.level == 2 and run.experience_required == 60, "Level two threshold must follow ceil(previous * 1.20 + 12).")
	_expect(int(run.call("add_experience", 400)) >= 2, "Large XP pickup must queue multiple level-ups.")
	var pending_before := int(run.get("pending_level_ups"))
	_expect(bool(run.call("consume_pending_level")), "Pending level must be consumable.")
	_expect(int(run.get("pending_level_ups")) == pending_before - 1, "Consuming a level must decrement the queue.")
	var sprint_run := RunState.new()
	sprint_run.begin_run(["ember_bolt"])
	_expect(
		int(sprint_run.call("add_experience", 445)) == 5
			and sprint_run.level == 6,
		"The fast XP curve must supply five level pages inside the six-minute run."
	)
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
