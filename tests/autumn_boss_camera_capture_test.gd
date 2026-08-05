extends SceneTree

const ARENA_SCENE := preload("res://scenes/maps/boss/AutumnBossArena.tscn")
const CAPTURE_SIZE := Vector2i(1920, 800)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := OS.get_environment("AUTUMN_BOSS_CAMERA_CAPTURE_PATH")
	if output_path.is_empty():
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var arena := ARENA_SCENE.instantiate()
	viewport.add_child(arena)
	for helper_path in ["EditorHUDReference", "EditorHelpers"]:
		var helper := arena.get_node_or_null(helper_path)
		if helper is CanvasItem:
			(helper as CanvasItem).visible = false
	var director := arena.get_node("RegionalBossDirector")
	director.call("start_encounter")
	await process_frame
	var camera := arena.get_node("ArenaOverviewCamera") as Camera2D
	camera.position = Vector2(960, 1280)
	var active_bosses: Array = director.call("get_active_enemies")
	if active_bosses.size() == 1:
		(active_bosses[0] as Node2D).global_position = Vector2(960, 1660)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.save_png(output_path) != OK:
		push_error("Could not save autumn boss camera capture.")
		quit(1)
		return
	quit(0)
