class_name CardGrowthUI
extends Control

signal choice_confirmed(choice_id: String)
signal reward_skipped

const MAX_GROWTH_CHOICES := 5
const DIVINE_GIFT_CHOICE_SCENE := preload(
	"res://scenes/ui/cards/DivineGiftChoiceCard.tscn"
)

@onready var title_label: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title
@onready var modal_panel: PanelContainer = $SafeMargin/ModalCenter/ModalPanel
@onready var source_label: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Source
@onready var instruction_label: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Instruction
@onready var choice_scroll: ScrollContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll
@onready var upgrade_section: VBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection
@onready var upgrade_top_row: HBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/TopRow
@onready var upgrade_bottom_row: HBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/UpgradeGrid/BottomRow
@onready var fusion_section: VBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FusionSection
@onready var fusion_grid: GridContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FusionSection/FusionGrid
@onready var fallback_section: VBoxContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection
@onready var fallback_grid: GridContainer = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection/FallbackGrid
@onready var selection_summary: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/SelectionSummary
@onready var required_hint: Label = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/RequiredHint
@onready var skip_button: Button = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/SkipButton
@onready var confirm_button: Button = $SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/ConfirmButton

var _page: Dictionary = {}
var _choice_buttons: Array[Button] = []
var _choice_ids: Dictionary = {}
var _choice_data_by_id: Dictionary = {}
var _selected_choice_id := ""
var _confirmed := false
var _choice_icon_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(confirm_selected_choice)
	skip_button.pressed.connect(skip_reward)
	_apply_responsive_modal_geometry()
	if not get_viewport().size_changed.is_connected(_apply_responsive_modal_geometry):
		get_viewport().size_changed.connect(_apply_responsive_modal_geometry)


func present_page(page: Dictionary) -> void:
	_page = page.duplicate(true)
	_selected_choice_id = ""
	_confirmed = false
	_clear_choice_buttons()
	choice_scroll.scroll_vertical = 0
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
	)
	fusion_section.visible = not fusions.is_empty() or not divine_fusions.is_empty()
	fallback_section.visible = not fallbacks.is_empty()
	selection_summary.visible = not divine_gifts.is_empty() or not divine_fusions.is_empty()
	($SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection/SectionTitle as Label).text = (
		"神賜"
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
		_add_fusion_choice_button(choice, _compact_fusion_text(choice))
	for choice in divine_gifts:
		_add_growth_choice_button(choice, _compact_divine_gift_text(choice))
	for choice in divine_fusions:
		_add_fusion_choice_button(choice, _compact_divine_fusion_text(choice))
	for choice in fallbacks:
		_add_choice_button(fallback_grid, choice, _fallback_text(choice))
	fusion_section.visible = fusion_grid.get_child_count() > 0

	confirm_button.disabled = _choice_buttons.is_empty()
	confirm_button.text = "確認選擇"
	var source := String(_page.get("source", "")).to_lower()
	var can_skip := (
		(source == "wave" and not new_cards.is_empty())
		or (
			source == "divine"
			and divine_gifts.is_empty()
			and not divine_fusions.is_empty()
		)
	)
	skip_button.visible = can_skip
	skip_button.disabled = not can_skip
	required_hint.text = (
		"可保留兩項滿級神賜，或選擇將它們昇華融合。"
		if source == "divine" and can_skip
		else "選擇一張卡，或略過以維持精簡的遠征牌組。"
		if can_skip
		else "必須完成一項選擇，無法略過此畫面。"
	)
	visible = true
	_apply_responsive_modal_geometry()
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
	confirm_button.text = "選擇已鎖定"
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
			title_label.text = (
				"選擇一份成長資源"
				if has_fallback
				else "選擇新的祝福或提升祝福"
			)
			source_label.text = "角色升等"
			instruction_label.text = (
				"所有祝福都已達上限，抽取金錢或素材作為本次成長。"
				if has_fallback
				else "選擇尚未持有的新祝福，或提升一項目前擁有的祝福。"
			)
		"divine":
			title_label.text = "選擇一項神賜"
			source_label.text = "菁英祝福"
			instruction_label.text = "每項神賜都會改變連段招式與具名終結技。"
		"elite":
			title_label.text = "選擇菁英戰利品"
			source_label.text = "階段菁英"
			instruction_label.text = "提升祝福，或融合出會繼承劍魂效果的專屬背景自動攻擊。"
		"boss":
			title_label.text = "選擇首領戰利品"
			source_label.text = "BOSS 獎勵"
			instruction_label.text = "提升祝福，或融合出會繼承劍魂效果的專屬背景自動攻擊。"
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


func _add_fusion_choice_button(choice: Dictionary, display_text: String) -> void:
	if _choice_buttons.size() >= MAX_GROWTH_CHOICES:
		return
	_add_choice_button(fusion_grid, choice, display_text)


func _add_choice_button(parent: Control, choice: Dictionary, display_text: String) -> void:
	var choice_id := String(choice.get("choice_id", ""))
	if choice_id.is_empty() or _choice_ids.has(choice_id):
		return
	_choice_ids[choice_id] = true
	_choice_data_by_id[choice_id] = choice.duplicate(true)
	var is_divine := String(choice.get("action", "")).begins_with("divine_")
	var button := (
		DIVINE_GIFT_CHOICE_SCENE.instantiate() as Button
		if is_divine
		else Button.new()
	)
	button.name = "Choice%d" % (_choice_buttons.size() + 1)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
		if is_divine or not parent is HBoxContainer
		else Control.SIZE_SHRINK_CENTER
	)
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	var accent := _choice_accent(choice)
	button.set_meta("semantic_color", accent)
	button.set_meta("choice_id", choice_id)
	button.pressed.connect(_select_choice.bind(choice_id))
	parent.add_child(button)
	if is_divine:
		button.call("configure", choice, _divine_effect_lines(choice))
	else:
		button.custom_minimum_size = Vector2(280.0, 148.0)
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


