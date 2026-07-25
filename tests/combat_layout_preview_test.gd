extends SceneTree

const PREVIEW_SCENE_PATH := "res://scenes/dev/CombatLayoutPreview.tscn"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(PREVIEW_SCENE_PATH), "Combat layout preview scene must exist.")
	if not ResourceLoader.exists(PREVIEW_SCENE_PATH):
		quit(1)
		return

	var packed := load(PREVIEW_SCENE_PATH) as PackedScene
	var preview := packed.instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame

	var map := preview.get_node_or_null("AutumnForest")
	var camera := preview.get_node_or_null("PreviewCamera") as Camera2D
	var hud := preview.get_node_or_null("HUDLayer/HUD") as Control
	var hand := preview.get_node_or_null("HUDLayer/CardHandUI") as Control
	_expect(map != null, "Preview must instance the real autumn forest map.")
	_expect(map != null and map.process_mode == Node.PROCESS_MODE_DISABLED, "Preview map gameplay must remain disabled.")
	_expect(camera != null and camera.enabled, "Preview must provide an enabled layout camera.")
	_expect(hud != null and hud.visible, "Preview must show the real HUD.")
	_expect(hand != null and hand.visible, "Preview must show the real card hand.")
	_expect(
		hand != null and int(hand.call("get_card_button_count")) == 4,
		"Preview must populate one visible Q/W/E/R card group."
	)
	if hud != null:
		_expect(
			(hud.get_node("HUDQuestTracker/QuestRows/QuestText") as Label).text == "SURVIVAL PHASE 1",
			"Preview must populate stable sample objective text."
		)

	preview.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
