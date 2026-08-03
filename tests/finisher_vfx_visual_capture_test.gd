extends SceneTree

const FINISHER_DATA_PATH := "res://data/combo_finishers.json"
const CATALOG_SCRIPT_PATH := "res://scripts/systems/named_skill_vfx_catalog.gd"
const VFX_SCENE_PATH := "res://scenes/combat/vfx/NamedSkillVFX.tscn"
const CAPTURE_ENV := "FINISHER_VFX_CAPTURE_DIR"
const SHEET_SIZE := Vector2i(1920, 1080)
const SHEET_COUNT := 4
const FINISHERS_PER_SHEET := 8
const GRID_COLUMNS := 4
const GRID_ROWS := 2
const CELL_SIZE := Vector2(480.0, 540.0)
const NATIVE_FRAME_SIZE := Vector2i(720, 405)
const MOTION_SHEET_SIZE := Vector2i(1440, 810)
const MOTION_COLUMNS := 4
const MOTION_ROWS := 3
const MOTION_CELL_SIZE := Vector2(360.0, 270.0)
const AUTHORED_MOTION_FRAME_COUNT := 12
const STAGE_NAMES := ["ANTICIPATE", "TRAVEL", "CONTACT", "AFTERGLOW"]
const STAGE_FILE_NAMES := ["anticipation", "travel", "contact", "afterglow"]
const STAGE_PROGRESS := [0.20, 0.40, 0.68, 0.88]
const STAGE_X := [60.0, 180.0, 300.0, 420.0]
const MINIMUM_LUMINOUS_EFFECT_PIXELS := 320
const MINIMUM_FRAME_DIFFERENCE_RATIO := 0.025
const MINIMUM_SHAPE_CHANGE_RATIO := 0.035

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_dir := OS.get_environment(CAPTURE_ENV).strip_edges()
	if capture_dir.is_empty():
		print("PASS: finisher VFX visual capture is opt-in via %s" % CAPTURE_ENV)
		quit(0)
		return

	var recipes := _load_recipes()
	var catalog_script := load(CATALOG_SCRIPT_PATH)
	var vfx_scene := load(VFX_SCENE_PATH) as PackedScene
	_expect(recipes.size() == SHEET_COUNT * FINISHERS_PER_SHEET, "Capture review requires all 32 finisher recipes.")
	_expect(catalog_script != null, "Capture review requires the named VFX catalog.")
	_expect(vfx_scene != null, "Capture review requires the reusable NamedSkillVFX scene.")
	if recipes.size() != SHEET_COUNT * FINISHERS_PER_SHEET or catalog_script == null or vfx_scene == null:
		_finish()
		return

	var catalog: RefCounted = catalog_script.new()
	_expect(bool(catalog.call("load_catalog")), "Capture review requires a valid complete named VFX catalog.")
	var absolute_dir := _absolute_capture_dir(capture_dir)
	_expect(
		DirAccess.make_dir_recursive_absolute(absolute_dir) == OK,
		"Capture directory must be creatable: %s" % absolute_dir
	)
	if _failures > 0:
		_finish()
		return

	for sheet_index in SHEET_COUNT:
		await _capture_sheet(
			vfx_scene,
			catalog,
			recipes.slice(
				sheet_index * FINISHERS_PER_SHEET,
				(sheet_index + 1) * FINISHERS_PER_SHEET
			),
			absolute_dir.path_join("finisher_vfx_sheet_%02d.png" % (sheet_index + 1)),
			sheet_index
		)
	var native_dir := absolute_dir.path_join("native")
	var motion_dir := absolute_dir.path_join("motion")
	_expect(
		DirAccess.make_dir_recursive_absolute(native_dir) == OK,
		"Native-detail capture directory must be creatable: %s" % native_dir
	)
	_expect(
		DirAccess.make_dir_recursive_absolute(motion_dir) == OK,
		"Twelve-frame motion capture directory must be creatable: %s" % motion_dir
	)
	if _failures == 0:
		for recipe_variant in recipes:
			await _capture_native_sequence(
				vfx_scene,
				catalog,
				recipe_variant as Dictionary,
				native_dir
			)
			await _capture_motion_sheet(
				vfx_scene,
				recipe_variant as Dictionary,
				motion_dir
			)
	_finish()


