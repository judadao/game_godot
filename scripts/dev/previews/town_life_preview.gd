extends Node

const CAPTURE_PATH_ENV := "TOWN_LIFE_CAPTURE_PATH"
const CAPTURE_TIME_ENV := "TOWN_LIFE_CAPTURE_TIME"
const SLICE_DIRECTORY_ENV := "TOWN_LIFE_SLICE_DIR"

@onready var life_viewport: SubViewport = $TownViewport
@onready var life_camera: Camera2D = $TownViewport/LifeCamera


func _ready() -> void:
	var player_camera := get_node_or_null("TownViewport/Town/Player/Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false
	life_camera.enabled = true
	life_camera.make_current()
	if OS.has_environment(CAPTURE_PATH_ENV):
		call_deferred("_capture_living_town")


func _capture_living_town() -> void:
	var simulation := prepare_deterministic_capture()
	var target_time := maxf(0.0, float(OS.get_environment(CAPTURE_TIME_ENV)))
	advance_deterministic_capture(simulation, target_time)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var image := life_viewport.get_texture().get_image()
	var capture_path := OS.get_environment(CAPTURE_PATH_ENV).strip_edges()
	var error := image.save_png(capture_path)
	if error == OK:
		_save_equal_slices(image, int(round(target_time)))
	else:
		push_error("Failed to save Town life preview to %s." % capture_path)
	get_tree().quit(0 if error == OK else 1)


func prepare_deterministic_capture() -> Dictionary:
	var actors := _sorted_group_nodes(&"town_life_npcs")
	var visitors := _sorted_group_nodes(&"town_visitors")
	var reserved_residents: Array[Node] = []
	for visitor in visitors:
		var preferred_name := StringName(visitor.get("preferred_resident_name"))
		if preferred_name.is_empty() or visitor.get_parent() == null:
			continue
		var resident := visitor.get_parent().get_node_or_null(NodePath(String(preferred_name)))
		if resident != null and not reserved_residents.has(resident):
			reserved_residents.append(resident)
	reserved_residents.sort_custom(_sort_nodes_by_path)
	var advancing_actors: Array[Node] = []
	for actor in actors:
		actor.set_process(false)
		if not reserved_residents.has(actor):
			actor.set("social_chance", 0.0)
			advancing_actors.append(actor)
	for visitor in visitors:
		visitor.set_process(false)
	var priest := get_node_or_null("TownViewport/Town/NPCs/Mayor")
	if priest != null:
		priest.set_process(false)
	return {
		"actors": advancing_actors,
		"reserved_residents": reserved_residents,
		"visitors": visitors,
		"priest": priest,
		"elapsed": 0.0,
	}


func advance_deterministic_capture(simulation: Dictionary, target_time: float) -> void:
	var actors := simulation.get("actors", []) as Array
	var visitors := simulation.get("visitors", []) as Array
	var priest := simulation.get("priest") as Node
	var elapsed := float(simulation.get("elapsed", 0.0))
	var clamped_target := maxf(target_time, elapsed)
	while elapsed < clamped_target:
		var step := minf(0.05, clamped_target - elapsed)
		for actor in actors:
			actor.call("advance_life", step)
		for visitor in visitors:
			visitor.call("advance_visitor", step)
		if priest != null:
			priest.call("advance_behavior", step)
		elapsed += step
	simulation["elapsed"] = elapsed


func get_visitor_capture_snapshot(simulation: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for visitor in simulation.get("visitors", []) as Array:
		var partner := visitor.call("get_social_partner") as Node
		result.append({
			"name": String(visitor.name),
			"state": visitor.call("get_visitor_state"),
			"position": visitor.position,
			"completed_passes": int(visitor.call("get_completed_passes")),
			"completed_greetings": int(visitor.call("get_completed_greetings")),
			"partner": String(partner.name) if partner != null else "",
		})
	return result


func _sorted_group_nodes(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if is_ancestor_of(node):
			result.append(node)
	result.sort_custom(_sort_nodes_by_path)
	return result


func _sort_nodes_by_path(left: Node, right: Node) -> bool:
	return String(left.get_path()) < String(right.get_path())


func _save_equal_slices(image: Image, sample_second: int) -> void:
	var directory := OS.get_environment(SLICE_DIRECTORY_ENV).strip_edges()
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var slice_size := Vector2i(image.get_width() / 3, image.get_height() / 2)
	var origin_x := (image.get_width() - slice_size.x * 3) / 2
	for row in range(2):
		for column in range(3):
			var region := image.get_region(Rect2i(
				Vector2i(origin_x + column * slice_size.x, row * slice_size.y),
				slice_size
			))
			var output_path := directory.path_join(
				"town_life_t%02d_r%d_c%d.png" % [sample_second, row + 1, column + 1]
			)
			if region.save_png(output_path) != OK:
				push_error("Failed to save Town life review slice to %s." % output_path)
