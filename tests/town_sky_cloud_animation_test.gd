extends SceneTree

const SKY_SCENE := "res://scenes/maps/town/components/TownSkyLayer.tscn"
const CLOUD_SCENE := "res://scenes/maps/town/components/TownCloudLayer.tscn"
const BACKDROP_SCENE := "res://scenes/maps/town/components/TownBackdrop.tscn"
const MODULAR_SCENE := "res://scenes/maps/town/components/TownModularVisuals.tscn"
const PURE_SKY_TEXTURE := "res://assets/town/modular_v3/background/town_sky_cloud_free_v1.png"
const CLOUD_EDGE_SHADER := "res://shaders/cloud_edge_cleanup.gdshader"
const MAP_WIDTH := 1942.0
const MAP_HEIGHT := 720.0

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_sky_contract()
	_assert_cloud_contract()
	_assert_backdrop_integration()
	await _capture_review_frames()
	_finish()


func _assert_sky_contract() -> void:
	var packed := load(SKY_SCENE) as PackedScene
	_expect(packed != null, "Town must expose an authoritative independent sky scene.")
	if packed == null:
		return
	var layer := packed.instantiate() as Node2D
	root.add_child(layer)
	var sky := layer.get_node_or_null("Sky") as Sprite2D
	_expect(sky != null, "Town sky layer must own one editor-authored Sprite2D.")
	if sky != null:
		_expect(
			sky.texture != null and sky.texture.resource_path == PURE_SKY_TEXTURE,
			"Town sky must use the cloud-free tintable source."
		)
		var rendered_size := sky.texture.get_size() * sky.global_scale.abs()
		_expect(rendered_size.x >= MAP_WIDTH, "Town sky must cover the full map width.")
		_expect(rendered_size.y >= MAP_HEIGHT, "Town sky must cover the gameplay height.")
	_expect(_count_sprites(layer) == 1, "Town sky scene must not contain baked cloud sprites.")
	_expect(layer.has_method("set_sky_tint"), "Town sky must expose a future time-of-day tint API.")
	if layer.has_method("set_sky_tint") and sky != null:
		var golden_tint := Color("ffc58f")
		layer.call("set_sky_tint", golden_tint)
		_expect(sky.self_modulate.is_equal_approx(golden_tint), "Sky tint API must affect only the sky sprite.")
	layer.queue_free()


func _assert_cloud_contract() -> void:
	var packed := load(CLOUD_SCENE) as PackedScene
	_expect(packed != null, "Town must expose an authoritative independent cloud scene.")
	if packed == null:
		return
	var layer := packed.instantiate() as Node2D
	root.add_child(layer)
	var clouds: Array[Sprite2D] = []
	var speeds: Dictionary = {}
	for child in layer.get_children():
		var cloud := child as Sprite2D
		_expect(cloud != null, "%s must be an independently placeable cloud Sprite2D." % child.name)
		if cloud == null:
			continue
		clouds.append(cloud)
		var source := _source_texture_path(cloud.texture)
		_expect(
			source.begins_with("res://assets/town/background_modules/cloud_")
			and source.ends_with(".png"),
			"%s must reuse an approved transparent hand-drawn cloud." % cloud.name
		)
		var cleanup_material := cloud.material as ShaderMaterial
		_expect(
			cleanup_material != null
			and cleanup_material.shader != null
			and cleanup_material.shader.resource_path == CLOUD_EDGE_SHADER,
			"%s must remove source-edge specks, false seam tails, and chroma fringe at render time." % cloud.name
		)
		var speed := float(cloud.get_meta("drift_speed", 0.0))
		_expect(speed >= 7.0 and speed <= 18.0, "%s must drift at a calm readable speed." % cloud.name)
		speeds[speed] = true
		_expect(
			float(cloud.get_meta("sway_amplitude", -1.0)) >= 0.0
			and float(cloud.get_meta("sway_amplitude", 99.0)) <= 4.0,
			"%s vertical drift must remain subtle." % cloud.name
		)
	_expect(clouds.size() >= 7, "Town needs enough independent clouds for continuous entrances and exits.")
	_expect(speeds.size() >= 4, "Clouds must use staggered speeds instead of moving as one sheet.")
	if not clouds.is_empty():
		var sample := clouds[0]
		var before := sample.position
		layer.call("advance_clouds", 1.0)
		_expect(sample.position.x > before.x, "Cloud objects must drift horizontally over time.")
		var wrap_right := float(layer.get("wrap_right"))
		sample.position.x = wrap_right + sample.texture.get_width() * absf(sample.scale.x)
		layer.call("advance_clouds", 0.1)
		_expect(sample.position.x < 0.0, "A cloud that fully exits right must wrap off-screen to the left.")
	_expect(layer.has_method("set_cloud_tint"), "Cloud layer must expose a future lighting tint API.")
	if layer.has_method("set_cloud_tint") and not clouds.is_empty():
		var dusk_tint := Color("d9b3ad")
		layer.call("set_cloud_tint", dusk_tint)
		var tinted_material := clouds[0].material as ShaderMaterial
		_expect(
			tinted_material != null
			and (tinted_material.get_shader_parameter("cloud_tint") as Color).is_equal_approx(dusk_tint),
			"Cloud tint API must update the cleanup shader without reintroducing source chroma fringe."
		)
	layer.queue_free()


