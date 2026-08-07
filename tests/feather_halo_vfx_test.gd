extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null, "Feather halo needs the production NamedSkillVFX scene.")
	if effect == null:
		_finish()
		return
	root.add_child(effect)
	await process_frame
	_expect(
		effect.has_method("get_feather_halo_vfx_state")
			and effect.has_method("debug_advance_feather_halo")
			and effect.has_method("refill_feather_halo"),
		"Feather needs a persistent material halo renderer with refill control."
	)
	if not effect.has_method("get_feather_halo_vfx_state"):
		effect.queue_free()
		await process_frame
		_finish()
		return

	effect.call("play_series", "feather", 1, 1, false)
	var initial := effect.call("get_feather_halo_vfx_state") as Dictionary
	var feather_count := int(initial.get("feather_count", 0))
	_expect(String(initial.get("renderer", "")) == "persistent_feather_halo", "Feather must use its specialized halo renderer.")
	_expect(feather_count >= 3, "Basic Feather halo needs its full authored feather count.")
	_expect(int(initial.get("visible_feather_count", 0)) >= 1, "The first feather must appear immediately.")
	_expect(float(initial.get("summon_stagger_seconds", 0.0)) > 0.0, "Feathers must join the halo one by one.")
	_expect(int(initial.get("material_trail_layer_count", 0)) == feather_count * 2, "Every feather needs outer glow and bright arc history layers.")
	_expect(int(initial.get("aura_layer_count", 0)) == feather_count, "Every feather needs a separate luminous body aura.")
	_expect(int(initial.get("halo_ring_layer_count", 0)) == 2, "Feather contact range needs an authored outer-energy and bright-core light wheel.")
	_expect(bool(initial.get("uses_energy_shader", false)), "Feather bodies must use animated material energy, not flat sprites.")
	_expect(bool(initial.get("uses_dissolve_particles", false)), "Feathers must break into motes while fading.")
	_expect(String(initial.get("attack_mode", "")) == "orbit_contact", "Feathers must remain around the player instead of homing toward enemies.")
	_expect(float(initial.get("readability_scale", 0.0)) >= 1.18, "Feather bodies and light edges must remain obvious against combat backgrounds.")
	_expect(float(initial.get("max_root_alignment_error", 1.0)) <= 0.04, "Every feather root must point toward the player center.")
	_expect(float(initial.get("lifetime_seconds", 0.0)) >= 4.0, "The halo must persist long enough to function as a temporary reserve.")
	_expect(is_equal_approx(float(initial.get("lifetime_seconds", 0.0)), 4.8), "Feather lifetime must come from the series profile.")
	_expect(is_equal_approx(float(initial.get("orbit_speed", 0.0)), 0.82), "Feather orbit speed must come from the series profile.")

	var initial_angle := float(initial.get("orbit_angle", 0.0))
	effect.call("debug_advance_feather_halo", 0.8)
	var rotating := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(absf(float(rotating.get("orbit_angle", 0.0)) - initial_angle) > 0.25, "The light-feather halo must visibly rotate around the player.")
	_expect(float(rotating.get("max_root_alignment_error", 1.0)) <= 0.04, "Roots must stay aimed inward while the halo rotates.")
	_expect(int(rotating.get("visible_feather_count", 0)) == feather_count, "The stagger must finish with the complete halo visible.")

	effect.call("debug_advance_feather_halo", float(initial.get("fade_start_seconds", 3.0)) + 0.55)
	var fading := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(
		int(fading.get("fading_feather_count", 0)) >= 1
			and int(fading.get("expired_feather_count", 0)) >= 1
			and int(fading.get("visible_feather_count", 0)) < feather_count,
		"Feathers must visibly disappear one by one during the halo tail."
	)
	effect.call("debug_advance_feather_halo", 1.1)
	var depleted := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(int(depleted.get("expired_feather_count", 0)) == feather_count, "The full halo must eventually expire without a refill.")
	var refill_before := int(fading.get("refill_generation", 0))
	_expect(bool(effect.call("refill_feather_halo", 1, 1.0)), "Casting Feather again must refill the existing halo.")
	var refilled := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(int(refilled.get("refill_generation", 0)) == refill_before + 1, "Refill must update the existing halo generation.")
	_expect(int(refilled.get("refill_pending_count", 0)) >= 1, "Refill must visibly add feathers back one by one.")
	_expect(float(refilled.get("minimum_remaining_seconds", 0.0)) >= 4.0, "Refilled feathers must receive a fresh lifetime.")
	effect.call("debug_advance_feather_halo", 0.8)
	refilled = effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(int(refilled.get("visible_feather_count", 0)) == feather_count, "Refill must restore every missing or fading feather.")
	_expect(bool(effect.call("refill_feather_halo", 1, 1.0)), "A fast recast must extend an already full halo.")
	var fast_refill := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(
		int(fast_refill.get("visible_feather_count", 0)) == feather_count
			and int(fast_refill.get("refill_pending_count", 0)) == 0,
		"A fast refill must not blink or resummon feathers that are still visible."
	)
	effect.call("play_feather_contact_impact", Vector2(120.0, -20.0))
	var contacted := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(int(contacted.get("contact_impact_count", 0)) == 1, "Touching enemies need a clear material cut impact on the halo boundary.")
	effect.call("play_series", "feather", 3, 1, false)
	var master := effect.call("get_feather_halo_vfx_state") as Dictionary
	_expect(float(master.get("maximum_remaining_seconds", 0.0)) > float(initial.get("maximum_remaining_seconds", 0.0)), "More feathers must keep the master halo active longer.")

	var composer := effect.call("get_skill_vfx_recipe_debug_state") as Dictionary
	_expect(
		(composer.get("suppressed_generic_roles", []) as Array)
			== ["projectile", "trail", "afterimage", "ring", "impact"],
		"Feather halo must suppress generic connector lines and unrelated impacts."
	)
	effect.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Feather forms a refillable inward-facing material halo")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
