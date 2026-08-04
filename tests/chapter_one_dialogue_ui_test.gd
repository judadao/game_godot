extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/ui/dialogue/DialogueUI.tscn") as PackedScene
	_expect(packed != null, "Dialogue UI must load.")
	if packed == null:
		quit(1)
		return
	var dialogue := packed.instantiate() as Control
	root.add_child(dialogue)
	await process_frame

	var portrait_frame := dialogue.get_node_or_null("PortraitFrame") as Control
	var animated_portrait := dialogue.get_node_or_null("PortraitFrame/AnimatedPortrait")
	var dialogue_panel := dialogue.get_node_or_null("DialoguePanel") as Control
	_expect(portrait_frame != null, "Dialogue UI must expose its portrait in the upper-left layer.")
	_expect(animated_portrait != null, "Dialogue UI must use the reusable animated NPC portrait component.")
	_expect(dialogue.has_method("present_story_line"), "Dialogue UI must accept a complete story line presentation.")

	if portrait_frame != null and dialogue_panel != null:
		for viewport_size in VIEWPORT_SIZES:
			root.size = viewport_size
			await process_frame
			var portrait_rect := portrait_frame.get_global_rect()
			var panel_rect := dialogue_panel.get_global_rect()
			_expect(portrait_rect.position.x < viewport_size.x * 0.3, "Portrait remains in the left third at %s." % viewport_size)
			_expect(portrait_rect.position.y < panel_rect.position.y, "Portrait remains above the dialogue panel at %s." % viewport_size)
			_expect(portrait_rect.end.x <= viewport_size.x, "Portrait remains on screen at %s." % viewport_size)
			_expect(panel_rect.end.y <= viewport_size.y, "Dialogue panel remains on screen at %s." % viewport_size)

	dialogue.queue_free()
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
