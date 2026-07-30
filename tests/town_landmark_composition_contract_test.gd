extends SceneTree

const LAYOUT_PATH := "res://data/town_modular_layout.json"
const EXPECTED_SOURCE_BY_ID := {
	"background_sky":
		"res://assets/town/modular_v3/background/town_a_background_plate.png",
	"background_ancient_town_tree":
		"res://assets/town/modular_v3/background/ancient_town_tree.png",
	"eternal_flame":
		"res://assets/town/modular_v3/landmarks/eternal_forge_monument.png",
	"battle_portal":
		"res://assets/town/modular_v3/landmarks/battle_portal.png",
}
const OLD_BACKGROUND_LAYER_IDS := [
	"background_mountains",
	"background_distant_city",
	"background_forest",
]
const ASPECT_LOCKED_LANDMARK_IDS := [
	"background_ancient_town_tree",
	"eternal_flame",
	"battle_portal",
]
const RIGHT_FACADE_CLEARANCE_IDS := [
	"laundry_line",
	"water_trough",
	"woodpile",
	"street_signpost",
	"shrub_cluster",
	"ivy_strip",
]
const MAX_ASPECT_DISTORTION_RATIO := 0.02

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var layout := _load_layout()
	if layout.is_empty():
		_finish()
		return

	var entries_by_id := _index_entries(layout.get("layers", []))
	_assert_a_background_plate(entries_by_id)
	_assert_old_background_layers_hidden(entries_by_id)
	_assert_landmark_aspect_ratios(entries_by_id)
	_assert_right_facade_clearance(entries_by_id)
	_finish()


func _load_layout() -> Dictionary:
	_expect(FileAccess.file_exists(LAYOUT_PATH), "Town modular layout data must exist.")
	if not FileAccess.file_exists(LAYOUT_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_expect(parsed is Dictionary, "Town modular layout root must be a JSON object.")
	return parsed as Dictionary if parsed is Dictionary else {}


func _index_entries(layers_variant: Variant) -> Dictionary:
	_expect(layers_variant is Array, "Town modular layout layers must be an array.")
	if not layers_variant is Array:
		return {}
	var entries_by_id: Dictionary = {}
	for entry_variant in layers_variant as Array:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var entry_id := String(entry.get("id", ""))
		if not entry_id.is_empty():
			entries_by_id[entry_id] = entry
	return entries_by_id


func _assert_a_background_plate(entries_by_id: Dictionary) -> void:
	var background := _require_entry(entries_by_id, "background_sky")
	if background.is_empty():
		return
	_expect(
		String(background.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_sky"]),
		"Town must use the approved A background plate as its exact sky source."
	)
	_expect(
		bool(background.get("visible", false)),
		"The approved A background plate must remain visible."
	)


func _assert_old_background_layers_hidden(entries_by_id: Dictionary) -> void:
	for entry_id in OLD_BACKGROUND_LAYER_IDS:
		var entry := _require_entry(entries_by_id, entry_id)
		if entry.is_empty():
			continue
		_expect(
			not bool(entry.get("visible", true)),
			"Legacy Town background layer must remain hidden: %s" % entry_id
		)


func _assert_landmark_aspect_ratios(entries_by_id: Dictionary) -> void:
	for entry_id in ASPECT_LOCKED_LANDMARK_IDS:
		var entry := _require_entry(entries_by_id, entry_id)
		if entry.is_empty():
			continue
		var expected_source := String(EXPECTED_SOURCE_BY_ID[entry_id])
		var actual_source := String(entry.get("source", ""))
		_expect(
			actual_source == expected_source,
			"%s must use its expected modular_v3 source." % entry_id
		)
		_expect(
			bool(entry.get("visible", false)),
			"%s must remain visible in the Town composition." % entry_id
		)
		_assert_target_aspect(entry_id, entry, expected_source)


func _assert_target_aspect(
	entry_id: String,
	entry: Dictionary,
	source_path: String
) -> void:
	var texture := load(source_path) as Texture2D
	_expect(texture != null, "%s source texture must load: %s" % [entry_id, source_path])
	if texture == null:
		return
	var target_size := entry.get("target_size", []) as Array
	_expect(
		target_size.size() == 2,
		"%s must define a two-axis target size." % entry_id
	)
	if target_size.size() != 2:
		return
	var source_aspect := float(texture.get_width()) / float(texture.get_height())
	var target_aspect := float(target_size[0]) / float(target_size[1])
	var distortion_ratio := absf(target_aspect / source_aspect - 1.0)
	_expect(
		distortion_ratio <= MAX_ASPECT_DISTORTION_RATIO,
		(
			"%s target size must preserve source aspect within 2%%; "
			+ "source aspect %.4f, target aspect %.4f, distortion %.2f%%."
		)
		% [
			entry_id,
			source_aspect,
			target_aspect,
			distortion_ratio * 100.0,
		]
	)


func _assert_right_facade_clearance(entries_by_id: Dictionary) -> void:
	for entry_id in RIGHT_FACADE_CLEARANCE_IDS:
		var entry := _require_entry(entries_by_id, entry_id)
		if entry.is_empty():
			continue
		_expect(
			not bool(entry.get("visible", true)),
			"Right-side facade-clearance object must remain hidden: %s" % entry_id
		)


func _require_entry(entries_by_id: Dictionary, entry_id: String) -> Dictionary:
	_expect(entries_by_id.has(entry_id), "Town layout must define layer: %s" % entry_id)
	return entries_by_id.get(entry_id, {}) as Dictionary


func _finish() -> void:
	if _failures == 0:
		print("Town landmark composition contract passed.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
