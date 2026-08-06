extends SceneTree

const CAPTURE_ENV := "SKILL_SERIES_VFX_CAPTURE_PATH"
const SERIES_CATALOG_SCRIPT := preload("res://scripts/systems/skill_series_vfx_catalog.gd")
const VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const CELL_SIZE := Vector2i(480, 210)
const SHEET_SIZE := Vector2i(CELL_SIZE.x * 3, CELL_SIZE.y * 13)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: RefCounted = SERIES_CATALOG_SCRIPT.new()
	_expect(bool(catalog.call("load_catalog")), "Series VFX visual capture needs the production catalog.")
	var profiles := catalog.call("get_all_profiles") as Array
	_expect(profiles.size() == 13, "Series VFX visual capture must include all 13 series.")
	var capture_path := OS.get_environment(CAPTURE_ENV).strip_edges()
	if capture_path.is_empty() or _failures > 0:
		_finish()
		return
	var viewport := SubViewport.new()
	viewport.size = SHEET_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.size = SHEET_SIZE
	backdrop.color = Color("111820")
	viewport.add_child(backdrop)
	for row in profiles.size():
		var profile := profiles[row] as Dictionary
		for tier_rank in range(1, 4):
			_add_cell(viewport, profile, row, tier_rank)
	await process_frame
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	var image := viewport.get_texture().get_image()
	_expect(image != null, "Series VFX contact sheet needs an offscreen graphical renderer.")
	if image != null:
		_expect(
			image.save_png(capture_path) == OK,
			"Series VFX contact sheet must save: %s" % capture_path
		)
	viewport.queue_free()
	await process_frame
	_finish()


func _add_cell(viewport: SubViewport, profile: Dictionary, row: int, tier_rank: int) -> void:
	var origin := Vector2((tier_rank - 1) * CELL_SIZE.x, row * CELL_SIZE.y)
	var panel := ColorRect.new()
	panel.position = origin + Vector2(4, 4)
	panel.size = Vector2(CELL_SIZE) - Vector2(8, 8)
	panel.color = Color("17232e") if (row + tier_rank) % 2 == 0 else Color("14202a")
	viewport.add_child(panel)
	var label := Label.new()
	label.position = origin + Vector2(12, 8)
	label.text = "%s · %s · T%d" % [
		String(profile.get("name", "")),
		String(profile.get("object_name", "")),
		tier_rank,
	]
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f3d58a"))
	viewport.add_child(label)
	var effect := VFX_SCENE.instantiate() as Node2D
	_expect(effect != null, "Series VFX contact sheet must instantiate every cell.")
	if effect == null:
		return
	effect.auto_free = false
	effect.position = origin + Vector2(82, 150)
	viewport.add_child(effect)
	effect.call("play_series", String(profile.get("id", "")), tier_rank, 1, true, 1.0)
	effect.call("debug_set_progress", 0.55)


func _finish() -> void:
	if _failures == 0:
		print("PASS: series VFX contact sheet capture contract")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
