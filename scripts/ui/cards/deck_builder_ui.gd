class_name DeckBuilderUI
extends Control

signal deck_confirmed(deck_ids: Array[String])
signal loadout_confirmed(deck_ids: Array[String], auto_attack_card_id: String)
signal canceled

const SLOT_COUNT := 4
const SLOT_ROLES := ["固定治療", "劍魂 1", "劍魂 2", "劍魂 3"]
const SKILL_CATALOG_PATH := "res://data/skills.json"
const GEOMETRY_SCRIPT := preload("res://scripts/ui/cards/loadout_card_geometry.gd")
const INK := Color(0.010, 0.014, 0.021, 0.985)
const INK_RAISED := Color(0.025, 0.030, 0.042, 0.985)
const OLD_GOLD := Color(0.67, 0.49, 0.22, 1.0)
const BRIGHT_GOLD := Color(1.0, 0.84, 0.46, 1.0)
const HEALING_ACCENT := Color(0.56, 0.84, 0.45, 1.0)
const COMBO_ACCENT := Color(0.69, 0.52, 0.86, 1.0)

var _catalog: Array[Dictionary] = []
var _counts: Dictionary = {}
var _slot_card_ids: Array[String] = ["", "", "", ""]
var _active_slot_index := 0
var _visible_choice_ids: Array[String] = []
var _selected_skill_recipe_ids: Array[String] = []
var _auto_attack_card_id := "ember_bolt"
var _finisher_catalog := ComboFinisherCatalog.new()
var _skill_catalog := SkillRecipeManager.new()
var _context_id: StringName

var _slot_buttons: Array[Button] = []
var _title_label: Label
var _hint_label: Label
var _choice_grid: GridContainer
var _choice_scroll: ScrollContainer
var _loadout_panel: PanelContainer
var _choice_header: Label
var _detail_label: Label
var _recipe_summary: Label
var _count_label: Label
var _confirm_button: Button
var _auto_attack_selector: OptionButton
var _sword_soul_selector: VBoxContainer
var _skill_recipe_selector: VBoxContainer
var _recipe_choice_grid: GridContainer
var _recipe_scroll: ScrollContainer
var _sword_soul_mode_button: Button
var _skill_recipe_mode_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_finisher_catalog.load_catalog()
	_skill_catalog.load_catalog(SKILL_CATALOG_PATH)
	_build_layout()
	_apply_responsive_scale()
	if not get_viewport().size_changed.is_connected(_apply_responsive_scale):
		get_viewport().size_changed.connect(_apply_responsive_scale)
	_refresh_all()


func configure(
	cards: Array,
	current_deck: Array,
	auto_attack_card_id: String = "ember_bolt"
) -> void:
	_catalog.clear()
	_counts.clear()
	_selected_skill_recipe_ids.clear()
	for card_variant in cards:
		if not card_variant is Dictionary:
			continue
		var card := (card_variant as Dictionary).duplicate(true)
		_catalog.append(card)
		_counts[String(card.get("id", ""))] = 0
	var requested: Array[String] = []
	for card_id_variant in current_deck:
		var card_id := String(card_id_variant)
		if _counts.has(card_id) and not requested.has(card_id):
			requested.append(card_id)
	_restore_fixed_loadout(requested)
	_auto_attack_card_id = auto_attack_card_id
	if is_node_ready():
		set_skill_recipe_selector_visible(false)
		_refresh_all()


func set_context(context_id: StringName) -> void:
	_context_id = context_id
	if is_node_ready():
		_apply_context()


func get_context_id() -> StringName:
	return _context_id


func _restore_fixed_loadout(requested: Array[String]) -> void:
	_slot_card_ids = ["", "", "", ""]
	var restored: Array[String] = []
	var fixed_healing := ""
	for card_id in requested:
		var requested_card := _find_catalog_card(card_id)
		if (
			_is_combat_hand_card(requested_card)
			and String(requested_card.get("type", "")) == "healing"
		):
			fixed_healing = card_id
			break
	if fixed_healing.is_empty():
		fixed_healing = _first_available_card("healing", [])
	if not fixed_healing.is_empty():
		restored.append(fixed_healing)
	for card_id in requested:
		var card := _find_catalog_card(card_id)
		if (
			restored.size() >= SLOT_COUNT
			or restored.has(card_id)
			or not _is_combat_hand_card(card)
		):
			continue
		restored.append(card_id)
	while restored.size() < SLOT_COUNT:
		var fallback := _first_available_card("", restored)
		if fallback.is_empty():
			break
		restored.append(fallback)
	for slot_index in mini(SLOT_COUNT, restored.size()):
		_slot_card_ids[slot_index] = restored[slot_index]
	_sync_counts_from_slots()


func _first_available_card(required_type: String, excluded_ids: Array) -> String:
	for card in _catalog:
		var card_id := String(card.get("id", ""))
		if (
			_is_combat_hand_card(card)
			and (
				required_type.is_empty()
				or String(card.get("type", "")) == required_type
			)
			and not excluded_ids.has(card_id)
		):
			return card_id
	return ""


