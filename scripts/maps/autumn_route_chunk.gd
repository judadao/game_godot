class_name AutumnRouteChunk
extends Node2D

const CHUNK_WIDTH := 440.0
const FLOOR_Y := 500.0
const FLOOR_SEGMENT_COUNT := 10
const FLOOR_SEGMENT_WIDTH := CHUNK_WIDTH / FLOOR_SEGMENT_COUNT
const FLOOR_CAP_DEPTH := 92.0
const FLOOR_FILL_BOTTOM := 720.0
const SOURCE_SEGMENT_WIDTH := 88.0
const SOURCE_CAP_Y := 320.0
const SOURCE_CAP_HEIGHT := 112.0
const SOURCE_FILL_Y := 420.0
const SOURCE_FILL_HEIGHT := 64.0
const FILL_TILE_DEPTH := 32.0
const GROUND_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_ground_atlas.png"
)
const PLATFORM_REGION := Rect2(24, 684, 506, 198)
const BRIDGE_REGION := Rect2(552, 704, 438, 178)

var variant_id := "open"
var chunk_index := 0
var _floor_profile_id := "level"
var _floor_segments: Array[Dictionary] = []
var _platform_specs: Array[Dictionary] = []


func configure_layout(layout: Dictionary, next_chunk_index: int) -> void:
	chunk_index = next_chunk_index
	variant_id = String(layout.get("platform_assembly", "open"))
	_floor_profile_id = String(layout.get("floor_profile", "level"))
	_floor_segments.assign(layout.get("floor_segments", []))
	_platform_specs.assign(layout.get("platforms", []))
	set_meta("variant_id", variant_id)
	set_meta("floor_profile", _floor_profile_id)
	set_meta("chunk_index", chunk_index)
	set_meta("continuous_floor", true)
	_rebuild()


func get_platform_signature() -> String:
	var parts: Array[String] = []
	for spec in _platform_specs:
		var position := spec["position"] as Vector2
		parts.append("%s:%d:%d" % [String(spec["kind"]), int(position.x), int(position.y)])
	return ",".join(parts)


func get_floor_signature() -> String:
	var parts: Array[String] = []
	for segment in _floor_segments:
		parts.append(
			"%d:%s" % [int(float(segment["top_y"])), String(segment["material"])]
		)
	return ",".join(parts)


func get_floor_segment_count() -> int:
	return _floor_segments.size()


func get_platform_count() -> int:
	return _platform_specs.size()


func get_minimum_platform_y() -> float:
	var minimum_y := 999.0
	for spec in _platform_specs:
		minimum_y = minf(minimum_y, (spec["position"] as Vector2).y - 24.0)
	return minimum_y


func get_floor_y_at(local_x: float) -> float:
	if _floor_segments.is_empty():
		return FLOOR_Y - 40.0
	var index := clampi(floori(local_x / FLOOR_SEGMENT_WIDTH), 0, _floor_segments.size() - 1)
	return float(_floor_segments[index]["top_y"])


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_add_floor_segments()
	_add_platforms()
	_add_spawn_socket()


