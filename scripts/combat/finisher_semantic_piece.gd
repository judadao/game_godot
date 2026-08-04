class_name FinisherSemanticPiece
extends Node2D

## Plays authored frame-by-frame object animation.  Frames are never dissolved
## into each other: every visible pose is a distinct drawing with a shared
## camera, ground anchor, scale and silhouette continuity.

const PART_SHADER := preload("res://shaders/combat/finisher_sprite_part.gdshader")
const GLOW_SHADER := preload("res://shaders/combat/finisher_sprite_glow.gdshader")
# The glow shader samples four source pixels away from the current UV. Keep
# two more pixels for linear filtering so neither the registration gutter nor
# an adjacent cel can bleed into the active frame.
const ATLAS_EDGE_INSET := 6.0
const BASELINE_LUMINANCE_THRESHOLD := 0.045
const BASELINE_SAMPLE_STEP := 2
const MINIMUM_BASELINE_SAMPLES := 4
const MAXIMUM_ROW_REGISTRATION := 128.0

static var _row_registration_cache: Dictionary = {}

var role := "semantic"
var sequence_path := ""
var piece_seed := 0
var _columns := 4
var _rows := 3
var _frame_count := 12
var _frame_index := -1
var _frame_scale := 1.0
var _ground_anchor_ratio := 0.82
var _base_anchor_offset := Vector2.ZERO
var _y_registration_enabled := false
var _row_registration_offsets: Array[float] = []
var _row_baselines: Array[float] = []
var _registered_row_baselines: Array[float] = []
var _playback_map: Array[int] = []
var _timeline_frame_index := -1
var _texture: Texture2D
var _frames: Array[AtlasTexture] = []
var _wide_glow: Sprite2D
var _tight_glow: Sprite2D
var _body: Sprite2D


func _ready() -> void:
	_ensure_layers()


func configure(
	path: String,
	semantic_role: String,
	seed_value: int,
	columns: int = 4,
	rows: int = 3,
	ground_anchor_ratio: float = 0.82,
	light_energy: float = 1.0,
	stabilize_y: bool = true,
	playback_map: Array = []
) -> bool:
	_ensure_layers()
	sequence_path = path
	role = semantic_role
	piece_seed = seed_value
	_columns = maxi(1, columns)
	_rows = maxi(1, rows)
	_frame_count = _columns * _rows
	_ground_anchor_ratio = clampf(ground_anchor_ratio, 0.55, 0.94)
	if not ResourceLoader.exists(sequence_path, "Texture2D"):
		push_error("Finisher object sequence does not exist: %s" % sequence_path)
		visible = false
		return false
	_texture = load(sequence_path) as Texture2D
	if _texture == null:
		push_error("Finisher object sequence failed to load: %s" % sequence_path)
		visible = false
		return false
	_build_frames()
	if _frames.size() != _frame_count:
		push_error("Finisher object sequence could not build all frames: %s" % sequence_path)
		visible = false
		return false
	var cell_size := _cell_size()
	_frame_scale = 380.0 / maxf(cell_size.x, cell_size.y)
	_base_anchor_offset = Vector2(0.0, cell_size.y * (0.5 - _ground_anchor_ratio))
	_y_registration_enabled = stabilize_y
	_playback_map = _resolve_playback_map(playback_map)
	_resolve_row_registration()
	for sprite in [_wide_glow, _tight_glow, _body]:
		sprite.offset = _base_anchor_offset
	var energy := clampf(light_energy, 0.65, 1.65)
	(_wide_glow.material as ShaderMaterial).set_shader_parameter("glow_strength", 0.45 + energy * 0.12)
	(_tight_glow.material as ShaderMaterial).set_shader_parameter("glow_strength", 0.32 + energy * 0.1)
	_frame_index = -1
	_timeline_frame_index = -1
	set_sequence_progress(0.0)
	set_meta("sequence_path", sequence_path)
	set_meta("authored_frame_count", _frame_count)
	set_meta("ground_anchor_ratio", _ground_anchor_ratio)
	return true