func _capture_motion_sheet(
	vfx_scene: PackedScene,
	recipe: Dictionary,
	motion_dir: String
) -> void:
	var finisher_id := String(recipe.get("id", ""))
	var viewport := SubViewport.new()
	viewport.size = MOTION_SHEET_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("#070A12")
	background.size = Vector2(MOTION_SHEET_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)

	var observed_indices: Dictionary = {}
	for frame_index in AUTHORED_MOTION_FRAME_COUNT:
		var column := frame_index % MOTION_COLUMNS
		var row := frame_index / MOTION_COLUMNS
		var origin := Vector2(float(column), float(row)) * MOTION_CELL_SIZE
		_add_motion_cell(viewport, origin, frame_index)
		var effect := vfx_scene.instantiate()
		effect.set("auto_free", false)
		viewport.add_child(effect)
		effect.position = origin + Vector2(34.0, 205.0)
		effect.call("play", finisher_id, 1, 1.0, false, 3, 9)
		effect.scale *= 0.62
		effect.call("debug_set_progress", float(frame_index) / float(AUTHORED_MOTION_FRAME_COUNT - 1))
		effect.set_process(false)
		var state := effect.call("get_finisher_debug_state") as Dictionary
		observed_indices[int(state.get("authored_frame_index", -1))] = true

	await process_frame
	await RenderingServer.frame_post_draw
	_expect(
		observed_indices.size() == AUTHORED_MOTION_FRAME_COUNT,
		"%s motion evidence must expose all twelve distinct authored frame indices." % finisher_id
	)
	var image := viewport.get_texture().get_image()
	var output_path := motion_dir.path_join("%s_motion_12f.png" % finisher_id)
	_expect(not image.is_empty(), "%s twelve-frame motion sheet must produce pixels." % finisher_id)
	if not image.is_empty():
		_expect(image.save_png(output_path) == OK, "Twelve-frame motion sheet must save: %s" % output_path)
	viewport.queue_free()
	await process_frame


