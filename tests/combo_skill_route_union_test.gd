extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "Skill catalog must load.")
	var basic := catalog.get_skill("silent_war_cadence")
	var advanced := catalog.get_skill("frost_orchid_wildfire")
	var master := catalog.get_skill("celestial_wildfire")
	_expect(_route_lengths(basic) == [3], "Basic skills must require exactly three Combo casts.")
	_expect(_route_lengths(advanced) == [4], "Advanced skills must require exactly four Combo casts.")
	_expect(_route_lengths(master) == [6], "Master skills must require exactly six Combo casts.")

	var advanced_routes := advanced.get("combo_routes", []) as Array
	_expect(advanced_routes.size() == 2, "Mixed advanced skills must accept two authored route orders.")
	if advanced_routes.size() == 2:
		_expect(
			advanced_routes[0] != advanced_routes[1],
			"Accepted route alternatives must not be duplicate orders."
		)
	var lightning_basic := catalog.get_skill("endless_thunder_tone")
	var lightning_basic_routes := lightning_basic.get("combo_routes", []) as Array
	_expect(
		lightning_basic_routes.has([
			"storm_charge", "storm_charge", "storm_charge",
		]),
		"The basic Lightning skill must trigger from Storm Charge three times."
	)

	var all_ids: Array[String] = []
	for skill_variant in catalog.get_all_skills():
		all_ids.append(String((skill_variant as Dictionary).get("id", "")))
	_expect(
		catalog.configure_loadout(
			all_ids,
			["moonwheel_downlight", "moonwheel_downlight"],
			99
		),
		"Loadout must normalize duplicate active IDs."
	)
	var moon_route := (catalog.get_skill("moonwheel_downlight").get("combo_routes", []) as Array)[0] as Array
	var matches: Array[Dictionary] = catalog.match_active_combo_routes(moon_route)
	_expect(matches.size() == 1, "One skill must trigger at most once for one Combo sequence.")
	_expect(
		String(matches[0].get("id", "")) == "moonwheel_downlight" if not matches.is_empty() else false,
		"Route matching must return the formal equipped skill identity."
	)

	_expect(
		catalog.configure_loadout(
			all_ids,
			["flowing_fire_night", "celestial_wildfire"],
			99
		),
		"Two skills sharing one route must be equippable together."
	)
	var shared_route := (catalog.get_skill("celestial_wildfire").get("combo_routes", []) as Array)[0] as Array
	var union_matches: Array[Dictionary] = catalog.match_active_combo_routes(shared_route)
	_expect(union_matches.size() == 2, "One Combo sequence must trigger every equipped matching skill.")
	var matched_ids: Array[String] = []
	for match_variant in union_matches:
		matched_ids.append(String((match_variant as Dictionary).get("id", "")))
	_expect(
		matched_ids == ["flowing_fire_night", "celestial_wildfire"],
		"Union triggers must preserve deterministic loadout order."
	)

	if _failures == 0:
		print("PASS: formal Combo routes use 3/4/6 casts and union-trigger equipped skills")
	quit(1 if _failures > 0 else 0)


func _route_lengths(skill: Dictionary) -> Array[int]:
	var lengths: Array[int] = []
	for route_variant in skill.get("combo_routes", []) as Array:
		var length := (route_variant as Array).size()
		if not lengths.has(length):
			lengths.append(length)
	lengths.sort()
	return lengths


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
