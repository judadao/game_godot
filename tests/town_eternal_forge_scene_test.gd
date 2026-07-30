extends SceneTree

const TOWN_PATH := "res://scenes/maps/town.tscn"
const CONCEPT_TEXTURE_PATH := (
	"res://concept/town/main_horizontal_concept/town_style_direction_a_locked.png"
)
const MODULAR_SCENE_PATH := "res://scenes/maps/town/components/TownModularVisuals.tscn"
const IDENTITY_SCENE_PATH := "res://scenes/maps/town/components/TownEternalForgeIdentity.tscn"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(TOWN_PATH) as PackedScene
	_expect(packed != null, "Eternal Forge Town scene must load.")
	if packed == null:
		quit(1)
		return

	var town := packed.instantiate()
	root.add_child(town)
	await process_frame

	_expect(int(town.get_meta("map_width")) == 1942, "Town must preserve the Eternal Forge world width.")
	_expect(int(town.get_meta("map_height")) == 720, "Town must preserve the 720px gameplay height.")
	_expect(
		int(town.get_meta("camera_limit_right")) == 1942,
		"Town camera must reach the Eternal Forge east edge."
	)

	var concept := town.get_node_or_null("ParallaxBackground/EternalForgeConcept") as Sprite2D
	_expect(concept != null, "Town must retain the locked Eternal Forge concept reference.")
	if concept != null:
		_expect(
			concept.texture != null and concept.texture.resource_path == CONCEPT_TEXTURE_PATH,
			"Town concept reference must preserve the approved source artwork."
		)
		_expect(
			not concept.is_visible_in_tree(),
			"Locked A Town concept must remain a hidden composition reference."
		)
		_expect(
			town.get_node_or_null("ParallaxBackground/EternalForgeConceptMid") == null
				and town.get_node_or_null("ParallaxBackground/EternalForgeConceptEast") == null,
			"Town must not repeat the flattened concept reference."
		)

	var modular := town.get_node_or_null("ParallaxBackground/ModularVisuals")
	_expect(modular != null, "Town must expose the linked modular visual scene.")
	if modular != null:
		_expect(
			modular.scene_file_path == MODULAR_SCENE_PATH,
			"Town modular visuals must remain a linked static scene."
		)
		_expect(
			modular.is_visible_in_tree(),
			"Approved Town Base modular visuals must be the runtime presentation."
		)
		var object_ids: Dictionary = {}
		var modular_sprites := modular.find_children("*", "Sprite2D", true, false)
		_expect(
			modular_sprites.size() == 72,
			"Town modular scene must expose all 72 independently replaceable instances."
		)
		for sprite_variant in modular_sprites:
			var sprite := sprite_variant as Sprite2D
			var object_id := String(sprite.get_meta("object_id", ""))
			_expect(not object_id.is_empty(), "Every Town modular sprite must expose an object ID.")
			_expect(not object_ids.has(object_id), "Town modular object IDs must be unique: %s" % object_id)
			object_ids[object_id] = true
			_expect(
				String(sprite.get_meta("source_asset", "")).begins_with(
					"res://assets/town/modular_v1/"
				)
				or String(sprite.get_meta("source_asset", "")).begins_with(
					"res://assets/town/modular_v2/"
				)
				or String(sprite.get_meta("source_asset", "")).begins_with(
					"res://assets/town/modular_v3/"
				),
				"Town modular sprites must use replaceable modular sources."
			)
		var sky := modular.get_node_or_null("Background/BackgroundSky") as Sprite2D
		_expect(sky != null, "Town modular scene must own its independent sky layer.")
		if sky != null:
			var sky_size := sky.texture.get_size() * sky.global_scale.abs()
			var coverage_left := sky.global_position.x - sky_size.x * 0.5
			var coverage_right := sky.global_position.x + sky_size.x * 0.5
			var coverage_top := sky.global_position.y - sky_size.y * 0.5
			var coverage_bottom := sky.global_position.y + sky_size.y * 0.5
			_expect(
				coverage_left <= 0.5 and coverage_right >= 1941.5,
				"Modular Town sky must cover the full world width."
			)
			_expect(
				coverage_top <= 0.5 and coverage_bottom >= 719.5,
				"Modular Town sky must cover the gameplay viewport height."
			)
	_expect(
		not town.get_node("ParallaxBackground/Sky").visible,
		"Legacy sky must not cover the locked A Eternal Forge background."
	)

	var identity := town.get_node_or_null("EternalForgeIdentity")
	_expect(identity != null, "Town must instance the Eternal Forge identity scene.")
	if identity != null:
		_expect(
			identity.scene_file_path == IDENTITY_SCENE_PATH,
			"Eternal Forge identity must remain an editable linked scene."
		)
		for location_name in [
			"MaterialYard",
			"PlayerBlacksmith",
			"EternalFlame",
			"BattlePortal",
			"TownHall",
			"SwordSoulShop",
			"EquipmentBlueprintShop",
			"FarEastResidence",
		]:
			_expect(
				identity.has_node("LocationLabels/%s" % location_name),
				"Town location label missing: %s." % location_name
			)
		for location_name in [
			"MaterialYard",
			"PlayerBlacksmith",
			"TownHall",
			"SwordSoulShop",
			"EquipmentBlueprintShop",
			"FarEastResidence",
		]:
			var building_label := identity.get_node("LocationLabels/%s" % location_name) as Label
			var plaque := building_label.get_theme_stylebox("normal") as StyleBoxTexture
			_expect(building_label.size.y <= 34.0, "%s label must use the compact Town plaque height." % location_name)
			_expect(building_label.size.x <= 200.0, "%s label must not dominate its building facade." % location_name)
			_expect(building_label.get_theme_font_size("font_size") <= 16, "%s label typography must stay compact." % location_name)
			_expect(
				building_label.visible == (location_name == "MaterialYard"),
				"%s label visibility must follow the default player foundation." % location_name
			)
			_expect(plaque != null, "%s label must use the B2 wooden plaque texture." % location_name)
			if plaque != null:
				_expect(
					plaque.texture != null
						and plaque.texture.resource_path
							== "res://assets/town/modular_v2/ui/building_label_plaque.png",
					"%s label must resolve the shared B2 plaque source." % location_name
				)

	var expected_building_order := [
		["WestHouse", &"material_yard"],
		["Blacksmith", &"player_blacksmith"],
		["EmptyResidence", &"town_hall"],
		["ItemShop", &"sword_soul_shop"],
		["EmptyTowerHouse", &"equipment_blueprint_shop"],
		["MarketStall", &"far_east_residence"],
	]
	var previous_x := -INF
	for contract in expected_building_order:
		var building := town.get_node_or_null("Buildings/%s" % contract[0]) as Node2D
		_expect(building != null, "Town building missing: %s." % contract[0])
		if building == null:
			continue
		_expect(
			StringName(building.get_meta("location_id", &"")) == contract[1],
			"%s must project the Eternal Forge location identity." % contract[0]
		)
		_expect(building.global_position.x > previous_x, "Town buildings must follow the Figma left-to-right order.")
		previous_x = building.global_position.x

	var floor_collision := town.get_node("WorldCollision/FloorCollision") as CollisionShape2D
	var floor_shape := floor_collision.shape as RectangleShape2D
	_expect(floor_shape.size.x >= 1942.0, "Town floor collision must cover the single-segment world width.")
	var floor_left := floor_collision.global_position.x - floor_shape.size.x * 0.5
	var floor_right := floor_collision.global_position.x + floor_shape.size.x * 0.5
	_expect(floor_left <= 0.0 and floor_right >= 1942.0, "Town floor collision must cover both map edges.")
	var floor_top := floor_collision.global_position.y - floor_shape.size.y * 0.5
	_expect(is_equal_approx(floor_top, 672.0), "Town collision surface must match the new artwork road baseline.")
	var right_wall := town.get_node("WorldCollision/RightWall") as CollisionShape2D
	_expect(right_wall.global_position.x >= 1942.0, "Town right wall must guard the east edge.")
	var battle_gateway := town.get_node("Portals/BattleGateway") as Node2D
	_expect(
		battle_gateway.global_position == Vector2(830, 672),
		"Town must expose one centered battle gateway on the road baseline."
	)
	_expect(
		String(battle_gateway.get("target_scene_path")) == "res://scenes/maps/battle_portal_hub.tscn",
		"Town battle gateway must enter the battle portal hub."
	)
	_expect(
		not (battle_gateway.get_node("TownVisual") as CanvasItem).is_visible_in_tree(),
		"Town must use the locked A battle portal without a duplicate runtime portal visual."
	)
	_expect(
		not (identity.get_node("LocationLabels/BattlePortal") as CanvasItem).visible,
		"Town must keep the battle-portal label hidden over the locked A artwork."
	)
	_expect(
		not (identity.get_node("LocationLabels/EternalFlame") as CanvasItem).visible,
		"Town must keep the flame label hidden over the locked A artwork."
	)
	var eternal_flame_label := identity.get_node("LocationLabels/EternalFlame") as Control
	var battle_portal_label := identity.get_node("LocationLabels/BattlePortal") as Control
	_expect(
		is_equal_approx(eternal_flame_label.position.x + eternal_flame_label.size.x * 0.5, 830.0),
		"Eternal Flame label anchor must remain centered on the locked concept landmark."
	)
	_expect(
		eternal_flame_label.position.y <= 250.0,
		"Eternal Flame label must use the upper tower gap instead of covering the monument title area."
	)
	_expect(
		is_equal_approx(battle_portal_label.position.x + battle_portal_label.size.x * 0.5, 830.0),
		"Battle Portal label anchor must remain centered on the locked concept landmark."
	)
	_expect(
		battle_portal_label.position.y <= 465.0,
		"Battle Portal label must sit above the gateway instead of covering its portal core."
	)
	for npc_name in [
		"Mayor", "VillagerMale", "EquipmentBlueprintMerchant", "Guard",
		"ItemMerchant", "Blacksmith", "Innkeeper",
	]:
		_expect(
			is_equal_approx((town.get_node("NPCs/%s" % npc_name) as Node2D).global_position.y, 672.0),
			"%s must stand on the artwork road baseline." % npc_name
		)
	for npc_name in ["VillagerMale", "EquipmentBlueprintMerchant"]:
		var npc_x := (town.get_node("NPCs/%s" % npc_name) as Node2D).global_position.x
		_expect(
			npc_x < 650.0 or npc_x > 950.0,
			"%s must not obstruct the large battle portal." % npc_name
		)

	town.queue_free()
	await process_frame

	var authoritative := (load("res://scenes/maps/town/TownMap.tscn") as PackedScene).instantiate()
	root.add_child(authoritative)
	await process_frame
	_expect(authoritative.has_node("EternalForgeIdentity"), "TownMap must expose the editable identity instance.")
	_expect(authoritative.has_node("EditorHUDReference/HUD"), "TownMap must preserve its dedicated HUD authority.")
	var authored_hud := authoritative.get_node_or_null("EditorHUDReference/HUD") as Control
	var authored_hand := authoritative.get_node_or_null("EditorHUDReference/CardHandUI") as Control
	_expect(
		authored_hud != null
			and authored_hud.scene_file_path == "res://scenes/ui/town/TownEternalForgeHUD.tscn",
		"TownMap must author the Eternal Forge HUD."
	)
	_expect(
		authored_hand != null
			and authored_hand.scene_file_path == "res://scenes/ui/town/TownCardHandUI.tscn",
		"TownMap must author the Eternal Forge card hand as its sibling authority."
	)
	if authored_hud != null:
		for removed_panel_path in ["LeftCrest", "RightCrest", "BottomHUD"]:
			var removed_panel := authored_hud.get_node_or_null(removed_panel_path) as Control
			_expect(
				removed_panel != null and not removed_panel.visible,
				"Town HUD must hide the unused %s panel." % removed_panel_path
			)
		var area_panel := authored_hud.get_node_or_null("AreaPanel") as Control
		var prompt_panel := authored_hud.get_node_or_null("InteractionPanel") as Control
		_expect(area_panel != null and area_panel.size.x <= 260.0, "Town area title must stay compact.")
		_expect(prompt_panel != null and prompt_panel.size.x <= 420.0, "Town interaction prompt must stay compact.")
	var map_bounds := authoritative.get_node("EditorHelpers/MapBounds") as Line2D
	_expect(
		map_bounds.points.size() >= 3
		and map_bounds.points[1] == Vector2(1942, 0)
		and map_bounds.points[2] == Vector2(1942, 720),
		"Town editor bounds must match the 1942x720 runtime world."
	)
	authoritative.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
