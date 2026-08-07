extends SceneTree

const BLACKSMITH_SCENE := preload("res://scenes/ui/town/PlayerBlacksmithUI.tscn")
const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0
var _capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("BLACKSMITH_SHOP_CAPTURE_DIR").strip_edges()
	if not _capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_directory)
	for viewport_size in VIEWPORT_SIZES:
		await _check_ui(BLACKSMITH_SCENE, "blacksmith", "PlayerBlacksmithWindow", viewport_size)
		await _check_ui(MARKET_SCENE, "market", "PlayerMarketWindow", viewport_size)
	if _failures == 0:
		print("PASS: blacksmith workshop and market remain safe at all six required resolutions")
	quit(_failures)


func _check_ui(scene: PackedScene, prefix: String, window_name: String, viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("080a0d")
	viewport.add_child(background)
	var ui := scene.instantiate() as Control
	viewport.add_child(ui)
	ui.call("open")
	await process_frame
	await process_frame
	var window := ui.find_child(window_name, true, false) as Control
	_expect(window != null and window.is_visible_in_tree(), "%s window must render at %s." % [prefix, viewport_size])
	if window != null:
		var bounds := _transformed_bounds(window)
		_expect(
			Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(bounds),
			"%s window must stay inside %s; got %s." % [prefix, viewport_size, bounds]
		)
	if not _capture_directory.is_empty():
		await process_frame
		var image := viewport.get_texture().get_image()
		var base_name := "%s_%dx%d" % [prefix, viewport_size.x, viewport_size.y]
		if image == null:
			_expect(false, "%s graphical capture needs a rendering driver at %s." % [prefix, viewport_size])
			viewport.queue_free()
			await process_frame
			return
		_expect(
			not image.is_empty()
				and image.save_png(_capture_directory.path_join("%s.png" % base_name)) == OK,
			"%s capture must save at %s." % [prefix, viewport_size]
		)
		if viewport_size == Vector2i(1920, 1080):
			_save_slices(image, base_name)
			if prefix == "market":
				var product_button := ui.find_child("Product1InteractButton", true, false) as Button
				if product_button != null:
					product_button.pressed.emit()
					await process_frame
					await process_frame
					var management_image := viewport.get_texture().get_image()
					var management_name := "market_management_1920x1080"
					_expect(
						management_image != null
							and management_image.save_png(_capture_directory.path_join("%s.png" % management_name)) == OK,
						"Market side-dock capture must save."
					)
					if management_image != null:
						_save_slices(management_image, management_name)
	viewport.queue_free()
	await process_frame


func _transformed_bounds(control: Control) -> Rect2:
	var transform := control.get_global_transform()
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0),
		transform * control.size,
		transform * Vector2(0, control.size.y),
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds


func _save_slices(image: Image, base_name: String) -> void:
	var slice_size := Vector2i(image.get_width() / 3, image.get_height() / 2)
	for row in 2:
		for column in 3:
			var index := row * 3 + column + 1
			var region := Rect2i(column * slice_size.x, row * slice_size.y, slice_size.x, slice_size.y)
			var slice := image.get_region(region)
			_expect(
				slice.save_png(_capture_directory.path_join("%s_slice_%d.png" % [base_name, index])) == OK,
				"%s review slice %d must save." % [base_name, index]
			)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
