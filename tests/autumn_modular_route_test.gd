extends SceneTree

const BATTLE_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const SAFE_CANONICAL_PATH := "res://scenes/maps/autumn_safe_zone.tscn"
const LEGACY_WIDTH := 2600
const MINIMUM_CHUNKS := 24
const MINIMUM_VARIANTS := 4

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
	var expected_left := 0.0
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
		expected_left = right
		variant_ids[String(entry.get("variant", ""))] = true
	_expect(
		is_equal_approx(expected_left, float(map_width)),
		"Route manifest must cover the complete battle width."
	)
	_expect(
		variant_ids.size() >= MINIMUM_VARIANTS,
		"Generated route must use at least %d distinct module variants." % MINIMUM_VARIANTS
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
			distance_from_player >= 340.0 and distance_from_player <= 650.0,
			"Route-head enemies must keep safe distance instead of clamping onto the player."
		)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
