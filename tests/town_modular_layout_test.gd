extends SceneTree

const LAYOUT_PATH := "res://data/town_modular_layout.json"
const SOURCE_PREFIX := "res://assets/town/modular_v1/"
const EXPECTED_MAP_SIZE := Vector2i(1942, 809)
const EXPECTED_FACILITY_IDS := {
	"material_yard": true,
	"player_blacksmith": true,
	"eternal_flame": true,
	"battle_portal": true,
	"town_hall": true,
	"sword_soul_shop": true,
	"equipment_blueprint_shop": true,
	"far_east_residence": true,
}
const EXPECTED_SOURCES := {
	"res://assets/town/modular_v1/background/ancient_town_tree.png": true,
	"res://assets/town/modular_v1/buildings/material_yard.png": true,
	"res://assets/town/modular_v1/buildings/player_forge.png": true,
	"res://assets/town/modular_v1/landmarks/eternal_forge_monument.png": true,
	"res://assets/town/modular_v1/landmarks/battle_portal.png": true,
	"res://assets/town/modular_v1/buildings/town_hall.png": true,
	"res://assets/town/modular_v1/buildings/sword_soul_shop.png": true,
	"res://assets/town/modular_v1/buildings/blueprint_research.png": true,
	"res://assets/town/modular_v1/buildings/east_residence.png": true,
	"res://assets/town/modular_v1/background/sky.png": true,
	"res://assets/town/modular_v1/background/mountain_layer.png": true,
	"res://assets/town/modular_v1/background/castle_layer.png": true,
	"res://assets/town/modular_v1/background/forest_layer.png": true,
	"res://assets/town/modular_v1/ground/stone_road_tile.png": true,
	"res://assets/town/modular_v1/ground/bridge_wall_tile.png": true,
	"res://assets/town/modular_v1/props/street_lantern.png": true,
	"res://assets/town/modular_v1/props/forge_brazier.png": true,
	"res://assets/town/modular_v1/props/soul_brazier.png": true,
	"res://assets/town/modular_v1/props/hanging_banner.png": true,
	"res://assets/town/modular_v1/props/west_fence.png": true,
	"res://assets/town/modular_v1/props/notice_board.png": true,
	"res://assets/town/modular_v1/props/material_crates.png": true,
	"res://assets/town/modular_v1/props/material_barrels.png": true,
	"res://assets/town/modular_v1/props/forge_anvil.png": true,
	"res://assets/town/modular_v1/props/forge_cart.png": true,
	"res://assets/town/modular_v1/props/civic_well.png": true,
	"res://assets/town/modular_v1/props/civic_bench.png": true,
	"res://assets/town/modular_v1/props/east_flower_bed.png": true,
}
const VALID_CATEGORIES := {
	"background": true,
	"ground": true,
	"facility": true,
	"landmark": true,
	"street_prop": true,
}
const BUILDING_INTERACTION_OWNERS := {
	"material_yard": {
		"node_path": "MaterialYard",
		"interaction_id": "material_yard_entrance",
		"service_id": "material_yard",
	},
	"player_blacksmith": {
		"node_path": "PlayerBlacksmith",
		"interaction_id": "player_blacksmith_entrance",
		"service_id": "player_blacksmith",
	},
	"town_hall": {
		"node_path": "TownHall",
		"interaction_id": "town_hall_entrance",
		"service_id": "town_hall",
	},
	"sword_soul_shop": {
		"node_path": "SwordSoulShop",
		"interaction_id": "sword_soul_shop_entrance",
		"service_id": "sword_soul_shop",
	},
	"equipment_blueprint_shop": {
		"node_path": "EquipmentBlueprintShop",
		"interaction_id": "equipment_blueprint_shop_entrance",
		"service_id": "equipment_blueprint_shop",
	},
	"far_east_residence": {
		"node_path": "FarEastResidence",
		"interaction_id": "far_east_residence_entrance",
		"service_id": "far_east_residence",
	},
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists(LAYOUT_PATH), "Town modular layout data must exist.")
	if not FileAccess.file_exists(LAYOUT_PATH):
		_finish()
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_expect(parsed is Dictionary, "Town modular layout root must be a JSON object.")
	if not parsed is Dictionary:
		_finish()
		return

	var layout := parsed as Dictionary
	_expect(int(layout.get("schema_version", 0)) == 1, "Town modular layout schema must be version 1.")
	var map_data := layout.get("map", {}) as Dictionary
	_expect(
		Vector2i(int(map_data.get("width", 0)), int(map_data.get("height", 0)))
			== EXPECTED_MAP_SIZE,
		"Town modular layout must preserve the 1942x809 source canvas."
	)
	_expect(
		int(map_data.get("gameplay_baseline_y", -1)) == 672,
		"Town modular layout must preserve the existing y=672 gameplay baseline."
	)

	var layers_variant: Variant = layout.get("layers", [])
	_expect(layers_variant is Array, "Town modular layout layers must be an array.")
	if not layers_variant is Array:
		_finish()
		return
	var layers := layers_variant as Array
	_expect(layers.size() == 54, "Town modular layout must expose exactly 54 assembled objects.")

	var ids: Dictionary = {}
	var sources: Dictionary = {}
	var category_counts: Dictionary = {}
	var facility_ids: Dictionary = {}
	var entries_by_id: Dictionary = {}
	for entry_variant in layers:
		_expect(entry_variant is Dictionary, "Every Town modular layer must be a JSON object.")
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		_assert_layer_entry(entry, ids)
		var entry_id := String(entry.get("id", ""))
		var category := String(entry.get("category", ""))
		var source := String(entry.get("source", ""))
		entries_by_id[entry_id] = entry
		sources[source] = true
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		if category == "facility" or category == "landmark":
			facility_ids[entry_id] = true

	_expect(facility_ids == EXPECTED_FACILITY_IDS, "Town must expose exactly eight facility/landmark objects.")
	for category in VALID_CATEGORIES:
		_expect(
			int(category_counts.get(category, 0)) > 0,
			"Town modular layout must include the %s category." % category
		)
	for source in EXPECTED_SOURCES:
		_expect(sources.has(source), "Town modular layout must use generated source: %s" % source)
	for source in sources:
		_expect(
			EXPECTED_SOURCES.has(source),
			"Town modular layout must not reference an unassigned generated source: %s" % source
		)

	_assert_interaction_owners(entries_by_id)
	_assert_repeated_ground_modules(layers)
	_finish()


