extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null, "Combat VFX foundation requires NamedSkillVFX.")
	if effect == null:
		quit(1)
		return
	root.add_child(effect)
	await process_frame
	effect.call("play_series", "sword_rain", 2, 1, true)
	var slash_state := effect.call("get_series_debug_state") as Dictionary
	_expect(
		String(slash_state.get("presentation_mode", "")) == "procedural_vfx_recipe",
		"Series combat VFX must use the production recipe composer."
	)
	_expect(
		(slash_state.get("grammar", []) as Array).has("impact")
			and int(slash_state.get("real_visual_layer_count", 0)) >= 5,
		"Recipe playback needs concrete trail/contact layers, not debug metadata only."
	)
	effect.call("play_series", "fire", 3, 1, true)
	var fire_state := effect.call("get_skill_vfx_recipe_debug_state") as Dictionary
	var fire_grammar := fire_state.get("grammar", []) as Array
	for role in ["core", "trail", "distortion", "burst", "impact", "ground_zone"]:
		_expect(fire_grammar.has(role), "Fire recipe must include the reusable %s role." % role)
	_expect(
		(effect.call("get_vfx_foundation_debug_state") as Dictionary).is_empty(),
		"Legacy foundation must not process invisibly behind a valid production recipe."
	)
	_expect(int(effect.call("get_active_layer_count")) > int(slash_state.get("object_count", 0)), "Foundation VFX must add real render layers, not debug metadata only.")
	effect.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: procedural fire, slash, distortion, burst, and impact roles compose combat VFX")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
