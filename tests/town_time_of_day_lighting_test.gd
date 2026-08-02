extends SceneTree

const TOWN_SCENE := "res://scenes/maps/town.tscn"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load(TOWN_SCENE) as PackedScene).instantiate()
	root.add_child(town)
	_expect(town.has_method("set_time_of_day_progress"), "Town must expose synchronized time-of-day lighting.")
	_expect(town.has_method("set_time_of_day_preset"), "Town must expose stable day/golden-hour presets.")
	if town.has_method("set_time_of_day_progress"):
		town.call("set_time_of_day_progress", 0.5)
		_assert_day_state(town)
		town.call("set_time_of_day_progress", 1.0)
		_assert_golden_state(town)
	town.queue_free()
	await _capture_golden_hour()
	_finish()


func _assert_day_state(town: Node) -> void:
	var sky := town.get_node("ParallaxBackground/Sky")
	var clouds := town.get_node("ParallaxBackground/Clouds")
	var modular := town.get_node("ParallaxBackground/ModularVisuals") as CanvasItem
	var npcs := town.get_node("NPCs") as CanvasItem
	_expect(sky.call("get_sky_tint").is_equal_approx(Color.WHITE), "Before golden hour, sky tint must stay neutral.")
	_expect(_first_cloud_tint(clouds).is_equal_approx(Color.WHITE), "Before golden hour, cloud tint must stay neutral.")
	_expect(modular.modulate.is_equal_approx(Color.WHITE), "Before golden hour, Town structures must stay neutral.")
	_expect(npcs.modulate.is_equal_approx(Color.WHITE), "Before golden hour, Town NPC lighting must stay neutral.")


func _assert_golden_state(town: Node) -> void:
	var sky := town.get_node("ParallaxBackground/Sky")
	var clouds := town.get_node("ParallaxBackground/Clouds")
	var modular := town.get_node("ParallaxBackground/ModularVisuals") as CanvasItem
	var npcs := town.get_node("NPCs") as CanvasItem
	var portals := town.get_node("Portals") as CanvasItem
	var player := town.get_node("Player") as CanvasItem
	var sky_grade := sky.call("get_sky_grade") as Dictionary
	var cloud_tint := _first_cloud_tint(clouds)
	_expect(
		float(sky_grade.get("strength", 0.0)) > 0.5
			and (sky_grade.get("color", Color.WHITE) as Color).r > (sky_grade.get("color", Color.WHITE) as Color).b,
		"Golden hour must apply a warm color grade to the independent sky."
	)
	_expect(cloud_tint != Color.WHITE and cloud_tint.r > cloud_tint.b, "Golden hour must warm the independent clouds.")
	for target in [modular, npcs, portals, player]:
		_expect(
			target.modulate != Color.WHITE and target.modulate.r > target.modulate.b,
			"Golden hour must synchronize Town structures, NPCs, portals, and player lighting."
		)


func _first_cloud_tint(clouds: Node) -> Color:
	for child in clouds.get_children():
		if child is Sprite2D:
			var material := (child as Sprite2D).material as ShaderMaterial
			if material != null:
				return material.get_shader_parameter("cloud_tint") as Color
	return Color.TRANSPARENT


func _capture_golden_hour() -> void:
	var capture_directory := OS.get_environment("TOWN_TIME_OF_DAY_CAPTURE_DIR")
	if capture_directory.is_empty():
		return
	_expect(DirAccess.make_dir_recursive_absolute(capture_directory) == OK, "Golden-hour capture directory must be writable.")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1942, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var town := (load(TOWN_SCENE) as PackedScene).instantiate()
	_disable_cameras(town)
	viewport.add_child(town)
	town.call("set_time_of_day_preset", &"golden_hour")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := viewport.get_texture().get_image()
	_expect(frame.save_png(capture_directory.path_join("town_golden_hour_full.png")) == OK, "Golden-hour full frame must save.")
	var x_edges := [0, 647, 1294, frame.get_width()]
	var y_edges := [0, 360, frame.get_height()]
	for row in range(2):
		for column in range(3):
			var region := Rect2i(x_edges[column], y_edges[row], x_edges[column + 1] - x_edges[column], y_edges[row + 1] - y_edges[row])
			var output_path := capture_directory.path_join("town_golden_hour_r%d_c%d.png" % [row + 1, column + 1])
			_expect(frame.get_region(region).save_png(output_path) == OK, "Golden-hour slice must save: %s" % output_path)
	viewport.queue_free()
	await process_frame


func _disable_cameras(node: Node) -> void:
	if node is Camera2D:
		(node as Camera2D).enabled = false
	for child in node.get_children():
		_disable_cameras(child)


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town synchronized golden-hour lighting contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
