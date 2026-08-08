extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null, "Sword Rain material VFX needs the production NamedSkillVFX scene.")
	if effect == null:
		_finish()
		return
	root.add_child(effect)
	await process_frame
	effect.call("play_series", "sword_rain", 3, 1, true)
	_expect(
		effect.has_method("get_sword_rain_material_vfx_state"),
		"Sword Rain needs a dedicated material/cadence renderer instead of generic role lines."
	)
	if not effect.has_method("get_sword_rain_material_vfx_state"):
		effect.queue_free()
		await process_frame
		_finish()
		return

	var cadence := effect.call("get_sword_rain_cadence_state") as Dictionary
	var series_state := effect.call("get_series_debug_state") as Dictionary
	var initial := effect.call("get_sword_rain_material_vfx_state") as Dictionary
	var blade_count := int(cadence.get("trail_count", 0))
	_expect(String(initial.get("renderer", "")) == "sword_rain_material_cadence", "Sword Rain must identify its specialized renderer.")
	_expect(blade_count >= 20, "Master Sword Rain fixture needs four evolved ten-plus-blade volleys.")
	_expect(
		(cadence.get("release_group_sizes", []) as Array) == [5, 5, 5, 5],
		"Master Sword Rain must use four deliberate five-blade volleys instead of arbitrary scatter."
	)
	_expect(int(initial.get("blade_trail_count", 0)) == blade_count, "Every blade needs an independent history trail.")
	_expect(int(initial.get("materialized_trail_layer_count", 0)) == blade_count * 3, "Every blade trail needs outer energy, colored body, and white cutting core.")
	_expect(int(initial.get("blade_aura_count", 0)) == blade_count * 2, "Every blade needs separate summon echo and lock sheath layers.")
	_expect(int(initial.get("summon_star_count", 0)) == blade_count, "Every blade needs its own lock-star summon flash.")
	_expect(
		String(initial.get("summon_star_texture", ""))
			== "res://assets/generated/vfx/skill_materials/components/base/sword_rain__lock_star.png",
		"Sword Rain summon flashes must use the approved lock-star component."
	)
	_expect(int(initial.get("impact_stack_count", 0)) == blade_count, "Every blade needs its own insertion impact stack.")
	_expect(int(initial.get("ground_crater_count", 0)) == blade_count, "Every blade needs its own grounded crater impact.")
	_expect(
		String(initial.get("ground_crater_texture", ""))
			== "res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_crater.png",
		"Sword Rain ground impacts must reuse the approved stone-crater component."
	)
	_expect(
		(initial.get("impact_roles", []) as Array) == [
			"compression_wedge", "contact_flash", "directional_shards", "ground_crater", "ground_scar",
			"sword_afterglow", "sparks",
		],
		"Insertion impact must describe contact material instead of a generic circle."
	)
	_expect((initial.get("generic_line_roles", []) as Array).is_empty(), "Sword Rain must suppress generic Rain/Ring geometry.")
	_expect(bool(initial.get("uses_core_energy_shader", false)), "The sword body and aura must use an animated edge/energy material.")
	_expect(bool(initial.get("trail_uses_material_shader", false)), "Layered trails must use a directional material shader.")
	_expect(int(initial.get("spark_emitter_count", 0)) >= 3, "Sword Rain needs pooled impact sparks for material breakup.")
	_expect(
		int(series_state.get("specialized_real_visual_layer_count", 0)) > blade_count,
		"Sword Rain diagnostics must report the renderer's concrete scene layers, not metadata only."
	)
	_expect(
		(initial.get("motion_phases", []) as Array) == [
			"summon_stagger", "orbit_gather", "lock_charge", "snap_release",
			"insertion_hold", "afterglow_decay",
		],
		"Sword Rain VFX must expose a layered motion hierarchy."
	)

	var orbit_end := float(cadence.get("orbit_end_ratio", 0.0))
	var lock_end := float(cadence.get("lock_end_ratio", 0.0))
	effect.call("debug_set_progress", orbit_end * 0.5)
	var orbit := effect.call("get_sword_rain_material_vfx_state") as Dictionary
	_expect(int(orbit.get("active_summon_echo_count", 0)) >= 3, "Orbit reveal must stagger visible sword-shaped summon echoes.")
	_expect(int(orbit.get("active_summon_star_count", 0)) >= 1, "Each staggered sword reveal must include a short lock-star flash.")
	_expect(int(orbit.get("active_trail_count", -1)) == 0, "Orbit reveal must not show travel trails before release.")
	effect.call("debug_set_progress", (orbit_end + lock_end) * 0.5)
	var lock := effect.call("get_sword_rain_material_vfx_state") as Dictionary
	_expect(int(lock.get("active_lock_sheath_count", 0)) == blade_count, "Lock beat must charge every vertical blade with a readable sheath.")
	_expect(float(lock.get("lock_energy", 0.0)) > 0.4, "Lock beat needs a visible material-energy build-up.")
	effect.call("debug_set_progress", lock_end + 0.06)
	var release := effect.call("get_sword_rain_material_vfx_state") as Dictionary
	_expect(int(release.get("active_trail_count", 0)) >= 3, "First release beat must launch a readable group, not one lonely line.")
	effect.call("debug_set_progress", float(cadence.get("first_contact_ratio", 0.0)))
	var contact := effect.call("get_sword_rain_material_vfx_state") as Dictionary
	_expect(int(contact.get("active_impact_count", 0)) >= 1, "Each inserted sword must trigger its own material impact stack.")
	_expect(int(contact.get("active_ground_scar_count", 0)) >= 1, "Insertion must leave a short grounded cutting scar before decay.")
	_expect(int(contact.get("active_ground_crater_count", 0)) >= 1, "Each inserted sword must show a stone crater at its ground contact.")

	var composer := effect.call("get_skill_vfx_recipe_debug_state") as Dictionary
	var raster_state := composer.get("raster_material", {}) as Dictionary
	for region_value in raster_state.get("atlas_regions", []) as Array:
		var region := region_value as Dictionary
		_expect(
			not String(region.get("source_path", "")).ends_with("sword_rain__blue_crescent.png"),
			"Sword Rain runtime composition must not instantiate the removed blue crescent."
		)
	_expect(
		(composer.get("suppressed_generic_roles", []) as Array) == ["rain", "projectile", "trail", "ring", "impact"],
		"Generic Composer lines must be disabled when the Sword Rain renderer owns those roles."
	)
	effect.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Sword Rain uses blade-shaped energy, layered trails, and per-blade material impacts")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