func set_sequence_progress(value: float) -> void:
	if _frames.is_empty():
		return
	var progress := clampf(value, 0.0, 1.0)
	_timeline_frame_index = clampi(
		roundi(progress * float(_frame_count - 1)),
		0,
		_frame_count - 1
	)
	var next_index := _playback_map[_timeline_frame_index]
	if next_index != _frame_index:
		_frame_index = next_index
		var frame := _frames[_frame_index]
		var row_index := clampi(_frame_index / _columns, 0, _rows - 1)
		var registration_y := _row_registration_offsets[row_index]
		_wide_glow.texture = frame
		_tight_glow.texture = frame
		_body.texture = frame
		for sprite in [_wide_glow, _tight_glow, _body]:
			sprite.offset = _base_anchor_offset + Vector2(0.0, registration_y)
	var contact_pulse := smoothstep(0.58, 0.74, progress) * (1.0 - smoothstep(0.88, 1.0, progress))
	var residue_presence := smoothstep(0.78, 0.94, progress)
	_wide_glow.modulate.a = lerpf(0.34, 0.64, contact_pulse) + residue_presence * 0.06
	_tight_glow.modulate.a = lerpf(0.28, 0.52, contact_pulse) + residue_presence * 0.04
	_body.modulate.a = 1.0
	_wide_glow.scale = Vector2.ONE * _frame_scale * lerpf(1.045, 1.08, contact_pulse)
	_tight_glow.scale = Vector2.ONE * _frame_scale * lerpf(1.018, 1.04, contact_pulse)
	_body.scale = Vector2.ONE * _frame_scale
	set_meta("frame_index", _frame_index)
	set_meta("timeline_frame_index", _timeline_frame_index)


func get_debug_state() -> Dictionary:
	return {
		"sequence_path": sequence_path,
		"role": role,
		"frame_index": _frame_index,
		"timeline_frame_index": _timeline_frame_index,
		"authored_frame_count": _frame_count,
		"grid_columns": _columns,
		"grid_rows": _rows,
		"ground_anchor_ratio": _ground_anchor_ratio,
		"y_registration_enabled": _y_registration_enabled,
		"frame_row_registration_offsets": _row_registration_offsets.duplicate(),
		"row_baselines": _row_baselines.duplicate(),
		"registered_row_baselines": _registered_row_baselines.duplicate(),
		"current_frame_registration_offset_y": _current_registration_offset(),
		"playback_map": _playback_map.duplicate(),
		"source_position": position,
		"source_rotation": rotation,
		"authored_frame_animation": true,
		"crossfade_slideshow": false,
		"texture_filter_uses_mipmaps": false,
		"atlas_edge_inset": ATLAS_EDGE_INSET,
	}


func _ensure_layers() -> void:
	if _body != null:
		return
	_wide_glow = _make_sprite("WideChromaticGlow", -2, GLOW_SHADER)
	_tight_glow = _make_sprite("TightChromaticGlow", -1, GLOW_SHADER)
	_body = _make_sprite("AuthoredFrameBody", 0, PART_SHADER)


func _make_sprite(node_name: String, layer: int, shader: Shader) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = true
	sprite.z_index = layer
	# Atlas frames must never select a lower mip that averages the pure-black
	# gutter into the current cel. At runtime that looks like a dark line which
	# abruptly cuts through an otherwise continuous object.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	add_child(sprite)
	return sprite


func _build_frames() -> void:
	_frames.clear()
	var cell_size := _cell_size()
	for frame_index in _frame_count:
		var column := frame_index % _columns
		var row := frame_index / _columns
		var atlas := AtlasTexture.new()
		atlas.atlas = _texture
		# Generated contact sheets can contain one-pixel registration guides at
		# cel boundaries. Keep those guides and any filtering footprint outside
		# the runtime frame so they cannot cut a vertical or horizontal seam
		# through the authored action.
		atlas.region = Rect2(
			Vector2(float(column), float(row)) * cell_size + Vector2.ONE * ATLAS_EDGE_INSET,
			cell_size - Vector2.ONE * ATLAS_EDGE_INSET * 2.0
		)
		atlas.filter_clip = true
		_frames.append(atlas)


