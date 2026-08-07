extends SceneTree

const MANIFEST_PATH := "res://assets/asset_classification.json"
const SKIPPED_FILENAMES := {
	"README.md": true,
	"asset_classification.json": true,
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists(MANIFEST_PATH), "Asset classification manifest must exist at %s." % MANIFEST_PATH)
	if not FileAccess.file_exists(MANIFEST_PATH):
		_finish()
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_expect(file != null, "Asset classification manifest must be readable.")
	if file == null:
		_finish()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "Asset classification manifest must contain a JSON dictionary.")
	if not parsed is Dictionary:
		_finish()
		return
	var manifest := parsed as Dictionary
	var categories := manifest.get("categories", []) as Array
	_expect(int(manifest.get("schema_version", 0)) == 1, "Asset classification schema must be version 1.")
	_expect(String((manifest.get("policy", {}) as Dictionary).get("unreferenced_assets", "")) == "preserve", "Unused assets must have an explicit preserve policy.")
	_expect(not categories.is_empty(), "Asset classification must define categories.")
	var category_ids: Dictionary = {}
	for category_variant in categories:
		_expect(category_variant is Dictionary, "Every asset category must be a dictionary.")
		if not category_variant is Dictionary:
			continue
		var category := category_variant as Dictionary
		var category_id := String(category.get("id", ""))
		var prefix := String(category.get("prefix", ""))
		_expect(not category_id.is_empty() and not category_ids.has(category_id), "Asset category IDs must be non-empty and unique: %s." % category_id)
		category_ids[category_id] = true
		_expect(prefix.begins_with("assets/") and prefix.ends_with("/"), "Asset category prefixes must be normalized project paths: %s." % prefix)
		_expect(bool(category.get("preserve_unreferenced", false)), "Every category must preserve unreferenced source and candidate art: %s." % category_id)
	for asset_path in _asset_files("res://assets"):
		_expect(_category_for_path(asset_path.trim_prefix("res://"), categories) != "", "Every retained asset must have a classification: %s." % asset_path)
	_finish()


func _asset_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := root_path.path_join(entry)
			if directory.current_is_dir():
				result.append_array(_asset_files(path))
			elif not entry.ends_with(".import") and not SKIPPED_FILENAMES.has(entry):
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return result


func _category_for_path(asset_path: String, categories: Array) -> String:
	var best_id := ""
	var best_length := -1
	for category_variant in categories:
		if not category_variant is Dictionary:
			continue
		var category := category_variant as Dictionary
		var prefix := String(category.get("prefix", ""))
		if asset_path.begins_with(prefix) and prefix.length() > best_length:
			best_id = String(category.get("id", ""))
			best_length = prefix.length()
	return best_id


func _finish() -> void:
	if _failures == 0:
		print("PASS: every retained asset is classified and unused material remains preserved")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
