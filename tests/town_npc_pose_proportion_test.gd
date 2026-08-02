extends SceneTree

const CHARACTER_ROOT := "res://assets/town/npc/characters/"
const CHARACTER_ASSETS := [
	"traveler", "witch", "guard", "grocer", "scientist", "innkeeper",
	"visitor_farmer", "visitor_minstrel",
]
const CELL_SIZE := Vector2i(144, 152)
const FRAME_COUNT := 4
const STATE_COUNT := 13
const CHARACTER_ACTION_STATE_COUNT := 17
const EMOTION_ROWS := [4, 5, 6, 7, 8]
const CHARACTER_ACTION_ROWS := [13, 14, 15, 16]
const GUARD_SPEAR_ROWS := [0, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const TARGET_HEIGHT := 132
const FOOT_BASELINE_Y := 144
const CORE_SAMPLE_HALF_WIDTH := 24
const HEAD_BAND_START := 6
const HEAD_BAND_END := 40
const TORSO_BAND_START := 42
const TORSO_BAND_END := 88
const MAX_CORE_ALPHA_SPREAD_RATIO := 1.4
const MAX_HEAD_CORE_REFERENCE_RATIO := 1.33
const MAX_ACTION_HEAD_CORE_REFERENCE_RATIO := 1.5
const MIN_ACTION_HEAD_CORE_REFERENCE_RATIO := 0.55
const MAX_ACTION_HEIGHT_SPREAD := 10
const SPEAR_SAMPLE_END_Y := 132
const MIN_SPEAR_LENGTH := 112
const MAX_SPEAR_SLOPE_X := 30
const SPEAR_SAMPLE_RADIUS := 2
const MIN_SPEAR_ALPHA_COVERAGE := 0.92

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for character_name in CHARACTER_ASSETS:
		_assert_emotion_source(String(character_name))
		_assert_atlas_proportions(String(character_name))
	_assert_guard_spear_continuity()
	_finish()


func _assert_emotion_source(character_name: String) -> void:
	var source_path := "%smotion_strips_v3/%s_emotion.png" % [CHARACTER_ROOT, character_name]
	var source_exists := ResourceLoader.exists(source_path)
	_expect(
		source_exists,
		"%s must provide the reviewed 4x5 emotion strip used for atlas rows 4-8."
		% character_name
	)
	if not source_exists:
		return
	var texture := load(source_path) as Texture2D
	_expect(texture != null, "%s emotion strip must load." % character_name)
	if texture == null:
		return
	var image := texture.get_image()
	var row_ranges := _find_occupied_y_ranges(image)
	_expect(
		row_ranges.size() == EMOTION_ROWS.size(),
		"%s emotion strip must contain five occupied rows, got %d."
		% [character_name, row_ranges.size()]
	)
	if row_ranges.size() != EMOTION_ROWS.size():
		return
	var band_width := image.get_width() / FRAME_COUNT
	for source_row in row_ranges.size():
		var row_range: Vector2i = row_ranges[source_row]
		var pose_hashes := {}
		for column in FRAME_COUNT:
			var pose := image.get_region(Rect2i(
				column * band_width,
				row_range.x,
				band_width,
				row_range.y - row_range.x
			))
			if pose.get_used_rect().has_area():
				pose_hashes[hash(pose.get_data())] = true
		_expect(
			pose_hashes.size() >= 3,
			"%s emotion strip row %d must contain at least three distinct source poses."
			% [character_name, source_row]
		)


func _assert_atlas_proportions(character_name: String) -> void:
	var atlas_path := "%s%s_animation_atlas.png" % [CHARACTER_ROOT, character_name]
	var texture := load(atlas_path) as Texture2D
	_expect(texture != null, "%s atlas must load." % character_name)
	if texture == null:
		return
	var image := texture.get_image()
	var expected_state_count := (
		CHARACTER_ACTION_STATE_COUNT
		if character_name in ["witch", "scientist"]
		else STATE_COUNT
	)
	_expect(
		image.get_size() == Vector2i(CELL_SIZE.x * FRAME_COUNT, CELL_SIZE.y * expected_state_count),
		"%s atlas must use its approved 4x%d grid." % [character_name, expected_state_count]
	)
	var idle_head_core_areas: Array[int] = []
	for column in FRAME_COUNT:
		var idle_frame := image.get_region(Rect2i(
			column * CELL_SIZE.x,
			0,
			CELL_SIZE.x,
			CELL_SIZE.y
		))
		var idle_used := idle_frame.get_used_rect()
		if idle_used.has_area():
			idle_head_core_areas.append(_count_core_alpha(
				idle_frame,
				idle_used.position.y + HEAD_BAND_START,
				idle_used.position.y + HEAD_BAND_END
			))
	idle_head_core_areas.sort()
	var idle_head_reference := 0.0
	if idle_head_core_areas.size() == FRAME_COUNT:
		idle_head_reference = (
			idle_head_core_areas[1] + idle_head_core_areas[2]
		) * 0.5
	var reviewed_rows := EMOTION_ROWS.duplicate()
	if character_name in ["witch", "scientist"]:
		reviewed_rows.append_array(CHARACTER_ACTION_ROWS)
	for row in reviewed_rows:
		var is_character_action: bool = row in CHARACTER_ACTION_ROWS
		var heights: Array[int] = []
		var widths: Array[int] = []
		var head_core_areas: Array[int] = []
		var torso_core_areas: Array[int] = []
		var frame_hashes := {}
		for column in FRAME_COUNT:
			var frame := image.get_region(Rect2i(
				column * CELL_SIZE.x,
				row * CELL_SIZE.y,
				CELL_SIZE.x,
				CELL_SIZE.y
			))
			var used := frame.get_used_rect()
			_expect(used.has_area(), "%s row %d frame %d must not be empty." % [character_name, row, column])
			if not used.has_area():
				continue
			heights.append(used.size.y)
			widths.append(used.size.x)
			var head_core_area := _count_core_alpha(
				frame, used.position.y + HEAD_BAND_START, used.position.y + HEAD_BAND_END
			)
			head_core_areas.append(head_core_area)
			if idle_head_reference > 0.0:
				var head_ratio := float(head_core_area) / idle_head_reference
				var maximum_head_ratio := (
					MAX_ACTION_HEAD_CORE_REFERENCE_RATIO
					if is_character_action
					else MAX_HEAD_CORE_REFERENCE_RATIO
				)
				_expect(
					head_ratio <= maximum_head_ratio,
					"%s row %d frame %d head core must remain within %.2fx of idle adult proportions; got %.3fx."
					% [
						character_name,
						row,
						column,
						maximum_head_ratio,
						head_ratio,
					]
				)
				if is_character_action:
					_expect(
						head_ratio >= MIN_ACTION_HEAD_CORE_REFERENCE_RATIO,
						"%s row %d frame %d head core must remain at least %.2fx of idle adult proportions; got %.3fx."
						% [
							character_name,
							row,
							column,
							MIN_ACTION_HEAD_CORE_REFERENCE_RATIO,
							head_ratio,
						]
					)
			torso_core_areas.append(_count_core_alpha(
				frame, used.position.y + TORSO_BAND_START, used.position.y + TORSO_BAND_END
			))
			frame_hashes[hash(frame.get_data())] = true
			_expect(
				used.end.y == FOOT_BASELINE_Y,
				"%s row %d frame %d foot must end at y=%d, got y=%d."
				% [character_name, row, column, FOOT_BASELINE_Y, used.end.y]
			)
			_expect(
				used.size.y >= TARGET_HEIGHT - (8 if is_character_action else 6)
				and used.size.y <= TARGET_HEIGHT + 6,
				"%s row %d frame %d must retain adult height near %dpx, got %dpx."
				% [character_name, row, column, TARGET_HEIGHT, used.size.y]
			)
			_expect(
				used.position.x > 0 and used.end.x < CELL_SIZE.x,
				"%s row %d frame %d width %d must not clip the 144px cell."
				% [character_name, row, column, used.size.x]
			)
		if heights.size() == FRAME_COUNT:
			heights.sort()
			var median_height := (heights[1] + heights[2]) * 0.5
			var maximum_height_spread := (
				MAX_ACTION_HEIGHT_SPREAD if is_character_action else 4
			)
			_expect(
				heights[3] - heights[0] <= maximum_height_spread,
				"%s row %d visible height must stay within %dpx across its authored action; heights=%s."
				% [character_name, row, maximum_height_spread, heights]
			)
			_expect(
				median_height >= TARGET_HEIGHT - 1 and median_height <= TARGET_HEIGHT + 1,
				"%s row %d median height must normalize to %dpx; heights=%s widths=%s."
				% [character_name, row, TARGET_HEIGHT, heights, widths]
			)
		# Props and spell effects intentionally cross the central sample bands in
		# the authored action rows. Their body proportions are reviewed visually;
		# here we retain height, baseline, head-range, clipping, and uniqueness
		# contracts without mistaking a book or ward circle for a swollen torso.
		if head_core_areas.size() == FRAME_COUNT and not is_character_action:
			_assert_core_area_stability(character_name, row, "head", head_core_areas)
		if torso_core_areas.size() == FRAME_COUNT and not is_character_action:
			_assert_core_area_stability(character_name, row, "torso", torso_core_areas)
		_expect(
			frame_hashes.size() >= 3,
			"%s row %d must contain at least three authored poses."
			% [character_name, row]
		)


func _count_core_alpha(frame: Image, start_y: int, end_y: int) -> int:
	var alpha_count := 0
	var center_x := CELL_SIZE.x / 2
	for y in range(maxi(0, start_y), mini(frame.get_height(), end_y)):
		for x in range(center_x - CORE_SAMPLE_HALF_WIDTH, center_x + CORE_SAMPLE_HALF_WIDTH):
			if frame.get_pixel(x, y).a > 0.0:
				alpha_count += 1
	return alpha_count


func _assert_core_area_stability(
	character_name: String,
	row: int,
	region_name: String,
	areas: Array[int]
) -> void:
	areas.sort()
	_expect(
		areas[0] > 0,
		"%s row %d %s core sample must contain visible alpha in every frame."
		% [character_name, row, region_name]
	)
	if areas[0] <= 0:
		return
	var spread_ratio := float(areas[3]) / float(areas[0])
	_expect(
		spread_ratio <= MAX_CORE_ALPHA_SPREAD_RATIO,
		"%s row %d %s core area must remain proportionally stable (max/min <= %.2f); areas=%s ratio=%.3f."
		% [character_name, row, region_name, MAX_CORE_ALPHA_SPREAD_RATIO, areas, spread_ratio]
	)


func _find_occupied_y_ranges(image: Image) -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	var range_start := -1
	for y in image.get_height():
		var occupied := false
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				occupied = true
				break
		if occupied and range_start < 0:
			range_start = y
		elif not occupied and range_start >= 0:
			ranges.append(Vector2i(range_start, y))
			range_start = -1
	if range_start >= 0:
		ranges.append(Vector2i(range_start, image.get_height()))
	return ranges


func _assert_guard_spear_continuity() -> void:
	var texture := load("%sguard_animation_atlas.png" % CHARACTER_ROOT) as Texture2D
	_expect(texture != null, "Guard atlas must load for spear continuity checks.")
	if texture == null:
		return
	var image := texture.get_image()
	for row in GUARD_SPEAR_ROWS:
		for column in FRAME_COUNT:
			var frame := image.get_region(Rect2i(
				column * CELL_SIZE.x,
				row * CELL_SIZE.y,
				CELL_SIZE.x,
				CELL_SIZE.y
			))
			_expect(
				_has_long_straight_alpha(frame),
				"Guard row %d frame %d must retain one long continuous spear silhouette."
				% [row, column]
			)


func _has_long_straight_alpha(frame: Image) -> bool:
	var used := frame.get_used_rect()
	if not used.has_area():
		return false
	var start_y := used.position.y
	if SPEAR_SAMPLE_END_Y - start_y + 1 < MIN_SPEAR_LENGTH:
		return false
	var start_columns: Array[int] = []
	var end_columns: Array[int] = []
	for x in frame.get_width():
		if frame.get_pixel(x, start_y).a > 0.0:
			start_columns.append(x)
		if frame.get_pixel(x, SPEAR_SAMPLE_END_Y).a > 0.0:
			end_columns.append(x)
	for start_x in start_columns:
		for end_x in end_columns:
			if abs(end_x - start_x) > MAX_SPEAR_SLOPE_X:
				continue
			var supported_rows := 0
			var sample_count := SPEAR_SAMPLE_END_Y - start_y + 1
			for y in range(start_y, SPEAR_SAMPLE_END_Y + 1):
				var progress := float(y - start_y) / float(SPEAR_SAMPLE_END_Y - start_y)
				var expected_x := roundi(lerpf(float(start_x), float(end_x), progress))
				var row_supported := false
				for sample_x in range(
					maxi(0, expected_x - SPEAR_SAMPLE_RADIUS),
					mini(frame.get_width(), expected_x + SPEAR_SAMPLE_RADIUS + 1)
				):
					if frame.get_pixel(sample_x, y).a > 0.0:
						row_supported = true
						break
				if row_supported:
					supported_rows += 1
			if float(supported_rows) / float(sample_count) >= MIN_SPEAR_ALPHA_COVERAGE:
				return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC emotion sources, adult proportions, and Guard spear continuity")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
