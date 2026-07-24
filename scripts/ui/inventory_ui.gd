extends Control
class_name InventoryUI

signal opened
signal closed
signal toggled(is_open: bool)
signal category_selected(category: String)
signal item_selected(index: int, item_data: Dictionary)

const SLOT_GRID_PATH := "MainPanel/MainMargin/MainLayout/ContentRow/InventoryColumn/SlotGrid"
const CATEGORY_PATHS: Dictionary = {
	"all": "MainPanel/MainMargin/MainLayout/ContentRow/InventoryColumn/CategoryTabs/AllTab",
	"items": "MainPanel/MainMargin/MainLayout/ContentRow/InventoryColumn/CategoryTabs/ItemsTab",
	"gear": "MainPanel/MainMargin/MainLayout/ContentRow/InventoryColumn/CategoryTabs/GearTab",
	"quest": "MainPanel/MainMargin/MainLayout/ContentRow/InventoryColumn/CategoryTabs/QuestTab",
}

@onready var currency_display: Label = $MainPanel/MainMargin/MainLayout/HeaderPanel/HeaderMargin/HeaderRow/CurrencyDisplay
@onready var close_button: Button = $MainPanel/MainMargin/MainLayout/HeaderPanel/HeaderMargin/HeaderRow/CloseButton
@onready var slot_grid: GridContainer = get_node(SLOT_GRID_PATH)
@onready var item_name: Label = $MainPanel/MainMargin/MainLayout/ContentRow/DetailPanel/DetailMargin/DetailLayout/ItemName
@onready var description: Label = $MainPanel/MainMargin/MainLayout/ContentRow/DetailPanel/DetailMargin/DetailLayout/Description
@onready var stats: Label = $MainPanel/MainMargin/MainLayout/ContentRow/DetailPanel/DetailMargin/DetailLayout/Stats

var items: Array[Dictionary] = []
var current_category: String = "all"
var selected_index: int = -1
var _slot_nodes: Array[PanelContainer] = []
var _normal_slot_style: StyleBox
var _selected_slot_style: StyleBox
var _tab_normal_style: StyleBox
var _tab_selected_style: StyleBox

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	_cache_slots()
	_cache_styles()
	_connect_category_buttons()
	_bootstrap_placeholder_items()
	_set_open(false, false)

func open() -> void:
	_set_open(true, true)

func close() -> void:
	_set_open(false, true)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func set_gold(amount: int) -> void:
	currency_display.text = "Gold: %s" % _format_number(amount)

func set_items(new_items: Array) -> void:
	items = _to_dictionary_array(new_items)
	if selected_index >= items.size():
		selected_index = -1
	_refresh_slots()
	if selected_index == -1 and not items.is_empty():
		set_selected_item(0)
	else:
		_refresh_details()

func set_category(category: String) -> void:
	var normalized := category.to_lower()
	if not CATEGORY_PATHS.has(normalized):
		normalized = "all"
	current_category = normalized
	category_selected.emit(current_category)
	_refresh_category_buttons()

func set_selected_item(index: int) -> void:
	if index < 0 or index >= _slot_nodes.size():
		selected_index = -1
	else:
		selected_index = index
	_refresh_slots()
	_refresh_details()
	if selected_index >= 0 and selected_index < items.size():
		item_selected.emit(selected_index, items[selected_index])

func _cache_slots() -> void:
	_slot_nodes.clear()
	for child in slot_grid.get_children():
		if child is PanelContainer:
			var slot := child as PanelContainer
			_slot_nodes.append(slot)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			var index := _slot_nodes.size() - 1
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					set_selected_item(index)
			)

func _cache_styles() -> void:
	if _slot_nodes.size() > 0:
		_selected_slot_style = _slot_nodes[0].get_theme_stylebox("panel")
	if _slot_nodes.size() > 1:
		_normal_slot_style = _slot_nodes[1].get_theme_stylebox("panel")
	var all_tab := get_node(CATEGORY_PATHS["all"]) as Button
	var items_tab := get_node(CATEGORY_PATHS["items"]) as Button
	_tab_normal_style = items_tab.get_theme_stylebox("normal")
	_tab_selected_style = all_tab.get_theme_stylebox("normal")

func _connect_category_buttons() -> void:
	for category in CATEGORY_PATHS.keys():
		var button := get_node(CATEGORY_PATHS[category]) as Button
		button.pressed.connect(func() -> void:
			set_category(category)
		)
	_refresh_category_buttons()

func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if is_open:
		close_button.grab_focus()
	if not should_emit:
		return
	if is_open:
		opened.emit()
	else:
		closed.emit()
	toggled.emit(is_open)

func _bootstrap_placeholder_items() -> void:
	items = [
		{
			"name": item_name.text,
			"description": description.text,
			"stats": stats.text,
			"quantity": 8,
			"category": "items",
		},
		{
			"name": "Traveler Gear",
			"description": "Reliable equipment for long roads and uncertain weather.",
			"stats": "Defense +2\nValue: 90 gold",
			"quantity": 1,
			"category": "gear",
		},
	]
	selected_index = 0
	_refresh_slots()

func _refresh_category_buttons() -> void:
	for category in CATEGORY_PATHS.keys():
		var button := get_node(CATEGORY_PATHS[category]) as Button
		button.add_theme_stylebox_override("normal", _tab_selected_style if category == current_category else _tab_normal_style)

func _refresh_slots() -> void:
	for index in _slot_nodes.size():
		var slot := _slot_nodes[index]
		slot.add_theme_stylebox_override("panel", _selected_slot_style if index == selected_index else _normal_slot_style)
		slot.tooltip_text = _item_title(items[index]) if index < items.size() else "Empty"
		_set_slot_quantity(slot, items[index].get("quantity", 0) if index < items.size() else 0)

func _refresh_details() -> void:
	if selected_index < 0 or selected_index >= items.size():
		item_name.text = "Empty Slot"
		description.text = "No item selected."
		stats.text = ""
		return

	var item := items[selected_index]
	item_name.text = _item_title(item)
	description.text = str(item.get("description", ""))
	stats.text = str(item.get("stats", ""))

func _set_slot_quantity(slot: PanelContainer, quantity: int) -> void:
	var label := slot.get_node_or_null("Quantity") as Label
	if label == null:
		label = Label.new()
		label.name = "Quantity"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = str(quantity) if quantity > 1 else ""

func _item_title(item: Dictionary) -> String:
	return str(item.get("name", "Unknown Item"))

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
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
