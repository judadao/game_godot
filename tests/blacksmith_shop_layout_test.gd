extends SceneTree

const BLACKSMITH_SCENE := preload("res://scenes/ui/town/PlayerBlacksmithUI.tscn")
const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0
var _capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("BLACKSMITH_SHOP_CAPTURE_DIR").strip_edges()
	if not _capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_directory)
	for viewport_size in VIEWPORT_SIZES:
		await _check_ui(BLACKSMITH_SCENE, "blacksmith", "PlayerBlacksmithWindow", viewport_size)
		await _check_ui(MARKET_SCENE, "market", "PlayerMarketWindow", viewport_size)
	if _failures == 0:
		print("PASS: blacksmith workshop and market remain safe at all six required resolutions")
	quit(_failures)


func _check_ui(scene: PackedScene, prefix: String, window_name: String, viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("080a0d")
	viewport.add_child(background)
	var ui := scene.instantiate() as Control
	viewport.add_child(ui)
	if prefix == "blacksmith":
		ui.call("set_recipes", [{
			"id": "hunter_bow",
			"name": "獵人的長弓",
			"kind": "weapon",
			"quality_label": "普通",
			"description": "以韌性木材與穩定弓臂打造的狩獵長弓。",
			"unlocked": true,
			"visible": true,
			"cost": {"autumn_wood": 8, "stone": 2},
		}, {
			"id": "iron_sword",
			"name": "旅人的鐵劍",
			"kind": "weapon",
			"quality_label": "普通",
			"unlocked": true,
			"visible": true,
		}, {
			"id": "ember_charm",
			"name": "餘燼護符",
			"kind": "accessory",
			"quality_label": "稀有",
			"unlocked": true,
			"visible": true,
		}])
	else:
		ui.call("set_sale_state", {
			"capacity": 3,
			"candidates": [
				{
					"item_kind": "equipment",
					"item_id": "hunter_bow",
					"item_name": "北境獵弓",
					"quality": "rare",
					"quality_label": "稀有武器",
					"count": 2,
					"unit_price": 146,
				},
				{
					"item_kind": "equipment",
					"item_id": "chain_armor",
					"item_name": "城防鎖甲",
					"quality": "exceptional",
					"quality_label": "罕見防具",
					"count": 1,
					"unit_price": 228,
				},
				{
					"item_kind": "resource",
					"item_id": "iron_ingot",
					"item_name": "精煉鐵錠",
					"quality": "common",
					"quality_label": "鍛造素材",
					"count": 12,
					"unit_price": 34,
				},
			],
			"shelves": [
				{"shelf_index": 0, "status": "empty"},
				{
					"shelf_index": 1,
					"status": "customer_ready",
					"item_name": "青鋼短劍",
					"customer_name": "巡防士兵",
				},
				{"shelf_index": 2, "status": "empty"},
			],
			"fixture_state": {
				"active": {"id": "cedar_display", "name": "雪松武備櫃", "capacity": 3},
				"next": {},
			},
		})
	ui.call("open")
	await process_frame
	await process_frame
	if prefix == "market":
		var candidate_list := ui.find_child("MarketCandidateList", true, false) as VBoxContainer
		var visible_candidates := 0
		if candidate_list != null:
			for child in candidate_list.get_children():
				if child is Button and child.visible:
					visible_candidates += 1
		_expect(
			visible_candidates == 3 and candidate_list.size.y >= 150.0,
			"Market review fixture must render three readable candidate rows; got %d rows in %s."
			% [visible_candidates, candidate_list.size]
		)
	var window := ui.find_child(window_name, true, false) as Control
	_expect(window != null and window.is_visible_in_tree(), "%s window must render at %s." % [prefix, viewport_size])
	if window != null:
		var bounds := _transformed_bounds(window)
		_expect(
			Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(bounds),
			"%s window must stay inside %s; got %s." % [prefix, viewport_size, bounds]
		)
	if not _capture_directory.is_empty():
		await process_frame
		var image := viewport.get_texture().get_image()
		var base_name := "%s_%dx%d" % [prefix, viewport_size.x, viewport_size.y]
		if image == null:
			_expect(false, "%s graphical capture needs a rendering driver at %s." % [prefix, viewport_size])
			viewport.queue_free()
			await process_frame
			return
		_expect(
			not image.is_empty()
				and image.save_png(_capture_directory.path_join("%s.png" % base_name)) == OK,
			"%s capture must save at %s." % [prefix, viewport_size]
		)
		if viewport_size == Vector2i(1920, 1080):
			_save_slices(image, base_name)
			if prefix == "market":
				var product_button := ui.find_child("Product1InteractButton", true, false) as Button
				if product_button != null:
					product_button.pressed.emit()
					await process_frame
					await process_frame
					var capture_candidate_list := ui.find_child("MarketCandidateList", true, false) as VBoxContainer
					var capture_candidate_scroll := ui.find_child("CandidateScroll", true, false) as ScrollContainer
					_expect(
						capture_candidate_scroll != null
							and capture_candidate_scroll.is_visible_in_tree()
							and capture_candidate_scroll.size.y >= 180.0,
						"Market product picker must reserve visible height in the side dock."
					)
					if capture_candidate_list != null and capture_candidate_scroll != null:
						var candidate_viewport := capture_candidate_scroll.get_global_rect()
						for child in capture_candidate_list.get_children():
							if child is Button and child.visible:
								_expect(
									candidate_viewport.intersects(child.get_global_rect()),
									"Market candidate rows must render inside the product picker viewport."
								)
					var management_image := viewport.get_texture().get_image()
					var management_name := "market_management_1920x1080"
					_expect(
						management_image != null
							and management_image.save_png(_capture_directory.path_join("%s.png" % management_name)) == OK,
						"Market side-dock capture must save."
					)
					if management_image != null:
						_save_slices(management_image, management_name)
	if prefix == "blacksmith":
		ui.call("select_blacksmith_service", &"forge")
		await process_frame
		await process_frame
		var forge_stage := ui.find_child("ForgeInteractionStage", true, false) as Control
		_expect(
			forge_stage != null
				and forge_stage.is_visible_in_tree()
				and Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(
					_transformed_bounds(forge_stage)
				),
			"Object-led forge stage must stay inside %s." % viewport_size
		)
		var blueprint_hotspot := ui.find_child("BlueprintRackButton", true, false) as Control
		_expect(
			blueprint_hotspot != null
				and blueprint_hotspot.is_visible_in_tree()
				and _transformed_bounds(window).encloses(_transformed_bounds(blueprint_hotspot)),
			"The current blueprint decision must remain visible inside the window at %s."
			% viewport_size
		)
		for hidden_hotspot_name in [
			"MethodToolsButton",
			"MaterialChestButton",
			"ForgeWorkspaceActionButton",
			"FinishedRackButton",
		]:
			var hidden_hotspot := ui.find_child(hidden_hotspot_name, true, false) as Control
			_expect(
				hidden_hotspot != null and not hidden_hotspot.is_visible_in_tree(),
				"Future forge decision %s must stay concealed at %s."
				% [hidden_hotspot_name, viewport_size]
			)
		if not _capture_directory.is_empty():
			var forge_image := viewport.get_texture().get_image()
			var forge_name := "blacksmith_forge_%dx%d" % [viewport_size.x, viewport_size.y]
			_expect(
				forge_image != null
					and forge_image.save_png(
						_capture_directory.path_join("%s.png" % forge_name)
					) == OK,
				"Forge interaction capture must save at %s." % viewport_size
			)
			if forge_image != null and viewport_size == Vector2i(1920, 1080):
				_save_slices(forge_image, forge_name)
				await _advance_blacksmith_to_anvil(ui)
				var anvil_slot := ui.find_child("AnvilSlot", true, false) as Control
				var anvil_visual_layer := ui.find_child(
					"AnvilVisualLayer", true, false
				) as Control
				var anvil_hotspot := ui.find_child(
					"ForgeWorkspaceActionButton", true, false
				) as Button
				_expect(
					anvil_slot != null
						and anvil_slot.is_visible_in_tree()
						and anvil_hotspot != null
						and anvil_hotspot.is_visible_in_tree()
						and not anvil_hotspot.disabled,
					"The 1920x1080 forge review fixture must reach an enabled anvil state."
				)
				var forge_animation := ui.find_child(
					"ForgeWorkspaceAnimation", true, false
				) as AnimationPlayer
				_expect(
					forge_animation != null,
					"The final forge review needs the authored hammer animation."
				)
				if forge_animation != null:
					forge_animation.seek(0.0, true)
				await process_frame
				var idle_image := viewport.get_texture().get_image()
				var idle_name := "blacksmith_forge_anvil_idle_1920x1080"
				_expect(
					idle_image != null
						and idle_image.save_png(
							_capture_directory.path_join("%s.png" % idle_name)
						) == OK,
					"Idle anvil review capture must save at 1920x1080."
				)
				if idle_image != null:
					_save_slices(idle_image, idle_name)
					_save_control_detail(idle_image, anvil_visual_layer, "%s_native" % idle_name)
				if forge_animation != null:
					forge_animation.seek(2.86, true)
				await process_frame
				var impact_image := viewport.get_texture().get_image()
				var impact_name := "blacksmith_forge_anvil_impact_1920x1080"
				_expect(
					impact_image != null
						and impact_image.save_png(
							_capture_directory.path_join("%s.png" % impact_name)
						) == OK,
					"Impact-frame anvil review capture must save at 1920x1080."
				)
				if impact_image != null:
					_save_slices(impact_image, impact_name)
					_save_control_detail(
						impact_image, anvil_visual_layer, "%s_native" % impact_name
					)
	viewport.queue_free()
	await process_frame


func _advance_blacksmith_to_anvil(ui: Control) -> void:
	var recipe_list := ui.find_child("RecipeList", true, false) as Control
	if recipe_list != null:
		for child in recipe_list.get_children():
			if child is Button and child.visible and not child.disabled:
				(child as Button).pressed.emit()
				break
	await process_frame
	for button_name in [
		"BlueprintRackButton",
		"MethodToolsButton",
		"SteadyMethodButton",
		"MaterialChestButton",
		"CommonMaterialButton",
	]:
		var button := ui.find_child(button_name, true, false) as Button
		_expect(button != null, "Forge review flow needs %s." % button_name)
		if button != null and not button.disabled:
			button.pressed.emit()
		await process_frame


func _transformed_bounds(control: Control) -> Rect2:
	var transform := control.get_global_transform()
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0),
		transform * control.size,
		transform * Vector2(0, control.size.y),
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds


func _save_slices(image: Image, base_name: String) -> void:
	var slice_size := Vector2i(image.get_width() / 3, image.get_height() / 2)
	for row in 2:
		for column in 3:
			var index := row * 3 + column + 1
			var region := Rect2i(column * slice_size.x, row * slice_size.y, slice_size.x, slice_size.y)
			var slice := image.get_region(region)
			_expect(
				slice.save_png(_capture_directory.path_join("%s_slice_%d.png" % [base_name, index])) == OK,
				"%s review slice %d must save." % [base_name, index]
			)


func _save_control_detail(image: Image, control: Control, base_name: String) -> void:
	if control == null:
		_expect(false, "%s detail capture needs its authored control." % base_name)
		return
	var bounds := _transformed_bounds(control).grow(8.0)
	var left := clampi(floori(bounds.position.x), 0, image.get_width() - 1)
	var top := clampi(floori(bounds.position.y), 0, image.get_height() - 1)
	var right := clampi(ceili(bounds.end.x), left + 1, image.get_width())
	var bottom := clampi(ceili(bounds.end.y), top + 1, image.get_height())
	var detail := image.get_region(Rect2i(left, top, right - left, bottom - top))
	_expect(
		detail.save_png(_capture_directory.path_join("%s.png" % base_name)) == OK,
		"%s native-detail capture must save." % base_name
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