func _cell_size() -> Vector2:
	# Generated landscape sheets can retain one padding pixel below row three.
	# Integer regions prevent fractional sampling from leaking the next frame.
	var texture_size := _texture.get_size()
	return Vector2(
		floorf(texture_size.x / float(_columns)),
		floorf(texture_size.y / float(_rows))
	)


func _resolve_playback_map(values: Array) -> Array[int]:
	var result: Array[int] = []
	if values.size() == _frame_count:
		for value in values:
			result.append(clampi(int(value), 0, _frame_count - 1))
		return result
	for frame_index in _frame_count:
		result.append(frame_index)
	return result


func _resolve_row_registration() -> void:
	_row_registration_offsets.clear()
	_row_baselines.clear()
	_registered_row_baselines.clear()
	for _row_index in _rows:
		_row_registration_offsets.append(0.0)
		_row_baselines.append(0.0)
		_registered_row_baselines.append(0.0)
	if not _y_registration_enabled:
		return
	var cache_key := "%s|%d|%d" % [sequence_path, _columns, _rows]
	if _row_registration_cache.has(cache_key):
		_apply_cached_row_registration(_row_registration_cache[cache_key] as Dictionary)
		return
	var image := _texture.get_image()
	if image == null or image.is_empty():
		_y_registration_enabled = false
		return
	var cell_size := Vector2i(_cell_size())
	for row_index in _rows:
		var frame_baselines: Array[float] = []
		for column_index in _columns:
			frame_baselines.append(_find_frame_baseline(image, column_index, row_index, cell_size))
		frame_baselines.sort()
		var middle := frame_baselines.size() / 2
		var row_baseline := (
			(frame_baselines[middle - 1] + frame_baselines[middle]) * 0.5
			if frame_baselines.size() % 2 == 0
			else frame_baselines[middle]
		)
		_row_baselines[row_index] = row_baseline
	var reference_baseline := _row_baselines[0]
	for row_index in _rows:
		var offset := clampf(
			reference_baseline - _row_baselines[row_index],
			-MAXIMUM_ROW_REGISTRATION,
			MAXIMUM_ROW_REGISTRATION
		)
		_row_registration_offsets[row_index] = offset
		_registered_row_baselines[row_index] = _row_baselines[row_index] + offset
	_row_registration_cache[cache_key] = {
		"offsets": _row_registration_offsets.duplicate(),
		"baselines": _row_baselines.duplicate(),
		"registered_baselines": _registered_row_baselines.duplicate(),
	}


func _apply_cached_row_registration(cached: Dictionary) -> void:
	_row_registration_offsets.assign(cached.get("offsets", []) as Array)
	_row_baselines.assign(cached.get("baselines", []) as Array)
	_registered_row_baselines.assign(cached.get("registered_baselines", []) as Array)


func _find_frame_baseline(
	image: Image,
	column_index: int,
	row_index: int,
	cell_size: Vector2i
) -> float:
	var cell_origin := Vector2i(column_index * cell_size.x, row_index * cell_size.y)
	for local_y in range(
		cell_size.y - ceili(ATLAS_EDGE_INSET) - 1,
		ceili(ATLAS_EDGE_INSET) - 1,
		-1
	):
		var bright_samples := 0
		for local_x in range(
			ceili(ATLAS_EDGE_INSET),
			cell_size.x - ceili(ATLAS_EDGE_INSET),
			BASELINE_SAMPLE_STEP
		):
			var color := image.get_pixel(cell_origin.x + local_x, cell_origin.y + local_y)
			if maxf(color.r, maxf(color.g, color.b)) >= BASELINE_LUMINANCE_THRESHOLD:
				bright_samples += 1
				if bright_samples >= MINIMUM_BASELINE_SAMPLES:
					return float(local_y)
	return float(cell_size.y) * _ground_anchor_ratio


func _current_registration_offset() -> float:
	if _frame_index < 0 or _row_registration_offsets.is_empty():
		return 0.0
	var row_index := clampi(_frame_index / _columns, 0, _row_registration_offsets.size() - 1)
	return _row_registration_offsets[row_index]
