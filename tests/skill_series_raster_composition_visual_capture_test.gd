extends SceneTree

const CAPTURE_DIR_ENV := "SKILL_SERIES_RASTER_COMPOSITION_CAPTURE_DIR"
const RECIPE_CATALOG_SCRIPT := preload("res://scripts/vfx/skill_vfx_recipe_catalog.gd")
const MATERIAL_SCENE := preload("res://scenes/vfx/skills/SkillSeriesRasterMaterialVFX2D.tscn")
const SERIES := [
	"sword_rain", "moon_wheel", "feather", "thorn", "dr_stone",
	"black_hole", "fire", "lightning", "water_flow", "arcane_swamp",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
const ELEMENTS := ["dark", "fire", "ice", "light", "lightning", "poison", "water", "wind"]
const PHASES := {
	"anticipation": 0.10,
	"travel": 0.34,
	"contact": 0.62,
	"residual": 0.84,
}
const FRAME_SIZE := Vector2i(1920, 1080)
const CELL_SIZE := Vector2(384.0, 360.0)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if output_dir.is_empty():
		_finish()
		return
	var catalog := RECIPE_CATALOG_SCRIPT.new() as RefCounted
	_expect(bool(catalog.call("load_catalog")), "Raster composition capture needs the production recipe catalog.")
	if _failures > 0:
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	for phase_name in PHASES:
		await _capture_phase(catalog, String(phase_name), float(PHASES[phase_name]), output_dir)
	_finish()


func _capture_phase(catalog: RefCounted, phase_name: String, progress: float, output_dir: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = FRAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = FRAME_SIZE
	background.color = Color("101821")
	viewport.add_child(background)
	for index in SERIES.size():
		_add_series_cell(viewport, catalog, index, phase_name, progress)
	await process_frame
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s phase needs an offscreen-rendered full frame." % phase_name)
	if image != null and not image.is_empty():
		var base_path := output_dir.path_join("%s_full_frame.png" % phase_name)
		_expect(image.save_png(base_path) == OK, "%s phase full frame must save." % phase_name)
		_save_slices(image, phase_name, output_dir)
	viewport.queue_free()
	await process_frame


func _add_series_cell(
	viewport: SubViewport,
	catalog: RefCounted,
	index: int,
	phase_name: String,
	progress: float
) -> void:
	var row := 0
	var column := index
	var row_count := 5
	if index >= 9:
		row = 2
		column = index - 9
		row_count = 4
	elif index >= 5:
		row = 1
		column = index - 5
		row_count = 4
	var row_width := float(row_count) * CELL_SIZE.x
	var origin := Vector2((float(FRAME_SIZE.x) - row_width) * 0.5, float(row) * CELL_SIZE.y)
	origin += Vector2(float(column) * CELL_SIZE.x, 0.0)
	var panel := ColorRect.new()
	panel.position = origin + Vector2(5.0, 5.0)
	panel.size = CELL_SIZE - Vector2(10.0, 10.0)
	panel.color = Color("17232e") if index % 2 == 0 else Color("14202a")
	viewport.add_child(panel)
	var label := Label.new()
	label.position = origin + Vector2(12.0, 10.0)
	label.text = "%s | %s" % [SERIES[index], phase_name]
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("f3d58a"))
	viewport.add_child(label)
	var ground := Line2D.new()
	ground.add_point(origin + Vector2(26.0, 278.0))
	ground.add_point(origin + Vector2(CELL_SIZE.x - 26.0, 278.0))
	ground.width = 3.0
	ground.default_color = Color("526677")
	viewport.add_child(ground)
	var source_marker := ColorRect.new()
	source_marker.position = origin + Vector2(48.0, 170.0)
	source_marker.size = Vector2(24.0, 96.0)
	source_marker.color = Color("6f8fa5")
	viewport.add_child(source_marker)
	var target_marker := ColorRect.new()
	target_marker.position = origin + Vector2(310.0, 192.0)
	target_marker.size = Vector2(28.0, 76.0)
	target_marker.color = Color("ad6268")
	viewport.add_child(target_marker)
	var material := MATERIAL_SCENE.instantiate() as Node2D
	_expect(material != null, "%s must instantiate for %s capture." % [SERIES[index], phase_name])
	if material == null:
		return
	material.position = origin + Vector2(CELL_SIZE.x * 0.5, 230.0)
	viewport.add_child(material)
	var recipe := catalog.call("get_recipe", SERIES[index]) as Dictionary
	var overlay := {
		"id": "review_%s" % ELEMENTS[index % ELEMENTS.size()],
		"element": ELEMENTS[index % ELEMENTS.size()],
		"level": 2,
	}
	_expect(bool(material.call("configure", recipe, 3, [overlay])), "%s must configure for visual capture." % SERIES[index])
	material.call("set_progress", progress, Vector2(-132.0, -30.0), Vector2(132.0, 22.0), 0.58)


func _save_slices(image: Image, phase_name: String, output_dir: String) -> void:
	var slice_width := image.get_width() / 3
	var slice_height := image.get_height() / 2
	for row in 2:
		for column in 3:
			var x := column * slice_width
			var y := row * slice_height
			var width := image.get_width() - x if column == 2 else slice_width
			var height := image.get_height() - y if row == 1 else slice_height
			var slice := image.get_region(Rect2i(x, y, width, height))
			var path := output_dir.path_join("%s_R%dC%d.png" % [phase_name, row + 1, column + 1])
			_expect(slice.save_png(path) == OK, "%s slice R%dC%d must save." % [phase_name, row + 1, column + 1])


func _finish() -> void:
	if _failures == 0:
		print("PASS: four-phase skill-series raster composition capture contract")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
