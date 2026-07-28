class_name AutumnRouteGenerator
extends Node2D

const CATALOG := preload("res://scripts/maps/autumn_route_catalog.gd")
const CHUNK_WIDTH := AutumnRouteChunk.CHUNK_WIDTH
const FLOOR_SEGMENT_WIDTH := AutumnRouteChunk.FLOOR_SEGMENT_WIDTH
const BASE_FLOOR_TOP := 460.0
const MIN_FLOOR_TOP := 360.0
const MAX_FLOOR_TOP := 470.0
const PANORAMA := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_forest_background.png"
)
const TREE_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_trees_atlas.png"
)
const OAK_REGION := Rect2(34, 122, 650, 632)
const MAPLE_REGION := Rect2(700, 64, 260, 690)
const AMBER_TREE_REGION := Rect2(964, 166, 370, 590)

@export var chunk_scene: PackedScene
@export_range(24, 64, 1) var chunk_count := 24
@export var preview_seed := 20260728

var _manifest: Array[Dictionary] = []
var _active_seed := 0


func _ready() -> void:
	var initial_seed := (
		preview_seed
		if Engine.is_editor_hint()
		else int(Time.get_ticks_usec() ^ get_instance_id())
	)
	regenerate(initial_seed)


func regenerate(seed_value: int) -> void:
	if chunk_scene == null:
		push_error("Autumn route generator requires a chunk scene.")
		return
	_clear_generated_children()
	_active_seed = seed_value
	set_meta("route_seed", _active_seed)
	_manifest.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var platform_order := CATALOG.PLATFORM_ASSEMBLY_ORDER.duplicate()
	_shuffle_strings(platform_order, rng)
	var floor_plan := _build_floor_profile_plan(rng)
	var platform_plan := _build_platform_plan(platform_order, rng)
	var current_floor_top := BASE_FLOOR_TOP
	for chunk_index in chunk_count:
		var floor_profile_id := floor_plan[chunk_index]
		var floor_offsets := CATALOG.floor_profile(floor_profile_id)
		var floor_segments := _build_floor_segments(
			floor_offsets,
			current_floor_top,
			chunk_index,
			rng
		)
		var floor_exit_y := float(floor_segments[-1]["top_y"])
		var floor_range := _floor_range(floor_segments)
		var assembly_id := platform_plan[chunk_index]
		var platforms := _build_platforms(
			CATALOG.platform_assembly(assembly_id),
			floor_segments,
			rng
		)
		var layout := {
			"floor_profile": floor_profile_id,
			"floor_segments": floor_segments,
			"platform_assembly": assembly_id,
			"platforms": platforms,
		}
		var chunk := chunk_scene.instantiate() as Node2D
		chunk.name = "RouteChunk%02d_%s_%s" % [
			chunk_index,
			floor_profile_id,
			assembly_id,
		]
		chunk.position = Vector2(float(chunk_index) * CHUNK_WIDTH, 0)
		add_child(chunk)
		chunk.call("configure_layout", layout, chunk_index)
		var left := float(chunk_index) * CHUNK_WIDTH
		_manifest.append({
			"index": chunk_index,
			"variant": assembly_id,
			"floor_profile": floor_profile_id,
			"left": left,
			"right": left + CHUNK_WIDTH,
			"continuous_floor": true,
			"floor_entry_y": current_floor_top,
			"floor_exit_y": floor_exit_y,
			"minimum_floor_y": floor_range.x,
			"maximum_floor_y": floor_range.y,
			"maximum_floor_step": _maximum_floor_step(floor_segments),
			"visual_fill_bottom": AutumnRouteChunk.FLOOR_FILL_BOTTOM,
			"floor_segment_count": int(chunk.call("get_floor_segment_count")),
			"floor_signature": String(chunk.call("get_floor_signature")),
			"platform_signature": String(chunk.call("get_platform_signature")),
			"platform_count": int(chunk.call("get_platform_count")),
			"minimum_platform_y": float(chunk.call("get_minimum_platform_y")),
		})
		current_floor_top = floor_exit_y
	_rebuild_backdrop()


func get_manifest() -> Array[Dictionary]:
	return _manifest.duplicate(true)


func get_route_fingerprint() -> String:
	var parts: Array[String] = []
	for entry in _manifest:
		parts.append(
			"%s[%s](%s)"
			% [
				String(entry["floor_profile"]),
				String(entry["floor_signature"]),
				String(entry["platform_signature"]),
			]
		)
	return "|".join(parts)


