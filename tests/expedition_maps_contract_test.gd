extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/systems/expedition_region_catalog.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := CATALOG_SCRIPT.new()
	for region_id in catalog.get_variant_ids():
		var route_path := catalog.get_route_scene_path(region_id)
		_expect(ResourceLoader.exists(route_path), "%s route scene must exist." % region_id)
		if ResourceLoader.exists(route_path):
			var route := (load(route_path) as PackedScene).instantiate()
			root.add_child(route)
			await process_frame
			_expect(int(route.get_meta("map_width", 0)) >= 10000, "%s must be a complete long-form expedition route." % region_id)
			_expect(route.has_node("GeneratedRoute"), "%s must expose modular generated terrain." % region_id)
			var generated_route := route.get_node_or_null("GeneratedRoute")
			if generated_route is ThemedExpeditionRoute:
				var expected_terrain_path := _expected_terrain_path(region_id)
				var terrain_texture := generated_route.get("terrain_atlas_texture") as Texture2D
				_expect(
					terrain_texture != null and terrain_texture.resource_path == expected_terrain_path,
					"%s must use its authored concept terrain atlas." % region_id
				)
				_expect(
					generated_route.find_children("TerrainFloorPanel*", "Sprite2D", true, false).size() >= 8,
					"%s must skin its full floor with authored modular terrain." % region_id
				)
				_expect(
					generated_route.find_children("TerrainPlatformArt", "Sprite2D", true, false).size() >= 20,
					"%s must skin its jump platforms with authored modular terrain." % region_id
				)
				_expect(
					_has_visible_texture(generated_route.find_child("TerrainFloorPanel*", true, false) as Sprite2D),
					"%s authored floor crop must contain visible pixels." % region_id
				)
				_expect(
					_has_visible_texture(generated_route.find_child("TerrainPlatformArt", true, false) as Sprite2D),
					"%s authored platform crop must contain visible pixels." % region_id
				)
			_expect(not get_nodes_in_group("EncounterDirectors").filter(func(node: Node) -> bool: return route.is_ancestor_of(node)).is_empty(), "%s must own an encounter director." % region_id)
			_expect(route.has_node("Player"), "%s must be directly playable." % region_id)
			route.queue_free()
			await process_frame

		var boss_path := catalog.get_boss_scene_path(region_id)
		_expect(ResourceLoader.exists(boss_path), "%s boss arena must exist." % region_id)
		if ResourceLoader.exists(boss_path):
			var arena := (load(boss_path) as PackedScene).instantiate()
			root.add_child(arena)
			await process_frame
			var width := int(arena.get_meta("map_width", 0))
			var height := int(arena.get_meta("map_height", 0))
			if region_id == &"autumn":
				_expect(width == 1920 and height == 1664, "Autumn boss arena must fill the approved wide gameplay viewport while retaining vertical play space.")
			else:
				_expect(width >= 1600 and width <= 1700, "%s boss arena must be about 1.3 screens wide." % region_id)
				_expect(height >= 800, "%s boss arena must provide vertical play space." % region_id)
			var backdrop := arena.get_node_or_null("Backdrop") as Sprite2D
			var expected_backdrop_path := _expected_boss_backdrop_path(region_id)
			_expect(
				backdrop != null
					and backdrop.texture != null
					and backdrop.texture.resource_path == expected_backdrop_path,
				"%s boss arena must use its dedicated full-height authored wall." % region_id
			)
			if backdrop != null and backdrop.texture != null:
				var backdrop_size := backdrop.texture.get_size() * backdrop.scale.abs()
				_expect(
					backdrop_size.x >= float(width) - 1.0
						and backdrop_size.y >= float(height) - 1.0,
					"%s boss wall must cover the complete camera bounds without black bands." % region_id
				)
			_expect(arena.has_node("ArenaPlatforms") and arena.get_node("ArenaPlatforms").get_child_count() >= 4, "%s boss arena must provide jump platforms." % region_id)
			var authored_floor_count := arena.find_children("TerrainFloorPanel*", "Sprite2D", true, false).size()
			if region_id == &"autumn":
				authored_floor_count = 1 if arena.get_node_or_null("FloorTiles").get_child_count() == 5 else 0
			_expect(authored_floor_count == 1, "%s boss arena must use one continuous authored floor strip without a center seam." % region_id)
			_expect(
				arena.find_children("TerrainPlatformArt", "Sprite2D", true, false).size() >= 7,
				"%s boss arena jump platforms must use authored terrain art." % region_id
			)
			var arena_builder := arena.get_node("ArenaPlatforms")
			_expect(
				_boss_platforms_are_reachable(arena_builder),
				"%s boss platforms must form a monster-reachable chain." % region_id
			)
			_expect(
				_boss_platform_collisions_are_stable(arena_builder),
				"%s boss one-way platforms must align with their art and keep a generous landing margin." % region_id
			)
			var arena_terrain := arena_builder.get("terrain_texture") as Texture2D
			_expect(
				arena_terrain != null and arena_terrain.resource_path == _expected_terrain_path(region_id),
				"%s boss arena must share its route's authored terrain language." % region_id
			)
			_expect(arena.has_node("EditorHelpers") and arena.has_node("EditorHUDReference/HUD"), "%s boss arena must remain editor-reviewable." % region_id)
			var exit_portal := arena.get_node_or_null("ExitPortal")
			_expect(exit_portal != null and bool(exit_portal.get("locked")), "%s boss exit must remain sealed before victory." % region_id)
			arena.queue_free()
			await process_frame

	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _expected_terrain_path(region_id: StringName) -> String:
	match region_id:
		&"crystal", &"hell_crystal", &"heaven_crystal":
			return "res://assets/environments/expedition/generated/crystal_terrain_atlas.png"
		&"hell_autumn":
			return "res://assets/environments/expedition/generated/hell_autumn_terrain_atlas.png"
		&"heaven_autumn":
			return "res://assets/environments/expedition/generated/heaven_autumn_terrain_atlas.png"
		&"hell":
			return "res://assets/environments/expedition/generated/hell_terrain_atlas.png"
		&"disorder_hell":
			return "res://assets/environments/expedition/generated/disorder_hell_terrain_atlas.png"
		&"heaven":
			return "res://assets/environments/expedition/generated/heaven_terrain_atlas.png"
		_:
			return "res://assets/environments/autumn_town_style/generated/autumn_ground_atlas.png"


