extends SceneTree

const CELL_SIZE := Vector2i(144, 152)
const FRAME_COUNT := 4
const STATES := [
	"idle", "walk", "sit", "chat", "laugh",
	"happy", "sad", "surprised", "angry",
]
const OUTPUT_ROOT := "res://assets/town/npc/characters/"
const CHARACTER_SPECS := [
	{"name": "mayor", "source": "mayor_cutout.png", "variant": "none"},
	{"name": "traveler", "source": "traveler_cutout.png", "variant": "none"},
	{"name": "witch", "source": "witch_cutout.png", "variant": "none"},
	{"name": "guard", "source": "traveler_cutout.png", "variant": "guard"},
	{"name": "grocer", "source": "grocer_cutout.png", "variant": "none"},
	{"name": "scientist", "source": "scientist_cutout.png", "variant": "none"},
	{"name": "innkeeper", "source": "grocer_cutout.png", "variant": "innkeeper"},
]


func _init() -> void:
	for spec in CHARACTER_SPECS:
		_build_atlas(spec)
	quit()


func _build_atlas(spec: Dictionary) -> void:
	var source_path := OUTPUT_ROOT.path_join(String(spec["source"]))
	var source_texture := load(source_path) as Texture2D
	var source: Image = source_texture.get_image() if source_texture != null else null
	if source == null or source.is_empty():
		push_error("Cannot load Town NPC cutout: %s" % source_path)
		return
	var max_body_size := Vector2i(112, 132)
	var scale_factor := minf(
		float(max_body_size.x) / float(source.get_width()),
		float(max_body_size.y) / float(source.get_height())
	)
	var body_size := Vector2i(
		maxi(1, int(round(source.get_width() * scale_factor))),
		maxi(1, int(round(source.get_height() * scale_factor)))
	)
	source.resize(body_size.x, body_size.y, Image.INTERPOLATE_NEAREST)
	_apply_variant_palette(source, String(spec["variant"]))
	var atlas := Image.create_empty(
		CELL_SIZE.x * FRAME_COUNT,
		CELL_SIZE.y * STATES.size(),
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for state_index in range(STATES.size()):
		for frame in range(FRAME_COUNT):
			var cell := _build_frame(source, String(STATES[state_index]), frame, String(spec["variant"]))
			atlas.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL_SIZE), Vector2i(frame * CELL_SIZE.x, state_index * CELL_SIZE.y))
	var output_path := OUTPUT_ROOT.path_join("%s_animation_atlas.png" % spec["name"])
	var error := atlas.save_png(output_path)
	if error != OK:
		push_error("Cannot save Town NPC animation atlas: %s" % output_path)
	else:
		print("WROTE %s (%dx%d)" % [output_path, atlas.get_width(), atlas.get_height()])


