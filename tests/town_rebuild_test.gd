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
		"res://assets/town/rebuild_v2/town_background_v2.png",
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
		"PortalVisuals/Forest",
		"PortalVisuals/Caves",
		"PortalVisuals/Graveyard",
	]:
		_expect(town.has_node(node_path), "Town rebuild node missing: %s" % node_path)

	for portal_name in ["ForestPortal", "CavesPortal", "GraveyardPortal"]:
		var portal := town.get_node("Portals/%s" % portal_name) as CollisionObject2D
		_expect(portal.collision_layer == 0, "%s must not block the town road." % portal_name)

	var chest := town.get_node("Props/TownChest") as CollisionObject2D
	_expect(not chest.visible and chest.collision_layer == 0, "Retired chest must be hidden and non-blocking.")
	_expect(not town.get_node("ParallaxBackground/Mountains").visible, "Legacy mountain strip must stay hidden.")
	_expect(not town.get_node("ParallaxBackground/Forest").visible, "Legacy forest strip must stay hidden.")
	_expect(not town.get_node("ParallaxBackground/Rooftops").visible, "Legacy rooftop strip must stay hidden.")

	town.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