func _apply_responsive_modal_geometry() -> void:
	if modal_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var available := Vector2(
		maxf(900.0, viewport_size.x - 72.0),
		maxf(560.0, viewport_size.y - 72.0)
	)
	modal_panel.custom_minimum_size = Vector2(
		minf(available.x, clampf(viewport_size.x * 0.82, 1040.0, 1580.0)),
		minf(available.y, clampf(viewport_size.y * 0.78, 620.0, 680.0))
	)


func _select_choice(choice_id: String) -> void:
	if _confirmed or choice_id.is_empty():
		return
	var found := false
	for button in _choice_buttons:
		var is_selected := String(button.get_meta("choice_id", "")) == choice_id
		if button.has_method("set_selected_state"):
			button.call("set_selected_state", is_selected)
		else:
			button.button_pressed = is_selected
		found = found or is_selected
	if not found:
		return
	_selected_choice_id = choice_id
	confirm_button.disabled = false
	_update_selection_summary()
	var selected_button := _choice_button_for_id(choice_id)
	if selected_button != null:
		choice_scroll.call_deferred("ensure_control_visible", selected_button)


func _choice_button_for_id(choice_id: String) -> Button:
	for button in _choice_buttons:
		if String(button.get_meta("choice_id", "")) == choice_id:
			return button
	return null


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.free()
	_choice_buttons.clear()
	_choice_ids.clear()
	_choice_data_by_id.clear()


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
	var tier_name := (
		"昇華神賜"
		if String(choice.get("kind", "base")) == "evolved"
		else "神賜"
	)
	return "%s  %s\n%s · 等級 %d → %d\n%s" % [
		String(choice.get("icon", "✦")),
		_choice_name(choice, "name", "gift_id", "神賜"),
		tier_name,
		current_level,
		int(choice.get("next_level", current_level + 1)),
		"\n".join(_divine_effect_lines(choice)),
	]


