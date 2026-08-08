extends SceneTree

const ACTIVE_THRESHOLD := 8
const ATLAS_SPECS := [
	{
		"path": "res://assets/generated/vfx/reusable/ground/poison_ground_mask_atlas_v1.png",
		"size": Vector2i(1536, 1024),
		"columns": 3,
		"rows": 2,
		"safe_margin": 48,
	},
	{
		"path": "res://assets/generated/vfx/reusable/ground/ice_trail_mask_atlas_v1.png",
		"size": Vector2i(1536, 1024),
		"columns": 3,
		"rows": 2,
		"safe_margin": 48,
	},
	{
		"path": "res://assets/generated/vfx/reusable/kinetic/slash_energy_mask_atlas_v1.png",
		"size": Vector2i(1536, 1024),
		"columns": 3,
		"rows": 2,
		"safe_margin": 48,
	},
	{
		"path": "res://assets/generated/vfx/reusable/kinetic/shockwave_energy_mask_atlas_v1.png",
		"size": Vector2i(1536, 1024),
		"columns": 3,
		"rows": 2,
		"safe_margin": 48,
	},
	{
		"path": "res://assets/generated/vfx/reusable/utility/contact_flash_hit_debris_atlas_v1.png",
		"size": Vector2i(1536, 1024),
		"columns": 3,
		"rows": 2,
		"safe_margin": 48,
	},
	{
		"path": "res://assets/generated/vfx/reusable/utility/healing_void_components_atlas_v1.png",
		"size": Vector2i(1536, 1024),
		"columns": 3,
		"rows": 2,
		"safe_margin": 48,
	},
	{
		"path": "res://assets/generated/vfx/reusable/atmospheric/smoke_dust_components_atlas_v1.png",
		"size": Vector2i(1252, 1252),
		"columns": 4,
		"rows": 4,
		"safe_margin": 20,
	},
	{
		"path": "res://assets/generated/vfx/reusable/atmospheric/explosion_spark_components_atlas_v1.png",
		"size": Vector2i(1252, 1252),
		"columns": 4,
		"rows": 4,
		"safe_margin": 20,
	},
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec_variant in ATLAS_SPECS:
		_test_atlas(spec_variant as Dictionary)
	if _failures == 0:
		print("PASS: reusable combat VFX atlases are loadable, padded, and free of low-level background noise")
	quit(1 if _failures > 0 else 0)


func _test_atlas(spec: Dictionary) -> void:
	var path := String(spec.get("path", ""))
	_expect(FileAccess.file_exists(path), "Reusable VFX atlas must exist: %s." % path)
	if not FileAccess.file_exists(path):
		return
	var texture := load(path) as Texture2D
	_expect(texture != null, "Reusable VFX atlas must load as Texture2D: %s." % path)
	if texture == null:
		return
	_expect(Vector2i(texture.get_size()) == spec.get("size"), "Reusable VFX atlas has the wrong imported size: %s." % path)
	var image := texture.get_image()
	_expect(image != null and not image.is_empty(), "Reusable VFX imported texture must expose pixel data: %s." % path)
	if image == null or image.is_empty():
		return
	var expected_size := spec.get("size") as Vector2i
	_expect(image.get_size() == expected_size, "Reusable VFX source PNG has the wrong size: %s." % path)
	var columns := int(spec.get("columns", 0))
	var rows := int(spec.get("rows", 0))
	_expect(columns > 0 and rows > 0, "Reusable VFX atlas grid must be positive: %s." % path)
	if columns <= 0 or rows <= 0:
		return
	_expect(image.get_width() % columns == 0 and image.get_height() % rows == 0, "Reusable VFX atlas grid must divide evenly: %s." % path)
	var cell_size := Vector2i(image.get_width() / columns, image.get_height() / rows)
	var safe_margin := int(spec.get("safe_margin", 0))
	for row in range(rows):
		for column in range(columns):
			_test_cell(image, path, column, row, cell_size, safe_margin)


func _test_cell(
	image: Image,
	path: String,
	column: int,
	row: int,
	cell_size: Vector2i,
	safe_margin: int
) -> void:
	var origin := Vector2i(column * cell_size.x, row * cell_size.y)
	var active_count := 0
	for local_y in range(cell_size.y):
		for local_x in range(cell_size.x):
			var color := image.get_pixelv(origin + Vector2i(local_x, local_y))
			var red := int(round(color.r * 255.0))
			var green := int(round(color.g * 255.0))
			var blue := int(round(color.b * 255.0))
			var maximum := maxi(red, maxi(green, blue))
			if maximum > 0 and maximum < ACTIVE_THRESHOLD:
				_expect(false, "%s R%dC%d contains low-level background noise at (%d, %d): rgb(%d, %d, %d)." % [path, row + 1, column + 1, local_x, local_y, red, green, blue])
				return
			if maximum < ACTIVE_THRESHOLD:
				continue
			active_count += 1
			var inside_safe_area := (
				local_x >= safe_margin
				and local_y >= safe_margin
				and local_x < cell_size.x - safe_margin
				and local_y < cell_size.y - safe_margin
			)
			if not inside_safe_area:
				_expect(false, "%s R%dC%d crosses its %dpx safe margin at (%d, %d)." % [path, row + 1, column + 1, safe_margin, local_x, local_y])
				return
	_expect(active_count > 0, "%s R%dC%d must contain one visible reusable component." % [path, row + 1, column + 1])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
