extends SceneTree

const MANIFEST_PATH := "res://assets/town/npc/priest/priest_animation_manifest.json"
const ATLAS_PATH := "res://assets/town/npc/priest/priest_animation_atlas.png"
const PRIEST_SCENE := preload("res://scenes/npc/town/PriestAnimatedSprite.tscn")
const PREVIEW_SCENE := preload("res://scenes/dev/previews/PriestAnimationPreview.tscn")
const FRAME_SIZE := Vector2i(384, 512)
const FRAME_COUNT := 8
const ACTIONS := [&"front_idle", &"front_chat", &"side_walk", &"side_chat"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manifest()
	_test_atlas_contract()
	await _test_runtime_player()
	await _capture_preview_if_requested()
	if _failures.is_empty():
		print("PASS: priest animation asset contract")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_expect(file != null, "Priest animation manifest must be readable.")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "Priest animation manifest must contain a JSON object.")
	if not parsed is Dictionary:
		return
	var manifest := parsed as Dictionary
	_expect(manifest.get("construction") == "reviewed_full_pose_strips", "Manifest must declare reviewed full-pose strip construction.")
	_expect(float(manifest.get("adult_head_heights", 0.0)) >= 6.5, "Priest artwork must declare an adult 6.5-head-or-taller proportion contract.")
	var pose_strips := manifest.get("pose_strips", {}) as Dictionary
	for action in ACTIONS:
		_expect(pose_strips.has(String(action)), "Manifest must retain the reviewed %s full-pose strip." % action)
	var body_groups: Array = manifest.get("body_groups", []) as Array
	for required_group in ["head", "chest", "abdomen", "left_arm", "right_arm", "legs"]:
		_expect(body_groups.has(required_group), "Manifest must retain %s parts." % required_group)
	var animations := manifest.get("animations", {}) as Dictionary
	for action in ACTIONS:
		var spec := animations.get(String(action), {}) as Dictionary
		_expect(int(spec.get("frames", 0)) == FRAME_COUNT, "%s must expose eight frames." % action)


func _test_atlas_contract() -> void:
	var texture := load(ATLAS_PATH) as Texture2D
	_expect(texture != null, "Priest animation atlas must load as Texture2D.")
	if texture == null:
		return
	var atlas := texture.get_image()
	_expect(atlas.get_size() == Vector2i(FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y * ACTIONS.size()), "Priest atlas dimensions must match the 8x4 frame contract.")
	_expect(atlas.detect_alpha(), "Priest atlas must retain transparency.")
	for row in range(ACTIONS.size()):
		var frame_hashes: Dictionary = {}
		for column in range(FRAME_COUNT):
			var region := atlas.get_region(Rect2i(Vector2i(column * FRAME_SIZE.x, row * FRAME_SIZE.y), FRAME_SIZE))
			var used := region.get_used_rect()
			_expect(used.size.x > 0 and used.size.y > 0, "%s frame %d must not be empty." % [ACTIONS[row], column])
			_expect(used.position.x > 0 and used.position.y > 0, "%s frame %d must keep top/left padding." % [ACTIONS[row], column])
			_expect(used.end.x < FRAME_SIZE.x and used.end.y < FRAME_SIZE.y, "%s frame %d must not be clipped." % [ACTIONS[row], column])
			_expect(used.size.y >= 440 and used.size.y <= 454, "%s frame %d must retain the normalized adult-height silhouette." % [ACTIONS[row], column])
			_expect(used.end.y >= 490 and used.end.y <= 492, "%s frame %d must share the authored foot baseline." % [ACTIONS[row], column])
			_expect(used.size.x <= 280, "%s frame %d must not contain a neighbouring pose or detached side artifact." % [ACTIONS[row], column])
			frame_hashes[hash(region.get_data())] = true
		_expect(frame_hashes.size() >= 7, "%s must contain at least seven visually distinct frames." % ACTIONS[row])


func _test_runtime_player() -> void:
	var priest := PRIEST_SCENE.instantiate()
	root.add_child(priest)
	await process_frame
	var sprite := priest.get_node_or_null("CharacterSprite") as Sprite2D
	_expect(sprite != null, "Priest scene must own its CharacterSprite.")
	if sprite != null:
		_expect(sprite.hframes == 8 and sprite.vframes == 4, "Priest runtime sprite must expose the 8x4 atlas grid.")
	for row in range(ACTIONS.size()):
		_expect(bool(priest.call("play_animation", ACTIONS[row], true)), "%s must be playable." % ACTIONS[row])
		priest.call("set_frame_for_review", 7)
		_expect(int(priest.call("get_frame_index")) == 7, "%s must reach frame seven." % ACTIONS[row])
		_expect(int(priest.call("get_animation_row")) == row, "%s must map to atlas row %d." % [ACTIONS[row], row])
	priest.queue_free()


func _capture_preview_if_requested() -> void:
	var capture_path := OS.get_environment("PRIEST_ANIMATION_CAPTURE_PATH").strip_edges()
	if capture_path.is_empty():
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := PREVIEW_SCENE.instantiate()
	viewport.add_child(preview)
	var requested_frame := int(OS.get_environment("PRIEST_ANIMATION_CAPTURE_FRAME"))
	for node_name in [&"FrontIdle", &"FrontChat", &"SideWalk", &"SideChat"]:
		var actor := preview.get_node_or_null(NodePath(String(node_name)))
		if actor != null:
			actor.call("set_frame_for_review", requested_frame)
	await process_frame
	await process_frame
	await process_frame
	var error := viewport.get_texture().get_image().save_png(capture_path)
	_expect(error == OK, "Priest preview capture must save to %s." % capture_path)
	viewport.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
