class_name MaterialYardUI
extends Control

signal opened
signal closed
signal toggled(is_open: bool)
signal canceled
signal purchase_requested(offer_id: StringName, quantity: int)

const WORKSHOP_ID: StringName = &"workshop"
const MATERIAL_FILTER: StringName = &"materials"
const TOOL_FILTER: StringName = &"forge_tools"
const DEFAULT_ICON := preload(
	"res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Ore_01.png"
)

@onready var close_button: Button = %CloseButton
@onready var materials_button: Button = %MaterialsButton
@onready var tools_button: Button = %ForgeToolsButton
@onready var offer_scroll: ScrollContainer = %OfferScroll
@onready var offer_rows: VBoxContainer = %OfferRows
@onready var offer_template: Button = %OfferTemplate
@onready var empty_label: Label = %EmptyLabel
@onready var tier_label: Label = %TierLabel
@onready var wallet_label: Label = %WalletLabel
@onready var selected_icon: TextureRect = %SelectedIcon
@onready var selected_category: Label = %SelectedCategory
@onready var selected_name: Label = %SelectedName
@onready var selected_description: Label = %SelectedDescription
@onready var owned_value: Label = %OwnedValue
@onready var unlock_value: Label = %UnlockValue
@onready var unit_price_value: Label = %UnitPriceValue
@onready var quantity_minus: Button = %QuantityMinus
@onready var quantity_value: Label = %QuantityValue
@onready var quantity_plus: Button = %QuantityPlus
@onready var total_value: Label = %TotalValue
@onready var purchase_status: Label = %PurchaseStatus
@onready var buy_button: Button = %BuyButton

var _town: RefCounted
var _inventory: RefCounted
var _forge_service: RefCounted
var _context_id: StringName = &"material_yard"
var _offers: Array[Dictionary] = []
var _visible_offer_indices: Array[int] = []
var _offer_buttons: Array[Button] = []
var _active_filter: StringName = MATERIAL_FILTER
var _selected_offer_index := -1
var _quantity := 1
var _store_tier := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	materials_button.pressed.connect(_set_filter.bind(MATERIAL_FILTER))
	tools_button.pressed.connect(_set_filter.bind(TOOL_FILTER))
	quantity_minus.pressed.connect(_set_quantity.bind(-1))
	quantity_plus.pressed.connect(_set_quantity.bind(1))
	buy_button.pressed.connect(_request_purchase)
	_refresh()
	visible = false


func open() -> void:
	var was_visible := visible
	visible = true
	_refresh()
	_focus_primary_control.call_deferred()
	if not was_visible:
		opened.emit()
		toggled.emit(true)


