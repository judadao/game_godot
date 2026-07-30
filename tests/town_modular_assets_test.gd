extends SceneTree

const LAYOUT_PATH := "res://data/town_modular_layout.json"
const MODULAR_SCENE_PATH := "res://scenes/maps/town/components/TownModularVisuals.tscn"
const EXPECTED_LAYER_COUNT := 53
const EXPECTED_SOURCE_COUNT := 27
const TRANSPARENT_ALPHA_MAX := 0.001
const OPAQUE_ALPHA_MIN := 0.99

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists(LAYOUT_PATH), "Town modular layout data must exist.")
	if not FileAccess.file_exists(LAYOUT_PATH):
		_finish()
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_expect(parsed is Dictionary, "Town modular layout root must be a JSON object.")
	if not parsed is Dictionary:
		_finish()
		return

	var layout := parsed as Dictionary
	var layers_variant: Variant = layout.get("layers", [])
	_expect(layers_variant is Array, "Town modular layout layers must be an array.")
	if not layers_variant is Array:
		_finish()
		return
	var layers := layers_variant as Array
	_expect(
		layers.size() == EXPECTED_LAYER_COUNT,
		"Town modular layout must contain exactly %d selectable entries." % EXPECTED_LAYER_COUNT
	)

	var source_categories: Dictionary = {}
	for layer_variant in layers:
		_expect(layer_variant is Dictionary, "Every Town modular layer must be structured.")
		if not layer_variant is Dictionary:
			continue
		var layer := layer_variant as Dictionary
		var source := String(layer.get("source", ""))
		var category := String(layer.get("category", ""))
		_expect(not source.is_empty(), "Every Town modular layer must define a source.")
		if source.is_empty():
			continue
		var categories := source_categories.get(source, {}) as Dictionary
		categories[category] = true
		source_categories[source] = categories

	_expect(
		source_categories.size() == EXPECTED_SOURCE_COUNT,
		"Town modular layout must reference exactly %d unique source assets."
		% EXPECTED_SOURCE_COUNT
	)
	for source_variant in source_categories:
		var source := String(source_variant)
		_assert_source_asset(source, source_categories[source] as Dictionary)

	if ResourceLoader.exists(MODULAR_SCENE_PATH):
		_assert_generated_scene(layers)
	else:
		print("Town modular scene is not generated yet; scene assertions skipped.")
	_finish()


func _assert_source_asset(source: String, categories: Dictionary) -> void:
	_expect(
		ResourceLoader.exists(source),
		"Town modular source must be registered by ResourceLoader: %s" % source
	)
	if ResourceLoader.exists(source):
		var resource := load(source)
		_expect(resource is Texture2D, "Town modular source must load as Texture2D: %s" % source)

	var absolute_path := ProjectSettings.globalize_path(source)
	_expect(FileAccess.file_exists(source), "Town modular PNG must exist on disk: %s" % source)
	if not FileAccess.file_exists(source):
		return
	var image := Image.load_from_file(absolute_path)
	_expect(not image.is_empty(), "Town modular PNG must load through Image: %s" % source)
	if image.is_empty():
		return
	_expect(
		image.get_width() > 0 and image.get_height() > 0,
		"Town modular PNG dimensions must be positive: %s" % source
	)

	var alpha_profile := _scan_alpha(image)
	var has_transparent := bool(alpha_profile.get("has_transparent", false))
	var has_opaque := bool(alpha_profile.get("has_opaque", false))
	_expect(has_opaque, "Town modular PNG must contain visible opaque pixels: %s" % source)

	var is_background_only := categories.size() == 1 and categories.has("background")
	if not is_background_only:
		_expect(
			_has_transparent_corners(image),
			"Non-background Town modular PNG must have four transparent corners: %s" % source
		)
		_expect(
			has_transparent,
			"Non-background Town modular PNG must contain transparent pixels: %s" % source
		)
		return

	var is_sky := source.ends_with("/background/sky.png")
	if not is_sky and has_transparent:
		_expect(
			_has_transparent_corners(image),
			"Transparent Town background layer must have four transparent corners: %s" % source
		)


func _scan_alpha(image: Image) -> Dictionary:
	var has_transparent := false
	var has_opaque := false
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha <= TRANSPARENT_ALPHA_MAX:
				has_transparent = true
			elif alpha >= OPAQUE_ALPHA_MIN:
				has_opaque = true
			if has_transparent and has_opaque:
				return {
					"has_transparent": true,
					"has_opaque": true,
				}
	return {
		"has_transparent": has_transparent,
		"has_opaque": has_opaque,
	}


func _has_transparent_corners(image: Image) -> bool:
	var right := image.get_width() - 1
	var bottom := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a <= TRANSPARENT_ALPHA_MAX
		and image.get_pixel(right, 0).a <= TRANSPARENT_ALPHA_MAX
		and image.get_pixel(0, bottom).a <= TRANSPARENT_ALPHA_MAX
		and image.get_pixel(right, bottom).a <= TRANSPARENT_ALPHA_MAX
	)


func _assert_generated_scene(layers: Array) -> void:
	var packed := load(MODULAR_SCENE_PATH) as PackedScene
	_expect(packed != null, "TownModularVisuals must load as PackedScene when it exists.")
	if packed == null:
		return
	var instance := packed.instantiate()
	var sprites := instance.find_children("*", "Sprite2D", true, false)
	_expect(
		sprites.size() == layers.size(),
		"TownModularVisuals Sprite2D count must match all layout entries."
	)

	var expected_object_ids: Dictionary = {}
	for layer_variant in layers:
		if not layer_variant is Dictionary:
			continue
		var layer := layer_variant as Dictionary
		expected_object_ids[String(layer.get("id", ""))] = String(layer.get("source", ""))
	var actual_object_ids: Dictionary = {}
	for sprite_variant in sprites:
		var sprite := sprite_variant as Sprite2D
		var object_id := String(sprite.get_meta("object_id", ""))
		var source := String(sprite.get_meta("source_asset", ""))
		_expect(not object_id.is_empty(), "Every generated Town Sprite2D must expose object_id metadata.")
		_expect(
			expected_object_ids.has(object_id),
			"Generated Town Sprite2D object_id must exist in the layout: %s" % object_id
		)
		_expect(
			not actual_object_ids.has(object_id),
			"Generated Town Sprite2D object_id must be unique: %s" % object_id
		)
		actual_object_ids[object_id] = true
		if expected_object_ids.has(object_id):
			_expect(
				source == String(expected_object_ids[object_id]),
				"Generated Town Sprite2D source metadata must match layout: %s" % object_id
			)
		_expect(sprite.texture != null, "Generated Town Sprite2D must have a texture: %s" % object_id)
		if sprite.texture != null:
			_expect(
				sprite.texture.resource_path == source,
				"Generated Town Sprite2D texture path must match source metadata: %s" % object_id
			)
			_expect(
				ResourceLoader.exists(source) and load(source) is Texture2D,
				"Generated Town Sprite2D source must remain loadable: %s" % source
			)
	instance.free()


func _finish() -> void:
	if _failures == 0:
		print("Town modular asset contract passed.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
