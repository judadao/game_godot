extends SceneTree

const VFX_SCENE := preload("res://scenes/vfx/skills/MoonWheelBounceMaterialVFX2D.tscn")
const WHEEL_TEXTURE := preload("res://assets/generated/vfx/skill_series/moon_wheel.png")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var wheels: Array[Sprite2D] = []
	for index in 5:
		var wheel := Sprite2D.new()
		wheel.name = "Wheel%02d" % index
		wheel.texture = WHEEL_TEXTURE
		wheel.scale = Vector2.ONE * 0.08
		host.add_child(wheel)
		wheels.append(wheel)
	var effect := VFX_SCENE.instantiate() as Node2D
	host.add_child(effect)
	await process_frame
	effect.call("configure", wheels, 1, [Color("fffbe2"), Color("a8c9ff"), Color("7162d8")], {
		"wheel_count": 5,
		"round_trip_count": 1,
		"radius": 420.0,
	})

	_expect(_count_line_nodes(effect) == 0, "Moon Wheel must not draw visible trajectory or rebound guide lines.")
	var initial := effect.call("get_debug_state") as Dictionary
	_expect(String(initial.get("motion_model", "")) == "bounded_pinball_reflection", "Moon Wheel must identify its motion as bounded pinball reflection, not a shared windshield-wiper arc.")
	_expect((initial.get("rhythm_beats", []) as Array) == ["materialize", "accelerate", "wall_contact", "rebound_release", "residual_dissolve"], "Moon Wheel needs a staged anticipation, contact, rebound, and dissolve cadence.")
	_expect(int(initial.get("material_layer_count", 0)) >= 5, "Moon Wheel needs core, aura, afterimage, contact, and residual layers.")
	var aura := effect.get_node_or_null("MoonAura00") as Sprite2D
	_expect(aura != null and aura.material is ShaderMaterial, "Every Moon Wheel needs a shader-driven energy aura around the concrete crescent body.")
	_expect(_count_named_children(effect, "MoonBloom") == 5, "Every basic Moon Wheel needs its own following bloom light instead of sharing one stationary glow.")
	_expect(int(initial.get("per_wheel_glow_layer_count", 0)) >= 2, "Each Moon Wheel needs both a close energy aura and a broader bloom light.")
	_expect(_count_named_children(effect, "MoonEcho") == 10, "Five basic Moon Wheels need exactly two short material afterimages each.")
	var motes := effect.get_node_or_null("ContactMotes") as GPUParticles2D
	_expect(motes != null and motes.process_material is ParticleProcessMaterial, "Moon Wheel rebounds need a pooled particle debris layer.")
	_expect(int(initial.get("particle_emitter_pool_size", 0)) == 5, "Basic Moon Wheel needs one bounded contact-particle emitter per simultaneous wheel.")

	effect.call("set_progress", 0.28)
	var before := _positions(wheels)
	var first_bloom := effect.get_node_or_null("MoonBloom00") as Sprite2D
	_expect(first_bloom != null and first_bloom.position.distance_to(wheels[0].position) < 0.1, "A Moon Wheel's bloom light must follow the wheel body exactly.")
	var first_echo := effect.get_node_or_null("MoonEcho00_0") as Sprite2D
	_expect(first_echo != null and is_equal_approx(first_echo.modulate.a, 1.0), "Afterimage alpha must be owned by its shader exactly once.")
	_expect(first_echo != null and first_echo.position.distance_to(wheels[0].position) <= 58.0, "The first material echo must remain a short body trail measured in world distance.")
	effect.call("set_progress", 0.34)
	var after := _positions(wheels)
	var moving_left := false
	var moving_right := false
	var vertical_delta_count := 0
	for index in mini(before.size(), after.size()):
		var delta: Vector2 = after[index] - before[index]
		moving_left = moving_left or delta.x < -1.0
		moving_right = moving_right or delta.x > 1.0
		vertical_delta_count += 1 if absf(delta.y) > 1.0 else 0
	_expect(moving_left and moving_right, "Separated Moon Wheels must travel in opposing reflected directions instead of sweeping as one synchronized row.")
	_expect(vertical_delta_count >= 3, "Moon Wheels must visibly ricochet across both axes like pinballs.")

	effect.call("set_progress", 0.5)
	var contact := effect.call("get_debug_state") as Dictionary
	_expect(int(contact.get("active_rebound_flash_count", 0)) > 0, "Boundary contact must produce a short rebound flash beat.")
	_expect(int(contact.get("visible_trajectory_line_count", -1)) == 0, "Moon Wheel diagnostics must guarantee that no trajectory line is rendered.")

	for frame in 121:
		effect.call("set_progress", float(frame) / 120.0)
	var completed := effect.call("get_debug_state") as Dictionary
	var particle_trigger_count := int(completed.get("particle_trigger_count", 0))
	_expect(particle_trigger_count == 10, "Five basic Moon Wheels must each trigger exactly two horizontal rebound particle beats.")
	_expect((completed.get("afterimage_world_distances", []) as Array) == [22.0, 44.0], "All tiers must author short afterimages by fixed world distance rather than normalized timeline delay.")

	# Reflection apexes are the failure case for instantaneous-speed sampling: the
	# before/after velocity cancels at the corner and stretches the echo far away.
	var advanced_host := Node2D.new()
	root.add_child(advanced_host)
	var advanced_wheels := _make_wheels(advanced_host, 8)
	var advanced_effect := VFX_SCENE.instantiate() as Node2D
	advanced_host.add_child(advanced_effect)
	await process_frame
	advanced_effect.call("configure", advanced_wheels, 2, [Color("fffbe2"), Color("a8c9ff"), Color("7162d8")], {
		"wheel_count": 8,
		"round_trip_count": 2,
		"radius": 470.0,
	})
	for sample_progress in [0.50, 0.5152, 0.72]:
		advanced_effect.call("set_progress", sample_progress)
		for wheel_index in advanced_wheels.size():
			var core := advanced_wheels[wheel_index]
			var close_echo := advanced_effect.get_node_or_null("MoonEcho%02d_0" % wheel_index) as Sprite2D
			var far_echo := advanced_effect.get_node_or_null("MoonEcho%02d_1" % wheel_index) as Sprite2D
			_expect(close_echo != null and close_echo.position.distance_to(core.position) <= 28.0, "Close Moon Wheel light echo must stay attached across a reflection apex.")
			_expect(far_echo != null and far_echo.position.distance_to(core.position) <= 52.0, "Far Moon Wheel light echo must follow the reflected path instead of stretching at a corner.")
	advanced_host.queue_free()

	host.queue_free()
	await process_frame
	_finish()


func _positions(wheels: Array[Sprite2D]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for wheel in wheels:
		result.append(wheel.position)
	return result


func _make_wheels(host: Node2D, count: int) -> Array[Sprite2D]:
	var wheels: Array[Sprite2D] = []
	for index in count:
		var wheel := Sprite2D.new()
		wheel.name = "Wheel%02d" % index
		wheel.texture = WHEEL_TEXTURE
		wheel.scale = Vector2.ONE * 0.08
		host.add_child(wheel)
		wheels.append(wheel)
	return wheels


func _count_line_nodes(node: Node) -> int:
	var count := 1 if node is Line2D else 0
	for child in node.get_children():
		count += _count_line_nodes(child)
	return count


func _count_named_children(node: Node, prefix: String) -> int:
	var count := 0
	for child in node.get_children():
		if String(child.name).begins_with(prefix):
			count += 1
	return count


func _finish() -> void:
	if _failures == 0:
		print("PASS: Moon Wheel uses layered material pinball rebounds without trajectory lines")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
