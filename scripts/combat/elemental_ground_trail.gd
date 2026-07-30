class_name ElementalGroundTrail
extends Node2D

signal trail_started(profile_id: String, element: String, segment_count: int)
signal stage_changed(stage_name: StringName)
signal trail_finished(profile_id: String)

const CATALOG_SCRIPT := preload("res://scripts/systems/elemental_ground_trail_catalog.gd")
const STAGE_FRESH := &"fresh"
const STAGE_ACTIVE := &"active"
const STAGE_DECAY := &"decay"
const VISUAL_SLOT_COUNT := 4

@export var auto_free := true

@onready var underlay_edge: Line2D = $PathUnderlay/EdgeRibbon
@onready var underlay_core: Line2D = $PathUnderlay/CoreRibbon
@onready var segment_owner: Node2D = $SegmentOwner

var _catalog: RefCounted = CATALOG_SCRIPT.new()
var _profile: Dictionary = {}
var _profile_id := ""
var _element := ""
var _topology := ""
var _segments: Array[Node2D] = []
var _sampled_points := PackedVector2Array()
var _duration := 1.0
var _elapsed := 0.0
var _progress := 0.0
var _intensity := 1.0
var _active := false
var _stage_name := STAGE_FRESH
var _atlas: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	visible = false


func play_path(
	profile_id: String,
	local_path: PackedVector2Array,
	intensity: float = 1.0,
	duration_scale: float = 1.0
) -> bool:
	if local_path.size() < 2:
		push_error("Elemental ground trail path needs at least two points: %s" % profile_id)
		return false
	if _catalog.call("get_all_profiles").is_empty():
		if not bool(_catalog.call("load_catalog")):
			return false
	var profile := _catalog.call("get_profile", profile_id) as Dictionary
	if profile.is_empty():
		push_error("Unknown elemental ground trail profile: %s" % profile_id)
		return false
	var atlas_path := String(profile.get("atlas_path", ""))
	var atlas := load(atlas_path) as Texture2D
	if atlas == null:
		push_error("Elemental ground trail atlas could not be loaded: %s" % atlas_path)
		return false
	var samples := _sample_path(
		local_path,
		float(profile.get("segment_spacing", 64.0)),
		int(profile.get("max_segments", 20))
	)
	if samples.size() < 2:
		push_error("Elemental ground trail path has no measurable length: %s" % profile_id)
		return false

	_clear_segments()
	_profile = profile
	_profile_id = profile_id
	_element = String(profile.get("element", "normal"))
	_topology = String(profile.get("topology", ""))
	_atlas = atlas
	_intensity = clampf(intensity, 0.5, 2.0)
	_duration = maxf(
		0.05,
		float(profile.get("duration", 3.0)) * clampf(duration_scale, 0.05, 4.0)
	)
	_sampled_points.clear()
	for sample_index in samples.size():
		var sample := samples[sample_index] as Dictionary
		var point := sample.get("point", Vector2.ZERO) as Vector2
		var tangent := sample.get("tangent", Vector2.RIGHT) as Vector2
		_sampled_points.append(point)
		_build_segment(sample_index, point, tangent)
	_configure_underlay()
	_elapsed = 0.0
	_progress = 0.0
	_active = true
	visible = true
	_set_stage(STAGE_FRESH)
	set_process(true)
	_apply_progress(0.0)
	trail_started.emit(_profile_id, _element, _segments.size())
	return true


func play_world_path(
	profile_id: String,
	world_path: PackedVector2Array,
	intensity: float = 1.0,
	duration_scale: float = 1.0
) -> bool:
	var local_path := PackedVector2Array()
	for world_point in world_path:
		local_path.append(to_local(world_point))
	return play_path(profile_id, local_path, intensity, duration_scale)


func is_active() -> bool:
	return _active


func get_profile_id() -> String:
	return _profile_id


func get_element() -> String:
	return _element


func get_topology() -> String:
	return _topology


func get_atlas_path() -> String:
	return String(_profile.get("atlas_path", ""))


func get_stage_name() -> StringName:
	return _stage_name


func get_segment_count() -> int:
	return _segments.size()


func get_visual_slot_count() -> int:
	return _segments.size() * VISUAL_SLOT_COUNT


func get_visual_budget() -> int:
	return 2 + _segments.size() * (
		VISUAL_SLOT_COUNT + int(_profile.get("debris_count", 0))
	)


func get_duration() -> float:
	return _duration


func uses_unscaled_timeline() -> bool:
	return true


func get_sampled_points() -> PackedVector2Array:
	return _sampled_points.duplicate()