func _build_frame(source: Image, state: String, frame: int, variant: String) -> Image:
	var cell: Image = Image.create_empty(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	cell.fill(Color.TRANSPARENT)
	var body: Image = source.duplicate()
	var frame_wave: int = [-1, 0, 1, 0][frame]
	var body_height_scale: float = 1.0
	var body_y_offset: int = 0
	match state:
		"sit":
			body_height_scale = [0.76, 0.75, 0.74, 0.75][frame]
			body_y_offset = 1
		"laugh":
			body_height_scale = [1.0, 1.025, 1.04, 1.02][frame]
			body_y_offset = [-1, -3, -5, -2][frame]
		"happy":
			body_height_scale = [1.0, 1.015, 1.03, 1.015][frame]
			body_y_offset = [0, -2, -4, -2][frame]
		"sad":
			body_height_scale = [0.98, 0.97, 0.965, 0.97][frame]
			body_y_offset = [2, 3, 4, 3][frame]
		"surprised":
			body_height_scale = [1.0, 1.045, 1.01, 1.03][frame]
			body_y_offset = [0, -4, -1, -3][frame]
	if not is_equal_approx(body_height_scale, 1.0):
		body.resize(body.get_width(), maxi(1, int(round(body.get_height() * body_height_scale))), Image.INTERPOLATE_NEAREST)
	var body_x: int = int((CELL_SIZE.x - body.get_width()) / 2)
	var body_y: int = CELL_SIZE.y - 8 - body.get_height() + body_y_offset
	if variant == "guard":
		_draw_guard_spear(cell, body_x, body_y, body.get_height())
	if state == "sit":
		_draw_stool(cell, body_x + body.get_width() / 2, CELL_SIZE.y - 9)
	for y in range(body.get_height()):
		var normalized_y: float = float(y) / maxf(1.0, float(body.get_height() - 1))
		for x in range(body.get_width()):
			var color: Color = body.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var normalized_x: float = float(x) / maxf(1.0, float(body.get_width() - 1))
			var row_shift: int = _pixel_shift(state, frame_wave, normalized_x, normalized_y, frame)
			var target_x: int = body_x + x + row_shift
			var target_y: int = body_y + y
			if target_x >= 0 and target_x < CELL_SIZE.x and target_y >= 0 and target_y < CELL_SIZE.y:
				cell.set_pixel(target_x, target_y, color)
	if variant == "innkeeper":
		_draw_innkeeper_cap(cell, body_x + body.get_width() / 2, body_y + 2)
	return cell


func _pixel_shift(
	state: String,
	frame_wave: int,
	normalized_x: float,
	normalized_y: float,
	frame: int
) -> int:
	match state:
		"idle":
			if normalized_y < 0.38:
				return frame_wave
			if normalized_y > 0.72:
				return -frame_wave
		"walk":
			if normalized_y > 0.74:
				var stride: int = [3, -2, -3, 2][frame]
				return stride if normalized_x < 0.5 else -stride
			return [-1, 0, 1, 0][frame]
		"chat":
			if normalized_y < 0.58:
				return [0, 2, -1, 1][frame]
		"laugh":
			return int(round(sin(normalized_y * PI) * [-2.0, 2.0, -2.0, 2.0][frame]))
		"happy":
			if normalized_y < 0.45:
				return [-1, 1, -1, 1][frame]
		"sad":
			if normalized_y < 0.55:
				return -2
		"surprised":
			if normalized_y < 0.35:
				return [0, -1, 1, 0][frame]
		"angry":
			return int(round((1.0 - normalized_y) * [-3.0, 2.0, -3.0, 2.0][frame]))
	return 0


func _apply_variant_palette(image: Image, variant: String) -> void:
	if variant == "none":
		return
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if variant == "guard" and color.b > color.r * 1.12 and color.b > color.g * 1.04:
				var value := maxf(color.b, color.g)
				color = Color(value * 0.42, value * 0.68, value * 0.38, color.a)
			elif variant == "innkeeper" and color.g > color.r * 1.05 and color.g > color.b * 1.08:
				var value := color.g
				color = Color(value * 0.72, value * 0.28, value * 0.24, color.a)
			image.set_pixel(x, y, color)


func _draw_guard_spear(image: Image, body_x: int, body_y: int, body_height: int) -> void:
	# Draw behind the body so the near hand/forearm naturally covers the shaft.
	var spear_x := maxi(8, body_x + 12)
	for y in range(maxi(4, body_y - 5), mini(CELL_SIZE.y - 7, body_y + body_height)):
		for width in range(2):
			image.set_pixel(spear_x + width, y, Color("6d4930"))
	for offset in range(6):
		var half_width := mini(offset, 5 - offset)
		for x in range(spear_x - half_width, spear_x + half_width + 2):
			var y := maxi(0, body_y - 10 + offset)
			if x >= 0 and x < CELL_SIZE.x:
				image.set_pixel(x, y, Color("c7d4cd"))


func _draw_innkeeper_cap(image: Image, center_x: int, top_y: int) -> void:
	var dark := Color("613a32")
	var light := Color("9b5944")
	for y in range(maxi(0, top_y), mini(CELL_SIZE.y, top_y + 6)):
		var inset: int = absi((top_y + 3) - y)
		for x in range(center_x - 9 + inset, center_x + 10 - inset):
			if x >= 0 and x < CELL_SIZE.x:
				image.set_pixel(x, y, light)
	var brim_y := mini(CELL_SIZE.y - 1, top_y + 6)
	for x in range(center_x - 12, center_x + 13):
		if x >= 0 and x < CELL_SIZE.x:
			image.set_pixel(x, brim_y, dark)


func _draw_stool(image: Image, center_x: int, baseline_y: int) -> void:
	var dark := Color("5b3825")
	var light := Color("a96d3e")
	for y in range(baseline_y - 29, baseline_y - 23):
		for x in range(center_x - 24, center_x + 25):
			image.set_pixel(x, y, light if y < baseline_y - 26 else dark)
	for y in range(baseline_y - 23, baseline_y + 1):
		for width in range(4):
			image.set_pixel(center_x - 19 + width, y, dark)
			image.set_pixel(center_x + 16 + width, y, dark)
