extends SceneTree

const AUTUMN_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const TOWN_MAP_PATH := "res://scenes/maps/town/TownMap.tscn"
const SHARED_HUD_PATH := "res://scenes/ui/HUD.tscn"
const AUTUMN_COMBAT_HUD_PATH := "res://scenes/ui/autumn/AutumnCombatHUD.tscn"
const RETIRED_AUTUMN_HUD_PATH := "res://scenes/ui/autumn/AutumnHUD.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load(TOWN_MAP_PATH) as PackedScene).instantiate()
	var autumn := (load(AUTUMN_MAP_PATH) as PackedScene).instantiate()
	root.add_child(town)
	root.add_child(autumn)
	await process_frame
	var town_hud := town.get_node_or_null("EditorHUDReference/HUD") as Control
	var autumn_hud := autumn.get_node_or_null("EditorHUDReference/HUD") as Control
	_expect(town_hud != null and town_hud.scene_file_path == SHARED_HUD_PATH, "Town must retain its shared HUD authority.")
	_expect(autumn_hud != null, "Autumn must expose its map-authored combat HUD.")
	if autumn_hud != null:
		_expect(autumn_hud.scene_file_path == AUTUMN_COMBAT_HUD_PATH, "Autumn must use AutumnCombatHUD.")
		_expect(autumn_hud.scene_file_path != RETIRED_AUTUMN_HUD_PATH, "Autumn may not retain the retired AutumnHUD authority.")
		_expect(
			autumn.get_node_or_null("EditorHUDReference/CardHandUI") == null,
			"Autumn map may not expose a second standalone card-hand authority."
		)
	town.queue_free()
	autumn.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
