class_name DeckBuilderUI
extends Control

signal deck_confirmed(deck_ids: Array[String])
signal loadout_confirmed(deck_ids: Array[String], auto_attack_card_id: String)
signal canceled

const SLOT_COUNT := 4
const HEALING_SLOT := 0
const SLOT_ROLES := ["治療", "COMBO 1", "COMBO 2", "COMBO 3"]

var _catalog: Array[Dictionary] = []
var _counts: Dictionary = {}
var _slot_card_ids: Array[String] = ["", "", "", ""]
var _active_slot_index := 0
var _visible_choice_ids: Array[String] = []
var _auto_attack_card_id := "ember_bolt"
var _finisher_catalog := ComboFinisherCatalog.new()
var _context_id: StringName

var _slot_buttons: Array[Button] = []
var _title_label: Label
var _hint_label: Label
var _choice_grid: GridContainer
var _choice_header: Label
var _detail_label: Label
var _recipe_summary: Label
var _count_label: Label
var _confirm_button: Button
var _auto_attack_selector: OptionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_finisher_catalog.load_catalog()
	_build_layout()
	_refresh_all()


func configure(
	cards: Array,
	current_deck: Array,
	auto_attack_card_id: String = "ember_bolt"
) -> void:
	_catalog.clear()
	_counts.clear()
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
		_refresh_all()


func set_context(context_id: StringName) -> void:
	_context_id = context_id
	if is_node_ready():
		_apply_context()


func get_context_id() -> StringName:
	return _context_id


func _restore_fixed_loadout(requested: Array[String]) -> void:
	_slot_card_ids = ["", "", "", ""]
	var requested_combos: Array[String] = []
	for card_id in requested:
		var card := _find_catalog_card(card_id)
		if not _is_combat_hand_card(card):
			continue
		var card_type := String(card.get("type", ""))
		if card_type == "healing" and _slot_card_ids[HEALING_SLOT].is_empty():
			_slot_card_ids[HEALING_SLOT] = card_id
		elif (
			card_type == "combo"
			and requested_combos.size() < 3
			and not requested_combos.has(card_id)
		):
			requested_combos.append(card_id)
	_fill_missing_slot(HEALING_SLOT, "healing", [])
	for combo_index in 3:
		var slot_index := combo_index + 1
		if combo_index < requested_combos.size():
			_slot_card_ids[slot_index] = requested_combos[combo_index]
		_fill_missing_slot(slot_index, "combo", _slot_card_ids)
	_sync_counts_from_slots()


func _fill_missing_slot(
	slot_index: int,
	required_type: String,
	excluded_ids: Array
) -> void:
	if not _slot_card_ids[slot_index].is_empty():
		return
	for card in _catalog:
		var card_id := String(card.get("id", ""))
		if (
			_is_combat_hand_card(card)
			and String(card.get("type", "")) == required_type
			and not excluded_ids.has(card_id)
		):
			_slot_card_ids[slot_index] = card_id
			return


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


func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	_active_slot_index = slot_index
	_refresh_slots()
	_rebuild_choices()


func choose_card_for_active_slot(card_id: String) -> bool:
	var card := _find_catalog_card(card_id)
	if not _is_card_valid_for_slot(card, _active_slot_index):
		return false
	if (
		_active_slot_index != HEALING_SLOT
		and _slot_card_ids.has(card_id)
		and _slot_card_ids[_active_slot_index] != card_id
	):
		return false
	_slot_card_ids[_active_slot_index] = card_id
	_sync_counts_from_slots()
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
	panel.name = "LoadoutPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-490, -330)
	panel.size = Vector2(980, 660)
	shade.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	column.add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
	column.add_child(_hint_label)

	_auto_attack_selector = OptionButton.new()
	_auto_attack_selector.name = "BasicAttackSelector"
	_auto_attack_selector.custom_minimum_size = Vector2(0, 40)
	_auto_attack_selector.item_selected.connect(_on_auto_attack_selected)
	column.add_child(_auto_attack_selector)

	var slots := HBoxContainer.new()
	slots.name = "LoadoutSlots"
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 10)
	column.add_child(slots)
	for slot_index in SLOT_COUNT:
		var slot := Button.new()
		slot.name = (
			"HealingSlot"
			if slot_index == HEALING_SLOT
			else "ComboSlot%d" % slot_index
		)
		slot.custom_minimum_size = Vector2(215, 100)
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_ALL
		slot.pressed.connect(select_slot.bind(slot_index))
		slots.add_child(slot)
		_slot_buttons.append(slot)

	_choice_header = Label.new()
	_choice_header.name = "ChoiceHeader"
	_choice_header.add_theme_font_size_override("font_size", 16)
	column.add_child(_choice_header)

	var scroll := ScrollContainer.new()
	scroll.name = "SkillChoiceScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_choice_grid = GridContainer.new()
	_choice_grid.name = "SkillChoices"
	_choice_grid.columns = 2
	_choice_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_grid.add_theme_constant_override("h_separation", 8)
	_choice_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_choice_grid)

	_detail_label = Label.new()
	_detail_label.name = "SelectedSkillDetail"
	_detail_label.custom_minimum_size = Vector2(0, 38)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.86))
	column.add_child(_detail_label)

	_recipe_summary = Label.new()
	_recipe_summary.name = "RecipeSummary"
	_recipe_summary.custom_minimum_size = Vector2(0, 32)
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