func debug_set_progress(value: float) -> void:
	if not _active:
		return
	_progress = clampf(value, 0.0, 1.0)
	_elapsed = _progress * _duration
	_apply_progress(_progress)


func _process(delta: float) -> void:
	if not _active:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.05)
	_elapsed = minf(_duration, _elapsed + real_delta)
	_progress = _elapsed / _duration
	_apply_progress(_progress)
	if _elapsed >= _duration:
		_finish()


func _sample_path(
	path: PackedVector2Array,
	requested_spacing: float,
	max_segments: int
) -> Array[Dictionary]:
	var segment_lengths := PackedFloat32Array()
	var total_length := 0.0
	for index in path.size() - 1:
		var length := path[index].distance_to(path[index + 1])
		segment_lengths.append(length)
		total_length += length
	if total_length <= 0.01:
		return []
	var sample_count := clampi(
		int(ceil(total_length / maxf(1.0, requested_spacing))) + 1,
		2,
		maxi(2, max_segments)
	)
	var samples: Array[Dictionary] = []
	for sample_index in sample_count:
		var distance := (
			total_length * float(sample_index) / float(maxi(1, sample_count - 1))
		)
		samples.append(_sample_at_distance(path, segment_lengths, distance))
	return samples


func _sample_at_distance(
	path: PackedVector2Array,
	segment_lengths: PackedFloat32Array,
	distance: float
) -> Dictionary:
	var remaining := distance
	for index in segment_lengths.size():
		var segment_length := float(segment_lengths[index])
		if remaining <= segment_length or index == segment_lengths.size() - 1:
			var tangent := (path[index + 1] - path[index]).normalized()
			if tangent.is_zero_approx():
				tangent = Vector2.RIGHT
			return {
				"point": path[index] + tangent * minf(remaining, segment_length),
				"tangent": tangent,
			}
		remaining -= segment_length
	return {"point": path[-1], "tangent": Vector2.RIGHT}


func _build_segment(index: int, point: Vector2, tangent: Vector2) -> void:
	var segment := Node2D.new()
	segment.name = "GroundSegment%02d" % index
	segment.position = point
	segment.rotation = tangent.angle() + sin(float(index) * 2.17) * 0.025
	segment_owner.add_child(segment)
	_segments.append(segment)

	var width := float(_profile.get("width", 80.0)) * _intensity
	var length := float(_profile.get("segment_spacing", 64.0))
	var size_variation := 0.96 + sin(float(index) * 1.73) * 0.045
	_add_atlas_slot(
		segment,
		"Core",
		"core",
		-3,
		Vector2(length * 1.65, width * 1.55) * size_variation,
		String(_profile.get("core_color", "#ffffff")),
		index
	)
	_add_atlas_slot(
		segment,
		"Edge",
		"edge",
		-2,
		Vector2(length * 1.78, width * 1.48) * size_variation,
		String(_profile.get("edge_color", "#ffffff")),
		index
	)
	_add_atlas_slot(
		segment,
		"Accent",
		"accent",
		-1,
		Vector2(length * 1.58, width * 1.34) * size_variation,
		String(_profile.get("accent_color", "#ffffff")),
		index
	)
	_add_atlas_slot(
		segment,
		"Debris",
		"debris",
		0,
		Vector2(length * 1.82, width * 1.62) * size_variation,
		String(_profile.get("debris_color", "#ffffff")),
		index
	)


func _add_atlas_slot(
	segment: Node2D,
	node_name: String,
	atlas_region_name: String,
	z_index: int,
	target_size: Vector2,
	tint_html: String,
	segment_index: int
) -> void:
	var slot := Node2D.new()
	slot.name = node_name
	slot.z_index = z_index
	var phase := float(segment_index) * 1.37 + float(z_index) * 0.61
	slot.position.y = sin(phase) * target_size.y * 0.035
	slot.rotation = sin(phase * 0.73) * 0.022
	slot.set_meta("base_scale", slot.scale)
	segment.add_child(slot)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _make_atlas_texture(atlas_region_name)
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var texture_size := sprite.texture.get_size()
	var vertical_variation := 1.0 + cos(phase * 1.13) * 0.08
	sprite.scale = Vector2(
		target_size.x / maxf(1.0, texture_size.x),
		target_size.y * vertical_variation / maxf(1.0, texture_size.y)
	)
	sprite.flip_h = segment_index % 2 == 1
	var authored_tint := Color.from_string(tint_html, Color.WHITE)
	sprite.modulate = authored_tint.lerp(Color.WHITE, 0.72)
	sprite.modulate.a = authored_tint.a * (0.58 if atlas_region_name == "core" else 1.0)
	slot.add_child(sprite)