func _assert_backdrop_integration() -> void:
	var packed := load(BACKDROP_SCENE) as PackedScene
	_expect(packed != null, "Town backdrop must remain loadable.")
	if packed == null:
		return
	var backdrop := packed.instantiate() as Node2D
	root.add_child(backdrop)
	var sky := backdrop.get_node_or_null("Sky") as Node2D
	var clouds := backdrop.get_node_or_null("Clouds") as Node2D
	_expect(sky != null and sky.scene_file_path == SKY_SCENE, "TownBackdrop must link the current sky scene.")
	_expect(clouds != null and clouds.scene_file_path == CLOUD_SCENE, "TownBackdrop must link the current cloud scene.")
	_expect(sky != null and sky.visible, "Independent Town sky must be visible by default.")
	_expect(clouds != null and clouds.visible, "Independent Town clouds must be visible by default.")
	if sky != null and clouds != null:
		_expect(sky.z_index < clouds.z_index, "Clouds must render in front of the sky.")
	var modular := backdrop.get_node_or_null("ModularVisuals") as Node2D
	_expect(modular != null, "Town backdrop must retain modular environment visuals.")
	if modular != null:
		_expect(
			modular.get_node_or_null("Background/BackgroundSky") == null,
			"Modular visuals must not retain the former baked sky-and-cloud plate."
		)
		var mountains := modular.get_node_or_null("Background/BackgroundMountains") as Sprite2D
		_expect(mountains != null and mountains.visible, "Separated sky must retain the authored mountain layer.")
		if clouds != null and mountains != null:
			_expect(clouds.z_index < mountains.z_index, "Clouds must remain behind the mountain skyline.")
	backdrop.queue_free()


func _count_sprites(node: Node) -> int:
	var count := 1 if node is Sprite2D else 0
	for child in node.get_children():
		count += _count_sprites(child)
	return count


func _capture_review_frames() -> void:
	var capture_directory := OS.get_environment("TOWN_SKY_CLOUD_CAPTURE_DIR")
	if capture_directory.is_empty():
		return
	_expect(
		DirAccess.make_dir_recursive_absolute(capture_directory) == OK,
		"Town sky/cloud review capture directory must be writable."
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(MAP_WIDTH), int(MAP_HEIGHT))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var town := (load("res://scenes/maps/town.tscn") as PackedScene).instantiate()
	_disable_cameras(town)
	viewport.add_child(town)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save_review_frame(viewport, capture_directory.path_join("town_sky_cloud_t0"))
	var clouds := town.get_node("ParallaxBackground/Clouds")
	await _save_runtime_clouds(clouds, capture_directory)
	clouds.call("advance_clouds", 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_review_frame(viewport, capture_directory.path_join("town_sky_cloud_t60"))
	viewport.queue_free()
	await process_frame


func _disable_cameras(node: Node) -> void:
	if node is Camera2D:
		(node as Camera2D).enabled = false
	for child in node.get_children():
		_disable_cameras(child)


func _source_texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		return atlas.resource_path if atlas != null else ""
	return texture.resource_path


func _save_runtime_clouds(clouds: Node, capture_directory: String) -> void:
	var index := 0
	for child in clouds.get_children():
		var cloud := child as Sprite2D
		if cloud == null or cloud.texture == null:
			continue
		index += 1
		var detail_viewport := SubViewport.new()
		var texture_size := Vector2i(cloud.texture.get_size())
		detail_viewport.size = texture_size + Vector2i(16, 16)
		detail_viewport.transparent_bg = true
		detail_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		root.add_child(detail_viewport)
		var detail_cloud := Sprite2D.new()
		detail_cloud.position = Vector2(detail_viewport.size) * 0.5
		detail_cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		detail_cloud.texture = cloud.texture
		detail_cloud.material = cloud.material
		detail_viewport.add_child(detail_cloud)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := detail_viewport.get_texture().get_image()
		var output_path := capture_directory.path_join("town_cloud_runtime_%02d.png" % index)
		_expect(image.save_png(output_path) == OK, "Runtime cloud detail must save: %s" % output_path)
		detail_viewport.queue_free()
		await process_frame


func _save_review_frame(viewport: SubViewport, path_prefix: String) -> void:
	var frame := viewport.get_texture().get_image()
	_expect(frame.save_png("%s_full.png" % path_prefix) == OK, "Town full-frame capture must save.")
	var x_edges := [0, 647, 1294, frame.get_width()]
	var y_edges := [0, 360, frame.get_height()]
	for row in range(2):
		for column in range(3):
			var region := Rect2i(
				x_edges[column],
				y_edges[row],
				x_edges[column + 1] - x_edges[column],
				y_edges[row + 1] - y_edges[row]
			)
			var slice := frame.get_region(region)
			var slice_path := "%s_r%d_c%d.png" % [path_prefix, row + 1, column + 1]
			_expect(slice.save_png(slice_path) == OK, "Town review slice must save: %s" % slice_path)


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town sky and cloud animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
