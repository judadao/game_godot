class_name StoryDialogueCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/story/chapter_01_dialogues.json"
const SUPPORTED_EMOTIONS := ["idle", "chat", "laugh", "happy", "sad", "surprised", "angry"]

var _catalog: Dictionary = {}


func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> bool:
	_catalog.clear()
	if not FileAccess.file_exists(path):
		push_error("Story dialogue catalog does not exist: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Story dialogue catalog must contain a JSON object.")
		return false
	var candidate := parsed as Dictionary
	if not _validate_catalog(candidate):
		return false
	_catalog = candidate.duplicate(true)
	return true


func get_schema_version() -> int:
	return int(_catalog.get("schema_version", 0))


func get_chapter() -> Dictionary:
	return (_catalog.get("chapter", {}) as Dictionary).duplicate(true)


func get_sequence(sequence_id: StringName) -> Dictionary:
	var sequences := _catalog.get("sequences", {}) as Dictionary
	return (sequences.get(String(sequence_id), {}) as Dictionary).duplicate(true)


func get_speaker(speaker_id: StringName) -> Dictionary:
	var speakers := _catalog.get("speakers", {}) as Dictionary
	return (speakers.get(String(speaker_id), {}) as Dictionary).duplicate(true)


func _validate_catalog(candidate: Dictionary) -> bool:
	if int(candidate.get("schema_version", 0)) != 1:
		push_error("Unsupported story dialogue schema.")
		return false
	var speakers_variant: Variant = candidate.get("speakers", {})
	var sequences_variant: Variant = candidate.get("sequences", {})
	if not speakers_variant is Dictionary or not sequences_variant is Dictionary:
		push_error("Story catalog requires speakers and sequences objects.")
		return false
	var speakers := speakers_variant as Dictionary
	for speaker_id in speakers:
		var speaker := speakers[speaker_id] as Dictionary
		var portrait := speaker.get("portrait", {}) as Dictionary
		var texture_path := String(portrait.get("texture_path", ""))
		if String(speaker.get("display_name", "")).is_empty() or not ResourceLoader.exists(texture_path, "Texture2D"):
			push_error("Story speaker '%s' has an invalid portrait contract." % speaker_id)
			return false
		if int(portrait.get("columns", 0)) <= 0 or int(portrait.get("rows", 0)) <= 0:
			push_error("Story speaker '%s' has an invalid portrait grid." % speaker_id)
			return false
	for sequence_id in sequences_variant:
		var sequence := (sequences_variant as Dictionary)[sequence_id] as Dictionary
		var lines_variant: Variant = sequence.get("lines", [])
		if not lines_variant is Array or (lines_variant as Array).is_empty():
			push_error("Story sequence '%s' has no lines." % sequence_id)
			return false
		for line_variant in lines_variant as Array:
			if not line_variant is Dictionary:
				return false
			var line := line_variant as Dictionary
			if not speakers.has(String(line.get("speaker", ""))):
				push_error("Story sequence '%s' references an unknown speaker." % sequence_id)
				return false
			if not SUPPORTED_EMOTIONS.has(String(line.get("emotion", "idle"))):
				push_error("Story sequence '%s' uses an unsupported emotion." % sequence_id)
				return false
			if String(line.get("text", "")).strip_edges().is_empty():
				push_error("Story sequence '%s' contains an empty line." % sequence_id)
				return false
	return true
