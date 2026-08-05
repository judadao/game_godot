extends SceneTree

const ARENA_SCENE := preload("res://scenes/maps/boss/AutumnBossArena.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := ARENA_SCENE.instantiate()
	root.add_child(arena)
	await process_frame

	var background := arena.get_node_or_null("Backdrop") as Sprite2D
	_expect(bool(arena.get_meta("hide_objective_hud", false)), "Autumn boss room must hide the mission HUD.")
	_expect(bool(arena.get_meta("hide_meta_hud", false)), "Autumn boss room must hide the currency and settings HUD.")
	var scenery := arena.get_node_or_null("ModularScenery")
	var floor_tiles := arena.get_node_or_null("FloorTiles")
	_expect(background != null and background.texture != null, "Autumn boss background must be authored.")
	_expect(scenery != null and scenery.get_child_count() >= 8, "Autumn boss room must be assembled from modular scenery objects.")
	_expect(floor_tiles != null and floor_tiles.get_child_count() == 5, "Autumn boss floor must use five native-scale atlas tiles.")
	if floor_tiles != null:
		for tile_variant in floor_tiles.get_children():
			var tile := tile_variant as Sprite2D
			_expect(tile != null and tile.scale == Vector2.ONE, "Autumn boss floor tiles must never be stretched.")
	_expect(arena.has_node("ArenaOverviewCamera"), "Autumn boss room must use a vertically tracking camera.")
	_expect(
		String(arena.get_meta("boss_presentation_role", "")) == "background_colossus",
		"Autumn boss room must frame its boss as a background colossus.",
	)
	_expect(
		float(arena.get_meta("boss_target_player_height_ratio", 0.0)) >= 4.0,
		"Autumn boss presentation must target at least a four-to-one player height ratio.",
	)
	_expect(
		float(arena.get_meta("boss_minimum_visible_fraction", 0.0)) >= 0.8,
		"At least four fifths of the boss body must remain inside the gameplay frame.",
	)
	if scenery != null:
		for prop_variant in scenery.get_children():
			var prop := prop_variant as Sprite2D
			_expect(prop != null and prop.texture != null, "Every modular scenery object must own an authored texture region.")
			if prop != null:
				_expect(_has_transparent_corner(prop.texture), "Modular scenery regions must retain transparent corners.")

	var director := arena.get_node_or_null("RegionalBossDirector")
	_expect(director is Node2D and (director as Node2D).z_index < 30, "Boss presentation must remain behind the player foreground plane.")
	var guardian_scene := director.get("guardian_scene") as PackedScene if director != null else null
	_expect(guardian_scene != null, "Autumn boss director must own a dedicated boss scene.")
	if guardian_scene != null:
		_expect(
			guardian_scene.resource_path == "res://scenes/monsters/AutumnSixArmColossusBoss.tscn",
			"Autumn boss director must spawn the approved six-arm colossus."
		)
		var boss := guardian_scene.instantiate()
		_expect(boss.has_node("Visual/Core/HeadPivot/UpperSkullKabuto"), "Colossus boss must own a separate upper skull and kabuto.")
		_expect(boss.has_node("Visual/Core/HeadPivot/JawPivot/LowerJaw"), "Colossus boss must own an independently animated lower jaw.")
		_expect(boss.has_node("Visual/Core/Torso") and boss.has_node("Visual/Core/Pelvis"), "Colossus torso and pelvis must remain separate animation parts.")
		var boss_arms := boss.get_node("Visual/Armature").get_children().filter(
			func(child: Node) -> bool: return child.name.begins_with("Arm")
		)
		_expect(boss_arms.size() == 6, "Colossus boss must expose six independent shoulder pivots.")
		for arm_variant in boss_arms:
			var arm := arm_variant as Node
			_expect(
				arm.has_node("UpperArm")
					and arm.has_node("ElbowPivot/Forearm")
					and arm.has_node("ElbowPivot/WristPivot/HandKatana"),
				"Every colossus arm must expose upper-arm, elbow, forearm, wrist, hand, and katana parts."
			)
		boss.free()
		_expect(bool(director.call("start_encounter")), "Autumn boss encounter must start for presentation verification.")
		await process_frame
		var active_bosses: Array = director.call("get_active_enemies")
		_expect(active_bosses.size() == 1, "Autumn boss encounter must spawn exactly one cinematic boss.")
		if active_bosses.size() == 1:
			var active_boss := active_bosses[0] as CharacterBody2D
			_expect(active_boss != null and active_boss.z_index == 0, "The giant boss and all relative child layers must remain behind the platform art plane.")
			_expect(active_boss != null and active_boss.collision_layer == 0 and active_boss.collision_mask == 0, "The background colossus must not collide with arena platforms.")
			_expect(
				active_boss != null and String(active_boss.get_meta("presentation_role", "")) == "background_colossus",
				"The spawned boss must receive the arena's cinematic presentation contract.",
			)

	var platforms := arena.get_node("ArenaPlatforms").find_children("JumpPlatform*", "StaticBody2D", false, false)
	_expect(platforms.size() == 7, "Autumn boss arena must retain seven asymmetric platforms.")
	var sorted_platforms := platforms.duplicate()
	sorted_platforms.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node2D).position.y < (b as Node2D).position.y)
	for index in range(1, sorted_platforms.size()):
		var gap := (sorted_platforms[index] as Node2D).position.y - (sorted_platforms[index - 1] as Node2D).position.y
		_expect(gap <= 205.0, "Successive portrait platforms must remain inside the boss-room jump-height budget.")
	_expect(
		director is Node2D and (director as Node2D).position.distance_to(Vector2(960, 1340)) <= 1.0,
		"The smoke oni boss must spawn on the central ground stage."
	)

	arena.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _has_transparent_corner(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	return image.get_pixel(0, 0).a <= 0.05


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
