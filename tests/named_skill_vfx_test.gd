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
const VALID_ELEMENTS := [
	"water",
	"fire",
	"wind",
	"lightning",
	"ice",
	"poison",
	"light",
	"dark",
	"normal",
]
const EXPECTED_ARCHETYPES := {
	"thousand_blade_kill": "blade_storm_lane",
	"inferno_cremation": "compression_detonation",
	"thunder_prison_pierce": "rail_prison",
	"heavenly_wheel_sever": "orbiting_wheel",
	"frozen_burial": "descending_tomb",
	"iron_momentum": "armor_lock",
	"ember_reprise": "returning_arc",
	"battle_tempo": "rhythm_pulse",
	"grand_strategy": "tactical_ward",
}

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
	var archetypes: Dictionary = {}
	var beat_patterns: Dictionary = {}
	var evolution_signatures: Dictionary = {}
	var stack_trait_signatures: Dictionary = {}
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
		var element := String(profile.get("element", ""))
		_expect(
			element in VALID_ELEMENTS,
			"Named VFX element must use the weapon/blessing taxonomy: %s." % profile_id
		)
		if profile_id == "thunder_prison_pierce":
			_expect(
				element == "lightning",
				"Thunder Prison must use the formal lightning element."
			)
		var archetype := String(profile.get("archetype", ""))
		_expect(not archetype.is_empty(), "Named VFX needs a visual archetype: %s." % profile_id)
		_expect(
			archetype == String(EXPECTED_ARCHETYPES.get(profile_id, "")),
			"Named VFX must use its supported identity archetype: %s." % profile_id
		)
		_expect(
			not archetypes.has(archetype),
			"Named VFX archetypes must be unique instead of template aliases: %s." % archetype
		)
		archetypes[archetype] = profile_id
		var beat_pattern := profile.get("beat_pattern", []) as Array
		var beat_signature := JSON.stringify(beat_pattern)
		_expect(
			beat_pattern.size() >= 3
				and beat_pattern.size() <= 5
				and _is_strictly_increasing_unit_sequence(beat_pattern),
			"Named VFX needs three to five authored, ordered beats: %s." % profile_id
		)
		_expect(
			not beat_patterns.has(beat_signature),
			"Named VFX beat patterns must differ by identity: %s." % profile_id
		)
		beat_patterns[beat_signature] = profile_id
		var evolution_layers := profile.get("evolution_layers", []) as Array
		var evolution_signature := JSON.stringify(evolution_layers)
		_expect(
			evolution_layers.size() == 3 and _all_non_empty_unique_strings(evolution_layers),
			"Named VFX must add a distinct structure at levels one, two, and three: %s." % profile_id
		)
		_expect(
			not evolution_signatures.has(evolution_signature),
			"Named VFX level evolution must not share one template: %s." % profile_id
		)
		evolution_signatures[evolution_signature] = profile_id
		var stack_milestones := profile.get("stack_milestones", []) as Array
		var stack_traits := profile.get("stack_traits", []) as Array
		var stack_trait_signature := JSON.stringify(stack_traits)
		_expect(
			stack_milestones.size() == stack_traits.size()
				and stack_milestones.size() >= 3
				and int(stack_milestones[0]) == 0
				and _is_strictly_increasing_integer_sequence(stack_milestones)
				and _all_non_empty_unique_strings(stack_traits),
			"Named VFX needs aligned stack milestones and escalating visual traits: %s." % profile_id
		)
		_expect(
			not stack_trait_signatures.has(stack_trait_signature),
			"Named VFX stack traits must communicate its own buff identity: %s." % profile_id
		)
		stack_trait_signatures[stack_trait_signature] = profile_id

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
	var capture_level := clampi(
		int(OS.get_environment("NAMED_SKILL_VFX_CAPTURE_LEVEL")),
		1,
		3
	)
	var capture_stacks := maxi(
		0,
		int(OS.get_environment("NAMED_SKILL_VFX_CAPTURE_STACKS"))
	)
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
		effect.call(
			"play",
			profile_id,
			1,
			1.0,
			true,
			capture_level,
			capture_stacks
		)
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


func _is_strictly_increasing_unit_sequence(values: Array) -> bool:
	var previous := -1.0
	for value in values:
		if not value is float and not value is int:
			return false
		var current := float(value)
		if current < 0.0 or current > 1.0 or current <= previous:
			return false
		previous = current
	return true


func _is_strictly_increasing_integer_sequence(values: Array) -> bool:
	var previous := -1
	for value in values:
		if not value is int and not (value is float and is_equal_approx(value, round(value))):
			return false
		var current := int(value)
		if current < 0 or current <= previous:
			return false
		previous = current
	return true


func _all_non_empty_unique_strings(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if not value is String:
			return false
		var text := String(value).strip_edges()
		if text.is_empty() or seen.has(text):
			return false
		seen[text] = true
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
