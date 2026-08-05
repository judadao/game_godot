extends SceneTree

const BOSS_SCENE := preload("res://scenes/monsters/AutumnSixArmColossusBoss.tscn")
const CAPTURE_SIZE := Vector2i(1536, 1024)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := OS.get_environment("AUTUMN_COLOSSUS_CAPTURE_PATH")
	if output_path.is_empty():
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(CAPTURE_SIZE.x, 0),
		Vector2(CAPTURE_SIZE),
		Vector2(0, CAPTURE_SIZE.y),
	])
	backdrop.color = Color(0.14, 0.12, 0.18, 1.0)
	backdrop.z_index = -100
	viewport.add_child(backdrop)
	var boss := BOSS_SCENE.instantiate()
	boss.position = Vector2(768, 950)
	viewport.add_child(boss)
	await process_frame
	var isolated_arm := OS.get_environment("AUTUMN_COLOSSUS_ISOLATE_ARM")
	if not isolated_arm.is_empty():
		for arm_variant in boss.get_node("Visual/Armature").get_children():
			(arm_variant as CanvasItem).visible = arm_variant.name == isolated_arm
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	(boss.get_node("Visual/Core/HeadPivot/JawPivot") as Node2D).position.y = 146.0
	(boss.get_node("Visual/SpiritFire/JawCoreFlame") as Node2D).visible = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.save_png(output_path) != OK:
		push_error("Could not save the native colossus capture.")
		quit(1)
		return
	quit(0)
