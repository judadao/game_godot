class_name StoryDirector
extends Node

signal dialogue_requested(sequence_id: StringName)
signal story_progress_changed(story_state: Dictionary)
signal sequence_finished(sequence_id: StringName)

const OPENING_SEQUENCE_ID := &"chapter_01_town_square"
const OPENING_FLAG := "protagonist_town_routine_established"
const CATALOG_SCRIPT := preload("res://scripts/story/story_dialogue_catalog.gd")

@onready var dialogue_runner: Node = $DialogueRunner

var _catalog: RefCounted = CATALOG_SCRIPT.new()
var _meta_state: RefCounted
var _opening_requested := false


func _ready() -> void:
	if not bool(_catalog.call("load_catalog")):
		push_error("StoryDirector could not load the chapter-one dialogue catalog.")
	dialogue_runner.configure(_catalog)
	dialogue_runner.sequence_completed.connect(_on_sequence_completed)
	dialogue_runner.sequence_canceled.connect(_on_sequence_canceled)


func configure(meta_state: RefCounted) -> void:
	_meta_state = meta_state


func request_chapter_one_opening() -> bool:
	if _meta_state == null or _opening_requested or has_story_flag(OPENING_FLAG):
		return false
	_opening_requested = true
	dialogue_requested.emit(OPENING_SEQUENCE_ID)
	return true


func start_requested_sequence(sequence_id: StringName, dialogue_ui: Control) -> bool:
	if sequence_id != OPENING_SEQUENCE_ID:
		return false
	var started := bool(dialogue_runner.call("start_sequence", sequence_id, dialogue_ui))
	if not started:
		_opening_requested = false
	return started


func has_story_flag(flag: String) -> bool:
	if _meta_state == null:
		return false
	var story_variant: Variant = _meta_state.get("story_state")
	if not story_variant is Dictionary:
		return false
	return ((story_variant as Dictionary).get("story_flags", []) as Array).has(flag)


func _on_sequence_completed(
	sequence_id: StringName,
	completion_flags: Array[String],
	next_sequence_id: StringName
) -> void:
	if _meta_state == null:
		return
	var story_variant: Variant = _meta_state.get("story_state")
	var story: Dictionary = (
		(story_variant as Dictionary).duplicate(true)
		if story_variant is Dictionary
		else {}
	)
	var flags: Array = story.get("story_flags", []) as Array
	for flag in completion_flags:
		if not flags.has(flag):
			flags.append(flag)
	story["story_flags"] = flags
	story["next_sequence_id"] = String(next_sequence_id)
	_meta_state.set("story_state", story)
	_opening_requested = false
	story_progress_changed.emit(story.duplicate(true))
	sequence_finished.emit(sequence_id)


func _on_sequence_canceled(_sequence_id: StringName) -> void:
	_opening_requested = false
