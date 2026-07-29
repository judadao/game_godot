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

const ROW_CONTAINER_PATH := "CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout/ItemScroll/ItemRows"
const SHOP_ITEM_ROW_SCENE := preload("res://scenes/ui/shop/ShopItemRow.tscn")
const ITEM_ICON_SWORD := preload("res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png")
const ITEM_ICON_BOOTS := preload("res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0006_Boots.png")
const ITEM_ICON_GEM := preload("res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png")
const ITEM_ICON_SUPPLY := preload("res://assets/ui/fantasy_icons_16x16/png/Separately/Icon67_1.png")
const ITEM_ICON_MAP := preload("res://assets/ui/fantasy_icons_16x16/png/Separately/Icon46_1.png")
const ACTION_ICON_CONFIRM := preload("res://assets/ui/fantasy_icons_16x16/png/Separately/Icon25_1.png")
const NPC_PORTRAIT_ATLAS := preload("res://assets/town/rebuild_v2/town_npcs_atlas_v2.png")
const DEFAULT_MERCHANT_PORTRAIT := preload("res://assets/ui/shop/generated/merchant_counter.png")

@onready var mode_bar: HBoxContainer = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar
@onready var buy_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar/BuyButton
@onready var sell_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar/SellButton
@onready var title_text: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Title/TitleBanner/TitleText
@onready var header_icon: TextureRect = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Title/HeaderIcon
@onready var merchant_name: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ModeBar/MerchantName
@onready var merchant_role: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/MerchantPanel/SectionLabel
@onready var merchant_identity: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/MerchantPanel/IdentityLabel
@onready var merchant_portrait: TextureRect = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/MerchantPanel/PortraitFrame/MerchantPortrait
@onready var merchant_dialogue: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/MerchantPanel/DialoguePanel/Dialogue
@onready var merchant_hint: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/MerchantPanel/Hint
@onready var blueprint_icon: TextureRect = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout/ItemListHeader/BlueprintIcon
@onready var item_header: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout/ItemListHeader/ItemHeader
@onready var item_scroll: ScrollContainer = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout/ItemScroll
@onready var preview_icon: TextureRect = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/PreviewFrame/PreviewLayout/PreviewIcon
@onready var details_header: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/SectionLabel
@onready var item_name: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/ItemName
@onready var item_description: RichTextLabel = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/ItemDescription
@onready var quantity_label: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/QuantityLabel
@onready var minus_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/MinusButton
@onready var quantity_value: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/QuantityValue
@onready var plus_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/QuantityRow/PlusButton
@onready var currency_amount: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/DetailsPanel/DetailsLayout/TotalRow/CurrencyAmount
@onready var gold_balance: Label = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ActionBar/GoldBalance
@onready var confirm_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/ActionBar/ConfirmButton
@onready var cancel_button: Button = $CenterContainer/ShopWindow/WindowMargin/WindowLayout/Title/CancelButton
@onready var row_container: VBoxContainer = get_node(ROW_CONTAINER_PATH)

var items: Array[Dictionary] = []
var mode: String = "buy"
var selected_index: int = -1
var quantity: int = 1
var wallet_balance: int = 0
var shop_context: StringName = &"general_store"
var _merchant_name_override := ""
var _row_buttons: Array[Button] = []
var _row_icons: Array[TextureRect] = []
var _row_names: Array[Label] = []
var _row_stock_labels: Array[Label] = []
var _row_prices: Array[Label] = []
var _row_normal_style: StyleBox
var _row_selected_style: StyleBox
var _mode_normal_style: StyleBox
var _mode_selected_style: StyleBox

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cache_rows()
	_cache_styles()
	_configure_focus_navigation()
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_cancel()


func set_merchant_name(display_name: String) -> void:
	_merchant_name_override = display_name.strip_edges()
	merchant_name.text = display_name


func set_shop_context(shop_id: StringName) -> void:
	shop_context = shop_id
	match shop_id:
		&"sword_soul_shop":
			_apply_shop_identity(
				"SWORD SOUL BLUEPRINTS",
				"SOULWRIGHT",
				"Soulwright Ilyra",
				"Every sword soul begins as a design.\nChoose the one your forge will awaken.",
				"Forge and upgrade purchased blueprints at your workshop.",
				Rect2(330, 54, 280, 590)
			)
		&"equipment_blueprint_shop":
			_apply_shop_identity(
				"EQUIPMENT BLUEPRINTS",
				"MASTER DRAFTSWOMAN",
				"Draftswoman Elara",
				"A sound weapon starts with a precise plan.\nInspect each design before you invest.",
				"Each blueprint unlocks a permanent workshop recipe.",
				Rect2(1940, 54, 172, 590)
			)
		&"material_store", &"material_yard":
			_apply_shop_identity(
				"FORGE MATERIALS",
				"YARD QUARTERMASTER",
				"Quartermaster Brann",
				"Tools on the left, quality stock on the right.\nTake what your next forge job needs.",
				"Materials and tools improve as the forge flame grows stronger.",
				Rect2(620, 54, 300, 590)
			)
		_:
			_apply_shop_identity(
				"TRADE COUNTER",
				"MERCHANT",
				"Mira",
				"Welcome, traveler!\nWhat can I get for you?",
				"Choose a trade mode, then inspect an item.",
				Rect2()
			)
	_apply_context_controls()
	set_mode("buy" if _is_blueprint_shop() else mode)


