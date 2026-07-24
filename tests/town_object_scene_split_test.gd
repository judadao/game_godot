extends SceneTree

const TOWN_SCENES: Array[String] = [
	"res://scenes/maps/town.tscn",
]
const EXPECTED_BUILDINGS: Array[StringName] = [
	&"WestHouse",
	&"ItemShop",
	&"Blacksmith",
	&"MarketStall",
	&"EmptyResidence",
	&"EmptyTowerHouse",
	&"TownPortal",
	&"TownWell",
	&"NoticeBoard",
]
const EXPECTED_PROPS: Array[StringName] = [
	&"WestFence",
	&"LampWest",
	&"LampCenter",
	&"CrossroadSign",
	&"Bench",
	&"BarrelStack",
	&"Crates",
	&"MarketCart",
	&"EastTree",
	&"FlowerBedWest",
	&"FlowerBedEast",
]
const EXPECTED_VISUAL_NPCS: Array[StringName] = [
	&"Mayor",
	&"VillagerMale",
	&"VillagerFemale",
	&"Guard",
]

func _init() -> void:
	var failed := false
	for scene_path in TOWN_SCENES:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("%s failed to load." % scene_path)
			failed = true
			continue

		var town := packed.instantiate()
		failed = _expect_container(town, scene_path, "Buildings", EXPECTED_BUILDINGS) or failed
		failed = _expect_container(town, scene_path, "Props", EXPECTED_PROPS) or failed
		failed = _expect_container(town, scene_path, "NPCs", EXPECTED_VISUAL_NPCS) or failed
		town.free()
	quit(1 if failed else 0)

func _expect_container(town: Node, scene_path: String, container_name: String, expected_names: Array[StringName]) -> bool:
	var failed := false
	var container := town.get_node_or_null(container_name)
	if container == null:
		push_error("%s: %s container is missing." % [scene_path, container_name])
		return true

	for expected_name in expected_names:
		var child := container.get_node_or_null(String(expected_name))
		if child == null:
			push_error("%s: %s/%s is missing." % [scene_path, container_name, String(expected_name)])
			failed = true
			continue
		if child.scene_file_path.is_empty():
			push_error("%s: %s/%s is inline; expected a scene instance." % [scene_path, container_name, String(expected_name)])
			failed = true

	return failed
