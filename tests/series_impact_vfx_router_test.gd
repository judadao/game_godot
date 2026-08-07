extends SceneTree


class SignalFixture:
	extends Node

	signal pillar_erupted(index: int, world_position: Vector2)
	signal chain_hit(from_position: Vector2, target: Node, target_position: Vector2)
	signal final_strike(target: Node, target_position: Vector2)
	signal wave_pulse(target: Node, world_position: Vector2, damage: int)
	signal detonated(world_position: Vector2, hit_count: int)


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var router_script := load("res://scripts/vfx/series_impact_vfx_router.gd") as Script
	_expect(router_script != null, "Combat VFX needs one reusable event-to-primitive router.")
	if router_script == null:
		_finish()
		return
	var visual_root := Node2D.new()
	visual_root.name = "VisualRoot"
	root.add_child(visual_root)
	var router := router_script.new() as Node
	root.add_child(router)
	var fixture := SignalFixture.new()
	root.add_child(fixture)
	_expect(
		bool(router.call("bind_controller", "fire", fixture, visual_root, [])),
		"Fire controllers must bind their real eruption event."
	)
	fixture.pillar_erupted.emit(0, Vector2(42.0, 70.0))
	await process_frame
	_expect(_has_primitive(visual_root, "fire_burst"), "A fire eruption must spawn the reusable layered Fire Burst primitive.")
	_expect(_primitive_position(visual_root, "fire_burst") == Vector2(42.0, 70.0), "Fire Burst must occur at the controller's real eruption position.")

	var lightning_root := Node2D.new()
	root.add_child(lightning_root)
	var lightning_fixture := SignalFixture.new()
	root.add_child(lightning_fixture)
	_expect(bool(router.call("bind_controller", "lightning", lightning_fixture, lightning_root, [])), "Lightning controllers must bind chain and final-strike events.")
	lightning_fixture.chain_hit.emit(Vector2(10.0, 12.0), null, Vector2(150.0, 44.0))
	lightning_fixture.final_strike.emit(null, Vector2(150.0, 44.0))
	await process_frame
	_expect(_has_primitive(lightning_root, "lightning_bolt"), "A chain hop must render a procedural bolt between its real endpoints.")
	_expect(_has_primitive(lightning_root, "lightning_impact"), "Residual lightning must end with the shared heavy impact primitive.")

	var water_root := Node2D.new()
	root.add_child(water_root)
	var water_fixture := SignalFixture.new()
	root.add_child(water_fixture)
	_expect(bool(router.call("bind_controller", "water_flow", water_fixture, water_root, [])), "Water controllers must bind damage pulses.")
	water_fixture.wave_pulse.emit(null, Vector2(96.0, 20.0), 3)
	await process_frame
	_expect(_has_primitive(water_root, "water_splash"), "A damaging wave contact must spawn layered body, foam, droplets, mist, and splash material.")
	var blessed_water_root := Node2D.new()
	root.add_child(blessed_water_root)
	var blessed_water_fixture := SignalFixture.new()
	root.add_child(blessed_water_fixture)
	_expect(bool(router.call("bind_controller", "water_flow", blessed_water_fixture, blessed_water_root, [{"element": "fire", "level": 3}])), "Blessed impacts must retain the same gameplay event authority.")
	blessed_water_fixture.wave_pulse.emit(null, Vector2(120.0, 24.0), 4)
	await process_frame
	_expect(_has_primitive(blessed_water_root, "fire_burst"), "A Fire Blessing must replace the Water contact material with Fire Burst without changing Water gameplay.")

	var black_hole_root := Node2D.new()
	root.add_child(black_hole_root)
	var black_hole_fixture := SignalFixture.new()
	root.add_child(black_hole_fixture)
	_expect(bool(router.call("bind_controller", "black_hole", black_hole_fixture, black_hole_root, [{"element": "dark", "level": 2}])), "Black Hole must bind its actual detonation.")
	black_hole_fixture.detonated.emit(Vector2(210.0, 60.0), 4)
	await process_frame
	_expect(_has_primitive(black_hole_root, "wind_burst"), "Black Hole detonation must reuse a recolored shockwave/burst primitive.")
	var burst := _find_primitive(black_hole_root, "wind_burst")
	_expect(burst != null and burst.has_meta("skill_series_id") and String(burst.get_meta("skill_series_id")) == "black_hole", "Spawned primitives must retain series identity for Blessing mutation and diagnostics.")

	var state := router.call("get_debug_state") as Dictionary
	_expect(int(state.get("spawn_count", 0)) == 7, "Router diagnostics must count every gameplay-triggered primitive.")
	_expect((state.get("effect_counts", {}) as Dictionary).has("fire_burst"), "Router diagnostics must expose concrete primitive usage.")
	_finish()


func _find_primitive(parent: Node, effect_id: String) -> Node:
	for child in parent.get_children():
		if String(child.get("effect_id")) == effect_id:
			return child
	return null


func _has_primitive(parent: Node, effect_id: String) -> bool:
	return _find_primitive(parent, effect_id) != null


func _primitive_position(parent: Node, effect_id: String) -> Vector2:
	var primitive := _find_primitive(parent, effect_id) as Node2D
	return primitive.global_position if primitive != null else Vector2.INF


func _finish() -> void:
	if _failures == 0:
		print("PASS: gameplay controller signals trigger layered reusable material and impact VFX")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
