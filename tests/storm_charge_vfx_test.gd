extends SceneTree

const VFX_SCENE_PATH := "res://scenes/combat/vfx/StormChargeVFX.tscn"
const ATLAS_PATH := "res://assets/generated/vfx/storm_charge_v3/storm_charge_components_v3_final_padded.png"
const PLAYER_TEXTURE_PATH := "res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png"
const EXPECTED_STAGES := [
	&"ground_gather",
	&"limb_conduction",
	&"weapon_lock",
	&"forward_contact",
	&"residual_decay",
]
const STAGE_SAMPLE_TIMES := [0.16, 0.38, 0.64, 0.84, 1.08]
const MOTION_SAMPLE_COUNT := 12
const TOTAL_DURATION := 1.54
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 3
const ATLAS_CELL_SIZE := 402
const ATLAS_SAFE_MARGIN := 20
const BLACK_KEY_THRESHOLD := 0.08

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(VFX_SCENE_PATH) as PackedScene
	_expect(packed != null, "Storm charge VFX scene must load from its dedicated reusable path.")
	if packed == null:
		quit(1)
		return

	var effect := packed.instantiate() as Node2D
	_expect(effect != null, "Storm charge VFX root must be a Node2D.")
	if effect == null:
		quit(1)
		return
	root.add_child(effect)
	await process_frame

	_expect(effect.has_method("configure"), "Storm charge VFX must expose configure(level: int).")
	_expect(effect.has_method("play"), "Storm charge VFX must expose play().")
	_expect(effect.has_method("get_debug_state"), "Storm charge VFX must expose deterministic debug state.")
	_expect(effect.has_method("debug_set_elapsed"), "Storm charge VFX must expose stage sampling for focused tests.")
	_expect(effect.get_node_or_null("GroundLayer/GroundCrawl") is Sprite2D, "V4 needs an authored short-arc ground-current source.")
	_expect(effect.get_node_or_null("BehindPlayerAura/RearConduit") is Sprite2D, "V4 needs a second independently timed ground-current segment.")
	_expect(effect.get_node_or_null("BehindPlayerAura/RearConduitGlow") is Sprite2D, "The second ground-current segment needs a restrained authored glow pass.")
	_expect(effect.get_node_or_null("BehindPlayerAura/MidConduit") is Sprite2D, "V4 needs a short leg-conduction segment behind the fighter.")
	_expect(effect.get_node_or_null("BehindPlayerAura/MidConduitGlow") is Sprite2D, "The leg-conduction segment needs a restrained authored glow pass.")
	_expect(effect.get_node_or_null("FrontLayer/FrontConduit") is Sprite2D, "V4 needs a short weapon-feed segment in front of the fighter.")
	_expect(effect.get_node_or_null("FrontLayer/FrontConduitGlow") is Sprite2D, "The weapon-feed segment needs a restrained authored glow pass.")
	_expect(effect.get_node_or_null("FrontLayer/WeaponSheath") is Sprite2D, "The weapon must use a distinct authored lightning sheath.")
	_expect(effect.get_node_or_null("ClimaxLayer/Strike") is Sprite2D, "The unique climax must use the authored spear/blade component rotated to the right.")
	_expect(effect.get_node_or_null("GroundLayer/GroundBloom") is Sprite2D, "The ground needs a restrained authored foot-contact pool.")
	_expect(effect.get_node_or_null("GroundLayer/GroundScorch") is Sprite2D, "The residual needs an authored scorched ground object.")
	_expect(effect.get_node_or_null("FrontLayer/ResidualArmor/Left") is Sprite2D, "Residual armor needs an independently animated left path.")
	_expect(effect.get_node_or_null("FrontLayer/ResidualArmor/Right") is Sprite2D, "Residual armor needs an independently animated right path.")
	_expect(effect.get_node_or_null("BackLayer/BackParticles") is CPUParticles2D, "Storm charge needs a behind-player particle depth layer.")
	_expect(effect.get_node_or_null("ChargeParticles") is CPUParticles2D, "Storm charge needs a front charge particle layer.")
	_expect(effect.get_node_or_null("ResidualParticles") is CPUParticles2D, "Residual hold must use a separate bounded particle layer.")
	_expect(effect.get_node_or_null("ChargeLight") is PointLight2D, "The charge climax must use a dedicated cold PointLight2D.")
	_expect(effect.get_node_or_null("GroundLight") is PointLight2D, "The ground ellipse must have a dedicated reflected light.")
	_expect(effect.get_node_or_null("WarmBounceLight") is PointLight2D, "The character needs restrained warm conductor bounce light.")
	_expect(not _contains_rough_primary_geometry(effect), "V4 must not introduce Line2D or Polygon2D scribble/logo geometry.")
	_validate_authored_atlas()

	var particle_budgets: Array[int] = []
	var silhouette_ids: Array[String] = []
	for level in [1, 2, 3]:
		effect.call("configure", level)
		var configured := effect.call("get_debug_state") as Dictionary
		particle_budgets.append(int(configured.get("particle_budget", 0)))
		silhouette_ids.append(String(configured.get("core_silhouette", "")))
		_expect(int(configured.get("level", 0)) == level, "configure() must clamp and expose level %d." % level)
		_expect(String(configured.get("authored_component_atlas", "")) == ATLAS_PATH, "Every level must reuse the project-bound Storm authored component atlas.")
		_expect(int(configured.get("authored_component_count", 0)) >= 12, "Storm V4 must expose the reusable authored component atlas.")
		_expect(bool(configured.get("smooth_choreography", false)), "Storm V4 must expose smooth continuous choreography.")
		_expect(int(configured.get("motion_sample_count", 0)) >= MOTION_SAMPLE_COUNT, "Storm V4 must support a twelve-timepoint motion review.")
		_expect(String(configured.get("motion_identity", "")) == "foot_current_to_rightward_weapon_spear", "Storm V4 must expose one traceable foot-to-weapon-to-rightward-spear identity.")
		_expect(not bool(configured.get("whole_plate_motion", true)), "The component atlas must never move as one complete plate.")
		_expect(not bool(configured.get("moving_projectile", true)), "Storm charge must remain an attached in-place charge, not a moving projectile.")
		_expect(not bool(configured.get("generic_ring", true)), "Storm charge must not use a generic circle or ring.")
		_expect(not bool(configured.get("vertical_strike", true)), "Storm V4 must not retain the rejected vertical portal/spear climax.")
		_expect(bool(configured.get("rightward_strike", false)), "Storm V4 must fire exactly one clearly rightward spear/blade.")
		_expect(not bool(configured.get("crystal_plate_visible", true)), "Complete crystal-cluster plates must remain disabled in V4.")
		_expect(not bool(configured.get("core_glyph_visible", true)), "The gold-ring core/glyph plate must remain disabled in V4.")
		_expect(not bool(configured.get("body_s_curve_plate", true)), "The complete S-bolt body plate must remain disabled in V4.")
		_expect(bool(configured.get("face_chest_clear", false)), "Short body arcs must remain below the face/chest readability zone.")
		_expect(bool(configured.get("post_peak_monotonic_decay", false)), "All samples after the sole contact peak must be decay-only.")
		_expect(bool(configured.get("cold_warm_character_lighting", false)), "Storm V4 must preserve controlled character light response.")
		_expect(int(configured.get("point_light_count", 0)) >= 3, "Storm V4 must expose layered weapon, ground, and bounce lights.")
		_expect(float(configured.get("residual_duration", 0.0)) >= 0.5 and float(configured.get("residual_duration", 0.0)) <= 0.8, "Residual electricity must remain attached for 0.5–0.8 seconds.")
		_expect(int(configured.get("visual_budget", 999)) <= 96, "Storm charge detail must remain inside the focused VFX budget.")
		_expect(String(configured.get("primary_geometry", "")) == "fixed_semantic_conduction_polylines", "Storm V4h must build its readable silhouette from fixed semantic conduction polylines.")
		_expect((configured.get("conduction_stroke_widths", PackedFloat32Array()) as PackedFloat32Array) == PackedFloat32Array([10.0, 4.0, 1.4]), "Storm V4i must render the main trunk with restrained outer glow, energized body, and white-hot core.")
		_expect((configured.get("secondary_stroke_widths", PackedFloat32Array()) as PackedFloat32Array) == PackedFloat32Array([6.0, 3.0, 1.0]), "Storm V4i ground, leg, blade contours, and forks must remain finer than the main sword trunk.")
		_expect(int(configured.get("fixed_conduction_path_count", 0)) >= 10, "Storm V4h needs two ground feeds, two leg feeds, three blade traces, and several sword-rooted branches.")
		_expect(bool(configured.get("stage_revealed_paths", false)), "Storm V4h paths must reveal by choreography stage instead of translating a projectile plate.")

	_expect(particle_budgets[0] < particle_budgets[1] and particle_budgets[1] < particle_budgets[2], "Levels 1–3 must increase particle detail monotonically.")
	_expect(silhouette_ids[0] == silhouette_ids[1] and silhouette_ids[1] == silhouette_ids[2], "Levels may add detail but must preserve one ground-to-right-spear silhouette.")

	effect.call("configure", 3)
	effect.call("play")
	_expect(bool((effect.call("get_debug_state") as Dictionary).get("active", false)), "play() must begin the in-place charge lifecycle.")
	for sample_index in STAGE_SAMPLE_TIMES.size():
		effect.call("debug_set_elapsed", STAGE_SAMPLE_TIMES[sample_index])
		var sampled := effect.call("get_debug_state") as Dictionary
		_expect(StringName(sampled.get("stage", &"")) == EXPECTED_STAGES[sample_index], "Elapsed %.2f must resolve to the %s charge beat." % [STAGE_SAMPLE_TIMES[sample_index], EXPECTED_STAGES[sample_index]])
		_expect((sampled.get("world_offset", Vector2(99.0, 99.0)) as Vector2).is_equal_approx(Vector2.ZERO), "Every charge beat must stay attached to its original cast anchor.")

	effect.call("debug_set_elapsed", 0.34)
	var crawl_scale := (effect.get_node("GroundLayer/GroundCrawl") as Sprite2D).scale
	effect.call("debug_set_elapsed", 0.60)
	var closure := effect.call("get_debug_state") as Dictionary
	_expect(int(closure.get("lit_depth_nodes", -1)) == 0, "V4 must not conduct through complete depth-crystal plates.")
	_expect(int(closure.get("connected_arc_count", 0)) >= 4, "Foot, leg, and weapon conduction must expose one segmented purposeful current path.")
	_expect((effect.get_node("GroundLayer/GroundCrawl") as Sprite2D).scale.is_equal_approx(crawl_scale), "Ground current must grow by timed segments, never by whole-plate scale popping.")

	effect.call("debug_set_elapsed", 0.84)
	var climax := effect.call("get_debug_state") as Dictionary
	_expect(float(climax.get("point_light_energy", 0.0)) > 0.8, "The single F7 contact frame must visibly peak through PointLight2D energy.")
	_expect(int(climax.get("climax_count", 0)) == 1, "Storm charge must have exactly one lock-on climax.")
	_expect((climax.get("strike_direction", Vector2.LEFT) as Vector2).dot(Vector2.RIGHT) > 0.98, "The sole strike direction must be unambiguously rightward.")
	_expect(bool(climax.get("strike_origin_connected", false)), "The discharge blade must remain visibly connected to the original sword tip, never read as a detached projectile.")
	effect.call("debug_set_elapsed", 1.08)
	var decay := effect.call("get_debug_state") as Dictionary
	_expect(float(decay.get("point_light_energy", 99.0)) < float(climax.get("point_light_energy", 0.0)), "Post-contact lighting must only decay and cannot create a second peak.")

	await _capture_five_beats_if_requested(packed)
	await _capture_motion_if_requested(packed)
	await _capture_codex_integration_if_requested(packed)
	effect.free()
	if _failures == 0:
		print("PASS: traceable single-path Storm Charge V4 contract")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _contains_rough_primary_geometry(node: Node) -> bool:
	for child in node.get_children():
		if child is Line2D or child is Polygon2D:
			return true
		if _contains_rough_primary_geometry(child):
			return true
	return false


