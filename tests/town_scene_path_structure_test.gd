extends SceneTree

const ACTIVE_SCENES := [
	"res://scenes/maps/town/components/TownBackdrop.tscn",
	"res://scenes/maps/town/components/TownModularVisuals.tscn",
	"res://scenes/maps/town/components/TownEternalForgeIdentity.tscn",
	"res://scenes/maps/town/components/TownNPCs.tscn",
	"res://scenes/maps/town/components/TownBuildingEntrances.tscn",
	"res://scenes/maps/town/components/TownWorldCollision.tscn",
	"res://scenes/maps/town/portals/TownPortalSet.tscn",
	"res://scenes/maps/town/portals/TownBattleGateway.tscn",
	"res://scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn",
]
const LEGACY_SCENES := [
	"res://scenes/maps/town/legacy/background/TownSkyLayer.tscn",
	"res://scenes/maps/town/legacy/background/TownCloudSet.tscn",
	"res://scenes/maps/town/legacy/background/TownMountainSet.tscn",
	"res://scenes/maps/town/legacy/background/TownDistantBuildings.tscn",
	"res://scenes/maps/town/legacy/background/TownTreeSet.tscn",
	"res://scenes/maps/town/legacy/buildings/TownBuildings.tscn",
	"res://scenes/maps/town/legacy/buildings/GeneratedBlueResidence.tscn",
	"res://scenes/maps/town/legacy/buildings/GeneratedBlueShop.tscn",
	"res://scenes/maps/town/legacy/buildings/GeneratedBlueTower.tscn",
	"res://scenes/maps/town/legacy/buildings/GeneratedRedResidence.tscn",
	"res://scenes/maps/town/legacy/buildings/GeneratedRedShop.tscn",
	"res://scenes/maps/town/legacy/buildings/GeneratedRedTower.tscn",
	"res://scenes/maps/town/legacy/props/TownStreetGround.tscn",
	"res://scenes/maps/town/legacy/props/TownStreetProps.tscn",
]
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in ACTIVE_SCENES + LEGACY_SCENES:
		_expect(ResourceLoader.exists(scene_path), "Town scene must use its classified path: %s" % scene_path)
		if ResourceLoader.exists(scene_path):
			_expect(load(scene_path) is PackedScene, "Town scene must load: %s" % scene_path)

	for old_path in [
		"res://scenes/maps/components/TownBackdrop.tscn",
		"res://scenes/maps/components/TownBuildings.tscn",
		"res://scenes/maps/components/TownEternalForgeIdentity.tscn",
		"res://scenes/maps/components/TownNPCs.tscn",
		"res://scenes/maps/components/TownStreetGround.tscn",
		"res://scenes/maps/components/TownWorldCollision.tscn",
		"res://scenes/props/town/TownPortalSet.tscn",
		"res://scenes/dev/TownEternalForgeEditorHUDReference.tscn",
	]:
		_expect(not ResourceLoader.exists(old_path), "Retired Town scene path must be absent: %s" % old_path)

	var town := (load("res://scenes/maps/town.tscn") as PackedScene).instantiate()
	var expected_links := {
		"ParallaxBackground": "res://scenes/maps/town/components/TownBackdrop.tscn",
		"Buildings": "res://scenes/maps/town/legacy/buildings/TownBuildings.tscn",
		"Ground": "res://scenes/maps/town/legacy/props/TownStreetGround.tscn",
		"Props": "res://scenes/maps/town/legacy/props/TownStreetProps.tscn",
		"Portals": "res://scenes/maps/town/portals/TownPortalSet.tscn",
		"NPCs": "res://scenes/maps/town/components/TownNPCs.tscn",
		"BuildingEntrances": "res://scenes/maps/town/components/TownBuildingEntrances.tscn",
		"WorldCollision": "res://scenes/maps/town/components/TownWorldCollision.tscn",
		"EternalForgeIdentity": "res://scenes/maps/town/components/TownEternalForgeIdentity.tscn",
	}
	for node_path in expected_links:
		var linked := town.get_node_or_null(node_path)
		_expect(linked != null, "Town linked node must exist: %s" % node_path)
		if linked != null:
			_expect(
				linked.scene_file_path == expected_links[node_path],
				"Town linked node must use classified scene path: %s" % node_path
			)
	var modular := town.get_node_or_null("ParallaxBackground/ModularVisuals")
	_expect(modular != null, "Town backdrop must expose the modular visual scene.")
	if modular != null:
		_expect(
			modular.scene_file_path
				== "res://scenes/maps/town/components/TownModularVisuals.tscn",
			"Town modular visuals must remain a linked active scene."
		)
	town.free()
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
