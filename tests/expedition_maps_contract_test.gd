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
			_expect(width >= 1600 and width <= 1700, "%s boss arena must be about 1.3 screens wide." % region_id)
			_expect(height >= 800, "%s boss arena must provide vertical play space." % region_id)
			_expect(arena.has_node("ArenaPlatforms") and arena.get_node("ArenaPlatforms").get_child_count() >= 4, "%s boss arena must provide jump platforms." % region_id)
			_expect(
				arena.find_children("TerrainFloorPanel*", "Sprite2D", true, false).size() >= 2,
				"%s boss arena must use authored floor art instead of an exposed color block." % region_id
			)
			_expect(
				arena.find_children("TerrainPlatformArt", "Sprite2D", true, false).size() >= 7,
				"%s boss arena jump platforms must use authored terrain art." % region_id
			)
			var arena_builder := arena.get_node("ArenaPlatforms")
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


func _has_visible_texture(sprite: Sprite2D) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var image := sprite.texture.get_image()
	return image != null and not image.is_empty() and image.get_used_rect().has_area()
