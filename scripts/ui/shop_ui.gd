extends Control
class_name ShopUI

signal opened
signal closed
signal toggled(is_open: bool)
signal mode_changed(mode: String)
signal item_selected(index: int, item_data: Dictionary, mode: String)
signal quantity_changed(quantity: int)
signal confirmed(item_data: Dictionary, quantity: int, mode: String)
signal canceled

const ROW_CONTAINER_PATH := "CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout"

@onready var buy_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar/BuyButton
@onready var sell_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar/SellButton
@onready var merchant_name: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar/MerchantName
@onready var item_header: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout/ItemListHeader/ItemHeader
@onready var preview_icon: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/PreviewFrame/PreviewLayout/PreviewIcon
@onready var item_name: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/ItemName
@onready var item_description: RichTextLabel = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/ItemDescription
@onready var minus_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/MinusButton
@onready var quantity_value: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/QuantityValue
@onready var plus_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/PlusButton
@onready var currency_amount: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/TotalRow/CurrencyAmount
@onready var gold_balance: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ActionBar/GoldBalance
@onready var confirm_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ActionBar/ConfirmButton
@onready var cancel_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ActionBar/CancelButton
@onready var row_container: VBoxContainer = get_node(ROW_CONTAINER_PATH)

var items: Array[Dictionary] = []
var mode: String = "buy"
var selected_index: int = -1
var quantity: int = 1
var _row_buttons: Array[Button] = []
var _row_normal_style: StyleBox
var _row_selected_style: StyleBox
var _mode_normal_style: StyleBox
var _mode_selected_style: StyleBox

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cache_rows()
	_cache_styles()
	buy_button.pressed.connect(func() -> void: set_mode("buy"))
	sell_button.pressed.connect(func() -> void: set_mode("sell"))
	minus_button.pressed.connect(func() -> void: set_quantity(quantity - 1))
	plus_button.pressed.connect(func() -> void: set_quantity(quantity + 1))
	confirm_button.pressed.connect(_confirm_selection)
	cancel_button.pressed.connect(_cancel)
	_bootstrap_placeholder_items()
	set_mode(mode)
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

func set_merchant_name(display_name: String) -> void:
	merchant_name.text = display_name

func set_wallet(amount: int) -> void:
	gold_balance.text = "Wallet: %s gold" % _format_number(amount)

func set_mode(new_mode: String) -> void:
	mode = "sell" if new_mode.to_lower() == "sell" else "buy"
	item_header.text = "Your Goods" if mode == "sell" else "Merchant Stock"
	buy_button.add_theme_stylebox_override("normal", _mode_selected_style if mode == "buy" else _mode_normal_style)
	sell_button.add_theme_stylebox_override("normal", _mode_selected_style if mode == "sell" else _mode_normal_style)
	mode_changed.emit(mode)
	_refresh_details()

func set_items(new_items: Array) -> void:
	items = _to_dictionary_array(new_items)
	if selected_index >= items.size():
		selected_index = -1
	_refresh_rows()
	if selected_index == -1 and not items.is_empty():
		set_selected_item(0)
	else:
		_refresh_details()

func set_selected_item(index: int) -> void:
	selected_index = index if index >= 0 and index < items.size() else -1
	quantity = 1
	_refresh_rows()
	_refresh_details()
	if selected_index >= 0:
		item_selected.emit(selected_index, items[selected_index], mode)

func set_quantity(new_quantity: int) -> void:
	var max_quantity := 99
	if selected_index >= 0 and selected_index < items.size():
		max_quantity = max(1, int(items[selected_index].get("stock", 99)))
	quantity = clampi(new_quantity, 1, max_quantity)
	quantity_value.text = str(quantity)
	_refresh_total()
	quantity_changed.emit(quantity)

func _cache_rows() -> void:
	_row_buttons.clear()
	for child in row_container.get_children():
		if child is Button:
			var button := child as Button
			_row_buttons.append(button)
			var index := _row_buttons.size() - 1
			button.pressed.connect(func() -> void:
				set_selected_item(index)
			)

func _cache_styles() -> void:
	if _row_buttons.size() > 0:
		_row_selected_style = _row_buttons[0].get_theme_stylebox("normal")
	if _row_buttons.size() > 1:
		_row_normal_style = _row_buttons[1].get_theme_stylebox("normal")
	_mode_selected_style = buy_button.get_theme_stylebox("normal")
	_mode_normal_style = sell_button.get_theme_stylebox("normal")

func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if not should_emit:
		return
	if is_open:
		opened.emit()
	else:
		closed.emit()
	toggled.emit(is_open)

func _bootstrap_placeholder_items() -> void:
	if not items.is_empty():
		return
	for button in _row_buttons:
		var row_text := button.text.strip_edges()
		if row_text.is_empty():
			continue
		var parts := row_text.split(" ", false)
		var price := 0
		if not parts.is_empty() and parts[parts.size() - 1].is_valid_int():
			price = int(parts[parts.size() - 1])
			parts.remove_at(parts.size() - 1)
		items.append({
			"name": " ".join(parts),
			"price": price,
			"description": item_description.text if items.is_empty() else "A useful item from the merchant's stock.",
			"stock": 5,
		})
	selected_index = 0 if not items.is_empty() else -1
	_refresh_rows()
	_refresh_details()

func _refresh_rows() -> void:
	for index in _row_buttons.size():
		var button := _row_buttons[index]
		button.visible = index < items.size()
		button.disabled = index >= items.size()
		if index < items.size():
			var item := items[index]
			button.text = "%s    %s" % [_item_title(item), _format_number(int(item.get("price", 0)))]
			button.tooltip_text = str(item.get("description", ""))
		button.add_theme_stylebox_override("normal", _row_selected_style if index == selected_index else _row_normal_style)

func _refresh_details() -> void:
	if selected_index < 0 or selected_index >= items.size():
		preview_icon.text = "-"
		item_name.text = "No Item Selected"
		item_description.text = ""
		set_quantity(1)
		return

	var item := items[selected_index]
	preview_icon.text = str(item.get("icon", _item_title(item).substr(0, 1).to_upper()))
	item_name.text = _item_title(item)
	item_description.text = str(item.get("description", ""))
	set_quantity(quantity)

func _refresh_total() -> void:
	var price := 0
	if selected_index >= 0 and selected_index < items.size():
		price = int(items[selected_index].get("price", 0))
	currency_amount.text = "%s gold" % _format_number(price * quantity)

func _confirm_selection() -> void:
	if selected_index >= 0 and selected_index < items.size():
		confirmed.emit(items[selected_index], quantity, mode)

func _cancel() -> void:
	canceled.emit()
	close()

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
