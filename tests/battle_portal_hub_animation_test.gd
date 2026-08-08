extends SceneTree

const HUB_SCENE := preload("res://scenes/maps/battle_portal_hub.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub := HUB_SCENE.instantiate()
	var authored_player_y := (hub.get_node("Player") as Node2D).position.y
	root.add_child(hub)
	await process_frame
	var expected_portal_x := {
		"AutumnPortal": 160.0,
		"CrystalPortal": 436.0,
		"HellPortal": 1117.0,
		"HeavenPortal": 1405.0,
	}
	for portal_name in ["AutumnPortal", "CrystalPortal", "HellPortal", "HeavenPortal"]:
		var portal := hub.get_node("RegionPortals/%s" % portal_name)
		var visual := portal.get_node_or_null("PortalVisual")
		var label_name: String = String(portal_name).trim_suffix("Portal") + "Label"
		var label := hub.get_node_or_null("PortalLabels/%s" % label_name) as Control
		var animation := visual.get_node_or_null("PortalStateAnimation") as AnimationPlayer if visual != null else null
		_expect(visual != null, "%s needs the authored animated portal visual." % portal_name)
		_expect(animation != null and animation.is_playing(), "%s portal animation must play automatically." % portal_name)
		_expect(
			is_equal_approx((portal as Node2D).position.x, float(expected_portal_x[portal_name])),
			"%s must align with the native backdrop aperture center." % portal_name
		)
		_expect(
			label != null
				and is_equal_approx(label.position.x + label.size.x * 0.5, float(expected_portal_x[portal_name]))
				and label.position.y >= 550.0,
			"%s label must center on its aperture and remain below the vortex artwork." % portal_name
		)
		if visual != null:
			var active_portal := visual.get_node_or_null("ApertureAnchor/PortalScale/ActivePortalAnimation") as Node2D
			var portal_core := visual.get_node_or_null("ApertureAnchor/PortalScale/ActivePortalAnimation/PortalCore") as Node2D
			var aperture_anchor := visual.get_node_or_null("ApertureAnchor") as Node2D
			var portal_scale := visual.get_node_or_null("ApertureAnchor/PortalScale") as Node2D
			_expect(active_portal != null and active_portal.position == Vector2.ZERO, "%s active art must use the Hub portal's local origin." % portal_name)
			_expect(portal_core != null and portal_core.position == Vector2.ZERO, "%s vortex core must not retain Town's absolute coordinates." % portal_name)
			_expect(
				aperture_anchor != null
					and portal_scale != null
					and is_equal_approx(
						(portal as Node2D).position.y + aperture_anchor.position.y + 102.0 * portal_scale.scale.y,
						545.0
					),
				"%s vortex bottom must remain fitted to the backdrop aperture." % portal_name
			)
	var heaven_visual := hub.get_node_or_null("RegionPortals/HeavenPortal/PortalVisual")
	_expect(
		heaven_visual != null
			and bool(heaven_visual.get("sealed"))
			and heaven_visual.get_node("ApertureAnchor/PortalScale/SealRig").visible,
		"A locked region portal needs the inset sealed presentation."
	)
	if heaven_visual != null:
		var sealed_core := heaven_visual.get_node_or_null("ApertureAnchor/PortalScale/SealedPortalAnimation/PortalCore") as AnimatedSprite2D
		var seal_rig := heaven_visual.get_node_or_null("ApertureAnchor/PortalScale/SealRig") as Node2D
		_expect(sealed_core != null and not sealed_core.is_playing(), "A locked portal must use a stable dimmed vortex instead of a slow cheap loop.")
		_expect(seal_rig != null and not seal_rig.has_node("SealBarA") and not seal_rig.has_node("SealBarB"), "A locked portal must not retain the presentation-like X seal.")
		_expect(seal_rig != null and seal_rig.has_node("SealVeil") and seal_rig.has_node("SealRing") and seal_rig.has_node("SealGlyph"), "A locked portal needs a layered inset seal material.")
	var autumn_visual := hub.get_node_or_null("RegionPortals/AutumnPortal/PortalVisual")
	_expect(
		autumn_visual != null
			and not bool(autumn_visual.get("sealed"))
			and autumn_visual.get_node("ApertureAnchor/PortalScale/ActivePortalAnimation").visible,
		"An available region portal needs the active Town-style vortex."
	)
	if autumn_visual != null:
		var active_core := autumn_visual.get_node_or_null("ApertureAnchor/PortalScale/ActivePortalAnimation/PortalCore") as AnimatedSprite2D
		_expect(active_core != null and active_core.is_playing(), "An available portal must retain the authored 12-frame vortex motion.")
	var boss_visual := hub.get_node_or_null("BossPortal/PortalVisual")
	var boss_label := hub.get_node_or_null("BossLabel") as Control
	_expect(
		boss_visual != null and bool(boss_visual.get("sealed")),
		"The boss portal must begin with its animated seal."
	)
	if boss_visual != null:
		var boss_seal_rig := boss_visual.get_node_or_null("ApertureAnchor/PortalScale/SealRig") as Node2D
		var boss_seal_ring := boss_visual.get_node_or_null("ApertureAnchor/PortalScale/SealRig/SealRing") as Line2D
		_expect(
			boss_seal_rig != null
				and boss_seal_ring != null
				and not boss_seal_ring.visible
				and boss_seal_rig.to_global(Vector2(-57.0, 0.0)).x >= 727.0
				and boss_seal_rig.to_global(Vector2(57.0, 0.0)).x <= 873.0
				and boss_seal_rig.to_global(Vector2(0.0, -80.0)).y >= 350.0
				and boss_seal_rig.to_global(Vector2(0.0, 48.0)).y <= 545.0,
			"Boss seal veil and glyph must stay inside the central black doorway without an outer ring."
		)
	_expect(
		boss_label != null
			and is_equal_approx(boss_label.position.x + boss_label.size.x * 0.5, 800.0)
			and boss_label.position.y + boss_label.size.y <= 294.0,
		"Boss label must center on the main door and remain above its fitted portal artwork."
	)
	hub.call(
		"configure_progression",
		{"chapter_id": "chapter_04"},
		{"heaven_autumn": 4},
		{"heaven_autumn": 4},
		{"heaven_autumn": true},
		{}
	)
	await process_frame
	if boss_visual != null:
		var boss_active_portal := boss_visual.get_node_or_null("ApertureAnchor/PortalScale/ActivePortalAnimation") as Node2D
		var boss_active_core := boss_visual.get_node_or_null("ApertureAnchor/PortalScale/ActivePortalAnimation/PortalCore") as AnimatedSprite2D
		var boss_active_rune := boss_visual.get_node_or_null("ApertureAnchor/PortalScale/ActivePortalAnimation/PortalRuneGlow") as Polygon2D
		var boss_active_aura := boss_visual.get_node_or_null("ApertureAnchor/PortalScale/ActiveAura") as Line2D
		_expect(
			not bool(boss_visual.get("sealed"))
				and boss_active_portal != null
				and boss_active_portal.visible
				and boss_active_core != null
				and boss_active_core.is_playing()
				and boss_active_rune != null
				and not boss_active_rune.visible
				and boss_active_aura != null
				and not boss_active_aura.visible,
			"Active Boss portal must show only the fitted animated vortex without an aura or top rune."
		)
	var baseline := hub.get_node_or_null("StairWalkBaseline") as Marker2D
	var spawn := hub.get_node_or_null("PlayerSpawn") as Marker2D
	var player := hub.get_node_or_null("Player") as Node2D
	var floor_collision := hub.get_node_or_null("WorldCollision/FloorCollision") as CollisionShape2D
	_expect(baseline != null, "Portal sanctuary needs an explicit stair walk baseline.")
	_expect(
		baseline != null
			and spawn != null
			and player != null
			and is_equal_approx(baseline.position.y, 640.0)
			and is_equal_approx(spawn.position.y, baseline.position.y)
			and is_equal_approx(authored_player_y, baseline.position.y),
		"Player and transferred spawn must return to the authored paved-ground entry height."
	)
	_expect(
		floor_collision != null and is_equal_approx(floor_collision.position.y, 720.0),
		"Portal sanctuary collision must place the settled character on the foreground paving."
	)
	var autumn_root_transform := Transform2D.IDENTITY
	var autumn_anchor_transform := Transform2D.IDENTITY
	if autumn_visual != null:
		autumn_root_transform = (autumn_visual as Node2D).transform
		autumn_anchor_transform = (autumn_visual.get_node("ApertureAnchor") as Node2D).transform
	await create_timer(0.35).timeout
	if autumn_visual != null:
		_expect((autumn_visual as Node2D).transform == autumn_root_transform, "Portal ambient motion must never animate the interaction root transform.")
		_expect((autumn_visual.get_node("ApertureAnchor") as Node2D).transform == autumn_anchor_transform, "Portal ambient motion must preserve the fixed aperture-bottom anchor.")
	hub.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: battle portal hub active, sealed, and stair-baseline presentation")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
