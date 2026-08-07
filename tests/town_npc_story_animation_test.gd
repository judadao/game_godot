extends SceneTree

const STORY_ANIMATOR_SCENE := preload("res://scenes/npc/town/TownNPCStoryAnimator.tscn")
const CATALOG_PATH := "res://data/town_npc_story_animations.json"
const CORE_CHARACTERS := [&"priest", &"witch", &"scientist", &"guard", &"grocer"]
const EXPECTED_STATE_COUNT := 6
const EXPECTED_ATLAS_SIZE := Vector2i(1024, 1536)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists(CATALOG_PATH), "NPC story animation catalog must exist.")
	if not FileAccess.file_exists(CATALOG_PATH):
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_expect(parsed is Dictionary, "NPC story animation catalog must be valid JSON.")
	if not parsed is Dictionary:
		quit(1)
		return
	var profiles := (parsed as Dictionary).get("profiles", []) as Array
	_expect(profiles.size() == CORE_CHARACTERS.size(), "All five core NPCs need story animation profiles.")
	var profile_by_id := {}
	for profile_variant in profiles:
		var profile := profile_variant as Dictionary
		profile_by_id[StringName(profile.get("id", ""))] = profile
	for character_id in CORE_CHARACTERS:
		_expect(profile_by_id.has(character_id), "%s needs a story animation profile." % character_id)
		if not profile_by_id.has(character_id):
			continue
		var profile := profile_by_id[character_id] as Dictionary
		for kind in ["expressions", "actions"]:
			var spec := profile.get(kind, {}) as Dictionary
			var states := spec.get("states", []) as Array
			var atlas_path := String(spec.get("atlas_path", ""))
			_expect(states.size() == EXPECTED_STATE_COUNT, "%s needs six %s." % [character_id, kind])
			_expect(ResourceLoader.exists(atlas_path), "%s %s atlas must exist." % [character_id, kind])
			var texture := load(atlas_path) as Texture2D
			if texture != null:
				var image := texture.get_image()
				_expect(image.get_size() == EXPECTED_ATLAS_SIZE, "%s %s atlas must use a 4x6 grid." % [character_id, kind])
				_expect(_has_transparency(image), "%s %s atlas must retain alpha." % [character_id, kind])
	var animator := STORY_ANIMATOR_SCENE.instantiate()
	root.add_child(animator)
	await process_frame
	for character_id in CORE_CHARACTERS:
		_expect(bool(animator.call("set_character", character_id)), "%s must load in the story animator." % character_id)
		var expressions := animator.call("get_supported_expressions") as Array
		var actions := animator.call("get_supported_actions") as Array
		_expect(expressions.size() == EXPECTED_STATE_COUNT, "%s must expose six expression animations." % character_id)
		_expect(actions.size() == EXPECTED_STATE_COUNT, "%s must expose six action animations." % character_id)
		for expression in expressions:
			_expect(bool(animator.call("play_expression", StringName(expression))), "%s expression %s must play." % [character_id, expression])
		for action in actions:
			_expect(bool(animator.call("play_action", StringName(action))), "%s action %s must play." % [character_id, action])
	animator.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _has_transparency(image: Image) -> bool:
	for y in range(0, image.get_height(), 48):
		for x in range(0, image.get_width(), 48):
			if image.get_pixel(x, y).a < 0.05:
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