func _validate_authored_atlas() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not image.is_empty(), "Storm V4 authored component atlas must load as source pixels.")
	if image.is_empty():
		return
	_expect(image.get_width() == ATLAS_CELL_SIZE * ATLAS_COLUMNS, "Storm V4 atlas width must expose four exact square component cells.")
	_expect(image.get_height() == ATLAS_CELL_SIZE * ATLAS_ROWS, "Storm V4 atlas height must expose three exact square component rows.")
	for component_index in ATLAS_COLUMNS * ATLAS_ROWS:
		var column := component_index % ATLAS_COLUMNS
		var row := component_index / ATLAS_COLUMNS
		var origin := Vector2i(column * ATLAS_CELL_SIZE, row * ATLAS_CELL_SIZE)
		_expect(_cell_has_safe_black_margin(image, origin), "Storm V4 atlas component %d must retain a pure-black %dpx safety margin." % [component_index + 1, ATLAS_SAFE_MARGIN])


func _cell_has_safe_black_margin(image: Image, origin: Vector2i) -> bool:
	for offset in ATLAS_SAFE_MARGIN:
		for coordinate in ATLAS_CELL_SIZE:
			if _pixel_is_visible(image.get_pixel(origin.x + offset, origin.y + coordinate)):
				return false
			if _pixel_is_visible(image.get_pixel(origin.x + ATLAS_CELL_SIZE - 1 - offset, origin.y + coordinate)):
				return false
			if _pixel_is_visible(image.get_pixel(origin.x + coordinate, origin.y + offset)):
				return false
			if _pixel_is_visible(image.get_pixel(origin.x + coordinate, origin.y + ATLAS_CELL_SIZE - 1 - offset)):
				return false
	return true


