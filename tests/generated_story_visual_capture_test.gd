extends SceneTree

const STORY_SCENE := preload("res://scenes/npc/town/TownNPCStoryAnimator.tscn")
const BOSS_SCENE := preload("res://scenes/monsters/AutumnSmokeOniBoss.tscn")
const WEAPON_ATLAS := preload("res://assets/ui/story/generated/ob_story_weapon_icons.png")
const CHARACTERS := [&"priest", &"witch", &"scientist", &"guard", &"grocer"]
const CHARACTER_LABELS := ["聖女祭司", "神秘女巫", "瘋狂科學家", "城鎮守衛", "商店店長"]
const WEAPON_LABELS := ["守望者聖盾", "斷翼戰戟", "熾天核槍", "無月法鈴", "相位扳手", "零號觀測鏡", "萬魂空劍", "無冕火刃"]
const CAPTURE_SIZE := Vector2i(1920, 1080)

var _capture_directory := ""
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("GENERATED_STORY_CAPTURE_DIR").strip_edges()
	if _capture_directory.is_empty():
		print("PASS: generated story visual capture is opt-in")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_capture_directory)
	await _capture_npc_sheet()
	await _capture_weapon_sheet()
	await _capture_boss()
	quit(_failures)


func _capture_npc_sheet() -> void:
	var viewport := _make_viewport(Color("101720"))
	_add_title(viewport, "劇情演出：表情與動作", "每名角色各 6 種表情與 6 種動作；此畫面抽樣實機播放")
	for index in CHARACTERS.size():
		var x := 192.0 + float(index) * 384.0
		var expression := STORY_SCENE.instantiate() as Node2D
		viewport.add_child(expression)
		expression.position = Vector2(x, 330)
		expression.scale = Vector2.ONE * 0.72
		expression.call("set_character", CHARACTERS[index])
		var expression_states := expression.call("get_supported_expressions") as Array
		expression.call("play_expression", StringName(expression_states[index % expression_states.size()]))
		var action := STORY_SCENE.instantiate() as Node2D
		viewport.add_child(action)
		action.position = Vector2(x, 775)
		action.scale = Vector2.ONE * 0.72
		action.call("set_character", CHARACTERS[index])
		var action_states := action.call("get_supported_actions") as Array
		action.call("play_action", StringName(action_states[(index + 2) % action_states.size()]))
		_add_label(viewport, CHARACTER_LABELS[index], Vector2(x - 160, 160), Vector2(320, 48), 26)
		_add_label(viewport, "表情動畫", Vector2(x - 160, 485), Vector2(320, 36), 18, Color("9adcf0"))
		_add_label(viewport, "動作動畫", Vector2(x - 160, 950), Vector2(320, 36), 18, Color("f3c66b"))
	await _save_viewport(viewport, "npc_story_animations_1920x1080")


func _capture_weapon_sheet() -> void:
	var viewport := _make_viewport(Color("17120d"))
	_add_title(viewport, "OB 傳說武器圖示", "裝備傳說與來歷：八件代表物件的圖鑑與鍛造介面素材")
	for index in 8:
		var sprite := Sprite2D.new()
		sprite.texture = WEAPON_ATLAS
		sprite.region_enabled = true
		sprite.region_rect = Rect2((index % 4) * 384, (index / 4) * 512, 384, 512)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * 0.52
		sprite.position = Vector2(240 + (index % 4) * 480, 330 + (index / 4) * 455)
		viewport.add_child(sprite)
		_add_label(viewport, WEAPON_LABELS[index], sprite.position + Vector2(-190, 160), Vector2(380, 44), 22, Color("f2ce79"))
	await _save_viewport(viewport, "ob_story_weapons_1920x1080")


func _capture_boss() -> void:
	var viewport := _make_viewport(Color("040814"))
	for x in [180, 1740]:
		var pillar := ColorRect.new()
		pillar.position = Vector2(x - 35, 0)
		pillar.size = Vector2(70, 1080)
		pillar.color = Color("101a2b")
		viewport.add_child(pillar)
	_add_title(viewport, "青燐六臂骸武者", "六臂斬擊 · 交叉處決 · 顱火召喚 · 相位移動 · 受創 · 死亡")
	var boss := BOSS_SCENE.instantiate() as Node2D
	viewport.add_child(boss)
	boss.position = Vector2(960, 1045)
	boss.scale = Vector2.ONE * 1.22
	await process_frame
	boss.call("play_boss_animation", &"cross_execution")
	boss.call("advance_boss_animation", 0.72)
	await _save_viewport(viewport, "smoke_oni_boss_1920x1080")


func _make_viewport(background_color: Color) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = CAPTURE_SIZE
	background.color = background_color
	viewport.add_child(background)
	return viewport


func _add_title(viewport: SubViewport, title: String, subtitle: String) -> void:
	_add_label(viewport, title, Vector2(110, 35), Vector2(1700, 70), 38, Color("f2c96f"))
	_add_label(viewport, subtitle, Vector2(110, 100), Vector2(1700, 44), 20, Color("b8c4cf"))


func _add_label(viewport: SubViewport, value: String, position: Vector2, size: Vector2, font_size: int, color := Color.WHITE) -> void:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	viewport.add_child(label)


func _save_viewport(viewport: SubViewport, base_name: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_failures += 1
		push_error("Capture failed: %s" % base_name)
	else:
		var full_path := _capture_directory.path_join("%s.png" % base_name)
		if image.save_png(full_path) != OK:
			_failures += 1
		_save_slices(image, base_name)
	viewport.queue_free()
	await process_frame


func _save_slices(image: Image, base_name: String) -> void:
	var slice_size := Vector2i(image.get_width() / 3, image.get_height() / 2)
	for row in 2:
		for column in 3:
			var index := row * 3 + column + 1
			var slice := image.get_region(Rect2i(column * slice_size.x, row * slice_size.y, slice_size.x, slice_size.y))
			if slice.save_png(_capture_directory.path_join("%s_slice_%d.png" % [base_name, index])) != OK:
				_failures += 1
