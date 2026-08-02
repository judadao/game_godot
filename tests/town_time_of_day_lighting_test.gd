extends SceneTree

const TOWN_SCENE := "res://scenes/maps/town.tscn"
const TOWN_SKY_SCENE := "res://scenes/maps/town/components/TownSkyLayer.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"
const HOUR_14 := 14.0 / 24.0
const HOUR_14_59 := (14.0 + 59.0 / 60.0) / 24.0
const HOUR_15 := 15.0 / 24.0
const HOUR_15_15 := 15.25 / 24.0
const HOUR_15_30 := 15.5 / 24.0
const HOUR_16_30 := 16.5 / 24.0
const HOUR_17 := 17.0 / 24.0
const HOUR_17_30 := 17.5 / 24.0
const HOUR_18 := 18.0 / 24.0

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load(TOWN_SCENE) as PackedScene).instantiate()
	root.add_child(town)
	_expect(town.has_method("set_time_of_day_progress"), "Town must expose synchronized time-of-day lighting.")
	_expect(town.has_method("set_time_of_day_preset"), "Town must expose stable day/golden-hour presets.")
	if town.has_method("set_time_of_day_progress"):
		town.call("set_time_of_day_progress", HOUR_14)
		_assert_day_state(town)
		town.call("set_time_of_day_progress", HOUR_15_15)
		_assert_golden_transition_state(town)
		town.call("set_time_of_day_progress", HOUR_17)
		_assert_golden_state(town)
		town.call("set_time_of_day_progress", HOUR_18)
		_assert_evening_state(town)
	town.queue_free()
	await _capture_golden_hour()
	_finish()


func _assert_day_state(town: Node) -> void:
	var sky := town.get_node("ParallaxBackground/Sky")
	var clouds := town.get_node("ParallaxBackground/Clouds")
	var modular := town.get_node("ParallaxBackground/ModularVisuals") as CanvasItem
	var npcs := town.get_node("NPCs") as CanvasItem
	var atmosphere := town.get_node_or_null("TownAtmosphere")
	_expect(sky.call("get_sky_tint").is_equal_approx(Color.WHITE), "Before golden hour, sky tint must stay neutral.")
	_expect(_first_cloud_tint(clouds).is_equal_approx(Color.WHITE), "Before golden hour, cloud tint must stay neutral.")
	_expect(modular.modulate.is_equal_approx(Color.WHITE), "Before golden hour, Town structures must stay neutral.")
	_expect(npcs.modulate.is_equal_approx(Color.WHITE), "Before golden hour, Town NPC lighting must stay neutral.")
	_expect(atmosphere != null, "Town must own a viewport atmosphere color grade below HUD layers.")
	if atmosphere != null:
		_expect(atmosphere.layer < 10, "Town atmosphere must stay below the HUD CanvasLayer.")
		_expect(_atmosphere_intensity(atmosphere) <= 0.001, "Town atmosphere must be neutral before 15:00.")
		_expect(_atmosphere_parameter(atmosphere, "sunlight_strength") <= 0.001, "Directional sunlight must be neutral before golden hour.")


func _assert_golden_transition_state(town: Node) -> void:
	var contract := town.call("get_time_of_day_contract") as Dictionary
	_expect(float(contract.get("golden_weight", 0.0)) > 0.0, "Golden light must start ramping after 15:00.")
	_expect(float(contract.get("golden_weight", 0.0)) < 1.0, "15:30 must still be a gradual golden-hour transition.")
	_expect(float(contract.get("hour", 0.0)) > 15.0, "Town time contract must expose the current clock hour.")