func close() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and (focused == self or is_ancestor_of(focused)):
		focused.release_focus()
	visible = false
	closed.emit()
	toggled.emit(false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func set_context(context_id: StringName) -> void:
	_context_id = context_id


func get_context_id() -> StringName:
	return _context_id


func get_building_id() -> StringName:
	return WORKSHOP_ID


func set_services(
	town: RefCounted,
	inventory: RefCounted,
	forge_service: RefCounted = null
) -> void:
	_town = town
	_inventory = inventory
	_forge_service = forge_service
	if _offers.is_empty():
		_project_service_offers()
	if is_node_ready():
		_refresh()


func set_offers(offers: Array) -> void:
	_offers.clear()
	for offer in offers:
		if offer is Dictionary:
			_offers.append((offer as Dictionary).duplicate(true))
	_selected_offer_index = -1
	_quantity = 1
	if is_node_ready():
		_refresh()


func set_transaction_feedback(message: String, successful: bool) -> void:
	purchase_status.text = message
	purchase_status.add_theme_color_override(
		"font_color",
		Color(0.57, 0.9, 0.62) if successful else Color(1.0, 0.55, 0.36),
	)


func get_offer_button_count() -> int:
	return _offer_buttons.size()


func get_building_button_count() -> int:
	return 0


func get_resource_text() -> String:
	return wallet_label.text if is_instance_valid(wallet_label) else ""


func request_upgrade() -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
		close()


func _project_service_offers() -> void:
	if _forge_service == null or not _forge_service.has_method("get_shop_offers"):
		return
	var projected: Variant = _forge_service.call("get_shop_offers", _context_id)
	if projected is Array:
		set_offers(projected as Array)


func _refresh() -> void:
	if not is_node_ready():
		return
	_store_tier = _resolve_store_tier()
	tier_label.text = "ETERNAL TORCH  •  TIER %d" % _store_tier
	wallet_label.text = "Wallet  %s G" % _format_number(_resource_amount(&"gold"))
	_refresh_filter_buttons()
	_rebuild_offer_rows()
	_refresh_details()


func _resolve_store_tier() -> int:
	if _town == null or not _town.has_method("get_village_stage"):
		return 1
	return maxi(1, int(_town.call("get_village_stage")) + 1)


func _set_filter(filter_id: StringName) -> void:
	if _active_filter == filter_id:
		return
	_active_filter = filter_id
	_selected_offer_index = -1
	_quantity = 1
	_refresh_filter_buttons()
	_rebuild_offer_rows()
	_refresh_details()
	_focus_primary_control.call_deferred()


func _refresh_filter_buttons() -> void:
	materials_button.button_pressed = _active_filter == MATERIAL_FILTER
	tools_button.button_pressed = _active_filter == TOOL_FILTER


func _rebuild_offer_rows() -> void:
	for child in offer_rows.get_children():
		offer_rows.remove_child(child)
		child.queue_free()
	_offer_buttons.clear()
	_visible_offer_indices.clear()

	for offer_index in _offers.size():
		var offer := _offers[offer_index]
		if _offer_filter(offer) != _active_filter:
			continue
		_visible_offer_indices.append(offer_index)
		var row := _create_offer_row(offer, offer_index)
		offer_rows.add_child(row)
		_offer_buttons.append(row)

	empty_label.visible = _offer_buttons.is_empty()
	if _selected_offer_index < 0 and not _visible_offer_indices.is_empty():
		_selected_offer_index = _visible_offer_indices[0]
	_configure_focus_navigation()


func _create_offer_row(offer: Dictionary, offer_index: int) -> Button:
	var row := offer_template.duplicate() as Button
	row.name = "Offer_%s" % _offer_id(offer)
	row.visible = true
	row.text = "%s\n%s" % [_offer_name(offer), _offer_row_status(offer)]
	row.icon = _offer_icon(offer)
	row.tooltip_text = _offer_description(offer)
	row.disabled = false
	row.pressed.connect(_select_offer.bind(offer_index))
	row.focus_entered.connect(_on_offer_focused.bind(offer_index, row))
	return row


func _select_offer(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _offers.size():
		return
	_selected_offer_index = offer_index
	_quantity = 1
	_refresh_details()


func _on_offer_focused(offer_index: int, row: Button) -> void:
	_select_offer(offer_index)
	offer_scroll.call_deferred("ensure_control_visible", row)


func _refresh_details() -> void:
	var has_selection := (
		_selected_offer_index >= 0 and _selected_offer_index < _offers.size()
	)
	if not has_selection:
		selected_icon.texture = DEFAULT_ICON
		selected_category.text = "MATERIAL YARD STOCK"
		selected_name.text = "Select an offer"
		selected_description.text = (
			"Choose materials or forge tools to inspect the yard's current stock."
		)
		owned_value.text = "--"
		unlock_value.text = "--"
		unit_price_value.text = "--"
		quantity_value.text = "1"
		total_value.text = "--"
		purchase_status.text = "No offer selected."
		buy_button.disabled = true
		buy_button.text = "SELECT AN OFFER"
		quantity_minus.disabled = true
		quantity_plus.disabled = true
		return

	var offer := _offers[_selected_offer_index]
	var required_tier := _required_tier(offer)
	var unlocked := _store_tier >= required_tier
	var unique_tool := _offer_filter(offer) == TOOL_FILTER
	var owned := _owned_amount(offer)
	var already_owned := unique_tool and owned > 0
	var price := _offer_price(offer)
	var total := price * _quantity
	var can_afford := _resource_amount(&"gold") >= total

	selected_icon.texture = _offer_icon(offer)
	selected_category.text = (
		"FORGE TOOL" if unique_tool else "FORGING MATERIAL"
	)
	selected_name.text = _offer_name(offer)
	selected_description.text = _offer_description(offer)
	owned_value.text = _format_number(owned)
	unlock_value.text = (
		"TIER %d  •  READY" % required_tier
		if unlocked
		else "TIER %d  •  LOCKED" % required_tier
	)
	unlock_value.add_theme_color_override(
		"font_color",
		Color(0.57, 0.9, 0.62) if unlocked else Color(1.0, 0.55, 0.36),
	)
	unit_price_value.text = "%s G" % _format_number(price)
	quantity_value.text = str(_quantity)
	total_value.text = "%s G" % _format_number(total)
	quantity_minus.disabled = unique_tool or _quantity <= 1
	quantity_plus.disabled = unique_tool or _quantity >= _max_quantity(offer)

	if not unlocked:
		purchase_status.text = (
			"Raise the Eternal Torch to Tier %d to unlock this offer." % required_tier
		)
		buy_button.text = "TIER %d REQUIRED" % required_tier
	elif already_owned:
		purchase_status.text = "This permanent forge tool is already owned."
		buy_button.text = "ALREADY OWNED"
	elif not can_afford:
		purchase_status.text = "Not enough gold for this purchase."
		buy_button.text = "INSUFFICIENT GOLD"
	else:
		purchase_status.text = "Stock ready. Purchase will be sent to the forge ledger."
		buy_button.text = "BUY  •  %s G" % _format_number(total)
	buy_button.disabled = not unlocked or already_owned or not can_afford


func _set_quantity(delta: int) -> void:
	if _selected_offer_index < 0 or _selected_offer_index >= _offers.size():
		return
	var offer := _offers[_selected_offer_index]
	if _offer_filter(offer) == TOOL_FILTER:
		_quantity = 1
	else:
		_quantity = clampi(_quantity + delta, 1, _max_quantity(offer))
	_refresh_details()


func _request_purchase() -> void:
	if buy_button.disabled:
		return
	var offer := _offers[_selected_offer_index]
	purchase_requested.emit(_offer_id(offer), _quantity)


func _configure_focus_navigation() -> void:
	materials_button.focus_neighbor_right = materials_button.get_path_to(tools_button)
	tools_button.focus_neighbor_left = tools_button.get_path_to(materials_button)
	if _offer_buttons.is_empty():
		materials_button.focus_neighbor_bottom = materials_button.get_path_to(buy_button)
		tools_button.focus_neighbor_bottom = tools_button.get_path_to(buy_button)
		return
	materials_button.focus_neighbor_bottom = materials_button.get_path_to(_offer_buttons[0])
	tools_button.focus_neighbor_bottom = tools_button.get_path_to(_offer_buttons[0])
	for index in _offer_buttons.size():
		var row := _offer_buttons[index]
		row.focus_neighbor_top = row.get_path_to(
			materials_button if index == 0 else _offer_buttons[index - 1]
		)
		row.focus_neighbor_bottom = row.get_path_to(
			buy_button if index == _offer_buttons.size() - 1 else _offer_buttons[index + 1]
		)
		row.focus_neighbor_right = row.get_path_to(quantity_minus)
	quantity_minus.focus_neighbor_left = quantity_minus.get_path_to(_offer_buttons[0])
	quantity_minus.focus_neighbor_right = quantity_minus.get_path_to(quantity_plus)
	quantity_plus.focus_neighbor_left = quantity_plus.get_path_to(quantity_minus)
	buy_button.focus_neighbor_top = buy_button.get_path_to(quantity_minus)
	buy_button.focus_neighbor_right = buy_button.get_path_to(close_button)
	close_button.focus_neighbor_left = close_button.get_path_to(buy_button)


func _focus_primary_control() -> void:
	if not visible:
		return
	if not _offer_buttons.is_empty():
		_offer_buttons[0].grab_focus()
	else:
		materials_button.grab_focus()


func _offer_filter(offer: Dictionary) -> StringName:
	var raw := String(
		offer.get("category", offer.get("product_kind", offer.get("kind", "material")))
	).to_lower()
	return TOOL_FILTER if raw in ["tool", "forge_tool", "forge_tools"] else MATERIAL_FILTER


func _offer_id(offer: Dictionary) -> StringName:
	return StringName(offer.get("offer_id", offer.get("id", "")))


func _offer_name(offer: Dictionary) -> String:
	return str(offer.get("display_name", offer.get("name", "Unnamed offer")))


func _offer_description(offer: Dictionary) -> String:
	return str(
		offer.get(
			"description",
			"Forging stock supplied by the Material Yard."
		)
	)


func _offer_price(offer: Dictionary) -> int:
	return maxi(0, int(offer.get("price", offer.get("unit_price", 0))))


func _required_tier(offer: Dictionary) -> int:
	if offer.has("required_village_stage"):
		return maxi(1, int(offer.get("required_village_stage", 0)) + 1)
	if offer.has("required_flame_tier"):
		return maxi(1, int(offer.get("required_flame_tier", 0)) + 1)
	return maxi(
		1,
		int(offer.get("required_tier", offer.get("required_flame_level", 1)))
	)


func _max_quantity(offer: Dictionary) -> int:
	return maxi(1, int(offer.get("max_quantity", offer.get("stock", 99))))


func _owned_amount(offer: Dictionary) -> int:
	if offer.has("owned_count"):
		return maxi(0, int(offer.get("owned_count", 0)))
	if bool(offer.get("owned", false)):
		return 1
	var product_id := StringName(
		offer.get("product_id", offer.get("resource_id", offer.get("tool_id", "")))
	)
	if product_id == &"" or _inventory == null:
		return 0
	if _offer_filter(offer) == TOOL_FILTER and _inventory.has_method("owns_tool"):
		return 1 if bool(_inventory.call("owns_tool", product_id)) else 0
	if _inventory.has_method("get_resource_amount"):
		return maxi(0, int(_inventory.call("get_resource_amount", product_id)))
	return 0


func _resource_amount(resource_id: StringName) -> int:
	if _inventory != null and _inventory.has_method("get_resource_amount"):
		return maxi(0, int(_inventory.call("get_resource_amount", resource_id)))
	return 0


func _offer_icon(offer: Dictionary) -> Texture2D:
	var texture: Variant = offer.get("texture", offer.get("icon", null))
	if texture is Texture2D:
		return texture as Texture2D
	var icon_path := str(offer.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var loaded := load(icon_path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return DEFAULT_ICON


func _offer_row_status(offer: Dictionary) -> String:
	var tier := _required_tier(offer)
	var lock_text := "LOCKED • TIER %d" % tier if tier > _store_tier else "TIER %d" % tier
	return "%s    %s G" % [lock_text, _format_number(_offer_price(offer))]


func _format_number(value: int) -> String:
	var text := str(maxi(0, value))
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
