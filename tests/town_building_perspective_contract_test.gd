extends SceneTree

const LAYOUT_PATH := "res://data/town_modular_layout.json"
const STYLE_PATH := "res://data/town_visual_style.json"
const MODULAR_SCENE_PATH := "res://scenes/maps/town/components/TownModularVisuals.tscn"
const BUILDING_IDS := {
	"material_yard": true,
	"player_blacksmith": true,
	"town_hall": true,
	"sword_soul_shop": true,
	"equipment_blueprint_shop": true,
	"far_east_residence": true,
}
const BUILDING_NODE_NAMES := {
	"material_yard": "MaterialYard",
	"player_blacksmith": "PlayerBlacksmith",
	"town_hall": "TownHall",
	"sword_soul_shop": "SwordSoulShop",
	"equipment_blueprint_shop": "EquipmentBlueprintShop",
	"far_east_residence": "FarEastResidence",
}
const EXPECTED_BUILDING_SOURCE_BY_ID := {
	"material_yard": "res://assets/town/modular_v2/buildings/material_yard.png",
	"player_blacksmith": "res://assets/town/modular_v2/buildings/player_forge.png",
	"town_hall": "res://assets/town/modular_v2/buildings/town_hall_base_v2.png",
	"sword_soul_shop":
		"res://assets/town/modular_v2/buildings/sword_soul_shop_base_v2.png",
	"equipment_blueprint_shop":
		"res://assets/town/modular_v2/buildings/blueprint_research_base_v2.png",
	"far_east_residence":
		"res://assets/town/modular_v2/buildings/east_residence_base_v2.png",
}
const EXPECTED_PERSPECTIVE_PROFILE := "b2_front_right_orthographic"
const EXPECTED_BACKGROUND_PROFILE := "a_locked_autumn_panorama"
const EXPECTED_LANDMARK_PROFILE := "base_material_yard_landmarks_v3"
const EXPECTED_NEW_DRESSING_IDS := {
	"market_stall": true,
	"produce_baskets": true,
	"laundry_line": true,
	"tavern_table": true,
	"stacked_sacks": true,
	"tool_rack": true,
	"flower_planter": true,
	"water_trough": true,
	"woodpile": true,
	"street_signpost": true,
	"road_patch": true,
	"curb_grass": true,
	"shrub_cluster": true,
	"small_tree": true,
	"ivy_strip": true,
	"fallen_leaves": true,
	"flower_clump": true,
	"drain_grate": true,
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var style := _load_json_object(STYLE_PATH)
	var layout := _load_json_object(LAYOUT_PATH)
	if style.is_empty() or layout.is_empty():
		_finish()
		return

	var perspective := style.get("perspective", {}) as Dictionary
	_expect(
		String(layout.get("building_perspective_profile", ""))
			== EXPECTED_PERSPECTIVE_PROFILE,
		"Town modular layout must declare the approved B2 building perspective."
	)
	_expect(
		String(perspective.get("profile", "")) == EXPECTED_PERSPECTIVE_PROFILE,
		"Town B2 style must define the approved shared building perspective profile."
	)
	_expect(
		String(layout.get("background_style_profile", "")) == EXPECTED_BACKGROUND_PROFILE,
		"Town background must use the locked approved A panorama profile."
	)
	var variants := style.get("variants", {}) as Dictionary
	var background_tree_profile := String(
		layout.get("background_tree_material_profile", "")
	)
	_expect(
		not background_tree_profile.is_empty()
			and String(variants.get("background_trees", "")) == background_tree_profile,
		"Town layout and visual style must share one non-empty background material profile."
	)
	_expect(
		String(layout.get("landmark_style_profile", "")) == EXPECTED_LANDMARK_PROFILE,
		"Town flame and portal must use the locked A landmark profile."
	)
	_expect(
		String(perspective.get("projection", "")) == "orthographic_pseudo_three_quarter",
		"Town B2 buildings must use an orthographic pseudo-three-quarter projection."
	)
	_expect(
		String(perspective.get("visible_side", "")) == "right_narrow",
		"Town B2 buildings must expose only a narrow right side plane."
	)
	_expect(
		String(perspective.get("depth_recession", "")) == "upper_right",
		"Town B2 depth edges must consistently recede toward the upper right."
	)
	_expect(
		bool(perspective.get("verticals_remain_vertical", false)),
		"Town B2 building verticals must remain vertical."
	)
	_expect(
		bool(perspective.get("horizontal_foundation", false)),
		"Town B2 building foundations must remain horizontal."
	)

	var seen_buildings: Dictionary = {}
	var seen_dressing: Dictionary = {}
	for layer_variant in layout.get("layers", []) as Array:
		if not layer_variant is Dictionary:
			continue
		var layer := layer_variant as Dictionary
		var layer_id := String(layer.get("id", ""))
		if BUILDING_IDS.has(layer_id):
			seen_buildings[layer_id] = true
			_expect(
				String(layer.get("perspective_profile", ""))
					== EXPECTED_PERSPECTIVE_PROFILE,
				"%s must opt into the shared B2 perspective profile." % layer_id
			)
			_expect(
				String(layer.get("source", "")).begins_with(
					"res://assets/town/modular_v2/buildings/"
				),
				"%s must use a B2 modular building source." % layer_id
			)
			_expect(
				String(layer.get("source", ""))
					== String(EXPECTED_BUILDING_SOURCE_BY_ID[layer_id]),
				"%s must use its approved MaterialYard-style Base source." % layer_id
			)
			_assert_building_aspect_ratio(layer_id, layer)
		if EXPECTED_NEW_DRESSING_IDS.has(layer_id):
			seen_dressing[layer_id] = true
			var ownership := layer.get("interaction_ownership", {}) as Dictionary
			_expect(
				String(ownership.get("mode", "")) == "none",
				"%s must remain visual-only and own no interaction." % layer_id
			)
		if (
			String(layer.get("category", "")) == "street_prop"
			and bool(layer.get("visible", false))
		):
			_expect(
				String(layer.get("source", "")).begins_with(
					"res://assets/town/modular_v2/"
				),
				"Every visible Town street object must use the B object family: %s"
				% layer_id
			)
		if layer_id.begins_with("hanging_banner"):
			_expect(
				not bool(layer.get("visible", true)),
				"Floating Town banners must remain hidden: %s" % layer_id
			)

	_expect(seen_buildings == BUILDING_IDS, "Every Town service building must use the B2 perspective.")
	_expect(
		seen_dressing == EXPECTED_NEW_DRESSING_IDS,
		"Town layout must include every approved B2 streetscape dressing object."
	)
	_assert_generated_scene_perspective()
	_finish()


func _assert_building_aspect_ratio(layer_id: String, layer: Dictionary) -> void:
	var source_path := String(layer.get("source", ""))
	var texture := load(source_path) as Texture2D
	_expect(texture != null, "%s B2 source texture must load." % layer_id)
	if texture == null:
		return
	var target_size := layer.get("target_size", []) as Array
	_expect(target_size.size() == 2, "%s must define a two-axis target size." % layer_id)
	if target_size.size() != 2:
		return
	var source_aspect := float(texture.get_width()) / float(texture.get_height())
	var target_aspect := float(target_size[0]) / float(target_size[1])
	_expect(
		absf(source_aspect - target_aspect) <= 0.01,
		"%s must preserve the approved B2 source aspect ratio." % layer_id
	)
	var source_image := texture.get_image()
	_expect(source_image != null, "%s B2 source image must be readable." % layer_id)
	if source_image == null:
		return
	var used_rect := source_image.get_used_rect()
	var position := layer.get("position", []) as Array
	_expect(position.size() == 2, "%s must define a two-axis position." % layer_id)
	if position.size() != 2:
		return
	var visible_bottom := (
		float(position[1])
		- float(target_size[1]) * 0.5
		+ float(used_rect.end.y) * float(target_size[1]) / float(texture.get_height())
	)
	_expect(
		absf(visible_bottom - 672.0) <= 1.0,
		"%s visible foundation must align with the Town gameplay baseline." % layer_id
	)


func _load_json_object(path: String) -> Dictionary:
	_expect(FileAccess.file_exists(path), "Required Town contract must exist: %s" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "Town contract must be a JSON object: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _assert_generated_scene_perspective() -> void:
	var packed := load(MODULAR_SCENE_PATH) as PackedScene
	_expect(packed != null, "Generated Town modular scene must load.")
	if packed == null:
		return
	var instance := packed.instantiate()
	for building_id in BUILDING_IDS:
		var expected_node_name := String(BUILDING_NODE_NAMES[building_id])
		var sprite := instance.get_node_or_null("Facilities/%s" % expected_node_name) as Sprite2D
		_expect(sprite != null, "Generated Town building sprite must exist: %s" % building_id)
		if sprite != null:
			_expect(
				String(sprite.get_meta("perspective_profile", ""))
					== EXPECTED_PERSPECTIVE_PROFILE,
				"Generated Town building must retain B2 perspective metadata: %s"
				% building_id
			)
	instance.free()


func _finish() -> void:
	if _failures == 0:
		print("Town B2 building perspective contract passed.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
