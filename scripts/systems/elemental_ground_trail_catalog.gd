class_name ElementalGroundTrailCatalog
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/elemental_ground_trail_profiles.json"
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")
const VALID_TOPOLOGIES := [
	"burning_scar",
	"frozen_rift",
	"toxic_puddle",
]
const REQUIRED_KEYS := [
	"id",
	"element",
	"topology",
	"slots",
	"atlas_path",
	"atlas_size",
	"atlas_regions",
	"duration",
	"segment_spacing",
	"width",
	"max_segments",
	"core_color",
	"edge_color",
	"accent_color",
	"debris_color",
	"pulse_speed",
	"edge_jitter",
	"accent_density",
	"debris_count",
]
const REQUIRED_SLOTS := ["core", "edge", "accent", "debris"]

var _taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()
var _profiles: Dictionary = {}


func load_catalog(path: String = DEFAULT_DATA_PATH) -> bool:
	_profiles.clear()
	if not FileAccess.file_exists(path):
		push_error("Elemental ground trail catalog not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Elemental ground trail catalog could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Elemental ground trail catalog root must be a Dictionary: %s" % path)
		return false
	var profile_variants: Variant = (parsed as Dictionary).get("profiles", null)
	if not profile_variants is Array or (profile_variants as Array).is_empty():
		push_error("Elemental ground trail catalog needs a non-empty profiles array: %s" % path)
		return false
	for profile_variant in profile_variants as Array:
		if not profile_variant is Dictionary:
			push_error("Elemental ground trail profiles must be dictionaries: %s" % path)
			_profiles.clear()
			return false
		var profile := (profile_variant as Dictionary).duplicate(true)
		if not _validate_profile(profile):
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


func _validate_profile(profile: Dictionary) -> bool:
	for key in REQUIRED_KEYS:
		if not profile.has(key):
			push_error("Elemental ground trail profile is missing '%s'." % key)
			return false
	var profile_id := String(profile.get("id", "")).strip_edges()
	var element := String(profile.get("element", "")).strip_edges()
	var topology := String(profile.get("topology", "")).strip_edges()
	if profile_id.is_empty() or _profiles.has(profile_id):
		push_error("Elemental ground trail ID must be non-empty and unique: %s" % profile_id)
		return false
	if not bool(_taxonomy.call("is_valid", element)):
		push_error("Elemental ground trail has an invalid canonical element: %s" % profile_id)
		return false
	if topology not in VALID_TOPOLOGIES:
		push_error("Elemental ground trail has an unsupported topology: %s" % profile_id)
		return false
	var slots_variant: Variant = profile.get("slots", null)
	if not slots_variant is Dictionary:
		push_error("Elemental ground trail slots must be a Dictionary: %s" % profile_id)
		return false
	var slots := slots_variant as Dictionary
	var slot_values: Dictionary = {}
	for slot_name in REQUIRED_SLOTS:
		var slot_value := String(slots.get(slot_name, "")).strip_edges()
		if slot_value.is_empty() or slot_values.has(slot_value):
			push_error("Elemental ground trail slots must be named and distinct: %s" % profile_id)
			return false
		slot_values[slot_value] = true
	if not _validate_atlas_contract(profile, profile_id):
		return false
	if (
		float(profile.get("duration", 0.0)) <= 0.0
		or float(profile.get("segment_spacing", 0.0)) < 24.0
		or float(profile.get("width", 0.0)) < 24.0
		or int(profile.get("max_segments", 0)) < 2
		or int(profile.get("max_segments", 0)) > 32
		or float(profile.get("pulse_speed", 0.0)) <= 0.0
		or float(profile.get("edge_jitter", -1.0)) < 0.0
		or float(profile.get("edge_jitter", 2.0)) > 1.0
		or int(profile.get("accent_density", 0)) < 1
		or int(profile.get("accent_density", 0)) > 8
		or int(profile.get("debris_count", 0)) < 1
		or int(profile.get("debris_count", 0)) > 10
	):
		push_error("Elemental ground trail numeric budget is invalid: %s" % profile_id)
		return false
	for color_key in ["core_color", "edge_color", "accent_color", "debris_color"]:
		if not Color.html_is_valid(String(profile.get(color_key, ""))):
			push_error("Elemental ground trail color is invalid: %s.%s" % [profile_id, color_key])
			return false
	return true


func _validate_atlas_contract(profile: Dictionary, profile_id: String) -> bool:
	var atlas_path := String(profile.get("atlas_path", "")).strip_edges()
	if atlas_path.is_empty() or not ResourceLoader.exists(atlas_path, "Texture2D"):
		push_error("Elemental ground trail atlas texture is missing: %s" % profile_id)
		return false
	var atlas := load(atlas_path) as Texture2D
	if atlas == null:
		push_error("Elemental ground trail atlas could not be loaded: %s" % profile_id)
		return false
	var atlas_size_variant: Variant = profile.get("atlas_size", null)
	if not atlas_size_variant is Array or (atlas_size_variant as Array).size() != 2:
		push_error("Elemental ground trail atlas_size must contain width and height: %s" % profile_id)
		return false
	var atlas_size_values := atlas_size_variant as Array
	var declared_size := Vector2i(
		int(atlas_size_values[0]),
		int(atlas_size_values[1])
	)
	if declared_size.x <= 0 or declared_size.y <= 0:
		push_error("Elemental ground trail atlas_size must be positive: %s" % profile_id)
		return false
	if Vector2i(atlas.get_size()) != declared_size:
		push_error("Elemental ground trail atlas_size does not match the texture: %s" % profile_id)
		return false
	var regions_variant: Variant = profile.get("atlas_regions", null)
	if not regions_variant is Dictionary:
		push_error("Elemental ground trail atlas_regions must be a Dictionary: %s" % profile_id)
		return false
	var regions := regions_variant as Dictionary
	var occupied_regions: Array[Rect2i] = []
	for slot_name in REQUIRED_SLOTS:
		var region_variant: Variant = regions.get(slot_name, null)
		if not region_variant is Array or (region_variant as Array).size() != 4:
			push_error(
				"Elemental ground trail atlas region must be [x, y, width, height]: %s.%s"
				% [profile_id, slot_name]
			)
			return false
		var values := region_variant as Array
		var region := Rect2i(
			int(values[0]),
			int(values[1]),
			int(values[2]),
			int(values[3])
		)
		if (
			region.position.x < 0
			or region.position.y < 0
			or region.size.x <= 0
			or region.size.y <= 0
			or region.end.x > declared_size.x
			or region.end.y > declared_size.y
		):
			push_error(
				"Elemental ground trail atlas region is outside the texture: %s.%s"
				% [profile_id, slot_name]
			)
			return false
		for occupied in occupied_regions:
			if occupied.intersects(region):
				push_error(
					"Elemental ground trail atlas regions must not overlap: %s.%s"
					% [profile_id, slot_name]
				)
				return false
		occupied_regions.append(region)
	return true