func _assert_layer_entry(entry: Dictionary, ids: Dictionary) -> void:
	for required_field in [
		"id",
		"category",
		"source",
		"position",
		"z_index",
		"visible",
		"interaction_ownership",
	]:
		_expect(entry.has(required_field), "Town modular layer must define %s." % required_field)
	var entry_id := String(entry.get("id", ""))
	_expect(not entry_id.is_empty(), "Town modular layer ID must not be empty.")
	_expect(not ids.has(entry_id), "Town modular layer ID must be unique: %s" % entry_id)
	ids[entry_id] = true
	var category := String(entry.get("category", ""))
	_expect(VALID_CATEGORIES.has(category), "Town modular layer category must be supported: %s" % category)
	var source := String(entry.get("source", ""))
	_expect(
		source.begins_with(SOURCE_PREFIX) and source.ends_with(".png"),
		"Town modular source must use the modular_v1 PNG namespace: %s" % source
	)
	_assert_numeric_pair(entry.get("position"), "position", entry_id, false)
	var has_target_size := entry.has("target_size")
	var has_scale := entry.has("scale")
	_expect(
		has_target_size != has_scale,
		"Town modular layer must define exactly one of target_size or scale: %s" % entry_id
	)
	if has_target_size:
		_assert_numeric_pair(entry.get("target_size"), "target_size", entry_id, true)
	if has_scale:
		_assert_numeric_pair(entry.get("scale"), "scale", entry_id, true)
	_expect(entry.get("z_index") is float, "Town modular layer z_index must be numeric: %s" % entry_id)
	_expect(entry.get("visible") is bool, "Town modular layer visible must be boolean: %s" % entry_id)
	_expect(
		entry.get("interaction_ownership") is Dictionary,
		"Town modular layer interaction ownership must be structured: %s" % entry_id
	)


