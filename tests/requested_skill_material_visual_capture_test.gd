extends SceneTree

const CAPTURE_DIR_ENV := "REQUESTED_SKILL_VFX_CAPTURE_DIR"
const VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const EVENT_VFX := preload("res://scripts/vfx/series_raster_event_vfx_2d.gd")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")
const LANCE_SHADER := preload("res://shaders/vfx/stone_lance_core_preserve.gdshader")
const FRAME_SIZE := Vector2i(1280, 720)
const NATIVE_TEXTURES := {
	"fire_pillar": preload("res://assets/generated/vfx/skill_materials/components/base/fire__fire_pillar.png"),
	"stone_orbit": preload("res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_orbit.png"),
	"stone_lance": preload("res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_lance.png"),
	"tidal_curl": preload("res://assets/generated/vfx/skill_materials/components/base/water_flow__tidal_curl.png"),
	"chain_bolt": preload("res://assets/generated/vfx/skill_materials/components/base/lightning__chain_bolt.png"),
	"sky_impact": preload("res://assets/generated/vfx/skill_materials/components/base/lightning__sky_impact.png"),
	"void_ring": preload("res://assets/generated/vfx/skill_materials/components/base/black_hole__void_ring.png"),
	"dragon_head": preload("res://assets/generated/vfx/skill_materials/components/base/dragon_breath__dragon_head.png"),
	"breath_beam": preload("res://assets/generated/vfx/skill_materials/components/base/dragon_breath__breath_beam.png"),
	"thorn_bloom": preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_bloom.png"),
	"thorn_seed": preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_seed.png"),
	"thorn_run": preload("res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_run.png"),
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_dir := OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if capture_dir.is_empty():
		_finish()
		return
	_expect(DirAccess.make_dir_recursive_absolute(capture_dir) == OK, "Requested skill capture directory must be writable.")
	for id in NATIVE_TEXTURES:
		var image := (NATIVE_TEXTURES[id] as Texture2D).get_image()
		_expect(image != null and not image.is_empty(), "%s native image must decode." % id)
		if image != null and not image.is_empty():
			_expect(image.save_png(capture_dir.path_join("native_%s.png" % id)) == OK, "%s native image must save." % id)
			await _capture_runtime_native(capture_dir, String(id), NATIVE_TEXTURES[id] as Texture2D, image.get_size())
	var captures := [
		["thorn", 3, 0.47, Vector2(640.0, 548.0)],
		["fire", 3, 0.56, Vector2(640.0, 548.0)],
		["dr_stone", 3, 0.54, Vector2(640.0, 470.0)],
		["water_flow", 3, 0.52, Vector2(640.0, 548.0)],
		["black_hole", 3, 0.52, Vector2(640.0, 390.0)],
		["dragon_breath", 3, 0.62, Vector2(640.0, 548.0)],
	]
	for config in captures:
		await _capture_series(capture_dir, String(config[0]), int(config[1]), float(config[2]), config[3] as Vector2)
	await _capture_lightning(capture_dir)
	_finish()


func _base_viewport(label_text: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = FRAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = FRAME_SIZE
	background.color = Color("101821")
	viewport.add_child(background)
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(0, 550), Vector2(1280, 550), Vector2(1280, 720), Vector2(0, 720)])
	ground.color = Color("1b2b34")
	viewport.add_child(ground)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(0, 550), Vector2(1280, 550)])
	edge.width = 4.0
	edge.default_color = Color("526677")
	viewport.add_child(edge)
	var label := Label.new()
	label.position = Vector2(24, 18)
	label.text = label_text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("f3d58a"))
	viewport.add_child(label)
	return viewport


func _capture_runtime_native(capture_dir: String, id: String, texture: Texture2D, native_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = native_size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = native_size
	background.color = Color("101821")
	viewport.add_child(background)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = Vector2(native_size) * 0.5
	var material := ShaderMaterial.new()
	material.shader = LANCE_SHADER if id == "stone_lance" else EDGE_SHADER
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	_expect(rendered != null and not rendered.is_empty(), "%s runtime native image must render." % id)
	if rendered != null and not rendered.is_empty():
		_expect(rendered.save_png(capture_dir.path_join("runtime_native_%s.png" % id)) == OK, "%s runtime native image must save." % id)
		if id == "stone_lance":
			_expect(rendered.save_png(capture_dir.path_join("runtime_native_stone_lance_core_preserved.png")) == OK, "Stone lance core-preserved evidence must save.")
	viewport.queue_free()
	await process_frame


func _capture_series(capture_dir: String, series_id: String, tier: int, progress: float, effect_position: Vector2) -> void:
	var viewport := _base_viewport("%s - Master - integrated" % series_id)
	var effect := VFX_SCENE.instantiate() as Node2D
	viewport.add_child(effect)
	effect.set("auto_free", false)
	effect.position = effect_position
	effect.call("play_series", series_id, tier, 1, true, 1.0)
	effect.set_process(false)
	effect.call("debug_set_progress", progress)
	await _save_viewport(viewport, capture_dir, series_id)


func _capture_lightning(capture_dir: String) -> void:
	var viewport := _base_viewport("lightning - vertical descent + ground finish")
	var strike := EVENT_VFX.new() as Node2D
	viewport.add_child(strike)
	strike.call("play_lightning_sky_strike", Vector2(640.0, 550.0))
	await create_timer(0.13).timeout
	await _save_viewport(viewport, capture_dir, "lightning")


func _save_viewport(viewport: SubViewport, capture_dir: String, label: String) -> void:
	await process_frame
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s integrated frame must render." % label)
	if image != null and not image.is_empty():
		_expect(image.save_png(capture_dir.path_join("%s_full.png" % label)) == OK, "%s full frame must save." % label)
		_save_slices(image, capture_dir, label)
	viewport.queue_free()
	await process_frame


func _save_slices(image: Image, capture_dir: String, label: String) -> void:
	var x_edges := [0, image.get_width() / 3, image.get_width() * 2 / 3, image.get_width()]
	var y_edges := [0, image.get_height() / 2, image.get_height()]
	for row in 2:
		for column in 3:
			var region := Rect2i(x_edges[column], y_edges[row], x_edges[column + 1] - x_edges[column], y_edges[row + 1] - y_edges[row])
			_expect(image.get_region(region).save_png(capture_dir.path_join("%s_R%dC%d.png" % [label, row + 1, column + 1])) == OK, "%s slice R%dC%d must save." % [label, row + 1, column + 1])


func _finish() -> void:
	if _failures == 0:
		print("PASS: requested skill VFX native, integrated, and 3x2 review captures")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
