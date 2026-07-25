extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_paths: Array[String] = []
	_collect_scenes("res://scenes", scene_paths)
	var basename_owners: Dictionary = {}

	for scene_path in scene_paths:
		var basename := scene_path.get_file().to_lower()
		if basename_owners.has(basename):
			_fail(
				"Duplicate scene basename '%s': %s and %s"
				% [basename, basename_owners[basename], scene_path]
			)
		else:
			basename_owners[basename] = scene_path

		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("Scene must load: %s" % scene_path)

	if scene_paths.is_empty():
		_fail("Scene registry must contain scenes.")

	quit(0 if _failures == 0 else 1)


func _collect_scenes(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_fail("Cannot open scene directory: %s" % directory_path)
		return

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scenes(child_path, output)
		elif entry.get_extension().to_lower() == "tscn":
			output.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
