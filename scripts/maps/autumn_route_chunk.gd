class_name AutumnRouteChunk
extends Node2D

const CHUNK_WIDTH := 440.0
const FLOOR_Y := 500.0
const GROUND_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_ground_atlas.png"
)
const PROP_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_props_atlas.png"
)
const TREE_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_trees_atlas.png"
)
const GROUND_REGION := Rect2(14, 320, 996, 174)
const PLATFORM_REGION := Rect2(24, 684, 506, 198)
const BRIDGE_REGION := Rect2(552, 704, 438, 178)
const FENCE_REGION := Rect2(850, 270, 326, 214)
const ROCK_REGION := Rect2(778, 638, 362, 280)
const SIGN_REGION := Rect2(588, 140, 242, 342)
const BUSH_REGION := Rect2(1290, 494, 474, 270)

const VARIANT_PLATFORMS := {
	"gateway": [],
	"flat": [],
	"twin_ledges": [
		{"position": Vector2(115, 412), "kind": "small"},
		{"position": Vector2(330, 372), "kind": "small"},
	],
	"high_bridge": [
		{"position": Vector2(105, 418), "kind": "small"},
		{"position": Vector2(305, 350), "kind": "bridge"},
	],
	"stepping_stones": [
		{"position": Vector2(82, 420), "kind": "small"},
		{"position": Vector2(220, 382), "kind": "small"},
		{"position": Vector2(358, 420), "kind": "small"},
	],
	"canopy_walk": [
		{"position": Vector2(125, 408), "kind": "small"},
		{"position": Vector2(320, 344), "kind": "bridge"},
	],
	"crossing": [
		{"position": Vector2(105, 368), "kind": "small"},
		{"position": Vector2(338, 412), "kind": "small"},
	],
	"upper_canopy": [
		{"position": Vector2(78, 420), "kind": "small"},
		{"position": Vector2(200, 350), "kind": "small"},
		{"position": Vector2(322, 280), "kind": "small"},
	],
	"broken_crown": [
		{"position": Vector2(92, 410), "kind": "small"},
		{"position": Vector2(235, 342), "kind": "small"},
		{"position": Vector2(370, 294), "kind": "small"},
	],
}

var variant_id := "flat"
var chunk_index := 0
var _platform_specs: Array[Dictionary] = []


func configure(next_variant_id: String, next_chunk_index: int, layout_seed: int = 0) -> void:
	variant_id = next_variant_id if VARIANT_PLATFORMS.has(next_variant_id) else "flat"
	chunk_index = next_chunk_index
	_platform_specs.clear()
	for platform_spec in VARIANT_PLATFORMS[variant_id] as Array:
		_platform_specs.append((platform_spec as Dictionary).duplicate(true))
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var mirror_layout := rng.randi_range(0, 1) == 1
	for platform_spec in _platform_specs:
		var platform_position := platform_spec["position"] as Vector2
		if mirror_layout:
			platform_position.x = CHUNK_WIDTH - platform_position.x
		platform_position += Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-7.0, 7.0))
		platform_position.x = clampf(platform_position.x, 68.0, CHUNK_WIDTH - 68.0)
		platform_spec["position"] = platform_position
	set_meta("variant_id", variant_id)
	set_meta("chunk_index", chunk_index)
	set_meta("continuous_floor", true)
	_rebuild()


func get_platform_signature() -> String:
	var parts: Array[String] = []
	for platform_spec in _platform_specs:
		var position := platform_spec["position"] as Vector2
		parts.append(
			"%s:%d:%d"
			% [String(platform_spec["kind"]), int(position.x), int(position.y)]
		)
	return ",".join(parts)


func get_platform_count() -> int:
	return _platform_specs.size()


func get_minimum_platform_y() -> float:
	var minimum_y := 999.0
	for platform_spec in _platform_specs:
		minimum_y = minf(minimum_y, (platform_spec["position"] as Vector2).y)
	return minimum_y


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_add_floor()
	_add_platforms()
	_add_dressing()
	_add_spawn_socket()


func _add_floor() -> void:
	var floor_sprite := Sprite2D.new()
	floor_sprite.name = "ContinuousFloorVisual"
	floor_sprite.position = Vector2(CHUNK_WIDTH * 0.5, FLOOR_Y)
	floor_sprite.scale = Vector2(0.5, 0.5)
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_sprite.texture = _atlas_texture(GROUND_ATLAS, GROUND_REGION)
	add_child(floor_sprite)

	var floor_body := StaticBody2D.new()
	floor_body.name = "ContinuousFloorCollision"
	add_child(floor_body)
	var floor_shape := CollisionShape2D.new()
	floor_shape.name = "FloorShape"
	floor_shape.position = Vector2(CHUNK_WIDTH * 0.5, FLOOR_Y)
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(CHUNK_WIDTH + 2.0, 80.0)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)


func _add_platforms() -> void:
	var platforms := Node2D.new()
	platforms.name = "OneWayPlatforms"
	platforms.z_index = 4
	add_child(platforms)
	for platform_index in _platform_specs.size():
		var platform_spec := _platform_specs[platform_index]
		var kind := String(platform_spec["kind"])
		var platform_position := platform_spec["position"] as Vector2
		var platform_sprite := Sprite2D.new()
		platform_sprite.name = "PlatformVisual%02d" % platform_index
		platform_sprite.position = platform_position
		platform_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		platform_sprite.texture = _atlas_texture(
			GROUND_ATLAS,
			BRIDGE_REGION if kind == "bridge" else PLATFORM_REGION
		)
		platform_sprite.scale = (
			Vector2(0.42, 0.42)
			if kind == "bridge"
			else Vector2(0.25, 0.25) if kind == "small" else Vector2(0.34, 0.34)
		)
		platforms.add_child(platform_sprite)

		var platform_body := StaticBody2D.new()
		platform_body.name = "PlatformCollision%02d" % platform_index
		platforms.add_child(platform_body)
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
		platform_body.add_child(collision)


func _add_dressing() -> void:
	var dressing := Node2D.new()
	dressing.name = "Dressing"
	dressing.z_index = 8
	add_child(dressing)
	var selector := chunk_index % 5
	match selector:
		0:
			_add_prop(dressing, "Fence", PROP_ATLAS, FENCE_REGION, Vector2(112, 440), 0.3)
			_add_prop(dressing, "Bush", TREE_ATLAS, BUSH_REGION, Vector2(340, 450), 0.24)
		1:
			_add_prop(dressing, "Rocks", PROP_ATLAS, ROCK_REGION, Vector2(330, 452), 0.2)
		2:
			_add_prop(dressing, "Sign", PROP_ATLAS, SIGN_REGION, Vector2(92, 418), 0.28)
		3:
			_add_prop(dressing, "Bush", TREE_ATLAS, BUSH_REGION, Vector2(118, 452), 0.26)
			_add_prop(dressing, "Rocks", PROP_ATLAS, ROCK_REGION, Vector2(350, 454), 0.18)
		4:
			_add_prop(dressing, "Fence", PROP_ATLAS, FENCE_REGION, Vector2(330, 440), 0.28)


func _add_spawn_socket() -> void:
	var socket := Marker2D.new()
	socket.name = "EnemySpawnSocket"
	socket.position = Vector2(CHUNK_WIDTH * 0.5, 452)
	add_child(socket)


func _add_prop(
	parent: Node2D,
	node_name: String,
	atlas: Texture2D,
	region: Rect2,
	at_position: Vector2,
	uniform_scale: float
) -> void:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.position = at_position
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _atlas_texture(atlas, region)
	parent.add_child(sprite)


func _atlas_texture(atlas: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture
