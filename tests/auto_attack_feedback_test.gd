extends SceneTree

const FEEDBACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")
const GENERATED_STAGE_ASSETS := [
	"res://assets/generated/vfx/basic_attack_release_sheet_v2.png",
	"res://assets/generated/vfx/basic_attack_release_mask_v2.png",
	"res://assets/generated/vfx/basic_attack_travel_sheet_v2.png",
	"res://assets/generated/vfx/basic_attack_travel_mask_v2.png",
	"res://assets/generated/vfx/basic_attack_impact_sheet_v2.png",
	"res://assets/generated/vfx/basic_attack_impact_mask_v2.png",
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
	for asset_path in MODULAR_PART_ASSETS:
		_expect(
			FileAccess.file_exists(asset_path),
			"Basic Attack must keep inspectable modular 2D VFX part sheets: %s."
				% asset_path
		)
	var feedback := FEEDBACK_SCENE.instantiate()
	root.add_child(feedback)
	await process_frame
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
		float(feedback.call("get_travel_duration")) <= 0.23
			and float(feedback.call("get_impact_duration")) <= 0.25,
		"Basic Attack presentation must stay fast enough to read as a sharp sword wave."
	)
	await create_timer(0.55).timeout
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
			"elements": ["flame", "frost", "storm", "venom"],
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
			and int(feedback.call("get_element_emphasis_pass_count")) == 8,
		"Each elemental infusion must receive two explicit silhouette emphasis passes."
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
			0.22,
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