func _expected_boss_backdrop_path(region_id: StringName) -> String:
	if region_id == &"autumn":
		return "res://assets/environments/expedition/generated/autumn_boss_sky_wide_v2.png"
	return "res://assets/environments/expedition/generated/%s_boss_backdrop.png" % region_id


func _boss_platforms_are_reachable(arena_builder: Node) -> bool:
	var floor_y := 1340.0 if bool(arena_builder.get("portrait_boss_layout")) else 500.0
	var max_horizontal_edge_gap := 720.0 if bool(arena_builder.get("portrait_boss_layout")) else 280.0
	var max_vertical_step := 65.0 if bool(arena_builder.get("portrait_boss_layout")) else 130.0
	var platforms := arena_builder.find_children("JumpPlatform*", "StaticBody2D", false, false)
	for platform_variant in platforms:
		var platform := platform_variant as StaticBody2D
		if floor_y - platform.position.y <= max_vertical_step:
			continue
		var has_launch_surface := false
		for candidate_variant in platforms:
			var candidate := candidate_variant as StaticBody2D
			if candidate == platform or candidate.position.y <= platform.position.y:
				continue
			var platform_shape := (platform.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
			var candidate_shape := (candidate.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
			var edge_gap := maxf(
				0.0,
				absf(candidate.position.x - platform.position.x)
					- platform_shape.size.x * 0.5
					- candidate_shape.size.x * 0.5
			)
			if (
				candidate.position.y - platform.position.y <= max_vertical_step
				and edge_gap <= max_horizontal_edge_gap
			):
				has_launch_surface = true
				break
		if not has_launch_surface:
			return false
	return not platforms.is_empty()


func _boss_platform_collisions_are_stable(arena_builder: Node) -> bool:
	var platforms := arena_builder.find_children("JumpPlatform*", "StaticBody2D", false, false)
	for platform_variant in platforms:
		var platform := platform_variant as StaticBody2D
		var collision := platform.find_child("CollisionShape2D", false, false) as CollisionShape2D
		var art := platform.find_child("TerrainPlatformArt", false, false) as Sprite2D
		var shape := collision.shape as RectangleShape2D if collision != null else null
		if (
			collision == null
			or not collision.one_way_collision
			or collision.one_way_collision_margin < 12.0
			or shape == null
			or art == null
		):
			return false
		var collision_top := collision.position.y - shape.size.y * 0.5
		var art_top := art.position.y - art.texture.get_height() * absf(art.scale.y) * 0.5
		if not is_equal_approx(collision_top, art_top):
			return false
	return not platforms.is_empty()


func _has_visible_texture(sprite: Sprite2D) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var image := sprite.texture.get_image()
	return image != null and not image.is_empty() and image.get_used_rect().has_area()
