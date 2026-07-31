extends SceneTree

const AMBIENT_SCENE_PATH := (
	"res://scenes/maps/town/components/TownAmbientAnimation.tscn"
)
const BACKDROP_SCENE_PATH := "res://scenes/maps/town/components/TownBackdrop.tscn"
const ASSET_ROOT := "res://assets/town/modular_v3/ambient/"
const SHEETS := {
	"Eave branch sway": ASSET_ROOT + "eave_branch_sway_sheet.png",
	"Falling leaves": ASSET_ROOT + "falling_leaves_sheet.png",
	"Bird idle": ASSET_ROOT + "bird_idle_sheet.png",
	"Bird flight": ASSET_ROOT + "bird_flight_sheet.png",
}
const EXPECTED_SHEET_SIZE := Vector2i(1448, 1086)
const EXPECTED_FRAME_COUNT := 12
const EXPECTED_COLUMNS := 4
const EXPECTED_ROWS := 3

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_asset_contract()
	await _assert_scene_contract()
	_assert_backdrop_contract()
	_finish()


func _assert_asset_contract() -> void:
	for label in SHEETS:
		var path := String(SHEETS[label])
		_expect(FileAccess.file_exists(path), "%s sheet must exist: %s" % [label, path])
		_expect(ResourceLoader.exists(path), "%s sheet must import: %s" % [label, path])
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(not image.is_empty(), "%s sheet must load through Image." % label)
		if image.is_empty():
			continue
		_expect(
			image.get_size() == EXPECTED_SHEET_SIZE,
			"%s sheet must remain a 1448x1086 4x3 atlas." % label
		)
		_expect(image.detect_alpha() != Image.ALPHA_NONE, "%s must retain alpha." % label)
		_assert_sheet_cells(image, String(label))


