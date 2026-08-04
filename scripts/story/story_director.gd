class_name StoryDirector
extends Node

signal dialogue_requested(sequence_id: StringName)
signal story_progress_changed(story_state: Dictionary)
signal sequence_finished(sequence_id: StringName)
signal review_finished(sequence_id: StringName)

const OPENING_SEQUENCE_ID := &"chapter_01_town_square"
const OPENING_FLAG := "protagonist_town_routine_established"
const CATALOG_SCRIPT := preload("res://scripts/story/story_dialogue_catalog.gd")

@onready var dialogue_runner: Node = $DialogueRunner

var _catalog: RefCounted = CATALOG_SCRIPT.new()
var _meta_state: RefCounted
var _opening_requested := false
var _review_mode := false


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


func start_review_sequence(sequence_id: StringName, dialogue_ui: Control) -> bool:
	_review_mode = true
	var started := bool(dialogue_runner.call("start_sequence", sequence_id, dialogue_ui))
	if not started:
		_review_mode = false
	return started


func get_review_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section in _catalog.call("get_review_sections") as Array[Dictionary]:
		var sequence_id := String(section.get("sequence_id", ""))
		result.append({
			"section": "story_review",
			"id": sequence_id,
			"sequence_id": sequence_id,
			"name": "%s · %s" % [String(section.get("scene_id", "")), String(section.get("title", "未命名"))],
			"kind_label": "第一章 · 劇情回顧",
			"description": String(section.get("summary", "")),
			"meta_summary": "可重播 · 不影響主線進度",
			"playable": true,
			"icon_path": "res://assets/ui/fantasy_icons_16x16/png/Separately/Icon45_1_2.png",
		})
	return result


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
	if _review_mode:
		_review_mode = false
		review_finished.emit(sequence_id)
		return
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


func _on_sequence_canceled(sequence_id: StringName) -> void:
	_opening_requested = false
	if _review_mode:
		_review_mode = false
		review_finished.emit(sequence_id)