func _assert_golden_state(town: Node) -> void:
	var sky := town.get_node("ParallaxBackground/Sky")
	var clouds := town.get_node("ParallaxBackground/Clouds")
	var modular := town.get_node("ParallaxBackground/ModularVisuals") as CanvasItem
	var npcs := town.get_node("NPCs") as CanvasItem
	var portals := town.get_node("Portals") as CanvasItem
	var player := town.get_node("Player") as CanvasItem
	var sky_grade := sky.call("get_sky_grade") as Dictionary
	var cloud_tint := _first_cloud_tint(clouds)
	var atmosphere := town.get_node("TownAtmosphere")
	var contract := town.call("get_time_of_day_contract") as Dictionary
	_expect(
		float(sky_grade.get("strength", 0.0)) > 0.5
			and (sky_grade.get("horizon_color", Color.WHITE) as Color).r
				> (sky_grade.get("horizon_color", Color.WHITE) as Color).b,
		"Golden hour must apply a warm horizon grade to the independent sky."
	)
	_expect(cloud_tint != Color.WHITE and cloud_tint.r > cloud_tint.b, "Golden hour must warm the independent clouds.")
	for target in [modular, npcs, portals, player]:
		_expect(
			target.modulate != Color.WHITE and target.modulate.r > target.modulate.b,
			"Golden hour must synchronize Town structures, NPCs, portals, and player lighting."
		)
	_expect(modular.modulate.b > 0.88, "Town materials must retain their authored color instead of sitting under a strong yellow filter.")
	_expect(npcs.modulate.b > 0.92, "Character skin, cloth, and metal must not be globally yellowed by sunset lighting.")
	_expect(_atmosphere_intensity(atmosphere) > 0.1, "Golden hour must apply a restrained split-tone atmosphere grade.")
	_expect(_atmosphere_intensity(atmosphere) < 0.25, "The global atmosphere grade must stay secondary to object-readable directional light.")
	_expect(_atmosphere_parameter(atmosphere, "sunlight_strength") > 0.75, "Golden hour must cast clearly visible left-to-right sunlight across every Town object.")
	_expect(_atmosphere_parameter(atmosphere, "cloud_shadow_strength") > 0.16, "Golden hour must include readable soft cloud shade across trees, buildings, and streets.")
	_expect(_atmosphere_parameter(atmosphere, "cozy_palette_strength") > 0.1, "Golden hour must gently unify saturation across Town materials.")
	_expect(_atmosphere_parameter(atmosphere, "cozy_palette_strength") < 0.24, "Palette unification must not flatten every material into the same yellow hue.")
	_expect(float(contract.get("golden_weight", 0.0)) > 0.9, "17:00 must sit near the golden-hour peak.")
	_expect(float(contract.get("golden_plateau_hours", 0.0)) > float(contract.get("golden_transition_hours", 99.0)), "The full-gold plateau must be the longest part of the 15:00–18:00 window.")
	var shadow_field_count := int(contract.get("cloud_shadow_count", 0))
	_expect(shadow_field_count >= 2 and shadow_field_count <= 4, "Moving cloud shade must use two to four broad low-frequency fields, not repeated per-cloud stickers.")
	_expect(bool(contract.get("affects_all_world_objects", false)), "Sunset lighting must grade every Town world object below the HUD.")
	_expect(bool(contract.get("cozy_palette_unification", false)), "Sunset lighting must present Town objects through one coherent cozy palette.")
	_expect(int(contract.get("excluded_canvas_layer", 0)) == 10, "Sunset lighting must stop below the HUD CanvasLayer.")
	var sun_direction := contract.get("sun_direction", Vector2.ZERO) as Vector2
	_expect(sun_direction.x > 0.9 and sun_direction.y > 0.0, "Golden sunlight must travel from left to right and slightly downward.")
	_assert_cloud_shadows_move(town)


func _assert_evening_state(town: Node) -> void:
	var sky := town.get_node("ParallaxBackground/Sky")
	var contract := town.call("get_time_of_day_contract") as Dictionary
	var sky_grade := sky.call("get_sky_grade") as Dictionary
	_expect(float(contract.get("golden_weight", 1.0)) <= 0.001, "Golden light must finish by 18:00.")
	_expect(float(contract.get("dusk_weight", 0.0)) > 0.9, "18:00 must transition into the evening palette.")
	var zenith := sky_grade.get("zenith_color", Color.WHITE) as Color
	var horizon := sky_grade.get("horizon_color", Color.WHITE) as Color
	_expect(zenith.b > zenith.r, "Evening sky zenith must cool toward blue-violet.")
	_expect(horizon.r > horizon.b, "Evening horizon must retain the sunset afterglow.")


func _atmosphere_intensity(atmosphere: Node) -> float:
	var color_grade := atmosphere.get_node_or_null("ColorGrade") as ColorRect
	if color_grade == null:
		return -1.0
	var material := color_grade.material as ShaderMaterial
	if material == null:
		return -1.0
	return float(material.get_shader_parameter("grade_strength"))


func _atmosphere_parameter(atmosphere: Node, parameter: StringName) -> float:
	var color_grade := atmosphere.get_node_or_null("ColorGrade") as ColorRect
	if color_grade == null:
		return -1.0
	var material := color_grade.material as ShaderMaterial
	if material == null:
		return -1.0
	var value: Variant = material.get_shader_parameter(parameter)
	if value == null:
		return -1.0
	return float(value)


