extends SceneTree

const CAPTURE_DIR_ENV := "SWORD_RAIN_VFX_CAPTURE_DIR"
const VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const LOCK_STAR_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/sword_rain__lock_star.png")
const STONE_CRATER_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_crater.png")
const FRAME_SIZE := Vector2i(1280, 720)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_dir := OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if capture_dir.is_empty():
		_finish()
		return
	_expect(DirAccess.make_dir_recursive_absolute(capture_dir) == OK, "Sword Rain capture directory must be writable.")
	_save_native_texture(LOCK_STAR_TEXTURE, capture_dir.path_join("native_lock_star.png"), "lock star")
	_save_native_texture(STONE_CRATER_TEXTURE, capture_dir.path_join("native_stone_crater.png"), "stone crater")
	for phase in ["summon", "release", "contact"]:
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
	var label := Label.new()
	label.position = Vector2(24.0, 18.0)
	label.text = "Sword Rain · Master · %s" % phase
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("f3d58a"))
	viewport.add_child(label)
	var effect := VFX_SCENE.instantiate() as Node2D
	_expect(effect != null, "Sword Rain %s capture must instantiate the production effect." % phase)
	if effect == null:
		viewport.queue_free()
		await process_frame
		return
	effect.auto_free = false
	effect.position = Vector2(640.0, 420.0)
	viewport.add_child(effect)
	effect.call("play_series", "sword_rain", 3, 1, true, 1.0)
	var series_state := effect.call("get_series_debug_state") as Dictionary
	var source_position := series_state.get("source_position", Vector2.ZERO) as Vector2
	var target_position := series_state.get("target_position", Vector2.ZERO) as Vector2
	var ground_y := effect.to_global(target_position).y
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(90.0, ground_y), Vector2(1190.0, ground_y)])
	ground.width = 4.0
	ground.default_color = Color("526677")
	viewport.add_child(ground)
	viewport.move_child(ground, 1)
	var caster := ColorRect.new()
	caster.size = Vector2(38.0, 122.0)
	caster.position = Vector2(effect.to_global(source_position).x - 19.0, ground_y - caster.size.y)
	caster.color = Color("6f8fa5")
	viewport.add_child(caster)
	viewport.move_child(caster, 2)
	var target := ColorRect.new()
	target.size = Vector2(44.0, 106.0)
	target.position = Vector2(effect.to_global(target_position).x - 22.0, ground_y - target.size.y)
	target.color = Color("ad6268")
	viewport.add_child(target)
	viewport.move_child(target, 3)
	var cadence := effect.call("get_sword_rain_cadence_state") as Dictionary
	var progress := 0.0
	match phase:
		"summon":
			progress = float(cadence.get("orbit_end_ratio", 0.0)) * 0.2
		"release":
			progress = float(cadence.get("lock_end_ratio", 0.0)) + 0.06
		_:
			progress = float(cadence.get("first_contact_ratio", 0.0))
	effect.call("debug_set_progress", progress)
	await process_frame
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "Sword Rain %s needs an offscreen-rendered full frame." % phase)
	if image != null and not image.is_empty():
		_expect(image.save_png(capture_dir.path_join("%s_full.png" % phase)) == OK, "Sword Rain %s full frame must save." % phase)
		_save_slices(image, capture_dir, phase)
	viewport.queue_free()
	await process_frame


func _save_native_texture(texture: Texture2D, path: String, label: String) -> void:
	var image := texture.get_image()
	_expect(image != null and not image.is_empty(), "Sword Rain %s native texture must decode." % label)
	if image != null and not image.is_empty():
		_expect(image.save_png(path) == OK, "Sword Rain %s native texture must save." % label)


func _save_slices(image: Image, capture_dir: String, label: String) -> void:
	var x_edges := [0, image.get_width() / 3, image.get_width() * 2 / 3, image.get_width()]
	var y_edges := [0, image.get_height() / 2, image.get_height()]
	for row in 2:
		for column in 3:
			var region := Rect2i(
				x_edges[column],
				y_edges[row],
				x_edges[column + 1] - x_edges[column],
				y_edges[row + 1] - y_edges[row]
			)
			var output_path := capture_dir.path_join("%s_R%dC%d.png" % [label, row + 1, column + 1])
			_expect(image.get_region(region).save_png(output_path) == OK, "Sword Rain %s slice R%dC%d must save." % [label, row + 1, column + 1])


func _finish() -> void:
	if _failures == 0:
		print("PASS: Sword Rain summon, release, contact, native-detail, and 3x2 review captures")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
