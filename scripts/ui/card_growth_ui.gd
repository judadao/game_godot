class_name CardGrowthUI
extends Control

signal choice_confirmed(action: Dictionary)
signal close_requested

const PAGES := ["new_card", "upgrade", "fusion", "reward"]
const EMPTY_REASONS := {
	"new_card": "No new cards are available for this blessing.",
	"upgrade": "No cards can be upgraded right now.",
	"fusion": "No full fusion pairs are available right now.",
	"reward": "No fallback rewards are available right now.",
}

@onready var source_title: Label = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/SourceTitle
@onready var new_card_tab: Button = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/NewCardTab
@onready var upgrade_tab: Button = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/UpgradeTab
@onready var fusion_tab: Button = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/FusionTab
@onready var reward_tab: Button = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/PageTabs/RewardTab
@onready var option_grid: GridContainer = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/OptionScroll/OptionGrid
@onready var empty_reason: Label = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/OptionPanel/OptionLayout/EmptyReason
@onready var detail_title: Label = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/DetailPanel/DetailLayout/DetailTitle
@onready var detail_text: RichTextLabel = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/Content/DetailPanel/DetailLayout/DetailText
@onready var confirm_button: Button = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/ActionBar/ConfirmButton
@onready var cancel_button: Button = $CenterContainer/GrowthModal/ModalMargin/ModalLayout/ActionBar/CancelButton

var _entry: Dictionary = {}
var _active_page := ""
var _options: Array[Dictionary] = []
var _selected_index := -1
var _option_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	new_card_tab.pressed.connect(_show_page.bind("new_card"))
	upgrade_tab.pressed.connect(_show_page.bind("upgrade"))
	fusion_tab.pressed.connect(_show_page.bind("fusion"))
	reward_tab.pressed.connect(_show_page.bind("reward"))
	confirm_button.pressed.connect(confirm_selection)
	cancel_button.pressed.connect(request_close)
	_configure_tab_navigation()
	_refresh()