func _assert_cloud_shadows_move(town: Node) -> void:
	var atmosphere := town.get_node("TownAtmosphere")
	var material := (atmosphere.get_node("ColorGrade") as ColorRect).material as ShaderMaterial
	var before_value: Variant = material.get_shader_parameter("cloud_shadows")
	var shape_value: Variant = material.get_shader_parameter("cloud_shadow_shapes")
	var before := PackedVector4Array()
	var shapes := PackedVector4Array()
	if before_value is PackedVector4Array:
		before = before_value as PackedVector4Array
	if shape_value is PackedVector4Array:
		shapes = shape_value as PackedVector4Array
	var clouds := town.get_node("ParallaxBackground/Clouds")
	clouds.call("advance_clouds", 5.0)
	town.call("refresh_cloud_shadows")
	var after_value: Variant = material.get_shader_parameter("cloud_shadows")
	var after := PackedVector4Array()
	if after_value is PackedVector4Array:
		after = after_value as PackedVector4Array
	_expect(before.size() >= 2 and before.size() <= 4 and after.size() == before.size(), "Cloud-shadow uniforms must expose only the broad active fields.")
	_expect(shapes.size() == before.size(), "Each cloud-shadow field must carry an independent aspect, skew, and contour profile.")
	var shape_signatures: Dictionary = {}
	for shape in shapes:
		shape_signatures["%.3f|%.3f|%.3f|%.3f" % [shape.x, shape.y, shape.z, shape.w]] = true
	_expect(shape_signatures.size() == shapes.size(), "Cloud-shadow fields must not repeat one sticker silhouette.")
	if before.size() > 0 and after.size() > 0:
		var five_second_drift := absf(after[0].x - before[0].x)
		_expect(
			five_second_drift >= 0.015 and five_second_drift <= 0.06,
			"Cloud shade must drift calmly with the visible cloud layer instead of accelerating with player-camera motion."
		)
		var viewport := town.get_viewport()
		var original_canvas_transform := viewport.canvas_transform
		var camera_shift := -80.0
		var shifted_canvas_transform := original_canvas_transform
		shifted_canvas_transform.origin.x += camera_shift
		viewport.canvas_transform = shifted_canvas_transform
		town.call("refresh_cloud_shadows")
		var camera_value: Variant = material.get_shader_parameter("cloud_shadows")
		var camera_shifted := PackedVector4Array()
		if camera_value is PackedVector4Array:
			camera_shifted = camera_value as PackedVector4Array
		if camera_shifted.size() == after.size():
			var expected_screen_shift := camera_shift / maxf(viewport.get_visible_rect().size.x, 1.0)
			var actual_screen_shift := camera_shifted[0].x - after[0].x
			_expect(
				is_equal_approx(actual_screen_shift, expected_screen_shift),
				"Player-camera movement must project cloud shade 1:1 instead of accelerating a dark field around the player."
			)
		viewport.canvas_transform = original_canvas_transform
		town.call("refresh_cloud_shadows")


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
	for capture in [
		{"label": "14_59_baseline", "progress": HOUR_14_59},
		{"label": "15_00_onset", "progress": HOUR_15},
		{"label": "15_30_transition", "progress": HOUR_15_30},
		{"label": "16_30_midpoint", "progress": HOUR_16_30},
		{"label": "17_30_late", "progress": HOUR_17_30},
		{"label": "18_00_evening", "progress": HOUR_18},
	]:
		town.call("set_time_of_day_progress", float(capture["progress"]))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		var label := String(capture["label"])
		_expect(frame.save_png(capture_directory.path_join("town_%s_full.png" % label)) == OK, "Town time-of-day full frame must save: %s" % label)
		var x_edges := [0, 647, 1294, frame.get_width()]
		var y_edges := [0, 360, frame.get_height()]
		for row in range(2):
			for column in range(3):
				var region := Rect2i(x_edges[column], y_edges[row], x_edges[column + 1] - x_edges[column], y_edges[row + 1] - y_edges[row])
				var output_path := capture_directory.path_join("town_%s_r%d_c%d.png" % [label, row + 1, column + 1])
				_expect(frame.get_region(region).save_png(output_path) == OK, "Town time-of-day slice must save: %s" % output_path)
	await _capture_timeline_contact_sheet(viewport, town, capture_directory)
	await _capture_peak_cloud_shadow_sequence(viewport, town, capture_directory)
	await _capture_foliage_breeze_sequence(viewport, town, capture_directory)
	await _capture_lighting_diagnostics(viewport, town, capture_directory)
	await _capture_sky_native_details(town, capture_directory)
	await _capture_cloud_native_details(town, capture_directory)
	viewport.queue_free()
	await process_frame
	await _capture_runtime_game_flow(capture_directory)