func _make_atlas_texture(region_name: String) -> AtlasTexture:
	var regions := _profile.get("atlas_regions", {}) as Dictionary
	var values := regions.get(region_name, []) as Array
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = Rect2(
		float(values[0]),
		float(values[1]),
		float(values[2]),
		float(values[3])
	)
	return texture


func _configure_underlay() -> void:
	var width := float(_profile.get("width", 80.0)) * _intensity
	underlay_edge.points = _sampled_points
	underlay_edge.width = width * 0.72
	underlay_edge.default_color = Color.from_string(
		String(_profile.get("edge_color", "#ffffff")),
		Color.WHITE
	).darkened(0.28)
	underlay_edge.joint_mode = Line2D.LINE_JOINT_ROUND
	underlay_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	underlay_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	underlay_core.points = _sampled_points
	underlay_core.width = width * 0.58
	underlay_core.default_color = Color.from_string(
		String(_profile.get("core_color", "#ffffff")),
		Color.WHITE
	)
	underlay_core.joint_mode = Line2D.LINE_JOINT_ROUND
	underlay_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	underlay_core.end_cap_mode = Line2D.LINE_CAP_ROUND


func _apply_progress(progress: float) -> void:
	if progress < 0.14:
		_set_stage(STAGE_FRESH)
	elif progress < 0.7:
		_set_stage(STAGE_ACTIVE)
	else:
		_set_stage(STAGE_DECAY)
	var global_reveal := smoothstep(0.0, 0.13, progress)
	var global_decay := 1.0 - smoothstep(0.7, 1.0, progress)
	var pulse_speed := float(_profile.get("pulse_speed", 3.0))
	var ribbon_pulse := 0.96 + 0.04 * sin(progress * pulse_speed * TAU)
	var profile_width := float(_profile.get("width", 80.0)) * _intensity
	underlay_edge.width = profile_width * 0.72 * ribbon_pulse
	underlay_core.width = profile_width * 0.58 * ribbon_pulse
	underlay_edge.modulate.a = global_reveal * global_decay * 0.18
	underlay_core.modulate.a = global_reveal * global_decay * 0.26
	for index in _segments.size():
		var segment := _segments[index]
		var reveal_start := (
			0.16 * float(index) / float(maxi(1, _segments.size() - 1))
		)
		var reveal := smoothstep(reveal_start, reveal_start + 0.11, progress)
		var decay := 1.0 - smoothstep(0.7, 1.0, progress)
		var pulse := 0.92 + 0.08 * sin(progress * pulse_speed * TAU + float(index) * 0.83)
		var alpha := clampf(reveal * decay * pulse, 0.0, 1.0)
		var core := segment.get_node("Core") as Node2D
		var edge := segment.get_node("Edge") as Node2D
		var accent := segment.get_node("Accent") as Node2D
		var debris := segment.get_node("Debris") as Node2D
		core.modulate.a = alpha * 0.9
		edge.modulate.a = alpha
		accent.modulate.a = alpha * (0.72 + 0.28 * pulse)
		debris.modulate.a = alpha * 0.86
		match _topology:
			"burning_scar":
				accent.scale = (
					accent.get_meta("base_scale", Vector2.ONE) as Vector2
				) * Vector2(1.0, 0.82 + pulse * 0.24)
				debris.position.y = -absf(sin(progress * TAU * 2.0 + index)) * 5.0
			"frozen_rift":
				var settle := 0.94 + reveal * 0.06
				segment.scale = Vector2(settle, settle)
				accent.modulate.a *= 0.82 + 0.18 * sin(progress * TAU + index)
			_:
				var breathe := 0.96 + 0.05 * sin(progress * pulse_speed * TAU + index)
				segment.scale = Vector2(1.0 + (breathe - 1.0) * 0.45, breathe)
				debris.position.y = -sin(progress * TAU * 1.4 + index) * 3.0


func _set_stage(stage_name: StringName) -> void:
	if _stage_name == stage_name:
		return
	_stage_name = stage_name
	stage_changed.emit(_stage_name)


func _clear_segments() -> void:
	if not is_instance_valid(segment_owner):
		return
	for segment in _segments:
		if not is_instance_valid(segment):
			continue
		segment_owner.remove_child(segment)
		segment.queue_free()
	_segments.clear()
	_sampled_points.clear()
	underlay_edge.clear_points()
	underlay_core.clear_points()


func _finish() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	trail_finished.emit(_profile_id)
	if auto_free:
		queue_free()
	else:
		_apply_progress(1.0)