func _pixel_is_visible(color: Color) -> bool:
	return maxf(color.r, maxf(color.g, color.b)) > BLACK_KEY_THRESHOLD


func _capture_five_beats_if_requested(packed: PackedScene) -> void:
	var capture_path := OS.get_environment("STORM_CHARGE_VFX_CAPTURE_PATH")
	if capture_path.is_empty():
		return
	var viewport := _make_review_viewport(Vector2i(1600, 400))
	var effects: Array[Node2D] = []
	for index in STAGE_SAMPLE_TIMES.size():
		var origin := Vector2(float(index) * 320.0, 0.0)
		_add_codex_cell(viewport, Rect2(origin, Vector2(320.0, 400.0)), index)
		var anchor := origin + Vector2(160.0, 312.0)
		_add_codex_player(viewport, anchor)
		var effect := _add_sample_effect(viewport, packed, anchor, STAGE_SAMPLE_TIMES[index], 0.88)
		effects.append(effect)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport(viewport, capture_path, "five-beat")
	viewport.queue_free()
	await process_frame


func _capture_motion_if_requested(packed: PackedScene) -> void:
	var capture_path := OS.get_environment("STORM_CHARGE_VFX_MOTION_CAPTURE_PATH")
	if capture_path.is_empty():
		return
	var viewport := _make_review_viewport(Vector2i(1440, 1080))
	for index in MOTION_SAMPLE_COUNT:
		var column := index % 4
		var row := index / 4
		var origin := Vector2(float(column) * 360.0, float(row) * 360.0)
		_add_codex_cell(viewport, Rect2(origin, Vector2(360.0, 360.0)), index)
		var anchor := origin + Vector2(180.0, 280.8)
		_add_codex_player(viewport, anchor)
		var sample_time := TOTAL_DURATION * float(index) / float(MOTION_SAMPLE_COUNT - 1)
		_add_sample_effect(viewport, packed, anchor, sample_time, 0.82)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport(viewport, capture_path, "twelve-timepoint motion")
	viewport.queue_free()
	await process_frame


