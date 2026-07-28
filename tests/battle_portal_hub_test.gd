extends SceneTree

const HUB_PATH := "res://scenes/maps/battle_portal_hub.tscn"
const TOWN_PORTAL_SET_PATH := "res://scenes/maps/town/portals/TownPortalSet.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(HUB_PATH), "Battle portal hub scene must exist.")
	if not ResourceLoader.exists(HUB_PATH):
		quit(1)
		return

	var town_portals := (load(TOWN_PORTAL_SET_PATH) as PackedScene).instantiate()
	root.add_child(town_portals)
	await process_frame
	_expect(town_portals.get_child_count() == 1, "Town must expose one battle gateway only.")
	var gateway := town_portals.get_node_or_null("BattleGateway")
	_expect(gateway != null, "Town must expose BattleGateway.")
	if gateway != null:
		_expect(
			String(gateway.get("target_scene_path")) == HUB_PATH,
			"Town BattleGateway must enter the portal hub."
		)
	town_portals.queue_free()
	await process_frame

	var hub := (load(HUB_PATH) as PackedScene).instantiate()
	root.add_child(hub)
	await process_frame
	_expect(hub.has_node("PlayerSpawn") and hub.has_node("Player"), "Portal hub must be a playable map.")
	_expect(hub.has_node("TownPortal"), "Portal hub must provide a return route to Town.")
	_expect(hub.has_node("BossPortalAnchor"), "Portal hub must reserve its central boss slot.")
	var boss_anchor := hub.get_node_or_null("BossPortalAnchor") as Node2D
	_expect(boss_anchor != null and boss_anchor.position.x == 800.0, "Boss slot must remain centered.")
	_expect(hub.get_node_or_null("BossPortal") == null, "Final boss portal must not exist before it is unlocked.")

	var expected_targets := {
		"AutumnPortal": "res://scenes/maps/autumn_safe_zone.tscn",
		"CrystalPortal": "res://scenes/maps/crystal_caves.tscn",
		"GraveyardPortal": "res://scenes/maps/forbidden_graveyard.tscn",
	}
	for portal_name in expected_targets:
		var portal := hub.get_node_or_null("RegionPortals/%s" % portal_name)
		_expect(portal != null, "%s must exist in the hub." % portal_name)
		if portal != null:
			_expect(
				String(portal.get("target_scene_path")) == expected_targets[portal_name],
				"%s target is incorrect." % portal_name
			)
			_expect_portal_trigger_matches_town_visual(portal as Node2D, portal_name)
	var fourth := hub.get_node_or_null("RegionPortals/FourthRegionPortal")
	_expect(fourth != null, "Hub must reserve a visible fourth region portal.")
	if fourth != null:
		_expect(bool(fourth.get("locked")), "Fourth region portal must stay locked until its map exists.")
		_expect_portal_trigger_matches_town_visual(fourth as Node2D, "FourthRegionPortal")
	_expect(hub.get_node("RegionPortals").get_child_count() == 4, "Hub must contain exactly four region portals.")
	var town_portal := hub.get_node_or_null("TownPortal") as Node2D
	var autumn_portal := hub.get_node_or_null("RegionPortals/AutumnPortal") as Node2D
	var player := hub.get_node_or_null("Player") as CharacterBody2D
	_expect_portal_triggers_do_not_overlap(town_portal, autumn_portal, player)

	hub.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _expect_portal_trigger_matches_town_visual(portal: Node2D, portal_name: String) -> void:
	var visual := portal.get_node_or_null("TownVisual") as Sprite2D
	_expect(visual != null, "%s must expose the TownVisual portal art." % portal_name)
	var collision := portal.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
	_expect(collision != null, "%s must expose an interaction collision shape." % portal_name)
	if visual == null or collision == null:
		return
	var expected_center := portal.global_position + visual.position + visual.offset * visual.global_scale
	_expect(
		collision.global_position.distance_to(expected_center) <= 1.0,
		"%s interaction trigger must align with the visible portal doorway. Expected %s, got %s."
		% [portal_name, expected_center, collision.global_position]
	)


func _expect_portal_triggers_do_not_overlap(
	first_portal: Node2D,
	second_portal: Node2D,
	player: CharacterBody2D
) -> void:
	_expect(first_portal != null, "Battle hub must expose the Town return portal.")
	_expect(second_portal != null, "Battle hub must expose the Autumn portal.")
	_expect(player != null, "Battle hub must expose the player collision contract.")
	if first_portal == null or second_portal == null or player == null:
		return
	var first_rect := _interaction_rect(first_portal)
	var second_rect := _interaction_rect(second_portal)
	var player_collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var player_shape := player_collision.shape as RectangleShape2D
	var player_width := player_shape.size.x * absf(player_collision.global_scale.x)
	var horizontal_gap := second_rect.position.x - first_rect.end.x
	_expect(
		not first_rect.intersects(second_rect),
		"Town return and Autumn portal interaction triggers must not overlap. Got %s and %s."
		% [first_rect, second_rect]
	)
	_expect(
		horizontal_gap > player_width,
		"Town return and Autumn portal triggers need more than one player width of clearance. "
		+ "Expected > %.1f, got %.1f." % [player_width, horizontal_gap]
	)


func _interaction_rect(portal: Node2D) -> Rect2:
	var collision := portal.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	var scaled_size := shape.size * collision.global_scale.abs()
	return Rect2(collision.global_position - scaled_size * 0.5, scaled_size)
