extends SceneTree

const HUB_SCENE := preload("res://scenes/maps/battle_portal_hub.tscn")
const HELL_ROUTE_SCENE := preload("res://scenes/maps/expedition/HellRoute.tscn")
const CRYSTAL_ROUTE_SCENE := preload("res://scenes/maps/expedition/CrystalRoute.tscn")
const CAPTURE_DIRECTORY := "user://test_artifacts/expedition_visuals"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		await _check_hub_layout(viewport_size)
	await _check_six_route_zones()
	await _check_crystal_modular_terrain()
	quit(1 if _failures > 0 else 0)


func _check_hub_layout(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var hub := HUB_SCENE.instantiate()
	viewport.add_child(hub)
	hub.call(
		"configure_progression",
		{"chapter_id": "chapter_04"},
		{"heaven_autumn": 4},
		{"heaven_autumn": 4},
		{"heaven_autumn": true},
		{}
	)
	await process_frame
	await process_frame
	var safe_rect := Rect2(Vector2.ZERO, Vector2(1600, 720))
	for label_path in [
		"PortalLabels/AutumnLabel", "PortalLabels/CrystalLabel",
		"PortalLabels/HellLabel", "PortalLabels/HeavenLabel", "BossLabel",
	]:
		var label := hub.get_node(label_path) as Control
		_expect(safe_rect.encloses(label.get_global_rect()), "%s must remain inside %s." % [label_path, viewport_size])
	if _capture_requested():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIRECTORY))
		await RenderingServer.frame_post_draw
		_expect(viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(CAPTURE_DIRECTORY.path_join("portal_hub_%dx%d.png" % [viewport_size.x, viewport_size.y]))
		) == OK, "Portal sanctuary capture must save.")
	viewport.queue_free()
	await process_frame


func _check_six_route_zones() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var route := HELL_ROUTE_SCENE.instantiate()
	viewport.add_child(route)
	for player_camera in route.find_children("*", "Camera2D", true, false):
		(player_camera as Camera2D).enabled = false
	var camera := Camera2D.new()
	camera.enabled = true
	camera.position = Vector2(640, 360)
	route.add_child(camera)
	await process_frame
	await process_frame
	_expect(route.get_node("GeneratedRoute").get_child_count() >= 24, "A completed route must expose at least 24 modular chunks.")
	if _capture_requested():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIRECTORY))
		for zone_index in 6:
			camera.position.x = lerpf(640.0, 9920.0, float(zone_index) / 5.0)
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(viewport.get_texture().get_image().save_png(
				ProjectSettings.globalize_path(CAPTURE_DIRECTORY.path_join("hell_route_zone_%d.png" % (zone_index + 1)))
			) == OK, "Six-zone route capture must save.")
	viewport.queue_free()
	await process_frame


func _check_crystal_modular_terrain() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var route := CRYSTAL_ROUTE_SCENE.instantiate()
	viewport.add_child(route)
	for player_camera in route.find_children("*", "Camera2D", true, false):
		(player_camera as Camera2D).enabled = false
	var camera := Camera2D.new()
	camera.enabled = true
	camera.position = Vector2(640, 360)
	route.add_child(camera)
	await process_frame
	await process_frame
	var generated_route := route.get_node("GeneratedRoute")
	_expect(
		generated_route.find_children("TerrainFloorPanel*", "Sprite2D", true, false).size() >= 8,
		"Crystal must render a continuous modular floor across the full route."
	)
	_expect(
		generated_route.find_children("TerrainPlatformArt", "Sprite2D", true, false).size() >= 20,
		"Crystal platforms must use the replaceable hand-drawn terrain atlas."
	)
	_expect(route.has_node("GeneratedRoute/RouteFloorCollision"), "Crystal must retain an independent full-width floor collision.")
	if _capture_requested():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIRECTORY))
		for zone_index in 6:
			camera.position.x = lerpf(640.0, 9920.0, float(zone_index) / 5.0)
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(viewport.get_texture().get_image().save_png(
				ProjectSettings.globalize_path(CAPTURE_DIRECTORY.path_join("crystal_route_zone_%d.png" % (zone_index + 1)))
			) == OK, "Crystal six-zone capture must save.")
	viewport.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _capture_requested() -> bool:
	return "--capture" in OS.get_cmdline_user_args()
