class_name CardGrowthUI
extends Control

signal choice_confirmed(choice_id: String)
signal reward_skipped

const MAX_GROWTH_CHOICES := 5

@onready var title_label: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title
@onready var source_label: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Source
@onready var instruction_label: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Instruction
@onready var upgrade_section: VBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection
@onready var upgrade_top_row: HBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/TopRow
@onready var upgrade_bottom_row: HBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/BottomRow
@onready var fusion_section: VBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FusionSection
@onready var fallback_section: VBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection
@onready var fallback_grid: GridContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection/FallbackGrid
@onready var required_hint: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/RequiredHint
@onready var skip_button: Button = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/SkipButton
@onready var confirm_button: Button = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/ConfirmButton

var _page: Dictionary = {}
var _choice_buttons: Array[Button] = []
var _choice_ids: Dictionary = {}
var _selected_choice_id := ""
var _confirmed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(confirm_selected_choice)
	skip_button.pressed.connect(skip_reward)


func present_page(page: Dictionary) -> void:
	_page = page.duplicate(true)
	_selected_choice_id = ""
	_confirmed = false
	_clear_choice_buttons()
	_apply_header()

	var upgrades: Array[Dictionary] = []
	var fusions: Array[Dictionary] = []
	var fallbacks: Array[Dictionary] = []
	var new_cards: Array[Dictionary] = []
	for choice_variant in _page.get("choices", []) as Array:
		if not choice_variant is Dictionary:
			continue
		var choice := (choice_variant as Dictionary).duplicate(true)
		match String(choice.get("action", "")):
			"new_card":
				new_cards.append(choice)
			"upgrade":
				upgrades.append(choice)
			"fusion":
				fusions.append(choice)
			"fallback":
				fallbacks.append(choice)

	upgrade_section.visible = not upgrades.is_empty() or not new_cards.is_empty()
	upgrade_section.visible = upgrade_section.visible or not fusions.is_empty()
	fusion_section.visible = false
	fallback_section.visible = not fallbacks.is_empty()
	($SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/SectionTitle as Label).text = (
		"NEW CARDS"
		if not new_cards.is_empty()
		else ("FULL-LEVEL FUSIONS" if upgrades.is_empty() and not fusions.is_empty() else "INDIVIDUAL UPGRADES")
	)
	for choice in new_cards:
		_add_growth_choice_button(choice, _new_card_text(choice))
	for choice in upgrades:
		_add_growth_choice_button(choice, _upgrade_text(choice))
	for choice in fusions:
		_add_growth_choice_button(choice, _fusion_text(choice))
	for choice in fallbacks:
		_add_choice_button(fallback_grid, choice, _fallback_text(choice))

	confirm_button.disabled = _choice_buttons.is_empty()
	confirm_button.text = "CONFIRM CHOICE"
	var source := String(_page.get("source", "")).to_lower()
	var can_skip := (
		(source == "wave" and not new_cards.is_empty())
		or (source == "fusion_followup" and not fusions.is_empty())
	)
	skip_button.visible = can_skip
	skip_button.disabled = not can_skip
	required_hint.text = (
		"Choose a card, or skip to keep your expedition deck compact."
		if can_skip
		else "A choice is required. This screen cannot be skipped."
	)
	visible = true
	if not _choice_buttons.is_empty():
		_wire_focus_navigation()
		_select_choice(String(_choice_buttons[0].get_meta("choice_id", "")))
		_choice_buttons[0].call_deferred("grab_focus")


func get_choice_button_count() -> int:
	return _choice_buttons.size()


func get_choice_buttons() -> Array[Button]:
	return _choice_buttons.duplicate()


func select_choice(choice_id: String) -> void:
	if _confirmed:
		return
	_select_choice(choice_id)


func confirm_selected_choice() -> void:
	if _confirmed or _selected_choice_id.is_empty():
		return
	_confirmed = true
	confirm_button.disabled = true
	confirm_button.text = "CHOICE LOCKED"
	for button in _choice_buttons:
		button.disabled = true
	choice_confirmed.emit(_selected_choice_id)


func skip_reward() -> void:
	if _confirmed or not skip_button.visible or skip_button.disabled:
		return
	_confirmed = true
	skip_button.disabled = true
	confirm_button.disabled = true
	for button in _choice_buttons:
		button.disabled = true
	reward_skipped.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()


func _apply_header() -> void:
	var source := String(_page.get("source", "")).to_lower()
	match source:
		"wave":
			title_label.text = "CHOOSE A NEW CARD"
			source_label.text = "WAVE BLESSING"
			instruction_label.text = "Add one card to this expedition deck."
		"experience":
			var has_fallback := _page_has_action("fallback")
			var has_upgrade := _page_has_action("upgrade")
			var has_fusion := _page_has_action("fusion")
			title_label.text = (
				"CHOOSE RESOURCES"
				if has_fallback
				else ("CHOOSE AN UPGRADE" if has_upgrade else "CHOOSE A FUSION")
			)
			source_label.text = "EXPERIENCE GROWTH"
			instruction_label.text = (
				"No card can grow. Choose one permanent resource bundle."
				if has_fallback
				else (
					"Choose one of five unfinished cards to level up."
					if has_upgrade
					else "Fuse one pair of full-level cards."
				)
			)
		"fusion_followup":
			title_label.text = "EVOLVE COMBO?"
			source_label.text = "NEW LV.3 PAIR"
			instruction_label.text = "Fuse two full-level cards into one stronger Combo, or keep both."
		_:
			title_label.text = "CARD GROWTH"
			source_label.text = "PENDING CHOICE"
			instruction_label.text = "Choose one reward to continue."


