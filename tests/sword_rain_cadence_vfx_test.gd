extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillSeriesVFXCatalog.new()
	_expect(catalog.load_catalog(), "Sword Rain cadence test needs the production series catalog.")
	var basic := catalog.get_tier_profile("sword_rain", 1)
	var advanced := catalog.get_tier_profile("sword_rain", 2)
	var master := catalog.get_tier_profile("sword_rain", 3)
	_expect(
		int(basic.get("object_count", 0)) >= 3
			and int(basic.get("path_count", 0)) >= 3
			and int(basic.get("direction_count", 0)) >= 3,
		"Basic Sword Rain must already attack on at least three paths."
	)
	_expect(
		int(advanced.get("object_count", 0)) > int(basic.get("object_count", 0))
			and int(master.get("object_count", 0)) > int(advanced.get("object_count", 0))
			and int(master.get("path_count", 0)) >= 5,
		"Sword Rain tiers must grow from three paths into denser and wider barrages."
	)

	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null, "Sword Rain cadence test needs NamedSkillVFX.")
	if effect == null:
		quit(1)
		return
	root.add_child(effect)
	await process_frame
	effect.call("play_series", "sword_rain", 1, 1, true)
	var basic_state := effect.call("get_series_debug_state") as Dictionary
	_expect(int(basic_state.get("object_count", 0)) >= 3, "Basic playback must render all three Sword Rain lanes.")
	_expect(effect.has_method("get_sword_rain_cadence_state"), "Sword Rain must expose its authored rhythm diagnostics.")
	if not effect.has_method("get_sword_rain_cadence_state"):
		effect.queue_free()
		await process_frame
		quit(1)
		return

	effect.call("play_series", "sword_rain", 3, 1, true)
	var initial := effect.call("get_sword_rain_cadence_state") as Dictionary
	var beat_schedule := initial.get("beat_schedule", []) as Array
	_expect(beat_schedule.size() == int(master.get("object_count", 0)), "Every master Sword Rain blade needs its own authored attack beat.")
	_expect(int(initial.get("trail_count", 0)) == beat_schedule.size(), "Every Sword Rain blade needs an independent curved streak.")
	_expect(int(initial.get("cadence_pause_count", 0)) >= 2, "Sword Rain needs at least two readable breath pauses.")
	_expect(
		(initial.get("speed_phases", []) as Array) == ["hover", "recoil", "snap", "contact_hold", "afterbeat"],
		"Sword Rain must use non-linear hover, recoil, snap, contact-hold, and afterbeat timing."
	)
	_expect(
		(initial.get("presentation_phases", []) as Array) == ["orbit_reveal", "target_lock", "release", "impact_afterbeat"],
		"Sword Rain must reveal around the caster, lock vertically above targets, then release."
	)
	_expect(is_equal_approx(float(initial.get("target_lock_duration", 0.0)), 0.8), "Sword Rain vertical target lock must last 0.8 seconds.")
	_expect(float(initial.get("appearance_stagger", 0.0)) > 0.0, "Sword Rain blades must appear one by one around the caster.")
	_expect(float(initial.get("minimum_render_size", 0.0)) >= 105.0 and float(initial.get("minimum_render_size", 0.0)) <= 120.0, "Sword Rain blades must be about 70 percent of the previous oversized presentation.")
	_expect(float(initial.get("lock_lane_spacing", 0.0)) >= 55.0 and float(initial.get("lock_row_spacing", 0.0)) >= 30.0, "Sword Rain target-lock blades must not overlap into one unreadable cluster.")
	_expect(float(initial.get("orbit_radius", 0.0)) >= 140.0, "Sword Rain reveal must use a wide readable orbit around the caster.")
	_expect(int(initial.get("impact_vfx_count", 0)) == beat_schedule.size(), "Every Sword Rain blade needs a target-insertion impact VFX.")

	var orbit_end := float(initial.get("orbit_end_ratio", 0.0))
	var lock_end := float(initial.get("lock_end_ratio", 0.0))
	var sampled_phases: Array[String] = []
	for progress in [orbit_end * 0.5, (orbit_end + lock_end) * 0.5, lock_end + 0.03, 0.96]:
		effect.call("debug_set_progress", progress)
		var state := effect.call("get_sword_rain_cadence_state") as Dictionary
		sampled_phases.append(String(state.get("cadence_phase", "")))
	_expect(
		sampled_phases == ["orbit_reveal", "target_lock", "release", "impact_afterbeat"],
		"Sword Rain must visibly progress through orbit reveal, two-second lock, release, and impact afterbeat."
	)
	effect.call("debug_set_progress", lock_end + 0.06)
	var climax := effect.call("get_sword_rain_cadence_state") as Dictionary
	_expect(int(climax.get("active_trail_count", 0)) >= 3, "Sword Rain climax must show multiple simultaneous moving trails.")
	_expect(float(climax.get("maximum_speed_ratio", 0.0)) >= 4.0, "Sword Rain snap must be materially faster than its hover phase.")
	effect.call("debug_set_progress", float(initial.get("first_contact_ratio", 0.0)))
	var contact := effect.call("get_sword_rain_cadence_state") as Dictionary
	_expect(int(contact.get("inserted_blade_count", 0)) >= 1, "Sword Rain must visibly insert a blade into the target.")
	_expect(int(contact.get("active_impact_vfx_count", 0)) >= 1, "A target impact VFX must fire exactly where the blade inserts.")
	effect.call("debug_set_progress", 1.0)
	var finished_state := effect.call("get_sword_rain_cadence_state") as Dictionary
	_expect(int(finished_state.get("visible_blade_count", -1)) == 0, "Inserted Sword Rain blades must disappear after their impact VFX.")
	effect.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Sword Rain uses three-path minimum and authored pause/snap cadence")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