func _sync_counts_from_slots() -> void:
	for card_id in _counts:
		_counts[card_id] = 0
	for card_id in _slot_card_ids:
		if not card_id.is_empty():
			_counts[card_id] = 1


func _find_catalog_card(card_id: String) -> Dictionary:
	for card in _catalog:
		if String(card.get("id", "")) == card_id:
			return card
	return {}


func get_selected_deck() -> Array[String]:
	var result: Array[String] = []
	for card_id in _slot_card_ids:
		if not card_id.is_empty():
			result.append(card_id)
	return result


func get_selected_count() -> int:
	return get_selected_deck().size()


func get_configurable_count() -> int:
	return get_selected_count()


func get_auto_attack_card_id() -> String:
	return _auto_attack_card_id


func get_slot_card_ids() -> Array[String]:
	return _slot_card_ids.duplicate()


func get_active_slot_index() -> int:
	return _active_slot_index


func get_visible_choice_ids() -> Array[String]:
	return _visible_choice_ids.duplicate()


func get_selected_skill_recipe_ids() -> Array[String]:
	return _selected_skill_recipe_ids.duplicate()


func set_skill_recipe_selector_visible(show_recipes: bool) -> void:
	if _sword_soul_selector == null or _skill_recipe_selector == null:
		return
	_sword_soul_selector.visible = not show_recipes
	_skill_recipe_selector.visible = show_recipes
	if _sword_soul_mode_button != null:
		_sword_soul_mode_button.button_pressed = not show_recipes
		_apply_selection_mode_style(
			_sword_soul_mode_button,
			not show_recipes,
			COMBO_ACCENT
		)
	if _skill_recipe_mode_button != null:
		_skill_recipe_mode_button.button_pressed = show_recipes
		_apply_selection_mode_style(
			_skill_recipe_mode_button,
			show_recipes,
			BRIGHT_GOLD
		)


func is_skill_recipe_selectable(skill_id: String) -> bool:
	if _selected_skill_recipe_ids.has(skill_id):
		return true
	var recipe := _finisher_recipe_for_skill(skill_id)
	if recipe.is_empty() or not _recipe_requirements_available(recipe):
		return false
	var candidate_ids := _selected_skill_recipe_ids.duplicate()
	candidate_ids.append(skill_id)
	return _can_fit_skill_recipes(candidate_ids)


func choose_skill_recipe(skill_id: String) -> bool:
	if _selected_skill_recipe_ids.has(skill_id):
		_selected_skill_recipe_ids.erase(skill_id)
		_apply_selected_skill_recipes_to_slots()
		_refresh_all()
		return true
	if not is_skill_recipe_selectable(skill_id):
		return false
	_selected_skill_recipe_ids.append(skill_id)
	_apply_selected_skill_recipes_to_slots()
	_refresh_all()
	return true


func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	_active_slot_index = slot_index
	set_skill_recipe_selector_visible(false)
	_refresh_slots()
	_rebuild_choices()


