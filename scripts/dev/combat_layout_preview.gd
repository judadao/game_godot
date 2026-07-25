extends Node2D

@onready var preview_camera: Camera2D = $PreviewCamera
@onready var hud: HUD = $HUDLayer/HUD
@onready var card_hand: CardHandUI = $HUDLayer/CardHandUI


func _ready() -> void:
	var gameplay_camera := get_node_or_null("AutumnForest/Player/Camera2D") as Camera2D
	if gameplay_camera != null:
		gameplay_camera.enabled = false
	preview_camera.enabled = true

	hud.set_health(43, 100)
	hud.set_mana(31, 50)
	hud.set_stamina(100, 100)
	hud.set_player_level(1)
	hud.set_player_class("Adventurer")
	hud.set_currency(45)
	hud.set_experience(0, 40)
	hud.set_objective("SURVIVAL PHASE 1", "36s   Enemies 7 / 8")

	card_hand.set_cards(_sample_cards(), 5.0)
	card_hand.set_action_points(5.0, 5.0)
	card_hand.set_combo("—  [0/4]", "Same type stacks / four types max")


func _sample_cards() -> Array[Dictionary]:
	return [
		_card("Ember Bolt", "attack", "Deal 12 damage and apply burn.", 1),
		_card("Guard", "defense", "Gain 12 block.", 1),
		_card("Quickstep", "skill", "Dash through danger.", 1),
		_card("Cleave", "attack", "Strike enemies in an arc.", 2),
		_card("Flame Infusion", "power", "Future attacks gain flame.", 2),
		_card("Frost Burst", "power", "Future attacks gain frost.", 2),
		_card("Healing Light", "skill", "Restore health over time.", 2),
		_card("Meteor", "ultimate", "Call down a devastating meteor.", 5),
	]


func _card(name_text: String, type_text: String, description: String, cost: int) -> Dictionary:
	return {
		"name": name_text,
		"type": type_text,
		"description": description,
		"cost": cost,
		"level": 1,
	}
