extends SceneTree

const HUD_PATH := "res://scenes/ui/autumn/AutumnHUD.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]
const BOTTOM_REGIONS := [
	"PlayerVitals",
	"CardStage",
	"ActivityFeed",
]

var _failures := 0
var _capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_directory = OS.get_environment("AUTUMN_HUD_CAPTURE_DIR")
	_expect(ResourceLoader.exists(HUD_PATH), "AutumnHUD must exist for layout verification.")
	if _failures > 0:
		quit(1)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	await _check_projection_behavior()
	quit(0 if _failures == 0 else 1)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(hud)
	hud.call("set_boss_health", "HEARTWOOD GUARDIAN", 72, 100)
	hud.call("set_active_statuses", [
		{"id": "armor", "name": "Iron Momentum", "icon": "◆", "remaining_seconds": 2.8},
		{"id": "regen", "name": "Verdant Renewal", "icon": "+", "remaining_seconds": 4.2},
	])
	hud.call("set_cards", _sample_cards(), 5.0)
	hud.call("set_action_points", 5.0, 5.0)
	hud.call("set_experience", 18, 48)
	hud.call("set_combo_chain", [
		{"name": "Iron Will", "count": 2},
		{"name": "Flame Imbue", "count": 3},
	])
	await process_frame
	await process_frame

	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var bottom_stage := hud.get_node("BottomStage") as HBoxContainer
	var bottom_rect := _canvas_rect(bottom_stage)
	var player_vitals := hud.get_node("BottomStage/PlayerVitals") as Control
	var xp_progress := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/XPProgress"
	) as ProgressBar
	var xp_value := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/ExperienceHeader/XPValue"
	) as Label
	_expect(
		is_equal_approx(xp_progress.max_value, 48.0)
			and is_equal_approx(xp_progress.value, 18.0)
			and xp_value.text.contains("NEXT 30"),
		"XP bar must show current progress and remaining XP at %s." % viewport_size
	)
	_expect(
		_canvas_rect(player_vitals).encloses(_canvas_rect(xp_progress))
			and _canvas_rect(player_vitals).encloses(_canvas_rect(xp_value)),
		"XP projection must remain inside PlayerVitals at %s." % viewport_size
	)
	var activity_feed := hud.get_node("BottomStage/ActivityFeed") as Control
	var activity_rect_before_dense_combo := _canvas_rect(activity_feed)
	var dense_combo_skills: Array[Dictionary] = []
	for index in 18:
		dense_combo_skills.append({
			"name": "Long Combo Ability Name %02d" % index,
			"count": index + 1,
		})
	hud.call("set_combo_chain", dense_combo_skills, 171, 9.8)
	await process_frame
	await process_frame
	var combo_viewport := hud.get_node(
		"BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboSkillRows"
	) as Control
	var combo_rows := combo_viewport.get_node("Rows") as VBoxContainer
	_expect(combo_viewport.clip_contents, "Combo ability rows must be clipped inside a fixed HUD viewport at %s." % viewport_size)
	_expect(combo_rows.get_child_count() == 3, "Only three recent Combo abilities may occupy HUD layout space at %s." % viewport_size)
	_expect(
		_canvas_rect(activity_feed).is_equal_approx(activity_rect_before_dense_combo),
		"Dense Combo abilities must not resize the ActivityFeed frame at %s." % viewport_size
	)
	bottom_rect = _canvas_rect(bottom_stage)
	_expect(
		absf(bottom_rect.position.y - float(viewport_size.y) * 0.66 - 6.0) <= 5.0,
		"Autumn bottom stage must begin at the approved 66%% gameplay boundary at %s; got %.1f." % [
			viewport_size,
			bottom_rect.position.y,
		]
	)
	_expect(screen.encloses(bottom_rect), "Autumn bottom stage must remain on-screen at %s." % viewport_size)

	var previous_end := bottom_rect.position.x
	for node_name in BOTTOM_REGIONS:
		var region := bottom_stage.get_node(node_name) as Control
		var region_rect := _canvas_rect(region)
		_expect(bottom_rect.encloses(region_rect), "%s must stay inside BottomStage at %s." % [node_name, viewport_size])
		_expect(
			region_rect.position.x >= previous_end - 1.5,
			"BottomStage region %s must not overlap its previous sibling at %s." % [node_name, viewport_size]
		)
		previous_end = region_rect.end.x

	var top_left := hud.get_node("TopLeftStack") as Control
	var top_center := hud.get_node("TopCenterStack") as Control
	var top_right := hud.get_node("TopRightMeta") as Control
	var top_left_rect := _canvas_rect(top_left)
	var top_center_rect := _canvas_rect(top_center)
	_expect(screen.encloses(top_left_rect), "Top-left status/objective stack must remain on-screen at %s." % viewport_size)
	_expect(screen.encloses(top_center_rect), "Top-center Boss/toast stack must remain on-screen at %s." % viewport_size)
	_expect(screen.encloses(_canvas_rect(top_right)), "Top-right economy strip must remain on-screen at %s." % viewport_size)
	_expect(
		not top_left_rect.intersects(top_center_rect),
		"Top-left status/objective must not overlap Boss/toast space at %s." % viewport_size
	)
	_expect(
		top_left_rect.end.y <= bottom_rect.position.y,
		"Top-left projections must not cover the lower card stage at %s." % viewport_size
	)
	_expect(
		top_center_rect.end.y <= bottom_rect.position.y,
		"Boss/toast projections must not cover the lower card stage at %s." % viewport_size
	)

	var hand := hud.get_node("BottomStage/CardStage/AutumnCardHandUI") as CardHandUI
	var redraw := hud.get_node("BottomStage/CardStage/ActionStrip/RedrawHand") as Button
	var auto_use := hud.get_node("BottomStage/CardStage/ActionStrip/AutoUse") as CheckButton
	_expect(
		redraw.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Redraw must remain mouse-interactive at %s." % viewport_size
	)
	_expect(
		auto_use.mouse_filter == Control.MOUSE_FILTER_STOP
			and bottom_rect.encloses(_canvas_rect(auto_use)),
		"Auto Use checkbox must remain interactive and inside BottomStage at %s." % viewport_size
	)
	_expect(
		not hud.has_node("BottomStage/CardStage/ActionStrip/CooldownStrip"),
		"Card cooldown UI must remain removed at %s." % viewport_size
	)
	_expect(hand.get_card_button_count() == 4, "Embedded Autumn hand must render only the active four-card group at %s." % viewport_size)
	for index in hand.get_card_button_count():
		var card := hand.get_card_button(index)
		var card_rect := _canvas_rect(card)
		_expect(
			screen.encloses(card_rect)
			and bottom_rect.encloses(card_rect),
			"Every Autumn card body must remain fully inside BottomStage at %s." % viewport_size
		)
		for descendant in card.find_children("*", "Control", true, false):
			if not (descendant as Control).is_visible_in_tree():
				continue
			var descendant_rect := _canvas_rect(descendant as Control)
			_expect(
				descendant_rect.end.y <= float(viewport_size.y) + 0.5
				and descendant_rect.end.y <= bottom_rect.end.y + 0.5,
				"Card %d content %s must not be clipped by the viewport or BottomStage at %s." % [
					index,
					descendant.get_path(),
					viewport_size,
				]
			)

	if not _capture_directory.is_empty():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await create_timer(0.05).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		var capture_path := _capture_directory.path_join(
			"autumn_hud_%dx%d.png" % [viewport_size.x, viewport_size.y]
		)
		_expect(
			viewport.get_texture().get_image().save_png(capture_path) == OK,
			"Autumn HUD visual capture must save at %s." % viewport_size
		)

	viewport.queue_free()
	await process_frame


func _check_projection_behavior() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(hud)
	await process_frame

	var boss := hud.get_node("TopCenterStack/BossHealth") as Control
	_expect(not boss.visible, "Boss panel must not occupy space before a Boss is projected.")
	hud.call("set_boss_health", "HEARTWOOD GUARDIAN", 80, 100)
	_expect(boss.visible, "Boss panel must become visible when a Boss is projected.")
	hud.call("hide_boss_health")
	_expect(not boss.visible, "Boss panel must release its space when the Boss is gone.")
	hud.call("set_survival_timer", 29.4, 180.0, true)
	var survival_timer := hud.get_node(
		"FooterRail/FooterRow/SurvivalTimerLabel"
	) as Label
	_expect(
		survival_timer.text == "00:30  FINAL RUSH",
		"Autumn footer must project a rounded-up countdown and explicit Final Rush state."
	)

	for skill_id in ["one", "two", "three", "four"]:
		hud.call("show_skill_toast", skill_id, skill_id.to_upper())
	var toast_stack := hud.get_node(
		"BottomStage/ActivityFeed/FeedMargin/FeedRows/SkillToastStack"
	) as VBoxContainer
	_expect(toast_stack.get_child_count() == 3, "Skill toast stack must cap visible notifications at three.")
	hud.call("show_skill_toast", "four", "FOUR REFRESHED")
	_expect(toast_stack.get_child_count() == 3, "Repeated Skill toast must refresh instead of duplicating.")
	await create_timer(1.9).timeout
	_expect(toast_stack.get_child_count() == 0, "Skill toasts must fade and disappear after 1.5 seconds.")
	hud.call("show_skill_toast", "refresh", "REFRESH")
	await create_timer(1.3).timeout
	hud.call("show_skill_toast", "refresh", "REFRESH")
	await create_timer(0.4).timeout
	_expect(
		toast_stack.get_child_count() == 1
		and (toast_stack.get_child(0) as Label).modulate.a > 0.9,
		"Refreshing a fading Skill toast must restart its full visible lifetime."
	)
	await create_timer(1.3).timeout
	_expect(toast_stack.get_child_count() == 0, "Refreshed Skill toast must still expire after its restarted lifetime.")

	hud.call("set_health", 100, 100)
	hud.call("set_health", 88, 100)
	hud.call("set_action_points", 3.0, 5.0)
	hud.call("set_action_points", 3.7, 5.0)
	hud.call("set_experience", 18, 48)
	hud.call("set_experience", 19, 48)
	hud.call("set_material_count", 98)
	var hp_value := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/HPRow/HPBar/HPValue"
	) as Label
	var ap_value := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/APPanel/APRows/APHeader/APValue"
	) as Label
	var ap_progress := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/APPanel/APRows/APProgress"
	) as ProgressBar
	_expect(ap_value.text == "3.7 / 5.0", "AP must use the approved decimal real-time projection.")
	_expect(is_equal_approx(ap_progress.value, 3.7), "AP progress must track the decimal value.")
	_expect(
		hp_value.scale.x > 1.0 and ap_value.scale.x > 1.0,
		"Damage and AP recovery must immediately emphasize their changed values."
	)
	var xp_progress := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/XPProgress"
	) as ProgressBar
	var xp_value := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/ExperienceHeader/XPValue"
	) as Label
	_expect(
		is_equal_approx(xp_progress.value, 19.0)
			and xp_value.text.contains("NEXT 29")
			and xp_value.scale.x > 1.0,
		"Collecting XP must update the remaining amount and trigger immediate cyan emphasis."
	)
	hud.call("set_player_level", 7)
	hud.call("set_player_level", 8)
	var level_label := hud.get_node(
		"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/LevelLabel"
	) as Label
	_expect(
		level_label.scale.x > 1.0,
		"Level gain must immediately emphasize the new level."
	)
	await create_timer(0.55).timeout
	_expect(
		xp_value.scale.is_equal_approx(Vector2.ONE)
			and level_label.scale.is_equal_approx(Vector2.ONE)
			and hp_value.scale.is_equal_approx(Vector2.ONE)
			and ap_value.scale.is_equal_approx(Vector2.ONE),
		"Vitals emphasis must settle back to a stable readable layout."
	)
	_expect(
		(hud.get_node("TopRightMeta/MetaRow/MaterialValue") as Label).text == "98",
		"Top-right economy strip must project upgrade material."
	)

	viewport.queue_free()
	await process_frame


func _sample_cards() -> Array[Dictionary]:
	return [
		{"id": "healing_light", "name": "Healing Light", "type": "healing", "description": "Recover.", "cost": 1, "level": 1, "fixed": true},
		{"id": "flame_imbue", "name": "Flame Imbue", "type": "combo", "description": "Gain flame.", "cost": 3, "level": 1, "fixed": true, "combo_stack": 3},
		{"id": "echo_volley", "name": "Echo Volley", "type": "combo", "description": "Add projectiles.", "cost": 2, "level": 1, "fixed": true, "combo_stack": 2},
		{"id": "storm_charge", "name": "Storm Charge", "type": "combo", "description": "Add storm.", "cost": 2, "level": 1, "fixed": true, "combo_stack": 1},
		{"id": "gale_lunge", "name": "Gale Lunge", "type": "attack", "description": "Dash.", "cost": 2, "level": 3},
		{"id": "healing_light", "name": "Healing Light", "type": "healing", "description": "Recover.", "cost": 2, "level": 1},
		{"id": "meteor", "name": "Meteor", "type": "ultimate", "description": "Heavy damage.", "cost": 5, "level": 1},
	]


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