func choose_card_for_active_slot(card_id: String) -> bool:
	var card := _find_catalog_card(card_id)
	if not _is_card_valid_for_slot(card, _active_slot_index):
		return false
	if (
		_slot_card_ids.has(card_id)
		and _slot_card_ids[_active_slot_index] != card_id
	):
		return false
	_slot_card_ids[_active_slot_index] = card_id
	_sync_counts_from_slots()
	_prune_selected_skill_recipes_for_loadout()
	_refresh_all()
	return true


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.018, 0.028, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	_loadout_panel = panel
	panel.name = "LoadoutPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-520, -340)
	panel.size = Vector2(1040, 680)
	panel.add_theme_stylebox_override("panel", _panel_style())
	shade.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68))
	column.add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
	column.add_child(_hint_label)

	var type_legend := HBoxContainer.new()
	type_legend.name = "TypeLegend"
	type_legend.alignment = BoxContainer.ALIGNMENT_CENTER
	type_legend.add_theme_constant_override("separation", 20)
	column.add_child(type_legend)
	_add_legend_chip(type_legend, "✚  第 1 格固定治療", HEALING_ACCENT)
	_add_legend_chip(type_legend, "◆  後 3 格組成招式劍魂", COMBO_ACCENT)
	_add_legend_chip(type_legend, "先點上方卡槽，再從下方替換", BRIGHT_GOLD)

	var slots := HBoxContainer.new()
	slots.name = "LoadoutSlots"
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 10)
	column.add_child(slots)
	for slot_index in SLOT_COUNT:
		var slot := Button.new()
		slot.name = "SkillSlot%d" % (slot_index + 1)
		slot.custom_minimum_size = Vector2(232, 126)
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_ALL
		slot.clip_contents = true
		slot.text = ""
		slot.pressed.connect(select_slot.bind(slot_index))
		slots.add_child(slot)
		_build_slot_visual(slot)
		_slot_buttons.append(slot)

	var loadout_tools := HBoxContainer.new()
	loadout_tools.name = "LoadoutTools"
	loadout_tools.add_theme_constant_override("separation", 10)
	column.add_child(loadout_tools)

	_auto_attack_selector = OptionButton.new()
	_auto_attack_selector.name = "BasicAttackSelector"
	_auto_attack_selector.custom_minimum_size = Vector2(360, 40)
	_auto_attack_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_attack_selector.add_theme_font_size_override("font_size", 16)
	_auto_attack_selector.item_selected.connect(_on_auto_attack_selected)
	loadout_tools.add_child(_auto_attack_selector)

	var selection_mode_bar := HBoxContainer.new()
	selection_mode_bar.name = "SelectionModeBar"
	selection_mode_bar.add_theme_constant_override("separation", 6)
	loadout_tools.add_child(selection_mode_bar)
	_sword_soul_mode_button = Button.new()
	_sword_soul_mode_button.name = "SwordSoulModeButton"
	_sword_soul_mode_button.text = "劍魂替換"
	_sword_soul_mode_button.toggle_mode = true
	_sword_soul_mode_button.custom_minimum_size = Vector2(176, 40)
	_sword_soul_mode_button.pressed.connect(
		set_skill_recipe_selector_visible.bind(false)
	)
	selection_mode_bar.add_child(_sword_soul_mode_button)
	_skill_recipe_mode_button = Button.new()
	_skill_recipe_mode_button.name = "SkillRecipeModeButton"
	_skill_recipe_mode_button.text = "依招式配置"
	_skill_recipe_mode_button.toggle_mode = true
	_skill_recipe_mode_button.custom_minimum_size = Vector2(176, 40)
	_skill_recipe_mode_button.pressed.connect(
		set_skill_recipe_selector_visible.bind(true)
	)
	selection_mode_bar.add_child(_skill_recipe_mode_button)

	var selection_workspace := VBoxContainer.new()
	selection_workspace.name = "SelectionWorkspace"
	selection_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(selection_workspace)

	_sword_soul_selector = VBoxContainer.new()
	_sword_soul_selector.name = "SwordSoulSelector"
	_sword_soul_selector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sword_soul_selector.add_theme_constant_override("separation", 5)
	selection_workspace.add_child(_sword_soul_selector)

	_choice_header = Label.new()
	_choice_header.name = "ChoiceHeader"
	_choice_header.add_theme_font_size_override("font_size", 16)
	_choice_header.add_theme_color_override("font_color", BRIGHT_GOLD)
	_sword_soul_selector.add_child(_choice_header)

	var scroll := ScrollContainer.new()
	_choice_scroll = scroll
	scroll.name = "SkillChoiceScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sword_soul_selector.add_child(scroll)
	_choice_grid = GridContainer.new()
	_choice_grid.name = "SkillChoices"
	_choice_grid.columns = 2
	_choice_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_grid.add_theme_constant_override("h_separation", 8)
	_choice_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_choice_grid)

	_detail_label = Label.new()
	_detail_label.name = "SelectedSkillDetail"
	_detail_label.custom_minimum_size = Vector2(0, 34)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.86))
	_sword_soul_selector.add_child(_detail_label)

	_skill_recipe_selector = VBoxContainer.new()
	_skill_recipe_selector.name = "SkillRecipeSelector"
	_skill_recipe_selector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_recipe_selector.add_theme_constant_override("separation", 5)
	selection_workspace.add_child(_skill_recipe_selector)
	var recipe_header := Label.new()
	recipe_header.name = "Header"
	recipe_header.text = "依招式配置  ·  相容配方可疊加，所需劍魂會填入後三格"
	recipe_header.add_theme_font_size_override("font_size", 16)
	recipe_header.add_theme_color_override("font_color", BRIGHT_GOLD)
	_skill_recipe_selector.add_child(recipe_header)
	var recipe_scroll := ScrollContainer.new()
	_recipe_scroll = recipe_scroll
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skill_recipe_selector.add_child(recipe_scroll)
	_recipe_choice_grid = GridContainer.new()
	_recipe_choice_grid.name = "RecipeChoices"
	_recipe_choice_grid.columns = 3
	_recipe_choice_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_choice_grid.add_theme_constant_override("h_separation", 7)
	_recipe_choice_grid.add_theme_constant_override("v_separation", 5)
	recipe_scroll.add_child(_recipe_choice_grid)
	set_skill_recipe_selector_visible(false)

	_recipe_summary = Label.new()
	_recipe_summary.name = "RecipeSummary"
	_recipe_summary.custom_minimum_size = Vector2(0, 30)
	_recipe_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_summary.add_theme_color_override("font_color", Color(0.84, 0.65, 1.0))
	column.add_child(_recipe_summary)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_count_label = Label.new()
	_count_label.custom_minimum_size = Vector2(170, 42)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_count_label)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(130, 42)
	cancel_button.pressed.connect(func() -> void: canceled.emit())
	footer.add_child(cancel_button)
	_confirm_button = Button.new()
	_confirm_button.text = "進入森林"
	_confirm_button.custom_minimum_size = Vector2(180, 42)
	_confirm_button.pressed.connect(func() -> void:
		loadout_confirmed.emit(get_selected_deck(), _auto_attack_card_id)
	)
	footer.add_child(_confirm_button)
	_apply_context()


