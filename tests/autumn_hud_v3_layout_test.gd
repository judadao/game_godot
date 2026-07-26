extends SceneTree

const HUD_PATH := "res://scenes/ui/autumn/AutumnCombatHUD.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(HUD_PATH), "AutumnCombatHUD must exist for responsive-layout verification.")
	if _failures > 0:
		quit(1)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	quit(0 if _failures == 0 else 1)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(hud)
	await process_frame
	await process_frame
	for node_path in ["TopLeftStack", "TopCenterStack", "BottomStage"]:
		var node := hud.get_node(node_path) as Control
		_expect(_inside_viewport(_canvas_rect(node), viewport_size), "%s must fit at %s." % [node_path, viewport_size])
	var hand := hud.get_node("BottomStage/CardHandUI") as Control
	var stage := hud.get_node("BottomStage") as Control
	_expect(_canvas_rect(stage).encloses(_canvas_rect(hand)), "Embedded hand must remain within BottomStage at %s." % viewport_size)
	hand.call("set_cards", _sample_cards(), 5.0)
	hand.call("set_action_points", 5.0, 5.0)
	await process_frame
	await process_frame
	var safe_area := hand.get_node("CardSafeArea") as Control
	var safe_rect := _canvas_rect(safe_area)
	for card in hand.find_children("Card_*", "Button", true, false):
		_expect(safe_rect.encloses(_canvas_rect(card as Control)), "Every card must stay within the embedded bottom stage at %s." % viewport_size)
	for panel_path in ["TopLeftStack/ActiveStatusList", "TopLeftStack/ObjectivePanel", "TopCenterStack/BossStack", "BottomStage/PlayerVitals", "BottomStage/BottomRightPanel"]:
		var panel := hud.get_node_or_null(panel_path) as Control
		_expect(panel != null, "%s must be authored at %s." % [panel_path, viewport_size])
		if panel == null:
			continue
		_expect(_inside_viewport(_canvas_rect(panel), viewport_size), "%s must remain readable at %s." % [panel_path, viewport_size])
	viewport.queue_free()
	await process_frame


func _sample_cards() -> Array[Dictionary]:
	return [
		{"id": "ember_bolt", "name": "Ember Bolt", "type": "attack", "cost": 1, "fixed": true},
		{"id": "quickstep", "name": "Quickstep", "type": "utility", "cost": 1, "fixed": true},
		{"id": "iron_will", "name": "Iron Will", "type": "combo", "cost": 1},
		{"id": "cleave", "name": "Cleave", "type": "attack", "cost": 2},
		{"id": "healing_light", "name": "Healing Light", "type": "healing", "cost": 1},
		{"id": "gale_lunge", "name": "Gale Lunge", "type": "attack", "cost": 2},
		{"id": "stone_form", "name": "Stone Form", "type": "combo", "cost": 2},
		{"id": "meteor", "name": "Meteor", "type": "ultimate", "cost": 5},
	]


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= viewport_size.x + 0.5 and rect.end.y <= viewport_size.y + 0.5


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
