extends SceneTree

const SCENE_PATH := "res://scenes/ui/expedition/ExpeditionVariantSelectUI.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1152, 720), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(SCENE_PATH), "Expedition variant selector scene must exist.")
	if not ResourceLoader.exists(SCENE_PATH):
		quit(1)
		return
	for viewport_size in VIEWPORT_SIZES:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var ui := (load(SCENE_PATH) as PackedScene).instantiate()
		viewport.add_child(ui)
		ui.call("configure", "選擇秋季戰場", [
			{"variant_id": "autumn", "display_name": "秋季戰場", "power_tier": 1, "fragment_name": "秋天碎片", "fragment_count": 4, "key_ready": true},
			{"variant_id": "hell_autumn", "display_name": "地獄秋季", "power_tier": 3, "fragment_name": "地獄秋季碎片", "fragment_count": 2, "key_ready": false},
			{"variant_id": "heaven_autumn", "display_name": "天堂秋季", "power_tier": 4, "fragment_name": "天堂秋季碎片", "fragment_count": 0, "key_ready": false},
		])
		await process_frame
		var panel := ui.get_node("Center/Panel") as Control
		var buttons := ui.call("get_option_buttons") as Array
		_expect(panel.get_global_rect().intersection(Rect2(Vector2.ZERO, viewport_size)).size == panel.get_global_rect().size, "Variant panel must remain inside %s." % viewport_size)
		_expect(buttons.size() == 3, "Variant selector must use one direct button per available world.")
		_expect(
			String((buttons[0] as Button).text).contains("秋天碎片  4/4")
				and String((buttons[1] as Button).text).contains("強度 3")
				and String((buttons[2] as Button).text).contains("天堂秋季"),
			"Variant buttons must expose world name, strict strength tier, and independent fragment progress."
		)
		viewport.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