func _apply_responsive_scale() -> void:
	if _loadout_panel == null:
		return
	var viewport_size := Vector2(get_viewport_rect().size)
	var scale_factor := clampf(
		minf(viewport_size.x / 1280.0, viewport_size.y / 720.0),
		1.0,
		1.75
	)
	_loadout_panel.pivot_offset = _loadout_panel.size * 0.5
	_loadout_panel.scale = Vector2.ONE * scale_factor


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = OLD_GOLD.lightened(0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	style.shadow_size = 0 if DisplayServer.get_name() == "headless" else 18
	return style


func _apply_selection_mode_style(
	button: Button,
	active: bool,
	accent: Color
) -> void:
	var normal := _button_style(accent, active, true)
	var hover := _button_style(accent.lightened(0.12), true, true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override(
		"font_color",
		BRIGHT_GOLD if active else Color(0.72, 0.74, 0.76)
	)
	button.add_theme_color_override("font_pressed_color", BRIGHT_GOLD)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))
	button.add_theme_color_override("font_focus_color", BRIGHT_GOLD)


func _add_legend_chip(parent: Container, text_value: String, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.82)
	style.border_color = Color(color.r, color.g, color.b, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	label.add_theme_stylebox_override("normal", style)
	parent.add_child(label)


func _build_slot_visual(slot: Button) -> void:
	var geometry := GEOMETRY_SCRIPT.new() as Control
	geometry.name = "Geometry"
	geometry.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	geometry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(geometry)

	var visual := Control.new()
	visual.name = "Visual"
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(visual)

	var icon_frame := Panel.new()
	icon_frame.name = "IconFrame"
	icon_frame.position = Vector2(14, 20)
	icon_frame.size = Vector2(72, 72)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(18, 24)
	icon.size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(icon)

	_add_visual_label(visual, "Role", Vector2(94, 13), Vector2(124, 20), 12)
	_add_visual_label(visual, "Type", Vector2(94, 34), Vector2(124, 20), 12)
	var name_label := _add_visual_label(visual, "Name", Vector2(94, 55), Vector2(124, 42), 17)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_visual_label(visual, "Cost", Vector2(94, 98), Vector2(70, 20), 14)
	var state_label := _add_visual_label(visual, "State", Vector2(158, 98), Vector2(60, 20), 11)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_choice_visual(choice: Button) -> void:
	var visual := Control.new()
	visual.name = "Visual"
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice.add_child(visual)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(8, 6)
	icon.size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(icon)
	_add_visual_label(visual, "Type", Vector2(60, 5), Vector2(270, 18), 11)
	_add_visual_label(visual, "Name", Vector2(60, 23), Vector2(310, 25), 16)
	var cost := Label.new()
	cost.name = "Cost"
	cost.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cost.position = Vector2(-86, 0)
	cost.size = Vector2(74, 54)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 14)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(cost)


func _apply_choice_visual(choice: Button, card: Dictionary, selected: bool) -> void:
	var accent := _card_accent(card)
	var visual := choice.get_node("Visual") as Control
	var icon := visual.get_node("Icon") as TextureRect
	var type_label := visual.get_node("Type") as Label
	var name_label := visual.get_node("Name") as Label
	var cost_label := visual.get_node("Cost") as Label
	icon.texture = _load_card_texture(card)
	type_label.text = "%s%s" % [
		_card_type_text(card),
		"  ·  已配置" if selected else "",
	]
	type_label.add_theme_color_override("font_color", accent.lightened(0.18))
	name_label.text = _display_name(card, String(card.get("id", "")))
	name_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78))
	cost_label.text = "AP  %d" % int(card.get("cost", 0))
	cost_label.add_theme_color_override("font_color", BRIGHT_GOLD)
	_apply_button_styles(choice, accent, selected, true)