func _capture_timeline_contact_sheet(viewport: SubViewport, town: Node, capture_directory: String) -> void:
	const THUMBNAIL_SIZE := Vector2i(486, 180)
	const COLUMN_COUNT := 4
	const SAMPLE_COUNT := 13
	var row_count := ceili(float(SAMPLE_COUNT) / float(COLUMN_COUNT))
	var sheet := Image.create(THUMBNAIL_SIZE.x * COLUMN_COUNT, THUMBNAIL_SIZE.y * row_count, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("151925"))
	for index in range(SAMPLE_COUNT):
		var hour := 15.0 + float(index) * 0.25
		town.call("set_time_of_day_hour", hour)
		await process_frame
		await RenderingServer.frame_post_draw
		var thumbnail := viewport.get_texture().get_image()
		thumbnail.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_NEAREST)
		thumbnail.convert(Image.FORMAT_RGBA8)
		var destination := Vector2i(
			(index % COLUMN_COUNT) * THUMBNAIL_SIZE.x,
			(index / COLUMN_COUNT) * THUMBNAIL_SIZE.y
		)
		sheet.blit_rect(thumbnail, Rect2i(Vector2i.ZERO, THUMBNAIL_SIZE), destination)
	var output_path := capture_directory.path_join("town_15_00_to_18_00_quarter_hour_contact_sheet.png")
	_expect(sheet.save_png(output_path) == OK, "Town quarter-hour contact sheet must save.")


func _capture_runtime_game_flow(capture_directory: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var game := (load(GAME_SCENE) as PackedScene).instantiate()
	viewport.add_child(game)
	for _frame in 6:
		await process_frame
	var town: Node = game.call("get_current_map")
	_expect(town != null, "Main game flow must load the authoritative Town map for lighting review.")
	if town == null:
		viewport.queue_free()
		await process_frame
		return
	_expect(
		town.scene_file_path == "res://scenes/maps/town/TownMap.tscn",
		"Runtime sunset review must use the same TownMap scene loaded by game.tscn."
	)
	for capture in [
		{"label": "14_59_baseline", "hour": 14.0 + 59.0 / 60.0},
		{"label": "15_00_onset", "hour": 15.0},
		{"label": "15_30_transition", "hour": 15.5},
		{"label": "16_30_midpoint", "hour": 16.5},
		{"label": "17_30_late", "hour": 17.5},
		{"label": "18_00_evening", "hour": 18.0},
	]:
		town.call("set_time_of_day_hour", float(capture["hour"]))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_save_runtime_full_and_slices(
			viewport.get_texture().get_image(),
			capture_directory,
			String(capture["label"])
		)
	await _capture_runtime_timeline_contact_sheet(viewport, town, capture_directory)
	var clouds := town.get_node("ParallaxBackground/Clouds")
	clouds.process_mode = Node.PROCESS_MODE_DISABLED
	town.call("set_time_of_day_hour", 17.0)
	var previous_elapsed_seconds := 0
	for elapsed_seconds in [0, 10, 60, 120]:
		if elapsed_seconds > previous_elapsed_seconds:
			clouds.call(
				"advance_clouds",
				float(elapsed_seconds - previous_elapsed_seconds)
			)
		previous_elapsed_seconds = elapsed_seconds
		town.call("refresh_cloud_shadows")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_save_runtime_full_and_slices(
			viewport.get_texture().get_image(),
			capture_directory,
			"17_00_cloud_shadow_t%02d" % elapsed_seconds
		)
	clouds.process_mode = Node.PROCESS_MODE_INHERIT
	var runtime_color_grade := town.get_node("TownAtmosphere/ColorGrade") as ColorRect
	var runtime_material := runtime_color_grade.material as ShaderMaterial
	runtime_material.set_shader_parameter("debug_view", 3)
	town.call("refresh_cloud_shadows")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save_runtime_full_and_slices(
		viewport.get_texture().get_image(),
		capture_directory,
		"17_00_cloud_shadow_debug"
	)
	runtime_material.set_shader_parameter("debug_view", 0)
	var runtime_ambient := town.get_node("ParallaxBackground/AmbientAnimation")
	runtime_ambient.process_mode = Node.PROCESS_MODE_DISABLED
	for elapsed_seconds in [0, 3, 6]:
		runtime_ambient.set("_ambient_time", float(elapsed_seconds))
		runtime_ambient.call("_apply_calm_pose")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_save_runtime_full_and_slices(
			viewport.get_texture().get_image(),
			capture_directory,
			"17_00_foliage_breeze_t%02d" % elapsed_seconds
		)
	runtime_ambient.process_mode = Node.PROCESS_MODE_INHERIT
	viewport.queue_free()
	await process_frame


func _capture_runtime_timeline_contact_sheet(
	viewport: SubViewport,
	town: Node,
	capture_directory: String
) -> void:
	const THUMBNAIL_SIZE := Vector2i(320, 180)
	const COLUMN_COUNT := 4
	const SAMPLE_COUNT := 13
	var row_count := ceili(float(SAMPLE_COUNT) / float(COLUMN_COUNT))
	var sheet := Image.create(
		THUMBNAIL_SIZE.x * COLUMN_COUNT,
		THUMBNAIL_SIZE.y * row_count,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color("151925"))
	for index in range(SAMPLE_COUNT):
		town.call("set_time_of_day_hour", 15.0 + float(index) * 0.25)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var thumbnail := viewport.get_texture().get_image()
		thumbnail.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_NEAREST)
		thumbnail.convert(Image.FORMAT_RGBA8)
		var destination := Vector2i(
			(index % COLUMN_COUNT) * THUMBNAIL_SIZE.x,
			(index / COLUMN_COUNT) * THUMBNAIL_SIZE.y
		)
		sheet.blit_rect(thumbnail, Rect2i(Vector2i.ZERO, THUMBNAIL_SIZE), destination)
	var output_path := capture_directory.path_join("runtime_15_00_to_18_00_quarter_hour_contact_sheet.png")
	_expect(sheet.save_png(output_path) == OK, "Runtime Town quarter-hour contact sheet must save.")


