extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1152, 720), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(2560, 1440),
]

var _failures := 0
var _capture_path := ""
var _capture_dir := ""
var _capture_size := Vector2i.ZERO
var _capture_entry_id := ""
var _capture_view := &"live"
var _capture_delay := 0.12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_path = OS.get_environment("INVENTORY_CODEX_CAPTURE_PATH")
	_capture_dir = OS.get_environment("INVENTORY_CODEX_CAPTURE_DIR")
	_capture_size = _parse_size(OS.get_environment("INVENTORY_CODEX_CAPTURE_SIZE"))
	_capture_entry_id = OS.get_environment("INVENTORY_CODEX_CAPTURE_ENTRY")
	_capture_view = StringName(OS.get_environment("INVENTORY_CODEX_CAPTURE_VIEW"))
	if _capture_view != &"concept":
		_capture_view = &"live"
	_capture_delay = maxf(
		0.0,
		float(OS.get_environment("INVENTORY_CODEX_CAPTURE_DELAY"))
		if not OS.get_environment("INVENTORY_CODEX_CAPTURE_DELAY").is_empty()
		else 0.12
	)
	for viewport_size in VIEWPORT_SIZES:
		await _check_size(viewport_size)
	if _failures == 0:
		print("PASS: Inventory codex layout at six viewport sizes")
	quit(1 if _failures > 0 else 0)


