class_name AutumnRouteGenerator
extends Node2D

const CHUNK_WIDTH := AutumnRouteChunk.CHUNK_WIDTH
const VARIANT_IDS: Array[String] = [
	"flat",
	"twin_ledges",
	"high_bridge",
	"stepping_stones",
	"canopy_walk",
	"crossing",
]
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
	var offset := rng.randi_range(0, VARIANT_IDS.size() - 1)
	for chunk_index in chunk_count:
		var variant_id := "gateway"
		if chunk_index > 0 and chunk_index < chunk_count - 1:
			var jitter := rng.randi_range(0, VARIANT_IDS.size() - 1)
			variant_id = VARIANT_IDS[(chunk_index + offset + jitter) % VARIANT_IDS.size()]
		var chunk := chunk_scene.instantiate() as Node2D
		chunk.name = "RouteChunk%02d_%s" % [chunk_index, variant_id]
		chunk.position = Vector2(float(chunk_index) * CHUNK_WIDTH, 0)
		add_child(chunk)
		if chunk.has_method("configure"):
			chunk.call("configure", variant_id, chunk_index)
		var left := float(chunk_index) * CHUNK_WIDTH
		_manifest.append({
			"index": chunk_index,
			"variant": variant_id,
			"left": left,
			"right": left + CHUNK_WIDTH,
			"continuous_floor": true,
			"platform_signature": (
				String(chunk.call("get_platform_signature"))
				if chunk.has_method("get_platform_signature")
				else ""
			),
		})
	_rebuild_backdrop()


func get_manifest() -> Array[Dictionary]:
	return _manifest.duplicate(true)


func get_route_fingerprint() -> String:
	var parts: Array[String] = []
	for entry in _manifest:
		parts.append(
			"%s[%s]"
			% [String(entry["variant"]), String(entry["platform_signature"])]
		)
	return "|".join(parts)


func get_route_width() -> float:
	return float(chunk_count) * CHUNK_WIDTH


func get_active_seed() -> int:
	return _active_seed


func get_enemy_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for chunk_index in range(2, chunk_count - 2):
		positions.append(Vector2((float(chunk_index) + 0.5) * CHUNK_WIDTH, 452))
	return positions


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
	for chunk_index in range(1, chunk_count, 2):
		var tree := Sprite2D.new()
		tree.name = "RearTree%02d" % chunk_index
		tree.position = Vector2((float(chunk_index) + 0.5) * CHUNK_WIDTH, 408)
		tree.scale = Vector2(0.3, 0.3)
		tree.modulate = Color(0.62, 0.49, 0.37, 0.7)
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var texture := AtlasTexture.new()
		texture.atlas = TREE_ATLAS
		texture.region = tree_regions[chunk_index % tree_regions.size()]
		tree.texture = texture
		backdrop.add_child(tree)
