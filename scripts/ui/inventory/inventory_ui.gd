extends Control
class_name InventoryUI

signal opened
signal closed
signal toggled(is_open: bool)
signal category_selected(category: String)
signal item_selected(index: int, item_data: Dictionary)
signal equip_requested(item_id: StringName)

const MODE_INVENTORY := &"bag"
const MODE_STATUS := &"status"
const MODE_SWORD_SOULS := &"sword_souls"
const MODE_CODEX := &"codex"
const LEGACY_MODE_INVENTORY := &"inventory"
const CODEX_VIEW_LIVE := &"live"
const SUPPORTED_ELEMENTS := [
	"water", "fire", "wind", "lightning", "ice", "poison", "light", "dark", "normal",
]
const DEFAULT_ITEM_ICON := preload(
	"res://assets/ui/fantasy_icons_16x16/png/Separately/Icon48_1_2.png"
)
const DEFAULT_SOUL_ICON := preload(
	"res://assets/ui/fantasy_icons_16x16/png/Separately/Icon41_1_2.png"
)

@onready var main_panel: Control = $Center/MainPanel
@onready var gold_label: Label = $Center/MainPanel/Margin/Layout/Header/Gold
@onready var close_button: Button = $Center/MainPanel/Margin/Layout/Header/Close
@onready var inventory_tab: Button = $Center/MainPanel/Margin/Layout/ModeTabs/Inventory
@onready var status_tab: Button = $Center/MainPanel/Margin/Layout/ModeTabs/Status
@onready var sword_souls_tab: Button = $Center/MainPanel/Margin/Layout/ModeTabs/SwordSouls
@onready var codex_tab: Button = $Center/MainPanel/Margin/Layout/ModeTabs/Codex
@onready var inventory_page: HBoxContainer = $Center/MainPanel/Margin/Layout/Pages/InventoryPage
@onready var status_page: HBoxContainer = $Center/MainPanel/Margin/Layout/Pages/StatusPage
@onready var sword_souls_page: HBoxContainer = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage
@onready var codex_page: HBoxContainer = $Center/MainPanel/Margin/Layout/Pages/CodexPage
@onready var item_filter: OptionButton = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Browser/Filter
@onready var item_list: ItemList = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Browser/Items
@onready var item_name: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Name
@onready var item_kind: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Kind
@onready var item_description: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Description
@onready var item_stats: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Stats
@onready var equip_button: Button = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Equip
@onready var status_identity: Label = $Center/MainPanel/Margin/Layout/Pages/StatusPage/Personal/Content/Identity
@onready var status_experience: ProgressBar = $Center/MainPanel/Margin/Layout/Pages/StatusPage/Personal/Content/Experience
@onready var status_experience_text: Label = $Center/MainPanel/Margin/Layout/Pages/StatusPage/Personal/Content/ExperienceText
@onready var status_vitals: Label = $Center/MainPanel/Margin/Layout/Pages/StatusPage/Personal/Content/Vitals
@onready var soul_list: ItemList = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Browser/Entries
@onready var soul_icon: TextureRect = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Icon
@onready var soul_name: Label = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Name
@onready var soul_kind: Label = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Kind
@onready var soul_bonus_type: Label = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/BonusType
@onready var soul_meta: Label = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Meta
@onready var soul_description: Label = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Description
@onready var soul_effect: Label = $Center/MainPanel/Margin/Layout/Pages/SwordSoulsPage/Details/Content/Effect
@onready var codex_filter: OptionButton = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Filter
@onready var codex_list: ItemList = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Entries
@onready var live_vfx_button: Button = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/ViewTabs/LiveVFX
@onready var concept_art_button: Button = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/ViewTabs/ConceptArt
@onready var preview: Control = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Preview
@onready var concept_view: TextureRect = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/ConceptView
@onready var static_icon: TextureRect = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/StaticIcon
@onready var codex_scroll: ScrollContainer = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll
@onready var codex_content: VBoxContainer = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content
@onready var codex_top_inset: Control = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/TopInset
@onready var codex_name: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Name
@onready var codex_kind: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Kind
@onready var codex_meta: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Meta
@onready var codex_growth: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Growth
@onready var codex_description: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Description
@onready var codex_effect: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Effect
@onready var codex_trigger: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll/Content/Trigger

