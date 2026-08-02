extends SceneTree

const OUTPUT_ROOT := "res://assets/town/npc/characters"
const LOCAL_STEP_THRESHOLD_SQUARED := 0.004
const MINIMUM_FOREGROUND_COMPONENT := 24
const CROP_MARGIN := 16
const SOURCES := {
	"witch": "res://concept/characters/女巫.png",
	"mayor": "res://concept/characters/村長.png",
	"scientist": "res://concept/characters/瘋狂科學家.png",
	"traveler": "res://concept/characters/路人.png",
	"grocer": "res://concept/characters/雜貨店大叔.png",
}


func _init() -> void:
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if directory_error != OK:
		push_error("Could not create Town character output directory: %s" % absolute_output)
		quit(1)
		return
	for character_id in SOURCES:
		if not _build_cutout(String(character_id), String(SOURCES[character_id])):
			quit(1)
			return
	print("Built %d Town character cutouts." % SOURCES.size())
	quit(0)


func _build_cutout(character_id: String, source_path: String) -> bool:
	var source := Image.load_from_file(source_path)
	if source == null or source.is_empty():
		push_error("Could not load Town character concept: %s" % source_path)
		return false
	source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width()
	var height := source.get_height()
	var background := _flood_background(source)
	var foreground := _retain_foreground_components(background, width, height)
	var bounds := _foreground_bounds(foreground, width, height)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		push_error("Town character segmentation produced no foreground: %s" % source_path)
		return false
	bounds = bounds.grow(CROP_MARGIN).intersection(Rect2i(0, 0, width, height))
	var cutout := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	cutout.fill(Color.TRANSPARENT)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var source_index := y * width + x
			if foreground[source_index] == 0:
				continue
			var color := source.get_pixel(x, y)
			color.a = 1.0
			cutout.set_pixel(x - bounds.position.x, y - bounds.position.y, color)
	var output_path := OUTPUT_ROOT.path_join("%s_cutout.png" % character_id)
	var save_error := cutout.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("Could not save Town character cutout: %s" % output_path)
		return false
	print("Built %s from %s (%dx%d)." % [output_path, source_path, cutout.get_width(), cutout.get_height()])
	return true


func _flood_background(source: Image) -> PackedByteArray:
	var width := source.get_width()
	var height := source.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	for x in range(width):
		_seed_pixel(queue, visited, x, 0, width)
		_seed_pixel(queue, visited, x, height - 1, width)
	for y in range(1, height - 1):
		_seed_pixel(queue, visited, 0, y, width)
		_seed_pixel(queue, visited, width - 1, y, width)
	var cursor := 0
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var x: int = index % width
		var y: int = int(index / width)
		var current := source.get_pixel(x, y)
		for direction in directions:
			var nx: int = x + direction.x
			var ny: int = y + direction.y
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			var neighbor_index: int = ny * width + nx
			if visited[neighbor_index] != 0:
				continue
			var neighbor := source.get_pixel(nx, ny)
			if _rgb_distance_squared(current, neighbor) > LOCAL_STEP_THRESHOLD_SQUARED:
				continue
			visited[neighbor_index] = 1
			queue.push_back(neighbor_index)
	return visited


func _retain_foreground_components(background: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var retained := PackedByteArray()
	retained.resize(width * height)
	var inspected := PackedByteArray()
	inspected.resize(width * height)
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for start_index in range(width * height):
		if background[start_index] != 0 or inspected[start_index] != 0:
			continue
		var component := PackedInt32Array([start_index])
		inspected[start_index] = 1
		var cursor := 0
		while cursor < component.size():
			var index := component[cursor]
			cursor += 1
			var x: int = index % width
			var y: int = int(index / width)
			for direction in directions:
				var nx: int = x + direction.x
				var ny: int = y + direction.y
				if nx < 0 or nx >= width or ny < 0 or ny >= height:
					continue
				var neighbor_index: int = ny * width + nx
				if background[neighbor_index] != 0 or inspected[neighbor_index] != 0:
					continue
				inspected[neighbor_index] = 1
				component.push_back(neighbor_index)
		if component.size() < MINIMUM_FOREGROUND_COMPONENT:
			continue
		for index in component:
			retained[index] = 1
	return retained


func _foreground_bounds(foreground: PackedByteArray, width: int, height: int) -> Rect2i:
	var minimum := Vector2i(width, height)
	var maximum := Vector2i(-1, -1)
	for index in range(foreground.size()):
		if foreground[index] == 0:
			continue
		var point := Vector2i(index % width, int(index / width))
		minimum.x = mini(minimum.x, point.x)
		minimum.y = mini(minimum.y, point.y)
		maximum.x = maxi(maximum.x, point.x)
		maximum.y = maxi(maximum.y, point.y)
	if maximum.x < minimum.x:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _seed_pixel(queue: PackedInt32Array, visited: PackedByteArray, x: int, y: int, width: int) -> void:
	var index := y * width + x
	if visited[index] != 0:
		return
	visited[index] = 1
	queue.push_back(index)


func _rgb_distance_squared(left: Color, right: Color) -> float:
	var red := left.r - right.r
	var green := left.g - right.g
	var blue := left.b - right.b
	return red * red + green * green + blue * blue
