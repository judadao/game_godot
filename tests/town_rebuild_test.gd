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
		"NPCs/ItemMerchantInteractive",
		"NPCs/BlacksmithInteractive",
		"NPCs/InnkeeperInteractive",
		"Portals/ForestPortal/TownVisual",
		"Portals/CavesPortal/TownVisual",
		"Portals/GraveyardPortal/TownVisual",
	]:
		_expect(town.has_node(node_path), "Town rebuild node missing: %s" % node_path)

	for portal_name in ["ForestPortal", "CavesPortal", "GraveyardPortal"]:
		var portal := town.get_node("Portals/%s" % portal_name) as CollisionObject2D
		_expect(portal.collision_layer == 0, "%s must not block the town road." % portal_name)

	for portal_name in ["EntranceFastTravelPortal", "EastRoadPortal"]:
		var portal := town.get_node("Portals/%s" % portal_name)
		_expect(
			not portal.get_node("Visual").is_visible_in_tree(),
			"%s must not render the retired default portal visual." % portal_name
		)

	for npc_name in [
		"Mayor",
		"VillagerMale",
		"VillagerFemale",
		"Guard",
		"ItemMerchantInteractive",
		"BlacksmithInteractive",
		"InnkeeperInteractive",
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
		"ItemMerchantInteractive": "res://scenes/npc/town/PotionMerchant.tscn",
		"BlacksmithInteractive": "res://scenes/npc/town/Blacksmith.tscn",
		"InnkeeperInteractive": "res://scenes/npc/town/Innkeeper.tscn",
	}
	var npc_regions: Array[Rect2] = []
	for npc_name in npc_scene_paths:
		var npc := town.get_node("NPCs/%s" % npc_name)
		_expect(
			npc.scene_file_path == npc_scene_paths[npc_name],
			"%s must remain linked to its dedicated NPC scene." % npc_name
		)
		_expect(npc.has_node("Visual"), "%s must own its visual inside the NPC scene." % npc_name)
		_expect(npc.has_node("InteractionArea/InteractionCollision"), "%s must own a complete interaction area." % npc_name)
		var visual := npc.get_node_or_null("Visual") as Sprite2D
		if visual != null and visual.texture is AtlasTexture:
			var region := (visual.texture as AtlasTexture).region
			_expect(not npc_regions.has(region), "%s must use a unique atlas region." % npc_name)
			npc_regions.append(region)

	_expect(
		town.get_node("ParallaxBackground/MidLayer/Background").texture.resource_path
		== "res://assets/town/rebuild_v2/town_background_clean_v3.png",
		"Town must use the clean distant-only background."
	)
	_expect(
		town.get_node("ParallaxBackground/MiddleNearLayer").texture.resource_path
		== "res://assets/town/rebuild_v2/town_mid_near_layer.png",
		"Town must use the generated middle-near scenery layer."
	)
	_expect(
		not town.has_node("ParallaxBackground/ParallaxBackground"),
		"Town must not nest a second TownBackdrop inside the linked backdrop scene."
	)
	_expect(
		not town.has_node("ParallaxBackground/MiddleNearLayer/MiddleNearLayer"),
		"Town backdrop must not nest a duplicate middle-near layer."
	)
	var continuous_ground := town.get_node("Ground/ContinuousStreet") as Sprite2D
	_expect(
		continuous_ground.texture.resource_path
		== "res://assets/town/rebuild_v2/town_ground_continuous.png",
		"Town ground must use one continuous texture."
	)
	_expect(town.get_node("Ground").get_child_count() == 1, "Town ground must not contain stitched segments.")
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
		"ParallaxBackground": "res://scenes/maps/components/TownBackdrop.tscn",
		"Ground": "res://scenes/maps/components/TownStreetGround.tscn",
		"Buildings": "res://scenes/maps/components/TownBuildings.tscn",
		"Props": "res://scenes/props/town/TownStreetProps.tscn",
		"Portals": "res://scenes/props/town/TownPortalSet.tscn",
		"NPCs": "res://scenes/maps/components/TownNPCs.tscn",
		"WorldCollision": "res://scenes/maps/components/TownWorldCollision.tscn",
	}
	for node_path in linked_scenes:
		var linked_node := town.get_node(node_path)
		_expect(
			linked_node.scene_file_path == linked_scenes[node_path],
			"%s must be a real linked child scene." % node_path
		)
	_expect(not town.has_node("PortalVisuals"), "Town must not keep a detached portal visual layer.")
	_expect(not town.has_node("Ground/RoadStones"), "Town must not keep retired hidden road nodes.")
	_expect(town.get_node("NPCs/Guard").position.y == 618.0, "Guard must stand on the town baseline.")

	town.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
