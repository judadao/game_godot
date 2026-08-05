extends SceneTree

var _failures := 0
var _return_requested := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/ui/results/RunResultUI.tscn") as PackedScene
	_expect(scene != null, "Run result UI scene must load.")
	if scene == null:
		quit(1)
		return
	var ui := scene.instantiate()
	root.add_child(ui)
	ui.connect("return_to_town_requested", func() -> void: _return_requested = true)
	ui.call("set_result", true, {"gold": 120, "materials": {"autumn_core": 1}, "defeated_enemies": 9, "completion_bonus_rate": 0.15})
	await process_frame
	_expect(String(ui.call("get_title_text")).contains("VICTORY"), "Victory result must be unmistakable.")
	_expect(String(ui.call("get_summary_text")).contains("120"), "Result must show earned gold.")
	_expect(String(ui.call("get_summary_text")).contains("15%"), "Victory result must explain the clear bonus.")
	ui.call("set_result", false, {"gold": 40, "materials": {"stone": 2}, "defeated_enemies": 3, "completion_bonus_rate": 0.0})
	_expect(
		String(ui.call("get_summary_text")).contains("retained")
			and String(ui.call("get_summary_text")).contains("Stone"),
		"Defeat result must clearly confirm that gold and materials are retained."
	)
	ui.call("request_return_to_town")
	_expect(_return_requested, "Result UI must expose the Return to Town action.")
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
