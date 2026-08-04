extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var ui := (load("res://scenes/ui/inventory/InventoryUI.tscn") as PackedScene).instantiate()
	viewport.add_child(ui)
	await process_frame

	var skill_catalog := (load("res://scripts/systems/skill_recipe_manager.gd") as Script).new() as RefCounted
	_expect(bool(skill_catalog.call("load_catalog", "res://data/skills.json")), "Codex UI test requires the production skill catalog.")
	var codex_entries := _make_codex_entries(skill_catalog)
	codex_entries.reverse()
	ui.call("set_codex_entries", codex_entries)
	ui.call("set_mode", &"codex")
	ui.call("open")
	await process_frame
	await process_frame

	ui.call("select_codex_entry", "flowing_fire_night")
	await process_frame
	var preview := ui.get_node("Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Preview")
	var codex_rows := ui.get_node(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Entries"
	) as ItemList
	_expect(ui.call("get_mode") == &"codex", "Codex mode must be selectable.")
	_expect(ui.call("get_visible_codex_count") == 39, "Codex must list all 39 current skills.")
	_expect(codex_rows.item_count == 52, "Codex must group 39 skills under 13 visible series headers.")
	var expected_opening_rows := [
		"◆  劍雨系列", "基礎 · 戰律希聲", "進階 · 萬劍垂天", "大師 · 驟雨繁音",
		"◆  月輪系列", "基礎 · 月輪垂光", "進階 · 扶搖月輪", "大師 · 月蝕重輪",
	]
	for row_index in expected_opening_rows.size():
		_expect(
			codex_rows.get_item_text(row_index) == expected_opening_rows[row_index],
			"Codex row %d must follow catalog series/tier order; got: %s"
				% [row_index, codex_rows.get_item_text(row_index)]
		)
	_expect(
		not codex_rows.is_item_selectable(0)
			and not codex_rows.is_item_selectable(4)
			and not codex_rows.is_item_disabled(0)
			and codex_rows.is_item_selectable(1),
		"Series headers must remain bright and non-selectable while skill rows remain selectable."
	)
	var header_foreground := codex_rows.get_item_custom_fg_color(0)
	var header_background := codex_rows.get_item_custom_bg_color(0)
	_expect(
		header_background.a >= 0.9
			and header_foreground.get_luminance() - header_background.get_luminance() >= 0.55,
		"Series headers need an opaque dark strip and high-luminance text; got foreground=%s background=%s."
			% [header_foreground, header_background]
	)
	_expect(ui.call("get_selected_codex_id") == "flowing_fire_night", "Codex selection must use the new stable skill ID.")
	_expect(preview.call("get_preview_kind") == "finisher", "New skills must use the temporary named-animation preview path.")
	_expect(preview.call("get_active_named_vfx_id") == "inferno_cremation", "流火照夜 must temporarily reuse its mapped existing animation.")
	_expect(not bool(preview.call("is_effect_top_level")), "Codex preview effects must stay clipped inside the preview panel.")

	var meta := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Meta"
	) as Label
	var growth := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Growth"
	) as Label
	var effect_label := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Effect"
	) as Label
	var description_label := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Description"
	) as Label
	var notes_label := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Trigger"
	) as Label
	_expect(
		meta != null
			and meta.text.contains("系列  火焰")
			and meta.text.contains("階級 基礎")
			and meta.text.contains("元素 火"),
		"Codex details must show the new series, tier, and combat element; got: %s" % (meta.text if meta != null else "<missing>")
	)
	_expect(
		growth != null
			and growth.text.contains("系列語彙")
			and growth.text.contains("特效狀態  暫用既有動畫"),
		"Codex details must distinguish skill identity from its temporary VFX mapping; got: %s" % (growth.text if growth != null else "<missing>")
	)
	_expect(
		effect_label != null
			and effect_label.text.begins_with("效果\n")
			and effect_label.text.contains("基礎火焰攻擊")
			and description_label != null
			and description_label.text.contains("流火先環繞角色")
			and description_label.text.contains("持續燃燒區域")
			and notes_label != null
			and notes_label.text.begins_with("說明\n")
			and notes_label.text.contains("流火在角色周圍")
			and notes_label.text.contains("貼地燃燒區"),
		"Codex must project the new skill role and description without stale card text; got effect=%s notes=%s" % [effect_label.text if effect_label != null else "<missing>", notes_label.text if notes_label != null else "<missing>"]
	)

	ui.call("select_codex_entry", "celestial_feather_myriad")
	await process_frame
	_expect(ui.call("get_selected_codex_id") == "celestial_feather_myriad", "The Master feather skill must be selectable.")
	_expect(meta.text.contains("系列  羽毛") and meta.text.contains("階級 大師"), "天羽萬象 must be classified as the Feather Master skill; got: %s" % meta.text)
	_expect(notes_label.text.contains("細羽高速追擊") and notes_label.text.contains("巨型天羽垂直墜落"), "天羽萬象 must expose its new authored choreography description; got: %s" % notes_label.text)

	_expect(
		ui.has_method("set_codex_view_mode")
			and ui.has_method("get_codex_view_mode")
			and ui.has_method("get_active_concept_region"),
		"Discovery Codex must retain its live-preview compatibility diagnostics."
	)
	ui.call("set_codex_view_mode", &"concept")
	await process_frame
	var concept := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/ConceptView"
	) as TextureRect
	_expect(
		ui.call("get_codex_view_mode") == &"live"
			and concept != null
			and not concept.visible
			and preview.visible
			and not (ui.call("get_active_concept_region") as Rect2).has_area(),
		"Retired concept effects must not replace the current live animation preview."
	)

	ui.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: 39-skill series codex behavior")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _make_codex_entries(catalog: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var series_ranks: Dictionary = {}
	var ordered_series := catalog.call("get_all_series") as Array
	for series_index in ordered_series.size():
		series_ranks[String((ordered_series[series_index] as Dictionary).get("id", ""))] = series_index
	for skill_variant in catalog.call("get_all_skills") as Array:
		var skill := skill_variant as Dictionary
		var tier_id := String(skill.get("tier", "basic"))
		var series_id := String(skill.get("series_id", ""))
		result.append({
			"id": String(skill.get("id", "")),
			"name": String(skill.get("name", "")),
			"catalog_kind": "skill_series",
			"category": "skills",
			"skill_series_id": series_id,
			"skill_series_name": String(skill.get("series_name", "")),
			"skill_series_rank": int(series_ranks.get(series_id, 999)),
			"tier": tier_id,
			"tier_label": String(catalog.call("get_tier_label", tier_id)),
			"tier_rank": int(skill.get("tier_rank", 1)),
			"description": String(skill.get("description", "")),
			"effect_summary": String(skill.get("positioning", "")),
			"trigger_summary": "動畫：%s" % " → ".join(skill.get("animation_beats", []) as Array),
			"identity_elements": (skill.get("series_identity_elements", []) as Array).duplicate(),
			"elements": (skill.get("combat_elements", []) as Array).duplicate(),
			"element": String((skill.get("combat_elements", ["normal"]) as Array)[0]),
			"preview_kind": "finisher",
			"named_vfx_id": String(skill.get("legacy_vfx_id", "")),
			"legacy_vfx": true,
		})
	return result