func _add_visual_label(
	parent: Control,
	label_name: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.position = position_value
	label.size = size_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button_style(accent: Color, selected: bool, compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK_RAISED.lerp(Color(accent.r * 0.10, accent.g * 0.08, accent.b * 0.10, 1.0), 0.24)
	style.border_color = (
		BRIGHT_GOLD.lightened(0.10)
		if selected
		else OLD_GOLD.lerp(accent, 0.22).lightened(0.05)
	)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(4)
	style.shadow_color = (
		Color(BRIGHT_GOLD.r, BRIGHT_GOLD.g, BRIGHT_GOLD.b, 0.34)
		if selected
		else Color(0.0, 0.0, 0.0, 0.62)
	)
	style.shadow_size = 0 if DisplayServer.get_name() == "headless" else (8 if selected else 3)
	if compact:
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
	return style


func _apply_button_styles(button: Button, accent: Color, selected: bool, compact: bool = false) -> void:
	var normal := _button_style(accent, selected, compact)
	var hover := _button_style(accent.lightened(0.18), true, compact)
	var disabled := _button_style(accent.darkened(0.22), selected, compact)
	disabled.bg_color = disabled.bg_color.darkened(0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(color_key, Color.TRANSPARENT)


func _load_card_texture(card: Dictionary) -> Texture2D:
	var icon_path := String(card.get("icon_path", ""))
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _load_card_thumbnail(card: Dictionary, thumbnail_size: int) -> Texture2D:
	var source := _load_card_texture(card)
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	image.resize(thumbnail_size, thumbnail_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _card_accent(card: Dictionary) -> Color:
	if String(card.get("type", "")) == "healing":
		return HEALING_ACCENT
	var card_id := String(card.get("id", ""))
	if "flame" in card_id or "fire" in card_id:
		return Color(0.96, 0.43, 0.20, 1.0)
	if "frost" in card_id or "ice" in card_id:
		return Color(0.48, 0.78, 0.94, 1.0)
	if "storm" in card_id or "lightning" in card_id:
		return Color(0.38, 0.72, 0.92, 1.0)
	if "venom" in card_id or "poison" in card_id:
		return Color(0.55, 0.82, 0.36, 1.0)
	if "echo" in card_id:
		return Color(0.67, 0.50, 0.91, 1.0)
	return COMBO_ACCENT


func _card_type_text(card: Dictionary) -> String:
	return "✚  治療 HEALING" if String(card.get("type", "")) == "healing" else "◆  連段 COMBO"


func _apply_context() -> void:
	if _title_label == null or _hint_label == null or _confirm_button == null:
		return
	if _context_id == &"blueprint_research":
		_title_label.text = "技能設計研究"
		_hint_label.text = "第 1 格固定治療；選擇招式可自動配置後 3 格劍魂。"
		_confirm_button.text = "儲存設計"
	else:
		_title_label.text = "遠征技能配置"
		_hint_label.text = "第 1 格固定治療；選擇招式可自動配置後 3 格劍魂。"
		_confirm_button.text = "進入森林"


func _refresh_all() -> void:
	if not is_node_ready() or _slot_buttons.is_empty():
		return
	_refresh_slots()
	_rebuild_skill_recipe_choices()
	_rebuild_choices()
	_rebuild_auto_attack_selector()
	_refresh_recipe_summary()
	_update_controls()


func _refresh_slots() -> void:
	for slot_index in _slot_buttons.size():
		var slot := _slot_buttons[slot_index]
		var card := _find_catalog_card(_slot_card_ids[slot_index])
		var selected := slot_index == _active_slot_index
		var accent := _card_accent(card)
		slot.text = ""
		slot.button_pressed = selected
		slot.modulate = Color.WHITE
		slot.tooltip_text = "%s\n%s\nAP %d\n\n點擊後可在下方替換" % [
			_display_name(card, "選擇技能"),
			_display_description(card),
			int(card.get("cost", 0)),
		]
		var visual := slot.get_node("Visual") as Control
		var icon := visual.get_node("Icon") as TextureRect
		var role := visual.get_node("Role") as Label
		var type_label := visual.get_node("Type") as Label
		var name_label := visual.get_node("Name") as Label
		var cost_label := visual.get_node("Cost") as Label
		var state_label := visual.get_node("State") as Label
		icon.texture = _load_card_texture(card)
		role.text = "%02d  ·  %s" % [slot_index + 1, SLOT_ROLES[slot_index]]
		role.add_theme_color_override("font_color", Color(0.80, 0.72, 0.57))
		type_label.text = _card_type_text(card)
		type_label.add_theme_color_override("font_color", accent.lightened(0.18))
		name_label.text = _display_name(card, "選擇技能")
		name_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
		cost_label.text = "AP  %d" % int(card.get("cost", 0))
		cost_label.add_theme_color_override("font_color", BRIGHT_GOLD)
		state_label.text = "替換中" if selected else "點選"
		state_label.add_theme_color_override(
			"font_color",
			BRIGHT_GOLD if selected else Color(0.58, 0.61, 0.66)
		)
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(0.005, 0.007, 0.010, 0.98)
		icon_style.border_color = Color(accent.r, accent.g, accent.b, 0.70)
		icon_style.set_border_width_all(1)
		icon_style.set_corner_radius_all(3)
		(visual.get_node("IconFrame") as Panel).add_theme_stylebox_override("panel", icon_style)
		(slot.get_node("Geometry") as Control).call(
			"set_card_state",
			accent,
			selected,
			String(card.get("id", ""))
		)
		_apply_button_styles(slot, accent, selected)


func _rebuild_skill_recipe_choices() -> void:
	if _recipe_choice_grid == null:
		return
	for child in _recipe_choice_grid.get_children():
		_recipe_choice_grid.remove_child(child)
		child.queue_free()
	for skill in _skill_catalog.get_all_skills():
		var skill_id := String(skill.get("id", ""))
		var recipe := _finisher_recipe_for_skill(skill_id)
		var selected := _selected_skill_recipe_ids.has(skill_id)
		var selectable := is_skill_recipe_selectable(skill_id)
		var choice := Button.new()
		choice.name = "Skill_%s" % skill_id
		choice.custom_minimum_size = Vector2(310, 36)
		choice.toggle_mode = true
		choice.button_pressed = selected
		choice.disabled = not selectable
		choice.text = "%s%s" % [
			"✓  " if selected else "",
			_display_name(skill, skill_id),
		]
		choice.tooltip_text = "%s\n所需劍魂：%s" % [
			_display_description(skill),
			_recipe_requirement_names(recipe),
		]
		choice.pressed.connect(_on_skill_recipe_pressed.bind(skill_id))
		choice.focus_entered.connect(_focus_skill_recipe_choice.bind(choice))
		_apply_skill_recipe_button_style(choice, selected, selectable)
		_recipe_choice_grid.add_child(choice)
	_wire_skill_recipe_focus_navigation()


func _apply_skill_recipe_button_style(
	button: Button,
	selected: bool,
	selectable: bool
) -> void:
	var accent := BRIGHT_GOLD if selected else Color(0.78, 0.66, 0.48, 1.0)
	var normal := _button_style(accent, selected, true)
	var hover := _button_style(accent.lightened(0.15), true, true)
	var disabled := _button_style(Color(0.30, 0.32, 0.36, 1.0), false, true)
	disabled.bg_color = Color(0.035, 0.038, 0.045, 0.92)
	disabled.border_color = Color(0.25, 0.27, 0.30, 0.72)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override(
		"font_color",
		BRIGHT_GOLD if selected else Color(0.92, 0.86, 0.73, 1.0)
	)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_pressed_color", BRIGHT_GOLD)
	button.add_theme_color_override("font_focus_color", BRIGHT_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.36, 0.38, 0.41, 1.0))
	button.modulate = Color.WHITE if selectable else Color(0.78, 0.78, 0.78, 1.0)


func _on_skill_recipe_pressed(skill_id: String) -> void:
	choose_skill_recipe(skill_id)


func _focus_skill_recipe_choice(choice: Control) -> void:
	if _recipe_scroll != null:
		_recipe_scroll.call_deferred("ensure_control_visible", choice)


func _wire_skill_recipe_focus_navigation() -> void:
	var choices := _recipe_choice_grid.get_children()
	var columns := maxi(1, _recipe_choice_grid.columns)
	for index in choices.size():
		var choice := choices[index] as Button
		if choice.disabled:
			continue
		var left := index - 1
		if index % columns > 0 and left >= 0 and not (choices[left] as Button).disabled:
			choice.focus_neighbor_left = choice.get_path_to(choices[left])
		var right := index + 1
		if right < choices.size() and right % columns > 0 and not (choices[right] as Button).disabled:
			choice.focus_neighbor_right = choice.get_path_to(choices[right])
		var upper := index - columns
		while upper >= 0 and (choices[upper] as Button).disabled:
			upper -= columns
		if upper >= 0:
			choice.focus_neighbor_top = choice.get_path_to(choices[upper])
		var lower := index + columns
		while lower < choices.size() and (choices[lower] as Button).disabled:
			lower += columns
		if lower < choices.size():
			choice.focus_neighbor_bottom = choice.get_path_to(choices[lower])


func _rebuild_choices() -> void:
	if _choice_grid == null:
		return
	for child in _choice_grid.get_children():
		_choice_grid.remove_child(child)
		child.queue_free()
	_visible_choice_ids.clear()
	var fixed_healing_slot := _is_fixed_healing_slot(_active_slot_index)
	_choice_header.text = (
		"✚  固定治療槽：可更換其他治療劍魂，但不能改成 Combo"
		if fixed_healing_slot
		else "選擇替換卡  ·  綠色＝治療  /  紫色與元素色＝Combo"
	)
	_choice_header.add_theme_color_override(
		"font_color",
		HEALING_ACCENT.lightened(0.18) if fixed_healing_slot else BRIGHT_GOLD
	)
	for card in _catalog:
		if not _is_card_valid_for_slot(card, _active_slot_index):
			continue
		var card_id := String(card.get("id", ""))
		if (
			_slot_card_ids.has(card_id)
			and _slot_card_ids[_active_slot_index] != card_id
		):
			continue
		_visible_choice_ids.append(card_id)
		var choice := Button.new()
		choice.name = "Choice_%s" % card_id
		choice.text = ""
		choice.custom_minimum_size = Vector2(480, 54)
		choice.clip_contents = true
		choice.tooltip_text = _display_description(card)
		choice.disabled = _slot_card_ids[_active_slot_index] == card_id
		choice.pressed.connect(_on_choice_pressed.bind(card_id))
		choice.focus_entered.connect(_preview_choice.bind(card_id, choice))
		choice.mouse_entered.connect(_preview_choice.bind(card_id, choice))
		choice.mouse_exited.connect(_restore_active_detail)
		_choice_grid.add_child(choice)
		_build_choice_visual(choice)
		_apply_choice_visual(choice, card, choice.disabled)
	_wire_choice_focus_navigation()
	var selected := _find_catalog_card(_slot_card_ids[_active_slot_index])
	_update_detail(selected)


func _on_choice_pressed(card_id: String) -> void:
	choose_card_for_active_slot(card_id)


func _preview_choice(card_id: String, choice: Control) -> void:
	_update_detail(_find_catalog_card(card_id))
	if _choice_scroll != null:
		_choice_scroll.call_deferred("ensure_control_visible", choice)


func _restore_active_detail() -> void:
	_update_detail(_find_catalog_card(_slot_card_ids[_active_slot_index]))


func _wire_choice_focus_navigation() -> void:
	var choices := _choice_grid.get_children()
	for index in choices.size():
		var choice := choices[index] as Button
		if choice.disabled:
			continue
		if index % 2 == 1 and not (choices[index - 1] as Button).disabled:
			choice.focus_neighbor_left = choice.get_path_to(choices[index - 1])
		elif index + 1 < choices.size() and not (choices[index + 1] as Button).disabled:
			choice.focus_neighbor_right = choice.get_path_to(choices[index + 1])
		var upper := index - 2
		while upper >= 0 and (choices[upper] as Button).disabled:
			upper -= 2
		if upper >= 0:
			choice.focus_neighbor_top = choice.get_path_to(choices[upper])
		var lower := index + 2
		while lower < choices.size() and (choices[lower] as Button).disabled:
			lower += 2
		if lower < choices.size():
			choice.focus_neighbor_bottom = choice.get_path_to(choices[lower])


func _update_detail(card: Dictionary) -> void:
	if _detail_label == null:
		return
	_detail_label.text = "%s  ·  %s  —  %s" % [
		_card_type_text(card),
		_display_name(card, "尚未選擇技能"),
		_display_description(card),
	]
	_detail_label.add_theme_color_override("font_color", _card_accent(card).lightened(0.18))


func _refresh_recipe_summary() -> void:
	if _recipe_summary == null:
		return
	var selected_skills: Array[String] = []
	for card_id in _slot_card_ids:
		if not card_id.is_empty():
			selected_skills.append(card_id)
	var available_recipes: Array[String] = []
	for recipe in _finisher_catalog.get_all_recipes():
		var all_available := true
		for required_id in recipe.get("required_skills", []):
			if not selected_skills.has(String(required_id)):
				all_available = false
				break
		if all_available:
			available_recipes.append(_format_recipe_hint(recipe))
	_recipe_summary.text = (
		"⚔ 可用終結技  " + "  ·  ".join(available_recipes)
		if not available_recipes.is_empty()
		else "⚠ 目前四張技能沒有可用的終結技配方"
	)


func _update_controls() -> void:
	var valid := _is_valid_loadout()
	if _count_label != null:
		_count_label.text = "4 / 4 可出戰" if valid else "已選 %d / 4" % get_selected_count()
		_count_label.modulate = (
			Color(0.55, 1.0, 0.65)
			if valid
			else Color(1.0, 0.68, 0.34)
		)
	if _confirm_button != null:
		_confirm_button.disabled = not valid


func _is_valid_loadout() -> bool:
	if get_selected_count() != SLOT_COUNT:
		return false
	var unique_ids: Array[String] = []
	for card_id in _slot_card_ids:
		if unique_ids.has(card_id) or not _is_combat_hand_card(_find_catalog_card(card_id)):
			return false
		unique_ids.append(card_id)
	return String(_find_catalog_card(_slot_card_ids[0]).get("type", "")) == "healing"


func _rebuild_auto_attack_selector() -> void:
	if _auto_attack_selector == null:
		return
	_auto_attack_selector.clear()
	var selected_index := -1
	for card in _catalog:
		if String(card.get("type", "")) != "attack":
			continue
		var index := _auto_attack_selector.item_count
		var card_id := String(card.get("id", ""))
		_auto_attack_selector.add_item(
			"自動攻擊  ·  %s"
			% _display_name(card, card_id)
		)
		_auto_attack_selector.set_item_metadata(index, card_id)
		var card_texture := _load_card_thumbnail(card, 28)
		if card_texture != null:
			_auto_attack_selector.set_item_icon(index, card_texture)
		if card_id == _auto_attack_card_id:
			selected_index = index
	if _auto_attack_selector.item_count <= 0:
		_auto_attack_card_id = ""
		_auto_attack_selector.disabled = true
		return
	_auto_attack_selector.disabled = false
	if selected_index < 0:
		selected_index = 0
		_auto_attack_card_id = String(_auto_attack_selector.get_item_metadata(0))
	_auto_attack_selector.select(selected_index)


func _on_auto_attack_selected(index: int) -> void:
	if (
		_auto_attack_selector == null
		or index < 0
		or index >= _auto_attack_selector.item_count
	):
		return
	_auto_attack_card_id = String(_auto_attack_selector.get_item_metadata(index))


func _is_card_valid_for_slot(card: Dictionary, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or not _is_combat_hand_card(card):
		return false
	return slot_index != 0 or String(card.get("type", "")) == "healing"


func _is_combat_hand_card(card: Dictionary) -> bool:
	return (
		String(card.get("type", "")) in ["combo", "healing"]
		and bool(card.get("combat_hand", true))
		and _finisher_catalog.is_skill_eligible(String(card.get("id", "")))
	)


func _recipe_requirements_available(recipe: Dictionary) -> bool:
	var required_ids := recipe.get("required_skills", []) as Array
	if required_ids.is_empty():
		return false
	for card_id_variant in required_ids:
		if not _is_combat_hand_card(_find_catalog_card(String(card_id_variant))):
			return false
	return true


func _finisher_recipe_for_skill(skill_id: String) -> Dictionary:
	var profile_id := _skill_catalog.get_legacy_vfx_id(skill_id)
	return _finisher_catalog.get_recipe(profile_id) if not profile_id.is_empty() else {}


func _required_souls_for_skill_recipes(recipe_ids: Array) -> Array[String]:
	var required: Array[String] = []
	for skill_id_variant in recipe_ids:
		var recipe := _finisher_recipe_for_skill(String(skill_id_variant))
		for card_id_variant in recipe.get("required_skills", []) as Array:
			var card_id := String(card_id_variant)
			if not required.has(card_id):
				required.append(card_id)
	return required


func _can_fit_skill_recipes(recipe_ids: Array) -> bool:
	for skill_id_variant in recipe_ids:
		var recipe := _finisher_recipe_for_skill(String(skill_id_variant))
		if recipe.is_empty() or not _recipe_requirements_available(recipe):
			return false
	var required := _required_souls_for_skill_recipes(recipe_ids)
	var fixed_healing := _slot_card_ids[0] if not _slot_card_ids.is_empty() else ""
	if not fixed_healing.is_empty():
		required.erase(fixed_healing)
	return required.size() <= SLOT_COUNT - 1


func _apply_selected_skill_recipes_to_slots() -> void:
	var requested: Array[String] = []
	var fixed_healing := _slot_card_ids[0] if not _slot_card_ids.is_empty() else ""
	if not fixed_healing.is_empty():
		requested.append(fixed_healing)
	for required_id in _required_souls_for_skill_recipes(_selected_skill_recipe_ids):
		if required_id != fixed_healing and not requested.has(required_id):
			requested.append(required_id)
	for current_card_id in _slot_card_ids.slice(1):
		if not current_card_id.is_empty() and not requested.has(current_card_id):
			requested.append(current_card_id)
	_restore_fixed_loadout(requested)


func _prune_selected_skill_recipes_for_loadout() -> void:
	var retained: Array[String] = []
	for skill_id in _selected_skill_recipe_ids:
		var recipe := _finisher_recipe_for_skill(skill_id)
		var requirements_met := not recipe.is_empty()
		for card_id_variant in recipe.get("required_skills", []) as Array:
			if not _slot_card_ids.has(String(card_id_variant)):
				requirements_met = false
				break
		if requirements_met:
			retained.append(skill_id)
	_selected_skill_recipe_ids = retained


func _recipe_requirement_names(recipe: Dictionary) -> String:
	var names: Array[String] = []
	for card_id_variant in recipe.get("required_skills", []) as Array:
		var card_id := String(card_id_variant)
		names.append(_display_name(_find_catalog_card(card_id), card_id))
	return "、".join(names)


func _card_icon(card: Dictionary) -> String:
	var card_id := String(card.get("id", ""))
	if String(card.get("type", "")) == "healing":
		return "💚"
	if "flame" in card_id:
		return "🔥"
	if "frost" in card_id:
		return "❄"
	if "storm" in card_id:
		return "⚡"
	if "echo" in card_id:
		return "🌀"
	if "venom" in card_id:
		return "☠"
	return "◆"


func _is_fixed_healing_slot(slot_index: int) -> bool:
	return slot_index == 0


func _format_recipe_hint(recipe: Dictionary) -> String:
	var sequence_names: Array[String] = []
	for card_id_variant in recipe.get("sequence", []) as Array:
		var card_id := String(card_id_variant)
		sequence_names.append(_display_name(_find_catalog_card(card_id), card_id))
	var formula := " → ".join(sequence_names)
	if (
		sequence_names.size() == 3
		and sequence_names[0] == sequence_names[1]
		and sequence_names[1] == sequence_names[2]
	):
		formula = "%s ×3" % sequence_names[0]
	return "%s（%s）" % [_display_name(recipe, "終結技"), formula]


func _display_name(entry: Dictionary, fallback: String) -> String:
	for key in [
		"display_name_zh_tw", "name_zh_tw", "display_name_zh", "name_zh",
		"display_name", "name",
	]:
		var value := String(entry.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return fallback


func _display_description(entry: Dictionary) -> String:
	for key in ["description_zh_tw", "description_zh", "description"]:
		var value := String(entry.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""
