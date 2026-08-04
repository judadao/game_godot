extends SceneTree

const JOURNAL_SCENE := preload("res://scenes/ui/inventory/InventoryUI.tscn")
const DIRECTOR_SCRIPT := preload("res://scripts/story/story_director.gd")
const RUNNER_SCRIPT := preload("res://scripts/story/dialogue_runner.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/managers/game.gd")
	_expect(
		not game_source.contains("story_director.request_chapter_one_opening()"),
		"Loading Town must not auto-trigger chapter-one dialogue before live integration is approved."
	)
	var director := Node.new()
	director.set_script(DIRECTOR_SCRIPT)
	var runner := Node.new()
	runner.name = "DialogueRunner"
	runner.set_script(RUNNER_SCRIPT)
	director.add_child(runner)
	root.add_child(director)
	await process_frame

	var meta := MetaState.new()
	var original_story := meta.story_state.duplicate(true)
	director.call("configure", meta)
	_expect(director.has_method("get_review_entries"), "StoryDirector must project selectable Codex review sections.")
	var entries := director.call("get_review_entries") as Array
	_expect(not entries.is_empty(), "Chapter one must expose at least one Story Review section.")
	var opening := entries[0] as Dictionary if not entries.is_empty() else {}
	_expect(String(opening.get("section", "")) == "story_review", "Review rows must belong to the Story Review section.")
	_expect(bool(opening.get("playable", false)), "The completed 1-1 dialogue section must be replayable.")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var journal := JOURNAL_SCENE.instantiate()
	viewport.add_child(journal)
	await process_frame
	journal.call("set_codex_entries", entries)
	journal.call("set_mode", &"codex")
	_expect(journal.has_method("set_codex_section"), "Codex must support direct button-section selection.")
	journal.call("set_codex_section", "story_review")
	_expect(journal.call("get_codex_section") == "story_review", "Story Review button must select its section directly.")
	var play_button := journal.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/PlayStory"
	) as Button
	_expect(play_button != null and play_button.visible and not play_button.disabled, "A playable review entry needs a visible replay button.")
	var requested := [StringName()]
	journal.connect("story_review_requested", func(sequence_id: StringName) -> void: requested[0] = sequence_id)
	if play_button != null:
		play_button.pressed.emit()
	_expect(requested[0] == &"chapter_01_town_square", "Replay button must emit the selected section id.")

	var dialogue := load("res://scenes/ui/dialogue/DialogueUI.tscn").instantiate() as DialogueUI
	root.add_child(dialogue)
	await process_frame
	dialogue.open()
	_expect(
		director.call("start_review_sequence", &"chapter_01_town_square", dialogue),
		"Story Review must start the selected section without live-flow integration."
	)
	for _line in range(21):
		dialogue.advanced.emit()
	_expect(meta.story_state == original_story, "Review playback must never mutate story progress or completion flags.")

	journal.queue_free()
	viewport.queue_free()
	dialogue.queue_free()
	director.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Codex Story Review")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
