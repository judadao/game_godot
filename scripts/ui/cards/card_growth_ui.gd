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
var _choice_icon_cache: Dictionary = {}


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
	var divine_gifts: Array[Dictionary] = []
	var divine_fusions: Array[Dictionary] = []
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
			"divine_gift":
				divine_gifts.append(choice)
			"divine_fusion":
				divine_fusions.append(choice)

	upgrade_section.visible = (
		not upgrades.is_empty()
		or not new_cards.is_empty()
		or not divine_gifts.is_empty()
		or not divine_fusions.is_empty()
	)
	upgrade_section.visible = upgrade_section.visible or not fusions.is_empty()
	fusion_section.visible = false
	fallback_section.visible = not fallbacks.is_empty()
	($SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/SectionTitle as Label).text = (
		"DIVINE GIFTS"
		if not divine_gifts.is_empty() or not divine_fusions.is_empty()
		else (
			"NEW CARDS"
			if not new_cards.is_empty()
			else ("FULL-LEVEL FUSIONS" if upgrades.is_empty() and not fusions.is_empty() else "INDIVIDUAL UPGRADES")
		)
	)
	for choice in new_cards:
		_add_growth_choice_button(choice, _compact_new_card_text(choice))
	for choice in upgrades:
		_add_growth_choice_button(choice, _compact_upgrade_text(choice))
	for choice in fusions:
		_add_growth_choice_button(choice, _compact_fusion_text(choice))
	for choice in divine_gifts:
		_add_growth_choice_button(choice, _compact_divine_gift_text(choice))
	for choice in divine_fusions:
		_add_growth_choice_button(choice, _compact_divine_fusion_text(choice))
	for choice in fallbacks:
		_add_choice_button(fallback_grid, choice, _fallback_text(choice))

	confirm_button.disabled = _choice_buttons.is_empty()
	confirm_button.text = "CONFIRM CHOICE"
	var source := String(_page.get("source", "")).to_lower()
	var can_skip := (
		(source == "wave" and not new_cards.is_empty())
		or (source == "fusion_followup" and not fusions.is_empty())
		or (
			source == "divine"
			and divine_gifts.is_empty()
			and not divine_fusions.is_empty()
		)
	)
	skip_button.visible = can_skip
	skip_button.disabled = not can_skip
	required_hint.text = (
		"Keep both maximum Gifts, or fuse them."
		if source == "divine" and can_skip
		else "Choose a card, or skip to keep your expedition deck compact."
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
		"divine":
			title_label.text = "CHOOSE A DIVINE GIFT"
			source_label.text = "ELITE BLESSING"
			instruction_label.text = "Every Gift changes Combo skills and named Finishers."
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
	button.custom_minimum_size = Vector2(280.0, 148.0)
	button.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
		if parent is HBoxContainer
		else Control.SIZE_EXPAND_FILL
	)
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.text = display_text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 12)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = _choice_tooltip(choice, display_text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icon_path := String(choice.get("icon_path", "")).strip_edges()
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = _load_choice_icon(icon_path)
	var accent := _choice_accent(choice)
	button.set_meta("semantic_color", accent)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.98)
	normal_style.border_color = Color(accent, 0.9)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(7)
	normal_style.content_margin_left = 10.0
	normal_style.content_margin_right = 10.0
	var selected_style := normal_style.duplicate() as StyleBoxFlat
	selected_style.bg_color = Color(accent.r * 0.28, accent.g * 0.28, accent.b * 0.28, 1.0)
	selected_style.border_color = accent.lightened(0.22)
	selected_style.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", selected_style)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_stylebox_override("focus", selected_style)
	button.add_theme_color_override("font_color", accent.lightened(0.42))
	button.set_meta("choice_id", choice_id)
	button.pressed.connect(_select_choice.bind(choice_id))
	parent.add_child(button)
	_choice_buttons.append(button)


