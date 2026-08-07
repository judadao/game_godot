class_name QuickSaveService
extends RefCounted


static func write_json(
	payload: Dictionary,
	save_path: String,
	temp_path: String,
	backup_path: String
) -> Dictionary:
	var save_directory := ProjectSettings.globalize_path(save_path.get_base_dir())
	var create_error := DirAccess.make_dir_recursive_absolute(save_directory)
	if create_error != OK:
		return _failure("Save failed: cannot create save folder.")

	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return _failure("Save failed: cannot write temporary file.")
	temp_file.store_string(JSON.stringify(payload, "\t"))
	temp_file.flush()
	temp_file = null

	var validation := read_json(temp_path)
	if not bool(validation.get("ok", false)):
		remove_if_present(temp_path)
		return _failure("Save failed: validation error.")

	if FileAccess.file_exists(save_path):
		if not copy_file(save_path, backup_path):
			remove_if_present(temp_path)
			return _failure("Save failed: cannot preserve previous save.")
		remove_if_present(save_path)

	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(save_path)
	)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			copy_file(backup_path, save_path)
		return _failure("Save failed while replacing quick save.")
	return {"ok": true, "message": "Game saved."}


static func read_json(path: String) -> Dictionary:
	var save_file := FileAccess.open(path, FileAccess.READ)
	if save_file == null:
		return _failure("No quick save found.")
	var parser := JSON.new()
	if parser.parse(save_file.get_as_text()) != OK:
		return _failure("Load failed: save data is corrupted.")
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _failure("Load failed: save data is corrupted.")
	return {"ok": true, "payload": (parsed as Dictionary).duplicate(true)}


static func copy_file(source_path: String, target_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(source.get_buffer(source.get_length()))
	target.flush()
	return true


static func remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "payload": {}}