func set_wallet(amount: int) -> void:
	wallet_balance = maxi(0, amount)
	gold_balance.text = "Wallet: %s gold" % _format_number(wallet_balance)
	_refresh_details()

func set_mode(new_mode: String) -> void:
	mode = "buy" if _is_blueprint_shop() else (
		"sell" if new_mode.to_lower() == "sell" else "buy"
	)
	item_header.text = (
		"Blueprint Catalog"
		if _is_blueprint_shop()
		else ("Your Goods" if mode == "sell" else "Merchant Stock")
	)
	confirm_button.text = (
		"Buy Blueprint"
		if _is_blueprint_shop()
		else ("Sell" if mode == "sell" else "Buy")
	)
	buy_button.add_theme_stylebox_override("normal", _mode_selected_style if mode == "buy" else _mode_normal_style)
	sell_button.add_theme_stylebox_override("normal", _mode_selected_style if mode == "sell" else _mode_normal_style)
	mode_changed.emit(mode)
	_refresh_rows()
	_refresh_details()

func set_items(new_items: Array) -> void:
	items = _to_dictionary_array(new_items)
	_ensure_row_capacity(items.size())
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
	if _is_blueprint_shop():
		quantity = 1
		quantity_value.text = "1"
		_refresh_total()
		quantity_changed.emit(quantity)
		return
	var max_quantity := 99
	if selected_index >= 0 and selected_index < items.size():
		var limit_key := "owned_count" if mode == "sell" else "stock"
		max_quantity = max(1, int(items[selected_index].get(limit_key, 99)))
	quantity = clampi(new_quantity, 1, max_quantity)
	quantity_value.text = str(quantity)
	_refresh_total()
	quantity_changed.emit(quantity)

func _cache_rows() -> void:
	_row_buttons.clear()
	_row_icons.clear()
	_row_names.clear()
	_row_stock_labels.clear()
	_row_prices.clear()
	for child in row_container.get_children():
		if child is Button:
			_register_row(child as Button)

func _register_row(button: Button) -> void:
	var index := _row_buttons.size()
	_row_buttons.append(button)
	_row_icons.append(button.get_node("RowMargin/RowLayout/ItemIcon") as TextureRect)
	_row_names.append(button.get_node("RowMargin/RowLayout/ItemText/ItemName") as Label)
	_row_stock_labels.append(button.get_node("RowMargin/RowLayout/ItemText/Stock") as Label)
	_row_prices.append(button.get_node("RowMargin/RowLayout/PriceGroup/Price") as Label)
	button.pressed.connect(set_selected_item.bind(index))
	button.focus_entered.connect(_on_row_focused.bind(index))

func _ensure_row_capacity(required: int) -> void:
	while _row_buttons.size() < required:
		var button := SHOP_ITEM_ROW_SCENE.instantiate() as Button
		if button == null:
			push_error("ShopItemRow must instantiate as Button.")
			return
		button.name = "Row%02d" % (_row_buttons.size() + 1)
		row_container.add_child(button)
		_register_row(button)
	_configure_focus_navigation()

func _cache_styles() -> void:
	if _row_buttons.size() > 0:
		_row_selected_style = _row_buttons[0].get_theme_stylebox("normal")
	if _row_buttons.size() > 1:
		_row_normal_style = _row_buttons[1].get_theme_stylebox("normal")
	_mode_selected_style = buy_button.get_theme_stylebox("normal")
	_mode_normal_style = sell_button.get_theme_stylebox("normal")

