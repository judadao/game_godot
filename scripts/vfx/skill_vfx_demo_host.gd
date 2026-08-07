class_name SkillVFXDemoHost
extends Node2D

const RECIPE_CATALOG_SCRIPT := preload("res://scripts/vfx/skill_vfx_recipe_catalog.gd")

@export var recipe_id := "sword_rain"
@export_range(1, 3, 1) var tier_rank := 2
@export var blessing_element := ""
@export_range(0.5, 5.0, 0.1) var cycle_duration := 2.4

@onready var composer: SkillVFXComposer2D = $SkillVFXComposer2D
@onready var core_root: Node2D = $CoreRoot

var _catalog: RefCounted = RECIPE_CATALOG_SCRIPT.new()
var _recipe: Dictionary = {}
var _cores: Array[Sprite2D] = []
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not bool(_catalog.call("load_catalog")):
		set_process(false)
		return
	_recipe = _catalog.call("get_recipe", recipe_id) as Dictionary
	if _recipe.is_empty():
		push_error("Unknown Skill VFX demo recipe: %s" % recipe_id)
		set_process(false)
		return
	_build_cores()
	_configure_cycle()


func _process(delta: float) -> void:
	var previous := _elapsed
	_elapsed = fposmod(_elapsed + delta, cycle_duration)
	if _elapsed < previous:
		_configure_cycle()
	var progress := _elapsed / cycle_duration
	var source := _vector_from_recipe("source")
	var target := _vector_from_recipe("target")
	var core_positions: Array[Vector2] = []
	for index in _cores.size():
		var sprite := _cores[index]
		var stagger := float(index) * 0.055
		var travel := clampf((progress - stagger) / maxf(0.1, 0.7 - stagger), 0.0, 1.0)
		var lane := float(index) - float(_cores.size() - 1) * 0.5
		var normal := (target - source).normalized().orthogonal()
		var path_target := target + normal * lane * 24.0
		var curve := normal * (float(_recipe.get("curve", 0.0)) + lane * 8.0) * sin(travel * PI)
		sprite.position = source.lerp(path_target, 1.0 - pow(1.0 - travel, 3.0)) + curve
		sprite.rotation = (path_target - source).angle()
		sprite.modulate.a = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.78, 1.0, progress))
		core_positions.append(sprite.position)
	composer.set_progress(progress, source, target, core_positions)


func _configure_cycle() -> void:
	var overlays: Array = []
	if not blessing_element.is_empty():
		overlays.append({
			"id": "%s_demo" % blessing_element,
			"element": blessing_element,
			"elements": [blessing_element],
			"level": tier_rank,
		})
	composer.configure(_recipe, tier_rank, overlays)
	composer.configure_core_sprites(_cores)


func _build_cores() -> void:
	var texture := load(String(_recipe.get("asset_path", ""))) as Texture2D
	if texture == null:
		return
	var count := 3 if tier_rank == 1 else (5 if tier_rank == 2 else 7)
	var texture_size := texture.get_size()
	var scale_value := 94.0 / maxf(1.0, maxf(texture_size.x, texture_size.y))
	for index in count:
		var sprite := Sprite2D.new()
		sprite.name = "DemoCore%02d" % (index + 1)
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.scale = Vector2.ONE * scale_value
		sprite.z_index = index % 3
		core_root.add_child(sprite)
		_cores.append(sprite)


func _vector_from_recipe(key: String) -> Vector2:
	var values := _recipe.get(key, [0.0, 0.0]) as Array
	return Vector2(float(values[0]), float(values[1])) if values.size() == 2 else Vector2.ZERO