func _save_runtime_full_and_slices(
	frame: Image,
	capture_directory: String,
	label: String
) -> void:
	var full_path := capture_directory.path_join("runtime_town_%s_full.png" % label)
	_expect(frame.save_png(full_path) == OK, "Runtime Town full frame must save: %s" % full_path)
	var x_edges := [0, frame.get_width() / 3, frame.get_width() * 2 / 3, frame.get_width()]
	var y_edges := [0, frame.get_height() / 2, frame.get_height()]
	for row in range(2):
		for column in range(3):
			var region := Rect2i(
				x_edges[column],
				y_edges[row],
				x_edges[column + 1] - x_edges[column],
				y_edges[row + 1] - y_edges[row]
			)
			var output_path := capture_directory.path_join(
				"runtime_town_%s_r%d_c%d.png" % [label, row + 1, column + 1]
			)
			_expect(frame.get_region(region).save_png(output_path) == OK, "Runtime Town slice must save: %s" % output_path)


func _capture_peak_cloud_shadow_sequence(viewport: SubViewport, town: Node, capture_directory: String) -> void:
	town.call("set_time_of_day_hour", 17.0)
	var clouds := town.get_node("ParallaxBackground/Clouds")
	clouds.process_mode = Node.PROCESS_MODE_DISABLED
	for elapsed_seconds in [0, 5, 10, 15, 20]:
		if elapsed_seconds > 0:
			clouds.call("advance_clouds", 5.0)
		town.call("refresh_cloud_shadows")
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		var label := "17_00_cloud_shadow_t%02d" % elapsed_seconds
		_save_full_and_slices(frame, capture_directory, label)
	clouds.process_mode = Node.PROCESS_MODE_INHERIT


func _capture_foliage_breeze_sequence(
	viewport: SubViewport,
	town: Node,
	capture_directory: String
) -> void:
	town.call("set_time_of_day_hour", 17.0)
	var ambient := town.get_node("ParallaxBackground/AmbientAnimation")
	ambient.process_mode = Node.PROCESS_MODE_DISABLED
	for elapsed_seconds in [0, 3, 6]:
		ambient.set("_ambient_time", float(elapsed_seconds))
		ambient.call("_apply_calm_pose")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_save_full_and_slices(
			viewport.get_texture().get_image(),
			capture_directory,
			"17_00_foliage_breeze_t%02d" % elapsed_seconds
		)
	ambient.process_mode = Node.PROCESS_MODE_INHERIT


