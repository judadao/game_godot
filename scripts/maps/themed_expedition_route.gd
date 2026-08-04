class_name ThemedExpeditionRoute
extends Node2D

const MAP_WIDTH := 10560.0
const MAP_HEIGHT := 720.0
const CHUNK_COUNT := 24
const CHUNK_WIDTH := MAP_WIDTH / CHUNK_COUNT
const BACKDROP_SPAN := 1280.0
const TERRAIN_PANEL_WIDTH := 1280.0
const FLOOR_TOP := 460.0
const FLOOR_DEPTH := MAP_HEIGHT - FLOOR_TOP
const AUTUMN_TERRAIN_ATLAS := preload(
	"res://assets/environments/autumn_town_style/generated/autumn_ground_atlas.png"
)
const AUTUMN_FLOOR_REGION := Rect2(14, 320, 994, 170)
const AUTUMN_PLATFORM_REGION := Rect2(24, 684, 506, 198)
const CRYSTAL_FLOOR_REGION := Rect2(100, 126, 1338, 132)
const CRYSTAL_PLATFORM_SHORT_REGION := Rect2(105, 345, 258, 135)
const CRYSTAL_PLATFORM_MEDIUM_REGION := Rect2(438, 345, 356, 135)
const CRYSTAL_PLATFORM_LONG_REGION := Rect2(870, 340, 580, 145)
const CRYSTAL_ACCENT_REGIONS: Array[Rect2] = [
	Rect2(270, 810, 160, 145),
	Rect2(530, 785, 175, 175),
	Rect2(795, 778, 180, 180),
	Rect2(1070, 830, 200, 125),
]

@export var variant_id: StringName = &"crystal"
@export var background_texture: Texture2D
@export_enum(
	"autumn", "crystal", "hell_autumn", "heaven_autumn",
	"hell", "disorder_hell", "heaven"
) var terrain_style := "autumn"
@export var terrain_atlas_texture: Texture2D = AUTUMN_TERRAIN_ATLAS
@export var terrain_modulate := Color.WHITE
@export var ground_color := Color("26324b")
@export var ground_highlight := Color("64749a")
@export var platform_color := Color("3d4d70")
@export var accent_color := Color("63d7ff")


func _ready() -> void:
	get_parent().set_meta("expedition_variant_id", variant_id)
	_build_backdrop()
	_build_floor()
	_build_chunks()


func get_floor_y_at(_world_x: float) -> float:
	return FLOOR_TOP


func _build_backdrop() -> void:
	var backdrop := Node2D.new()
	backdrop.name = "ThemeBackdrop"
	backdrop.z_index = -100
	add_child(backdrop)
	if background_texture == null:
		return
	var texture_size := background_texture.get_size()
	var scale_factor := Vector2(
		BACKDROP_SPAN / maxf(1.0, texture_size.x),
		MAP_HEIGHT / maxf(1.0, texture_size.y)
	)
	var panel_count := ceili(MAP_WIDTH / BACKDROP_SPAN) + 1
	for panel_index in panel_count:
		var panel := Sprite2D.new()
		panel.name = "BackdropPanel%02d" % (panel_index + 1)
		panel.texture = background_texture
		panel.position = Vector2(panel_index * BACKDROP_SPAN + BACKDROP_SPAN * 0.5, MAP_HEIGHT * 0.5)
		panel.scale = scale_factor
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.flip_h = panel_index % 2 == 1
		backdrop.add_child(panel)


