class_name RegionalBossArenaBuilder
extends Node2D

const AUTUMN_TERRAIN_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_ground_atlas.png"
)
const FLOOR_REGION := Rect2(14, 320, 994, 170)
const PLATFORM_REGION := Rect2(24, 684, 506, 198)
const WOOD_PLATFORM_REGION := Rect2(548, 700, 450, 150)
const ARENA_WIDTH := 1664.0
const ARENA_HEIGHT := 900.0
const FLOOR_TOP := 500.0
const FLOOR_EDGE_TRIM := 18.0
const PLATFORM_LANDING_MARGIN := 16.0

@export var platform_color := Color("4a5265")
@export var rim_color := Color("d7b96b")
@export var terrain_texture: Texture2D = AUTUMN_TERRAIN_ATLAS
@export var terrain_modulate := Color.WHITE
@export var floor_region := FLOOR_REGION
@export var platform_region := PLATFORM_REGION
@export var perimeter_boss_layout := false
@export var vary_platform_art := false
@export var layout_seed := 87031
@export_range(0.2, 1.0, 0.01) var floor_art_scale_y := 1.0
@export_range(0.2, 0.8, 0.01) var platform_art_scale_y := 0.45
@export var build_floor_art := true
@export var arena_width := ARENA_WIDTH
@export var arena_height := ARENA_HEIGHT
@export var floor_top := FLOOR_TOP
@export var portrait_boss_layout := false
@export var preserve_backdrop_aspect := false

const PLATFORM_SPECS := [
	[Vector2(300, 390), 250.0],
	[Vector2(555, 300), 220.0],
	[Vector2(810, 390), 250.0],
	[Vector2(1065, 300), 220.0],
	[Vector2(1320, 390), 250.0],
	[Vector2(730, 205), 205.0],
	[Vector2(985, 205), 205.0],
]
const PERIMETER_PLATFORM_SPECS := [
	[Vector2(832, 120), 196.0],
	[Vector2(1090, 240), 205.0],
	[Vector2(570, 315), 205.0],
	[Vector2(330, 400), 218.0],
	[Vector2(1340, 365), 218.0],
	[Vector2(520, 480), 220.0],
	[Vector2(1150, 475), 220.0],
]
const PORTRAIT_PLATFORM_SPECS := [
	[Vector2(960, 360), 420.0],
	[Vector2(1200, 540), 420.0],
	[Vector2(800, 720), 440.0],
	[Vector2(1300, 900), 440.0],
	[Vector2(600, 1080), 440.0],
	[Vector2(300, 1280), 460.0],
	[Vector2(1500, 1280), 460.0],
]


func _ready() -> void:
	_fit_backdrop()
	if build_floor_art:
		_build_floor_art()
	var platform_specs := PORTRAIT_PLATFORM_SPECS if portrait_boss_layout else (PERIMETER_PLATFORM_SPECS if perimeter_boss_layout else PLATFORM_SPECS)
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = layout_seed
	for index in platform_specs.size():
		var spec: Array = platform_specs[index]
		var platform_position := spec[0] as Vector2
		var platform_width := float(spec[1])
		if perimeter_boss_layout or portrait_boss_layout:
			var random_y := 0 if portrait_boss_layout else layout_rng.randi_range(-6, 6)
			platform_position += Vector2(layout_rng.randi_range(-14, 14), random_y)
			platform_width += float(layout_rng.randi_range(-18, 18))
		_build_platform(index, platform_position, platform_width)


func _fit_backdrop() -> void:
	var backdrop := get_node_or_null("../Backdrop") as Sprite2D
	if backdrop == null or backdrop.texture == null:
		return
	var texture_size := backdrop.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	backdrop.position = Vector2(arena_width * 0.5, arena_height * 0.5)
	if preserve_backdrop_aspect:
		var cover_scale := maxf(arena_width / texture_size.x, arena_height / texture_size.y)
		backdrop.scale = Vector2.ONE * cover_scale
	else:
		backdrop.scale = Vector2(arena_width / texture_size.x, arena_height / texture_size.y)


func _build_platform(index: int, platform_position: Vector2, width: float) -> void:
	var platform := StaticBody2D.new()
	platform.name = "JumpPlatform%02d" % (index + 1)
	platform.position = platform_position
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 20)
	collision.shape = shape
	collision.position.y = 5.0
	collision.one_way_collision = true
	collision.one_way_collision_margin = PLATFORM_LANDING_MARGIN
	platform.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -5), Vector2(width * 0.5, -5),
		Vector2(width * 0.42, 22), Vector2(-width * 0.42, 22),
	])
	visual.color = platform_color
	visual.visible = terrain_texture == null
	visual.z_index = 8
	platform.add_child(visual)
	if terrain_texture != null:
		var art := Sprite2D.new()
		art.name = "TerrainPlatformArt"
		var chosen_region := WOOD_PLATFORM_REGION if vary_platform_art and index % 3 == 1 else platform_region
		art.texture = _atlas_texture(chosen_region)
		art.position = Vector2(0, -5.0 + chosen_region.size.y * platform_art_scale_y * 0.5)
		art.scale = Vector2(width / chosen_region.size.x, platform_art_scale_y)
		art.modulate = terrain_modulate
		if vary_platform_art:
			art.flip_h = index % 2 == 1
			art.modulate *= Color(0.94 + float(index % 3) * 0.03, 0.95, 1.0, 1.0)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.z_index = 9
		platform.add_child(art)
	var rim := Line2D.new()
	rim.points = PackedVector2Array([Vector2(-width * 0.5, -5), Vector2(width * 0.5, -5)])
	rim.width = 7.0
	rim.default_color = rim_color
	rim.visible = terrain_texture == null
	rim.z_index = 10
	platform.add_child(rim)
	add_child(platform)


func _build_floor_art() -> void:
	if terrain_texture == null:
		return
	var safe_region := Rect2(
		floor_region.position + Vector2(FLOOR_EDGE_TRIM, 0.0),
		Vector2(floor_region.size.x - FLOOR_EDGE_TRIM * 2.0, floor_region.size.y)
	)
	var panel := Sprite2D.new()
	panel.name = "TerrainFloorPanel01"
	panel.texture = _atlas_texture(safe_region)
	panel.position = Vector2(arena_width * 0.5, floor_top + safe_region.size.y * floor_art_scale_y * 0.5)
	panel.scale = Vector2(arena_width / safe_region.size.x, floor_art_scale_y)
	panel.modulate = terrain_modulate
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.z_index = 6
	add_child(panel)


func _atlas_texture(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = terrain_texture
	texture.region = region
	return texture