func _assert_numeric_pair(value: Variant, field: String, entry_id: String, positive: bool) -> void:
	_expect(value is Array, "Town modular layer %s must be an array: %s" % [field, entry_id])
	if not value is Array:
		return
	var pair := value as Array
	_expect(pair.size() == 2, "Town modular layer %s must contain two values: %s" % [field, entry_id])
	if pair.size() != 2:
		return
	for number in pair:
		_expect(number is float, "Town modular layer %s values must be numeric: %s" % [field, entry_id])
		if positive and number is float:
			_expect(float(number) > 0.0, "Town modular layer %s values must be positive: %s" % [field, entry_id])


func _assert_interaction_owners(entries_by_id: Dictionary) -> void:
	const BUILDING_OWNER_SCENE := "res://scenes/maps/town/components/TownBuildingEntrances.tscn"
	for facility_id in BUILDING_INTERACTION_OWNERS:
		var entry := entries_by_id.get(facility_id, {}) as Dictionary
		var ownership := entry.get("interaction_ownership", {}) as Dictionary
		var expected := BUILDING_INTERACTION_OWNERS[facility_id] as Dictionary
		_expect(
			String(ownership.get("mode", "")) == "scene_owned",
			"%s interaction must remain scene-owned." % facility_id
		)
		_expect(
			String(ownership.get("owner_scene", "")) == BUILDING_OWNER_SCENE,
			"%s interaction owner scene must remain TownBuildingEntrances." % facility_id
		)
		for field in ["node_path", "interaction_id", "service_id"]:
			_expect(
				String(ownership.get(field, "")) == String(expected.get(field, "")),
				"%s interaction %s must match the gameplay authority." % [facility_id, field]
			)

	var portal := entries_by_id.get("battle_portal", {}) as Dictionary
	var portal_ownership := portal.get("interaction_ownership", {}) as Dictionary
	_expect(
		String(portal_ownership.get("owner_scene", ""))
			== "res://scenes/maps/town/portals/TownPortalSet.tscn",
		"Battle portal interaction must remain owned by TownPortalSet."
	)
	_expect(
		String(portal_ownership.get("node_path", "")) == "BattleGateway",
		"Battle portal interaction must resolve to BattleGateway."
	)
	_expect(
		String(portal_ownership.get("interaction_id", "")) == "town_battle_gateway",
		"Battle portal interaction ID must remain stable."
	)

	var flame := entries_by_id.get("eternal_flame", {}) as Dictionary
	var flame_ownership := flame.get("interaction_ownership", {}) as Dictionary
	_expect(
		String(flame_ownership.get("mode", "")) == "none",
		"Eternal Flame visual must not duplicate an interaction authority."
	)


func _assert_repeated_ground_modules(layers: Array) -> void:
	var road_ids: Dictionary = {}
	var bridge_ids: Dictionary = {}
	for entry_variant in layers:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var source := String(entry.get("source", ""))
		if source.ends_with("/ground/stone_road_tile.png"):
			road_ids[String(entry.get("id", ""))] = true
		elif source.ends_with("/ground/bridge_wall_tile.png"):
			bridge_ids[String(entry.get("id", ""))] = true
	_expect(road_ids.size() >= 8, "Town road must be assembled from at least eight selectable modules.")
	_expect(bridge_ids.size() >= 8, "Town bridge wall must be assembled from at least eight selectable modules.")


func _finish() -> void:
	if _failures == 0:
		print("Town modular layout contract passed.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