func _build_floor() -> void:
	# Keep a solid authored floor behind the modular art so missing imports can
	# never turn the route into a visually empty collision plane.
	var floor_visual := Polygon2D.new()
	floor_visual.name = "RouteFloorVisual"
	floor_visual.polygon = PackedVector2Array([
		Vector2(0, FLOOR_TOP), Vector2(MAP_WIDTH, FLOOR_TOP),
		Vector2(MAP_WIDTH, MAP_HEIGHT), Vector2(0, MAP_HEIGHT),
	])
	floor_visual.color = ground_color
	floor_visual.z_index = 3
	add_child(floor_visual)
	if terrain_atlas_texture != null:
		_build_floor_art()
	var rim := Line2D.new()
	rim.name = "RouteFloorRim"
	rim.points = PackedVector2Array([Vector2(0, FLOOR_TOP), Vector2(MAP_WIDTH, FLOOR_TOP)])
	rim.width = 12.0
	rim.default_color = ground_highlight
	rim.z_index = 7
	add_child(rim)
	var body := StaticBody2D.new()
	body.name = "RouteFloorCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(MAP_WIDTH, FLOOR_DEPTH)
	collision.shape = shape
	collision.position = Vector2(MAP_WIDTH * 0.5, FLOOR_TOP + FLOOR_DEPTH * 0.5)
	body.add_child(collision)
	add_child(body)


func _build_floor_art() -> void:
	var floor_region := _floor_region()
	var floor_texture := _create_atlas_texture(floor_region)
	var panel_count := ceili(MAP_WIDTH / TERRAIN_PANEL_WIDTH)
	for panel_index in panel_count:
		var panel := Sprite2D.new()
		panel.name = "TerrainFloorPanel%02d" % (panel_index + 1)
		panel.texture = floor_texture
		panel.centered = true
		panel.position = Vector2(
			panel_index * TERRAIN_PANEL_WIDTH + TERRAIN_PANEL_WIDTH * 0.5,
			FLOOR_TOP + floor_region.size.y * 0.5
		)
		panel.scale = Vector2(TERRAIN_PANEL_WIDTH / floor_region.size.x, 1.0)
		panel.modulate = terrain_modulate
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.z_index = 6
		add_child(panel)


func _build_chunks() -> void:
	for chunk_index in CHUNK_COUNT:
		var chunk := Node2D.new()
		chunk.name = "RouteChunk%02d" % (chunk_index + 1)
		chunk.position.x = chunk_index * CHUNK_WIDTH
		chunk.set_meta("chunk_index", chunk_index)
		chunk.set_meta("variant_id", variant_id)
		add_child(chunk)
		if chunk_index in [0, 23]:
			continue
		var platform_y := 326.0 - float((chunk_index * 47) % 3) * 52.0
		var platform_width := 150.0 + float((chunk_index * 31) % 3) * 42.0
		_build_platform(chunk, Vector2(CHUNK_WIDTH * 0.5, platform_y), platform_width)
		if chunk_index % 4 == 2:
			_build_platform(chunk, Vector2(CHUNK_WIDTH * 0.82, platform_y - 118.0), 116.0)
		if chunk_index % 3 == 1:
			_build_accent(chunk, Vector2(CHUNK_WIDTH * 0.22, FLOOR_TOP - 36.0))


func _build_platform(parent: Node2D, local_position: Vector2, width: float) -> void:
	var visual := Polygon2D.new()
	visual.position = local_position
	visual.polygon = PackedVector2Array([
		Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0),
		Vector2(width * 0.42, 24), Vector2(-width * 0.42, 24),
	])
	visual.color = platform_color
	visual.z_index = 7
	parent.add_child(visual)
	if terrain_atlas_texture != null:
		var region := _platform_region_for_width(width)
		var terrain := Sprite2D.new()
		terrain.name = "TerrainPlatformArt"
		terrain.texture = _create_atlas_texture(region)
		terrain.position = local_position + Vector2(0, region.size.y * 0.375)
		terrain.scale = Vector2(width / region.size.x, 0.75)
		terrain.modulate = terrain_modulate
		terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		terrain.z_index = 9
		parent.add_child(terrain)
	var rim := Line2D.new()
	rim.position = local_position
	rim.points = PackedVector2Array([Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0)])
	rim.width = 7.0
	rim.default_color = ground_highlight
	rim.z_index = 10
	parent.add_child(rim)
	var body := StaticBody2D.new()
	body.position = local_position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 10)
	collision.shape = shape
	collision.one_way_collision = true
	body.add_child(collision)
	parent.add_child(body)