func _apply_context() -> void:
	if _title_label == null or _hint_label == null or _confirm_button == null:
		return
	if _context_id == &"blueprint_research":
		_title_label.text = "DESIGN RESEARCH"
		_hint_label.text = "Review the healing and combo blueprint slots, then save the design."
		_confirm_button.text = "SAVE DESIGN"
	else:
		_title_label.text = "EXPEDITION LOADOUT"
		_hint_label.text = "Choose a slot, then select a card below. Healing has a dedicated slot."
		_confirm_button.text = "ENTER FOREST"


func _refresh_all() -> void:
	if not is_node_ready() or _slot_buttons.is_empty():
		return
	_refresh_slots()
	_rebuild_choices()
	_rebuild_auto_attack_selector()
	_refresh_recipe_summary()
	_update_controls()


func _refresh_slots() -> void:
	for slot_index in _slot_buttons.size():
		var slot := _slot_buttons[slot_index]
		var card := _find_catalog_card(_slot_card_ids[slot_index])
		var icon := _card_icon(card)
		slot.text = "%s  %s\n%s\nAP %d" % [
			icon,
			SLOT_ROLES[slot_index],
			String(card.get("name", "選擇技能")),
			int(card.get("cost", 0)),
		]
		slot.button_pressed = slot_index == _active_slot_index
		slot.modulate = (
			Color(0.72, 1.0, 0.78)
			if slot_index == HEALING_SLOT
			else Color(0.90, 0.76, 1.0)
		)
		if slot_index == _active_slot_index:
			slot.modulate = Color(1.0, 0.82, 0.38)


func _rebuild_choices() -> void:
	if _choice_grid == null:
		return
	for child in _choice_grid.get_children():
		child.queue_free()
	_visible_choice_ids.clear()
	var required_type := "healing" if _active_slot_index == HEALING_SLOT else "combo"
	_choice_header.text = (
		"💚 選擇治療技能"
		if required_type == "healing"
		else "⚔ 選擇 COMBO %d" % _active_slot_index
	)
	for card in _catalog:
		if not _is_card_valid_for_slot(card, _active_slot_index):
			continue
		var card_id := String(card.get("id", ""))
		if (
			required_type == "combo"
			and _slot_card_ids.has(card_id)
			and _slot_card_ids[_active_slot_index] != card_id
		):
			continue
		_visible_choice_ids.append(card_id)
		var choice := Button.new()
		choice.name = "Choice_%s" % card_id
		choice.text = "%s  %s     AP %d" % [
			_card_icon(card),
			String(card.get("name", card_id)),
			int(card.get("cost", 0)),
		]
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.custom_minimum_size = Vector2(445, 44)
		choice.tooltip_text = String(card.get("description", ""))
		choice.disabled = _slot_card_ids[_active_slot_index] == card_id
		choice.pressed.connect(_on_choice_pressed.bind(card_id))
		_choice_grid.add_child(choice)
	var selected := _find_catalog_card(_slot_card_ids[_active_slot_index])
	_update_detail(selected)


func _on_choice_pressed(card_id: String) -> void:
	choose_card_for_active_slot(card_id)


func _update_detail(card: Dictionary) -> void:
	if _detail_label == null:
		return
	_detail_label.text = "%s  %s — %s" % [
		_card_icon(card),
		String(card.get("name", "尚未選擇技能")),
		String(card.get("description", "")),
	]


func _refresh_recipe_summary() -> void:
	if _recipe_summary == null:
		return
	var selected_combos: Array[String] = []
	for slot_index in range(1, SLOT_COUNT):
		if not _slot_card_ids[slot_index].is_empty():
			selected_combos.append(_slot_card_ids[slot_index])
	var available_names: Array[String] = []
	for recipe in _finisher_catalog.get_all_recipes():
		var all_available := true
		for required_id in recipe.get("required_skills", []):
			if not selected_combos.has(String(required_id)):
				all_available = false
				break
		if all_available:
			available_names.append(String(recipe.get("name", "Finisher")))
	_recipe_summary.text = (
		"⚔ 可用終結技  " + "  ·  ".join(available_names)
		if not available_names.is_empty()
		else "⚠ 這三張 Combo 目前沒有已學會的終結技配方"
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
	if String(_find_catalog_card(_slot_card_ids[0]).get("type", "")) != "healing":
		return false
	var combos: Array[String] = []
	for slot_index in range(1, SLOT_COUNT):
		var card_id := _slot_card_ids[slot_index]
		if String(_find_catalog_card(card_id).get("type", "")) != "combo":
			return false
		if combos.has(card_id):
			return false
		combos.append(card_id)
	return true


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
			"🎯 自動水平攻擊 — %s"
			% String(card.get("name", card_id))
		)
		_auto_attack_selector.set_item_metadata(index, card_id)
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
	if not _is_combat_hand_card(card):
		return false
	var expected_type := "healing" if slot_index == HEALING_SLOT else "combo"
	return String(card.get("type", "")) == expected_type


func _is_combat_hand_card(card: Dictionary) -> bool:
	return (
		String(card.get("type", "")) in ["combo", "healing"]
		and bool(card.get("combat_hand", true))
	)


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