func _check_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	root.add_child(viewport)
	var ui := (load("res://scenes/ui/inventory/InventoryUI.tscn") as PackedScene).instantiate()
	viewport.add_child(ui)
	await process_frame
	var skill_catalog := (load("res://scripts/systems/skill_recipe_manager.gd") as Script).new() as RefCounted
	_expect(bool(skill_catalog.call("load_catalog", "res://data/skills.json")), "Codex layout requires the production skill-series catalog.")
	var codex_entries := _make_codex_entries(skill_catalog)
	_expect(codex_entries.size() == 39, "Codex layout must exercise all 39 current skills.")
	var finisher_ids := PackedStringArray()
	var catalog: RefCounted = (load("res://scripts/systems/named_skill_vfx_catalog.gd") as Script).new()
	_expect(bool(catalog.call("load_catalog")), "Codex fit test requires the production named VFX catalog.")
	for entry in codex_entries:
		var profile_id := String(entry.get("named_vfx_id", ""))
		if not profile_id.is_empty() and not finisher_ids.has(profile_id):
			finisher_ids.append(profile_id)
	ui.call("set_codex_entries", codex_entries)
	ui.call("set_mode", &"codex")
	ui.call("open")
	var selected_entry_id := (
		_capture_entry_id
		if (
			not _capture_entry_id.is_empty()
			and (not _capture_dir.is_empty() or viewport_size == _capture_size)
		)
		else "flowing_fire_night"
	)
	ui.call("select_codex_entry", selected_entry_id)
	ui.call("set_codex_view_mode", _capture_view)
	await process_frame
	await process_frame
	var panel := ui.get_node("Center/MainPanel") as Control
	var browser := panel.get_node("Margin/Layout/Pages/CodexPage/Browser") as Control
	var view_tabs := panel.get_node("Margin/Layout/Pages/CodexPage/Details/ViewTabs") as Control
	var preview := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Preview") as Control
	var concept := panel.get_node("Margin/Layout/Pages/CodexPage/Details/ConceptView") as Control
	var info := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Info") as Control
	var active_view := preview
	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	_expect(screen.encloses(_rect(panel)), "Panel must remain on-screen at %s." % viewport_size)
	_expect(
		not _rect(browser).intersects(_rect(active_view)),
		"Discovery list must not overlap the active visual at %s." % viewport_size
	)
	_expect(not view_tabs.visible and not concept.visible, "Retired concept-effect controls must stay hidden at %s." % viewport_size)
	_expect(
		_rect(active_view).end.y <= _rect(info).position.y,
		"Active visual must remain above explanation at %s." % viewport_size
	)
	_expect(
		preview.size.y >= 186.0 and preview.size.y <= 194.0,
		"Discovery live VFX frame must be a compact horizontal casting stage at %s."
			% viewport_size
	)
	_expect(
		preview.size.x / preview.size.y >= 2.0 and info.size.y >= preview.size.y,
		"The casting stage must stay landscape while the description receives at least equal height at %s."
			% viewport_size
	)
	if selected_entry_id == "flowing_fire_night" and _capture_view == &"live":
		_expect(
			preview.call("get_active_named_vfx_id") == "inferno_cremation",
			"流火照夜 must keep its temporary production animation at %s." % viewport_size
		)
		_expect(
			int(preview.call("get_effect_node_count")) == 1
				and not bool(preview.call("is_effect_top_level")),
			"Named Finisher preview must stay singly owned and clipped at %s." % viewport_size
		)
	var capture_path := _capture_path
	if not _capture_dir.is_empty():
		capture_path = _capture_dir.path_join(
			"%s_%s_%dx%d.png" % [
				selected_entry_id,
				String(_capture_view),
				viewport_size.x,
				viewport_size.y,
			]
		)
	if (
		not capture_path.is_empty()
		and (not _capture_dir.is_empty() or viewport_size == _capture_size)
	):
		await create_timer(_capture_delay).timeout
		# Container relayout can restart a resize-sensitive preview at a slightly
		# different frame on each viewport size.  Seek dedicated deterministic
		# effects back to the requested evidence time so multi-resolution captures
		# compare the same choreography beat instead of six unrelated replay frames.
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(viewport.get_texture().get_image().save_png(capture_path) == OK, "Visual capture must save.")
	for named_entry_id in finisher_ids:
		ui.call("select_codex_entry", named_entry_id)
		await process_frame
		await process_frame
		var named_mode := String(preview.call("get_named_effect_spatial_mode"))
		var named_position := preview.call("get_effect_local_position") as Vector2
		_expect(
			is_equal_approx(named_position.y, float(preview.call("get_preview_floor_y"))),
			"Named Finisher preview must anchor its authored ground contact to the preview floor at %s: %s."
				% [viewport_size, named_entry_id]
		)
		_expect(
			float(preview.call("get_named_effect_estimated_horizontal_span"))
				<= preview.size.x - 16.0,
			"Named Finisher preview must fit its object and full travel path inside the display frame at %s: %s."
				% [viewport_size, named_entry_id]
		)
		_expect(
			float(preview.call("get_named_effect_estimated_vertical_span"))
				<= preview.size.y - 16.0,
			"Named Finisher preview must fit the complete authored object vertically at %s: %s."
				% [viewport_size, named_entry_id]
		)
		_expect(
			float(preview.call("get_named_effect_estimated_vertical_span"))
				>= preview.size.y * (0.45 if named_mode == "directional_forward" else 0.65),
			"Named Finisher preview must remain readable while sharing the stage with its caster at %s: %s."
				% [viewport_size, named_entry_id]
		)
		_expect(
			bool(preview.call("character_uses_attack_sheet")),
			"Named Finisher preview must show the player actively casting the move at %s: %s."
				% [viewport_size, named_entry_id]
		)
		_expect(
			preview.has_method("get_preview_caster_ground_position")
				and preview.has_method("get_named_effect_estimated_rect"),
			"Codex preview must expose its caster and ground-effect stage geometry."
		)
		if (
			preview.has_method("get_preview_caster_ground_position")
			and preview.has_method("get_named_effect_estimated_rect")
		):
			var caster_position := preview.call("get_preview_caster_ground_position") as Vector2
			var effect_rect := preview.call("get_named_effect_estimated_rect") as Rect2
			_expect(
				is_equal_approx(caster_position.y, float(preview.call("get_preview_floor_y"))),
				"The player must stand on the same flat ground used by the move at %s: %s."
					% [viewport_size, named_entry_id]
			)
			_expect(
				effect_rect.position.x >= caster_position.x + 36.0,
				"The move must be cast into the ground ahead instead of being layered over the player at %s: %s."
					% [viewport_size, named_entry_id]
			)
	ui.queue_free()
	viewport.queue_free()
	await process_frame


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _parse_size(raw_size: String) -> Vector2i:
	var parts := raw_size.to_lower().split("x")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _make_codex_entries(catalog: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_variant in catalog.call("get_all_skills") as Array:
		var skill := skill_variant as Dictionary
		var elements := (skill.get("combat_elements", []) as Array).duplicate()
		result.append({
			"id": String(skill.get("id", "")),
			"name": String(skill.get("name", "")),
			"catalog_kind": "skill_series",
			"category": "skills",
			"skill_series_name": String(skill.get("series_name", "")),
			"tier": String(skill.get("tier", "basic")),
			"tier_label": String(catalog.call("get_tier_label", String(skill.get("tier", "basic")))),
			"tier_rank": int(skill.get("tier_rank", 1)),
			"description": String(skill.get("description", "")),
			"effect_summary": String(skill.get("positioning", "")),
			"elements": elements,
			"element": String(elements[0]) if not elements.is_empty() else "normal",
			"preview_kind": "finisher",
			"named_vfx_id": String(skill.get("legacy_vfx_id", "")),
			"legacy_vfx": true,
			"level": int(skill.get("tier_rank", 1)),
		})
	return result