func _compact_divine_fusion_text(choice: Dictionary) -> String:
	var profile := choice.get("background_attack", {}) as Dictionary
	return "✺  %s\n滿級 + 滿級 → 昇華\n背景自動攻擊：%s｜每 %.1f 秒｜%d 目標\n%s" % [
		_choice_name(choice, "name", "choice_id", "神賜昇華"),
		String(profile.get("name", "專屬攻擊")),
		float(profile.get("interval", 0.0)),
		int(profile.get("target_count", 1)),
		_bullet_description(_choice_description(
			choice,
			"description",
			"融合兩項神賜的整體規則。"
		)),
	]


func _update_selection_summary() -> void:
	if not selection_summary.visible or not _choice_data_by_id.has(_selected_choice_id):
		return
	var choice := _choice_data_by_id[_selected_choice_id] as Dictionary
	var lines := _divine_effect_lines(choice)
	selection_summary.text = "已選：%s｜%s" % [
		_choice_name(choice, "name", "gift_id", "神賜"),
		"　".join(lines.slice(0, 2)),
	]
	selection_summary.tooltip_text = "%s\n%s" % [
		String(choice.get("description", "")),
		"\n".join(lines),
	]


func _divine_effect_lines(choice: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var status_names: Array[String] = []
	for status_variant in choice.get("basic_attack_statuses", []) as Array:
		if not status_variant is Dictionary:
			continue
		var status := status_variant as Dictionary
		status_names.append(String(status.get("name", "元素附著")))
	if not status_names.is_empty():
		lines.append("⚔ 普攻／傷害招式：%s" % " + ".join(status_names))
	var fusion_hint := _best_fusion_hint(
		choice.get("fusion_hints", []) as Array
	)
	if not fusion_hint.is_empty() and lines.size() < 3:
		var partner_owned := bool(fusion_hint.get("partner_owned", false))
		var hint_line := "◇ 目前持有神賜無法與此候選融合"
		if partner_owned:
			hint_line = "◇ 你已持有【%s】｜可融合：%s" % [
				String(fusion_hint.get("partner_name", "另一神賜")),
				String(fusion_hint.get("result_name", "神賜昇華")),
			]
			if bool(fusion_hint.get("ready_after_selection", false)):
				hint_line = "◇ 選下後可融合【%s】→ %s" % [
					String(fusion_hint.get("partner_name", "另一神賜")),
					String(fusion_hint.get("result_name", "神賜昇華")),
				]
		var required_equipment := String(
			fusion_hint.get("required_equipment_name", "")
		).strip_edges()
		if partner_owned and not required_equipment.is_empty():
			hint_line += (
				"｜%s已裝備" % required_equipment
				if bool(fusion_hint.get("equipment_ready", false))
				else "｜需%s" % required_equipment
			)
		lines.append(hint_line)
	var equipment_name := String(choice.get("required_equipment_name", "")).strip_edges()
	if not equipment_name.is_empty():
		lines.append("◆ 儀式觸媒：%s（已裝備）" % equipment_name)
	var background_attack := choice.get("background_attack", {}) as Dictionary
	if not background_attack.is_empty() and lines.size() < 3:
		lines.append("✺ 背景自動攻擊：%s（%.1f 秒，繼承劍魂）" % [
			String(background_attack.get("name", "專屬攻擊")),
			float(background_attack.get("interval", 0.0)),
		])
	var effects := choice.get("next_effects", {}) as Dictionary
	var effect_order := [
		"combo_stack_bonus",
		"combo_effect_multiplier",
		"combo_ap_refund",
		"combo_element_bonus",
		"combo_speed_bonus",
		"combo_stack_cap_bonus",
		"finisher_damage_multiplier",
		"finisher_heal",
		"finisher_element_damage",
		"finisher_size_multiplier",
		"finisher_history_bonus",
	]
	for key_variant in effect_order:
		var key := String(key_variant)
		if not effects.has(key):
			continue
		var value: Variant = effects[key]
		match key:
			"combo_stack_bonus":
				lines.append("◆ 連段疊層 +%d" % int(value))
			"combo_effect_multiplier":
				lines.append("✦ 連段效果 +%d%%" % roundi((float(value) - 1.0) * 100.0))
			"combo_ap_refund":
				lines.append("↺ 每次連段返還 AP %.2f" % float(value))
			"combo_element_bonus":
				lines.append("◇ 連段元素加值 +%d" % int(value))
			"combo_speed_bonus":
				lines.append("» 連段速度 +%d%%" % roundi(float(value) * 100.0))
			"combo_stack_cap_bonus":
				lines.append("∞ 連段疊層上限 +%d" % int(value))
			"finisher_damage_multiplier":
				lines.append("⚔ 終結技傷害 +%d%%" % roundi((float(value) - 1.0) * 100.0))
			"finisher_heal":
				lines.append("♥ 終結技回復生命 +%d" % int(value))
			"finisher_element_damage":
				lines.append("⚡ 終結技元素傷害 +%d" % int(value))
			"finisher_size_multiplier":
				lines.append("◎ 終結技範圍 +%d%%" % roundi((float(value) - 1.0) * 100.0))
			"finisher_history_bonus":
				lines.append("◈ 終結技額外讀取 %d 段公式" % int(value))
		if lines.size() >= 3:
			break
	var mechanic := _divine_mechanic_line(choice.get("finisher_mutations", {}) as Dictionary)
	if not mechanic.is_empty() and lines.size() < 3:
		lines.append(mechanic)
	if lines.is_empty():
		lines.append("✦ %s" % _key_point(_choice_description(
			choice,
			"description",
			"改變連段招式與具名終結技。"
		)))
	if lines.size() == 1:
		lines.append("⚔ 強化具名終結技的特殊機制")
	return lines


func _best_fusion_hint(hints: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for hint_variant in hints:
		if not hint_variant is Dictionary:
			continue
		var hint := hint_variant as Dictionary
		var score := 0
		if bool(hint.get("partner_owned", false)):
			score += 20
		if bool(hint.get("equipment_ready", false)):
			score += 5
		if bool(hint.get("ready_after_selection", false)):
			score += 100
		if score > best_score:
			best = hint
			best_score = score
	return best


func _divine_mechanic_line(mutations: Dictionary) -> String:
	if bool(mutations.get("final_burst", false)):
		return "🔥 終結技附加灼燒與最終爆裂"
	if int(mutations.get("finisher_echoes", 0)) > 0:
		return "↻ 終結技額外迴響 %d 次" % int(mutations["finisher_echoes"])
	if bool(mutations.get("death_spread", false)) or mutations.has("poison_damage"):
		return "☠ 終結技附加中毒並可擴散"
	if bool(mutations.get("chain_lightning", false)):
		return "⚡ 終結技觸發連鎖雷擊"
	if bool(mutations.get("piercing", false)):
		return "➤ 終結技可貫穿，速度 ×%.1f" % float(mutations.get("speed_multiplier", 1.0))
	if bool(mutations.get("shatter", false)):
		return "❄ 終結技附加凍結與碎裂"
	return ""


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
	var authored_accent := String(choice.get("accent_color", "")).strip_edges()
	if not authored_accent.is_empty():
		return Color.from_string(authored_accent, Color(0.94, 0.36, 1.0, 1.0))
	var semantic := String(choice.get("card_color", "")).to_lower()
	var card_type := String(choice.get("type", "")).to_lower()
	if semantic == "green" or card_type == "healing":
		return Color(0.35, 0.9, 0.48, 1.0)
	if card_type == "combo":
		return Color(0.68, 0.48, 1.0, 1.0)
	if card_type == "attack":
		return Color(1.0, 0.46, 0.27, 1.0)
	if semantic == "prismatic":
		return Color(0.94, 0.36, 1.0, 1.0)
	if card_type == "divine" or semantic == "gold":
		return Color(1.0, 0.78, 0.24, 1.0)
	return Color(0.36, 0.78, 0.96, 1.0)
