extends SceneTree

const CAPTURE_ENV := "BLESSING_MARKET_CAPTURE_DIR"
const MAP_SCENE := preload("res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn")
const BACKGROUND_ATTACK_SCENE := preload("res://scenes/combat/vfx/EvolvedBackgroundAttack.tscn")
const AUTO_ATTACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")
const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")
const ENEMY_SCENE := preload("res://scenes/monsters/AutumnEnemy.tscn")
const MANAGER_SCRIPT := preload("res://scripts/systems/divine_gift_manager.gd")
const BATTLE_SIZE := Vector2i(1920, 1080)
const MARKET_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment(CAPTURE_ENV).strip_edges()
	if output_dir.is_empty():
		print("PASS: Blessing and Player Market visual capture is opt-in via %s" % CAPTURE_ENV)
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	await _capture_battle(output_dir)
	await _capture_basic_attack(output_dir)
	for viewport_size in MARKET_SIZES:
		await _capture_market(output_dir, viewport_size)
	if _failures == 0:
		print("PASS: captured integrated Blessing combat and layered Player Market review frames")
	quit(_failures)


func _capture_battle(output_dir: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = BATTLE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := MAP_SCENE.instantiate()
	viewport.add_child(map)
	for camera_node in map.find_children("*", "Camera2D", true, false):
		(camera_node as Camera2D).enabled = false
	for helper_name in ["EditorHUDReference", "EditorHelpers"]:
		var helper := map.get_node_or_null(helper_name)
		if helper is CanvasItem:
			(helper as CanvasItem).visible = false
	var camera := Camera2D.new()
	camera.position = Vector2(930.0, 360.0)
	camera.zoom = Vector2.ONE * 1.5
	camera.enabled = true
	map.add_child(camera)
	await process_frame
	await process_frame

	var manager := MANAGER_SCRIPT.new()
	manager.load_catalog()
	var recipes := manager.get_fusion_recipes()
	var recipe_indices := [2, 7, 9]
	var origins := [
		Vector2(720.0, 390.0),
		Vector2(960.0, 430.0),
		Vector2(1190.0, 390.0),
	]
	var attack_origin := Vector2(590.0, 500.0)
	var attack_target := Vector2(1120.0, 430.0)
	_add_review_actors(map, attack_origin, attack_target)
	for visual_index in recipe_indices.size():
		var recipe := recipes[recipe_indices[visual_index]] as Dictionary
		var visual := BACKGROUND_ATTACK_SCENE.instantiate()
		map.add_child(visual)
		visual.global_position = origins[visual_index]
		var target_points: Array[Vector2] = [
			origins[visual_index] + Vector2(150.0, -20.0),
			origins[visual_index] + Vector2(210.0, 45.0),
		]
		visual.play({
			"pattern": String(recipe.get("pattern", "prismatic_orbit")),
			"subject_asset_path": String(recipe.get("subject_asset_path", "")),
			"subject_motion": String(recipe.get("subject_motion", "")),
			"instance_count": [3, 3, 2][visual_index],
			"size_scale": [0.78, 0.92, 0.86][visual_index],
			"rhythm_speed": 1.6,
			"destruction_tier": 1 + visual_index / 2,
			"accent_color": ["#85dc3f", "#76efcf", "#b679ff"][visual_index],
			"geometry_modules": [],
		}, target_points)
		visual.debug_set_progress(0.42 + visual_index * 0.06)

	var feedback := AUTO_ATTACK_SCENE.instantiate()
	map.add_child(feedback)
	feedback.play(
		attack_origin,
		attack_target,
		38,
		8,
		12,
		true,
		1.6,
		0.82,
		{
			"stack_count": 9,
			"elements": ["fire", "ice", "lightning"],
			"blessing_attack_profiles": [
				_base_profile("resonant_grace", "fire", 3),
				_base_profile("celestial_momentum", "wind", 3),
				_base_profile("prismatic_oath", "lightning", 3),
			],
		}
	)
	feedback.debug_set_progress(0.58, 0.08)
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	var full_path := output_dir.path_join("blessing_combat_full_1920x1080.png")
	if image == null or image.is_empty():
		_failures += 1
		push_error("Graphical renderer did not produce the Blessing combat review frame.")
	else:
		image.save_png(full_path)
		_save_slices(image, output_dir, "blessing_combat")
	viewport.queue_free()
	await process_frame


func _capture_basic_attack(output_dir: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = BATTLE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := MAP_SCENE.instantiate()
	viewport.add_child(map)
	for camera_node in map.find_children("*", "Camera2D", true, false):
		(camera_node as Camera2D).enabled = false
	for helper_name in ["EditorHUDReference", "EditorHelpers"]:
		var helper := map.get_node_or_null(helper_name)
		if helper is CanvasItem:
			(helper as CanvasItem).visible = false
	var camera := Camera2D.new()
	camera.position = Vector2(930.0, 360.0)
	camera.zoom = Vector2.ONE * 1.5
	camera.enabled = true
	map.add_child(camera)
	await process_frame
	await process_frame
	var attack_origin := Vector2(590.0, 500.0)
	var attack_target := Vector2(1260.0, 430.0)
	_add_review_actors(map, attack_origin, attack_target)
	var feedback := AUTO_ATTACK_SCENE.instantiate()
	map.add_child(feedback)
	feedback.play(
		attack_origin,
		attack_target,
		31,
		8,
		10,
		false,
		1.5,
		0.78,
		{
			"stack_count": 8,
			"elements": ["fire", "wind", "lightning"],
			"blessing_attack_profiles": [
				_base_profile("resonant_grace", "fire", 3),
				_base_profile("celestial_momentum", "wind", 3),
				_base_profile("prismatic_oath", "lightning", 3),
			],
		}
	)
	feedback.debug_set_progress(0.52, 0.0)
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_failures += 1
		push_error("Graphical renderer did not produce the Basic Attack Blessing review frame.")
	else:
		image.save_png(output_dir.path_join("blessing_basic_attack_full_1920x1080.png"))
		_save_slices(image, output_dir, "blessing_basic_attack")
	viewport.queue_free()
	await process_frame


func _add_review_actors(map: Node, player_position: Vector2, target_position: Vector2) -> void:
	var player := map.get_node_or_null("Player") as Node2D
	if player != null:
		player.global_position = player_position
	for offset in [Vector2.ZERO, Vector2(54.0, -34.0), Vector2(68.0, 38.0)]:
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		map.add_child(enemy)
		enemy.global_position = target_position + offset


func _capture_market(output_dir: String, viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("080a0d")
	viewport.add_child(background)
	var market := MARKET_SCENE.instantiate()
	viewport.add_child(market)
	market.open()
	await process_frame
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	var base_name := "player_market_%dx%d" % [viewport_size.x, viewport_size.y]
	if image == null or image.is_empty():
		_failures += 1
		push_error("Graphical renderer did not produce Player Market at %s." % viewport_size)
	else:
		image.save_png(output_dir.path_join("%s.png" % base_name))
		if viewport_size == Vector2i(1920, 1080):
			_save_slices(image, output_dir, "player_market")
	viewport.queue_free()
	await process_frame


func _base_profile(gift_id: String, element: String, level: int) -> Dictionary:
	return {
		"gift_id": gift_id,
		"element": element,
		"level": level,
		"accent_color": {
			"fire": "#ff6438",
			"wind": "#76efcf",
			"lightning": "#a986ff",
		}.get(element, "#ffffff"),
		"asset_path": "res://assets/generated/vfx/blessings/base/%s.png" % gift_id,
	}


func _save_slices(image: Image, output_dir: String, prefix: String) -> void:
	var slice_width := image.get_width() / 3
	var slice_height := image.get_height() / 2
	for row in 2:
		for column in 3:
			var origin := Vector2i(column * slice_width, row * slice_height)
			var width := slice_width if column < 2 else image.get_width() - origin.x
			var height := slice_height if row < 1 else image.get_height() - origin.y
			var slice := image.get_region(Rect2i(origin, Vector2i(width, height)))
			slice.save_png(output_dir.path_join("%s_r%dc%d.png" % [prefix, row + 1, column + 1]))
