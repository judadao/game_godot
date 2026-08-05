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

	hub.call(
		"configure_progression",
		{"chapter_id": "chapter_03"},
		{"hell_autumn": 2, "hell_crystal": 0, "hell": 0},
		{"hell_autumn": 2},
		{},
		{}
	)
	var autumn_options := hub.get_node("RegionPortals/AutumnPortal").get_meta("expedition_variant_options", []) as Array
	var crystal_options := hub.get_node("RegionPortals/CrystalPortal").get_meta("expedition_variant_options", []) as Array
	_expect(
		_option_ids(autumn_options) == ["autumn", "hell_autumn"],
		"Hell chapter Autumn portal must offer normal and Hell battlefields."
	)
	_expect(
		_option_ids(crystal_options) == ["crystal", "hell_crystal"],
		"Hell chapter Crystal portal must offer normal and Hell battlefields."
	)
	_expect(String(hub.get_node("RegionPortals/HellPortal").get_meta("expedition_variant_id")) == "hell", "Hell chapter must open Hell.")
	_expect(bool(hub.get_node("RegionPortals/HeavenPortal").get("locked")), "Heaven must remain sealed during the Hell chapter.")
	_expect("/ 4" not in (hub.get_node("PortalLabels/AutumnLabel") as Label).text, "Region labels must not expose clear-count bookkeeping.")

	hub.call(
		"configure_progression",
		{"chapter_id": "chapter_04"},
		{"autumn": 4, "heaven_autumn": 4},
		{"autumn": 4, "heaven_autumn": 4},
		{"autumn": true, "heaven_autumn": true},
		{}
	)
	autumn_options = hub.get_node("RegionPortals/AutumnPortal").get_meta("expedition_variant_options", []) as Array
	var hell_options := hub.get_node("RegionPortals/HellPortal").get_meta("expedition_variant_options", []) as Array
	_expect(
		_option_ids(autumn_options) == ["autumn", "hell_autumn", "heaven_autumn"],
		"Heaven chapter must retain all three Autumn battlefield choices."
	)
	_expect(
		_option_ids(hell_options) == ["hell", "disorder_hell"],
		"Hell portal must retain Hell and add Disorder Hell after Heaven opens."
	)
	_expect(not bool(boss.get("locked")), "Four clears must make the central boss gate triggerable.")
	var boss_options := boss.get_meta("expedition_variant_options", []) as Array
	_expect(
		_option_ids(boss_options) == ["autumn", "heaven_autumn"],
		"The central gate must retain every independently assembled Boss key."
	)
	_expect(
		"2 把" in (hub.get_node("BossLabel") as Label).text,
		"The central gate label must summarize all available Boss passage keys."
	)

	hub.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _option_ids(options: Array) -> Array[String]:
	var result: Array[String] = []
	for option_variant in options:
		if option_variant is Dictionary:
			result.append(String((option_variant as Dictionary).get("variant_id", "")))
	return result