func set_growth_entry(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_active_page = _first_allowed_page()
	_selected_index = -1
	visible = not _entry.is_empty()
	_refresh()
	if visible:
		call_deferred("_focus_active_tab")


func open_entry(entry: Dictionary) -> void:
	set_growth_entry(entry)


func clear_entry() -> void:
	_entry.clear()
	_active_page = ""
	_selected_index = -1
	visible = false
	_refresh()


func select_option(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	_selected_index = index
	_refresh_option_buttons()
	_refresh_detail()
	confirm_button.disabled = false
	if index < _option_buttons.size():
		_option_buttons[index].grab_focus()


func confirm_selection() -> void:
	if _active_page.is_empty() or _selected_index < 0 or _selected_index >= _options.size():
		return
	var action := _options[_selected_index].duplicate(true)
	action["page"] = _active_page
	action["kind"] = _active_page
	choice_confirmed.emit(action)


func request_close() -> void:
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		request_close()


func _show_page(page: String) -> void:
	if not _allowed_pages().has(page):
		return
	_active_page = page
	_selected_index = -1
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	source_title.text = _source_title()
	var allowed := _allowed_pages()
	new_card_tab.visible = allowed.has("new_card")
	upgrade_tab.visible = allowed.has("upgrade")
	fusion_tab.visible = allowed.has("fusion")
	reward_tab.visible = allowed.has("reward")
	new_card_tab.disabled = _active_page == "new_card"
	upgrade_tab.disabled = _active_page == "upgrade"
	fusion_tab.disabled = _active_page == "fusion"
	reward_tab.disabled = _active_page == "reward"
	_options = _options_for_page(_active_page)
	_rebuild_option_buttons()
	empty_reason.visible = _options.is_empty()
	empty_reason.text = String(EMPTY_REASONS.get(_active_page, "No options are available for this choice."))
	confirm_button.disabled = _selected_index < 0 or _selected_index >= _options.size()
	_refresh_detail()
	_configure_tab_navigation()


func _allowed_pages() -> Array[String]:
	var pages: Array[String] = []
	var raw_pages: Variant = _entry.get("allowed_pages", [])
	if not raw_pages is Array:
		return pages
	for raw_page in raw_pages as Array:
		var page := String(raw_page).strip_edges().to_lower()
		if PAGES.has(page) and not pages.has(page):
			pages.append(page)
	return pages


func _first_allowed_page() -> String:
	var pages := _allowed_pages()
	return pages[0] if not pages.is_empty() else ""


func _options_for_page(page: String) -> Array[Dictionary]:
	var payload: Variant = _entry.get("payload", {})
	if not payload is Dictionary:
		return []
	var keys := {
		"new_card": ["card_options", "new_card_options"],
		"upgrade": ["upgrade_options", "upgrades"],
		"fusion": ["fusion_options", "fusion_recipes"],
		"reward": ["fallback_rewards", "reward_options"],
	}
	for key in keys.get(page, []) as Array:
		var raw_options: Variant = (payload as Dictionary).get(key, [])
		if raw_options is Array:
			return _dictionary_array(raw_options as Array)
	return []


func _dictionary_array(raw_options: Array) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for raw_option in raw_options:
		if raw_option is Dictionary:
			options.append((raw_option as Dictionary).duplicate(true))
	return options


func _rebuild_option_buttons() -> void:
	for button in _option_buttons:
		button.queue_free()
	_option_buttons.clear()
	for index in _options.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 58)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = _option_tooltip(_options[index])
		button.pressed.connect(select_option.bind(index))
		option_grid.add_child(button)
		_option_buttons.append(button)
	_refresh_option_buttons()
	_configure_option_navigation()


func _refresh_option_buttons() -> void:
	for index in _option_buttons.size():
		var button := _option_buttons[index]
		button.text = _option_label(_options[index])
		button.button_pressed = index == _selected_index


func _refresh_detail() -> void:
	if _options.is_empty():
		detail_title.text = "Choose a Growth Path"
		detail_text.text = "No valid option is available on this page. Choose another visible page when one is offered."
		return
	var preview_index := _selected_index if _selected_index >= 0 else 0
	var option := _options[preview_index]
	detail_title.text = _option_name(option)
	var before := String(option.get("before", _default_before(option)))
	var after := String(option.get("after", _default_after(option)))
	var description := String(option.get("description", ""))
	var level_comparison := ""
	if _active_page == "upgrade":
		var level := int(option.get("level", 1))
		level_comparison = "Lv. %d → Lv. %d\n\n" % [level, level + 1]
	detail_text.text = "%s%s\n\n%s\n→ %s%s" % [
		level_comparison,
		description,
		before,
		after,
		"\n\nSelected — confirm to continue." if _selected_index >= 0 else "\n\nPreview — select this option to confirm.",
	]


func _option_label(option: Dictionary) -> String:
	var label := _option_name(option)
	if _active_page == "upgrade":
		label += "  •  #%s  •  LV. %d" % [str(option.get("instance_id", "?")), int(option.get("level", 1))]
	elif _active_page == "fusion":
		label += "  •  Full Fusion"
	elif _active_page == "reward":
		var amount := int(option.get("amount", 0))
		if amount > 0:
			label += "  •  x%d" % amount
	return label


func _option_tooltip(option: Dictionary) -> String:
	return "%s\n%s\n→ %s" % [_option_name(option), _default_before(option), _default_after(option)]


func _option_name(option: Dictionary) -> String:
	for key in ["name", "display_name", "card_name", "card_id", "recipe_id", "resource_id"]:
		var value := String(option.get(key, "")).strip_edges()
		if not value.is_empty():
			return value.replace("_", " ").capitalize()
	return "Growth Option"


func _default_before(option: Dictionary) -> String:
	if _active_page == "upgrade":
		return "Lv. %d" % int(option.get("level", 1))
	return "Current choice"


func _default_after(option: Dictionary) -> String:
	if _active_page == "upgrade":
		return "Lv. %d" % (int(option.get("level", 1)) + 1)
	return "Applied on confirmation"


func _source_title() -> String:
	var source := String(_entry.get("source", "")).strip_edges().to_lower()
	if source == "exp_level":
		return "EXP LEVEL"
	if source == "wave_blessing":
		return "WAVE BLESSING"
	return "CARD GROWTH"


func _configure_tab_navigation() -> void:
	var visible_tabs: Array[Button] = []
	for tab in [new_card_tab, upgrade_tab, fusion_tab, reward_tab]:
		if tab.visible:
			visible_tabs.append(tab)
	for index in visible_tabs.size():
		var tab := visible_tabs[index]
		tab.focus_neighbor_left = tab.get_path_to(visible_tabs[(index - 1 + visible_tabs.size()) % visible_tabs.size()])
		tab.focus_neighbor_right = tab.get_path_to(visible_tabs[(index + 1) % visible_tabs.size()])
		if not _option_buttons.is_empty():
			tab.focus_neighbor_bottom = tab.get_path_to(_option_buttons[0])


func _configure_option_navigation() -> void:
	for index in _option_buttons.size():
		var button := _option_buttons[index]
		button.focus_neighbor_top = button.get_path_to(_option_buttons[index - 1] if index > 0 else _active_tab())
		button.focus_neighbor_bottom = button.get_path_to(_option_buttons[index + 1] if index + 1 < _option_buttons.size() else confirm_button)
		button.focus_neighbor_right = button.get_path_to(confirm_button)
	confirm_button.focus_neighbor_left = confirm_button.get_path_to(_option_buttons.back()) if not _option_buttons.is_empty() else NodePath()
	confirm_button.focus_neighbor_right = confirm_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(confirm_button)


func _active_tab() -> Button:
	match _active_page:
		"new_card": return new_card_tab
		"upgrade": return upgrade_tab
		"fusion": return fusion_tab
		"reward": return reward_tab
	return new_card_tab


func _focus_active_tab() -> void:
	if _active_tab().visible:
		_active_tab().grab_focus()
