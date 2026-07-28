extends SceneTree

const BATTLE_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const SAFE_CANONICAL_PATH := "res://scenes/maps/autumn_safe_zone.tscn"
const LEGACY_WIDTH := 2600
const MINIMUM_CHUNKS := 24
const MINIMUM_FLOOR_PROFILES := 5
const MINIMUM_PLATFORM_VARIANTS := 6
const MINIMUM_FLOOR_SEGMENTS := 8
const MINIMUM_ROUTE_RELIEF := 96.0

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BATTLE_MAP_PATH) as PackedScene
	_expect(packed != null, "Autumn battle map must load for modular route checks.")
	if packed == null:
		quit(1)
		return

	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	var map_width := int(map.get_meta("map_width", 0))
	_expect(
		map_width >= LEGACY_WIDTH * 4,
		"Autumn battle route must be at least four times the legacy width."
	)
	_expect(
		int(map.get_meta("camera_limit_right", 0)) == map_width,
		"Battle camera right limit must equal the generated route width."
	)
	for node_path in [
		"GeneratedBackdrop",
		"GeneratedRoute",
		"WestSafePortal",
		"EastSafePortal",
		"PlayerSpawn",
		"WorldBounds/LeftWall",
		"WorldBounds/RightWall",
	]:
		_expect(map.has_node(node_path), "Modular battle map must contain %s." % node_path)

	var route := map.get_node_or_null("GeneratedRoute")
	_expect(route != null and route.has_method("regenerate"), "GeneratedRoute must expose regenerate(seed).")
	_expect(route != null and route.has_method("get_manifest"), "GeneratedRoute must expose its manifest.")
	_expect(
		route != null and route.has_method("get_route_fingerprint"),
		"GeneratedRoute must expose a deterministic terrain fingerprint."
	)
	_expect(
		route != null and route.has_method("get_active_seed"),
		"GeneratedRoute must expose its active seed for debug reproduction."
	)
	if route != null and route.has_method("regenerate"):
		route.call("regenerate", 481516)
		_expect(int(route.call("get_active_seed")) == 481516, "Generated route must report its active seed.")
		_expect(int(route.get_meta("route_seed", 0)) == 481516, "Route seed must remain inspectable as metadata.")
		var first_manifest := route.call("get_manifest") as Array
		var first_fingerprint := String(route.call("get_route_fingerprint"))
		_assert_manifest(first_manifest, map_width)
		route.call("regenerate", 481516)
		_expect(
			String(route.call("get_route_fingerprint")) == first_fingerprint,
			"Identical seeds must reproduce the same terrain fingerprint."
		)
		route.call("regenerate", 8675309)
		_expect(
			String(route.call("get_route_fingerprint")) != first_fingerprint,
			"Different entries must be able to produce different terrain fingerprints."
		)
		for audit_seed in [8675309, 20260728, 314159]:
			route.call("regenerate", audit_seed)
			_assert_manifest(route.call("get_manifest") as Array, map_width)

	for portal_path in ["WestSafePortal", "EastSafePortal"]:
		var portal := map.get_node_or_null(portal_path)
		if portal != null:
			_expect(
				String(portal.get("target_scene_path")) == SAFE_CANONICAL_PATH,
				"%s must return to the Autumn safe zone." % portal_path
			)
	var west_portal := map.get_node_or_null("WestSafePortal") as Node2D
	var east_portal := map.get_node_or_null("EastSafePortal") as Node2D
	if west_portal != null:
		_expect(west_portal.position.x <= 160.0, "West safe portal must remain at the route head.")
	if east_portal != null:
		_expect(
			east_portal.position.x >= float(map_width) - 160.0,
			"East safe portal must remain at the route tail."
		)
	_assert_route_wide_spawning(map)

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _assert_manifest(manifest: Array, map_width: int) -> void:
	_expect(
		manifest.size() >= MINIMUM_CHUNKS,
		"Generated route must contain at least %d modules." % MINIMUM_CHUNKS
	)
	var variant_ids: Dictionary = {}
	var floor_profiles: Dictionary = {}
	var platform_variants: Dictionary = {}
	var expected_left := 0.0
	var previous_floor_exit := -1.0
	var route_minimum_floor_y := 999.0
	var route_maximum_floor_y := 0.0
	var platform_chunks := 0
	var relief_chunks := 0
	var flat_chunks := 0
	var consecutive_relief := 0
	var maximum_consecutive_relief := 0
	var consecutive_platform_chunks := 0
	var maximum_consecutive_platform_chunks := 0
	var empty_platform_streak := 0
	var maximum_empty_platform_streak := 0
	var has_high_route := false
	for entry_variant in manifest:
		_expect(entry_variant is Dictionary, "Every route manifest entry must be structured.")
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var left := float(entry.get("left", -1.0))
		var right := float(entry.get("right", -1.0))
		_expect(
			is_equal_approx(left, expected_left),
			"Route module seams must remain continuous at x=%d." % int(expected_left)
		)
		_expect(right > left, "Every route module must contribute positive width.")
		_expect(
			bool(entry.get("continuous_floor", false)),
			"Every module must preserve a continuous ground route."
		)
		var floor_entry_y := float(entry.get("floor_entry_y", -1.0))
		var floor_exit_y := float(entry.get("floor_exit_y", -1.0))
		_expect(
			int(entry.get("floor_segment_count", 0)) >= MINIMUM_FLOOR_SEGMENTS,
			"Every module must assemble at least %d terrain segments for detailed relief."
			% MINIMUM_FLOOR_SEGMENTS
		)
		_expect(
			not String(entry.get("floor_signature", "")).is_empty(),
			"Every module must expose its generated floor signature."
		)
		_expect(
			float(entry.get("minimum_floor_y", 0.0)) >= 360.0
				and float(entry.get("maximum_floor_y", 999.0)) <= 470.0,
			"Every floor segment must remain visible above the combat HUD."
		)
		route_minimum_floor_y = minf(
			route_minimum_floor_y,
			float(entry.get("minimum_floor_y", 999.0))
		)
		route_maximum_floor_y = maxf(
			route_maximum_floor_y,
			float(entry.get("maximum_floor_y", 0.0))
		)
		_expect(
			float(entry.get("visual_fill_bottom", 0.0)) >= 620.0,
			"Every terrain column must extend below the visible world without gaps."
		)
		_expect(
			float(entry.get("maximum_floor_step", 999.0)) <= 24.0,
			"Adjacent terrain columns must remain traversable without a blocking wall."
		)
		if previous_floor_exit >= 0.0:
			_expect(
				is_equal_approx(floor_entry_y, previous_floor_exit),
				"Adjacent floor modules must connect without a vertical seam."
			)
		previous_floor_exit = floor_exit_y
		floor_profiles[String(entry.get("floor_profile", ""))] = true
		if (
			float(entry.get("maximum_floor_y", 0.0))
			- float(entry.get("minimum_floor_y", 0.0))
		) >= 16.0:
			relief_chunks += 1
			consecutive_relief += 1
			maximum_consecutive_relief = maxi(
				maximum_consecutive_relief,
				consecutive_relief
			)
		else:
			flat_chunks += 1
			consecutive_relief = 0
		platform_variants[String(entry.get("variant", ""))] = true
		expected_left = right
		var variant_id := String(entry.get("variant", ""))
		variant_ids[variant_id] = true
		var platform_count := int(entry.get("platform_count", -1))
		if platform_count == 0:
			empty_platform_streak += 1
			consecutive_platform_chunks = 0
			maximum_empty_platform_streak = maxi(
				maximum_empty_platform_streak,
				empty_platform_streak
			)
		else:
			platform_chunks += 1
			empty_platform_streak = 0
			consecutive_platform_chunks += 1
			maximum_consecutive_platform_chunks = maxi(
				maximum_consecutive_platform_chunks,
				consecutive_platform_chunks
			)
		if float(entry.get("minimum_platform_y", 999.0)) <= 300.0:
			has_high_route = true
	_expect(
		is_equal_approx(expected_left, float(map_width)),
		"Route manifest must cover the complete battle width."
	)
	_expect(
		floor_profiles.size() >= MINIMUM_FLOOR_PROFILES,
		"Generated route must use at least %d distinct floor profiles."
		% MINIMUM_FLOOR_PROFILES
	)
	_expect(
		platform_variants.size() >= MINIMUM_PLATFORM_VARIANTS,
		"Generated route must use at least %d distinct platform assemblies."
		% MINIMUM_PLATFORM_VARIANTS
	)
	_expect(
		platform_chunks >= 8 and platform_chunks <= 14,
		"Raised traversal must form occasional clusters instead of covering the route."
	)
	_expect(
		flat_chunks >= 6 and flat_chunks <= 12,
		"Macro terrain must mix substantial flat zones with high and low landmarks."
	)
	_expect(
		relief_chunks >= 8,
		"Macro terrain must retain enough high and low landmark modules."
	)
	_expect(
		maximum_consecutive_relief <= 2,
		"Terrain transitions must not become a long connected staircase."
	)
	_expect(
		maximum_consecutive_platform_chunks <= 2,
		"Floating platforms must not form a long continuous ceiling."
	)
	_expect(
		maximum_empty_platform_streak <= 2,
		"Generated route must not leave large consecutive areas without platforms."
	)
	_expect(has_high_route, "Generated route must include at least one reachable upper-canopy sequence.")
	_expect(
		route_maximum_floor_y - route_minimum_floor_y >= MINIMUM_ROUTE_RELIEF,
		"Generated floor must use at least %d pixels of vertical relief."
		% int(MINIMUM_ROUTE_RELIEF)
	)


