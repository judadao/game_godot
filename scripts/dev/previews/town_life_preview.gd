extends Node

const CAPTURE_PATH_ENV := "TOWN_LIFE_CAPTURE_PATH"
const CAPTURE_TIME_ENV := "TOWN_LIFE_CAPTURE_TIME"
const SLICE_DIRECTORY_ENV := "TOWN_LIFE_SLICE_DIR"

@onready var life_viewport: SubViewport = $TownViewport
@onready var life_camera: Camera2D = $TownViewport/LifeCamera


func _ready() -> void:
	var player_camera := get_node_or_null("TownViewport/Town/Player/Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false
	life_camera.enabled = true
	life_camera.make_current()
	if OS.has_environment(CAPTURE_PATH_ENV):
		call_deferred("_capture_living_town")


func _capture_living_town() -> void:
	var actors := get_tree().get_nodes_in_group("town_life_npcs")
	for actor in actors:
		actor.set_process(false)
	var priest := get_node_or_null("TownViewport/Town/NPCs/Mayor")
	if priest != null:
		priest.set_process(false)
	var target_time := maxf(0.0, float(OS.get_environment(CAPTURE_TIME_ENV)))
	var elapsed := 0.0
	while elapsed < target_time:
		var step := minf(0.05, target_time - elapsed)
		for actor in actors:
			actor.call("advance_life", step)
		if priest != null:
			priest.call("advance_behavior", step)
		elapsed += step
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var image := life_viewport.get_texture().get_image()
	var capture_path := OS.get_environment(CAPTURE_PATH_ENV).strip_edges()
	var error := image.save_png(capture_path)
	if error == OK:
		_save_equal_slices(image, int(round(target_time)))
	else:
		push_error("Failed to save Town life preview to %s." % capture_path)
	get_tree().quit(0 if error == OK else 1)


func _save_equal_slices(image: Image, sample_second: int) -> void:
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
				"town_life_t%02d_r%d_c%d.png" % [sample_second, row + 1, column + 1]
			)
			if region.save_png(output_path) != OK:
				push_error("Failed to save Town life review slice to %s." % output_path)