func get_route_width() -> float:
	return float(chunk_count) * CHUNK_WIDTH


func get_active_seed() -> int:
	return _active_seed


func get_floor_y_at(world_x: float) -> float:
	if _manifest.is_empty():
		return BASE_FLOOR_TOP
	var chunk_index := clampi(floori(world_x / CHUNK_WIDTH), 0, _manifest.size() - 1)
	var chunk := get_child(chunk_index) as Node
	return float(chunk.call("get_floor_y_at", world_x - float(chunk_index) * CHUNK_WIDTH))


func get_enemy_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for chunk_index in range(2, chunk_count - 2):
		var x := (float(chunk_index) + 0.5) * CHUNK_WIDTH
		positions.append(Vector2(x, get_floor_y_at(x) + 10.0))
	return positions


func _build_floor_profile_plan(rng: RandomNumberGenerator) -> Array[String]:
	var plan: Array[String] = []
	plan.resize(chunk_count)
	plan.fill("level")
	var relief_flags: Array[bool] = []
	relief_flags.resize(chunk_count)
	relief_flags.fill(false)
	var transition_indices: Array[int] = []
	var previous_index := 0
	for transition_number in 4:
		var remaining := 3 - transition_number
		var candidate := int(round(
			float(chunk_count - 1) * (float(transition_number + 1) / 5.0)
		)) + rng.randi_range(-1, 1)
		candidate = maxi(previous_index + 3, candidate)
		candidate = mini(
			candidate,
			chunk_count - 2 - remaining * 3
		)
		transition_indices.append(candidate)
		relief_flags[candidate] = true
		previous_index = candidate
	plan[transition_indices[0]] = "rise_48"
	plan[transition_indices[1]] = "rise_48"
	plan[transition_indices[2]] = "fall_48"
	plan[transition_indices[3]] = "fall_48"

	var local_candidates: Array[int] = []
	for chunk_index in range(1, chunk_count - 1):
		if not relief_flags[chunk_index]:
			local_candidates.append(chunk_index)
	_shuffle_ints(local_candidates, rng)
	var local_target := maxi(4, int(round(float(chunk_count - 2) * 0.36)))
	var selected_locals := 0
	for candidate in local_candidates:
		if selected_locals >= local_target:
			break
		if _would_form_three_relief(relief_flags, candidate):
			continue
		relief_flags[candidate] = true
		selected_locals += 1

	var current_floor_top := BASE_FLOOR_TOP
	for chunk_index in range(1, chunk_count - 1):
		var profile_id := plan[chunk_index]
		if profile_id == "level" and relief_flags[chunk_index]:
			profile_id = _pick_local_profile(current_floor_top, rng)
			plan[chunk_index] = profile_id
		current_floor_top += CATALOG.floor_profile(profile_id)[-1]
	return plan


func _build_platform_plan(
	platform_order: Array[String],
	rng: RandomNumberGenerator
) -> Array[String]:
	var plan: Array[String] = []
	plan.resize(chunk_count)
	plan.fill("open")
	var chunk_index := 1
	var use_platforms := true
	var platform_cursor := rng.randi_range(0, platform_order.size() - 1)
	while chunk_index < chunk_count - 1:
		var run_length := rng.randi_range(1, 2)
		for _run_index in run_length:
			if chunk_index >= chunk_count - 1:
				break
			if use_platforms:
				plan[chunk_index] = platform_order[
					platform_cursor % platform_order.size()
				]
				platform_cursor += 1
			chunk_index += 1
		use_platforms = not use_platforms
	if (
		plan[chunk_count - 2] == "open"
		and plan[chunk_count - 3] == "open"
	):
		plan[chunk_count - 2] = platform_order[
			platform_cursor % platform_order.size()
		]
	return plan


func _pick_local_profile(
	current_floor_top: float,
	rng: RandomNumberGenerator
) -> String:
	var candidates: Array[String]
	if current_floor_top <= 370.0:
		candidates = ["basin_48"]
	elif current_floor_top >= 450.0:
		candidates = ["hill_48", "mesa_64", "shallow_roll"]
	else:
		candidates = ["hill_48", "basin_48", "shallow_roll"]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _would_form_three_relief(flags: Array[bool], candidate: int) -> bool:
	for start_index in range(maxi(0, candidate - 2), mini(candidate, flags.size() - 3) + 1):
		var relief_count := 0
		for flag_index in range(start_index, start_index + 3):
			if flag_index == candidate or flags[flag_index]:
				relief_count += 1
		if relief_count == 3:
			return true
	return false


