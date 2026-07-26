extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := (load("res://scenes/ui/LevelUpUI.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	var choices: Array[Dictionary] = [
		{"id": "a", "text": "A"},
		{"id": "b", "text": "B"},
		{"id": "c", "text": "C"},
	]
	ui.call("set_choices", choices)
	_expect(int(ui.call("get_choice_button_count")) == 3, "Level-up UI must show exactly three choices.")
	var selected: Array[Dictionary] = []
	ui.connect("choice_selected", func(choice: Dictionary) -> void: selected.append(choice))
	ui.call("select_choice", 1)
	_expect(selected.size() == 1 and String(selected[0].get("id", "")) == "b", "Level-up UI must emit selected metadata once.")
	ui.call("select_choice", 2)
	_expect(selected.size() == 1, "Level-up UI must accept only one selection.")
	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
