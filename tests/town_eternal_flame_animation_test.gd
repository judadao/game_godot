extends SceneTree

const ANIMATION_SCENE_PATH := (
	"res://scenes/maps/town/components/TownEternalFlameAnimation.tscn"
)
const BACKDROP_SCENE_PATH := "res://scenes/maps/town/components/TownBackdrop.tscn"
const BASE_TEXTURE_PATH := (
	"res://assets/town/modular_v3/landmarks/eternal_forge_monument_base_v5.png"
)
const ANIMATION_NAME := &"default"
const EXPECTED_FRAME_COUNT := 8
const EXPECTED_FIRE_FPS := 4.5
const EXPECTED_RUNE_FPS := 4.0
const EXPECTED_RUNE_CYCLE_SECONDS := 2.0
const POSITION_TOLERANCE := Vector2(4.0, 12.0)
const TRANSPARENT_ALPHA_MAX := 0.001
const PIVOT_TOLERANCE := 1.0

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_runtime_base()
	await _assert_animation_scene()
	_assert_backdrop_order()
	_finish()


func _assert_runtime_base() -> void:
	_expect(
		FileAccess.file_exists(BASE_TEXTURE_PATH),
		"Eternal Flame runtime Base v5 PNG must exist."
	)
	_expect(
		ResourceLoader.exists(BASE_TEXTURE_PATH),
		"Eternal Flame runtime Base v5 PNG must be registered by ResourceLoader."
	)
	if not FileAccess.file_exists(BASE_TEXTURE_PATH):
		return

	var texture := load(BASE_TEXTURE_PATH) as Texture2D
	_expect(texture != null, "Eternal Flame runtime Base v5 must load as Texture2D.")
	var image := Image.load_from_file(ProjectSettings.globalize_path(BASE_TEXTURE_PATH))
	_expect(not image.is_empty(), "Eternal Flame runtime Base v5 PNG must load through Image.")
	if image.is_empty():
		return
	_expect(
		image.detect_alpha() != Image.ALPHA_NONE,
		"Eternal Flame runtime Base v5 PNG must retain an alpha channel."
	)
	_expect(
		_has_transparent_corners(image),
		"Eternal Flame runtime Base v5 PNG must preserve transparent outer corners."
	)
	_expect(
		image.get_used_rect().has_area(),
		"Eternal Flame runtime Base v5 PNG must contain visible pixels."
	)


