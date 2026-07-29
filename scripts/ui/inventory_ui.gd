extends Control
class_name InventoryUI

signal opened
signal closed
signal toggled(is_open: bool)
signal category_selected(category: String)
signal item_selected(index: int, item_data: Dictionary)

const MODE_INVENTORY := &"inventory"
const MODE_CODEX := &"codex"

@onready var main_panel: PanelContainer = $Center/MainPanel
@onready var gold_label: Label = $Center/MainPanel/Margin/Layout/Header/Gold
@onready var close_button: Button = $Center/MainPanel/Margin/Layout/Header/Close
@onready var inventory_tab: Button = $Center/MainPanel/Margin/Layout/ModeTabs/Inventory
@onready var codex_tab: Button = $Center/MainPanel/Margin/Layout/ModeTabs/Codex
@onready var inventory_page: HBoxContainer = $Center/MainPanel/Margin/Layout/Pages/InventoryPage
@onready var codex_page: HBoxContainer = $Center/MainPanel/Margin/Layout/Pages/CodexPage
@onready var item_filter: OptionButton = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Browser/Filter
@onready var item_list: ItemList = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Browser/Items
@onready var item_name: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Name
@onready var item_kind: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Kind
@onready var item_description: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Description
@onready var item_stats: Label = $Center/MainPanel/Margin/Layout/Pages/InventoryPage/Details/Content/Stats
@onready var codex_filter: OptionButton = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Filter
@onready var codex_list: ItemList = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Entries
@onready var preview: Control = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Preview
@onready var codex_name: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/Content/Name
@onready var codex_kind: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/Content/Kind
@onready var codex_description: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/Content/Description
@onready var codex_effect: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/Content/Effect
@onready var codex_trigger: Label = $Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Info/Content/Trigger

var items: Array[Dictionary] = []
var codex_entries: Array[Dictionary] = []
var current_category := "all"
var current_mode := MODE_INVENTORY
var selected_index := -1
var _visible_items: Array[Dictionary] = []
var _visible_codex: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	inventory_tab.pressed.connect(set_mode.bind(MODE_INVENTORY))
	codex_tab.pressed.connect(set_mode.bind(MODE_CODEX))
	item_filter.item_selected.connect(_on_item_filter_selected)
	codex_filter.item_selected.connect(_on_codex_filter_selected)
	item_list.item_selected.connect(_on_item_selected)
	codex_list.item_selected.connect(_on_codex_selected)
	_populate_filters()
	set_mode(MODE_INVENTORY)
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


func set_codex_entries(entries: Array) -> void:
	codex_entries = _to_dictionary_array(entries)
	_refresh_codex_list()


func set_mode(mode: StringName) -> void:
	current_mode = MODE_CODEX if mode == MODE_CODEX else MODE_INVENTORY
	inventory_page.visible = current_mode == MODE_INVENTORY
	codex_page.visible = current_mode == MODE_CODEX
	inventory_tab.button_pressed = current_mode == MODE_INVENTORY
	codex_tab.button_pressed = current_mode == MODE_CODEX
	if visible:
		(codex_list if current_mode == MODE_CODEX else item_list).grab_focus()


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
			_on_codex_selected(index)
			return


func get_mode() -> StringName:
	return current_mode


func get_visible_item_count() -> int:
	return _visible_items.size()


func get_visible_codex_count() -> int:
	return _visible_codex.size()


func get_selected_codex_id() -> String:
	return preview.call("get_active_entry_id") if preview.has_method("get_active_entry_id") else ""


func _populate_filters() -> void:
	for entry in [["All items", "all"], ["Materials", "materials"], ["Equipment", "gear"], ["Consumables", "items"], ["Quest", "quest"]]:
		item_filter.add_item(entry[0])
		item_filter.set_item_metadata(item_filter.item_count - 1, entry[1])
	for entry in [["All discoveries", "all"], ["Basic attacks", "attacks"], ["Skills", "skills"], ["Attack infusions", "infusions"], ["Finishers", "finishers"]]:
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
		var suffix := "  x%s" % _format_number(quantity) if quantity > 0 else ""
		item_list.add_item("%s%s" % [String(item.get("name", "Unknown")), suffix], _load_icon(item))
	if _visible_items.is_empty():
		_clear_item_details()
	else:
		item_list.select(0)
		_on_item_selected(0)


func _refresh_codex_list() -> void:
	if not is_node_ready():
		return
	codex_list.clear()
	_visible_codex.clear()
	var category := String(codex_filter.get_item_metadata(codex_filter.selected)) if codex_filter.item_count > 0 else "all"
	for entry in codex_entries:
		if category != "all" and String(entry.get("category", "")) != category:
			continue
		_visible_codex.append(entry)
		codex_list.add_item(String(entry.get("name", "Unknown discovery")), _load_icon(entry))
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
	item_name.text = String(item.get("name", "Unknown item"))
	item_kind.text = String(item.get("kind_label", String(item.get("category", "item")).capitalize()))
	item_description.text = String(item.get("description", "No description available."))
	item_stats.text = String(item.get("stats", ""))
	item_selected.emit(selected_index, item)


func _on_codex_selected(index: int) -> void:
	if index < 0 or index >= _visible_codex.size():
		return
	var entry := _visible_codex[index]
	codex_name.text = String(entry.get("name", "Unknown discovery"))
	codex_kind.text = String(entry.get("kind_label", "Discovered technique"))
	codex_description.text = String(entry.get("description", "No description available."))
	codex_effect.text = "EFFECT\n%s" % String(entry.get("effect_summary", "No effect data."))
	codex_trigger.text = "ACTIVATION\n%s" % String(entry.get("trigger_summary", "Triggered when played."))
	preview.call("show_entry", entry)


func _clear_item_details() -> void:
	item_name.text = "No items"
	item_kind.text = "Your carried inventory is empty."
	item_description.text = ""
	item_stats.text = ""


func _clear_codex_details() -> void:
	codex_name.text = "No discoveries"
	codex_kind.text = "Explore and learn techniques to reveal them here."
	codex_description.text = ""
	codex_effect.text = ""
	codex_trigger.text = ""
	preview.call("show_entry", {})


func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if is_open:
		(codex_list if current_mode == MODE_CODEX else item_list).grab_focus()
	if should_emit:
		(opened if is_open else closed).emit()
		toggled.emit(is_open)


func _load_icon(entry: Dictionary) -> Texture2D:
	var path := String(entry.get("icon_path", ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _to_dictionary_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result
