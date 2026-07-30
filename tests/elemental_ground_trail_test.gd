extends SceneTree

const SCENE_PATH := "res://scenes/combat/vfx/ElementalGroundTrail.tscn"
const CATALOG_PATH := "res://scripts/systems/elemental_ground_trail_catalog.gd"
const PROFILE_IDS := ["fire_path", "ice_path", "poison_pool"]
const EXPECTED_TOPOLOGIES := {
	"fire_path": "burning_scar",
	"ice_path": "frozen_rift",
	"poison_pool": "toxic_puddle",
}
const EXPECTED_ATLASES := {
	"fire_path": "res://assets/generated/vfx/ground/fire_ground_path_parts_v1.png",
	"ice_path": "res://assets/generated/vfx/ground/ice_ground_path_parts_v1.png",
	"poison_pool": "res://assets/generated/vfx/ground/poison_ground_path_parts_v1.png",
}
const EXPECTED_ATLAS_REGIONS := {
	"core": Rect2(0.0, 0.0, 768.0, 512.0),
	"edge": Rect2(768.0, 0.0, 768.0, 512.0),
	"accent": Rect2(0.0, 512.0, 768.0, 512.0),
	"debris": Rect2(768.0, 512.0, 768.0, 512.0),
}
const SLOT_NAMES := [&"Core", &"Edge", &"Accent", &"Debris"]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var catalog_script := load(CATALOG_PATH) as GDScript
	_expect(packed != null, "Ground trail needs one reusable authored scene.")
	_expect(catalog_script != null, "Ground trail profiles need one validated catalog.")
	if packed == null or catalog_script == null:
		_finish()
		return

	var catalog: RefCounted = catalog_script.new()
	_expect(bool(catalog.call("load_catalog")), "Ground trail profile data must load.")
	var profiles := catalog.call("get_all_profiles") as Array
	_expect(profiles.size() == 3, "Fire, ice, and poison need extensible ground profiles.")
	var topology_ids: Dictionary = {}
	for profile_id in PROFILE_IDS:
		var profile := catalog.call("get_profile", profile_id) as Dictionary
		_expect(not profile.is_empty(), "Missing ground trail profile: %s." % profile_id)
		var topology := String(profile.get("topology", ""))
		_expect(
			topology == String(EXPECTED_TOPOLOGIES[profile_id]),
			"Ground trail profile needs its own topology: %s." % profile_id
		)
		_expect(
			not topology_ids.has(topology),
			"Ground trail profiles must not share one renamed topology: %s." % topology
		)
		topology_ids[topology] = profile_id
		var slots := profile.get("slots", {}) as Dictionary
		var atlas_path := String(profile.get("atlas_path", ""))
		_expect(
			atlas_path == String(EXPECTED_ATLASES[profile_id]),
			"Ground trail %s must reference its element-specific atlas." % profile_id
		)
		var atlas := load(atlas_path) as Texture2D
		_expect(atlas != null, "Ground trail atlas must load: %s." % profile_id)
		if atlas != null:
			_expect(
				Vector2i(atlas.get_size()) == Vector2i(1536, 1024),
				"Ground trail atlas dimensions must match the region contract: %s." % profile_id
			)
		var regions := profile.get("atlas_regions", {}) as Dictionary
		var occupied_regions: Array[Rect2] = []
		for slot_name in ["core", "edge", "accent", "debris"]:
			_expect(
				not String(slots.get(slot_name, "")).is_empty(),
				"Ground trail %s must declare the %s material slot." % [profile_id, slot_name]
			)
			var region := _rect_from_array(regions.get(slot_name, []) as Array)
			_expect(
				region == EXPECTED_ATLAS_REGIONS[slot_name],
				"Ground trail %s must map the %s atlas quadrant exactly."
				% [profile_id, slot_name]
			)
			for occupied in occupied_regions:
				_expect(
					not occupied.intersects(region),
					"Ground trail %s atlas quadrants must not overlap." % profile_id
				)
			occupied_regions.append(region)

	var effect := packed.instantiate() as Node2D
	root.add_child(effect)
	await process_frame
	_expect(effect.has_method("play_path"), "Ground trail must expose play_path().")
	_expect(effect.has_method("play_world_path"), "Ground trail must expose a world-space wiring API.")
	_expect(effect.has_method("get_segment_count"), "Ground trail must expose its sampled segment count.")
	_expect(effect.has_method("get_visual_slot_count"), "Ground trail must expose its composable slot count.")
	_expect(effect.has_method("get_profile_id"), "Ground trail must retain its exact profile identity.")
	_expect(effect.has_method("get_atlas_path"), "Ground trail must expose its assembled atlas identity.")
	_expect(effect.has_method("get_stage_name"), "Ground trail must expose fresh/active/decay stages.")
	_expect(
		effect.has_method("uses_unscaled_timeline")
			and bool(effect.call("uses_unscaled_timeline")),
		"Ground trails must reveal in real time so slow motion cannot detach them from the ultimate impact."
	)
	_expect(effect.has_signal("trail_finished"), "Ground trail must announce presentation cleanup.")
	_expect(
		effect.get_node_or_null("PathUnderlay/CoreRibbon") is Line2D
			and effect.get_node_or_null("PathUnderlay/EdgeRibbon") is Line2D,
		"Ground trail needs continuous core and edge ribbons beneath modular segments."
	)
	_expect(effect.get_node_or_null("SegmentOwner") is Node2D, "Ground trail scene needs one segment owner.")

	var path := PackedVector2Array([
		Vector2(80.0, 220.0),
		Vector2(290.0, 210.0),
		Vector2(520.0, 245.0),
	])
	var played := bool(effect.call("play_path", "fire_path", path, 1.2, 1.0))
	_expect(played, "A valid fire path must begin presentation.")
	_expect(String(effect.call("get_profile_id")) == "fire_path", "Ground trail must retain exact profile ID.")
	_expect(
		String(effect.call("get_atlas_path")) == String(EXPECTED_ATLASES["fire_path"]),
		"Ground trail must retain the selected atlas path."
	)
	_expect(String(effect.call("get_element")) == "fire", "Fire path must retain the formal fire element.")
	_expect(String(effect.call("get_topology")) == "burning_scar", "Fire path must use burning-scar topology.")
	var segment_count := int(effect.call("get_segment_count"))
	_expect(segment_count >= 5 and segment_count <= 24, "Path sampling must be dense but bounded.")
	_expect(
		int(effect.call("get_visual_budget")) <= 224,
		"Ground trail segments and debris must remain inside a bounded visual budget."
	)
	var sampled_points := effect.call("get_sampled_points") as PackedVector2Array
	_expect(
		sampled_points[0].is_equal_approx(path[0])
			and sampled_points[-1].is_equal_approx(path[-1]),
		"Ground trail sampling must preserve both path endpoints."
	)
	_expect(
		int(effect.call("get_visual_slot_count")) == segment_count * SLOT_NAMES.size(),
		"Every sampled segment must assemble core, edge, accent, and debris slots."
	)
	_expect_runtime_atlas(effect, "fire_path")

	effect.call("debug_set_progress", 0.82)
	_expect(
		StringName(effect.call("get_stage_name")) == &"decay",
		"Late ground residue must enter a readable decay stage."
	)
	effect.set("auto_free", false)
	played = bool(effect.call(
		"play_path",
		"ice_path",
		PackedVector2Array([Vector2(120.0, 250.0), Vector2(460.0, 260.0)]),
		1.0,
		1.0
	))
	_expect(played, "Ice path profile must replay through the same scene.")
	_expect_runtime_atlas(effect, "ice_path")
	played = bool(effect.call(
		"play_path",
		"poison_pool",
		PackedVector2Array([Vector2(140.0, 280.0), Vector2(420.0, 280.0)]),
		1.0,
		0.05
	))
	_expect(played, "Poison pool profile must replay through the same scene.")
	_expect(String(effect.call("get_element")) == "poison", "Poison pool must retain formal poison identity.")
	_expect(String(effect.call("get_topology")) == "toxic_puddle", "Poison must form puddles, not flame recolors.")
	_expect_runtime_atlas(effect, "poison_pool")
	await create_timer(0.2).timeout
	_expect(not bool(effect.call("is_active")), "Ground trail must finish after its configured residue lifetime.")
	effect.queue_free()
	await process_frame

	var capture_path := OS.get_environment("ELEMENTAL_GROUND_TRAIL_CAPTURE_PATH")
	if not capture_path.is_empty():
		await _capture_profiles(packed, capture_path)
	_finish()


