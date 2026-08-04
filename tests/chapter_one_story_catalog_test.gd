extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/story/story_dialogue_catalog.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: RefCounted = CATALOG_SCRIPT.new()
	_expect(catalog.call("load_catalog"), "Chapter-one dialogue catalog must load.")
	_expect(int(catalog.call("get_schema_version")) == 1, "Story catalog schema must be version one.")

	var opening := catalog.call("get_sequence", &"chapter_01_town_square") as Dictionary
	var lines := opening.get("lines", []) as Array
	_expect(String(opening.get("chapter_id", "")) == "chapter_01", "Town-square dialogue belongs to chapter one.")
	_expect(lines.size() == 21, "The canonical town-square scene must retain all 21 spoken lines.")
	_expect(String((lines[0] as Dictionary).get("speaker", "")) == "priest", "The priest opens the town-square scene.")
	_expect(String((lines[0] as Dictionary).get("text", "")) == "喂。", "The canonical opening line must not be paraphrased.")
	_expect(String((lines[20] as Dictionary).get("text", "")) == "……我先開爐。", "The canonical closing line must not be paraphrased.")
	_expect(
		(opening.get("completion_flags", []) as Array).has("protagonist_town_routine_established"),
		"Completing the opening must establish the protagonist's town routine."
	)

	for line_variant in lines:
		var line := line_variant as Dictionary
		var speaker := catalog.call("get_speaker", StringName(line.get("speaker", ""))) as Dictionary
		_expect(not speaker.is_empty(), "Every story line must reference a known speaker.")
		var portrait := speaker.get("portrait", {}) as Dictionary
		_expect(
			ResourceLoader.exists(String(portrait.get("texture_path", "")), "Texture2D"),
			"Every opening speaker must reference a loadable portrait texture."
		)

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
