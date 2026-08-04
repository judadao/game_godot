extends SceneTree

const JOURNAL_SCENE := preload("res://scenes/ui/inventory/InventoryUI.tscn")
const REQUIRED_MODES: Array[StringName] = [
	&"bag",
	&"status",
	&"sword_souls",
	&"codex",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var ui := JOURNAL_SCENE.instantiate()
	viewport.add_child(ui)
	await process_frame

	_expect(ui.has_method("set_player_status"), "Journal must accept a read-only player status projection.")
	_expect(ui.has_method("set_equipment_entries"), "Journal must accept equipped-slot projections.")
	_expect(ui.has_method("set_sword_souls"), "Journal must accept owned Sword Soul projections.")
	_expect(ui.has_method("get_active_page_count"), "Journal must expose its active-page count for layout verification.")
	_expect(ui.has_signal("equip_requested"), "Journal equipment actions must emit intent instead of mutating inventory authority.")

	for mode in REQUIRED_MODES:
		ui.call("set_mode", mode)
		_expect(ui.call("get_mode") == mode, "Journal mode must be selectable: %s." % mode)
		if ui.has_method("get_active_page_count"):
			_expect(
				int(ui.call("get_active_page_count")) == 1,
				"Exactly one journal page must be visible in mode %s." % mode
			)

	var main_panel := ui.get_node_or_null("Center/MainPanel") as Control
	var background := ui.get_node_or_null("Center/MainPanel/BookBackground") as TextureRect
	var header_inset := ui.get_node_or_null("Center/MainPanel/Margin/Layout/Header/HeaderInset") as Control
	var journal_margin := ui.get_node_or_null("Center/MainPanel/Margin") as MarginContainer
	_expect(main_panel != null, "The journal must retain the authoritative MainPanel node.")
	_expect(background != null and background.texture != null, "The journal needs an integrated book background texture.")
	if background != null and background.texture != null:
		var texture_size := background.texture.get_size()
		_expect(texture_size.x > texture_size.y, "The journal background must be a landscape spread.")
	_expect(header_inset != null and header_inset.custom_minimum_size.x >= 10.0, "Journal title needs left inset so scaled glyph overhang is not clipped.")
	_expect(journal_margin != null and journal_margin.get_theme_constant("margin_bottom") >= 96, "Journal content must keep a 32px-safe inset above the painted page curl.")

	var mode_tabs := ui.get_node_or_null("Center/MainPanel/Margin/Layout/ModeTabs")
	_expect(mode_tabs != null and mode_tabs.get_child_count() == 4, "The journal must expose four chapter tabs.")
	if mode_tabs != null:
		for tab_variant in mode_tabs.get_children():
			var tab := tab_variant as Button
			_expect(tab != null and tab.icon != null, "Every chapter tab needs a visible icon.")
			_expect(
				tab != null and (not tab.text.is_empty() or not tab.tooltip_text.is_empty()),
				"Every icon button needs a text label or tooltip."
			)
			_expect(tab != null and tab.size.x >= 32.0 and tab.size.y >= 32.0, "Chapter tabs need a 32px hit target.")
	var codex_tab := ui.get_node_or_null("Center/MainPanel/Margin/Layout/ModeTabs/Codex") as Button
	var codex_chapter := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Chapter"
	) as Label
	_expect(codex_tab != null and codex_tab.text == "圖鑑", "The visible chapter name must be 圖鑑 without CODEX.")
	_expect(codex_chapter != null and codex_chapter.text == "圖鑑", "The page heading must be 圖鑑 without COMPENDIUM.")

	var item_filter := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/InventoryPage/Browser/Filter"
	) as GridContainer
	var item_rows := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/InventoryPage/Browser/Items"
	) as ItemList
	_expect(item_rows != null and item_rows.get_theme_color("font_color").get_luminance() >= 0.55, "Unselected backpack rows need readable contrast on the dark list surface.")
	_expect(item_filter != null, "Backpack filters must be always-visible buttons, not a dropdown.")
	_expect(_has_filter_button(item_filter, "materials"), "Backpack must have a materials filter button.")
	_expect(_has_filter_button(item_filter, "quest"), "Backpack must have a key-item filter button.")
	_expect(_has_filter_button(item_filter, "gear"), "Backpack must have an equipment filter button.")
	var equip_button := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Equip"
	) as Button
	_expect(equip_button != null, "Equipment details need a direct equip action.")
	if equip_button != null:
		_expect(equip_button.size.y >= 32.0, "The equip action needs a 32px minimum hit target.")
		var request_capture := [StringName()]
		ui.connect("equip_requested", func(item_id: StringName) -> void: request_capture[0] = item_id)
		ui.call("set_items", [{
			"id": "iron_sword",
			"name": "Iron Sword",
			"category": "gear",
			"equipped": false,
		}])
		_expect(equip_button.visible and not equip_button.disabled, "Owned unequipped gear must expose an enabled equip action.")
		equip_button.pressed.emit()
		_expect(request_capture[0] == &"iron_sword", "Equip action must emit the selected equipment id.")

	var soul_rows := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Browser/Entries"
	) as ItemList
	var soul_hint := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Browser/Hint"
	) as Label
	var soul_bonus := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/BonusType"
	) as Label
	var soul_ability := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Effect"
	) as Label
	_expect(soul_rows != null and soul_rows.max_columns == 2, "Owned Sword Souls must use the journal's middle space as a two-column shelf.")
	ui.call("set_sword_souls", [{
		"instance_id": "ui-contract-soul",
		"name": "流火附魔",
		"level": 3,
		"kind_label": "現有劍魂",
		"bonus_type": "element",
		"bonus_type_label": "元素",
		"description": "讓每一次斬擊帶上火焰。",
		"ability_summary": "攻擊傷害 +4、附魔 1.5 秒",
	}])
	_expect(soul_bonus != null and soul_bonus.text == "加乘類型 · 元素", "Selected Sword Soul must show its projected Chinese bonus-type label.")
	_expect(soul_ability != null and soul_ability.text.contains("攻擊傷害 +4"), "Selected Sword Soul must show its projected short Chinese ability note.")
	_expect(
		soul_rows.get_item_text(0).contains("Lv.3")
			and soul_hint != null
			and soul_hint.text.contains("目前編成 1 / 4"),
		"Owned Sword Souls must expose visible levels and the complete loadout count."
	)

	var codex_filter := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Filter"
	) as GridContainer
	var codex_rows := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Entries"
	) as ItemList
	var codex_preview := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Preview"
	) as Control
	var codex_footer_safe := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/FooterSafe"
	) as Control
	var codex_bottom_inset := ui.get_node_or_null(
		"Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/BottomInset"
	) as Control
	_expect(
		codex_preview != null
			and codex_preview.custom_minimum_size.y >= 186.0
			and codex_preview.custom_minimum_size.y <= 194.0,
		"Codex live preview must be a compact landscape stage so the explanation panel stays large."
	)
	_expect(codex_footer_safe != null and codex_footer_safe.custom_minimum_size.y >= 26.0, "Codex details need an unpainted safe footer below the clipped scroll viewport.")
	_expect(codex_bottom_inset != null and codex_bottom_inset.custom_minimum_size.y >= 28.0, "Codex scroll content needs bottom space so the final line can rise above the footer mask.")
	_expect(codex_filter != null, "Codex filters must be always-visible buttons, not a dropdown.")
	for category in ["techniques", "enemies", "sword_souls", "equipment", "story_review"]:
		_expect(
			_has_filter_button(codex_filter, category),
			"Codex must expose the %s section." % category
		)
	_expect(ui.find_children("*", "OptionButton", true, false).is_empty(), "The I journal must not retain dropdown filters.")
	var long_codex: Array[Dictionary] = []
	for index in 20:
		long_codex.append({"section": "techniques", "id": "technique_%d" % index, "name": "Technique %d" % index})
	ui.call("set_codex_entries", long_codex)
	ui.call("set_mode", &"codex")
	ui.call("select_codex_entry", "technique_19")
	await process_frame
	_expect(ui.call("get_selected_codex_id") == "technique_19", "Programmatic codex selection must update the current row.")
	_expect(codex_rows != null and codex_rows.get_v_scroll_bar().value > 0.0, "Programmatic codex selection must scroll the selected row into view.")

	ui.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: four-chapter inventory journal UI contract")
	quit(1 if _failures > 0 else 0)


func _has_filter_button(filter: GridContainer, expected: String) -> bool:
	if filter == null:
		return false
	for child_variant in filter.get_children():
		var button := child_variant as Button
		if button != null and String(button.get_meta("filter_id", "")) == expected:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