func _capture_lighting_diagnostics(viewport: SubViewport, town: Node, capture_directory: String) -> void:
	town.call("set_time_of_day_hour", 17.0)
	town.call("refresh_cloud_shadows")
	var color_grade := town.get_node("TownAtmosphere/ColorGrade") as ColorRect
	var material := color_grade.material as ShaderMaterial
	for diagnostic in [
		{"label": "sunlight_mask", "mode": 1},
		{"label": "cloud_shadow_mask", "mode": 2},
	]:
		material.set_shader_parameter("debug_view", int(diagnostic["mode"]))
		await process_frame
		await RenderingServer.frame_post_draw
		var output_path := capture_directory.path_join("town_17_00_%s_diagnostic.png" % String(diagnostic["label"]))
		_expect(viewport.get_texture().get_image().save_png(output_path) == OK, "Town lighting diagnostic must save: %s" % output_path)
	material.set_shader_parameter("debug_view", 0)


func _save_full_and_slices(frame: Image, capture_directory: String, label: String) -> void:
	var full_path := capture_directory.path_join("town_%s_full.png" % label)
	_expect(frame.save_png(full_path) == OK, "Town cloud-shadow sequence full frame must save: %s" % full_path)
	var x_edges := [0, 647, 1294, frame.get_width()]
	var y_edges := [0, 360, frame.get_height()]
	for row in range(2):
		for column in range(3):
			var region := Rect2i(x_edges[column], y_edges[row], x_edges[column + 1] - x_edges[column], y_edges[row + 1] - y_edges[row])
			var output_path := capture_directory.path_join("town_%s_r%d_c%d.png" % [label, row + 1, column + 1])
			_expect(frame.get_region(region).save_png(output_path) == OK, "Town cloud-shadow sequence slice must save: %s" % output_path)


func _capture_sky_native_details(town: Node, capture_directory: String) -> void:
	for capture in [
		{"label": "15_00", "hour": 15.0},
		{"label": "16_30", "hour": 16.5},
		{"label": "18_00", "hour": 18.0},
	]:
		town.call("set_time_of_day_hour", float(capture["hour"]))
		var source_sky := town.get_node("ParallaxBackground/Sky")
		var grade := source_sky.call("get_sky_grade") as Dictionary
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1942, 809)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.transparent_bg = false
		root.add_child(viewport)
		var sky := (load(TOWN_SKY_SCENE) as PackedScene).instantiate()
		viewport.add_child(sky)
		await process_frame
		sky.call(
			"set_sky_atmosphere",
			grade.get("zenith_color", Color.WHITE) as Color,
			grade.get("horizon_color", Color.WHITE) as Color,
			float(grade.get("strength", 0.0)),
			grade.get("glow_color", Color.WHITE) as Color,
			float(grade.get("glow_strength", 0.0)),
			float(grade.get("sun_x", 0.12))
		)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		var output_path := capture_directory.path_join("sky_%s_native.png" % String(capture["label"]))
		_expect(viewport.get_texture().get_image().save_png(output_path) == OK, "Runtime sky native detail must save: %s" % output_path)
		viewport.queue_free()
		await process_frame


func _capture_cloud_native_details(town: Node, capture_directory: String) -> void:
	for capture in [
		{"label": "15_00", "hour": 15.0},
		{"label": "18_00", "hour": 18.0},
	]:
		town.call("set_time_of_day_hour", float(capture["hour"]))
		var clouds := town.get_node("ParallaxBackground/Clouds")
		var cloud_index := 0
		for child in clouds.get_children():
			var source_cloud := child as Sprite2D
			if source_cloud == null or source_cloud.texture == null:
				continue
			cloud_index += 1
			var viewport := SubViewport.new()
			viewport.size = Vector2i(source_cloud.texture.get_width(), source_cloud.texture.get_height())
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			viewport.transparent_bg = true
			root.add_child(viewport)
			var cloud := Sprite2D.new()
			cloud.texture = source_cloud.texture
			cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cloud.position = Vector2(viewport.size) * 0.5
			if source_cloud.material != null:
				cloud.material = source_cloud.material.duplicate()
			viewport.add_child(cloud)
			await process_frame
			await RenderingServer.frame_post_draw
			var output_path := capture_directory.path_join(
				"cloud_%s_%02d_native.png" % [String(capture["label"]), cloud_index]
			)
			_expect(viewport.get_texture().get_image().save_png(output_path) == OK, "Runtime cloud native detail must save: %s" % output_path)
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
