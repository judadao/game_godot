extends SceneTree

const ICE_ULTIMATE_SCENE := preload("res://scenes/combat/vfx/IceUltimateVFX.tscn")
const EXPECTED_CLOSING_ORDER := [
	&"impact_snap",
	&"cohesive_decay",
	&"tail_hold",
]
const EXPECTED_DECAY_RATIO := 0.18
const EXPECTED_TAIL_RATIO := 0.12
const EXPECTED_ICE_IMPACT_START := 0.67
const EXPECTED_ICE_DECAY_START := 0.83

var _failures := 0
var _observed_stages: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var effect := ICE_ULTIMATE_SCENE.instantiate()
	root.add_child(effect)
	await process_frame

	_expect(effect is Node2D, "Ice ultimate VFX must use a reusable Node2D root.")
	_expect(effect.has_method("play"), "Ice ultimate VFX must expose play().")
	_expect(effect.has_method("get_max_radius"), "Ice ultimate VFX must expose its maximum radius.")
	_expect(effect.has_method("get_crystal_count"), "Ice ultimate VFX must expose its crystal count.")
	_expect(effect.has_method("get_shard_count"), "Ice ultimate VFX must expose its bounded shatter count.")
	_expect(effect.has_method("get_visual_budget"), "Ice ultimate VFX must expose its bounded visual budget.")
	_expect(effect.has_method("get_stage_name"), "Ice ultimate VFX must expose its current animation stage.")
	_expect(effect.has_method("get_readability_hole_radius"), "Ice ultimate VFX must expose its player readability area.")
	_expect(effect.has_method("get_visual_bounds_radius"), "Ice ultimate VFX must expose its visual bounds.")
	_expect(
		effect.has_method("get_closing_stage_order")
			and effect.has_method("get_post_impact_decay_ratio")
			and effect.has_method("get_tail_hold_ratio")
			and effect.has_method("get_closing_stage_name")
			and effect.has_method("debug_set_tail_hold_progress")
			and effect.has_method("get_impact_start_progress_ratio")
			and effect.has_method("get_cohesive_decay_start_progress_ratio")
			and effect.has_method("uses_unscaled_timeline"),
		"Ice ultimate must expose the shared impact/decay/tail closing rhythm diagnostics."
	)
	_expect(
		bool(effect.call("uses_unscaled_timeline")),
		"Ice ultimate timing must stay aligned with real-time shatter presentation during slow motion."
	)
	_expect(effect.has_signal("stage_changed"), "Ice ultimate VFX must announce each readable animation stage.")
	_expect(effect.get_node_or_null("FrostRings/OuterRing") is Line2D, "The expanding freeze needs an authored outer ice ring.")
	_expect(effect.get_node_or_null("FrostRings/InnerRing") is Line2D, "The expanding freeze needs an authored inner ice ring.")
	_expect(effect.get_node_or_null("GroundFrost") is Polygon2D, "The frozen ground needs an authored Polygon2D wash.")
	_expect(effect.get_node_or_null("ColdMist") is GPUParticles2D, "The ultimate needs bounded GPU cold mist.")
	_expect(effect.get_node_or_null("Crystals") is Node2D, "Ice crystal rises need a dedicated visual owner.")
	_expect(effect.get_node_or_null("ShatterFragments") is Node2D, "Shatter fragments need a dedicated bounded owner.")
	_expect(effect.get_node_or_null("HighlightRing") is Line2D, "The shatter beat needs an authored highlight ring.")
	_expect(effect.get_node_or_null("CenterReadability") is Polygon2D, "The player needs a dedicated readability mask.")

	effect.set("radius", 360.0)
	effect.set("intensity", 0.75)
	effect.set("duration", 0.5)
	effect.connect("stage_changed", _on_stage_changed)
	effect.call("play")
	await process_frame

	_expect(bool(effect.get("active")), "play() must expose the active lifecycle state.")
	_expect(
		StringName(effect.call("get_stage_name")) == &"anticipation",
		"The ultimate must begin with a readable anticipation beat."
	)
	_expect(
		is_equal_approx(float(effect.call("get_max_radius")), 360.0),
		"Maximum radius must match the configured gameplay presentation radius."
	)
	var crystal_count := int(effect.call("get_crystal_count"))
	_expect(crystal_count >= 10 and crystal_count <= 40, "Intensity must scale crystals within a controlled budget.")
	_expect(
		(effect.get_node("ColdMist") as GPUParticles2D).amount <= 96,
		"Cold mist particle count must remain performance bounded."
	)
	var shard_count := int(effect.call("get_shard_count"))
	_expect(shard_count >= 12 and shard_count <= 64, "Shatter fragments must use a controlled visual budget.")
	var visual_budget := int(effect.call("get_visual_budget"))
	_expect(visual_budget > crystal_count, "The visual budget must include crystals, shatter, and mist.")
	_expect(visual_budget <= 200, "The full-screen ultimate must remain bounded to 200 dynamic visuals.")
	_expect(
		float(effect.call("get_readability_hole_radius")) >= 56.0,
		"The full-screen freeze must preserve a readable center around the player."
	)
	_expect(
		float(effect.call("get_visual_bounds_radius"))
			<= float(effect.call("get_max_radius")) * 1.15,
		"Every ice layer must stay inside a reusable bounded radius."
	)
	_expect(
		(effect.call("get_closing_stage_order") as Array) == EXPECTED_CLOSING_ORDER
			and is_equal_approx(float(effect.call("get_post_impact_decay_ratio")), EXPECTED_DECAY_RATIO)
			and is_equal_approx(float(effect.call("get_tail_hold_ratio")), EXPECTED_TAIL_RATIO),
		"Ice ultimate closing cadence must match the shared impact snap, cohesive decay, and tail hold contract."
	)
	_expect(
		is_equal_approx(float(effect.call("get_impact_start_progress_ratio")), EXPECTED_ICE_IMPACT_START)
			and is_equal_approx(float(effect.call("get_cohesive_decay_start_progress_ratio")), EXPECTED_ICE_DECAY_START),
		"Ice ultimate must expose its real contact and closing transition timing for synced defeat/trail presentation."
	)
	effect.call("debug_set_progress", 0.74)
	_expect(
		StringName(effect.call("get_closing_stage_name")) == &"impact_snap",
		"Ice shatter highlight must read as the shared impact snap."
	)
	effect.call("debug_set_progress", 0.92)
	_expect(
		StringName(effect.call("get_closing_stage_name")) == &"cohesive_decay",
		"Ice cold mist decay must read as the shared cohesive decay."
	)
	effect.call("debug_set_tail_hold_progress", 0.5)
	_expect(
		StringName(effect.call("get_closing_stage_name")) == &"tail_hold",
		"Ice post-decay mist linger must read as the shared tail hold."
	)

	await create_timer(0.75).timeout
	_expect(not is_instance_valid(effect), "The played ice ultimate must release itself after its visual tail.")
	_expect(
		_observed_stages == [
			&"anticipation",
			&"radial_freeze",
			&"crystal_eruption",
			&"shatter_highlight",
			&"cold_mist_decay",
		],
		"The animation must preserve anticipation -> radial freeze -> crystal eruption -> shatter/highlight -> cold mist decay."
	)
	await _capture_if_requested()

	if _failures == 0:
		print("PASS: staged reusable ice ultimate VFX contract")
	quit(1 if _failures > 0 else 0)


func _on_stage_changed(stage_name: StringName) -> void:
	if _observed_stages.is_empty() or _observed_stages.back() != stage_name:
		_observed_stages.append(stage_name)


func _capture_if_requested() -> void:
	var capture_path := OS.get_environment("ICE_ULTIMATE_CAPTURE_PATH")
	if capture_path.is_empty():
		return
	var capture_effect := ICE_ULTIMATE_SCENE.instantiate()
	root.add_child(capture_effect)
	capture_effect.position = Vector2(640.0, 360.0)
	capture_effect.set("radius", 320.0)
	capture_effect.set("intensity", 1.0)
	capture_effect.set("duration", 2.0)
	capture_effect.call("play")
	var capture_progress := 0.74
	var requested_progress := OS.get_environment("ICE_ULTIMATE_CAPTURE_PROGRESS")
	if not requested_progress.is_empty():
		capture_progress = clampf(requested_progress.to_float(), 0.0, 0.999)
	capture_effect.call("debug_set_progress", capture_progress)
	capture_effect.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	_expect(
		capture.save_png(capture_path) == OK,
		"Ice ultimate visual capture must save successfully to %s." % capture_path
	)
	capture_effect.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
