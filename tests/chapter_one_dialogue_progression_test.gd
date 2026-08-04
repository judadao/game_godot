extends SceneTree

const DIRECTOR_SCRIPT := preload("res://scripts/story/story_director.gd")
const RUNNER_SCRIPT := preload("res://scripts/story/dialogue_runner.gd")

var _failures := 0
var _requested_sequence: StringName


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := Node.new()
	director.set_script(DIRECTOR_SCRIPT)
	var runner := Node.new()
	runner.name = "DialogueRunner"
	runner.set_script(RUNNER_SCRIPT)
	director.add_child(runner)
	root.add_child(director)
	await process_frame

	var meta := MetaState.new()
	director.call("configure", meta)
	director.dialogue_requested.connect(func(sequence_id: StringName) -> void: _requested_sequence = sequence_id)
	_expect(director.call("request_chapter_one_opening"), "A fresh save requests the chapter-one opening.")
	_expect(_requested_sequence == &"chapter_01_town_square", "The story director requests the canonical opening sequence.")

	var dialogue := load("res://scenes/ui/dialogue/DialogueUI.tscn").instantiate() as DialogueUI
	root.add_child(dialogue)
	await process_frame
	dialogue.open()
	_expect(
		director.call("start_requested_sequence", _requested_sequence, dialogue),
		"The requested opening starts in the existing DialogueUI."
	)
	_expect((dialogue.speaker_name as Label).text == "聖女", "The first line projects the priest speaker.")
	_expect((dialogue.dialogue_text as RichTextLabel).text == "喂。", "The first canonical line is visible.")
	_expect(dialogue.animated_portrait.get_active_state() == &"chat", "The first line plays its authored chat emotion.")

	dialogue.advanced.emit()
	_expect((dialogue.speaker_name as Label).text == "主角", "Advancing switches the animated portrait speaker.")
	_expect((dialogue.dialogue_text as RichTextLabel).text == "痛。", "Advancing displays the next canonical line.")
	_expect(dialogue.animated_portrait.get_active_state() == &"surprised", "Advancing changes the authored emotion.")
	for _remaining_line in range(20):
		dialogue.advanced.emit()
	var flags := meta.story_state.get("story_flags", []) as Array
	_expect(flags.has("protagonist_town_routine_established"), "Finishing the opening writes its durable story flag.")
	_expect(String(meta.story_state.get("next_sequence_id", "")) == "chapter_01_forge", "Finishing the opening stores the next scene checkpoint.")
	_expect(not director.call("request_chapter_one_opening"), "A completed opening is not requested again.")

	dialogue.queue_free()
	director.queue_free()
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