func _build_accent(parent: Node2D, local_position: Vector2) -> void:
	if terrain_atlas_texture != null:
		var accent_regions := _accent_regions()
		var region_index := parent.get_index() % accent_regions.size()
		var region := accent_regions[region_index]
		var crystal := Sprite2D.new()
		crystal.name = "CrystalClusterArt"
		crystal.texture = _create_atlas_texture(region)
		crystal.position = local_position - Vector2(0, region.size.y * 0.22)
		crystal.scale = Vector2.ONE * 0.44
		crystal.modulate = terrain_modulate
		crystal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		crystal.z_index = 11
		parent.add_child(crystal)
		return
	var accent := Polygon2D.new()
	accent.position = local_position
	accent.polygon = PackedVector2Array([
		Vector2(-12, 0), Vector2(0, -38), Vector2(12, 0), Vector2(0, 16),
	])
	accent.color = accent_color
	accent.z_index = 10
	parent.add_child(accent)


func _platform_region_for_width(width: float) -> Rect2:
	var regions := _platform_regions()
	if width <= 145.0:
		return regions[0]
	if width <= 205.0:
		return regions[1]
	return regions[2]


func _floor_region() -> Rect2:
	match terrain_style:
		"crystal":
			return CRYSTAL_FLOOR_REGION
		"hell_autumn":
			return Rect2(20, 76, 1496, 100)
		"heaven_autumn":
			return Rect2(32, 92, 1112, 124)
		"hell":
			return Rect2(8, 176, 1008, 140)
		"disorder_hell":
			return Rect2(20, 104, 1496, 96)
		"heaven":
			return Rect2(28, 256, 968, 116)
		_:
			return AUTUMN_FLOOR_REGION


func _platform_regions() -> Array[Rect2]:
	match terrain_style:
		"crystal":
			return [
				CRYSTAL_PLATFORM_SHORT_REGION,
				CRYSTAL_PLATFORM_MEDIUM_REGION,
				CRYSTAL_PLATFORM_LONG_REGION,
			]
		"hell_autumn":
			return [Rect2(488, 240, 388, 92), Rect2(420, 368, 572, 92), Rect2(296, 500, 860, 96)]
		"heaven_autumn":
			return [Rect2(24, 336, 196, 172), Rect2(260, 336, 328, 140), Rect2(636, 336, 520, 220)]
		"hell":
			return [Rect2(72, 428, 272, 120), Rect2(416, 428, 536, 112), Rect2(40, 640, 948, 128)]
		"disorder_hell":
			return [Rect2(84, 336, 264, 100), Rect2(432, 336, 336, 96), Rect2(844, 336, 604, 96)]
		"heaven":
			return [Rect2(20, 532, 204, 120), Rect2(264, 532, 296, 108), Rect2(604, 532, 400, 112)]
		_:
			return [AUTUMN_PLATFORM_REGION, AUTUMN_PLATFORM_REGION, AUTUMN_PLATFORM_REGION]


func _accent_regions() -> Array[Rect2]:
	match terrain_style:
		"hell_autumn":
			return [Rect2(184, 900, 152, 52), Rect2(420, 856, 252, 104), Rect2(788, 868, 204, 88), Rect2(1080, 892, 144, 68)]
		"heaven_autumn":
			return [Rect2(144, 1152, 144, 72), Rect2(384, 1104, 152, 148), Rect2(616, 1108, 184, 128), Rect2(896, 1100, 120, 156)]
		"hell":
			return [Rect2(76, 1256, 188, 168), Rect2(312, 1312, 156, 112), Rect2(524, 1300, 140, 124), Rect2(716, 1316, 224, 116)]
		"disorder_hell":
			return [Rect2(188, 752, 168, 188), Rect2(468, 776, 212, 156), Rect2(828, 788, 124, 108), Rect2(1096, 852, 196, 88)]
		"heaven":
			return [Rect2(124, 1088, 108, 184), Rect2(312, 1100, 148, 172), Rect2(548, 1164, 148, 104), Rect2(792, 1088, 124, 188)]
		_:
			return CRYSTAL_ACCENT_REGIONS


func _create_atlas_texture(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = terrain_atlas_texture
	texture.region = region
	return texture
