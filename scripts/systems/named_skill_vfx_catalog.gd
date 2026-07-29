class_name NamedSkillVFXCatalog
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/named_skill_vfx_profiles.json"
const REQUIRED_KEYS := [
	"id",
	"display_name",
	"kind",
	"atlas_path",
	"rows",
	"columns",
	"row",
	"region_y",
	"motion",
	"duration",
	"anticipation_time",
	"impact_time",
	"source",
	"target",
	"scale",
	"preview_scale",
	"shake_strength",
	"hit_stop",
]

var _profiles: Dictionary = {}


func load_catalog(path: String = DEFAULT_DATA_PATH) -> bool:
	_profiles.clear()
	if not FileAccess.file_exists(path):
		push_error("Named skill VFX catalog not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Named skill VFX catalog could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Named skill VFX catalog root must be a Dictionary.")
		return false
	var rows_by_atlas: Dictionary = {}
	for profile_variant in (parsed as Dictionary).get("profiles", []):
		if not profile_variant is Dictionary:
			push_error("Named skill VFX profiles must be dictionaries.")
			_profiles.clear()
			return false
		var profile := (profile_variant as Dictionary).duplicate(true)
		if not _validate_profile(profile, rows_by_atlas):
			_profiles.clear()
			return false
		_profiles[String(profile["id"])] = profile
	return not _profiles.is_empty()


func has_profile(profile_id: String) -> bool:
	return _profiles.has(profile_id)


func get_profile(profile_id: String) -> Dictionary:
	return (_profiles.get(profile_id, {}) as Dictionary).duplicate(true)


func get_all_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_variant in _profiles.values():
		result.append((profile_variant as Dictionary).duplicate(true))
	result.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left.get("id", "")) < String(right.get("id", ""))
	)
	return result


func _validate_profile(profile: Dictionary, rows_by_atlas: Dictionary) -> bool:
	for key in REQUIRED_KEYS:
		if not profile.has(key):
			push_error("Named skill VFX profile is missing '%s'." % key)
			return false
	var profile_id := String(profile.get("id", "")).strip_edges()
	var atlas_path := String(profile.get("atlas_path", "")).strip_edges()
	var rows := int(profile.get("rows", 0))
	var columns := int(profile.get("columns", 0))
	var row := int(profile.get("row", -1))
	if profile_id.is_empty() or _profiles.has(profile_id):
		push_error("Named skill VFX id must be non-empty and unique: %s" % profile_id)
		return false
	if not FileAccess.file_exists(atlas_path):
		push_error("Named skill VFX atlas does not exist: %s" % atlas_path)
		return false
	if rows <= 0 or columns != 5 or row < 0 or row >= rows:
		push_error("Named skill VFX profile has an invalid atlas grid: %s" % profile_id)
		return false
	var region_y := profile.get("region_y", []) as Array
	if region_y.size() != 2 or int(region_y[0]) < 0 or int(region_y[1]) <= int(region_y[0]):
		push_error("Named skill VFX profile has an invalid vertical crop: %s" % profile_id)
		return false
	if not profile.get("source", []) is Array or (profile.get("source", []) as Array).size() != 2:
		push_error("Named skill VFX source must be a two-value array: %s" % profile_id)
		return false
	if not profile.get("target", []) is Array or (profile.get("target", []) as Array).size() != 2:
		push_error("Named skill VFX target must be a two-value array: %s" % profile_id)
		return false
	var anticipation := float(profile.get("anticipation_time", 0.0))
	var impact := float(profile.get("impact_time", 0.0))
	var duration := float(profile.get("duration", 0.0))
	if anticipation <= 0.0 or impact <= anticipation or duration <= impact:
		push_error("Named skill VFX timing is invalid: %s" % profile_id)
		return false
	var row_key := "%s:%d" % [atlas_path, row]
	if rows_by_atlas.has(row_key):
		push_error("Named skill VFX atlas rows must be unique: %s" % row_key)
		return false
	rows_by_atlas[row_key] = profile_id
	return true
