extends SceneTree

const MAP_PATH := "res://data/maintenance_scope_map.json"
const ALLOWED_SUITES := {
	"assets": true,
	"cards": true,
	"combat": true,
	"forge": true,
	"maintenance": true,
	"maps": true,
	"scene": true,
	"story": true,
	"systems": true,
	"town": true,
	"ui": true,
	"vfx": true,
}

var _failures := 0


func _init() -> void:
	_expect(FileAccess.file_exists(MAP_PATH), "Maintenance scope map must exist for fast task routing.")
	if not FileAccess.file_exists(MAP_PATH):
		_finish()
		return
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_expect(parsed is Dictionary, "Maintenance scope map must contain a JSON dictionary.")
	if not parsed is Dictionary:
		_finish()
		return
	var document := parsed as Dictionary
	_expect(int(document.get("schema_version", 0)) == 1, "Maintenance scope map schema must be version 1.")
	var domains := document.get("domains", []) as Array
	_expect(domains.size() >= 8, "Maintenance scope map must cover the project's major independent domains.")
	var ids: Dictionary = {}
	for domain_variant in domains:
		_expect(domain_variant is Dictionary, "Every maintenance domain must be a dictionary.")
		if not domain_variant is Dictionary:
			continue
		var domain := domain_variant as Dictionary
		var domain_id := String(domain.get("id", ""))
		_expect(not domain_id.is_empty() and not ids.has(domain_id), "Maintenance domain IDs must be unique: %s." % domain_id)
		ids[domain_id] = true
		_expect(ALLOWED_SUITES.has(String(domain.get("test_suite", ""))), "Every maintenance domain must route to a focused test suite: %s." % domain_id)
		var authority_paths := domain.get("authority_paths", []) as Array
		_expect(not authority_paths.is_empty(), "Every maintenance domain must identify authoritative paths: %s." % domain_id)
		for path_variant in authority_paths:
			var path := String(path_variant)
			_expect(FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)), "Maintenance authority path must exist: %s." % path)
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: maintenance scope map routes changes to explicit authorities and focused tests")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
