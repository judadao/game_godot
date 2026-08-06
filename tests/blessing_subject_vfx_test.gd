extends SceneTree

const MANAGER_SCRIPT := preload("res://scripts/systems/divine_gift_manager.gd")
const BACKGROUND_SCENE := preload("res://scenes/combat/vfx/EvolvedBackgroundAttack.tscn")
const FEEDBACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")
const BASE_IDS := [
	"resonant_grace",
	"echoing_will",
	"boundless_font",
	"prismatic_oath",
	"celestial_momentum",
	"eternal_memory",
	"tidal_covenant",
	"radiant_mercy",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := MANAGER_SCRIPT.new()
	_expect(manager.load_catalog(), "Blessing catalog must load with concrete attack assets.")
	var recipe_paths: Dictionary = {}
	var motions: Dictionary = {}
	var recipes := manager.get_fusion_recipes()
	_expect(recipes.size() == 10, "Exactly ten advanced Blessing recipes must remain authored.")
	for recipe in recipes:
		var asset_path := String(recipe.get("subject_asset_path", ""))
		var motion := String(recipe.get("subject_motion", ""))
		_expect(
			not asset_path.is_empty() and ResourceLoader.exists(asset_path),
			"Every advanced Blessing needs a loadable concrete subject: %s." % recipe.get("id", "")
		)
		_expect(not motion.is_empty(), "Every advanced Blessing needs a subject-specific motion.")
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture != null else Image.new()
		_expect(
			not image.is_empty() and image.detect_alpha() != Image.ALPHA_NONE,
			"Advanced Blessing subjects must preserve true alpha: %s." % asset_path
		)
		recipe_paths[asset_path] = true
		motions[motion] = true
	_expect(recipe_paths.size() == 10, "Advanced Blessings must not reuse one generic subject asset.")
	_expect(motions.size() == 10, "All ten advanced Blessings need distinct motion identities.")

	var base_paths: Dictionary = {}
	var base_motions: Dictionary = {}
	var base_profiles: Array[Dictionary] = []
	for gift_id in BASE_IDS:
		manager.reset_run()
		_expect(manager.add_or_upgrade(gift_id), "Base Blessing must be acquirable: %s." % gift_id)
		var profiles := manager.get_basic_attack_visual_profiles()
		_expect(profiles.size() == 1, "Owned base Blessing must affect the basic attack: %s." % gift_id)
		if profiles.is_empty():
			continue
		var asset_path := String(profiles[0].get("asset_path", ""))
		var motion := String(profiles[0].get("motion", ""))
		base_paths[asset_path] = true
		base_motions[motion] = true
		base_profiles.append((profiles[0] as Dictionary).duplicate(true))
		_expect(ResourceLoader.exists(asset_path), "Base attack object must load: %s." % asset_path)
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture != null else Image.new()
		_expect(
			not image.is_empty() and image.detect_alpha() != Image.ALPHA_NONE,
			"Concrete Blessing objects must use true alpha instead of black boxes: %s." % asset_path
		)
	_expect(base_paths.size() == 8, "Eight base Blessings must use eight readable object assets.")
	_expect(base_motions.size() == 8 and not base_motions.has(""), "Eight base Blessings need eight distinct Basic Attack trajectories.")

	manager.reset_run()
	for gift_id in ["resonant_grace", "prismatic_oath"]:
		for _upgrade in 3:
			_expect(manager.add_or_upgrade(gift_id), "Fusion test material must reach Lv.3.")
	var evolved := manager.fuse_max_level("resonant_grace", "prismatic_oath")
	var evolved_profiles := manager.get_basic_attack_visual_profiles()
	_expect(
		not evolved.is_empty()
			and evolved_profiles.size() == 1
			and bool(evolved_profiles[0].get("evolved", false))
			and String(evolved_profiles[0].get("asset_path", "")).ends_with("thunderflame_wheel.png"),
		"An evolved Blessing must replace its materials with its own concrete Basic Attack subject."
	)

	var background := BACKGROUND_SCENE.instantiate()
	root.add_child(background)
	await process_frame
	var sample_recipe := recipes[7] as Dictionary
	var targets: Array[Vector2] = [Vector2(180.0, 0.0)]
	background.play({
		"pattern": "prismatic_orbit",
		"subject_asset_path": sample_recipe.get("subject_asset_path", ""),
		"subject_motion": sample_recipe.get("subject_motion", ""),
		"instance_count": 6,
		"size_scale": 2.2,
		"rhythm_speed": 1.8,
		"destruction_tier": 3,
		"accent_color": "#76efcf",
	}, targets)
	_expect(
		background.get_subject_motion() == &"warhorse_charge"
			and background.get_subject_instance_count() == 2
			and not bool(background.call("uses_abstract_geometry"))
			and float(background.call("get_attack_duration")) >= 1.25,
		"Advanced Blessing attacks must show a slow readable subject pair without abstract geometry."
	)
	background.queue_free()

	var feedback := FEEDBACK_SCENE.instantiate()
	root.add_child(feedback)
	await process_frame
	base_profiles[0]["level"] = 1
	base_profiles[1]["level"] = 3
	feedback.play(
		Vector2.ZERO,
		Vector2(260.0, 0.0),
		20,
		6,
		0,
		false,
		1.0,
		1.0,
		{"stack_count": 8, "blessing_attack_profiles": [base_profiles[0], base_profiles[1]]}
	)
	_expect(
		feedback.get_blessing_overlay_object_count() >= 2
			and feedback.get_blessing_overlay_object_count() <= 4
			and bool(feedback.call("is_blessing_attack_override_active"))
			and feedback.get_travel_duration() >= 0.28,
		"Blessings must replace the generic Basic Attack with fewer, larger, slower concrete subjects."
	)
	feedback.queue_free()
	await process_frame

	if _failures == 0:
		print("PASS: concrete Blessing subjects drive advanced and Basic Attack VFX")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
