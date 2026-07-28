extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/maps/town.tscn") as PackedScene
	_expect(packed != null, "Town scene must load.")
	if packed == null:
		quit(1)
		return

	var town := packed.instantiate()
	root.add_child(town)
	await process_frame

	for asset_path in [
		"res://assets/town/rebuild_v2/town_background_clean_v3.png",
		"res://assets/town/rebuild_v2/town_street_atlas_v2.png",
		"res://assets/town/rebuild_v2/town_buildings_atlas_v2.png",
		"res://assets/town/rebuild_v2/town_props_portals_atlas_v2.png",
		"res://assets/town/rebuild_v2/town_npcs_atlas_v2.png",
	]:
		_expect(ResourceLoader.exists(asset_path), "Missing rebuilt town asset: %s" % asset_path)

	for node_path in [
		"Buildings/WestHouse",
		"Buildings/EmptyResidence",
		"Buildings/EmptyTowerHouse",
		"Buildings/ItemShop",
		"Buildings/MarketStall",
		"Buildings/Blacksmith",
		"NPCs/Mayor",
		"NPCs/ItemMerchant",
		"NPCs/Blacksmith",
		"NPCs/Innkeeper",
		"BuildingEntrances/MaterialYard",
		"BuildingEntrances/PlayerBlacksmith",
		"BuildingEntrances/TownHall",
		"BuildingEntrances/SwordSoulShop",
		"BuildingEntrances/EastResidence",
		"BuildingEntrances/FarEastResidence",
		"Portals/BattleGateway/TownVisual",
	]:
		_expect(town.has_node(node_path), "Town rebuild node missing: %s" % node_path)

	var configured_map_width := float(town.get_meta("map_width"))
	_expect(configured_map_width == 1942.0, "Town map must match its single Eternal Forge segment.")
	_expect(
		int(town.get_meta("camera_limit_right")) >= int(town.get_meta("map_width")),
		"Town camera must reach the configured map edge."
	)

	var battle_gateway := town.get_node("Portals/BattleGateway") as CollisionObject2D
	_expect(battle_gateway.collision_layer == 0, "BattleGateway must not block the town road.")

	for npc_name in [
		"Mayor",
		"VillagerMale",
		"VillagerFemale",
		"Guard",
		"ItemMerchant",
		"Blacksmith",
		"Innkeeper",
	]:
		var npc := town.get_node("NPCs/%s" % npc_name)
		var visual := npc if npc is Sprite2D else npc.get_node("Visual")
		var texture: Texture2D = (visual as Sprite2D).texture
		var atlas: Texture2D = texture.atlas if texture is AtlasTexture else texture
		_expect(
			atlas.resource_path == "res://assets/town/rebuild_v2/town_npcs_atlas_v2.png",
			"%s must use the rebuilt Town NPC atlas at runtime." % npc_name
		)

	var npc_scene_paths := {
		"Mayor": "res://scenes/npc/town/Mayor.tscn",
		"VillagerMale": "res://scenes/npc/town/MaleVillager.tscn",
		"VillagerFemale": "res://scenes/npc/town/FemaleVillager.tscn",
		"Guard": "res://scenes/npc/town/TownGuard.tscn",
		"ItemMerchant": "res://scenes/npc/town/PotionMerchant.tscn",
		"Blacksmith": "res://scenes/npc/town/Blacksmith.tscn",
		"Innkeeper": "res://scenes/npc/town/Innkeeper.tscn",
	}
	var npc_regions: Array[Rect2] = []
	for npc_name in npc_scene_paths:
		var npc := town.get_node("NPCs/%s" % npc_name)
		_expect(
			npc.scene_file_path == npc_scene_paths[npc_name],
			"%s must remain linked to its dedicated NPC scene." % npc_name
		)
		_expect(npc.has_node("Visual"), "%s must own its visual inside the NPC scene." % npc_name)
		_expect(not npc.is_in_group("Interactives"), "%s must not trigger Town building UI." % npc_name)
		_expect(not npc.has_node("InteractionArea"), "%s must not own an interaction area." % npc_name)
		var visual := npc.get_node_or_null("Visual") as Sprite2D
		if visual != null and visual.texture is AtlasTexture:
			var region := (visual.texture as AtlasTexture).region
			_expect(not npc_regions.has(region), "%s must use a unique atlas region." % npc_name)
			npc_regions.append(region)
	_assert_town_building_entrances(town)
	_expect(
		not town.has_node("BuildingEntrances/BlueprintResearch"),
		"The former Blueprint Research house must not own a functional entrance."
	)
	_expect(
		not town.has_node("BuildingEntrances/SoulRefinery"),
		"The former Soul Refinery house must not own a functional entrance."
	)

	_expect(
		not town.has_node("ParallaxBackground/ParallaxBackground"),
		"Town must not nest a second TownBackdrop inside the linked backdrop scene."
	)
	var background_modules := {
		"Sky": {
			"scene": "res://scenes/maps/town/legacy/background/TownSkyLayer.tscn",
			"minimum_sprites": 1,
		},
		"Clouds": {
			"scene": "res://scenes/maps/town/legacy/background/TownCloudSet.tscn",
			"minimum_sprites": 4,
		},
		"Mountains": {
			"scene": "res://scenes/maps/town/legacy/background/TownMountainSet.tscn",
			"minimum_sprites": 3,
		},
		"DistantBuildings": {
			"scene": "res://scenes/maps/town/legacy/background/TownDistantBuildings.tscn",
			"minimum_sprites": 4,
		},
		"Trees": {
			"scene": "res://scenes/maps/town/legacy/background/TownTreeSet.tscn",
			"minimum_sprites": 6,
		},
	}
	var backdrop := town.get_node("ParallaxBackground")
	var sky_sprite := backdrop.get_node("Sky/Sky") as Sprite2D
	var sky_half_width: float = (
		float(sky_sprite.texture.get_width())
		* absf(sky_sprite.global_scale.x)
		* 0.5
	)
	_expect(
		sky_sprite.global_position.x - sky_half_width <= 0.0
		and sky_sprite.global_position.x + sky_half_width >= configured_map_width,
		"Town sky must cover both edges after backdrop positioning."
	)
	for module_name in background_modules:
		var module := backdrop.get_node_or_null(module_name)
		_expect(module != null, "TownBackdrop must expose linked %s child scene." % module_name)
		if module == null:
			continue
		var contract: Dictionary = background_modules[module_name]
		_expect(
			module.scene_file_path == contract["scene"],
			"TownBackdrop/%s must link %s." % [module_name, contract["scene"]]
		)
		_expect(
			_count_sprites(module) >= contract["minimum_sprites"],
			"TownBackdrop/%s must contain at least %d Sprite2D nodes."
			% [module_name, contract["minimum_sprites"]]
		)
	var continuous_ground := town.get_node("Ground/ContinuousStreet") as Sprite2D
	_expect(
		continuous_ground.texture.resource_path
		== "res://assets/town/rebuild_v2/town_ground_continuous.png",
		"Town ground must use one continuous texture."
	)
	var ground_root := town.get_node("Ground") as Node2D
	var ground_width: float = continuous_ground.region_rect.size.x * absf(continuous_ground.scale.x)
	var ground_right: float = (
		ground_root.position.x
		+ continuous_ground.position.x
		+ ground_width * 0.5
	)
	_expect(ground_right >= configured_map_width, "Town continuous ground must reach the configured east edge.")

	var floor_collision := town.get_node("WorldCollision/FloorCollision") as CollisionShape2D
	var floor_shape := floor_collision.shape as RectangleShape2D
	var collision_root := town.get_node("WorldCollision") as Node2D
	var floor_right: float = (
		collision_root.position.x
		+ floor_collision.position.x
		+ floor_shape.size.x * 0.5
	)
	_expect(floor_right >= configured_map_width, "Town floor collision must reach the configured east edge.")
	var right_wall := town.get_node("WorldCollision/RightWall") as CollisionShape2D
	_expect(
		collision_root.position.x + right_wall.position.x >= configured_map_width,
		"Town right wall must be at or beyond the east boundary."
	)
	_expect(
		String(battle_gateway.get("target_scene_path")) == "res://scenes/maps/battle_portal_hub.tscn",
		"Town must route its sole battle gateway through the portal hub."
	)

	for asset_name in [
		"cloud_01.png", "cloud_02.png", "cloud_03.png", "cloud_04.png",
		"mountain_01.png", "mountain_02.png", "mountain_03.png",
		"distant_buildings_01.png", "distant_buildings_02.png",
		"distant_buildings_03.png", "distant_buildings_04.png",
		"tree_cluster_01.png", "tree_cluster_02.png", "tree_cluster_03.png",
		"tree_cluster_04.png", "tree_cluster_05.png", "tree_cluster_06.png",
	]:
		_expect(
			_has_transparent_corners(
				"res://assets/town/background_modules/%s" % asset_name
			),
			"%s must have transparent corners after chroma-key removal." % asset_name
		)
	for prop_name in [
		"EntranceFence",
		"ResidentialLamp",
		"NoticeBoard",
		"CivicWell",
		"CivicBench",
		"MarketCart",
		"SmithForge",
		"CratePile",
		"BarrelPile",
		"FlowerBed",
	]:
		var prop := town.get_node("Props/%s" % prop_name) as Sprite2D
		_expect(prop.position.y == 618.0, "%s must share the town ground baseline." % prop_name)
		_expect(prop.offset.y < 0.0, "%s must be bottom-aligned instead of center-aligned." % prop_name)
	var linked_scenes := {
		"ParallaxBackground": "res://scenes/maps/town/components/TownBackdrop.tscn",
		"Ground": "res://scenes/maps/town/legacy/props/TownStreetGround.tscn",
		"Buildings": "res://scenes/maps/town/legacy/buildings/TownBuildings.tscn",
		"Props": "res://scenes/maps/town/legacy/props/TownStreetProps.tscn",
		"Portals": "res://scenes/maps/town/portals/TownPortalSet.tscn",
		"NPCs": "res://scenes/maps/town/components/TownNPCs.tscn",
		"BuildingEntrances": "res://scenes/maps/town/components/TownBuildingEntrances.tscn",
		"WorldCollision": "res://scenes/maps/town/components/TownWorldCollision.tscn",
	}
	for node_path in linked_scenes:
		var linked_node := town.get_node(node_path)
		_expect(
			linked_node.scene_file_path == linked_scenes[node_path],
			"%s must be a real linked child scene." % node_path
		)
	_expect(not town.has_node("PortalVisuals"), "Town must not keep a detached portal visual layer.")
	_expect(not town.has_node("Ground/RoadStones"), "Town must not keep retired hidden road nodes.")
	_expect(town.get_node("NPCs/Guard").position.y == 672.0, "Guard must stand on the Eternal Forge road baseline.")

	town.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _assert_town_building_entrances(town: Node) -> void:
	var expected_anchors := {
		"BuildingEntrances/MaterialYard": {
			"building_id": &"material_yard",
			"ui_route": &"town_progress",
			"position": Vector2(170, 614),
			"size": Vector2(280, 116),
		},
		"BuildingEntrances/PlayerBlacksmith": {
			"building_id": &"player_blacksmith",
			"ui_route": &"town_progress",
			"position": Vector2(475, 614),
			"size": Vector2(350, 116),
		},
		"BuildingEntrances/TownHall": {
			"building_id": &"town_hall",
			"ui_route": &"town_progress",
			"position": Vector2(1120, 614),
			"size": Vector2(260, 116),
		},
		"BuildingEntrances/SwordSoulShop": {
			"building_id": &"sword_soul_shop",
			"ui_route": &"shop",
			"position": Vector2(1370, 614),
			"size": Vector2(240, 116),
		},
		"BuildingEntrances/EastResidence": {
			"building_id": &"east_residence",
			"ui_route": &"residence",
			"position": Vector2(1595, 614),
			"size": Vector2(210, 116),
		},
		"BuildingEntrances/FarEastResidence": {
			"building_id": &"far_east_residence",
			"ui_route": &"residence",
			"position": Vector2(1817, 614),
			"size": Vector2(234, 116),
		},
	}
	for entrance_path in expected_anchors:
		var entrance := town.get_node(entrance_path) as Node2D
		var contract: Dictionary = expected_anchors[entrance_path]
		_expect(
			entrance.is_in_group("Interactives"),
			"%s must be wired as an independent interactive." % entrance_path
		)
		_expect(
			String(entrance.get("building_id")) == String(contract["building_id"]),
			"%s must own its building ID." % entrance_path
		)
		_expect(
			String(entrance.get("ui_route")) == String(contract["ui_route"]),
			"%s must own its UI route." % entrance_path
		)
		var collision := entrance.get_node("InteractionArea/InteractionCollision") as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		_expect(
			shape != null and shape.size == contract["size"],
			"%s must cover the complete building foundation." % entrance_path
		)
		_expect(
			collision.global_position.is_equal_approx(contract["position"]),
			"%s trigger must sit at its building doorway %s."
			% [entrance_path, contract["position"]]
		)


func _has_transparent_corners(texture_path: String) -> bool:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.get_width() < 2 or image.get_height() < 2:
		return false
	var right := image.get_width() - 1
	var bottom := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a == 0.0
		and image.get_pixel(right, 0).a == 0.0
		and image.get_pixel(0, bottom).a == 0.0
		and image.get_pixel(right, bottom).a == 0.0
	)


func _count_sprites(node: Node) -> int:
	var count := 1 if node is Sprite2D else 0
	for child in node.get_children():
		count += _count_sprites(child)
	return count
