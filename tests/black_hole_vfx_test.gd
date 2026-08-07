extends SceneTree

const EFFECT_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_radius := 0.0
	var previous_duration := 0.0
	var previous_layer_count := 0
	for tier in range(1, 4):
		var effect := EFFECT_SCENE.instantiate()
		root.add_child(effect)
		effect.call("play_series", "black_hole", tier, 1, false, 1.0)
		var state := effect.call("get_series_debug_state") as Dictionary
		var material := effect.call("get_black_hole_vfx_state") as Dictionary
		_expect(String(state.get("series_id", "")) == "black_hole", "Black Hole must replace Great Shield as the authoritative series renderer.")
		_expect(String(state.get("object_name", "")) == "重力奇點", "Black Hole must present a singularity, never a shield asset.")
		_expect(bool(state.get("procedural_core", false)), "Black Hole core must be procedural VFX instead of the retired shield PNG.")
		_expect(String(material.get("renderer", "")) == "layered_black_hole", "Black Hole needs its dedicated layered renderer.")
		_expect((material.get("layer_ids", []) as Array).has("singularity_core"), "Black Hole needs a readable dark singularity core.")
		_expect((material.get("layer_ids", []) as Array).has("accretion_rings"), "Black Hole needs rotating accretion rings.")
		_expect((material.get("layer_ids", []) as Array).has("inward_particles"), "Black Hole needs visible inward-flowing matter.")
		_expect((material.get("layer_ids", []) as Array).has("gravity_lens"), "Black Hole needs a gravitational lens layer.")
		_expect((material.get("layer_ids", []) as Array).has("collapse_burst"), "Black Hole needs a cohesive final collapse burst.")
		var radius := float(material.get("radius", 0.0))
		var duration := float(material.get("duration_seconds", 0.0))
		var layer_count := int(material.get("real_visual_layer_count", 0))
		_expect(radius > previous_radius, "Black Hole radius must grow from basic to master.")
		_expect(duration > previous_duration, "Black Hole pull duration must grow from basic to master.")
		_expect(layer_count > previous_layer_count, "Black Hole visual density must grow from basic to master.")
		previous_radius = radius
		previous_duration = duration
		previous_layer_count = layer_count
		effect.call("debug_set_progress", 0.94)
		material = effect.call("get_black_hole_vfx_state") as Dictionary
		_expect(float(material.get("collapse_burst_progress", 0.0)) > 0.0, "The delayed damage must have a synchronized visible collapse burst.")
		effect.queue_free()
		await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Black Hole uses layered scalable procedural VFX")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
