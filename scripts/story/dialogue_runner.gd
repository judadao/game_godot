class_name DialogueRunner
extends Node

signal sequence_started(sequence_id: StringName)
signal line_changed(sequence_id: StringName, line_index: int, line: Dictionary)
signal sequence_completed(sequence_id: StringName, completion_flags: Array[String], next_sequence_id: StringName)
signal sequence_canceled(sequence_id: StringName)

var _catalog: RefCounted
var _dialogue_ui: Control
var _sequence_id: StringName
var _sequence: Dictionary = {}
var _lines: Array = []
var _line_index := -1
var _completing := false


func configure(catalog: RefCounted) -> void:
	_catalog = catalog


func start_sequence(sequence_id: StringName, dialogue_ui: Control) -> bool:
	if _catalog == null or dialogue_ui == null or not dialogue_ui.has_method("present_story_line"):
		return false
	var sequence := _catalog.call("get_sequence", sequence_id) as Dictionary
	var lines_variant: Variant = sequence.get("lines", [])
	if not lines_variant is Array or (lines_variant as Array).is_empty():
		return false
	_disconnect_ui()
	_sequence_id = sequence_id
	_sequence = sequence
	_lines = (lines_variant as Array).duplicate(true)
	_line_index = 0
	_dialogue_ui = dialogue_ui
	_dialogue_ui.advanced.connect(_advance)
	_dialogue_ui.canceled.connect(_cancel)
	_dialogue_ui.closed.connect(_on_ui_closed)
	sequence_started.emit(_sequence_id)
	_present_current_line()
	return true


func get_line_index() -> int:
	return _line_index


func get_active_sequence_id() -> StringName:
	return _sequence_id


func _advance() -> void:
	if _dialogue_ui == null or _completing:
		return
	_line_index += 1
	if _line_index < _lines.size():
		_present_current_line()
		return
	_complete()


func _present_current_line() -> void:
	var line := (_lines[_line_index] as Dictionary).duplicate(true)
	var speaker := _catalog.call(
		"get_speaker", StringName(line.get("speaker", ""))
	) as Dictionary
	_dialogue_ui.call("present_story_line", line, speaker)
	line_changed.emit(_sequence_id, _line_index, line)


func _complete() -> void:
	_completing = true
	var completed_id := _sequence_id
	var flags: Array[String] = []
	for flag_variant in _sequence.get("completion_flags", []) as Array:
		var flag := String(flag_variant).strip_edges()
		if not flag.is_empty() and not flags.has(flag):
			flags.append(flag)
	var next_id := StringName(_sequence.get("next_sequence_id", ""))
	_disconnect_ui()
	_clear_active()
	sequence_completed.emit(completed_id, flags, next_id)
	_completing = false


func _cancel() -> void:
	if _sequence_id == &"" or _completing:
		return
	var canceled_id := _sequence_id
	_disconnect_ui()
	_clear_active()
	sequence_canceled.emit(canceled_id)


func _on_ui_closed() -> void:
	if _sequence_id != &"" and not _completing:
		_cancel()


func _disconnect_ui() -> void:
	if _dialogue_ui == null or not is_instance_valid(_dialogue_ui):
		_dialogue_ui = null
		return
	if _dialogue_ui.advanced.is_connected(_advance):
		_dialogue_ui.advanced.disconnect(_advance)
	if _dialogue_ui.canceled.is_connected(_cancel):
		_dialogue_ui.canceled.disconnect(_cancel)
	if _dialogue_ui.closed.is_connected(_on_ui_closed):
		_dialogue_ui.closed.disconnect(_on_ui_closed)
	_dialogue_ui = null


func _clear_active() -> void:
	_sequence_id = &""
	_sequence.clear()
	_lines.clear()
	_line_index = -1
