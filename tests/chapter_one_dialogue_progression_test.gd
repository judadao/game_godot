extends SceneTree

const DIRECTOR_SCRIPT := preload("res://scripts/story/story_director.gd")
const RUNNER_SCRIPT := preload("res://scripts/story/dialogue_runner.gd")

var _failures := 0
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
	var initial_story := meta.story_state.duplicate(true)
	director.call("configure", meta)

	var dialogue := load("res://scenes/ui/dialogue/DialogueUI.tscn").instantiate() as DialogueUI
	root.add_child(dialogue)
	await process_frame
	dialogue.open()
	_expect(
		director.call("start_review_sequence", &"chapter_01_town_square", dialogue),
		"The selected review section starts in the existing DialogueUI."
	)
	_expect((dialogue.speaker_name as Label).text == "聖女", "The first line projects the priest speaker.")
	_expect((dialogue.dialogue_text as RichTextLabel).text == "喂。", "The first canonical line is visible.")
	_expect(dialogue.animated_portrait.get_active_state() == &"chat", "The first line plays its authored chat emotion.")
	dialogue.animated_portrait.advance_animation(10.0)
	var settled_frame := int(dialogue.animated_portrait.call("get_pose_frame"))
	_expect(dialogue.animated_portrait.call("is_animation_finished"), "A sentence emotion must finish instead of looping forever.")
	dialogue.animated_portrait.advance_animation(10.0)
	_expect(
		int(dialogue.animated_portrait.call("get_pose_frame")) == settled_frame,
		"A finished sentence emotion must hold its final pose."
	)

	dialogue.advanced.emit()
	_expect((dialogue.speaker_name as Label).text == "主角", "Advancing switches the animated portrait speaker.")
	_expect((dialogue.dialogue_text as RichTextLabel).text == "痛。", "Advancing displays the next canonical line.")
	_expect(dialogue.animated_portrait.get_active_state() == &"surprised", "Advancing changes the authored emotion.")
	for _remaining_line in range(20):
		dialogue.advanced.emit()
	_expect(meta.story_state == initial_story, "Finishing a Story Review must not write a flag or checkpoint.")

	dialogue.queue_free()
	director.queue_free()
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
