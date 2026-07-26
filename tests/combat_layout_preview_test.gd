extends SceneTree

const PREVIEW_SCENE_PATH := "res://scenes/dev/CombatLayoutPreview.tscn"
const AUTUMN_MAIN_SCENE_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"

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

	var map := preview.get_node_or_null("AutumnBattleMapV2")
	var camera := preview.get_node_or_null("PreviewCamera") as Camera2D
	var hud := preview.get_node_or_null("HUDLayer/HUD") as Control
	var hand := preview.get_node_or_null(
		"HUDLayer/HUD/BottomStage/CardStage/AutumnCardHandUI"
	) as Control
	_expect(map != null, "Preview must instance the real autumn forest map.")
	_expect(
		map != null and map.scene_file_path == AUTUMN_MAIN_SCENE_PATH,
		"Preview must use the authoritative AutumnBattleMapV2 scene."
	)
	_expect(map != null and map.process_mode == Node.PROCESS_MODE_DISABLED, "Preview map gameplay must remain disabled.")
	_expect(camera != null and camera.enabled, "Preview must provide an enabled layout camera.")
	_expect(preview.has_method("_preview_zoom_for_size"), "Preview must expose responsive camera scaling.")
	if preview.has_method("_preview_zoom_for_size"):
		_expect(
			(preview.call("_preview_zoom_for_size", Vector2(1280, 720)) as Vector2).is_equal_approx(Vector2.ONE)
			and (preview.call("_preview_zoom_for_size", Vector2(2560, 1440)) as Vector2).is_equal_approx(Vector2(2, 2)),
			"Preview camera must preserve the same world framing from 720p through 1440p."
		)
	_expect(hud != null and hud.visible, "Preview must show the real HUD.")
	_expect(
		hand != null and hand.visible,
		"Preview must show the real embedded card hand."
	)
	_expect(
		hand != null
			and int(hand.call("get_card_button_count")) == 4
			and int(hand.call("get_group_count")) == 1,
		"Preview must populate the single four-card Combo/Healing hand."
	)
	if hud != null:
		_expect(
			(
				hud.get_node(
					"TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/ObjectiveText"
				) as Label
			).text
			== "SURVIVAL PHASE 1",
			"Preview must populate stable sample objective text."
		)
	if hud != null and hand != null:
		var safe_rect := _canvas_rect(hud.get_node("BottomStage") as Control)
		var hud_paths := {
			"PlayerVitals": "BottomStage/PlayerVitals",
			"CardStage": "BottomStage/CardStage",
			"ActivityFeed": "BottomStage/ActivityFeed",
		}
		for node_name in hud_paths:
			var hud_rect := _canvas_rect(hud.get_node(hud_paths[node_name]) as Control)
			_expect(
				safe_rect.encloses(hud_rect),
				"Preview %s must stay inside the bottom UI safe area." % node_name
			)

	preview.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
