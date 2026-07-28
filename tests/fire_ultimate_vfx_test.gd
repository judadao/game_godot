extends SceneTree

const VFX_SCENE_PATH := "res://scenes/combat/vfx/FireUltimateVFX.tscn"

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
		effect.get_node_or_null("FlamePillars") is GPUParticles2D
			and effect.get_node_or_null("EmberSparks") is GPUParticles2D,
		"Fire ultimate VFX must use bounded GPU particle systems for pillars and sparks."
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
		effect.global_position.is_equal_approx(Vector2(320.0, 240.0)),
		"play(center) must place the reusable effect at the requested world center."
	)

	await create_timer(0.8).timeout
	_expect(
		not is_instance_valid(effect),
		"Fire ultimate VFX must release itself after its visual tail completes."
	)

	if _failures == 0:
		print("PASS: reusable fire ultimate VFX contract and lifecycle")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