func _assert_animation_scene() -> void:
	_expect(
		ResourceLoader.exists(ANIMATION_SCENE_PATH),
		"Town Eternal Flame animation component must exist."
	)
	if not ResourceLoader.exists(ANIMATION_SCENE_PATH):
		return

	var packed := load(ANIMATION_SCENE_PATH) as PackedScene
	_expect(packed != null, "Town Eternal Flame animation component must load as PackedScene.")
	if packed == null:
		return

	var animation_root := packed.instantiate() as Node2D
	_expect(animation_root != null, "Town Eternal Flame animation root must be Node2D.")
	if animation_root == null:
		return
	root.add_child(animation_root)
	await process_frame

	var fire_layers := animation_root.get_node_or_null("FireLayers") as Node2D
	var outer_flame := animation_root.get_node_or_null(
		"FireLayers/TopFire"
	) as AnimatedSprite2D
	var inner_flame := animation_root.get_node_or_null(
		"FireLayers/InnerFire"
	) as AnimatedSprite2D
	var afterglow := animation_root.get_node_or_null(
		"FireLayers/FireGlow"
	) as AnimatedSprite2D
	var brazier_front := animation_root.get_node_or_null(
		"BrazierFrontOccluder"
	) as Sprite2D
	var rune_charge := animation_root.get_node_or_null("RuneCharge") as AnimatedSprite2D
	_expect(
		fire_layers != null,
		"Eternal Flame animation must expose an independently controllable FireLayers group."
	)
	_expect(
		outer_flame != null,
		"FireLayers must expose a TopFire outer-flame AnimatedSprite2D layer."
	)
	_expect(
		inner_flame != null,
		"FireLayers must expose an InnerFire AnimatedSprite2D layer."
	)
	_expect(
		afterglow != null,
		"FireLayers must expose a FireGlow afterglow AnimatedSprite2D layer."
	)
	_expect(
		rune_charge != null,
		"Eternal Flame animation must expose RuneCharge AnimatedSprite2D."
	)
	if (
		fire_layers == null
		or outer_flame == null
		or inner_flame == null
		or afterglow == null
		or rune_charge == null
		or brazier_front == null
	):
		animation_root.queue_free()
		await process_frame
		return

	_expect(
		fire_layers.get_parent() == animation_root
			and rune_charge.get_parent() == animation_root
			and rune_charge.get_parent() != fire_layers,
		"FireLayers group and RuneCharge must remain independently controllable siblings."
	)
	_expect(
		outer_flame.get_parent() == fire_layers
			and inner_flame.get_parent() == fire_layers
			and afterglow.get_parent() == fire_layers,
		"Every flame layer must stay inside the independent FireLayers group."
	)
	_assert_position(fire_layers, Vector2(830.0, 195.0), "FireLayers bottom pivot")
	_expect(
		fire_layers.scale.is_equal_approx(Vector2(0.25, 0.25)),
		"FireLayers must retain the authored flame size."
	)
	_expect(
		fire_layers.z_index == -7
			and outer_flame.z_index == 1
			and inner_flame.z_index == 2
			and afterglow.z_index == -3,
		"Flame layers must stay between the static basin and its front-edge occluder."
	)
	_assert_position(brazier_front, Vector2(830.0, 209.5), "BrazierFrontOccluder")
	_expect(
		brazier_front.z_index == -4
			and brazier_front.scale.is_equal_approx(Vector2(0.25, 0.25))
			and brazier_front.region_enabled
			and brazier_front.region_rect.is_equal_approx(Rect2(400.0, 260.0, 580.0, 260.0)),
		"BrazierFrontOccluder must redraw the matching static basin front over the flame base."
	)
	_assert_position(rune_charge, Vector2(830.0, 365.0), "RuneCharge")
	_assert_flame_layer_variation(outer_flame, inner_flame, afterglow)
	_assert_bottom_pivot(outer_flame, "TopFire")
	_assert_bottom_pivot(inner_flame, "InnerFire")
	_assert_bottom_pivot(afterglow, "FireGlow")

	var outer_paths := _assert_sprite_contract(outer_flame, "TopFire", EXPECTED_FIRE_FPS)
	var inner_paths := _assert_sprite_contract(inner_flame, "InnerFire", EXPECTED_FIRE_FPS)
	var afterglow_paths := _assert_sprite_contract(
		afterglow,
		"FireGlow",
		EXPECTED_FIRE_FPS
	)
	var rune_paths := _assert_sprite_contract(
		rune_charge,
		"RuneCharge",
		EXPECTED_RUNE_FPS
	)
	_assert_rune_pulse_contract(animation_root, rune_charge)
	var flame_paths := _merge_path_sets([outer_paths, inner_paths, afterglow_paths])
	for path_variant in flame_paths:
		var path := String(path_variant)
		_expect(
			not rune_paths.has(path),
			"TopFire layers and RuneCharge must use independent frame textures: %s" % path
		)

	animation_root.queue_free()
	await process_frame


