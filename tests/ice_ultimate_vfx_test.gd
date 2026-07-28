extends SceneTree

const ICE_ULTIMATE_SCENE := preload("res://scenes/combat/vfx/IceUltimateVFX.tscn")

var _failures := 0


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
	_expect(effect.get_node_or_null("FrostRings/OuterRing") is Line2D, "The expanding freeze needs an authored outer ice ring.")
	_expect(effect.get_node_or_null("FrostRings/InnerRing") is Line2D, "The expanding freeze needs an authored inner ice ring.")
	_expect(effect.get_node_or_null("GroundFrost") is Polygon2D, "The frozen ground needs an authored Polygon2D wash.")
	_expect(effect.get_node_or_null("ColdMist") is GPUParticles2D, "The ultimate needs bounded GPU cold mist.")
	_expect(effect.get_node_or_null("Crystals") is Node2D, "Ice crystal rises need a dedicated visual owner.")

	effect.set("radius", 360.0)
	effect.set("intensity", 0.75)
	effect.set("duration", 0.18)
	effect.call("play")
	await process_frame

	_expect(bool(effect.get("active")), "play() must expose the active lifecycle state.")
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

	await create_timer(0.4).timeout
	_expect(not is_instance_valid(effect), "The played ice ultimate must release itself after its visual tail.")

	if _failures == 0:
		print("PASS: reusable expanding ice ultimate VFX contract")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
