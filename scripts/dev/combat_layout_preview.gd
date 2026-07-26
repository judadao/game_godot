extends Node2D

const CAPTURE_PATH_ENV := "AUTUMN_HUD_CAPTURE_PATH"

@onready var preview_camera: Camera2D = $PreviewCamera
@onready var hud: AutumnCombatHUD = $HUDLayer/HUD
@onready var card_hand: CardHandUI = $HUDLayer/HUD/BottomStage/CardStage/AutumnCardHandUI


func _ready() -> void:
	var gameplay_camera := get_node_or_null("AutumnBattleMapV2/Player/Camera2D") as Camera2D
	if gameplay_camera != null:
		gameplay_camera.enabled = false
	preview_camera.enabled = true
	_apply_preview_camera_scale()
	if not get_viewport().size_changed.is_connected(_apply_preview_camera_scale):
		get_viewport().size_changed.connect(_apply_preview_camera_scale)

	hud.set_health(43, 100)
	hud.set_mana(31, 50)
	hud.set_stamina(100, 100)
	hud.set_player_level(1)
	hud.set_player_class("Adventurer")
	hud.set_currency(45)
	hud.set_experience(0, 40)
	hud.set_material_count(98)
	hud.set_action_point_regen(0.8)
	hud.set_objective("SURVIVAL PHASE 1", "36s   Enemies 7 / 8")
	hud.set_active_statuses([
		{"id": "iron_momentum", "name": "Iron Momentum", "icon": "◆", "remaining_seconds": 2.8},
		{"id": "renewal", "name": "Verdant Renewal", "icon": "+", "remaining_seconds": 4.1},
	])
	hud.set_boss_health("HEARTWOOD GUARDIAN", 72, 100)
	hud.set_cooldown_cards([
		{"card_id": "guard", "name": "Iron Will", "remaining_seconds": 6.2},
	])
	hud.show_skill_toast("iron_momentum", "IRON MOMENTUM")

	card_hand.set_cards(_sample_cards(), 3.7)
	card_hand.set_action_points(3.7, 5.0)
	if OS.has_environment(CAPTURE_PATH_ENV):
		call_deferred("_capture_preview")


func _capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_path := OS.get_environment(CAPTURE_PATH_ENV).strip_edges()
	if capture_path.is_empty():
		get_tree().quit(1)
		return
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("Failed to save Autumn HUD preview to %s." % capture_path)
	get_tree().quit(0 if error == OK else 1)


func _apply_preview_camera_scale() -> void:
	preview_camera.zoom = _preview_zoom_for_size(get_viewport_rect().size)


func _preview_zoom_for_size(viewport_size: Vector2) -> Vector2:
	var scale := maxf(0.5, viewport_size.y / 720.0)
	return Vector2.ONE * scale


func _sample_cards() -> Array[Dictionary]:
	return [
		_card("Ember Bolt", "attack", "Deal 12 damage and apply burn.", 1, "ember_bolt"),
		_card("Frost Bind", "status", "Slow one enemy.", 1, "frost_bind"),
		_card("Iron Will", "combo", "Gain weak super armor for four seconds.", 1),
		_card("Cleave", "attack", "Strike enemies in an arc.", 2),
		_card("Flame Infusion", "power", "Future attacks gain flame.", 2),
		_card("Frost Burst", "power", "Future attacks gain frost.", 2),
		_card("Healing Light", "healing", "Restore health immediately.", 2),
		_card("Meteor", "ultimate", "Call down a devastating meteor.", 5),
	]


func _card(
	name_text: String,
	type_text: String,
	description: String,
	cost: int,
	card_id: String = "",
	fixed: bool = false
) -> Dictionary:
	return {
		"id": card_id,
		"name": name_text,
		"type": type_text,
		"description": description,
		"cost": cost,
		"level": 1,
		"fixed": fixed,
	}