func _assert_sprite_contract(
	sprite: AnimatedSprite2D,
	label: String,
	expected_fps: float
) -> Dictionary:
	_expect(
		sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s must explicitly use nearest texture filtering." % label
	)
	_expect(
		sprite.animation == ANIMATION_NAME and sprite.autoplay == String(ANIMATION_NAME),
		"%s must select and autoplay the default animation." % label
	)
	_expect(sprite.is_playing(), "%s autoplay must start after entering the SceneTree." % label)

	var frames := sprite.sprite_frames
	_expect(frames != null, "%s must own a SpriteFrames resource." % label)
	if frames == null:
		return {}
	_expect(
		frames.has_animation(ANIMATION_NAME),
		"%s SpriteFrames must define the default animation." % label
	)
	if not frames.has_animation(ANIMATION_NAME):
		return {}
	_expect(
		frames.get_frame_count(ANIMATION_NAME) == EXPECTED_FRAME_COUNT,
		"%s default animation must contain exactly 8 frames." % label
	)
	_expect(
		frames.get_animation_loop(ANIMATION_NAME),
		"%s default animation must loop." % label
	)
	_expect(
		is_equal_approx(frames.get_animation_speed(ANIMATION_NAME), expected_fps),
		"%s default animation must play at %.1f FPS." % [label, expected_fps]
	)

	var paths: Dictionary = {}
	for frame_index in frames.get_frame_count(ANIMATION_NAME):
		var texture := frames.get_frame_texture(ANIMATION_NAME, frame_index)
		_expect(
			texture != null,
			"%s frame %d must reference a texture." % [label, frame_index]
		)
		if texture == null:
			continue
		var texture_path := texture.resource_path
		_expect(
			not texture_path.is_empty(),
			"%s frame %d must use a saved texture resource." % [label, frame_index]
		)
		_expect(
			not paths.has(texture_path),
			"%s frame %d must use its own texture path." % [label, frame_index]
		)
		paths[texture_path] = true
		_assert_transparent_frame(texture_path, label, frame_index)
	_expect(
		paths.size() == EXPECTED_FRAME_COUNT,
		"%s must provide 8 independent frame texture paths." % label
	)
	return paths


func _assert_flame_layer_variation(
	outer_flame: AnimatedSprite2D,
	inner_flame: AnimatedSprite2D,
	afterglow: AnimatedSprite2D
) -> void:
	var outer_alpha := outer_flame.modulate.a * outer_flame.self_modulate.a
	var inner_alpha := inner_flame.modulate.a * inner_flame.self_modulate.a
	var afterglow_alpha := afterglow.modulate.a * afterglow.self_modulate.a
	_expect(
		afterglow_alpha >= 0.2
			and afterglow_alpha < inner_alpha
			and inner_alpha < outer_alpha
			and outer_alpha <= 1.0,
		"Flame opacity must read as solid outer flame, bright inner color, and softer afterglow."
	)
	_expect(
		afterglow.scale.x > outer_flame.scale.x
			and outer_flame.scale.x > inner_flame.scale.x
			and afterglow.scale.y > outer_flame.scale.y
			and outer_flame.scale.y > inner_flame.scale.y,
		"Flame layer scale must progress from compact inner flame to broad afterglow."
	)
	var authored_frames := {
		outer_flame.frame: true,
		inner_flame.frame: true,
		afterglow.frame: true,
	}
	var authored_progress := {
		snappedf(outer_flame.frame_progress, 0.01): true,
		snappedf(inner_flame.frame_progress, 0.01): true,
		snappedf(afterglow.frame_progress, 0.01): true,
	}
	_expect(
		authored_frames.size() == 3 and authored_progress.size() == 3,
		"TopFire, InnerFire, and FireGlow must stagger both initial frame and frame progress."
	)


func _assert_bottom_pivot(sprite: AnimatedSprite2D, label: String) -> void:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(ANIMATION_NAME):
		return
	var texture := frames.get_frame_texture(ANIMATION_NAME, sprite.frame)
	if texture == null or texture.resource_path.is_empty():
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
	if image.is_empty():
		return
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		return
	var visual_bottom := float(used_rect.end.y)
	if sprite.centered:
		visual_bottom -= float(image.get_height()) * 0.5
	visual_bottom += sprite.offset.y
	var anchored_bottom := sprite.position.y + visual_bottom * sprite.scale.y
	_expect(
		absf(anchored_bottom) <= PIVOT_TOLERANCE,
		"%s visible bottom must stay on the FireLayers origin; got %.2f."
			% [label, anchored_bottom]
	)