func _page_has_action(action: String) -> bool:
	for choice_variant in _page.get("choices", []) as Array:
		if choice_variant is Dictionary and String((choice_variant as Dictionary).get("action", "")) == action:
			return true
	return false


func _add_growth_choice_button(choice: Dictionary, display_text: String) -> void:
	if _choice_buttons.size() >= MAX_GROWTH_CHOICES:
		return
	var parent := upgrade_top_row if _choice_buttons.size() < 3 else upgrade_bottom_row
	_add_choice_button(parent, choice, display_text)


func _add_choice_button(parent: Control, choice: Dictionary, display_text: String) -> void:
	var choice_id := String(choice.get("choice_id", ""))
	if choice_id.is_empty() or _choice_ids.has(choice_id):
		return
	_choice_ids[choice_id] = true
	var button := Button.new()
	button.name = "Choice%d" % (_choice_buttons.size() + 1)
	button.custom_minimum_size = Vector2(280.0, 108.0)
	button.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
		if parent is HBoxContainer
		else Control.SIZE_EXPAND_FILL
	)
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.text = display_text
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = display_text
	button.set_meta("choice_id", choice_id)
	button.pressed.connect(_select_choice.bind(choice_id))
	parent.add_child(button)
	_choice_buttons.append(button)


func _select_choice(choice_id: String) -> void:
	if _confirmed or choice_id.is_empty():
		return
	var found := false
	for button in _choice_buttons:
		var is_selected := String(button.get_meta("choice_id", "")) == choice_id
		button.button_pressed = is_selected
		found = found or is_selected
	if not found:
		return
	_selected_choice_id = choice_id
	confirm_button.disabled = false


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.free()
	_choice_buttons.clear()
	_choice_ids.clear()


func _wire_focus_navigation() -> void:
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		var previous := _choice_buttons[maxi(index - 1, 0)]
		var next := _choice_buttons[mini(index + 1, _choice_buttons.size() - 1)]
		var above := _choice_buttons[maxi(index - 3, 0)]
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_neighbor_top = button.get_path_to(above)
		if index + 3 < _choice_buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(_choice_buttons[index + 3])
		else:
			button.focus_neighbor_bottom = button.get_path_to(confirm_button)
		button.focus_next = button.get_path_to(next if index < _choice_buttons.size() - 1 else confirm_button)
		button.focus_previous = button.get_path_to(previous)
	confirm_button.focus_neighbor_top = confirm_button.get_path_to(_choice_buttons[-1])
	confirm_button.focus_previous = confirm_button.get_path_to(_choice_buttons[-1])
	confirm_button.focus_next = confirm_button.get_path_to(_choice_buttons[0])
	if skip_button.visible:
		skip_button.focus_neighbor_top = skip_button.get_path_to(_choice_buttons[-1])
		skip_button.focus_previous = skip_button.get_path_to(_choice_buttons[-1])
		skip_button.focus_next = skip_button.get_path_to(confirm_button)


func _new_card_text(choice: Dictionary) -> String:
	return "%s\nNEW CARD  •  LV.1" % _choice_name(choice, "name", "card_id", "Unknown Card")


func _upgrade_text(choice: Dictionary) -> String:
	var level := clampi(int(choice.get("level", 1)), 1, 2)
	return "%s\nLV.%d  →  LV.%d\nINSTANCE  %s" % [
		_choice_name(choice, "name", "card_id", "Unknown Card"),
		level,
		level + 1,
		_short_id(String(choice.get("instance_id", ""))),
	]


func _fusion_text(choice: Dictionary) -> String:
	var left_name := _choice_name(choice, "left_name", "left_card_id", "Material A")
	var right_name := _choice_name(choice, "right_name", "right_card_id", "Material B")
	var result_name := _choice_name(choice, "result_name", "result_card_id", "Fusion Result")
	return "%s  +  %s\nLV.3  +  LV.3\n→  %s  •  LV.1" % [left_name, right_name, result_name]


func _fallback_text(choice: Dictionary) -> String:
	var reward := choice.get("reward", {}) as Dictionary
	if reward.has("gold"):
		return "%d GOLD\nTOWN & EQUIPMENT FUND" % int(reward.get("gold", 0))
	if reward.has("autumn_wood") or reward.has("stone"):
		return "%d AUTUMN WOOD  +  %d STONE\nBUILDING MATERIALS" % [
			int(reward.get("autumn_wood", 0)),
			int(reward.get("stone", 0)),
		]
	if reward.has("magic_shard"):
		return "%d MAGIC SHARDS\nRARE UPGRADE MATERIAL" % int(reward.get("magic_shard", 0))
	return "RESOURCE BUNDLE"


func _choice_name(choice: Dictionary, name_key: String, id_key: String, fallback: String) -> String:
	var display_name := String(choice.get(name_key, ""))
	if not display_name.is_empty():
		return display_name
	var raw_id := String(choice.get(id_key, ""))
	if raw_id.is_empty():
		return fallback
	return raw_id.replace("_", " ").capitalize()


func _short_id(instance_id: String) -> String:
	if instance_id.is_empty():
		return "—"
	return instance_id.left(12)
