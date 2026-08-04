class_name RegionalBossArenaBuilder
extends Node2D

const AUTUMN_TERRAIN_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_ground_atlas.png"
)
const FLOOR_REGION := Rect2(14, 320, 994, 170)
const PLATFORM_REGION := Rect2(24, 684, 506, 198)
const ARENA_WIDTH := 1664.0
const FLOOR_TOP := 500.0

@export var platform_color := Color("4a5265")
@export var rim_color := Color("d7b96b")
@export var terrain_texture: Texture2D = AUTUMN_TERRAIN_ATLAS
@export var terrain_modulate := Color.WHITE
@export var floor_region := FLOOR_REGION
@export var platform_region := PLATFORM_REGION

const PLATFORM_SPECS := [
	[Vector2(290, 390), 260.0],
	[Vector2(650, 290), 230.0],
	[Vector2(1014, 390), 260.0],
	[Vector2(1370, 275), 230.0],
	[Vector2(832, 185), 220.0],
	[Vector2(430, 110), 180.0],
	[Vector2(1230, 105), 180.0],
]


func _ready() -> void:
	_build_floor_art()
	for index in PLATFORM_SPECS.size():
		var spec: Array = PLATFORM_SPECS[index]
		_build_platform(index, spec[0] as Vector2, float(spec[1]))


func _build_platform(index: int, platform_position: Vector2, width: float) -> void:
	var platform := StaticBody2D.new()
	platform.name = "JumpPlatform%02d" % (index + 1)
	platform.position = platform_position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 12)
	collision.shape = shape
	collision.one_way_collision = true
	platform.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -5), Vector2(width * 0.5, -5),
		Vector2(width * 0.42, 22), Vector2(-width * 0.42, 22),
	])
	visual.color = platform_color
	visual.z_index = 8
	platform.add_child(visual)
	if terrain_texture != null:
		var art := Sprite2D.new()
		art.name = "TerrainPlatformArt"
		art.texture = _atlas_texture(platform_region)
		art.position = Vector2(0, -5.0 + platform_region.size.y * 0.225)
		art.scale = Vector2(width / platform_region.size.x, 0.45)
		art.modulate = terrain_modulate
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.z_index = 9
		platform.add_child(art)
	var rim := Line2D.new()
	rim.points = PackedVector2Array([Vector2(-width * 0.5, -5), Vector2(width * 0.5, -5)])
	rim.width = 7.0
	rim.default_color = rim_color
	rim.z_index = 10
	platform.add_child(rim)
	add_child(platform)


func _build_floor_art() -> void:
	if terrain_texture == null:
		return
	var panel_width := ARENA_WIDTH * 0.5
	for index in 2:
		var panel := Sprite2D.new()
		panel.name = "TerrainFloorPanel%02d" % (index + 1)
		panel.texture = _atlas_texture(floor_region)
		panel.position = Vector2(
			panel_width * (float(index) + 0.5),
			FLOOR_TOP + floor_region.size.y * 0.5
		)
		panel.scale = Vector2(panel_width / floor_region.size.x, 1.0)
		panel.modulate = terrain_modulate
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.z_index = 6
		add_child(panel)


func _atlas_texture(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = terrain_texture
	texture.region = region
	return texture
