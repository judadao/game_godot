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
	"ActionPoints",
	"CardStage",
	"InputGlyphHints",
	"PersonalResources",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	hud.call("set_cooldown_cards", [
		{"card_id": "guard", "name": "Iron Will", "remaining_seconds": 6.2},
	])
	await process_frame
	await process_frame

	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var bottom_stage := hud.get_node("BottomStage") as HBoxContainer
	var bottom_rect := _canvas_rect(bottom_stage)
	_expect(
		absf(bottom_rect.position.y - float(viewport_size.y) * 0.75 - 6.0) <= 1.5,
		"Autumn bottom stage must begin inside the authored lower quarter at %s." % viewport_size
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
	var top_left_rect := _canvas_rect(top_left)
	var top_center_rect := _canvas_rect(top_center)
	_expect(screen.encloses(top_left_rect), "Top-left status/objective stack must remain on-screen at %s." % viewport_size)
	_expect(screen.encloses(top_center_rect), "Top-center Boss/toast stack must remain on-screen at %s." % viewport_size)
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

	var cooldown := hud.get_node("BottomStage/CardStage/CooldownStrip") as Control
	var hand := hud.get_node("BottomStage/CardStage/AutumnCardHandUI") as CardHandUI
	var redraw := hud.get_node("BottomStage/ActionPoints/RedrawHand") as Button
	_expect(
		redraw.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Redraw must remain mouse-interactive at %s." % viewport_size
	)
	_expect(
		_canvas_rect(cooldown).end.y <= _canvas_rect(hand).position.y + 1.5,
		"Cooldown strip must remain above the embedded hand at %s." % viewport_size
	)
	_expect(hand.get_card_button_count() == 8, "Embedded Autumn hand must render eight cards at %s." % viewport_size)
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

	for skill_id in ["one", "two", "three", "four"]:
		hud.call("show_skill_toast", skill_id, skill_id.to_upper())
	var toast_stack := hud.get_node("TopCenterStack/SkillToastStack") as VBoxContainer
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

	viewport.queue_free()
	await process_frame


func _sample_cards() -> Array[Dictionary]:
	return [
		{"id": "ember_bolt", "name": "Ember Bolt", "type": "attack", "description": "Deal damage.", "cost": 1, "level": 1},
		{"id": "shockwave", "name": "Shockwave", "type": "status", "description": "Stun nearby enemies.", "cost": 2, "level": 1},
		{"id": "guard", "name": "Iron Will", "type": "combo", "description": "Gain armor.", "cost": 1, "level": 1},
		{"id": "cleave", "name": "Cleave", "type": "attack", "description": "Arc strike.", "cost": 2, "level": 1},
		{"id": "flame_imbue", "name": "Flame Infusion", "type": "utility", "description": "Gain flame.", "cost": 2, "level": 1},
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