func _assert_sheet_cells(image: Image, label: String) -> void:
	var frame_size := Vector2i(
		image.get_width() / EXPECTED_COLUMNS,
		image.get_height() / EXPECTED_ROWS
	)
	for frame_index in EXPECTED_FRAME_COUNT:
		var column := frame_index % EXPECTED_COLUMNS
		var row := frame_index / EXPECTED_COLUMNS
		var region := Rect2i(column * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		var frame := image.get_region(region)
		_expect(
			frame.get_used_rect().has_area(),
			"%s frame %02d must contain visible pixels." % [label, frame_index]
		)
		_expect(
			_has_transparent_corners(frame),
			"%s frame %02d must keep transparent corners." % [label, frame_index]
		)


func _assert_scene_contract() -> void:
	_expect(
		ResourceLoader.exists(AMBIENT_SCENE_PATH),
		"Town ambient animation component must exist."
	)
	if not ResourceLoader.exists(AMBIENT_SCENE_PATH):
		return
	var packed := load(AMBIENT_SCENE_PATH) as PackedScene
	_expect(packed != null, "Town ambient animation must load as PackedScene.")
	if packed == null:
		return
	var ambient := packed.instantiate() as Node2D
	_expect(ambient != null, "Town ambient animation root must be Node2D.")
	if ambient == null:
		return
	root.add_child(ambient)
	await process_frame

	_expect(ambient.has_method("force_bird_takeoff"), "Ambient owner must control bird takeoff.")
	_expect(
		ambient.has_method("get_ambient_contract"),
		"Ambient owner must expose its authored presentation contract."
	)
	var contract: Dictionary = ambient.call("get_ambient_contract")
	_expect(int(contract.get("frame_count", 0)) == 12, "Ambient loops must use 12 cels.")
	_expect(
		int(contract.get("bird_count", 0)) >= 10,
		"Town needs grouped and scattered bird perches."
	)
	_expect(
		int(contract.get("roof_perches", 0)) >= 6
			and int(contract.get("ground_perches", 0)) >= 3,
		"Town birds need roof flocks and a ground flock."
	)
	_expect(
		int(contract.get("leaf_streams", 0)) >= 5,
		"Town needs independently timed leaf streams."
	)
	_expect(
		float(contract.get("calm_wait_min", 0.0)) >= 8.0,
		"Foliage must hold calm before an occasional breeze."
	)
	_expect(
		String(contract.get("ancient_tree_source", ""))
			== "res://assets/town/modular_v3/background/"
				+ "autumn_ancient_tree_base_v2.png",
		"Ambient wind must deform the complete authored ancient tree."
	)
	_expect(
		float(contract.get("idle_wait_min", 0.0)) >= 6.0,
		"Bird idle waits must stay long enough for a relaxed town mood."
	)

	var canopy_layers := ambient.get_node_or_null("CanopyLayers")
	_expect(canopy_layers != null, "Ambient scene must expose canopy layers.")
	if canopy_layers != null:
		var tree := canopy_layers.get_node_or_null("AncientTreeWind") as Sprite2D
		_expect(tree != null, "AncientTreeWind must remain editor-authored.")
		if tree != null:
			_expect(
				tree.material is ShaderMaterial,
				"Ancient tree wind must preserve a root-anchored shader."
			)
		for child in canopy_layers.get_children():
			if child is Sprite2D and child.name != &"AncientTreeWind":
				_assert_atlas_sprite(child as Sprite2D, String(child.name))
	var birds := ambient.get_node_or_null("BirdPerches")
	_expect(birds != null, "Ambient scene must expose BirdPerches.")
	if birds != null:
		_expect(birds.get_child_count() >= 10, "BirdPerches must contain ten birds.")
		for bird in birds.get_children():
			_expect(bird is Sprite2D, "%s must be a Sprite2D without collision." % bird.name)
			if bird is Sprite2D:
				_assert_atlas_sprite(bird as Sprite2D, String(bird.name))
				_expect(
					String(bird.get_meta("perch_kind", "")) in ["roof", "ground"],
					"%s must declare roof or ground perch ownership." % bird.name
				)
		var takeoff_bird := birds.get_node_or_null("BirdGroundEast") as Sprite2D
		_expect(takeoff_bird != null, "BirdGroundEast must remain an authored perch.")
		if takeoff_bird != null:
			ambient.call("force_bird_takeoff", &"BirdGroundEast")
			_expect(
				takeoff_bird.texture != null
					and takeoff_bird.texture.resource_path
						== ASSET_ROOT + "bird_flight_sheet.png",
				"Forced takeoff must switch the bird to the flight atlas."
			)
			_expect(
				takeoff_bird.frame == 0,
				"Takeoff must begin from the first authored flight cel."
			)

	ambient.queue_free()
	await process_frame


func _assert_atlas_sprite(sprite: Sprite2D, label: String) -> void:
	_expect(
		sprite.hframes == EXPECTED_COLUMNS and sprite.vframes == EXPECTED_ROWS,
		"%s must read a 4x3 atlas." % label
	)
	_expect(
		sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s must use nearest filtering." % label
	)
	_expect(sprite.texture != null, "%s must reference an ambient sheet." % label)


func _assert_backdrop_contract() -> void:
	var packed := load(BACKDROP_SCENE_PATH) as PackedScene
	_expect(packed != null, "TownBackdrop must load as PackedScene.")
	if packed == null:
		return
	var backdrop := packed.instantiate() as Node2D
	var modular := backdrop.get_node_or_null("ModularVisuals")
	var ambient := backdrop.get_node_or_null("AmbientAnimation")
	_expect(ambient != null, "TownBackdrop must instantiate AmbientAnimation.")
	if modular != null and ambient != null:
		_expect(
			ambient.scene_file_path == AMBIENT_SCENE_PATH,
			"TownBackdrop must use the authoritative ambient component."
		)
		_expect(
			ambient.get_index() > modular.get_index(),
			"Ambient animation must render after the modular map."
		)
	backdrop.free()


func _has_transparent_corners(image: Image) -> bool:
	var right := image.get_width() - 1
	var bottom := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a <= 0.001
		and image.get_pixel(right, 0).a <= 0.001
		and image.get_pixel(0, bottom).a <= 0.001
		and image.get_pixel(right, bottom).a <= 0.001
	)


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town ambient animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