func _add_floor_segments() -> void:
	var floor_root := Node2D.new()
	floor_root.name = "ModularFloor"
	add_child(floor_root)
	for segment_index in _floor_segments.size():
		var segment := _floor_segments[segment_index]
		var top_y := float(segment["top_y"])
		var material_variant := int(segment.get("material_variant", 0))
		var source_x := (
			42.0
			+ float(material_variant % 3) * 8.0
			+ float(segment_index) * SOURCE_SEGMENT_WIDTH
		)
		var segment_center_x := (
			(float(segment_index) + 0.5) * FLOOR_SEGMENT_WIDTH
		)
		var fill_top := top_y + FLOOR_CAP_DEPTH - 4.0
		var fill := Node2D.new()
		fill.name = "TerrainFill%02d" % segment_index
		floor_root.add_child(fill)
		var fill_tile_count := ceili(
			(FLOOR_FILL_BOTTOM - fill_top) / FILL_TILE_DEPTH
		)
		for fill_tile_index in fill_tile_count:
			var fill_tile := Sprite2D.new()
			fill_tile.name = "FillTile%02d" % fill_tile_index
			fill_tile.position = Vector2(
				segment_center_x,
				fill_top
					+ FILL_TILE_DEPTH * (float(fill_tile_index) + 0.5)
			)
			fill_tile.scale = Vector2(
				(FLOOR_SEGMENT_WIDTH + 2.0) / SOURCE_SEGMENT_WIDTH,
				FILL_TILE_DEPTH / SOURCE_FILL_HEIGHT
			)
			fill_tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			fill_tile.texture = _atlas_texture(
				GROUND_ATLAS,
				Rect2(
					source_x,
					SOURCE_FILL_Y,
					SOURCE_SEGMENT_WIDTH,
					SOURCE_FILL_HEIGHT
				)
			)
			fill.add_child(fill_tile)

		var cap := Sprite2D.new()
		cap.name = "TerrainCap%02d" % segment_index
		cap.position = Vector2(
			segment_center_x,
			top_y + FLOOR_CAP_DEPTH * 0.5
		)
		cap.scale = Vector2(
			(FLOOR_SEGMENT_WIDTH + 2.0) / SOURCE_SEGMENT_WIDTH,
			FLOOR_CAP_DEPTH / SOURCE_CAP_HEIGHT
		)
		cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cap.texture = _atlas_texture(
			GROUND_ATLAS,
			Rect2(
				source_x,
				SOURCE_CAP_Y,
				SOURCE_SEGMENT_WIDTH,
				SOURCE_CAP_HEIGHT
			)
		)
		cap.z_index = 1
		floor_root.add_child(cap)

		var body := StaticBody2D.new()
		body.name = "FloorCollision%02d" % segment_index
		floor_root.add_child(body)
		var collision := CollisionShape2D.new()
		collision.name = "FloorShape"
		collision.position = Vector2(
			segment_center_x,
			top_y + (FLOOR_FILL_BOTTOM - top_y) * 0.5
		)
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(
			FLOOR_SEGMENT_WIDTH + 2.0,
			FLOOR_FILL_BOTTOM - top_y
		)
		collision.shape = rectangle
		body.add_child(collision)


func _add_platforms() -> void:
	var platforms := Node2D.new()
	platforms.name = "OneWayPlatforms"
	platforms.z_index = 4
	add_child(platforms)
	for platform_index in _platform_specs.size():
		var spec := _platform_specs[platform_index]
		var kind := String(spec["kind"])
		var platform_position := spec["position"] as Vector2
		var sprite := Sprite2D.new()
		sprite.name = "PlatformVisual%02d_%s" % [platform_index, kind]
		sprite.position = platform_position
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = _atlas_texture(
			GROUND_ATLAS,
			BRIDGE_REGION if kind == "bridge" else PLATFORM_REGION
		)
		sprite.scale = (
			Vector2(0.42, 0.42)
			if kind == "bridge"
			else Vector2(0.25, 0.25) if kind == "small" else Vector2(0.34, 0.34)
		)
		platforms.add_child(sprite)

		var body := StaticBody2D.new()
		body.name = "PlatformCollision%02d" % platform_index
		platforms.add_child(body)
		var collision := CollisionShape2D.new()
		collision.name = "OneWayShape"
		collision.position = platform_position + Vector2(0, -24)
		collision.one_way_collision = true
		collision.one_way_collision_margin = 12.0
		var rectangle := RectangleShape2D.new()
		rectangle.size = (
			Vector2(184, 22)
			if kind == "bridge"
			else Vector2(126, 18) if kind == "small" else Vector2(172, 18)
		)
		collision.shape = rectangle
		body.add_child(collision)


func _add_spawn_socket() -> void:
	var socket := Marker2D.new()
	socket.name = "EnemySpawnSocket"
	socket.position = Vector2(CHUNK_WIDTH * 0.5, get_floor_y_at(CHUNK_WIDTH * 0.5) + 10.0)
	add_child(socket)


func _atlas_texture(atlas: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture
