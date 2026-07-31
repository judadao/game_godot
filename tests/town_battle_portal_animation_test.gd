extends SceneTree

const ANIMATION_SCENE_PATH := (
	"res://scenes/maps/town/components/TownBattlePortalAnimation.tscn"
)
const BACKDROP_SCENE_PATH := "res://scenes/maps/town/components/TownBackdrop.tscn"
const BASE_TEXTURE_PATH := (
	"res://assets/town/modular_v3/landmarks/battle_portal_base_v5.png"
)
const ANIMATION_ROOT := (
	"res://assets/town/modular_v3/landmarks/battle_portal_animation/"
)
const MASK_TEXTURE_PATH := ANIMATION_ROOT + "portal_aperture_mask.png"
const UNDERPAINT_TEXTURE_PATH := ANIMATION_ROOT + "portal_underpaint.png"
const CORE_FRAME_ROOT := ANIMATION_ROOT + "vortex_core/frame_"
const HIGHLIGHT_FRAME_ROOT := ANIMATION_ROOT + "vortex_highlights/frame_"
const PULSE_ANIMATION := &"pulse"
const EXPECTED_CANVAS_SIZE := Vector2i(800, 960)
const EXPECTED_WORLD_POSITION := Vector2(830.0, 552.0)
const EXPECTED_RUNTIME_SCALE := Vector2(0.25, 0.25)
const EXPECTED_FRAME_COUNT := 12
const EXPECTED_FPS := 6.0
const EXPECTED_PULSE_SECONDS := 2.0
const TRANSPARENT_ALPHA_MAX := 0.001

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_asset_contract()
	await _assert_animation_scene()
	_assert_backdrop_order()
	_finish()


func _frame_path(root_path: String, frame_index: int) -> String:
	return root_path + "%02d.png" % frame_index


func _assert_asset_contract() -> void:
	var asset_paths: Array[String] = [
		BASE_TEXTURE_PATH,
		MASK_TEXTURE_PATH,
		UNDERPAINT_TEXTURE_PATH,
	]
	for frame_index in EXPECTED_FRAME_COUNT:
		asset_paths.append(_frame_path(CORE_FRAME_ROOT, frame_index))
		asset_paths.append(_frame_path(HIGHLIGHT_FRAME_ROOT, frame_index))
	for path in asset_paths:
		_expect(FileAccess.file_exists(path), "Portal asset must exist: %s" % path)
		_expect(ResourceLoader.exists(path), "Portal asset must import: %s" % path)

	var base := _load_image(BASE_TEXTURE_PATH)
	var mask := _load_image(MASK_TEXTURE_PATH)
	var underpaint := _load_image(UNDERPAINT_TEXTURE_PATH)
	if base.is_empty() or mask.is_empty() or underpaint.is_empty():
		return
	_assert_runtime_image(base, "Base v5")
	_assert_runtime_image(mask, "Aperture mask")
	_assert_runtime_image(underpaint, "Portal underpaint")
	var mask_rect := mask.get_used_rect()
	_expect(
		mask_rect.position.x > 180
			and mask_rect.position.y > 180
			and mask_rect.end.x < 620
			and mask_rect.end.y < 920,
		"Portal aperture mask must stay inside the stone arch; got %s." % mask_rect
	)
	_expect(
		_saturated_purple_ratio(base) < 0.03,
		"Battle Portal Base v5 must not bake the vortex into the stone frame."
	)
	_expect(
		underpaint.get_used_rect() == mask_rect,
		"Portal underpaint must fill the complete aperture without black slots."
	)

	for frame_index in EXPECTED_FRAME_COUNT:
		var core := _load_image(_frame_path(CORE_FRAME_ROOT, frame_index))
		var highlights := _load_image(
			_frame_path(HIGHLIGHT_FRAME_ROOT, frame_index)
		)
		if core.is_empty() or highlights.is_empty():
			continue
		_assert_runtime_image(core, "Core cel %02d" % frame_index)
		_assert_runtime_image(highlights, "Highlight cel %02d" % frame_index)
		_expect(
			mask_rect.encloses(core.get_used_rect()),
			"Core cel %02d must remain clipped to the aperture." % frame_index
		)
		_expect(
			mask_rect.encloses(highlights.get_used_rect()),
			"Highlight cel %02d must remain clipped to the aperture." % frame_index
		)


func _assert_runtime_image(image: Image, label: String) -> void:
	_expect(
		image.get_size() == EXPECTED_CANVAS_SIZE,
		"%s must use the 4x 800x960 runtime canvas." % label
	)
	_expect(image.detect_alpha() != Image.ALPHA_NONE, "%s must retain alpha." % label)
	_expect(
		_has_transparent_corners(image),
		"%s must retain four transparent corners." % label
	)
	_expect(image.get_used_rect().has_area(), "%s must contain visible pixels." % label)


func _assert_animation_scene() -> void:
	_expect(
		ResourceLoader.exists(ANIMATION_SCENE_PATH),
		"Town Battle Portal animation component must exist."
	)
	if not ResourceLoader.exists(ANIMATION_SCENE_PATH):
		return
	var packed := load(ANIMATION_SCENE_PATH) as PackedScene
	_expect(packed != null, "Town Battle Portal animation must load as PackedScene.")
	if packed == null:
		return

	var animation_root := packed.instantiate() as Node2D
	_expect(animation_root != null, "Town Battle Portal animation root must be Node2D.")
	if animation_root == null:
		return
	root.add_child(animation_root)
	await process_frame

	var underpaint := (
		animation_root.get_node_or_null("PortalUnderpaint") as Sprite2D
	)
	var core := animation_root.get_node_or_null("PortalCore") as AnimatedSprite2D
	var highlights := (
		animation_root.get_node_or_null("PortalHighlights") as AnimatedSprite2D
	)
	var rune := animation_root.get_node_or_null("PortalRuneGlow") as Polygon2D
	var pulse := animation_root.get_node_or_null("PortalPulse") as AnimationPlayer
	_expect(
		underpaint != null,
		"Portal animation must expose PortalUnderpaint Sprite2D."
	)
	_expect(core != null, "Portal animation must expose PortalCore AnimatedSprite2D.")
	_expect(
		highlights != null,
		"Portal animation must expose PortalHighlights AnimatedSprite2D."
	)
	_expect(rune != null, "Portal animation must expose PortalRuneGlow Polygon2D.")
	_expect(pulse != null, "Portal animation must expose PortalPulse AnimationPlayer.")
	if (
		underpaint == null
		or core == null
		or highlights == null
		or rune == null
		or pulse == null
	):
		animation_root.queue_free()
		await process_frame
		return

	_expect(
		underpaint.position.is_equal_approx(EXPECTED_WORLD_POSITION)
			and underpaint.scale.is_equal_approx(EXPECTED_RUNTIME_SCALE),
		"PortalUnderpaint must align with the authored portal center."
	)
	_expect(
		underpaint.texture != null
			and underpaint.texture.resource_path == UNDERPAINT_TEXTURE_PATH,
		"PortalUnderpaint must use the complete dark-purple aperture fill."
	)
	_assert_sprite_contract(core, "PortalCore")
	_assert_sprite_contract(highlights, "PortalHighlights")
	_expect(
		highlights.frame != core.frame or highlights.frame_progress != core.frame_progress,
		"PortalHighlights must keep an authored phase offset from PortalCore."
	)
	_expect(
		highlights.material is CanvasItemMaterial,
		"PortalHighlights must use a separate additive material."
	)
	_expect(
		rune.position.distance_to(Vector2(830.0, 469.0)) <= 8.0,
		"PortalRuneGlow must stay inside the top diamond housing."
	)
	_expect(
		rune.material is CanvasItemMaterial,
		"PortalRuneGlow must use an additive CanvasItemMaterial."
	)
	_assert_pulse_contract(pulse)

	animation_root.queue_free()
	await process_frame


