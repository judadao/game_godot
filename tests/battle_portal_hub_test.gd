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
		"AutumnPortal": "res://scenes/maps/autumn_forest.tscn",
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
	var fourth := hub.get_node_or_null("RegionPortals/FourthRegionPortal")
	_expect(fourth != null, "Hub must reserve a visible fourth region portal.")
	if fourth != null:
		_expect(bool(fourth.get("locked")), "Fourth region portal must stay locked until its map exists.")
	_expect(hub.get_node("RegionPortals").get_child_count() == 4, "Hub must contain exactly four region portals.")

	hub.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
