extends SceneTree

const QUICK_SAVE_SERVICE := preload("res://scripts/systems/quick_save_service.gd")
const TEST_ROOT := "user://tests/quick_save_service"
const SAVE_PATH := TEST_ROOT + "/slot.json"
const TEMP_PATH := TEST_ROOT + "/slot.tmp"
const BACKUP_PATH := TEST_ROOT + "/slot.json.bak"

var _failures := 0


func _init() -> void:
	_cleanup()
	var first_result: Dictionary = QUICK_SAVE_SERVICE.write_json(
		{"schema_version": 1, "wallet_gold": 12}, SAVE_PATH, TEMP_PATH, BACKUP_PATH
	)
	_expect(bool(first_result.get("ok", false)), "Quick-save service must create a valid JSON slot.")
	var first_load: Dictionary = QUICK_SAVE_SERVICE.read_json(SAVE_PATH)
	_expect(bool(first_load.get("ok", false)), "Quick-save service must read a valid JSON slot.")
	_expect(int((first_load.get("payload", {}) as Dictionary).get("wallet_gold", 0)) == 12, "Loaded payload must match the saved data.")
	var second_result: Dictionary = QUICK_SAVE_SERVICE.write_json(
		{"schema_version": 1, "wallet_gold": 24}, SAVE_PATH, TEMP_PATH, BACKUP_PATH
	)
	_expect(bool(second_result.get("ok", false)), "Replacing a quick save must remain transactional.")
	_expect(FileAccess.file_exists(BACKUP_PATH), "Replacing an existing slot must preserve a backup.")
	var backup_load: Dictionary = QUICK_SAVE_SERVICE.read_json(BACKUP_PATH)
	_expect(int((backup_load.get("payload", {}) as Dictionary).get("wallet_gold", 0)) == 12, "Backup must contain the previous valid slot.")
	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{broken")
		corrupt.flush()
	var corrupt_load: Dictionary = QUICK_SAVE_SERVICE.read_json(SAVE_PATH)
	_expect(not bool(corrupt_load.get("ok", true)), "Corrupted JSON must be rejected without returning a payload.")
	_cleanup()
	if _failures == 0:
		print("PASS: quick-save persistence is isolated, transactional, and validates JSON")
	quit(1 if _failures > 0 else 0)


func _cleanup() -> void:
	for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