func _assert_sprite_contract(sprite: AnimatedSprite2D, label: String) -> void:
	_expect(
		sprite.position.is_equal_approx(EXPECTED_WORLD_POSITION),
		"%s must align with the authored portal center." % label
	)
	_expect(
		sprite.scale.is_equal_approx(EXPECTED_RUNTIME_SCALE),
		"%s must use the 4x runtime asset scale." % label
	)
	_expect(
		sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s must explicitly use nearest filtering." % label
	)
	_expect(sprite.autoplay == &"vortex", "%s must autoplay vortex." % label)
	_expect(sprite.sprite_frames != null, "%s must define SpriteFrames." % label)
	if sprite.sprite_frames == null:
		return
	_expect(
		sprite.sprite_frames.get_frame_count(&"vortex") == EXPECTED_FRAME_COUNT,
		"%s must use all 12 hand-drawn cels." % label
	)
	_expect(
		is_equal_approx(
			sprite.sprite_frames.get_animation_speed(&"vortex"),
			EXPECTED_FPS
		),
		"%s must play the relaxed two-second loop at 6 FPS." % label
	)
	_expect(
		sprite.sprite_frames.get_animation_loop(&"vortex"),
		"%s vortex animation must loop." % label
	)


func _assert_pulse_contract(pulse: AnimationPlayer) -> void:
	_expect(
		pulse.autoplay == String(PULSE_ANIMATION) and pulse.is_playing(),
		"PortalPulse must autoplay the glow pulse."
	)
	_expect(pulse.has_animation(PULSE_ANIMATION), "PortalPulse must define pulse.")
	if not pulse.has_animation(PULSE_ANIMATION):
		return
	var animation := pulse.get_animation(PULSE_ANIMATION)
	_expect(
		animation != null
			and is_equal_approx(animation.length, EXPECTED_PULSE_SECONDS)
			and animation.loop_mode != Animation.LOOP_NONE,
		"Portal glow pulse must be a smooth looping two-second cycle."
	)
	if animation == null:
		return
	var expected_tracks := {
		"PortalHighlights:modulate": false,
		"PortalRuneGlow:modulate": false,
		"PortalRuneGlow:scale": false,
	}
	for track_index in animation.get_track_count():
		var path := String(animation.track_get_path(track_index))
		if expected_tracks.has(path):
			expected_tracks[path] = true
		_expect(
			animation.track_get_interpolation_type(track_index)
				!= Animation.INTERPOLATION_NEAREST,
			"Portal pulse track must interpolate smoothly: %s" % path
		)
	for path in expected_tracks:
		_expect(bool(expected_tracks[path]), "Portal pulse must animate %s." % path)


func _assert_backdrop_order() -> void:
	var packed := load(BACKDROP_SCENE_PATH) as PackedScene
	_expect(packed != null, "TownBackdrop must load as PackedScene.")
	if packed == null:
		return
	var backdrop := packed.instantiate() as Node2D
	var modular := backdrop.get_node_or_null("ModularVisuals")
	var portal_animation := backdrop.get_node_or_null("BattlePortalAnimation")
	_expect(modular != null, "TownBackdrop must retain ModularVisuals.")
	_expect(
		portal_animation != null,
		"TownBackdrop must instantiate the Battle Portal animation component."
	)
	if modular != null and portal_animation != null:
		_expect(
			portal_animation.scene_file_path == ANIMATION_SCENE_PATH,
			"TownBackdrop must link the authoritative portal animation component."
		)
		_expect(
			portal_animation.get_index() > modular.get_index(),
			"Portal animation must render after ModularVisuals."
		)
	backdrop.free()


func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(not image.is_empty(), "Portal image must load through Image: %s" % path)
	return image


func _saturated_purple_ratio(image: Image) -> float:
	var saturated_purple := 0
	var visible := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.1:
				continue
			visible += 1
			if (
				color.b > 0.45
				and color.r > color.g * 1.25
				and color.b > color.g * 1.35
			):
				saturated_purple += 1
	return float(saturated_purple) / float(maxi(1, visible))


func _has_transparent_corners(image: Image) -> bool:
	var right := image.get_width() - 1
	var bottom := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a <= TRANSPARENT_ALPHA_MAX
		and image.get_pixel(right, 0).a <= TRANSPARENT_ALPHA_MAX
		and image.get_pixel(0, bottom).a <= TRANSPARENT_ALPHA_MAX
		and image.get_pixel(right, bottom).a <= TRANSPARENT_ALPHA_MAX
	)


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town Battle Portal hand-drawn animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
