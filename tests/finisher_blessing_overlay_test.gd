extends SceneTree

const VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_begin_autumn_run", [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])
	var gifts := game.get("divine_gift_manager") as RefCounted
	var database := game.get("card_database") as CardDatabase
	_expect(bool(gifts.call("add_or_upgrade", "resonant_grace")), "Fire Gift must enter the Run.")
	_expect(bool(gifts.call("add_or_upgrade", "resonant_grace")), "Fire Gift level must be retained by VFX projection.")
	_expect(bool(gifts.call("add_or_upgrade", "prismatic_oath")), "Lightning Gift must enter after Fire.")
	_expect(bool(gifts.call("add_or_upgrade", "eternal_memory")), "Ice Gift must enter after Lightning.")
	gifts.call("set_primary_gift", "eternal_memory")

	var finisher := game.call(
		"_build_formula_finisher",
		database.get_card("ember_bolt"),
		{"id": "heavenly_wheel_sever", "name": "天輪斷", "formula_cards": []}
	) as Dictionary
	var visual := finisher.get("combo_visual_profile", {}) as Dictionary
	var overlays := visual.get("blessing_overlays", []) as Array
	_expect(
		overlays.size() == 3,
		"Every owned Gift must project one Finisher overlay, capped at three."
	)
	_expect(
		_overlay_ids(overlays) == ["resonant_grace", "prismatic_oath", "eternal_memory"],
		"Finisher Gift overlays must keep stable acquisition order, independent of primary selection."
	)
	if overlays.size() == 3:
		_expect(
			int((overlays[0] as Dictionary).get("level", 0)) == 2
				and String((overlays[0] as Dictionary).get("element", "")) == "fire",
			"Each overlay must retain its selected Gift level and normalized element."
		)

	var effect := VFX_SCENE.instantiate()
	root.add_child(effect)
	await process_frame
	effect.set_meta("finisher_blessing_overlays", overlays)
	effect.call("play", "heavenly_wheel_sever", 1, 1.0, true, 2, 4)
	effect.call("debug_set_progress", 0.64)
	var debug := effect.call("get_finisher_debug_state") as Dictionary
	var passes := debug.get("blessing_overlay_passes", []) as Array
	_expect(
		int(debug.get("blessing_overlay_count", 0)) == 3
			and int(debug.get("blessing_overlay_limit", 0)) == 3,
		"FinisherGeometryCore must expose at most three blessing-driven passes."
	)
	_expect(
		passes.size() == 3 and passes.all(_pass_has_sourced_particle_and_light),
		"Every blessing pass needs a named source particle and its own light color."
	)
	_expect(
		int(effect.call("get_total_visual_layer_count"))
			== int(effect.call("get_base_visual_layer_count")) + 6,
		"Three blessing passes must add one particle and one light layer each."
	)
	effect.queue_free()

	gifts.call("reset_run")
	for gift_id in ["resonant_grace", "prismatic_oath"]:
		for _level in 3:
			gifts.call("add_or_upgrade", gift_id)
	var evolved := gifts.call(
		"fuse_max_level", "resonant_grace", "prismatic_oath"
	) as Dictionary
	var evolved_finisher := game.call(
		"_build_formula_finisher",
		database.get_card("ember_bolt"),
		{"id": "heavenly_wheel_sever", "name": "天輪斷", "formula_cards": []}
	) as Dictionary
	var evolved_overlays := (
		(evolved_finisher.get("combo_visual_profile", {}) as Dictionary).get(
			"blessing_overlays", []
		) as Array
	)
	_expect(not evolved.is_empty() and evolved_overlays.size() == 1, "Fusion must replace its two source Gift passes with one evolved pass.")
	if evolved_overlays.size() == 1:
		var evolved_overlay := evolved_overlays[0] as Dictionary
		_expect(
			String(evolved_overlay.get("kind", "")) == "evolved"
				and bool(evolved_overlay.get("evolved", false))
				and (evolved_overlay.get("elements", []) as Array) == ["fire", "lightning"]
				and (evolved_overlay.get("components", []) as Array).size() == 2
				and not String(evolved_overlay.get("accent_color", "")).is_empty(),
			"Evolved overlays must preserve evolution identity, component Gifts, elements, and accent light."
		)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: selected and evolved Divine Gifts drive distinct Finisher particle/light overlays")
	quit(1 if _failures > 0 else 0)


func _overlay_ids(overlays: Array) -> Array[String]:
	var result: Array[String] = []
	for overlay_variant in overlays:
		result.append(String((overlay_variant as Dictionary).get("id", "")))
	return result


func _pass_has_sourced_particle_and_light(pass_variant: Variant) -> bool:
	if not pass_variant is Dictionary:
		return false
	var overlay_pass := pass_variant as Dictionary
	return (
		not String(overlay_pass.get("particle_source", "")).is_empty()
		and not String(overlay_pass.get("light_color", "")).is_empty()
		and bool(overlay_pass.get("has_source_particles", false))
		and bool(overlay_pass.get("has_colored_light", false))
		and bool(overlay_pass.get("particle_texture_assigned", false))
		and bool(overlay_pass.get("particles_emitting", false))
		and float(overlay_pass.get("current_light_energy", 0.0)) > 0.0
		and not bool(overlay_pass.get("generic_line_or_ring", true))
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
