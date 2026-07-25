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
]
const EXPECTED_PROPS: Array[StringName] = [
	&"EntranceFence",
	&"ResidentialLamp",
	&"NoticeBoard",
	&"CivicWell",
	&"CivicBench",
	&"MarketCart",
	&"SmithForge",
	&"CratePile",
	&"BarrelPile",
	&"FlowerBed",
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
		failed = _expect_linked_container(
			town,
			scene_path,
			"Buildings",
			"res://scenes/maps/components/TownBuildings.tscn",
			EXPECTED_BUILDINGS
		) or failed
		failed = _expect_linked_container(
			town,
			scene_path,
			"Props",
			"res://scenes/props/town/TownStreetProps.tscn",
			EXPECTED_PROPS
		) or failed
		failed = _expect_linked_container(
			town,
			scene_path,
			"NPCs",
			"res://scenes/maps/components/TownNPCs.tscn",
			EXPECTED_VISUAL_NPCS
		) or failed
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


func _expect_linked_container(
	town: Node,
	scene_path: String,
	container_name: String,
	expected_scene_path: String,
	expected_names: Array[StringName]
) -> bool:
	var container := town.get_node_or_null(container_name)
	if container == null:
		push_error("%s: %s container is missing." % [scene_path, container_name])
		return true
	var failed := false
	if container.scene_file_path != expected_scene_path:
		push_error("%s: %s is not linked to %s." % [scene_path, container_name, expected_scene_path])
		failed = true
	for expected_name in expected_names:
		if container.get_node_or_null(String(expected_name)) == null:
			push_error("%s: %s/%s is missing." % [scene_path, container_name, String(expected_name)])
			failed = true
	return failed
