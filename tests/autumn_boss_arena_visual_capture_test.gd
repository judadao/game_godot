extends SceneTree

const ARENA_SCENE := preload("res://scenes/maps/boss/AutumnBossArena.tscn")
const CAPTURE_SIZE := Vector2i(1920, 1664)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment("AUTUMN_BOSS_CAPTURE_DIR")
	if output_dir.is_empty():
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)

	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var arena := ARENA_SCENE.instantiate()
	viewport.add_child(arena)
	for camera_node in arena.find_children("*", "Camera2D", true, false):
		(camera_node as Camera2D).enabled = false
	for helper_path in ["EditorHUDReference", "EditorHelpers"]:
		var helper := arena.get_node_or_null(helper_path)
		if helper is CanvasItem:
			(helper as CanvasItem).visible = false
	var camera := Camera2D.new()
	camera.position = Vector2(CAPTURE_SIZE) * 0.5
	camera.enabled = true
	arena.add_child(camera)
	var director := arena.get_node("RegionalBossDirector")
	director.call("start_encounter")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	var full_path := output_dir.path_join("autumn_boss_arena_full.png")
	if image.save_png(full_path) != OK:
		push_error("Could not save autumn boss arena full-frame capture.")
		quit(1)
		return
	var slice_size := Vector2i(CAPTURE_SIZE.x / 3, CAPTURE_SIZE.y / 2)
	for row in 2:
		for column in 3:
			var origin := Vector2i(column * slice_size.x, row * slice_size.y)
			var width := slice_size.x if column < 2 else CAPTURE_SIZE.x - origin.x
			var height := slice_size.y if row < 1 else CAPTURE_SIZE.y - origin.y
			var slice := image.get_region(Rect2i(origin, Vector2i(width, height)))
			var slice_path := output_dir.path_join(
				"autumn_boss_arena_r%dc%d.png" % [row + 1, column + 1]
			)
			if slice.save_png(slice_path) != OK:
				push_error("Could not save autumn boss arena slice %s." % slice_path)
				quit(1)
				return
	quit(0)
