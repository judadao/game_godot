extends SceneTree

const EXPECTED_FINISHERS := [
	"thousand_blade_kill",
	"inferno_cremation",
	"thunder_prison_pierce",
	"heavenly_wheel_sever",
	"frozen_burial",
]
const EXPECTED_TRIGGERS := [
	"iron_momentum",
	"ember_reprise",
	"battle_tempo",
	"grand_strategy",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_script := load("res://scripts/systems/named_skill_vfx_catalog.gd")
	var vfx_scene := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	_expect(catalog_script != null, "Named skill VFX needs one data-driven catalog authority.")
	_expect(vfx_scene != null, "Named skill VFX needs one reusable modular scene.")
	if catalog_script == null or vfx_scene == null:
		_finish()
		return

	var catalog: RefCounted = catalog_script.new()
	_expect(bool(catalog.call("load_catalog")), "Named skill VFX profile data must load.")
	var profiles := catalog.call("get_all_profiles") as Array
	_expect(profiles.size() == 9, "All five finishers and four named triggers need profiles.")

	var atlas_rows: Dictionary = {}
	for profile_id in EXPECTED_FINISHERS + EXPECTED_TRIGGERS:
		_expect(bool(catalog.call("has_profile", profile_id)), "Missing named VFX profile: %s." % profile_id)
		var profile := catalog.call("get_profile", profile_id) as Dictionary
		var atlas_path := String(profile.get("atlas_path", ""))
		var row_key := "%s:%d" % [atlas_path, int(profile.get("row", -1))]
		_expect(not atlas_rows.has(row_key), "Named VFX profiles must not share an identity row: %s." % row_key)
		atlas_rows[row_key] = profile_id
		_expect(FileAccess.file_exists(atlas_path), "Named VFX atlas must exist: %s." % atlas_path)
		_expect(int(profile.get("columns", 0)) == 5, "Every named VFX must expose five composable parts.")
		var region_y := profile.get("region_y", []) as Array
		_expect(
			region_y.size() == 2 and int(region_y[1]) > int(region_y[0]),
			"Every generated atlas row needs an authored safe crop: %s." % profile_id
		)
		_expect(
			float(profile.get("impact_time", 0.0)) > float(profile.get("anticipation_time", 0.0)),
			"Impact must follow readable anticipation for %s." % profile_id
		)
		_expect(
			float(profile.get("duration", 0.0)) > float(profile.get("impact_time", 0.0)),
			"Named VFX must retain a post-impact decay for %s." % profile_id
		)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	root.add_child(viewport)
	var effect := vfx_scene.instantiate()
	viewport.add_child(effect)
	await process_frame
	effect.call("play", "thunder_prison_pierce", 1, 1.0, true)
	_expect(String(effect.call("get_profile_id")) == "thunder_prison_pierce", "Scene must retain exact skill identity.")
	_expect(int(effect.call("get_part_count")) == 5, "Runtime scene must assemble five authored sprite parts.")
	effect.call("debug_set_progress", 0.08)
	_expect(effect.call("get_stage_name") == &"anticipation", "Named VFX must begin with anticipation.")
	effect.call("debug_set_progress", 0.72)
	_expect(effect.call("get_stage_name") in [&"impact", &"decay"], "Named VFX must expose a decisive impact stage.")
	viewport.queue_free()
	await process_frame

	var capture_path := OS.get_environment("NAMED_SKILL_VFX_CAPTURE_PATH")
	if not capture_path.is_empty():
		await _capture_contact_sheet(vfx_scene, catalog, capture_path)

	var game_script := load("res://scripts/managers/game.gd")
	var game: Node = game_script.new()
	var finisher := {
		"id": "thousand_blade_kill",
		"name": "千刃殺",
		"type": "attack",
		"effect": {"kind": "damage"},
		"combo_visual_profile": {"finisher": true},
	}
	var resolved := game.call("_resolve_combat_vfx_profile", finisher) as Dictionary
	_expect(
		String(resolved.get("named_vfx_id", "")) == "thousand_blade_kill",
		"Combat mapping must preserve the exact Finisher identity."
	)
	game.free()
	_finish()


func _capture_contact_sheet(
	vfx_scene: PackedScene,
	catalog: RefCounted,
	capture_path: String
) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 840)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#0b1014")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var profile_ids := EXPECTED_FINISHERS + EXPECTED_TRIGGERS
	for index in profile_ids.size():
		var profile_id: String = profile_ids[index]
		var profile := catalog.call("get_profile", profile_id) as Dictionary
		var column := index % 3
		var row := index / 3
		var cell_origin := Vector2(float(column) * 480.0, float(row) * 280.0)
		var label := Label.new()
		label.text = String(profile.get("display_name", profile_id))
		label.position = cell_origin + Vector2(18.0, 12.0)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.68))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		viewport.add_child(label)
		var separator := Line2D.new()
		separator.points = PackedVector2Array([
			cell_origin + Vector2(8.0, 274.0),
			cell_origin + Vector2(472.0, 274.0),
		])
		separator.default_color = Color(0.28, 0.34, 0.38, 0.7)
		separator.width = 1.0
		viewport.add_child(separator)
		var effect := vfx_scene.instantiate()
		effect.set("auto_free", false)
		viewport.add_child(effect)
		effect.position = (
			cell_origin + Vector2(70.0, 172.0)
			if String(profile.get("kind", "")) == "finisher"
			else cell_origin + Vector2(232.0, 178.0)
		)
		effect.call("play", profile_id, 1, 1.0, true)
		var action_progress := clampf(
			float(profile.get("impact_time", 0.5))
				/ maxf(0.1, float(profile.get("duration", 1.0)))
				- 0.055,
			0.2,
			0.82
		)
		effect.call("debug_set_progress", action_progress)
		effect.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(
		viewport.get_texture().get_image().save_png(capture_path) == OK,
		"Named skill VFX contact-sheet capture must save."
	)
	viewport.queue_free()
	await process_frame


func _finish() -> void:
	if _failures == 0:
		print("PASS: nine named skills use unique modular VFX profiles")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