func _assert_route_wide_spawning(map: Node) -> void:
	var player := map.get_node_or_null("Player") as Node2D
	var director := map.get_node_or_null("AutumnRunDirector") as SurvivalWaveDirector
	_expect(player != null and director != null, "Route-wide spawning requires Player and director.")
	if player == null or director == null:
		return
	player.global_position = Vector2(300, 470)
	_expect(director.start_encounter(), "Route-wide director must start for spawn verification.")
	var enemies := director.get_active_enemies()
	_expect(enemies.size() >= 3, "Route-wide encounter must open with a visible enemy group.")
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		var spawn_x := (enemy as Node2D).global_position.x
		var distance_from_player := absf(spawn_x - player.global_position.x)
		_expect(
			spawn_x >= 260.0 and spawn_x <= 10300.0,
			"Route-wide enemy spawn must remain inside battle bounds."
		)
		_expect(
			distance_from_player >= 720.0 and distance_from_player <= 1040.0,
			"Enemies must enter from outside the camera perimeter instead of appearing onscreen."
		)
	var recycled_enemy := enemies[0] as Node2D
	recycled_enemy.global_position = player.global_position + Vector2(1800.0, 0.0)
	director.advance_survival(0.51)
	var recycled_distance := absf(
		recycled_enemy.global_position.x - player.global_position.x
	)
	_expect(
		recycled_distance >= 720.0 and recycled_distance <= 1040.0,
		"Distant enemies must recycle to the offscreen perimeter so nearby pressure continues."
	)
	_expect(
		bool(recycled_enemy.get_meta("persistent_pursuit", false)),
		"Survival enemies must pursue the player beyond ordinary detection range."
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
