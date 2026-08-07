extends SceneTree

const SERIES_VFX_SCENE := preload("res://scenes/vfx/skills/ResidualLightningMaterialVFX2D.tscn")
const BOLT_SCENE := preload("res://scenes/vfx/primitives/lightning/lightning_bolt.tscn")
const IMPACT_SCENE := preload("res://scenes/vfx/primitives/lightning/lightning_impact.tscn")
const NAMED_SKILL_VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var effect := SERIES_VFX_SCENE.instantiate() as Node2D
	host.add_child(effect)
	await process_frame
	var targets: Array[Vector2] = []
	for target_index in 20:
		var ratio := float(target_index) / 19.0
		targets.append(Vector2(lerpf(-280.0, 280.0, ratio), -36.0 - sin(ratio * PI) * 58.0))
	effect.call("configure", [], 2, [Color("f9feff"), Color("63d7ff"), Color("765cff")], {
		"target_limit": 20,
		"residual_duration": 2.2,
		"duration_seconds": 2.0,
	}, targets)
	effect.call("set_progress", 0.31)
	var state := effect.call("get_debug_state") as Dictionary
	_expect(_count_line_nodes(effect) == 0, "Residual Lightning must not keep geometric target-to-target route lines in the series renderer.")
	_expect(String(state.get("motion_model", "")) == "target_surface_current", "Residual Lightning must read as current crawling over marked bodies.")
	_expect(int(state.get("visible_route_line_count", -1)) == 0, "Residual Lightning diagnostics must forbid persistent route guides.")
	_expect(int(state.get("surface_arc_count", 0)) >= targets.size() * 2, "Every marked body needs multiple local electrical arcs instead of one shared polyline.")
	_expect(bool(state.get("final_strike_owned_by_gameplay_event", false)), "The series renderer must leave the actual sky strike to the controller's final_strike event.")
	_expect(int(state.get("material_layer_count", 0)) >= 5, "Residual marks need corona, core current, branches, sparks, and afterglow layers.")
	_expect(int(state.get("spark_emitter_pool_size", 0)) >= 12, "Advanced rapid focus hops need a bounded spark pool large enough to finish each 0.22-second burst.")
	_expect(_count_particle_nodes(effect) == int(state.get("spark_emitter_pool_size", 0)), "Spark diagnostics must match the concrete bounded emitter pool.")
	for particle in _particle_nodes(effect):
		_expect(not particle.local_coords, "Residual spark particles must remain in world space when a pooled emitter moves to the next target.")

	var focus_before := int(state.get("active_target_index", -1))
	effect.call("set_progress", 0.39)
	var later_state := effect.call("get_debug_state") as Dictionary
	_expect(int(later_state.get("active_target_index", -1)) != focus_before, "The conductive focus must rapidly jump between marked objects.")
	_expect(effect.has_method("set_target_position_provider"), "Residual marks need a presentation-only provider so they can follow moving targets.")
	if effect.has_method("set_target_position_provider"):
		var moving_targets := targets.duplicate()
		effect.call("set_target_position_provider", func() -> Array: return moving_targets)
		moving_targets[0] = Vector2(-122.0, -118.0)
		effect.call("set_progress", 0.43)
		var moving_state := effect.call("get_debug_state") as Dictionary
		var resolved_positions := moving_state.get("target_positions", []) as Array
		_expect(not resolved_positions.is_empty() and (resolved_positions[0] as Vector2).distance_to(moving_targets[0]) < 0.1, "Residual surface current must follow a marked target after it moves.")
		moving_targets.clear()
		effect.call("set_progress", 0.47)
		var cleared_state := effect.call("get_debug_state") as Dictionary
		_expect((cleared_state.get("target_positions", []) as Array).is_empty(), "Residual surface current must disappear when every marked target has left the battle.")

	var bolt := BOLT_SCENE.instantiate() as Node2D
	bolt.set("auto_play", false)
	host.add_child(bolt)
	var impact := IMPACT_SCENE.instantiate() as Node2D
	impact.set("auto_play", false)
	host.add_child(impact)
	await process_frame
	bolt.call("configure_runtime", {
		"one_shot": true,
		"primary_color": Color("ffffff"),
		"secondary_color": Color("63d7ff"),
		"glow_strength": 1.6,
	})
	impact.call("configure_runtime", {
		"one_shot": true,
		"primary_color": Color("ffffff"),
		"secondary_color": Color("63d7ff"),
		"glow_strength": 1.8,
	})
	bolt.call("play", Vector2.ZERO, Vector2(260.0, -28.0))
	impact.call("play", Vector2(180.0, 0.0))
	var bolt_state := bolt.call("get_quality_state") as Dictionary
	var impact_state := impact.call("get_quality_state") as Dictionary
	_expect(String(bolt_state.get("electricity_motion", "")) == "conductive_head", "Chain current must expose a fast conductive-head rhythm rather than a lingering trail.")
	_expect(int(bolt_state.get("energy_layer_count", 0)) >= 3, "Chain current needs glow, colored body, and white-hot core layers.")
	_expect(bool(bolt_state.get("transparent_additive_energy", false)), "Lightning must use transparent additive energy instead of an opaque strip.")
	_expect(String(impact_state.get("electricity_motion", "")) == "sky_strike", "Final lightning impact must use a dedicated top-down sky-strike composition.")
	_expect(int(impact_state.get("impact_layer_count", 0)) >= 6, "Sky strike needs preflash, glow, body, core, branches, sparks, and ground residue.")
	_expect(float(bolt.get("effect_lifetime")) <= 0.28, "A chain hop must discharge quickly enough to read as coursing current.")
	var impact_sparks := impact.get_node_or_null("Sparks") as GPUParticles2D
	_expect(impact_sparks != null and not impact_sparks.emitting, "Sky-strike sparks must wait through pre-ionization instead of firing on play().")
	impact.call("_process", float(impact.get("effect_lifetime")) * 0.10)
	_expect(impact_sparks != null and not impact_sparks.emitting, "Sky-strike sparks must remain held before the contact beat.")
	impact.call("_process", float(impact.get("effect_lifetime")) * 0.12)
	var contacted_state := impact.call("get_quality_state") as Dictionary
	_expect(impact_sparks != null and impact_sparks.emitting, "Sky-strike sparks must burst when the main bolt contacts the ground.")
	_expect(int(contacted_state.get("spark_trigger_count", 0)) == 1 and float(contacted_state.get("spark_trigger_progress", 0.0)) >= 0.14, "Sky-strike sparks must trigger exactly once at the authored contact phase.")

	var named_effect := NAMED_SKILL_VFX_SCENE.instantiate() as Node2D
	named_effect.position = Vector2(420.0, 180.0)
	host.add_child(named_effect)
	var runtime_targets: Array[Node2D] = []
	var shuffled_distances := [510.0, 92.0, 430.0, 138.0, 350.0, 64.0, 290.0, 118.0, 470.0, 210.0, 160.0, 390.0]
	for target_index in shuffled_distances.size():
		var hurtbox_offset := (
			Vector2(-500.0, -34.0)
			if target_index == 0
			else Vector2(float((target_index % 4) * 7), -22.0 - float(target_index % 3) * 9.0)
		)
		var target := _make_target(
			host,
			"LightningTarget%02d" % target_index,
			Vector2(420.0 + float(shuffled_distances[target_index]), 180.0 + float(target_index % 3) * 9.0),
			hurtbox_offset
		)
		runtime_targets.append(target)
	named_effect.call("configure_runtime_targeting", Callable(), runtime_targets)
	named_effect.call("play_series", "lightning", 1, -1, false, 1.35)
	var target_local_positions := named_effect.call("_runtime_target_local_positions", 10) as Array
	_expect(target_local_positions.size() == 10, "Basic Residual Lightning presentation must respect its ten-target gameplay cap.")
	var expected_targets := runtime_targets.duplicate()
	expected_targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(named_effect.global_position) < b.global_position.distance_squared_to(named_effect.global_position)
	)
	for target_index in target_local_positions.size():
		var rendered_world := named_effect.to_global(target_local_positions[target_index] as Vector2)
		var expected_world := ATTACK_GEOMETRY.target_center(expected_targets[target_index])
		_expect(
			rendered_world.distance_to(expected_world) < 0.1,
			"Residual Lightning marks must follow the nearest gameplay targets under mirrored, non-unit skill scaling."
		)

	host.queue_free()
	await process_frame
	_finish()


func _count_line_nodes(node: Node) -> int:
	var count := 1 if node is Line2D else 0
	for child in node.get_children():
		count += _count_line_nodes(child)
	return count


func _count_particle_nodes(node: Node) -> int:
	return _particle_nodes(node).size()


func _particle_nodes(node: Node) -> Array[GPUParticles2D]:
	var result: Array[GPUParticles2D] = []
	if node is GPUParticles2D:
		result.append(node as GPUParticles2D)
	for child in node.get_children():
		result.append_array(_particle_nodes(child))
	return result


func _make_target(parent: Node, node_name: String, world_position: Vector2, hurtbox_offset: Vector2) -> Node2D:
	var target := Node2D.new()
	target.name = node_name
	parent.add_child(target)
	target.global_position = world_position
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	target.add_child(hurtbox)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = hurtbox_offset
	collision.shape = CircleShape2D.new()
	hurtbox.add_child(collision)
	return target


func _finish() -> void:
	if _failures == 0:
		print("PASS: Residual Lightning crawls across targets and resolves as a layered sky strike")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