func _assert_rune_pulse_contract(
	animation_root: Node2D,
	rune_charge: AnimatedSprite2D
) -> void:
	var frames := rune_charge.sprite_frames
	if frames != null and frames.has_animation(ANIMATION_NAME):
		var cycle_seconds := (
			float(frames.get_frame_count(ANIMATION_NAME))
			/ frames.get_animation_speed(ANIMATION_NAME)
		)
		_expect(
			is_equal_approx(cycle_seconds, EXPECTED_RUNE_CYCLE_SECONDS),
			"RuneCharge sprite cycle must loop continuously every 2 seconds."
		)

	var pulse_player := animation_root.get_node_or_null("RunePulse") as AnimationPlayer
	_expect(
		pulse_player != null,
		"RuneCharge must expose a RunePulse AnimationPlayer or equivalent smooth pulse driver."
	)
	if pulse_player == null:
		return
	_expect(
		pulse_player.autoplay == "pulse" and pulse_player.is_playing(),
		"RunePulse must autoplay continuously after entering the SceneTree."
	)
	_expect(
		pulse_player.has_animation(&"pulse"),
		"RunePulse must define a pulse animation."
	)
	if not pulse_player.has_animation(&"pulse"):
		return
	var pulse := pulse_player.get_animation(&"pulse")
	_expect(
		pulse != null
			and is_equal_approx(pulse.length, EXPECTED_RUNE_CYCLE_SECONDS)
			and pulse.loop_mode != Animation.LOOP_NONE,
		"RunePulse must be a looping 2-second animation."
	)
	if pulse == null:
		return
	var has_glow_track := false
	var has_scale_track := false
	var tracks_are_smooth := true
	for track_index in pulse.get_track_count():
		var track_path := String(pulse.track_get_path(track_index))
		has_glow_track = has_glow_track or track_path == "RuneCharge:modulate"
		has_scale_track = has_scale_track or track_path == "RuneCharge:scale"
		tracks_are_smooth = (
			tracks_are_smooth
			and pulse.track_get_interpolation_type(track_index)
				!= Animation.INTERPOLATION_NEAREST
		)
	_expect(
		has_glow_track and has_scale_track and tracks_are_smooth,
		"RunePulse must smoothly animate RuneCharge glow and scale for a readable charge cycle."
	)


func _merge_path_sets(path_sets: Array) -> Dictionary:
	var merged: Dictionary = {}
	for path_set_variant in path_sets:
		var path_set := path_set_variant as Dictionary
		for path_variant in path_set:
			merged[String(path_variant)] = true
	return merged


func _assert_transparent_frame(texture_path: String, label: String, frame_index: int) -> void:
	if texture_path.is_empty():
		return
	_expect(
		FileAccess.file_exists(texture_path),
		"%s frame %d texture must exist on disk: %s" % [label, frame_index, texture_path]
	)
	if not FileAccess.file_exists(texture_path):
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
	_expect(
		not image.is_empty(),
		"%s frame %d texture must load through Image." % [label, frame_index]
	)
	if image.is_empty():
		return
	_expect(
		image.detect_alpha() != Image.ALPHA_NONE and _has_transparent_corners(image),
		"%s frame %d must retain alpha with four transparent corners."
			% [label, frame_index]
	)
	_expect(
		image.get_used_rect().has_area(),
		"%s frame %d must contain visible animation pixels." % [label, frame_index]
	)


func _assert_position(
	sprite: Node2D,
	expected: Vector2,
	label: String
) -> void:
	var delta := (sprite.global_position - expected).abs()
	_expect(
		delta.x <= POSITION_TOLERANCE.x and delta.y <= POSITION_TOLERANCE.y,
		"%s must align near %s; got %s." % [label, expected, sprite.global_position]
	)


func _assert_backdrop_order() -> void:
	var packed := load(BACKDROP_SCENE_PATH) as PackedScene
	_expect(packed != null, "TownBackdrop must load as PackedScene.")
	if packed == null:
		return
	var backdrop := packed.instantiate() as Node2D
	var modular := backdrop.get_node_or_null("ModularVisuals")
	var animation := backdrop.get_node_or_null("EternalFlameAnimation")
	_expect(modular != null, "TownBackdrop must retain its ModularVisuals instance.")
	_expect(
		animation != null,
		"TownBackdrop must instantiate the Eternal Flame animation component."
	)
	if modular != null and animation != null:
		_expect(
			animation.scene_file_path == ANIMATION_SCENE_PATH,
			"TownBackdrop must link the authoritative Eternal Flame animation component."
		)
		_expect(
			animation.get_index() > modular.get_index(),
			"TownBackdrop must place Eternal Flame animation after ModularVisuals."
		)
	backdrop.free()


func _has_transparent_corners(image: Image) -> bool:
	if image.is_empty():
		return false
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
		print("PASS: Town Eternal Flame 8-frame animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