func _configure_focus_navigation() -> void:
	buy_button.focus_neighbor_right = (
		NodePath() if _is_blueprint_shop() else buy_button.get_path_to(sell_button)
	)
	sell_button.focus_neighbor_left = sell_button.get_path_to(buy_button)
	if _row_buttons.is_empty():
		return
	buy_button.focus_neighbor_bottom = buy_button.get_path_to(_row_buttons[0])
	sell_button.focus_neighbor_bottom = sell_button.get_path_to(_row_buttons[0])
	for index in _row_buttons.size():
		var row := _row_buttons[index]
		row.focus_neighbor_top = row.get_path_to(
			buy_button if index == 0 else _row_buttons[index - 1]
		)
		row.focus_neighbor_bottom = row.get_path_to(
			confirm_button if index == _row_buttons.size() - 1 else _row_buttons[index + 1]
		)
		row.focus_neighbor_right = row.get_path_to(minus_button)
	minus_button.focus_neighbor_left = minus_button.get_path_to(_row_buttons[0])
	minus_button.focus_neighbor_right = minus_button.get_path_to(plus_button)
	plus_button.focus_neighbor_left = plus_button.get_path_to(minus_button)
	minus_button.focus_neighbor_bottom = minus_button.get_path_to(confirm_button)
	plus_button.focus_neighbor_bottom = plus_button.get_path_to(cancel_button)
	confirm_button.focus_neighbor_top = confirm_button.get_path_to(minus_button)
	confirm_button.focus_neighbor_right = confirm_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_top = cancel_button.get_path_to(plus_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(confirm_button)

func _on_row_focused(index: int) -> void:
	if index < items.size():
		set_selected_item(index)
		item_scroll.call_deferred("ensure_control_visible", _row_buttons[index])

func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if is_open:
		if selected_index >= 0 and selected_index < _row_buttons.size():
			_row_buttons[selected_index].grab_focus()
		else:
			buy_button.grab_focus()
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
		var preview_name := str(button.get_meta("preview_name", "")).strip_edges()
		if preview_name.is_empty():
			continue
		var item := {
			"name": preview_name,
			"price": int(button.get_meta("preview_price", 0)),
			"description": item_description.text if items.is_empty() else "A useful item from the merchant's stock.",
			"stock": int(button.get_meta("preview_stock", 5)),
		}
		var icon_path := str(button.get_meta("preview_icon_path", ""))
		if not icon_path.is_empty():
			item["texture"] = load(icon_path) as Texture2D
		items.append(item)
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
			var count_text := (
				("OWNED" if int(item.get("owned_count", 0)) > 0 else "BLUEPRINT")
				if _is_blueprint_shop()
				else (
					"Owned %d" % int(item.get("owned_count", 0))
					if mode == "sell"
					else "Stock %d" % int(item.get("stock", 0))
				)
			)
			_row_icons[index].texture = _item_icon(item)
			_row_names[index].text = _item_title(item)
			_row_stock_labels[index].text = count_text
			_row_prices[index].text = _format_number(_unit_price(item))
			button.tooltip_text = str(item.get("description", ""))
			button.add_theme_stylebox_override("normal", _row_selected_style if index == selected_index else _row_normal_style)
	_configure_active_row_navigation()

func _configure_active_row_navigation() -> void:
	var active_count := mini(items.size(), _row_buttons.size())
	if active_count <= 0:
		return
	buy_button.focus_neighbor_bottom = buy_button.get_path_to(_row_buttons[0])
	sell_button.focus_neighbor_bottom = sell_button.get_path_to(_row_buttons[0])
	for index in active_count:
		var row := _row_buttons[index]
		row.focus_neighbor_top = row.get_path_to(
			buy_button if index == 0 else _row_buttons[index - 1]
		)
		row.focus_neighbor_bottom = row.get_path_to(
			confirm_button if index == active_count - 1 else _row_buttons[index + 1]
		)

func _refresh_details() -> void:
	if selected_index < 0 or selected_index >= items.size():
		preview_icon.texture = null
		item_name.text = "No Item Selected"
		item_description.text = "Select an item from the list to view its details."
		minus_button.disabled = true
		plus_button.disabled = true
		confirm_button.disabled = true
		set_quantity(1)
		return

	var item := items[selected_index]
	minus_button.disabled = _is_blueprint_shop()
	plus_button.disabled = _is_blueprint_shop()
	var available := int(item.get("owned_count", 0)) if mode == "sell" else int(item.get("stock", 0))
	var already_owned := _is_blueprint_shop() and int(item.get("owned_count", 0)) > 0
	confirm_button.disabled = available <= 0 or already_owned
	confirm_button.text = (
		"Owned" if already_owned else (
			"Buy Blueprint"
			if _is_blueprint_shop()
			else ("Sell" if mode == "sell" else "Buy")
		)
	)
	preview_icon.texture = item.get("texture") as Texture2D
	if preview_icon.texture == null and selected_index < _row_icons.size():
		preview_icon.texture = _row_icons[selected_index].texture
	item_name.text = _item_title(item)
	if _is_blueprint_shop():
		item_description.text = "%s\n\n[b]Blueprint Status:[/b] %s" % [
			str(item.get("description", "")),
			"OWNED - available at your workshop" if already_owned else "AVAILABLE TO PURCHASE",
		]
	else:
		item_description.text = "%s\n\n%s: %d" % [
			str(item.get("description", "")),
			"Owned" if mode == "sell" else "Stock",
			available,
		]
	set_quantity(quantity)

func _refresh_total() -> void:
	var price := 0
	if selected_index >= 0 and selected_index < items.size():
		price = _unit_price(items[selected_index])
	currency_amount.text = "%s gold" % _format_number(price * quantity)

func _confirm_selection() -> void:
	if selected_index >= 0 and selected_index < items.size() and not confirm_button.disabled:
		confirmed.emit(items[selected_index], quantity, mode)

func set_transaction_feedback(message: String, successful: bool) -> void:
	var prefix := "Success" if successful else "Unable"
	item_description.text += "\n\n[b]%s:[/b] %s" % [prefix, message]

func _cancel() -> void:
	canceled.emit()
	close()

func _item_title(item: Dictionary) -> String:
	var display_name := str(item.get("name", "Unknown Item"))
	if _is_blueprint_shop() and not "blueprint" in display_name.to_lower():
		return "%s Blueprint" % display_name
	return display_name

func _unit_price(item: Dictionary) -> int:
	if mode == "sell":
		return int(item.get("sell_price", maxi(1, int(item.get("price", 0)) / 2)))
	return int(item.get("price", 0))

func _item_icon(item: Dictionary) -> Texture2D:
	var explicit_texture := item.get("texture") as Texture2D
	if explicit_texture != null:
		return explicit_texture
	if _is_blueprint_shop():
		return ITEM_ICON_MAP
	var identity := "%s %s" % [
		str(item.get("id", "")).to_lower(),
		_item_title(item).to_lower(),
	]
	if "boot" in identity:
		return ITEM_ICON_BOOTS
	if "sword" in identity or "blade" in identity or "edge" in identity:
		return ITEM_ICON_SWORD
	if "map" in identity:
		return ITEM_ICON_MAP
	if "shard" in identity or "charm" in identity or "soul" in identity or "gem" in identity:
		return ITEM_ICON_GEM
	return ITEM_ICON_SUPPLY

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


func _apply_shop_identity(
	window_title: String,
	role: String,
	display_name: String,
	dialogue: String,
	hint: String,
	atlas_region: Rect2
) -> void:
	title_text.text = window_title
	merchant_role.text = role
	var resolved_name := (
		_merchant_name_override
		if not _merchant_name_override.is_empty()
		else display_name
	)
	merchant_name.text = resolved_name
	merchant_identity.text = display_name
	merchant_identity.tooltip_text = display_name
	merchant_dialogue.text = dialogue
	merchant_hint.text = hint
	if atlas_region.size == Vector2.ZERO:
		merchant_portrait.texture = DEFAULT_MERCHANT_PORTRAIT
		return
	var portrait := AtlasTexture.new()
	portrait.atlas = NPC_PORTRAIT_ATLAS
	portrait.region = atlas_region
	merchant_portrait.texture = portrait


func _apply_context_controls() -> void:
	var blueprint_shop := _is_blueprint_shop()
	mode_bar.visible = not blueprint_shop
	sell_button.visible = not blueprint_shop
	sell_button.disabled = blueprint_shop
	blueprint_icon.visible = blueprint_shop
	blueprint_icon.texture = ITEM_ICON_MAP if blueprint_shop else ITEM_ICON_SUPPLY
	header_icon.texture = ITEM_ICON_MAP if blueprint_shop else ITEM_ICON_SUPPLY
	details_header.text = "BLUEPRINT DETAILS" if blueprint_shop else "ITEM DETAILS"
	quantity_label.text = "Unique Blueprint" if blueprint_shop else "Quantity"
	minus_button.tooltip_text = (
		"Blueprints are purchased once"
		if blueprint_shop
		else "Decrease quantity"
	)
	plus_button.tooltip_text = (
		"Blueprints are purchased once"
		if blueprint_shop
		else "Increase quantity"
	)
	confirm_button.icon = ITEM_ICON_MAP if blueprint_shop else ACTION_ICON_CONFIRM
	confirm_button.tooltip_text = (
		"Purchase this unique blueprint"
		if blueprint_shop
		else "Confirm this transaction"
	)
	_configure_focus_navigation()


func _is_blueprint_shop() -> bool:
	return shop_context == &"sword_soul_shop" or shop_context == &"equipment_blueprint_shop"
