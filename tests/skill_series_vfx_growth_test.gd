extends SceneTree

const PROFILE_PATH := "res://data/skill_series_vfx.json"
const EXPECTED_SERIES_IDS := [
	"sword_rain", "moon_wheel", "feather", "ancient_wood", "giant_stone",
	"great_shield", "fire", "lightning", "water_flow", "plant_attack",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists(PROFILE_PATH), "Skill-series VFX needs one authoritative profile catalog.")
	if not FileAccess.file_exists(PROFILE_PATH):
		_finish()
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_expect(parsed is Dictionary, "Skill-series VFX catalog must parse as a dictionary.")
	if not parsed is Dictionary:
		_finish()
		return
	var profiles := (parsed as Dictionary).get("profiles", []) as Array
	_expect(profiles.size() == EXPECTED_SERIES_IDS.size(), "Every official skill series needs exactly one reusable main-object profile.")
	var actual_ids: Array[String] = []
	for profile_variant in profiles:
		var profile := profile_variant as Dictionary
		var series_id := String(profile.get("id", ""))
		actual_ids.append(series_id)
		var asset_path := String(profile.get("asset_path", ""))
		_expect(not asset_path.is_empty() and ResourceLoader.exists(asset_path, "Texture2D"), "%s needs one loadable main-object texture." % series_id)
		var source_image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
		_expect(not source_image.is_empty(), "%s main-object PNG must decode." % series_id)
		if not source_image.is_empty():
			var corner_alpha := 0.0
			for corner in [
				Vector2i.ZERO,
				Vector2i(source_image.get_width() - 1, 0),
				Vector2i(0, source_image.get_height() - 1),
				Vector2i(source_image.get_width() - 1, source_image.get_height() - 1),
			]:
				corner_alpha += source_image.get_pixelv(corner).a
			_expect(corner_alpha <= 0.04, "%s must remain a transparent cutout, not a baked rectangular effect sheet." % series_id)
		var tiers := profile.get("tiers", []) as Array
		_expect(tiers.size() == 3, "%s needs basic, advanced, and master formation tiers." % series_id)
		if tiers.size() != 3:
			continue
		var basic := tiers[0] as Dictionary
		var advanced := tiers[1] as Dictionary
		var master := tiers[2] as Dictionary
		if series_id == "feather":
			_expect(
				is_equal_approx(float(profile.get("halo_lifetime_seconds", 0.0)), 4.8)
					and float(profile.get("halo_fade_seconds", 0.0)) > 0.0
					and float(profile.get("halo_summon_stagger_seconds", 0.0)) > 0.0
					and float(profile.get("halo_orbit_speed", 0.0)) > 0.0
					and float(profile.get("halo_feather_dissolve_seconds", 0.0)) > 0.0,
				"Feather must expose persistent halo lifetime, fade, stagger, and orbit timing."
			)
			_expect(
				float(profile.get("halo_basic_radius", 0.0))
					< float(profile.get("halo_advanced_radius", 0.0))
					and float(profile.get("halo_advanced_radius", 0.0))
					< float(profile.get("halo_master_radius", 0.0)),
				"Feather halo radii must grow through basic, advanced, and master tiers."
			)
			_expect(
				float(basic.get("halo_duration_seconds", 0.0))
					< float(advanced.get("halo_duration_seconds", 0.0))
					and float(advanced.get("halo_duration_seconds", 0.0))
					< float(master.get("halo_duration_seconds", 0.0)),
				"More Feather objects must keep the contact halo active longer."
			)
		if series_id == "ancient_wood":
			_expect(int(basic.get("node_count", 0)) == 2 and int(advanced.get("node_count", 0)) == 4 and int(master.get("node_count", 0)) == 6, "Ancient Wood must grow a 2/4/6-node sword-aura gate network.")
		else:
			_expect(bool(profile.get("launches_object", false)), "%s must explicitly declare its launched-object presentation." % series_id)
			_expect(float(profile.get("minimum_render_size", 0.0)) >= 112.0, "%s launched object must remain visually readable." % series_id)
			_expect(int(basic.get("object_count", 0)) >= 3 and int(basic.get("path_count", 0)) >= 3 and int(basic.get("direction_count", 0)) >= 3, "%s basic launched-object tier must already fill at least three paths." % series_id)
			_expect(int(advanced.get("object_count", 0)) > int(basic.get("object_count", 0)) and int(advanced.get("path_count", 0)) >= 3 and int(advanced.get("direction_count", 0)) >= 3, "%s advanced launched-object tier must densify its multi-path formation." % series_id)
		_expect(int(master.get("object_count", 0)) > int(advanced.get("object_count", 0)), "%s master tier must add more copies of the same object." % series_id)
		_expect(int(master.get("path_count", 0)) >= 3 and int(master.get("direction_count", 0)) >= 3, "%s master tier must preserve multiple paths and directions." % series_id)
	_expect(actual_ids == EXPECTED_SERIES_IDS, "Skill-series VFX profiles must preserve official series order.")

	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null and effect.has_method("play_series"), "NamedSkillVFX must expose the shared series-object playback entry.")
	if effect != null:
		root.add_child(effect)
		await process_frame
		if effect.has_method("play_series"):
			effect.call("play_series", "feather", 1, 1, true)
			var basic_state := effect.call("get_series_debug_state") as Dictionary
			effect.call("play_series", "feather", 2, 1, true)
			var advanced_state := effect.call("get_series_debug_state") as Dictionary
			effect.call("play_series", "feather", 3, 1, true)
			var master_state := effect.call("get_series_debug_state") as Dictionary
			_expect(int(basic_state.get("object_count", 0)) >= 3 and int(basic_state.get("path_count", 0)) >= 3, "Basic feather playback must render at least three readable sacred-feather lanes.")
			_expect(int(advanced_state.get("path_count", 0)) >= 3 and int(advanced_state.get("object_count", 0)) > int(basic_state.get("object_count", 0)), "Advanced feather playback must densify its multi-lane formation.")
			_expect(int(master_state.get("path_count", 0)) >= 3 and int(master_state.get("direction_count", 0)) >= 3, "Master feather playback must fan into multiple paths and directions.")
			_expect(String(basic_state.get("asset_path", "")) == String(master_state.get("asset_path", "")), "All feather tiers must reuse one main-object texture.")
		effect.queue_free()
		await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: launched skill-series VFX starts at three readable paths and grows through density")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
