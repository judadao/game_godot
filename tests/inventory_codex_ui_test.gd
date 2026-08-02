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
	ui.call("set_items", [
		{"id": "wood", "name": "Autumn Wood", "category": "materials", "quantity": 12},
		{"id": "sword", "name": "Iron Sword", "category": "gear", "quantity": 1},
	])
	ui.call("set_equipment_entries", [
		{"slot": "weapon", "id": "iron_sword", "name": "鐵劍", "level": 2, "stats": "攻擊 +4"},
	])
	ui.call("set_codex_entries", [
		{"id": "ember_bolt", "name": "Ember Bolt", "category": "attacks", "preview_kind": "basic_attack"},
		{"id": "flame_imbue", "name": "Flame Imbue", "category": "infusions", "preview_kind": "attack_aura", "elements": ["flame"]},
		{"id": "frost_bind", "name": "Glacial Dominion", "category": "skills", "preview_kind": "ice_ultimate", "radius": 460},
		{"id": "guard", "name": "Iron Will", "category": "skills", "preview_kind": "technique", "visual_family": "defense"},
		{"id": "healing_light", "name": "Healing Light", "category": "skills", "preview_kind": "technique", "visual_family": "healing"},
		{
			"id": "inferno_cremation", "name": "Inferno Cremation",
			"category": "finishers", "preview_kind": "finisher",
			"named_vfx_id": "inferno_cremation", "elements": ["fire"],
			"level": 3, "combo_stack": 7,
			"element": "fire",
			"evolution_layers": ["ember_core", "caldera_ring", "cremation_pillar"],
			"stack_milestones": [0, 3, 6, 9],
			"stack_traits": [
				"sealed_ember", "three_flame_satellites",
				"sixfold_magma_fissure", "ninefold_sunburst",
			],
		},
	])
	ui.call("set_mode", &"codex")
	ui.call("open")
	await process_frame
	await process_frame
	ui.call("select_codex_entry", "flame_imbue")
	await process_frame
	_expect(ui.call("get_mode") == &"codex", "Codex mode must be selectable.")
	_expect(ui.call("get_visible_codex_count") == 6, "Codex must list every projected attack, skill, infusion, and finisher.")
	_expect(ui.call("get_selected_codex_id") == "flame_imbue", "Codex selection must drive the preview.")
	var preview := ui.get_node("Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Preview")
	_expect(preview.call("get_preview_kind") == "attack_aura", "Attack infusion must use the aura preview.")
	_expect(preview.call("get_effect_node_count") == 1, "Preview must own exactly one active reusable effect.")
	_expect(
		not bool(preview.call("is_effect_top_level")),
		"Codex preview combat effects must stay clipped inside the preview panel."
	)
	ui.call("select_codex_entry", "ember_bolt")
	_expect(preview.call("get_preview_kind") == "basic_attack", "Basic attacks must use the directional strike preview.")
	_expect(
		float(preview.call("get_sword_wave_speed_multiplier")) >= 1.0,
		"Codex Basic Attack previews must retain the slash-shockwave speed."
	)
	_expect(
		(preview.call("get_effect_origin_offset_from_preview_center") as Vector2).is_equal_approx(
			Vector2(34.0, 7.0)
		),
		"Codex sword waves must launch beside the character in preview-local coordinates at every viewport stretch."
	)
	_expect(
		not bool(preview.call("is_effect_top_level")),
		"Basic Attack preview must not escape the codex panel as a top-level world effect."
	)
	ui.call("select_codex_entry", "guard")
	_expect(preview.call("get_preview_kind") == "technique", "Defense and support skills must use the reusable technique preview.")
	ui.call("select_codex_entry", "inferno_cremation")
	_expect(preview.call("get_preview_kind") == "finisher", "Finishers must use the amplified sword-wave preview.")
	_expect(
		preview.call("get_active_named_vfx_id") == "inferno_cremation",
		"Finisher previews must preserve the exact named VFX identity."
	)
	_expect(
		int(preview.call("get_active_effect_evolution_level")) == 3
			and int(preview.call("get_active_effect_buff_stacks")) == 7,
		"Codex named VFX previews must preserve entry evolution level and persistent buff stacks."
	)
	_expect(
		ui.has_method("set_codex_view_mode")
			and ui.has_method("get_codex_view_mode")
			and ui.has_method("get_active_concept_region"),
		"Discovery Codex must expose live-VFX and concept-art view modes."
	)
	if ui.has_method("set_codex_view_mode"):
		ui.call("set_codex_view_mode", &"concept")
		await process_frame
		var concept := ui.get_node_or_null(
			"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/ConceptView"
		) as TextureRect
		_expect(
			ui.call("get_codex_view_mode") == &"concept"
				and concept != null
				and concept.visible
				and not preview.visible
				and (ui.call("get_active_concept_region") as Rect2).has_area(),
			"Concept mode must replace the live preview with the selected skill's cropped concept art."
		)
	var meta := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Meta"
	) as Label
	var growth := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Growth"
	) as Label
	var effect_label := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Effect"
	) as Label
	var notes_label := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Trigger"
	) as Label
	_expect(
		meta != null
			and meta.text.contains("屬性  火")
			and meta.text.contains("等級 3/3")
			and meta.text.contains("增益 ×7")
			and not meta.text.contains("ELEMENT")
			and not meta.text.contains("BUFF"),
		"Codex details must show the element, evolution level, and Buff stacks in Traditional Chinese."
	)
	_expect(
		growth != null
			and growth.text.contains("進化")
			and growth.text.contains("Cremation Pillar")
			and growth.text.contains("下一層")
			and growth.text.contains("×9")
			and growth.text.contains("Ninefold Sunburst")
			and not growth.text.contains("EVOLUTION")
			and not growth.text.contains("NEXT STACK"),
		"Codex details must show the active evolution structure and next stack milestone with Chinese labels."
	)
	_expect(
		effect_label != null
			and effect_label.text.begins_with("效果\n")
			and notes_label != null
			and notes_label.text.begins_with("說明\n"),
		"Codex explanation headings must use Traditional Chinese."
	)
	var weapon_name := ui.get_node(
		"Center/MainPanel/Margin/Layout/Pages/StatusPage/Equipment/Weapon/Row/Text/Name"
	) as Label
	var armor_name := ui.get_node(
		"Center/MainPanel/Margin/Layout/Pages/StatusPage/Equipment/Armor/Row/Text/Name"
	) as Label
	var armor_stats := ui.get_node(
		"Center/MainPanel/Margin/Layout/Pages/StatusPage/Equipment/Armor/Row/Text/Stats"
	) as Label
	_expect(
		weapon_name.text == "武器  ·  鐵劍  ·  等級 2"
			and armor_name.text == "防具  ·  未裝備"
			and armor_stats.text == "此欄位目前沒有裝備。",
		"Status equipment slots must use natural Traditional Chinese labels."
	)
	ui.call("select_codex_entry", "flame_imbue")
	_expect(
		growth.text.contains("進化  基礎招式"),
		"Codex entries without authored evolution layers must show the Chinese base-technique label."
	)
	ui.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Inventory and discovery codex behavior")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
