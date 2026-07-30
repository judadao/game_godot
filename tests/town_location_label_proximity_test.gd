extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town/TownMap.tscn")
const BUILDING_LABELS := {
	"MaterialYard": "MaterialYard",
	"PlayerBlacksmith": "PlayerBlacksmith",
	"TownHall": "TownHall",
	"SwordSoulShop": "SwordSoulShop",
	"EquipmentBlueprintShop": "EquipmentBlueprintShop",
	"FarEastResidence": "FarEastResidence",
}
const MAX_LABEL_BOTTOM_BY_NAME := {
	"MaterialYard": 440.0,
	"PlayerBlacksmith": 381.0,
	"TownHall": 435.0,
	"SwordSoulShop": 474.0,
	"EquipmentBlueprintShop": 493.0,
	"FarEastResidence": 485.0,
}
const B2_PLAQUE_SOURCE := "res://assets/town/modular_v2/ui/building_label_plaque.png"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := TOWN_SCENE.instantiate()
	var player := town.get_node("Player")
	(player as Node2D).position = Vector2(800, 702)
	root.add_child(town)
	await process_frame
	await process_frame

	var identity := town.get_node("EternalForgeIdentity")
	var entrances := town.get_node("BuildingEntrances")
	for label_name in BUILDING_LABELS:
		var label := identity.get_node("LocationLabels/%s" % label_name) as Label
		_expect(not label.visible, "%s label must stay hidden away from its foundation." % label_name)
		_expect(
			label.position.y + label.size.y <= float(MAX_LABEL_BOTTOM_BY_NAME[label_name]),
			"%s label must sit above the visible building silhouette." % label_name
		)
		var plaque := label.get_theme_stylebox("normal") as StyleBoxTexture
		_expect(plaque != null, "%s label must use the B2 wooden plaque texture." % label_name)
		if plaque != null:
			_expect(
				plaque.texture != null
					and plaque.texture.resource_path == B2_PLAQUE_SOURCE,
				"%s label must resolve the shared B2 plaque source." % label_name
			)

	var material_entrance := entrances.get_node("MaterialYard")
	var material_label := identity.get_node("LocationLabels/MaterialYard") as Label
	material_entrance.emit_signal("interaction_available", material_entrance, player)
	await process_frame
	_expect(material_label.visible, "Material Yard label must appear over its active foundation.")
	for label_name in BUILDING_LABELS:
		if label_name == "MaterialYard":
			continue
		_expect(
			not (identity.get_node("LocationLabels/%s" % label_name) as Label).visible,
			"Only the foundation currently containing the player may reveal its label."
		)

	material_entrance.emit_signal("interaction_unavailable", material_entrance, player)
	await process_frame
	_expect(not material_label.visible, "Material Yard label must hide after leaving its foundation.")

	var non_player := Node2D.new()
	town.add_child(non_player)
	material_entrance.emit_signal("interaction_available", material_entrance, non_player)
	await process_frame
	_expect(not material_label.visible, "Non-player bodies must not reveal building labels.")

	town.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
