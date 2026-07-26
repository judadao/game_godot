class_name SaveService
extends RefCounted


func save_meta(path: String, data: Dictionary) -> bool:
	var directory := path.get_base_dir()
	if not directory.is_empty():
		var create_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if create_error != OK:
			return false
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file = null
	var validation_file := FileAccess.open(temporary_path, FileAccess.READ)
	if validation_file == null or not JSON.parse_string(validation_file.get_as_text()) is Dictionary:
		_remove_if_present(temporary_path)
		return false
	validation_file = null
	var backup_path := path + ".bak"
	_remove_if_present(backup_path)
	var had_previous := FileAccess.file_exists(path)
	if had_previous and not _copy_file(path, backup_path):
		_remove_if_present(temporary_path)
		return false
	if had_previous:
		_remove_if_present(path)
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		if had_previous:
			_copy_file(backup_path, path)
		return false
	_remove_if_present(backup_path)
	return true


func load_meta(path: String) -> Dictionary:
	var meta := MetaState.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return meta.to_dict()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		meta.apply_dict(parsed)
	return meta.to_dict()


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _copy_file(source_path: String, target_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(source.get_buffer(source.get_length()))
	target.flush()
	return true
