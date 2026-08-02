extends SceneTree

const LAYOUT_PATH := "res://data/town_modular_layout.json"
const FORBIDDEN_VISIBLE_FOREST_SOURCES := [
	"res://assets/town/modular_v1/background/forest_layer.png",
	"res://concept/town/can_use/background/parallax_forest_strip_v3.png",
]
const EXPECTED_SOURCE_BY_ID := {
	"background_mountains":
		"res://assets/town/modular_v1/background/mountain_layer.png",
	"background_forest":
		"res://assets/town/modular_v3/background/autumn_forest_canopy_base_v2.png",
	"background_green_ruins":
		"res://assets/town/modular_v3/background/green_ruins_boundary_tower_base_v4.png",
	"background_green_ruins_debris":
		"res://assets/town/modular_v3/background/green_ruins_debris_bush_strip_base_v2.png",
	"background_green_ruins_east_edge":
		"res://assets/town/modular_v3/background/green_ruins_east_edge_cluster_base_v2.png",
	"background_green_ruins_west_edge":
		"res://assets/town/modular_v3/background/green_ruins_east_edge_cluster_base_v2.png",
	"background_ancient_town_tree":
		"res://assets/town/modular_v3/background/autumn_ancient_tree_base_v2.png",
	"ground_transition_west_market":
		"res://assets/town/modular_v3/ground/building_street_transition_modules_base_v2.png",
	"ground_transition_material_forge":
		"res://assets/town/modular_v3/ground/building_street_transition_modules_base_v2.png",
	"ground_transition_forge_portal":
		"res://assets/town/modular_v3/ground/building_street_transition_modules_base_v2.png",
	"ground_transition_hall":
		"res://assets/town/modular_v3/ground/building_street_transition_modules_base_v2.png",
	"ground_transition_east_shops":
		"res://assets/town/modular_v3/ground/building_street_transition_modules_base_v2.png",
	"eternal_flame":
		"res://assets/town/modular_v3/landmarks/eternal_forge_monument_base_v5.png",
	"battle_portal":
		"res://assets/town/modular_v3/landmarks/battle_portal_base_v5.png",
}
const EXPECTED_PLACEMENT_BY_ID := {
	"background_forest": {
		"position": Vector2(971, 430),
		"target_size": Vector2(1942, 600),
	},
	"background_green_ruins": {
		"position": Vector2(220, 390),
		"target_size": Vector2(392, 650),
	},
	"background_green_ruins_debris": {
		"position": Vector2(971, 572),
		"target_size": Vector2(2000, 296),
	},
	"background_green_ruins_east_edge": {
		"position": Vector2(1840, 540),
		"target_size": Vector2(251, 360),
	},
	"background_green_ruins_west_edge": {
		"position": Vector2(70, 530),
		"target_size": Vector2(217, 310),
	},
	"background_ancient_town_tree": {
		"position": Vector2(1020, 330),
		"target_size": Vector2(720, 573),
	},
	"ground_transition_west_market": {
		"position": Vector2(95, 644),
		"target_size": Vector2(180, 46),
	},
	"ground_transition_material_forge": {
		"position": Vector2(400, 644),
		"target_size": Vector2(255, 47),
	},
	"ground_transition_forge_portal": {
		"position": Vector2(760, 647),
		"target_size": Vector2(340, 41),
	},
	"ground_transition_hall": {
		"position": Vector2(1305, 645),
		"target_size": Vector2(245, 45),
	},
	"ground_transition_east_shops": {
		"position": Vector2(1700, 647),
		"target_size": Vector2(330, 40),
	},
	"eternal_flame": {
		"position": Vector2(830, 392),
		"target_size": Vector2(345, 560),
	},
	"battle_portal": {
		"position": Vector2(830, 552),
		"target_size": Vector2(200, 240),
	},
}
const EXPECTED_SOURCE_REGION_BY_ID := {
	"ground_transition_west_market": [8, 8, 426, 110],
	"ground_transition_material_forge": [545, 16, 548, 101],
	"ground_transition_forge_portal": [1234, 20, 799, 96],
	"ground_transition_hall": [545, 16, 548, 101],
	"ground_transition_east_shops": [1234, 20, 799, 96],
}
const REPEATED_GROUND_PREFIXES := [
	"ground_bridge_wall_",
	"ground_stone_road_",
]
const GROUND_OVERLAY_IDS := [
	"road_patch",
	"curb_grass",
	"fallen_leaves",
	"drain_grate",
]
const ASPECT_LOCKED_LANDMARK_IDS := [
	"background_ancient_town_tree",
	"background_green_ruins",
	"background_green_ruins_debris",
	"background_green_ruins_east_edge",
	"background_green_ruins_west_edge",
	"eternal_flame",
	"battle_portal",
]
const RIGHT_FACADE_CLEARANCE_IDS := [
	"laundry_line",
	"water_trough",
	"woodpile",
	"street_signpost",
	"shrub_cluster",
	"small_tree",
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
	_assert_separated_background_layers(entries_by_id)
	_assert_autumn_forest_canopy(entries_by_id)
	_assert_green_ruins_midground(entries_by_id)
	_assert_locked_autumn_tree_material(entries_by_id)
	_assert_repeated_ground_visible(entries_by_id)
	_assert_ground_overlays_hidden(entries_by_id)
	_assert_landmark_aspect_ratios(entries_by_id)
	_assert_reference_placements(entries_by_id)
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


func _assert_separated_background_layers(entries_by_id: Dictionary) -> void:
	_expect(
		not entries_by_id.has("background_sky"),
		"Town modular layout must not retain the baked sky-and-cloud plate."
	)
	var mountains := _require_entry(entries_by_id, "background_mountains")
	if mountains.is_empty():
		return
	_expect(
		String(mountains.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_mountains"]),
		"Separated Town sky must restore the authored transparent mountain layer."
	)
	_expect(bool(mountains.get("visible", false)), "Separated Town mountains must remain visible.")
	var distant_city := _require_entry(entries_by_id, "background_distant_city")
	if not distant_city.is_empty():
		_expect(
			not bool(distant_city.get("visible", true)),
			"Legacy distant-city layer must remain hidden."
		)


func _assert_locked_autumn_tree_material(entries_by_id: Dictionary) -> void:
	var ancient_tree := _require_entry(entries_by_id, "background_ancient_town_tree")
	if not ancient_tree.is_empty():
		_expect(
			String(ancient_tree.get("source", ""))
				== String(EXPECTED_SOURCE_BY_ID["background_ancient_town_tree"]),
			"The main autumn tree must use the isolated material from the locked A reference."
		)
		_expect(
			bool(ancient_tree.get("visible", false)),
			"The locked A main autumn tree must remain visible."
		)
	for entry_id_variant in entries_by_id:
		var entry_id := String(entry_id_variant)
		var entry := entries_by_id[entry_id] as Dictionary
		if not bool(entry.get("visible", false)):
			continue
		var source := String(entry.get("source", ""))
		_expect(
			source not in FORBIDDEN_VISIBLE_FOREST_SOURCES,
			"Green legacy/parallax forest material must never be visible: %s" % source
	)


func _assert_autumn_forest_canopy(entries_by_id: Dictionary) -> void:
	var forest := _require_entry(entries_by_id, "background_forest")
	if forest.is_empty():
		return
	_expect(
		String(forest.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_forest"]),
		"Town midground foliage must use the generated locked-A autumn canopy material."
	)
	_expect(
		bool(forest.get("visible", false)),
		"The autumn canopy layer must fill the empty roofline background."
	)


func _assert_green_ruins_midground(entries_by_id: Dictionary) -> void:
	var ruins := _require_entry(entries_by_id, "background_green_ruins")
	var debris := _require_entry(entries_by_id, "background_green_ruins_debris")
	var east_edge := _require_entry(entries_by_id, "background_green_ruins_east_edge")
	var west_edge := _require_entry(entries_by_id, "background_green_ruins_west_edge")
	var forest := _require_entry(entries_by_id, "background_forest")
	var ancient_tree := _require_entry(entries_by_id, "background_ancient_town_tree")
	if (
		ruins.is_empty()
		or debris.is_empty()
		or east_edge.is_empty()
		or west_edge.is_empty()
		or forest.is_empty()
		or ancient_tree.is_empty()
	):
		return
	_expect(
		String(ruins.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_green_ruins"]),
		"Town must use the coarse-pixel boundary tower material."
	)
	_expect(
		String(debris.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_green_ruins_debris"]),
		"Town must use the generated bush and randomized ruin-debris strip."
	)
	_expect(
		String(east_edge.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_green_ruins_east_edge"]),
		"Town must use the east-edge conifer and grounded ruin cluster."
	)
	_expect(
		String(west_edge.get("source", ""))
			== String(EXPECTED_SOURCE_BY_ID["background_green_ruins_west_edge"]),
		"Town must reuse the approved coarse-pixel ruin and shrub cluster at the west edge."
	)
	_expect(
		bool(ruins.get("visible", false))
			and bool(debris.get("visible", false))
			and bool(east_edge.get("visible", false))
			and bool(west_edge.get("visible", false)),
		"The boundary tower, debris strip, and both edge clusters must fill pale gaps."
	)
	_expect(
		int(debris.get("z_index", 0)) > int(forest.get("z_index", 0))
			and int(ruins.get("z_index", 0)) > int(debris.get("z_index", 0))
			and int(east_edge.get("z_index", 0)) > int(debris.get("z_index", 0)),
		"The debris, boundary tower, and east-edge cluster must render in front of the canopy."
	)
	_expect(
		int(west_edge.get("z_index", 0)) > int(ruins.get("z_index", 0)),
		"The west shrub and ruin cluster must cover the exposed edge of the boundary tower."
	)
	_expect(
		int(ruins.get("z_index", 0)) < int(ancient_tree.get("z_index", 0))
			and int(east_edge.get("z_index", 0)) < int(ancient_tree.get("z_index", 0)),
		"The green ruins and edge cluster must remain behind the main autumn tree."
	)
	var ownership := ruins.get("interaction_ownership", {}) as Dictionary
	var debris_ownership := debris.get("interaction_ownership", {}) as Dictionary
	var east_edge_ownership := east_edge.get("interaction_ownership", {}) as Dictionary
	var west_edge_ownership := west_edge.get("interaction_ownership", {}) as Dictionary
	_expect(
		String(ownership.get("mode", "")) == "none"
			and String(debris_ownership.get("mode", "")) == "none"
			and String(east_edge_ownership.get("mode", "")) == "none"
			and String(west_edge_ownership.get("mode", "")) == "none",
		"The boundary tower, debris strip, and edge clusters must remain visual-only."
	)


func _assert_repeated_ground_visible(entries_by_id: Dictionary) -> void:
	for entry_id_variant in entries_by_id:
		var entry_id := String(entry_id_variant)
		var is_repeated_ground := false
		for prefix in REPEATED_GROUND_PREFIXES:
			if entry_id.begins_with(prefix):
				is_repeated_ground = true
				break
		if not is_repeated_ground:
			continue
		var entry := entries_by_id[entry_id] as Dictionary
		_expect(
			bool(entry.get("visible", false)),
			"Selectable road and bridge modules must assemble the approved A ground: %s"
			% entry_id
		)


func _assert_ground_overlays_hidden(entries_by_id: Dictionary) -> void:
	for entry_id in GROUND_OVERLAY_IDS:
		var entry := _require_entry(entries_by_id, entry_id)
		if entry.is_empty():
			continue
		_expect(
			not bool(entry.get("visible", true)),
			"Ground dressing must not repaint the restored road surface: %s" % entry_id
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
			"%s must use its expected locked-reference source." % entry_id
		)
		_expect(
			bool(entry.get("visible", false)),
			"%s must remain visible in the Town composition." % entry_id
		)
		_assert_target_aspect(entry_id, entry, expected_source)


func _assert_reference_placements(entries_by_id: Dictionary) -> void:
	for entry_id in EXPECTED_PLACEMENT_BY_ID:
		var entry := _require_entry(entries_by_id, entry_id)
		if entry.is_empty():
			continue
		var expected := EXPECTED_PLACEMENT_BY_ID[entry_id] as Dictionary
		if EXPECTED_SOURCE_BY_ID.has(entry_id):
			_expect(
				String(entry.get("source", "")) == String(EXPECTED_SOURCE_BY_ID[entry_id]),
				"%s must use its approved composition source." % entry_id
			)
		var position := entry.get("position", []) as Array
		var target_size := entry.get("target_size", []) as Array
		if position.size() == 2:
			_expect(
				Vector2(float(position[0]), float(position[1]))
					== (expected["position"] as Vector2),
				"%s must match the locked A reference position." % entry_id
			)
		if target_size.size() == 2:
			_expect(
				Vector2(float(target_size[0]), float(target_size[1]))
					== (expected["target_size"] as Vector2),
				"%s must match the locked A reference size." % entry_id
			)
		if EXPECTED_SOURCE_REGION_BY_ID.has(entry_id):
			var actual_region := entry.get("source_region", []) as Array
			var expected_region := EXPECTED_SOURCE_REGION_BY_ID[entry_id] as Array
			_expect(
				actual_region.size() == 4
					and Rect2(
						float(actual_region[0]),
						float(actual_region[1]),
						float(actual_region[2]),
						float(actual_region[3])
					) == Rect2(
						float(expected_region[0]),
						float(expected_region[1]),
						float(expected_region[2]),
						float(expected_region[3])
					),
				"%s must crop one approved low street-edge module." % entry_id
			)
			_expect(
				int(entry.get("z_index", 0)) == -11
					and float(target_size[1]) <= 47.0,
				"%s must remain a thin transition behind building foundations." % entry_id
			)


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