var items: Array[Dictionary] = []
var codex_entries: Array[Dictionary] = []
var equipment_entries: Array[Dictionary] = []
var sword_souls: Array[Dictionary] = []
var player_status: Dictionary = {}
var current_category := "all"
var current_mode := MODE_INVENTORY
var selected_index := -1
var _visible_items: Array[Dictionary] = []
var _visible_codex: Array[Dictionary] = []
var _codex_view_mode := CODEX_VIEW_LIVE
var _active_codex_section := "techniques"
var _active_concept_region := Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	inventory_tab.pressed.connect(set_mode.bind(MODE_INVENTORY))
	status_tab.pressed.connect(set_mode.bind(MODE_STATUS))
	sword_souls_tab.pressed.connect(set_mode.bind(MODE_SWORD_SOULS))
	codex_tab.pressed.connect(set_mode.bind(MODE_CODEX))
	item_filter.item_selected.connect(_on_item_filter_selected)
	codex_filter.item_selected.connect(_on_codex_filter_selected)
	item_list.item_selected.connect(_on_item_selected)
	equip_button.pressed.connect(_request_selected_equipment)
	soul_list.item_selected.connect(_on_soul_selected)
	codex_list.item_selected.connect(_on_codex_selected)
	live_vfx_button.pressed.connect(set_codex_view_mode.bind(CODEX_VIEW_LIVE))
	concept_art_button.get_parent().visible = false
	concept_view.visible = false
	codex_scroll.resized.connect(_schedule_codex_detail_alignment)
	codex_content.resized.connect(_schedule_codex_detail_alignment)
	_populate_filters()
	set_mode(MODE_INVENTORY)
	set_codex_view_mode(CODEX_VIEW_LIVE)
	resized.connect(_update_journal_scale)
	($Center as Control).resized.connect(_update_journal_scale)
	call_deferred("_update_journal_scale")
	_set_open(false, false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_set_open(true, true)


func close() -> void:
	_set_open(false, true)


func toggle() -> void:
	_set_open(not visible, true)


func set_gold(amount: int) -> void:
	gold_label.text = "%s G" % _format_number(maxi(0, amount))


func set_items(new_items: Array) -> void:
	items = _to_dictionary_array(new_items)
	_refresh_item_list()


func set_player_status(status: Dictionary) -> void:
	player_status = status.duplicate(true)
	if not is_node_ready():
		return
	var level := maxi(1, int(status.get("level", 1)))
	var character_class: String = String({
		"Adventurer": "冒險者",
		"Sword Adept": "劍術行者",
	}.get(String(status.get("character_class", "Adventurer")), "冒險者"))
	status_identity.text = "%s  ·  等級 %d" % [character_class, level]
	var experience := maxi(0, int(status.get("experience", 0)))
	var required := maxi(1, int(status.get("experience_required", 1)))
	status_experience.max_value = required
	status_experience.value = mini(experience, required)
	status_experience_text.text = "EXP  %s / %s" % [_format_number(experience), _format_number(required)]
	status_vitals.text = "\n".join(PackedStringArray([
		"生命       %s / %s" % [_format_number(int(status.get("health", 0))), _format_number(int(status.get("max_health", 0)))],
		"法力       %s / %s" % [_format_number(int(status.get("mana", 0))), _format_number(int(status.get("max_mana", 0)))],
		"攻擊       %s" % _format_number(int(status.get("attack", 0))),
		"防禦       %s" % _format_number(int(status.get("defense", 0))),
		"速度       %s" % _format_number(roundi(float(status.get("speed", 0.0)))),
	]))


func set_equipment_entries(entries: Array) -> void:
	equipment_entries = _to_dictionary_array(entries)
	if is_node_ready():
		_refresh_equipment_slots()


func set_sword_souls(entries: Array) -> void:
	sword_souls = _to_dictionary_array(entries)
	if is_node_ready():
		_refresh_soul_list()


func set_codex_entries(entries: Array) -> void:
	codex_entries = _to_dictionary_array(entries)
	_refresh_codex_list()


func set_mode(mode: StringName) -> void:
	match mode:
		MODE_STATUS:
			current_mode = MODE_STATUS
		MODE_SWORD_SOULS:
			current_mode = MODE_SWORD_SOULS
		MODE_CODEX:
			current_mode = MODE_CODEX
		MODE_INVENTORY, LEGACY_MODE_INVENTORY:
			current_mode = MODE_INVENTORY
		_:
			current_mode = MODE_INVENTORY
	inventory_page.visible = current_mode == MODE_INVENTORY
	status_page.visible = current_mode == MODE_STATUS
	sword_souls_page.visible = current_mode == MODE_SWORD_SOULS
	codex_page.visible = current_mode == MODE_CODEX
	inventory_tab.button_pressed = current_mode == MODE_INVENTORY
	status_tab.button_pressed = current_mode == MODE_STATUS
	sword_souls_tab.button_pressed = current_mode == MODE_SWORD_SOULS
	codex_tab.button_pressed = current_mode == MODE_CODEX
	if visible:
		_focus_current_page()


func set_category(category: String) -> void:
	current_category = category.to_lower()
	var filter_index := 0
	for index in item_filter.item_count:
		if String(item_filter.get_item_metadata(index)) == current_category:
			filter_index = index
			break
	item_filter.select(filter_index)
	_refresh_item_list()
	category_selected.emit(current_category)


func select_codex_entry(entry_id: String) -> void:
	for index in _visible_codex.size():
		if String(_visible_codex[index].get("id", "")) == entry_id:
			codex_list.select(index)
			call_deferred("_ensure_codex_selection_visible", index)
			_on_codex_selected(index)
			return


func _ensure_codex_selection_visible(index: int) -> void:
	if index < 0 or index >= codex_list.item_count:
		return
	codex_list.ensure_current_is_visible()
	var scroll_bar := codex_list.get_v_scroll_bar()
	var item_rect := codex_list.get_item_rect(index)
	var visible_top := scroll_bar.value
	var visible_bottom := visible_top + codex_list.size.y
	if item_rect.end.y > visible_bottom:
		scroll_bar.value = item_rect.end.y - codex_list.size.y + 8.0
	elif item_rect.position.y < visible_top:
		scroll_bar.value = maxf(0.0, item_rect.position.y - 8.0)


func get_mode() -> StringName:
	return current_mode


func get_active_page_count() -> int:
	var count := 0
	for page in [inventory_page, status_page, sword_souls_page, codex_page]:
		count += int(page.visible)
	return count


func get_visible_item_count() -> int:
	return _visible_items.size()


func get_visible_codex_count() -> int:
	return _visible_codex.size()


func get_selected_codex_id() -> String:
	var selected := codex_list.get_selected_items()
	if selected.is_empty() or selected[0] >= _visible_codex.size():
		return ""
	return String(_visible_codex[selected[0]].get("id", ""))


func set_codex_view_mode(_mode: StringName) -> void:
	var is_technique := _active_codex_section == "techniques"
	_codex_view_mode = CODEX_VIEW_LIVE
	live_vfx_button.disabled = not is_technique
	concept_art_button.disabled = true
	concept_art_button.get_parent().visible = false
	static_icon.visible = not is_technique
	preview.visible = is_technique
	concept_view.visible = false
	live_vfx_button.button_pressed = is_technique
	concept_art_button.button_pressed = false


func get_codex_view_mode() -> StringName:
	return _codex_view_mode


func get_active_concept_region() -> Rect2:
	return _active_concept_region


func _populate_filters() -> void:
	item_filter.clear()
	codex_filter.clear()
	for entry in [
		["全部 All", "all"],
		["素材 Materials", "materials"],
		["關鍵道具 Key Items", "quest"],
		["裝備 Equipment", "gear"],
		["消耗品 Supplies", "items"],
	]:
		item_filter.add_item(entry[0])
		item_filter.set_item_metadata(item_filter.item_count - 1, entry[1])
	for entry in [
		["招式 Techniques", "techniques"],
		["敵人 Enemies", "enemies"],
		["劍魂 Sword Souls", "sword_souls"],
		["裝備 Equipment", "equipment"],
	]:
		codex_filter.add_item(entry[0])
		codex_filter.set_item_metadata(codex_filter.item_count - 1, entry[1])


func _on_item_filter_selected(index: int) -> void:
	current_category = String(item_filter.get_item_metadata(index))
	_refresh_item_list()
	category_selected.emit(current_category)


func _on_codex_filter_selected(_index: int) -> void:
	_refresh_codex_list()


func _refresh_item_list() -> void:
	if not is_node_ready():
		return
	item_list.clear()
	_visible_items.clear()
	for item in items:
		if current_category != "all" and String(item.get("category", "items")) != current_category:
			continue
		_visible_items.append(item)
		var quantity := int(item.get("quantity", 0))
		var suffix := "  ×%s" % _format_number(quantity) if quantity > 0 else ""
		item_list.add_item("%s%s" % [String(item.get("name", "未知物品")), suffix], _load_icon(item, DEFAULT_ITEM_ICON))
	if _visible_items.is_empty():
		_clear_item_details()
	else:
		item_list.select(0)
		_on_item_selected(0)


func _refresh_equipment_slots() -> void:
	var by_slot: Dictionary = {}
	for entry in equipment_entries:
		by_slot[String(entry.get("slot", ""))] = entry
	var slot_labels := {
		"weapon": "武器",
		"armor": "防具",
		"accessory": "飾品",
	}
	for slot in ["weapon", "armor", "accessory"]:
		var panel_name: String = String(slot).capitalize()
		var panel := status_page.get_node("Equipment/%s" % panel_name)
		var name_label := panel.get_node("Row/Text/Name") as Label
		var stats_label := panel.get_node("Row/Text/Stats") as Label
		var icon_rect := panel.get_node("Row/Icon") as TextureRect
		var entry := by_slot.get(slot, {}) as Dictionary
		var slot_label := String(slot_labels.get(slot, "裝備"))
		if entry.is_empty() or String(entry.get("id", "")).is_empty():
			name_label.text = "%s  ·  未裝備" % slot_label
			stats_label.text = "此欄位目前沒有裝備。"
			continue
		name_label.text = "%s  ·  %s  ·  等級 %d" % [
			slot_label,
			String(entry.get("name", "未知裝備")),
			int(entry.get("level", 1)),
		]
		stats_label.text = String(entry.get("stats", entry.get("description", "")))
		var loaded := _load_icon(entry, null)
		if loaded != null:
			icon_rect.texture = loaded


func _refresh_soul_list() -> void:
	soul_list.clear()
	for soul in sword_souls:
		var row_index := soul_list.add_item(
			"[%s] %s" % [
				String(soul.get("bonus_type_label", "攻擊")),
				String(soul.get("name", "未知劍魂")),
			],
			_load_icon(soul, DEFAULT_SOUL_ICON)
		)
		soul_list.set_item_tooltip(
			row_index,
			"%s · 等級 %d\n%s" % [
				String(soul.get("name", "未知劍魂")),
				int(soul.get("level", 1)),
				String(soul.get("ability_summary", soul.get("effect_summary", ""))),
			]
		)
	if sword_souls.is_empty():
		_clear_soul_details()
	else:
		soul_list.select(0)
		_on_soul_selected(0)


func _refresh_codex_list() -> void:
	if not is_node_ready():
		return
	codex_list.clear()
	_visible_codex.clear()
	var section := String(codex_filter.get_item_metadata(codex_filter.selected)) if codex_filter.item_count > 0 else "techniques"
	for entry in codex_entries:
		var entry_section := String(entry.get("section", "techniques"))
		if entry_section != section:
			continue
		_visible_codex.append(entry)
		codex_list.add_item(String(entry.get("name", "未知紀錄")), _load_icon(entry, DEFAULT_ITEM_ICON))
	if _visible_codex.is_empty():
		_clear_codex_details()
	else:
		codex_list.select(0)
		_on_codex_selected(0)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _visible_items.size():
		return
	selected_index = items.find(_visible_items[index])
	var item := _visible_items[index]
	item_name.text = String(item.get("name", "未知物品"))
	item_kind.text = String(item.get("kind_label", "旅途物品"))
	item_description.text = String(item.get("description", "尚無說明。"))
	item_stats.text = String(item.get("stats", ""))
	var is_equipment := String(item.get("category", "")) == "gear" and not String(item.get("id", "")).is_empty()
	equip_button.visible = is_equipment
	equip_button.disabled = bool(item.get("equipped", false))
	equip_button.text = "已裝備 · EQUIPPED" if equip_button.disabled else "裝備 · EQUIP"
	item_selected.emit(selected_index, item)


func _request_selected_equipment() -> void:
	if selected_index < 0 or selected_index >= items.size():
		return
	var item := items[selected_index]
	var item_id := StringName(item.get("id", ""))
	if String(item.get("category", "")) != "gear" or item_id.is_empty():
		return
	equip_requested.emit(item_id)


func _on_soul_selected(index: int) -> void:
	if index < 0 or index >= sword_souls.size():
		return
	var soul := sword_souls[index]
	soul_icon.texture = _load_icon(soul, DEFAULT_SOUL_ICON)
	soul_name.text = String(soul.get("name", "未知劍魂"))
	soul_kind.text = String(soul.get("kind_label", "現有劍魂"))
	soul_bonus_type.text = "加乘類型 · %s" % String(soul.get("bonus_type_label", "攻擊"))
	soul_meta.text = "等級 %d / 3  ·  印記 %s" % [
		int(soul.get("level", 1)),
		String(soul.get("instance_id", "")).right(8).to_upper(),
	]
	soul_description.text = String(soul.get("description", "尚無說明。"))
	soul_effect.text = "能力札記\n%s" % String(
		soul.get("ability_summary", soul.get("effect_summary", "依劍魂等級提供戰鬥加乘。"))
	)


func _on_codex_selected(index: int) -> void:
	if index < 0 or index >= _visible_codex.size():
		return
	var entry := _visible_codex[index]
	_active_codex_section = String(entry.get("section", "techniques"))
	codex_name.text = String(entry.get("name", "未知紀錄"))
	codex_kind.text = String(entry.get("kind_label", "旅途紀錄"))
	codex_description.text = String(entry.get("description", "尚無說明。"))
	codex_effect.text = "效果\n%s" % String(entry.get("effect_summary", "尚無效果資料。"))
	codex_trigger.text = "說明\n%s" % String(entry.get("trigger_summary", "已記錄於旅途日誌。"))
	if _active_codex_section == "techniques":
		codex_meta.text = _format_codex_meta(entry)
		codex_growth.text = _format_codex_growth(entry)
		concept_view.texture = null
		_active_concept_region = Rect2()
		preview.call("show_entry", entry)
	else:
		codex_meta.text = String(entry.get("meta_summary", ""))
		codex_growth.text = String(entry.get("growth_summary", ""))
		concept_view.texture = null
		_active_concept_region = Rect2()
		preview.call("show_entry", {})
		static_icon.texture = _load_icon(entry, DEFAULT_ITEM_ICON)
	set_codex_view_mode(_codex_view_mode)
	codex_scroll.scroll_vertical = 0
	call_deferred("_schedule_codex_detail_alignment")


func _schedule_codex_detail_alignment() -> void:
	call_deferred("_align_codex_detail_lines")


func _align_codex_detail_lines() -> void:
	if not is_instance_valid(codex_scroll) or codex_content.size.y <= codex_scroll.size.y:
		return
	var visible_bottom := codex_scroll.size.y
	for child_variant in codex_content.get_children():
		var label := child_variant as Label
		if label == null or label.size.y <= 0.0:
			continue
		var label_top := label.position.y
		var label_bottom := label_top + label.size.y
		if label_top >= visible_bottom or label_bottom <= visible_bottom:
			continue
		var line_count := maxi(1, label.get_line_count())
		var line_height := label.size.y / float(line_count)
		var remainder := fposmod(visible_bottom - label_top, line_height)
		if remainder <= 1.0 or line_height - remainder <= 1.0:
			return
		var alignment_scroll := ceili(line_height - remainder)
		codex_scroll.scroll_vertical = mini(alignment_scroll, roundi(codex_top_inset.size.y))
		return


func _clear_item_details() -> void:
	item_name.text = "尚無物品"
	item_kind.text = "此頁目前沒有可查看的內容。"
	item_description.text = ""
	item_stats.text = ""
	equip_button.visible = false


func _clear_soul_details() -> void:
	soul_icon.texture = DEFAULT_SOUL_ICON
	soul_name.text = "尚無劍魂"
	soul_kind.text = "鍛造或發現劍魂後，會記錄於此。"
	soul_bonus_type.text = "加乘類型 · 未知"
	soul_meta.text = ""
	soul_description.text = ""
	soul_effect.text = ""


func _clear_codex_details() -> void:
	_active_codex_section = "techniques"
	codex_name.text = "尚無紀錄"
	codex_kind.text = "此章目前沒有可查閱的內容。"
	codex_meta.text = ""
	codex_growth.text = ""
	codex_description.text = ""
	codex_effect.text = ""
	codex_trigger.text = ""
	concept_view.texture = null
	static_icon.texture = DEFAULT_ITEM_ICON
	_active_concept_region = Rect2()
	preview.call("show_entry", {})
	set_codex_view_mode(CODEX_VIEW_LIVE)


func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if is_open:
		_focus_current_page()
	if should_emit:
		(opened if is_open else closed).emit()
		toggled.emit(is_open)


func _focus_current_page() -> void:
	match current_mode:
		MODE_INVENTORY:
			item_list.grab_focus()
		MODE_STATUS:
			status_tab.grab_focus()
		MODE_SWORD_SOULS:
			(soul_list if soul_list.item_count > 0 else sword_souls_tab).grab_focus()
		MODE_CODEX:
			(codex_list if codex_list.item_count > 0 else codex_tab).grab_focus()


func _update_journal_scale() -> void:
	if not is_node_ready() or main_panel.size.x <= 0.0 or main_panel.size.y <= 0.0:
		return
	var available := ($Center as Control).size
	var fit_scale := minf(available.x / main_panel.size.x, available.y / main_panel.size.y)
	var quarter_step_scale := floorf(fit_scale * 4.0) / 4.0
	var resolved_scale := clampf(quarter_step_scale, 1.0, 2.0)
	main_panel.scale = Vector2(resolved_scale, resolved_scale)


func _load_icon(entry: Dictionary, fallback: Texture2D) -> Texture2D:
	var path := String(entry.get("icon_path", ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else fallback


func _to_dictionary_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _format_codex_meta(entry: Dictionary) -> String:
	if String(entry.get("catalog_kind", "")) == "skill_series":
		return "系列  %s   ·   階級 %s   ·   元素 %s" % [
			String(entry.get("skill_series_name", "未分類")),
			String(entry.get("tier_label", "基礎")),
			_element_display_name(_entry_element(entry)),
		]
	var level := clampi(int(entry.get("level", entry.get("card_level", 1))), 1, 3)
	var stacks := maxi(0, int(entry.get("combo_stack", entry.get("buff_stacks", 0))))
	return "屬性  %s   ·   等級 %d/3   ·   增益 ×%d" % [
		_element_display_name(_entry_element(entry)),
		level,
		stacks,
	]


func _format_codex_growth(entry: Dictionary) -> String:
	if String(entry.get("catalog_kind", "")) == "skill_series":
		var elements := PackedStringArray()
		for identity_variant in entry.get("identity_elements", []) as Array:
			elements.append(String(identity_variant))
		return "系列語彙  %s\n特效狀態  暫用既有動畫" % " · ".join(elements)
	var level := clampi(int(entry.get("level", entry.get("card_level", 1))), 1, 3)
	var stacks := maxi(0, int(entry.get("combo_stack", entry.get("buff_stacks", 0))))
	var layers := entry.get("evolution_layers", []) as Array
	var active_layer := (
		_display_trait(String(layers[mini(level - 1, layers.size() - 1)]))
		if not layers.is_empty()
		else "基礎招式"
	)
	var growth_lines := PackedStringArray(["進化  %s" % active_layer])
	var milestones := entry.get("stack_milestones", []) as Array
	var traits := entry.get("stack_traits", []) as Array
	for index in mini(milestones.size(), traits.size()):
		var milestone := int(milestones[index])
		if milestone > stacks:
			growth_lines.append(
				"下一層  ×%d — %s" % [
					milestone,
					_display_trait(String(traits[index])),
				]
			)
			break
	return "\n".join(growth_lines)


func _entry_element(entry: Dictionary) -> String:
	var element := String(entry.get("element", "")).to_lower()
	if element.is_empty():
		var elements := entry.get("elements", []) as Array
		if not elements.is_empty():
			element = String(elements[0]).to_lower()
	if element == "flame":
		element = "fire"
	return element if SUPPORTED_ELEMENTS.has(element) else "normal"


func _element_display_name(element: String) -> String:
	return {
		"water": "水",
		"fire": "火",
		"wind": "風",
		"lightning": "雷",
		"ice": "冰",
		"poison": "毒",
		"light": "光",
		"dark": "暗",
		"normal": "普通",
	}.get(element, "普通")


func _display_trait(raw_trait: String) -> String:
	return raw_trait.replace("_", " ").capitalize()


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result