func _load_choice_icon(icon_path: String) -> Texture2D:
	if _choice_icon_cache.has(icon_path):
		return _choice_icon_cache[icon_path] as Texture2D
	var source := load(icon_path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var source_size := image.get_size()
	var longest_edge := maxi(source_size.x, source_size.y)
	if longest_edge > 48:
		var scale := 48.0 / float(longest_edge)
		var target_size := Vector2i(
			maxi(1, roundi(source_size.x * scale)),
			maxi(1, roundi(source_size.y * scale))
		)
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	var icon := ImageTexture.create_from_image(image)
	_choice_icon_cache[icon_path] = icon
	return icon


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
	return "%s\nNEW CARD  •  LV.1  •  %s  •  AP %d\n%s" % [
		_choice_name(choice, "name", "card_id", "Unknown Card"),
		String(choice.get("type", "card")).to_upper(),
		maxi(0, int(choice.get("cost", 0))),
		_choice_description(choice, "description", "No effect description available."),
	]


func _upgrade_text(choice: Dictionary) -> String:
	var level := clampi(int(choice.get("level", 1)), 1, 2)
	return "%s\nLV.%d  →  LV.%d\nNOW: %s\nUPGRADE: %s" % [
		_choice_name(choice, "name", "card_id", "Unknown Card"),
		level,
		level + 1,
		_choice_description(choice, "description", "No effect description available."),
		_choice_description(choice, "upgrade_description", "No upgrade description available."),
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


func _choice_description(choice: Dictionary, key: String, fallback: String) -> String:
	var description := String(choice.get(key, "")).strip_edges()
	return description if not description.is_empty() else fallback


func _compact_new_card_text(choice: Dictionary) -> String:
	return "%s\nNEW · %s · AP %d\n%s" % [
		_choice_name(choice, "name", "card_id", "Unknown Card"),
		String(choice.get("type", "card")).to_upper(),
		maxi(0, int(choice.get("cost", 0))),
		_bullet_description(_choice_description(
			choice,
			"description",
			"No effect description available."
		)),
	]


func _compact_upgrade_text(choice: Dictionary) -> String:
	var level := clampi(int(choice.get("level", 1)), 1, 2)
	return "%s\n%s · AP %d · LV.%d → LV.%d\n• NOW  %s\n• NEXT  %s" % [
		_choice_name(choice, "name", "card_id", "Unknown Card"),
		String(choice.get("type", "card")).to_upper(),
		maxi(0, int(choice.get("cost", 0))),
		level,
		level + 1,
		_key_point(_choice_description(
			choice,
			"description",
			"No effect description available."
		)),
		_key_point(_choice_description(
			choice,
			"upgrade_description",
			"No upgrade description available."
		)),
	]


func _compact_fusion_text(choice: Dictionary) -> String:
	var left_name := _choice_name(choice, "left_name", "left_card_id", "Material A")
	var right_name := _choice_name(choice, "right_name", "right_card_id", "Material B")
	var result_name := _choice_name(choice, "result_name", "result_card_id", "Fusion Result")
	return "%s + %s\nLV.3 + LV.3 → %s · LV.1\n%s" % [
		left_name,
		right_name,
		result_name,
		_bullet_description(_choice_description(
			choice,
			"description",
			"Creates a stronger Combo."
		)),
	]


func _compact_divine_gift_text(choice: Dictionary) -> String:
	var current_level := maxi(0, int(choice.get("level", 0)))
	return "%s  %s\nGIFT · LV.%d → LV.%d\n%s" % [
		String(choice.get("icon", "✦")),
		_choice_name(choice, "name", "gift_id", "Divine Gift"),
		current_level,
		int(choice.get("next_level", current_level + 1)),
		_bullet_description(_choice_description(
			choice,
			"description",
			"Changes Combo skills and named Finishers."
		)),
	]


func _compact_divine_fusion_text(choice: Dictionary) -> String:
	return "✺  %s\nMAX + MAX → EVOLVED\n%s" % [
		_choice_name(choice, "name", "choice_id", "Divine Evolution"),
		_bullet_description(_choice_description(
			choice,
			"description",
			"Combines both global rules."
		)),
	]


func _bullet_description(description: String) -> String:
	var normalized := description.strip_edges().replace("; ", ". ")
	var clauses := normalized.split(". ", false, 3)
	var bullets: Array[String] = []
	for clause_variant in clauses:
		if bullets.size() >= 2:
			break
		var clause := String(clause_variant).strip_edges()
		if not clause.is_empty():
			bullets.append("• %s" % _key_point(clause))
	return "\n".join(bullets)


func _key_point(description: String) -> String:
	var point := description.strip_edges()
	var sentence_end := point.find(". ")
	if sentence_end >= 0:
		point = point.left(sentence_end + 1)
	const MAX_KEY_POINT_LENGTH := 64
	if point.length() > MAX_KEY_POINT_LENGTH:
		point = point.left(MAX_KEY_POINT_LENGTH - 1).strip_edges() + "…"
	if not point.ends_with(".") and not point.ends_with("…"):
		point += "."
	return point


func _choice_tooltip(choice: Dictionary, display_text: String) -> String:
	var details: Array[String] = [display_text]
	for key in ["description", "upgrade_description"]:
		var detail := String(choice.get(key, "")).strip_edges()
		if not detail.is_empty() and not details.has(detail):
			details.append(detail)
	return "\n\n".join(details)


func _choice_accent(choice: Dictionary) -> Color:
	var semantic := String(choice.get("card_color", "")).to_lower()
	var card_type := String(choice.get("type", "")).to_lower()
	if semantic == "green" or card_type == "healing":
		return Color(0.35, 0.9, 0.48, 1.0)
	if card_type == "combo":
		return Color(0.68, 0.48, 1.0, 1.0)
	if card_type == "attack":
		return Color(1.0, 0.46, 0.27, 1.0)
	if card_type == "divine" or semantic == "gold":
		return Color(1.0, 0.78, 0.24, 1.0)
	return Color(0.36, 0.78, 0.96, 1.0)
