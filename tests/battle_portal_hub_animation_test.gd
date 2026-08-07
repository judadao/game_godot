extends SceneTree

const HUB_SCENE := preload("res://scenes/maps/battle_portal_hub.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub := HUB_SCENE.instantiate()
	root.add_child(hub)
	await process_frame
	for portal_name in ["AutumnPortal", "CrystalPortal", "HellPortal", "HeavenPortal"]:
		var portal := hub.get_node("RegionPortals/%s" % portal_name)
		var visual := portal.get_node_or_null("PortalVisual")
		var animation := visual.get_node_or_null("PortalStateAnimation") as AnimationPlayer if visual != null else null
		_expect(visual != null, "%s needs the authored animated portal visual." % portal_name)
		_expect(animation != null and animation.is_playing(), "%s portal animation must play automatically." % portal_name)
	var heaven_visual := hub.get_node_or_null("RegionPortals/HeavenPortal/PortalVisual")
	_expect(
		heaven_visual != null
			and bool(heaven_visual.get("sealed"))
			and heaven_visual.get_node("SealRig").visible,
		"A locked region portal needs the moving sealed presentation."
	)
	var autumn_visual := hub.get_node_or_null("RegionPortals/AutumnPortal/PortalVisual")
	_expect(
		autumn_visual != null
			and not bool(autumn_visual.get("sealed"))
			and autumn_visual.get_node("ActivePortalAnimation").visible,
		"An available region portal needs the active Town-style vortex."
	)
	var boss_visual := hub.get_node_or_null("BossPortal/PortalVisual")
	_expect(
		boss_visual != null and bool(boss_visual.get("sealed")),
		"The boss portal must begin with its animated seal."
	)
	var baseline := hub.get_node_or_null("StairWalkBaseline") as Marker2D
	var spawn := hub.get_node_or_null("PlayerSpawn") as Marker2D
	var player := hub.get_node_or_null("Player") as Node2D
	_expect(baseline != null, "Portal sanctuary needs an explicit stair walk baseline.")
	_expect(
		baseline != null
			and spawn != null
			and player != null
			and is_equal_approx(spawn.position.y, baseline.position.y)
			and is_equal_approx(player.position.y, baseline.position.y),
		"Player and transferred spawn must align with the midground stair baseline."
	)
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
