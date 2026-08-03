extends SceneTree

const FEEDBACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")
const GENERATED_STAGE_ASSETS := [
	"res://assets/generated/vfx/basic_attack_release_sheet_v2.png",
	"res://assets/generated/vfx/basic_attack_release_mask_v2.png",
	"res://assets/generated/vfx/basic_attack_travel_sheet_v2.png",
	"res://assets/generated/vfx/basic_attack_travel_mask_v2.png",
	"res://assets/generated/vfx/basic_attack_impact_sheet_v2.png",
	"res://assets/generated/vfx/basic_attack_impact_mask_v2.png",
	"res://assets/generated/vfx/basic_attack_crescent_quality_atlas_v3.png",
]
const MODULAR_PART_ASSETS := [
	"res://assets/generated/vfx/parts/basic_attack_release_core_blade_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_release_crescent_edge_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_release_afterimage_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_release_shards_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_travel_core_blade_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_travel_crescent_edge_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_travel_afterimage_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_travel_shards_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_impact_core_blade_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_impact_crescent_edge_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_impact_impact_wedge_sheet_v2.png",
	"res://assets/generated/vfx/parts/basic_attack_impact_shards_sheet_v2.png",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for asset_path in GENERATED_STAGE_ASSETS:
		_expect(
			ResourceLoader.exists(asset_path),
			"Every generated Basic Attack stage sheet and mask must remain available: %s."
				% asset_path
		)
	_expect(
		_frame_reads_as_forward_crescent(
			"res://assets/generated/vfx/parts/basic_attack_release_core_blade_sheet_v2.png",
			3
		),
		"Basic Attack release anticipation must open as a forward-facing crescent."
	)
	_expect(
		_frame_reads_as_forward_crescent(
			"res://assets/generated/vfx/parts/basic_attack_travel_core_blade_sheet_v2.png",
			3
		),
		"Basic Attack travel must preserve a hollow moon-crescent silhouette instead of an arrow or flame tail."
	)
	_expect(
		_frame_reads_as_forward_crescent(
			"res://assets/generated/vfx/parts/basic_attack_impact_core_blade_sheet_v2.png",
			4
		),
		"Basic Attack impact must bloom as the same forward-facing crescent."
	)
	for asset_path in MODULAR_PART_ASSETS:
		_expect(
			FileAccess.file_exists(asset_path),
			"Basic Attack must keep inspectable modular 2D VFX part sheets: %s."
				% asset_path
		)
	var feedback := FEEDBACK_SCENE.instantiate()
	root.add_child(feedback)
	await process_frame
	var impact_events: Array[Dictionary] = []
	feedback.impact_reached.connect(
		func(did_hit: bool, combo_tier: int) -> void:
			impact_events.append({
				"did_hit": did_hit,
				"combo_tier": combo_tier,
			})
	)
	feedback.play(Vector2(40.0, 40.0), Vector2(240.0, 40.0), 10, 0)
	_expect(
		(feedback.call("get_active_elements") as Array).is_empty()
			and int(feedback.call("get_visual_layer_count")) == 0,
		"Neutral Basic Attack must not carry flame/frost/storm/venom layers before a matching Combo infusion."
	)
	_expect(
		(feedback.call("get_modular_part_names") as Array) == [
			&"core_blade",
			&"crescent_edge",
			&"afterimage",
			&"shards",
			&"impact_wedge",
		],
		"Basic Attack sheets must be assembled from named 2D VFX parts."
	)
	_expect(
		float(feedback.call("get_travel_duration")) <= 0.16
			and float(feedback.call("get_impact_duration")) <= 0.20,
		"Basic Attack presentation must stay fast enough to read as a slash shockwave."
	)
	_expect(
		String(feedback.call("get_motion_profile")) == "slash_shockwave"
			and float(feedback.call("get_travel_distance_ratio_at_progress", 0.50)) >= 0.78,
		"Basic Attack must burst across most of its range immediately instead of accelerating like a missile."
	)
	_expect(
		feedback.has_method("get_animation_quality_profile")
			and feedback.call("get_animation_quality_profile") == &"premium_flowing_crescent",
		"Basic Attack animation must use the premium flowing-crescent timing profile."
	)
	_expect(
		feedback.has_method("get_premium_crescent_layer_names")
			and (feedback.call("get_premium_crescent_layer_names") as Array) == [
				&"outer_glow",
				&"moon_core",
				&"inner_current",
				&"flow_ribbons",
				&"ground_cut",
				&"spark_debris",
				&"contact_bloom",
			],
		"Premium sword waves must assemble distinct generated layers instead of moving one flat frame."
	)
	_expect(
		feedback.has_method("get_flow_ribbon_sample_count")
			and int(feedback.call("get_flow_ribbon_sample_count")) >= 3
			and feedback.has_method("get_crescent_deformation_sample_count")
			and int(feedback.call("get_crescent_deformation_sample_count")) >= 3,
		"Premium crescent animation needs independently timed flow ribbons and silhouette deformation."
	)
	_expect(
		feedback.has_method("get_temporal_afterimage_sample_count")
			and int(feedback.call("get_temporal_afterimage_sample_count")) >= 4
			and int(feedback.call("get_frame_interpolation_sample_count")) == 2,
		"Sword-wave travel needs at least four historical-position afterimages instead of one moving sticker."
	)
	_expect(
		feedback.has_method("get_travel_pose_scale")
			and (feedback.call("get_travel_pose_scale", 0.04) as Vector2).x < 0.90
			and (feedback.call("get_travel_pose_scale", 0.30) as Vector2).x > 1.0
			and not (feedback.call("get_travel_pose_scale", 0.04) as Vector2).is_equal_approx(
				feedback.call("get_travel_pose_scale", 0.30) as Vector2
			),
		"Sword-wave launch must visibly compress and snap open before settling."
	)
	_expect(
		feedback.has_method("get_impact_echo_count")
			and int(feedback.call("get_impact_echo_count")) >= 2
			and float(feedback.call("get_contact_flash_window")) <= 0.06,
		"Impact needs delayed sprite echoes and a short contact flash for a decisive hit."
	)
	await create_timer(0.55).timeout
	_expect(
		impact_events == [{"did_hit": true, "combo_tier": 0}],
		"Basic Attack must expose exactly one impact timing event for synchronized hit stop and camera shake."
	)
	_expect(not is_instance_valid(feedback), "Neutral Basic Attack feedback must clean itself up.")
	feedback = FEEDBACK_SCENE.instantiate()
	root.add_child(feedback)
	await process_frame
	feedback.play(
		Vector2(40.0, 80.0),
		Vector2(240.0, 80.0),
		24,
		6,
		8,
		false,
		1.5,
		1.4,
		{
			"stack_count": 6,
			"elements": ["fire", "ice", "lightning", "poison"],
			"lifesteal": true,
		}
	)
	_expect(feedback.is_in_group("AutoAttackFeedback"), "Attack feedback must be discoverable for runtime verification.")
	_expect(feedback.get_damage_text() == "-24", "Attack feedback must show actual applied damage.")
	_expect(
		feedback.get_combo_text().contains("COMBO ×6")
			and feedback.get_combo_text().contains("POWER +8"),
		"Attack feedback must make the active Combo power visible."
	)
	_expect(
		int(feedback.call("get_visual_layer_count")) >= 4
			and float(feedback.call("get_attack_scale")) > 1.4,
		"Stacked elemental Combo effects must add visible projectile layers and scale."
	)
	_expect(
		int(feedback.call("get_combo_visual_tier")) == 2,
		"Combo x6 must use the second distinct projectile and impact spectacle tier."
	)
	var active_elements := feedback.call("get_active_elements") as Array
	_expect(
		active_elements.has(&"flame")
			and active_elements.has(&"frost")
			and active_elements.has(&"storm")
			and active_elements.has(&"venom")
			and int(feedback.call("get_element_emphasis_pass_count")) == 8,
		"Formal fire, ice, lightning, and poison IDs must retain their internal silhouette emphasis layers."
	)
	_expect(
		int(feedback.call("get_combo_emphasis_pass_count")) >= 4,
		"Combo x6 must add a clearly layered attack-bound emphasis treatment."
	)
	_expect(
		(feedback.call("get_sword_wave_core_color") as Color).is_equal_approx(Color.WHITE),
		"Sword-wave core must stay white while elements flow around its silhouette."
	)
	_expect(
		int(feedback.call("get_energy_blade_frame_count")) == 8,
		"Sword-energy travel must use the complete eight-frame launch-to-dissipation sequence."
	)
	_expect(
		feedback.has_method("get_attack_presentation_stages")
			and (feedback.call("get_attack_presentation_stages") as Array) == [
				&"weapon_release",
				&"blade_travel",
				&"directional_impact",
			],
		"Basic Attack feedback must preserve the weapon release, blade travel, and directional impact beats."
	)
	_expect(
		feedback.has_method("get_generated_stage_frame_count")
			and int(feedback.call("get_generated_stage_frame_count", &"weapon_release")) == 8
			and int(feedback.call("get_generated_stage_frame_count", &"blade_travel")) == 8
			and int(feedback.call("get_generated_stage_frame_count", &"directional_impact")) == 8,
		"Every Basic Attack beat must use its complete generated eight-frame sequence."
	)
	_expect(
		feedback.has_method("get_primary_procedural_stroke_count")
			and int(feedback.call("get_primary_procedural_stroke_count")) == 0,
		"Generated sprites must replace geometric arcs, spokes, and line-based primary silhouettes."
	)
	var left_feedback := FEEDBACK_SCENE.instantiate()
	root.add_child(left_feedback)
	await process_frame
	left_feedback.play(Vector2(240.0, 120.0), Vector2(40.0, 120.0), 0, 0)
	_expect(
		(left_feedback.call("get_travel_offset") as Vector2).x < 0.0,
		"Sword waves must follow a left-facing attack target."
	)
	left_feedback.queue_free()
	var finisher_feedback := FEEDBACK_SCENE.instantiate()
	root.add_child(finisher_feedback)
	await process_frame
	finisher_feedback.play(
		Vector2(40.0, 160.0),
		Vector2(240.0, 160.0),
		32,
		9,
		12,
		false,
		1.0,
		1.0,
		{"finisher": true, "finisher_name": "流火照夜", "elements": ["fire"]}
	)
	_expect(
		bool(finisher_feedback.call("is_attack_geometry_suppressed"))
			and int(finisher_feedback.call("get_visual_layer_count")) == 0
			and not (finisher_feedback.get_node("PremiumCrescentLayer") as Node2D).visible,
		"A Finisher with its own authored action must suppress the generic sword-wave geometry."
	)
	finisher_feedback.queue_free()
	await create_timer(0.20).timeout
	_expect(
		(feedback.get_node("DamageLabel") as Label).visible
			and (feedback.get_node("ComboLabel") as Label).visible,
		"Damage and Combo labels must appear when the projectile reaches its target."
	)
	var capture_path := OS.get_environment("AUTO_ATTACK_FEEDBACK_CAPTURE_PATH")
	if not capture_path.is_empty():
		feedback.visible = false
		var capture_feedback := FEEDBACK_SCENE.instantiate()
		root.add_child(capture_feedback)
		await process_frame
		var capture_element := OS.get_environment(
			"AUTO_ATTACK_FEEDBACK_CAPTURE_ELEMENT"
		).strip_edges().to_lower()
		var capture_elements: Array[String] = []
		if not capture_element.is_empty():
			capture_elements.append(capture_element)
		var capture_combo := int(OS.get_environment(
			"AUTO_ATTACK_FEEDBACK_CAPTURE_COMBO"
		))
		capture_feedback.play(
			Vector2(180.0, 220.0),
			Vector2(620.0, 220.0),
			0,
			capture_combo,
			0,
			false,
			1.0,
			2.0,
			{"elements": capture_elements}
		)
		var capture_delay := float(OS.get_environment(
			"AUTO_ATTACK_FEEDBACK_CAPTURE_DELAY"
		))
		if capture_delay <= 0.0:
			capture_delay = 0.42
		await create_timer(capture_delay).timeout
		await RenderingServer.frame_post_draw
		_expect(
			root.get_texture().get_image().save_png(capture_path) == OK,
			"Auto Attack feedback visual capture must save."
		)
		capture_feedback.queue_free()
	await create_timer(0.4).timeout
	_expect(not is_instance_valid(feedback), "Short combat feedback must clean itself up.")
	if _failures == 0:
		print("PASS: visible Basic Attack travel, hit, damage, and Combo feedback")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _frame_alpha_aspect(asset_path: String, frame_index: int) -> float:
	var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
	if image == null or image.is_empty():
		return 0.0
	var frame_width := int(image.get_width() / 8)
	var start_x := clampi(frame_index, 0, 7) * frame_width
	var min_x := frame_width
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in frame_width:
			if image.get_pixel(start_x + x, y).a <= 0.03:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return 0.0
	return float(max_x - min_x + 1) / maxf(1.0, float(max_y - min_y + 1))


func _frame_reads_as_forward_crescent(asset_path: String, frame_index: int) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
	if image == null or image.is_empty():
		return false
	var frame_width := int(image.get_width() / 8)
	var start_x := clampi(frame_index, 0, 7) * frame_width
	var bounds := _frame_alpha_bounds(image, start_x, frame_width)
	if bounds.size.x < 40.0 or bounds.size.y < 40.0:
		return false
	var aspect := bounds.size.x / bounds.size.y
	if aspect < 0.90 or aspect > 2.20:
		return false
	var leading_center := _alpha_coverage(
		image,
		start_x,
		bounds,
		Rect2(0.66, 0.36, 0.30, 0.28)
	)
	var hollow_center := _alpha_coverage(
		image,
		start_x,
		bounds,
		Rect2(0.18, 0.36, 0.30, 0.28)
	)
	var upper_arm := _alpha_coverage(
		image,
		start_x,
		bounds,
		Rect2(0.06, 0.02, 0.52, 0.28)
	)
	var lower_arm := _alpha_coverage(
		image,
		start_x,
		bounds,
		Rect2(0.06, 0.70, 0.52, 0.28)
	)
	return (
		leading_center >= 0.18
		and hollow_center <= leading_center * 0.46
		and upper_arm >= 0.025
		and lower_arm >= 0.025
	)


func _frame_alpha_bounds(image: Image, start_x: int, frame_width: int) -> Rect2:
	var min_x := frame_width
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in frame_width:
			if image.get_pixel(start_x + x, y).a <= 0.08:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2()
	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x + 1, max_y - min_y + 1)
	)


func _alpha_coverage(
	image: Image,
	start_x: int,
	bounds: Rect2,
	normalized_zone: Rect2
) -> float:
	var zone_start := bounds.position + bounds.size * normalized_zone.position
	var zone_size := bounds.size * normalized_zone.size
	var min_x := clampi(floori(zone_start.x), 0, int(bounds.end.x) - 1)
	var min_y := clampi(floori(zone_start.y), 0, int(bounds.end.y) - 1)
	var max_x := clampi(ceili(zone_start.x + zone_size.x), min_x + 1, int(bounds.end.x))
	var max_y := clampi(ceili(zone_start.y + zone_size.y), min_y + 1, int(bounds.end.y))
	var visible := 0
	var total := maxi(1, (max_x - min_x) * (max_y - min_y))
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			if image.get_pixel(start_x + x, y).a > 0.08:
				visible += 1
	return float(visible) / float(total)
