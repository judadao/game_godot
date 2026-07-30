extends SceneTree

const VFX_SCENE_PATH := "res://scenes/combat/vfx/FireUltimateVFX.tscn"
const PLAYER_TEXTURE_PATH := "res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png"
const EXPECTED_STAGES := [
	&"anticipation",
	&"ignition",
	&"expanding_inferno",
	&"impact_crown",
	&"ember_decay",
]
const STAGE_SAMPLE_PROGRESS := [0.08, 0.22, 0.48, 0.74, 0.92]
const MAX_PARTICLE_BUDGET := 256
const EXPECTED_CLOSING_ORDER := [
	&"impact_snap",
	&"cohesive_decay",
	&"tail_hold",
]
const EXPECTED_DECAY_RATIO := 0.18
const EXPECTED_TAIL_RATIO := 0.12
const EXPECTED_FIRE_IMPACT_START := 0.68
const EXPECTED_FIRE_DECAY_START := 0.82

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(VFX_SCENE_PATH) as PackedScene
	_expect(packed != null, "Fire ultimate VFX scene must load from its reusable path.")
	if packed == null:
		quit(1)
		return

	var effect := packed.instantiate() as Node2D
	_expect(
		not (effect.get_node("FlamePillars") as GPUParticles2D).emitting
			and not (effect.get_node("EmberSparks") as GPUParticles2D).emitting,
		"Fire ultimate particles must be authored inactive before play()."
	)
	root.add_child(effect)
	await process_frame

	_expect(effect != null, "Fire ultimate VFX root must be Node2D.")
	_expect(
		effect.get_node_or_null("ScorchedGround") is Polygon2D,
		"Fire ultimate VFX must author a Polygon2D scorched-ground layer."
	)
	_expect(
		effect.get_node_or_null("FireWaves/OuterWave") is Line2D,
		"Fire ultimate VFX must author reusable Line2D fire-wave geometry."
	)
	_expect(
		effect.get_node_or_null("AnticipationGuide") is Line2D
			and effect.get_node_or_null("ImpactCrown") is Line2D,
		"Fire ultimate VFX must author distinct anticipation and impact-crown guides."
	)
	_expect(
		effect.get_node_or_null("FlamePillars") is GPUParticles2D
			and effect.get_node_or_null("EmberSparks") is GPUParticles2D,
		"Fire ultimate VFX must use bounded GPU particle systems for pillars and sparks."
	)
	_expect(
		effect.has_method("get_closing_stage_order")
			and effect.has_method("get_post_impact_decay_ratio")
			and effect.has_method("get_tail_hold_ratio")
			and effect.has_method("get_closing_stage_name")
			and effect.has_method("debug_set_tail_hold_progress")
			and effect.has_method("get_impact_start_progress_ratio")
			and effect.has_method("get_cohesive_decay_start_progress_ratio")
			and effect.has_method("uses_unscaled_timeline"),
		"Fire ultimate must expose the shared impact/decay/tail closing rhythm diagnostics."
	)
	_expect(
		bool(effect.call("uses_unscaled_timeline")),
		"Fire ultimate timing must stay aligned with real-time impact presentation during slow motion."
	)
	_expect(not bool(effect.call("is_active")), "Fire ultimate VFX must remain inactive before play().")

	effect.set("radius", 480.0)
	effect.set("intensity", 1.4)
	effect.set("duration", 0.3)
	effect.call("play", Vector2(320.0, 240.0))
	_expect(bool(effect.call("is_active")), "play() must expose an active runtime state.")
	_expect(
		is_equal_approx(float(effect.call("get_max_radius")), 480.0),
		"Maximum radius query must reflect the configured ultimate radius."
	)
	_expect(
		int(effect.call("get_ring_count")) >= 3,
		"Fire ultimate must project multiple outward fire-wave rings."
	)
	_expect(
		float(effect.call("get_readability_hole_radius")) >= 40.0,
		"Fire ultimate must preserve a readable center around the player."
	)
	_expect(
		float(effect.call("get_visual_bounds_radius"))
			<= float(effect.call("get_max_radius")) * 1.22,
		"Fire ultimate must keep every authored layer inside a bounded visual radius."
	)
	_expect(
		int(effect.call("get_particle_budget")) <= MAX_PARTICLE_BUDGET,
		"Fire ultimate GPU particles must stay inside the reusable effect budget."
	)
	_expect(
		effect.global_position.is_equal_approx(Vector2(320.0, 240.0)),
		"play(center) must place the reusable effect at the requested world center."
	)

	var capture_path := OS.get_environment("FIRE_ULTIMATE_VFX_CAPTURE_PATH")
	if not capture_path.is_empty():
		await _capture_impact_frame(effect, capture_path)

	for sample_index in STAGE_SAMPLE_PROGRESS.size():
		effect.call("debug_set_progress", STAGE_SAMPLE_PROGRESS[sample_index])
		_expect(
			StringName(effect.call("get_stage_name")) == EXPECTED_STAGES[sample_index],
			"Fire ultimate progress %.2f must resolve to the %s stage."
				% [STAGE_SAMPLE_PROGRESS[sample_index], EXPECTED_STAGES[sample_index]]
		)
	_expect(
		(effect.call("get_closing_stage_order") as Array) == EXPECTED_CLOSING_ORDER
			and is_equal_approx(float(effect.call("get_post_impact_decay_ratio")), EXPECTED_DECAY_RATIO)
			and is_equal_approx(float(effect.call("get_tail_hold_ratio")), EXPECTED_TAIL_RATIO),
		"Fire ultimate closing cadence must match the shared impact snap, cohesive decay, and tail hold contract."
	)
	_expect(
		is_equal_approx(float(effect.call("get_impact_start_progress_ratio")), EXPECTED_FIRE_IMPACT_START)
			and is_equal_approx(float(effect.call("get_cohesive_decay_start_progress_ratio")), EXPECTED_FIRE_DECAY_START),
		"Fire ultimate must expose its real contact and closing transition timing for synced defeat/trail presentation."
	)
	effect.call("debug_set_progress", 0.74)
	_expect(
		StringName(effect.call("get_closing_stage_name")) == &"impact_snap",
		"Fire ultimate impact crown must read as the shared impact snap."
	)
	effect.call("debug_set_progress", 0.92)
	_expect(
		StringName(effect.call("get_closing_stage_name")) == &"cohesive_decay",
		"Fire ultimate ember decay must read as the shared cohesive decay."
	)
	effect.call("debug_set_tail_hold_progress", 0.5)
	_expect(
		StringName(effect.call("get_closing_stage_name")) == &"tail_hold",
		"Fire ultimate post-decay particle linger must read as the shared tail hold."
	)

	effect.set("duration", 0.3)
	effect.call("play", Vector2(360.0, 260.0))
	_expect(
		effect.global_position.is_equal_approx(Vector2(360.0, 260.0))
			and StringName(effect.call("get_stage_name")) == &"anticipation",
		"Replaying the reusable effect must restart anticipation at the new center."
	)

	await create_timer(0.8).timeout
	_expect(
		not is_instance_valid(effect),
		"Fire ultimate VFX must release itself after its visual tail completes."
	)

	if _failures == 0:
		print("PASS: reusable fire ultimate VFX contract and lifecycle")
	quit(1 if _failures > 0 else 0)


func _capture_impact_frame(effect: Node2D, capture_path: String) -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("#101417")
	background.size = Vector2(1280.0, 720.0)
	background.z_index = -100
	root.add_child(background)
	var floor := ColorRect.new()
	floor.color = Color("#24231e")
	floor.position = Vector2(0.0, 475.0)
	floor.size = Vector2(1280.0, 245.0)
	floor.z_index = -90
	root.add_child(floor)
	var player := Sprite2D.new()
	player.texture = load(PLAYER_TEXTURE_PATH) as Texture2D
	player.hframes = 4
	player.frame = 0
	player.position = Vector2(640.0, 438.0)
	player.scale = Vector2(3.0, 3.0)
	player.z_index = 60
	root.add_child(player)

	effect.set("radius", 420.0)
	effect.set("intensity", 1.8)
	effect.set("duration", 1.2)
	effect.call("play", player.position)
	await create_timer(0.89).timeout
	await RenderingServer.frame_post_draw
	_expect(
		root.get_texture().get_image().save_png(capture_path) == OK,
		"Fire ultimate impact capture must save to %s." % capture_path
	)

	player.queue_free()
	floor.queue_free()
	background.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