func _capture_codex_integration_if_requested(packed: PackedScene) -> void:
	var capture_path := OS.get_environment("STORM_CHARGE_VFX_INTEGRATED_CAPTURE_PATH")
	if capture_path.is_empty():
		return
	var viewport := _make_review_viewport(Vector2i(960, 540))
	_add_codex_cell(viewport, Rect2(Vector2.ZERO, Vector2(960.0, 540.0)), 0)
	var anchor := Vector2(480.0, 421.2)
	_add_codex_player(viewport, anchor)
	_add_sample_effect(viewport, packed, anchor, 0.80, 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport(viewport, capture_path, "Codex integration")
	viewport.queue_free()
	await process_frame


func _make_review_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#10171A")
	background.size = Vector2(viewport_size)
	background.z_index = -100
	viewport.add_child(background)
	return viewport


func _add_codex_cell(viewport: SubViewport, rect: Rect2, index: int) -> void:
	var panel := ColorRect.new()
	panel.position = rect.position + Vector2(2.0, 2.0)
	panel.size = rect.size - Vector2(4.0, 4.0)
	panel.color = Color("#10171A") if index % 2 == 0 else Color("#11191D")
	panel.z_index = -90
	viewport.add_child(panel)
	var floor_y := rect.position.y + rect.size.y * 0.78
	for line_index in 5:
		var guide := Line2D.new()
		var y := rect.position.y + rect.size.y * (0.2 + float(line_index) * 0.11)
		guide.points = PackedVector2Array([Vector2(rect.position.x, y), Vector2(rect.end.x, y)])
		guide.width = 1.0
		guide.default_color = Color(0.2, 0.28, 0.27, 0.18)
		guide.z_index = -82
		viewport.add_child(guide)
	var floor := ColorRect.new()
	floor.position = Vector2(rect.position.x, floor_y)
	floor.size = Vector2(rect.size.x, rect.end.y - floor_y)
	floor.color = Color("#24231E")
	floor.z_index = -80
	viewport.add_child(floor)
	var ground_line := Line2D.new()
	ground_line.points = PackedVector2Array([Vector2(rect.position.x, floor_y), Vector2(rect.end.x, floor_y)])
	ground_line.width = 2.0
	ground_line.default_color = Color("#96743D")
	ground_line.z_index = -79
	viewport.add_child(ground_line)


func _add_codex_player(viewport: SubViewport, anchor: Vector2, scale_multiplier: float = 1.0) -> void:
	var texture := load(PLAYER_TEXTURE_PATH) as Texture2D
	_expect(texture != null, "Codex integration capture requires the actual player idle texture.")
	if texture == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, 0.0, texture.get_width() / 4.0, texture.get_height())
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = "ActualCodexPlayer"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = atlas
	# Match InventoryCodexPreview._draw_character(): the selected frame is
	# centered at preview floor minus 39px and rendered at uniform 2.5x scale.
	sprite.position = anchor + Vector2(0.0, -39.0) * scale_multiplier
	sprite.scale = Vector2.ONE * 2.5 * scale_multiplier
	sprite.z_index = 0
	viewport.add_child(sprite)


func _add_sample_effect(
	viewport: SubViewport,
	packed: PackedScene,
	anchor: Vector2,
	sample_time: float,
	visual_scale: float
) -> Node2D:
	var effect := packed.instantiate() as Node2D
	viewport.add_child(effect)
	effect.position = anchor
	effect.scale = Vector2.ONE * visual_scale
	effect.call("configure", 3)
	effect.call("play")
	effect.call("debug_set_elapsed", sample_time)
	(effect.get_node("BackLayer/BackParticles") as CPUParticles2D).emitting = false
	(effect.get_node("ChargeParticles") as CPUParticles2D).emitting = false
	(effect.get_node("ResidualParticles") as CPUParticles2D).emitting = false
	return effect


func _save_viewport(viewport: SubViewport, path: String, label: String) -> void:
	var image := viewport.get_texture().get_image()
	_expect(not image.is_empty(), "Storm Charge %s capture must produce pixels." % label)
	if not image.is_empty():
		_expect(image.save_png(path) == OK, "Storm Charge %s capture must save to %s." % [label, path])
