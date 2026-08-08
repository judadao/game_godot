extends SceneTree

const CAPTURE_DIR_ENV := "THORN_BLOOM_VFX_CAPTURE_DIR"
const VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const THORN_BLOOM_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_bloom.png")
const THORN_SEED_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_seed.png")
const THORN_RUN_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_run.png")
const FRAME_SIZE := Vector2i(1280, 720)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_dir := OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if capture_dir.is_empty():
		_finish()
		return
	_expect(DirAccess.make_dir_recursive_absolute(capture_dir) == OK, "Thorn capture directory must be writable.")
	_save_native_texture(THORN_BLOOM_TEXTURE, capture_dir.path_join("native_thorn_bloom.png"), "thorn bloom")
	_save_native_texture(THORN_SEED_TEXTURE, capture_dir.path_join("native_thorn_seed.png"), "thorn seed")
	_save_native_texture(THORN_RUN_TEXTURE, capture_dir.path_join("native_thorn_run.png"), "thorn run")
	for phase in ["growth", "bloom", "scatter"]:
		await _capture_phase(capture_dir, phase)
	_finish()


func _capture_phase(capture_dir: String, phase: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = FRAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = FRAME_SIZE
	background.color = Color("101821")
	viewport.add_child(background)
	var ground_plane := Polygon2D.new()
	ground_plane.polygon = PackedVector2Array([
		Vector2(70.0, 548.0), Vector2(1210.0, 548.0),
		Vector2(1280.0, 720.0), Vector2(0.0, 720.0),
	])
	ground_plane.color = Color("1a2830")
	viewport.add_child(ground_plane)
	var ground_edge := Line2D.new()
	ground_edge.points = PackedVector2Array([Vector2(70.0, 548.0), Vector2(1210.0, 548.0)])
	ground_edge.width = 4.0
	ground_edge.default_color = Color("526677")
	viewport.add_child(ground_edge)
	var label := Label.new()
	label.position = Vector2(24.0, 18.0)
	label.text = "Thorn - Master - %s" % phase
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("d9e96a"))
	viewport.add_child(label)
	var effect := VFX_SCENE.instantiate() as Node2D
	_expect(effect != null, "Thorn %s capture must instantiate the production effect." % phase)
	if effect == null:
		viewport.queue_free()
		await process_frame
		return
	effect.auto_free = false
	effect.position = Vector2(640.0, 548.0)
	viewport.add_child(effect)
	effect.call("play_series", "thorn", 3, 1, true, 1.0)
	effect.set_process(false)
	var progress := {"growth": 0.27, "bloom": 0.49, "scatter": 0.64}.get(phase, 0.64) as float
	effect.call("debug_set_progress", progress)
	await process_frame
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "Thorn %s needs an offscreen-rendered full frame." % phase)
	if image != null and not image.is_empty():
		_expect(image.save_png(capture_dir.path_join("%s_full.png" % phase)) == OK, "Thorn %s full frame must save." % phase)
		_save_slices(image, capture_dir, phase)
	viewport.queue_free()
	await process_frame


func _save_native_texture(texture: Texture2D, path: String, label: String) -> void:
	var image := texture.get_image()
	_expect(image != null and not image.is_empty(), "Thorn %s native texture must decode." % label)
	if image != null and not image.is_empty():
		_expect(image.save_png(path) == OK, "Thorn %s native texture must save." % label)


func _save_slices(image: Image, capture_dir: String, label: String) -> void:
	var x_edges := [0, image.get_width() / 3, image.get_width() * 2 / 3, image.get_width()]
	var y_edges := [0, image.get_height() / 2, image.get_height()]
	for row in 2:
		for column in 3:
			var region := Rect2i(
				x_edges[column], y_edges[row],
				x_edges[column + 1] - x_edges[column],
				y_edges[row + 1] - y_edges[row]
			)
			var output_path := capture_dir.path_join("%s_R%dC%d.png" % [label, row + 1, column + 1])
			_expect(image.get_region(region).save_png(output_path) == OK, "Thorn %s slice R%dC%d must save." % [label, row + 1, column + 1])


func _finish() -> void:
	if _failures == 0:
		print("PASS: Thorn growth, bloom, scatter, native-detail, and 3x2 review captures")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