func _add_motion_cell(viewport: SubViewport, origin: Vector2, frame_index: int) -> void:
	var panel := ColorRect.new()
	panel.position = origin + Vector2(2.0, 2.0)
	panel.size = MOTION_CELL_SIZE - Vector2(4.0, 4.0)
	panel.color = Color("#0D1422") if frame_index % 2 == 0 else Color("#101827")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(panel)
	var ground_line := Line2D.new()
	ground_line.points = PackedVector2Array([
		origin + Vector2(0.0, 205.0),
		origin + Vector2(MOTION_CELL_SIZE.x, 205.0),
	])
	ground_line.width = 2.0
	ground_line.default_color = Color(0.28, 0.38, 0.54, 0.58)
	ground_line.z_index = 150
	viewport.add_child(ground_line)
	var label := Label.new()
	label.text = "F%02d" % (frame_index + 1)
	label.position = origin + Vector2(12.0, 10.0)
	label.size = Vector2(64.0, 24.0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_color", Color("#F0DDA7"))
	label.add_theme_color_override("font_outline_color", Color("#05070B"))
	label.z_index = 200
	viewport.add_child(label)


func _capture_sheet(
	vfx_scene: PackedScene,
	catalog: RefCounted,
	recipes: Array,
	output_path: String,
	sheet_index: int
) -> void:
	var viewport := SubViewport.new()
	viewport.size = SHEET_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("#070A12")
	background.size = Vector2(SHEET_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)

	for local_index in recipes.size():
		var recipe := recipes[local_index] as Dictionary
		var finisher_id := String(recipe.get("id", ""))
		var profile := catalog.call("get_profile", finisher_id) as Dictionary
		_expect(not profile.is_empty(), "Capture profile missing for %s." % finisher_id)
		if profile.is_empty():
			continue
		var column := local_index % GRID_COLUMNS
		var row := local_index / GRID_COLUMNS
		var cell_origin := Vector2(float(column), float(row)) * CELL_SIZE
		_add_cell_backdrop(viewport, cell_origin, local_index)
		_add_title(viewport, cell_origin, recipe, sheet_index * FINISHERS_PER_SHEET + local_index)
		_add_icon(viewport, cell_origin, String(recipe.get("icon_path", "")))
		for stage_index in STAGE_NAMES.size():
			_add_stage_caption(viewport, cell_origin, stage_index)
			_add_stage_effect(
				viewport,
				vfx_scene,
				finisher_id,
				cell_origin,
				stage_index
			)

	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_expect(not image.is_empty(), "Finisher VFX capture must produce pixels for sheet %d." % (sheet_index + 1))
	if not image.is_empty():
		_expect(image.save_png(output_path) == OK, "Finisher VFX capture must save: %s" % output_path)
		_save_sheet_review_slices(image, output_path)
	viewport.queue_free()
	await process_frame


func _add_cell_backdrop(viewport: SubViewport, cell_origin: Vector2, local_index: int) -> void:
	var panel := ColorRect.new()
	panel.position = cell_origin + Vector2(5.0, 5.0)
	panel.size = CELL_SIZE - Vector2(10.0, 10.0)
	panel.color = Color("#111726") if local_index % 2 == 0 else Color("#0D1422")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(panel)
	var top_rule := Line2D.new()
	top_rule.points = PackedVector2Array([
		cell_origin + Vector2(8.0, 82.0),
		cell_origin + Vector2(CELL_SIZE.x - 8.0, 82.0),
	])
	top_rule.width = 2.0
	top_rule.default_color = Color("#B99A55")
	top_rule.modulate.a = 0.72
	top_rule.z_index = 160
	viewport.add_child(top_rule)
	for divider_x in [120.0, 240.0, 360.0]:
		var divider := Line2D.new()
		divider.points = PackedVector2Array([
			cell_origin + Vector2(divider_x, 104.0),
			cell_origin + Vector2(divider_x, CELL_SIZE.y - 18.0),
		])
		divider.width = 1.0
		divider.default_color = Color(0.42, 0.5, 0.62, 0.36)
		divider.z_index = 160
		viewport.add_child(divider)


func _add_title(
	viewport: SubViewport,
	cell_origin: Vector2,
	recipe: Dictionary,
	global_index: int
) -> void:
	var title := Label.new()
	title.text = "%02d  %s" % [global_index + 1, String(recipe.get("name", recipe.get("id", "")))]
	title.position = cell_origin + Vector2(66.0, 12.0)
	title.size = Vector2(400.0, 34.0)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_color", Color("#F4E3B0"))
	title.add_theme_color_override("font_outline_color", Color("#080A0F"))
	title.z_index = 200
	viewport.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%s  ·  %s" % [String(recipe.get("role", "")), String(recipe.get("id", ""))]
	subtitle.position = cell_origin + Vector2(68.0, 47.0)
	subtitle.size = Vector2(390.0, 24.0)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#91A4C3"))
	subtitle.z_index = 200
	viewport.add_child(subtitle)


func _add_icon(viewport: SubViewport, cell_origin: Vector2, icon_path: String) -> void:
	var texture := load(icon_path) as Texture2D
	_expect(texture != null, "Capture review icon must load: %s" % icon_path)
	if texture == null:
		return
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.position = cell_origin + Vector2(36.0, 40.0)
	var texture_size := texture.get_size()
	var icon_scale := 48.0 / maxf(1.0, maxf(texture_size.x, texture_size.y))
	icon.scale = Vector2.ONE * icon_scale
	icon.z_index = 190
	viewport.add_child(icon)


func _add_stage_caption(viewport: SubViewport, cell_origin: Vector2, stage_index: int) -> void:
	var caption := Label.new()
	caption.text = STAGE_NAMES[stage_index]
	caption.position = cell_origin + Vector2(STAGE_X[stage_index] - 58.0, 94.0)
	caption.size = Vector2(116.0, 24.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_constant_override("outline_size", 3)
	caption.add_theme_color_override("font_color", Color("#B9C9E2"))
	caption.add_theme_color_override("font_outline_color", Color("#080A0F"))
	caption.z_index = 200
	viewport.add_child(caption)


func _add_stage_effect(
	viewport: SubViewport,
	vfx_scene: PackedScene,
	finisher_id: String,
	cell_origin: Vector2,
	stage_index: int
) -> void:
	var effect := vfx_scene.instantiate()
	effect.set("auto_free", false)
	viewport.add_child(effect)
	effect.position = cell_origin + Vector2(STAGE_X[stage_index] - 48.0, 318.0)
	effect.call("play", finisher_id, 1, 1.0, true, 3, 9)
	# Preview scale is authored for one effect; the sheet reduces it again so four
	# causally ordered beats fit side by side without overlapping their dividers.
	effect.scale *= 0.34
	effect.call("debug_set_progress", STAGE_PROGRESS[stage_index])
	effect.set_process(false)


func _capture_native_sequence(
	vfx_scene: PackedScene,
	catalog: RefCounted,
	recipe: Dictionary,
	native_dir: String
) -> void:
	var finisher_id := String(recipe.get("id", ""))
	var profile := catalog.call("get_profile", finisher_id) as Dictionary
	_expect(not profile.is_empty(), "Native choreography profile missing for %s." % finisher_id)
	if profile.is_empty():
		return
	var viewport := SubViewport.new()
	viewport.size = NATIVE_FRAME_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	_add_native_background(viewport)

	var effect := vfx_scene.instantiate()
	effect.set("auto_free", false)
	viewport.add_child(effect)
	effect.position = Vector2(65.0, 278.0)
	# Native-detail evidence uses real combat scale. Advancing one instance in
	# order preserves causal semantic-piece and particle state across key frames.
	effect.call("play", finisher_id, 1, 1.0, false, 3, 9)
	effect.set_process(false)
	_add_native_label(viewport, recipe)

	await process_frame
	var stage_images: Array[Image] = []
	for stage_index in STAGE_PROGRESS.size():
		effect.call("debug_set_progress", STAGE_PROGRESS[stage_index])
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var stage_name := String(STAGE_FILE_NAMES[stage_index])
		var output_path := native_dir.path_join(
			"%s_%s_native.png" % [finisher_id, stage_name]
		)
		_expect(
			not image.is_empty(),
			"Native-detail %s capture must produce pixels for %s."
			% [stage_name, finisher_id]
		)
		if image.is_empty():
			continue
		_validate_native_effect_pixels(image, finisher_id, stage_name)
		_expect(image.save_png(output_path) == OK, "Native-detail capture must save: %s" % output_path)
		stage_images.append(image.duplicate())
	_validate_native_sequence_difference(stage_images, finisher_id)
	viewport.queue_free()
	await process_frame


func _add_native_background(viewport: SubViewport) -> void:
	var background := ColorRect.new()
	background.color = Color("#080B13")
	background.size = Vector2(NATIVE_FRAME_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var distant_band := ColorRect.new()
	distant_band.position = Vector2(0.0, 236.0)
	distant_band.size = Vector2(float(NATIVE_FRAME_SIZE.x), 169.0)
	distant_band.color = Color("#101928")
	distant_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(distant_band)
	var ground_line := Line2D.new()
	ground_line.points = PackedVector2Array([
		Vector2(0.0, 278.0),
		Vector2(float(NATIVE_FRAME_SIZE.x), 278.0),
	])
	ground_line.width = 2.0
	ground_line.default_color = Color(0.24, 0.32, 0.45, 0.55)
	viewport.add_child(ground_line)


func _add_native_label(viewport: SubViewport, recipe: Dictionary) -> void:
	var label_back := ColorRect.new()
	label_back.position = Vector2(10.0, 366.0)
	label_back.size = Vector2(420.0, 29.0)
	label_back.color = Color(0.02, 0.025, 0.05, 0.82)
	label_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_back.z_index = 190
	viewport.add_child(label_back)
	var label := Label.new()
	label.text = "%s  ·  %s" % [String(recipe.get("name", "")), String(recipe.get("id", ""))]
	label.position = Vector2(18.0, 370.0)
	label.size = Vector2(405.0, 22.0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_color", Color("#F0DDA7"))
	label.add_theme_color_override("font_outline_color", Color("#05070B"))
	label.z_index = 200
	viewport.add_child(label)


func _validate_native_effect_pixels(image: Image, finisher_id: String, stage_name: String) -> void:
	# The review background stays below 0.16 luminance except for a two-pixel ground
	# guide. Excluding the label band makes this fail when the VFX is transparent,
	# outside the viewport, or its shader does not render.
	var luminous_effect_pixels := 0
	for y in range(0, mini(350, image.get_height())):
		if y >= 274 and y <= 282:
			continue
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.24:
				luminous_effect_pixels += 1
	_expect(
		luminous_effect_pixels > MINIMUM_LUMINOUS_EFFECT_PIXELS,
		"%s %s native frame must contain a visible in-bounds semantic effect, not only the backdrop (found %d luminous pixels)."
		% [finisher_id, stage_name, luminous_effect_pixels]
	)


func _validate_native_sequence_difference(stage_images: Array[Image], finisher_id: String) -> void:
	_expect(
		stage_images.size() == STAGE_PROGRESS.size(),
		"%s must capture all four causal choreography frames." % finisher_id
	)
	if stage_images.size() != STAGE_PROGRESS.size():
		return
	var signatures: Dictionary = {}
	var previous_metrics: Dictionary = {}
	for stage_index in stage_images.size():
		var stage_name := String(STAGE_FILE_NAMES[stage_index])
		var metrics := _effect_shape_metrics(stage_images[stage_index])
		var signature := JSON.stringify([
			metrics.get("count", 0),
			metrics.get("centroid", Vector2.ZERO),
			metrics.get("bounds", Rect2i()),
			metrics.get("occupancy", []),
		])
		_expect(
			not signatures.has(signature),
			"%s %s repeats the exact same captured shape as %s."
			% [finisher_id, stage_name, String(signatures.get(signature, "another stage"))]
		)
		signatures[signature] = stage_name
		if stage_index > 0:
			var previous_image := stage_images[stage_index - 1]
			var pixel_difference := _sampled_pixel_difference_ratio(previous_image, stage_images[stage_index])
			var shape_difference := _shape_difference_ratio(previous_metrics, metrics)
			_expect(
				pixel_difference >= MINIMUM_FRAME_DIFFERENCE_RATIO,
				"%s %s must visibly differ from %s; changed-pixel ratio %.4f is below %.4f."
				% [
					finisher_id,
					stage_name,
					STAGE_FILE_NAMES[stage_index - 1],
					pixel_difference,
					MINIMUM_FRAME_DIFFERENCE_RATIO,
				]
			)
			_expect(
				shape_difference >= MINIMUM_SHAPE_CHANGE_RATIO,
				"%s %s must change semantic-piece position or silhouette from %s; shape ratio %.4f is below %.4f."
				% [
					finisher_id,
					stage_name,
					STAGE_FILE_NAMES[stage_index - 1],
					shape_difference,
					MINIMUM_SHAPE_CHANGE_RATIO,
				]
			)
		previous_metrics = metrics
	_expect(
		signatures.size() == STAGE_PROGRESS.size(),
		"%s must have four distinct anticipation, travel, contact, and afterglow captures."
		% finisher_id
	)


func _effect_shape_metrics(image: Image) -> Dictionary:
	var minimum := Vector2i(image.get_width(), 350)
	var maximum := Vector2i(-1, -1)
	var weighted_position := Vector2.ZERO
	var count := 0
	var occupancy: Array[int] = []
	occupancy.resize(12 * 6)
	occupancy.fill(0)
	for y in range(0, mini(350, image.get_height()), 2):
		if y >= 274 and y <= 282:
			continue
		for x in range(0, image.get_width(), 2):
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) <= 0.18:
				continue
			count += 1
			weighted_position += Vector2(x, y)
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
			var column := mini(11, int(float(x) / float(image.get_width()) * 12.0))
			var row := mini(5, int(float(y) / 350.0 * 6.0))
			occupancy[row * 12 + column] += 1
	var centroid := weighted_position / float(count) if count > 0 else Vector2.ZERO
	var bounds := Rect2i()
	if maximum.x >= minimum.x and maximum.y >= minimum.y:
		bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	return {
		"count": count,
		"centroid": centroid,
		"bounds": bounds,
		"occupancy": occupancy,
	}


func _sampled_pixel_difference_ratio(left: Image, right: Image) -> float:
	var changed := 0
	var sampled := 0
	for y in range(0, mini(350, mini(left.get_height(), right.get_height())), 4):
		for x in range(0, mini(left.get_width(), right.get_width()), 4):
			var left_color := left.get_pixel(x, y)
			var right_color := right.get_pixel(x, y)
			var color_delta := (
				absf(left_color.r - right_color.r)
				+ absf(left_color.g - right_color.g)
				+ absf(left_color.b - right_color.b)
			)
			if color_delta > 0.08:
				changed += 1
			sampled += 1
	return float(changed) / float(maxi(1, sampled))


func _shape_difference_ratio(left: Dictionary, right: Dictionary) -> float:
	var left_occupancy := left.get("occupancy", []) as Array
	var right_occupancy := right.get("occupancy", []) as Array
	var changed_cells := 0
	var cell_count := mini(left_occupancy.size(), right_occupancy.size())
	for index in cell_count:
		var left_count := int(left_occupancy[index])
		var right_count := int(right_occupancy[index])
		var largest := maxi(1, maxi(left_count, right_count))
		if float(absi(left_count - right_count)) / float(largest) > 0.18:
			changed_cells += 1
	var occupancy_ratio := float(changed_cells) / float(maxi(1, cell_count))
	var left_centroid := left.get("centroid", Vector2.ZERO) as Vector2
	var right_centroid := right.get("centroid", Vector2.ZERO) as Vector2
	var centroid_ratio := left_centroid.distance_to(right_centroid) / 180.0
	var left_bounds := left.get("bounds", Rect2i()) as Rect2i
	var right_bounds := right.get("bounds", Rect2i()) as Rect2i
	var bounds_delta := (
		absf(float(left_bounds.size.x - right_bounds.size.x))
		+ absf(float(left_bounds.size.y - right_bounds.size.y))
	) / 720.0
	return maxf(occupancy_ratio, maxf(centroid_ratio, bounds_delta))


func _save_sheet_review_slices(image: Image, output_path: String) -> void:
	var slice_dir := output_path.get_basename() + "_slices"
	_expect(
		DirAccess.make_dir_recursive_absolute(slice_dir) == OK,
		"Finisher sheet slice directory must be creatable: %s" % slice_dir
	)
	var slice_size := Vector2i(image.get_width() / 3, image.get_height() / 2)
	for row in 2:
		for column in 3:
			var slice := image.get_region(
				Rect2i(Vector2i(column, row) * slice_size, slice_size)
			)
			var slice_path := slice_dir.path_join(
				"slice_r%d_c%d.png" % [row + 1, column + 1]
			)
			_expect(slice.save_png(slice_path) == OK, "Finisher review slice must save: %s" % slice_path)


func _load_recipes() -> Array:
	if not FileAccess.file_exists(FINISHER_DATA_PATH):
		_expect(false, "Combo finisher data must exist for capture review.")
		return []
	var file := FileAccess.open(FINISHER_DATA_PATH, FileAccess.READ)
	if file == null:
		_expect(false, "Combo finisher data must be readable for capture review.")
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_expect(false, "Combo finisher data must parse for capture review.")
		return []
	var recipes_variant: Variant = (parsed as Dictionary).get("recipes", [])
	return recipes_variant as Array if recipes_variant is Array else []


func _absolute_capture_dir(capture_dir: String) -> String:
	if capture_dir.begins_with("res://") or capture_dir.begins_with("user://"):
		return ProjectSettings.globalize_path(capture_dir)
	return capture_dir.replace("\\", "/")


func _finish() -> void:
	if _failures == 0:
		print("PASS: four review sheets, 128 native stages, and 32 twelve-frame motion sheets captured")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
