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
	var codex_entries: Array[Dictionary] = [
		{
			"id": "ember_bolt", "name": "Ember Bolt", "category": "attacks",
			"kind_label": "BASIC ATTACK",
			"description": "Deal 16 damage and apply burn.",
			"effect_summary": "16 damage, 2 burn damage, 260 attack range",
			"trigger_summary": "Fires automatically toward enemies in front of the player.",
			"preview_kind": "basic_attack", "elements": [],
			"icon_path": "res://assets/ui/autumn/cards/generated/ember_bolt.png",
		},
		{
			"id": "flame_imbue", "name": "Flame Imbue", "category": "infusions",
			"kind_label": "FLAME ATTACK INFUSION",
			"description": "Wrap every weapon strike in fire and inflict Burn.",
			"effect_summary": "+4 attack damage, 3 burn damage",
			"trigger_summary": "Wraps your attacks for 2.5 seconds.",
			"preview_kind": "attack_aura", "elements": ["flame"], "intensity": 3,
			"icon_path": "res://assets/ui/autumn/cards/generated/flame_imbue.png",
		},
		{
			"id": "echo_volley", "name": "Echo Volley", "category": "infusions",
			"kind_label": "目前配置 · 攻擊附魔",
			"description": "以 360° 環形發射 8 枚投射物。",
			"effect_summary": "劍氣波 +7、散射角度 360 度",
			"trigger_summary": "打出後使攻擊獲得 1.5 秒附魔。",
			"preview_kind": "attack_aura", "elements": [], "level": 3,
			"direction_count": 8, "spread_degrees": 360.0, "stack_count": 7,
			"icon_path": "res://assets/ui/autumn/cards/generated/echo_volley.png",
		},
		{
			"id": "storm_charge", "name": "風暴充能", "category": "infusions",
			"kind_label": "雷霆攻擊灌注", "description": "將雷流聚回身體與武器。",
			"effect_summary": "附加雷電傷害與短暫暈眩",
			"trigger_summary": "施放時原地完成充能，後續攻擊帶電。",
			"preview_kind": "storm_charge", "element": "lightning", "level": 3,
			"icon_path": "res://assets/ui/autumn/cards/generated/storm_charge.png",
		},
		{
			"id": "frost_bind", "name": "Glacial Dominion", "category": "skills",
			"preview_kind": "ice_ultimate",
		},
		{
			"id": "inferno_cremation", "name": "Inferno Cremation",
			"category": "finishers", "kind_label": "COMBO FINISHER",
			"description": "Compress three flame invocations into one execution.",
			"effect_summary": "+44 attack damage, 2.00x effect size",
			"trigger_summary": "Formula: Flame Imbue > Flame Imbue > Flame Imbue",
			"preview_kind": "finisher", "elements": ["flame"], "intensity": 5,
			"named_vfx_id": "inferno_cremation",
			"attack_size_multiplier": 2.0, "stack_count": 3,
			"element": "fire", "level": 3, "combo_stack": 7,
			"evolution_layers": ["ember_core", "caldera_ring", "cremation_pillar"],
			"stack_milestones": [0, 3, 6, 9],
			"stack_traits": [
				"sealed_ember", "three_flame_satellites",
				"sixfold_magma_fissure", "ninefold_sunburst",
			],
		},
		{
			"id": "frozen_burial", "name": "Frozen Burial",
			"category": "finishers", "kind_label": "COMBO FINISHER",
			"description": "Raise and seal one continuous ice coffin around the target.",
			"effect_summary": "Grounded ice construction and vertical fracture",
			"trigger_summary": "Formula: Frost > Frost > Frost",
			"preview_kind": "finisher", "elements": ["ice"], "intensity": 5,
			"named_vfx_id": "frozen_burial",
			"element": "ice", "level": 3, "combo_stack": 7,
		},
	]
	var finisher_ids := PackedStringArray(["inferno_cremation", "frozen_burial"])
	var catalog: RefCounted = (load("res://scripts/systems/named_skill_vfx_catalog.gd") as Script).new()
	_expect(bool(catalog.call("load_catalog")), "Codex fit test requires the production named VFX catalog.")
	for profile_variant in catalog.call("get_all_profiles") as Array:
		var profile := profile_variant as Dictionary
		if String(profile.get("kind", "")) != "finisher":
			continue
		var profile_id := String(profile.get("id", ""))
		if finisher_ids.has(profile_id):
			continue
		finisher_ids.append(profile_id)
		codex_entries.append({
			"id": profile_id,
			"name": String(profile.get("display_name", profile_id)),
			"category": "finishers",
			"kind_label": "COMBO FINISHER",
			"description": String(profile.get("semantic_object", profile_id)),
			"effect_summary": "Production live named VFX",
			"trigger_summary": "Fit-contract coverage",
			"preview_kind": "finisher",
			"named_vfx_id": profile_id,
			"element": String(profile.get("element", "normal")),
			"level": 3,
			"combo_stack": 7,
		})
	ui.call("set_codex_entries", codex_entries)
	ui.call("set_mode", &"codex")
	ui.call("open")
	var selected_entry_id := (
		_capture_entry_id
		if (
			not _capture_entry_id.is_empty()
			and (not _capture_dir.is_empty() or viewport_size == _capture_size)
		)
		else "ember_bolt"
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
		preview.size.y >= 316.0,
		"Discovery live VFX frame must reserve enough height to read a complete move at %s."
			% viewport_size
	)
	var effect_origin_offset := (
		preview.call("get_effect_origin_offset_from_preview_center") as Vector2
	)
	var effect_travel_offset := preview.call("get_effect_travel_offset") as Vector2
	if selected_entry_id == "ember_bolt":
		_expect(
			effect_origin_offset.is_equal_approx(Vector2(34.0, 7.0)),
			"Basic Attack VFX origin must remain beside the preview character at %s; got %s."
				% [viewport_size, effect_origin_offset]
		)
		_expect(
			effect_travel_offset.x > 0.0 and absf(effect_travel_offset.y) <= 0.01,
			"Basic Attack VFX must travel horizontally to the character's right at %s; got %s."
				% [viewport_size, effect_travel_offset]
		)
	elif selected_entry_id == "echo_volley":
		_expect(
			int(preview.call("get_sword_wave_count")) == 8,
			"Level-three Echo Volley must keep all eight production directions at %s."
				% viewport_size
		)
	elif selected_entry_id == "inferno_cremation" and _capture_view == &"live":
		_expect(
			preview.call("get_active_named_vfx_id") == "inferno_cremation",
			"Named Finisher preview must keep its exact identity at %s." % viewport_size
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
		if selected_entry_id == "storm_charge":
			preview.call("_spawn_effect")
			preview.set("_effect_preview_size", preview.size)
			var captured_effect_variant: Variant = preview.get("_effect")
			if is_instance_valid(captured_effect_variant):
				var captured_effect := captured_effect_variant as Node2D
				if captured_effect != null and captured_effect.has_method("debug_set_elapsed"):
					captured_effect.call("debug_set_elapsed", _capture_delay)
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
				>= preview.size.y * 0.72,
			"Named Finisher preview must fill enough of the display frame to remain readable at %s: %s."
				% [viewport_size, named_entry_id]
		)
		_expect(
			not bool(preview.call("character_uses_attack_sheet")),
			"Named Finisher preview must not obscure its authored move with the old white attack crescent at %s: %s."
				% [viewport_size, named_entry_id]
		)
		if named_mode == "directional_forward":
			_expect(
				named_position.x < preview.size.x * 0.5,
				"Directional Finisher preview must start left of center to reserve its forward travel at %s: %s."
					% [viewport_size, named_entry_id]
			)
		else:
			_expect(
				is_equal_approx(named_position.x, preview.size.x * 0.5),
				"Player-centered Finisher preview must stay centered at %s: %s."
					% [viewport_size, named_entry_id]
			)
	ui.call("select_codex_entry", "storm_charge")
	await process_frame
	await process_frame
	_expect(
		bool(preview.call("is_dedicated_storm_charge_active")),
		"Storm Charge Codex preview must instantiate its dedicated stationary VFX at %s."
			% viewport_size
	)
	_expect(
		is_equal_approx(
			(preview.call("get_effect_local_position") as Vector2).y,
			float(preview.call("get_preview_floor_y"))
		),
		"Storm Charge Codex preview must stay attached to the preview ground at %s."
			% viewport_size
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
