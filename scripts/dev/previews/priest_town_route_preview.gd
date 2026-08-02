extends Node2D

const CAPTURE_PATH_ENV := "PRIEST_ROUTE_CAPTURE_PATH"
const CAPTURE_STATE_ENV := "PRIEST_ROUTE_CAPTURE_STATE"
const SLICE_DIRECTORY_ENV := "PRIEST_ROUTE_SLICE_DIR"

@onready var route_camera: Camera2D = $RouteCamera


func _ready() -> void:
	var player_camera := get_node_or_null("Town/Player/Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false
	route_camera.enabled = true
	route_camera.make_current()
	if OS.has_environment(CAPTURE_PATH_ENV):
		call_deferred("_capture_route_state")


func _capture_route_state() -> void:
	var priest := get_node_or_null("Town/NPCs/Mayor")
	if priest == null:
		push_error("Priest route preview could not resolve Town/NPCs/Mayor.")
		get_tree().quit(1)
		return
	priest.set_process(false)
	priest.set("home_wait_seconds", 0.1)
	priest.set("chat_seconds", 0.1)
	priest.set("walk_speed", 600.0)
	var requested_state := OS.get_environment(CAPTURE_STATE_ENV).strip_edges()
	match requested_state:
		"walk_to_witch":
			priest.call("advance_behavior", 0.11)
			priest.call("advance_behavior", 0.25)
		"chat_with_witch":
			_advance_until_state(priest, &"chat_with_witch")
		"walk_home":
			_advance_until_state(priest, &"chat_with_witch")
			priest.call("advance_behavior", 0.11)
			priest.call("advance_behavior", 0.25)
		_:
			pass
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var path := OS.get_environment(CAPTURE_PATH_ENV).strip_edges()
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save priest Town route preview to %s." % path)
	else:
		_save_equal_slices(image, requested_state)
	get_tree().quit(0 if error == OK else 1)


func _advance_until_state(priest: Node, target_state: StringName) -> void:
	for _step in range(200):
		if priest.call("get_behavior_state") == target_state:
			return
		priest.call("advance_behavior", 0.05)


func _save_equal_slices(image: Image, state: String) -> void:
	var directory := OS.get_environment(SLICE_DIRECTORY_ENV).strip_edges()
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var slice_size := Vector2i(image.get_width() / 3, image.get_height() / 2)
	var origin_x := (image.get_width() - slice_size.x * 3) / 2
	for row in range(2):
		for column in range(3):
			var region := image.get_region(Rect2i(
				Vector2i(origin_x + column * slice_size.x, row * slice_size.y),
				slice_size
			))
			var output_path := directory.path_join(
				"town_%s_r%d_c%d.png" % [state, row + 1, column + 1]
			)
			if region.save_png(output_path) != OK:
				push_error("Failed to save priest Town review slice to %s." % output_path)