func _expect_runtime_atlas(effect: Node, profile_id: String) -> void:
	var segment_owner := effect.get_node("SegmentOwner")
	for child_variant in segment_owner.get_children():
		var segment := child_variant as Node2D
		for slot_name in SLOT_NAMES:
			var slot := segment.get_node_or_null(NodePath(String(slot_name))) as Node2D
			_expect(
				slot != null,
				"Every ground segment needs the %s slot." % slot_name
			)
			if slot == null:
				continue
			var sprite := slot.get_node_or_null("Sprite") as Sprite2D
			_expect(sprite != null, "The %s slot needs one atlas sprite." % slot_name)
			if sprite == null:
				continue
			var atlas_texture := sprite.texture as AtlasTexture
			_expect(
				atlas_texture != null,
				"The %s slot must use AtlasTexture, not recolored geometry." % slot_name
			)
			if atlas_texture == null:
				continue
			var region_name := String(slot_name).to_lower()
			_expect(
				atlas_texture.region == EXPECTED_ATLAS_REGIONS[region_name],
				"The %s slot must use its authored atlas quadrant." % slot_name
			)
			_expect(
				atlas_texture.atlas.resource_path == String(EXPECTED_ATLASES[profile_id]),
				"The %s slot must use the selected %s atlas." % [slot_name, profile_id]
			)


func _capture_profiles(packed: PackedScene, capture_path: String) -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("#111519")
	background.size = Vector2(root.size)
	background.z_index = -100
	root.add_child(background)
	var floor := ColorRect.new()
	floor.color = Color("#24272a")
	floor.position = Vector2(0.0, 150.0)
	floor.size = Vector2(1280.0, 570.0)
	floor.z_index = -90
	root.add_child(floor)
	for index in PROFILE_IDS.size():
		var candidate := packed.instantiate() as Node2D
		candidate.set("auto_free", false)
		root.add_child(candidate)
		var y := 215.0 + float(index) * 185.0
		candidate.call(
			"play_path",
			PROFILE_IDS[index],
			PackedVector2Array([
				Vector2(120.0, y),
				Vector2(440.0, y - 18.0),
				Vector2(760.0, y + 12.0),
				Vector2(1110.0, y - 6.0),
			]),
			1.35,
			2.0
		)
		candidate.call("debug_set_progress", 0.42)
		candidate.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(
		root.get_texture().get_image().save_png(capture_path) == OK,
		"Ground trail contact sheet must save to %s." % capture_path
	)


func _finish() -> void:
	if _failures == 0:
		print("PASS: elemental ground trails use distinct modular path profiles")
	quit(1 if _failures > 0 else 0)


func _rect_from_array(values: Array) -> Rect2:
	if values.size() != 4:
		return Rect2()
	return Rect2(
		float(values[0]),
		float(values[1]),
		float(values[2]),
		float(values[3])
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
