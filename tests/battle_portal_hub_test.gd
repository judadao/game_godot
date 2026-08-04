extends SceneTree

const HUB_PATH := "res://scenes/maps/battle_portal_hub.tscn"
const TOWN_PORTAL_SET_PATH := "res://scenes/maps/town/portals/TownPortalSet.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town_portals := (load(TOWN_PORTAL_SET_PATH) as PackedScene).instantiate()
	root.add_child(town_portals)
	await process_frame
	var gateway := town_portals.get_node_or_null("BattleGateway")
	_expect(gateway != null and String(gateway.get("target_scene_path")) == HUB_PATH, "Town BattleGateway must enter the portal sanctuary.")
	town_portals.queue_free()
	await process_frame

	var hub := (load(HUB_PATH) as PackedScene).instantiate()
	root.add_child(hub)
	await process_frame
	_expect(hub.has_node("PlayerSpawn") and hub.has_node("Player"), "Portal sanctuary must be directly playable.")
	_expect(hub.has_node("TownPortal"), "Portal sanctuary must return to Town.")
	_expect(hub.get_node("RegionPortals").get_child_count() == 4, "The sanctuary must expose four stable region slots.")
	_expect((hub.get_node("BossPortalAnchor") as Node2D).position.x == 800.0, "The boss gate must remain centered.")
	var boss := hub.get_node("BossPortal")
	_expect(bool(boss.get("locked")) and String(boss.get("target_scene_path")).is_empty(), "The central boss gate must begin sealed.")

	hub.call("configure_progression", {"chapter_id": "chapter_03"}, {"hell_autumn": 2, "hell_crystal": 0, "hell": 0}, {})
	_expect(String(hub.get_node("RegionPortals/AutumnPortal").get_meta("expedition_variant_id")) == "hell_autumn", "Hell chapter must corrupt the Autumn slot.")
	_expect(String(hub.get_node("RegionPortals/CrystalPortal").get_meta("expedition_variant_id")) == "hell_crystal", "Hell chapter must corrupt the Crystal slot.")
	_expect(String(hub.get_node("RegionPortals/HellPortal").get_meta("expedition_variant_id")) == "hell", "Hell chapter must open Hell.")
	_expect(bool(hub.get_node("RegionPortals/HeavenPortal").get("locked")), "Heaven must remain sealed during the Hell chapter.")
	_expect("/ 4" not in (hub.get_node("PortalLabels/AutumnLabel") as Label).text, "Region labels must not expose clear-count bookkeeping.")

	hub.call("configure_progression", {"chapter_id": "chapter_04"}, {"heaven_autumn": 4}, {})
	_expect(String(hub.get_node("RegionPortals/AutumnPortal").get_meta("expedition_variant_id")) == "heaven_autumn", "Heaven chapter must sanctify the Autumn slot.")
	_expect(String(hub.get_node("RegionPortals/HellPortal").get_meta("expedition_variant_id")) == "disorder_hell", "Hell must become Disorder Hell after its commander falls.")
	_expect(not bool(boss.get("locked")), "Four clears must make the central boss gate triggerable.")
	_expect(String(boss.get("target_scene_path")).ends_with("HeavenAutumnBossArena.tscn"), "The boss gate must target the eligible current variant.")
	_expect(
		"強大的敵人正在靠近..." in (hub.get_node("PortalLabels/CrystalLabel") as Label).text,
		"Farmable routes must show the pending-boss warning instead of a clear count."
	)

	hub.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