func _build_floor_segments(
	offsets: PackedFloat32Array,
	entry_y: float,
	chunk_index: int,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var material_seed := rng.randi_range(0, 2)
	for segment_index in offsets.size():
		segments.append({
			"top_y": entry_y + offsets[segment_index],
			"material": "autumn_earth",
			"material_variant": (chunk_index + material_seed) % 3,
		})
	return segments


func _floor_range(floor_segments: Array[Dictionary]) -> Vector2:
	var minimum_y := MAX_FLOOR_TOP
	var maximum_y := MIN_FLOOR_TOP
	for segment in floor_segments:
		var top_y := float(segment["top_y"])
		minimum_y = minf(minimum_y, top_y)
		maximum_y = maxf(maximum_y, top_y)
	return Vector2(minimum_y, maximum_y)


func _maximum_floor_step(floor_segments: Array[Dictionary]) -> float:
	var maximum_step := 0.0
	for segment_index in range(1, floor_segments.size()):
		maximum_step = maxf(
			maximum_step,
			absf(
				float(floor_segments[segment_index]["top_y"])
				- float(floor_segments[segment_index - 1]["top_y"])
			)
		)
	return maximum_step


func _build_platforms(
	templates: Array[Dictionary],
	floor_segments: Array[Dictionary],
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var platforms: Array[Dictionary] = []
	var mirror := rng.randi_range(0, 1) == 1
	for template in templates:
		var x := float(template["x"])
		if mirror:
			x = CHUNK_WIDTH - x
		x = clampf(x + rng.randf_range(-12.0, 12.0), 66.0, CHUNK_WIDTH - 66.0)
		var floor_index := clampi(
			floori(x / FLOOR_SEGMENT_WIDTH),
			0,
			floor_segments.size() - 1
		)
		var platform_top := (
			float(floor_segments[floor_index]["top_y"])
			- float(template["lift"])
		)
		platforms.append({
			"position": Vector2(x, platform_top + 24.0 + rng.randf_range(-4.0, 4.0)),
			"kind": String(template["kind"]),
		})
	platforms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["position"] as Vector2).x < (b["position"] as Vector2).x
	)
	return platforms


func _shuffle_strings(values: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _clear_generated_children() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _rebuild_backdrop() -> void:
	var backdrop := get_node_or_null("../GeneratedBackdrop") as Node2D
	if backdrop == null:
		return
	for child in backdrop.get_children():
		backdrop.remove_child(child)
		child.free()
	var route_width := get_route_width()
	var sky := ColorRect.new()
	sky.name = "SkyFill"
	sky.offset_right = route_width
	sky.offset_bottom = 540
	sky.color = Color(0.36, 0.69, 0.82, 1)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(sky)
	var panorama_width := float(PANORAMA.get_width()) * 0.75
	var panorama_count := ceili(route_width / panorama_width) + 1
	for panorama_index in panorama_count:
		var panorama := Sprite2D.new()
		panorama.name = "Panorama%02d" % panorama_index
		panorama.position = Vector2((float(panorama_index) + 0.5) * panorama_width, 270)
		panorama.scale = Vector2(-0.75 if panorama_index % 2 == 1 else 0.75, 0.75)
		panorama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panorama.texture = PANORAMA
		backdrop.add_child(panorama)
	var tree_regions := [OAK_REGION, MAPLE_REGION, AMBER_TREE_REGION]
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = _active_seed ^ 0x5F3759DF
	for chunk_index in range(1, chunk_count):
		var tree := Sprite2D.new()
		tree.name = "RearTree%02d" % chunk_index
		tree.position = Vector2(
			(float(chunk_index) + tree_rng.randf_range(0.22, 0.78)) * CHUNK_WIDTH,
			tree_rng.randf_range(398.0, 430.0)
		)
		var tree_scale := tree_rng.randf_range(0.28, 0.41)
		tree.scale = Vector2(tree_scale, tree_scale)
		tree.modulate = Color(0.62, 0.49, 0.37, tree_rng.randf_range(0.55, 0.78))
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var texture := AtlasTexture.new()
		texture.atlas = TREE_ATLAS
		texture.region = tree_regions[chunk_index % tree_regions.size()]
		tree.texture = texture
		backdrop.add_child(tree)
