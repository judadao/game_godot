extends SceneTree

const QUICK_SAVE_PATH := "user://saves/quick_save.json"
const LEGACY_AUTUMN_TREE_PATH := "res://scenes/maps/autumn_tree/AutumnTreeMap.tscn"
const TOWN_CANONICAL_PATH := "res://scenes/maps/town.tscn"
const AUTUMN_AUTHORITATIVE_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var player := game.get("player") as Node
	var health_before := int(player.get("health"))
	_expect(
		bool(game.call("_apply_quick_save_payload", {
			"wallet_gold": 7,
			"inventory": "legacy-invalid",
			"merchant_catalogs": [],
			"player": "legacy-invalid",
		})),
		"Malformed legacy nested fields must be sanitized without aborting load."
	)
	_expect(game.get("player_inventory") is Dictionary, "Malformed legacy inventory must preserve safe defaults.")
	_expect(int(player.get("health")) == health_before, "Malformed legacy player data must preserve current stats.")
	_expect(
		bool(game.call("_apply_quick_save_payload", {
			"player": {"health": 55, "position": "legacy-invalid"},
		})),
		"Malformed legacy position must not block valid player fields."
	)
	_expect(int(player.get("health")) == 55, "Valid legacy player fields must still migrate.")
	_expect(
		String((game.call("_build_quick_save_payload") as Dictionary).get("map_path", "")) == TOWN_CANONICAL_PATH,
		"New quick saves must persist the current map's canonical identity."
	)

	var previous_save := _capture_quick_save()
	_write_quick_save({
		"schema_version": 1,
		"map_path": LEGACY_AUTUMN_TREE_PATH,
		"player": {},
		"wallet_gold": 7,
		"inventory": {},
		"merchant_catalogs": {},
	})
	var menu := Control.new()
	game.call("_load_quick_slot", menu)
	await process_frame
	await process_frame
	var migrated_map := game.get("current_map") as Node
	_expect(
		migrated_map != null and migrated_map.scene_file_path == AUTUMN_AUTHORITATIVE_PATH,
		"Quick load must resolve a legacy Autumn Tree path before checking and loading the scene."
	)
	_restore_quick_save(previous_save)
	menu.free()
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _capture_quick_save() -> Dictionary:
	if not FileAccess.file_exists(QUICK_SAVE_PATH):
		return {"existed": false, "content": PackedByteArray()}
	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.READ)
	return {
		"existed": true,
		"content": file.get_buffer(file.get_length()) if file != null else PackedByteArray(),
	}


func _write_quick_save(payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.WRITE)
	_expect(file != null, "Quick-save migration fixture must be writable.")
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.flush()


func _restore_quick_save(snapshot: Dictionary) -> void:
	if bool(snapshot.get("existed", false)):
		var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(snapshot.get("content", PackedByteArray()) as PackedByteArray)
			file.flush()
		return
	if FileAccess.file_exists(QUICK_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QUICK_SAVE_PATH))
