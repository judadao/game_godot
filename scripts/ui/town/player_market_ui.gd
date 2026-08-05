class_name PlayerMarketUI
extends Control

signal back_requested
signal list_for_sale_requested(
	item_kind: StringName,
	item_id: StringName,
	quality: StringName,
	price_strategy: StringName,
	shelf_index: int
)
signal customer_purchase_check_requested(shelf_index: int)
signal market_fixture_purchase_requested(fixture_id: StringName)

@onready var back_button: Button = %BackButton
@onready var resource_summary: Label = %MarketResourceSummary
@onready var candidate_list: VBoxContainer = %MarketCandidateList
@onready var candidate_template: Button = %MarketCandidateTemplate
@onready var candidate_empty: Label = %MarketCandidateEmpty
@onready var quick_button: Button = %MarketQuickButton
@onready var fair_button: Button = %MarketFairButton
@onready var luxury_button: Button = %MarketLuxuryButton
@onready var list_button: Button = %MarketListButton
@onready var shelf_buttons: Array[Button] = [
	%MarketShelf1Button,
	%MarketShelf2Button,
	%MarketShelf3Button,
	%MarketShelf4Button,
	%MarketShelf5Button,
	%MarketShelf6Button,
]
@onready var item_name: Label = %MarketItemName
@onready var item_status: Label = %MarketItemStatus
@onready var customer_status: Label = %MarketCustomerStatus
@onready var rumor_label: Label = %MarketRumorLabel
@onready var feedback_label: Label = %MarketFeedbackLabel
@onready var fixture_button: Button = %MarketFixtureButton
@onready var product_labels: Array[Label] = [%Product1, %Product2, %Product3]
@onready var customer_speech: Label = %MarketCustomerSpeech
@onready var context_bar: HBoxContainer = %ContextBar
@onready var context_title: Label = %ContextTitle
@onready var context_close_button: Button = %ContextCloseButton
@onready var context_content: HBoxContainer = %Content
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var shelves_panel: PanelContainer = %ShelvesPanel
@onready var rumor_panel: PanelContainer = %RumorPanel
@onready var store_interior: PanelContainer = %StoreInterior
@onready var shelf_interact_button: Button = %ShelfInteractButton
@onready var product_interact_buttons: Array[Button] = [
	%Product1InteractButton,
	%Product2InteractButton,
	%Product3InteractButton,
]
@onready var customer_interact_button: Button = %CustomerInteractButton
@onready var bell_interact_button: Button = %BellInteractButton
@onready var door_interact_button: Button = %DoorInteractButton
@onready var protagonist_visual: Control = %Protagonist
@onready var counter_customer_npc: TextureRect = %CounterCustomerNPC
@onready var browsing_customer_npc: TextureRect = %BrowsingCustomerNPC
@onready var queue_customer_npc: TextureRect = %QueueCustomerNPC
@onready var player_market_window: PanelContainer = $SafeMargin/PlayerMarketWindow

var _inventory: RefCounted
var _sale_overview: Dictionary = {}
var _shelves: Array[Dictionary] = []
var _candidates: Array[Dictionary] = []
var _candidate_buttons: Array[Button] = []
var _selected_shelf := 0
var _selected_candidate_key := ""
var _price_strategy: StringName = &"fair"
var _normal_style: StyleBox
var _selected_style: StyleBox
var _ambient_time := 0.0
var _ambient_origins: Dictionary = {}
var _customer_check_elapsed := 0.0
var _customer_check_pending := false
var _customer_check_cursor := 0
var _next_customer_check := 2.4


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal_style = fair_button.get_theme_stylebox("normal")
	_selected_style = fair_button.get_theme_stylebox("pressed")
	back_button.pressed.connect(_request_back)
	quick_button.pressed.connect(_select_price_strategy.bind(&"quick"))
	fair_button.pressed.connect(_select_price_strategy.bind(&"fair"))
	luxury_button.pressed.connect(_select_price_strategy.bind(&"luxury"))
	list_button.pressed.connect(_request_listing)
	fixture_button.pressed.connect(_request_fixture_purchase)
	context_close_button.pressed.connect(_hide_context)
	shelf_interact_button.pressed.connect(_show_context.bind(&"shelves"))
	for product_index in product_interact_buttons.size():
		product_interact_buttons[product_index].pressed.connect(
			_open_product_context.bind(product_index)
		)
	customer_interact_button.pressed.connect(_show_customer_comment)
	bell_interact_button.pressed.connect(_show_context.bind(&"rumor"))
	door_interact_button.pressed.connect(_request_back)
	resized.connect(_apply_viewport_scale)
	for shelf_index in shelf_buttons.size():
		shelf_buttons[shelf_index].pressed.connect(select_shelf.bind(shelf_index))
	visible = false
	call_deferred("_apply_viewport_scale")


func open() -> void:
	visible = true
	_apply_viewport_scale()
	_ambient_origins.clear()
	call_deferred("_capture_ambient_origins")
	_customer_check_elapsed = 0.0
	_customer_check_pending = false
	_hide_context()
	_refresh()
	if _selected_shelf < shelf_buttons.size() and shelf_buttons[_selected_shelf].visible:
		shelf_buttons[_selected_shelf].grab_focus()


func _apply_viewport_scale() -> void:
	if player_market_window == null:
		return
	var reference_size := Vector2(1280.0, 720.0)
	var window_size := Vector2(1040.0, 640.0)
	var viewport_scale := minf(size.x / reference_size.x, size.y / reference_size.y)
	viewport_scale = clampf(viewport_scale, 0.78, 2.0)
	player_market_window.size = window_size
	player_market_window.position = (size - window_size) * 0.5
	player_market_window.pivot_offset = window_size * 0.5
	player_market_window.scale = Vector2.ONE * viewport_scale


func close() -> void:
	visible = false
	_hide_context()


func set_services(inventory: RefCounted) -> void:
	_inventory = inventory
	_refresh_resources()


func set_sale_state(state: Dictionary) -> void:
	_sale_overview = state.duplicate(true)
	_customer_check_pending = false
	_candidates.clear()
	for candidate_variant in state.get("candidates", []) as Array:
		if candidate_variant is Dictionary:
			_candidates.append((candidate_variant as Dictionary).duplicate(true))
	_shelves.clear()
	for shelf_variant in state.get("shelves", []) as Array:
		if shelf_variant is Dictionary:
			_shelves.append((shelf_variant as Dictionary).duplicate(true))
	var capacity := clampi(int(state.get("capacity", maxi(2, _shelves.size()))), 1, 6)
	while _shelves.size() < capacity:
		_shelves.append({"shelf_index": _shelves.size(), "status": "empty"})
	_selected_shelf = clampi(_selected_shelf, 0, capacity - 1)
	if _find_candidate(_selected_candidate_key).is_empty():
		_selected_candidate_key = (
			_candidate_key(_candidates[0]) if not _candidates.is_empty() else ""
		)
	if is_node_ready():
		_refresh()


func select_shelf(shelf_index: int) -> void:
	if shelf_index < 0 or shelf_index >= _shelves.size():
		return
	_selected_shelf = shelf_index
	_refresh()


func get_selected_shelf() -> int:
	return _selected_shelf


func show_sale_result(result: Dictionary) -> void:
	var success := bool(result.get("ok", false))
	var gold := int(result.get("gold", 0))
	feedback_label.text = (
		"成交完成  ·  +%d GOLD" % gold
		if success and gold > 0 else String(result.get("message", "交易未完成。"))
	)
	feedback_label.modulate = Color(1.0, 0.82, 0.34) if success else Color(1.0, 0.55, 0.44)
	customer_speech.text = (
		"「買到了，謝謝！」"
		if success else "「這個價格……我再考慮一下。」"
	)


func show_action_result(result: Dictionary) -> void:
	var success := bool(result.get("ok", false))
	feedback_label.text = String(result.get("message", "商店狀態已更新。"))
	feedback_label.modulate = Color(0.56, 0.94, 0.72) if success else Color(1.0, 0.55, 0.44)


func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_resources()
	_refresh_candidates()
	_refresh_shelves()
	_refresh_store_interior()
	_refresh_detail()
	_refresh_fixture()
	_refresh_price_buttons()


func _refresh_resources() -> void:
	var gold := 0
	if _inventory != null and _inventory.has_method("get_resource_amount"):
		gold = int(_inventory.call("get_resource_amount", &"gold"))
	resource_summary.text = "店鋪資金  ·  %s GOLD   |   貨架 %d / %d" % [
		_format_number(gold),
		_occupied_shelf_count(),
		int(_sale_overview.get("capacity", maxi(2, _shelves.size()))),
	]


func _refresh_candidates() -> void:
	for button in _candidate_buttons:
		if is_instance_valid(button):
			button.visible = false
			button.queue_free()
	_candidate_buttons.clear()
	candidate_empty.visible = _candidates.is_empty()
	for candidate in _candidates:
		var key := _candidate_key(candidate)
		var button := candidate_template.duplicate() as Button
		button.visible = true
		button.text = "%s\n%s  ·  ×%d  ·  %d GOLD" % [
			String(candidate.get("item_name", candidate.get("item_id", ""))),
			String(candidate.get("quality_label", "普通")),
			int(candidate.get("count", 0)),
			int(candidate.get("unit_price", 0)),
		]
		button.button_pressed = key == _selected_candidate_key
		button.pressed.connect(_select_candidate.bind(key))
		candidate_list.add_child(button)
		_candidate_buttons.append(button)


func _refresh_shelves() -> void:
	var capacity := clampi(int(_sale_overview.get("capacity", maxi(2, _shelves.size()))), 1, 6)
	for shelf_index in shelf_buttons.size():
		var button := shelf_buttons[shelf_index]
		button.visible = shelf_index < capacity
		if not button.visible:
			continue
		var shelf := _shelf(shelf_index)
		var status := String(shelf.get("status", "empty"))
		var label := "空貨架"
		if status == "customer_ready":
			label = String(shelf.get("item_name", "待售商品"))
		elif status == "customer_declined":
			label = "等待重新補貨"
		button.text = "貨架 %d\n%s" % [shelf_index + 1, label]
		button.button_pressed = shelf_index == _selected_shelf
		button.add_theme_stylebox_override(
			"normal", _selected_style if shelf_index == _selected_shelf else _normal_style
		)


func _refresh_detail() -> void:
	var shelf := _shelf(_selected_shelf)
	var status := String(shelf.get("status", "empty"))
	var candidate := _find_candidate(_selected_candidate_key)
	if status == "empty":
		item_name.text = String(candidate.get("item_name", "選擇左側商品"))
		item_status.text = (
			"這個貨架目前空著，可用左側商品補貨。"
			if candidate.is_empty() else "%s  ·  庫存 ×%d" % [
				String(candidate.get("quality_label", "普通")),
				int(candidate.get("count", 0)),
			]
		)
		customer_status.text = "補貨並定價後，顧客會自動逛店與決定是否購買。"
	else:
		item_name.text = String(shelf.get("item_name", "已上架商品"))
		item_status.text = String(shelf.get("table_label", "商品正在貨架上展示。"))
		customer_status.text = String(shelf.get("customer_label", "等待顧客。"))
	rumor_label.text = (
		"✦ %s\n%s 將以 %.0f%% 價格來訪" % [
			String(shelf.get("rumor_title", "流言菲語")),
			String(shelf.get("customer_name", "特別顧客")),
			float(shelf.get("rumor_multiplier", 1.0)) * 100.0,
		]
		if not String(shelf.get("rumor_id", "")).is_empty()
		else "◇ 流言菲語\n選擇符合流言的商品，能吸引願意高價收購的特別顧客。"
	)
	list_button.disabled = status != "empty" or candidate.is_empty()


func _refresh_store_interior() -> void:
	var displayed_products: Array[String] = []
	for shelf in _shelves:
		if String(shelf.get("status", "empty")) == "empty":
			continue
		displayed_products.append(String(shelf.get("item_name", "商品")))
	for index in product_labels.size():
		product_labels[index].text = "%s %s" % [
			["▣", "◆", "✦"][index],
			displayed_products[index] if index < displayed_products.size() else "待補貨",
		]
	var selected := _shelf(_selected_shelf)
	customer_speech.text = (
		"「%s，我想買這個！」" % String(selected.get("customer_name", "客人"))
		if String(selected.get("status", "empty")) == "customer_ready"
		else "「今天有什麼好貨？」"
	)


func _refresh_price_buttons() -> void:
	var buttons := {&"quick": quick_button, &"fair": fair_button, &"luxury": luxury_button}
	for strategy in buttons:
		var button := buttons[strategy] as Button
		button.button_pressed = strategy == _price_strategy
		button.add_theme_stylebox_override(
			"normal", _selected_style if strategy == _price_strategy else _normal_style
		)
	quick_button.text = "親民 80%"
	fair_button.text = "公道 100%"
	luxury_button.text = "精品 135%"


func _refresh_fixture() -> void:
	var fixture_state := _sale_overview.get("fixture_state", {}) as Dictionary
	var active := fixture_state.get("active", {}) as Dictionary
	var next_fixture := fixture_state.get("next", {}) as Dictionary
	if next_fixture.is_empty():
		fixture_button.text = "目前櫃台：%s · 已達最高階" % String(active.get("name", "木製交易台"))
		fixture_button.disabled = true
		return
	var required_level := int(next_fixture.get("required_market_level", 0))
	var cost := next_fixture.get("cost", {}) as Dictionary
	fixture_button.text = (
		"建築 Lv.%d 才能裝設：%s（%d 格）" % [
			required_level,
			String(next_fixture.get("name", "新櫃台")),
			int(next_fixture.get("capacity", 2)),
		]
		if not bool(next_fixture.get("building_ready", false)) else
		"購買並裝設：%s（%d 格） · %s" % [
			String(next_fixture.get("name", "新櫃台")),
			int(next_fixture.get("capacity", 2)),
			_cost_text(cost),
		]
	)
	fixture_button.disabled = not bool(next_fixture.get("can_purchase", false))


func _show_context(context_id: StringName) -> void:
	context_bar.visible = true
	context_content.visible = true
	inventory_panel.visible = context_id == &"stock"
	shelves_panel.visible = context_id in [&"stock", &"shelves"]
	rumor_panel.visible = context_id == &"rumor"
	store_interior.custom_minimum_size.y = 180.0
	context_title.text = {
		&"stock": "櫃台商品  ·  選擇庫存與定價後補貨",
		&"shelves": "展示架  ·  選擇要檢查的貨架",
		&"rumor": "店內傳聞  ·  符合流言的商品更容易高價售出",
	}.get(context_id, "店內互動")
	var focus_target: Control = quick_button
	if context_id == &"shelves":
		focus_target = shelf_buttons[_selected_shelf]
	elif context_id == &"rumor":
		focus_target = context_close_button
	if focus_target != null:
		focus_target.grab_focus()


func _hide_context() -> void:
	if not is_node_ready():
		return
	context_bar.visible = false
	context_content.visible = false
	inventory_panel.visible = false
	shelves_panel.visible = false
	rumor_panel.visible = false
	store_interior.custom_minimum_size.y = 350.0
	if shelf_interact_button != null:
		shelf_interact_button.grab_focus.call_deferred()


func _capture_ambient_origins() -> void:
	_ambient_origins = {
		"protagonist": protagonist_visual.position,
		"counter_customer": counter_customer_npc.position,
		"browsing_customer": browsing_customer_npc.position,
		"queue_customer": queue_customer_npc.position,
	}


func _process(delta: float) -> void:
	if not visible or _ambient_origins.is_empty():
		return
	_ambient_time += delta
	protagonist_visual.position = _ambient_origins["protagonist"] + Vector2(
		0.0, sin(_ambient_time * 1.6) * 1.5
	)
	counter_customer_npc.position = _ambient_origins["counter_customer"] + Vector2(
		sin(_ambient_time * 0.7) * 3.0, sin(_ambient_time * 1.4) * 1.5
	)
	browsing_customer_npc.position = _ambient_origins["browsing_customer"] + Vector2(
		sin(_ambient_time * 0.38) * 20.0, sin(_ambient_time * 1.1) * 1.0
	)
	queue_customer_npc.position = _ambient_origins["queue_customer"] + Vector2(
		sin(_ambient_time * 0.5) * 5.0, sin(_ambient_time * 1.25) * 1.5
	)
	if _customer_check_pending:
		return
	_customer_check_elapsed += delta
	if _customer_check_elapsed < _next_customer_check:
		return
	_customer_check_elapsed = 0.0
	var shelf_index := _next_occupied_shelf()
	if shelf_index < 0:
		return
	_customer_check_pending = true
	customer_speech.text = "「讓我看看這件商品……」"
	customer_purchase_check_requested.emit(shelf_index)


func _select_candidate(key: String) -> void:
	if _find_candidate(key).is_empty():
		return
	_selected_candidate_key = key
	_refresh()


func _select_price_strategy(strategy: StringName) -> void:
	_price_strategy = strategy
	_refresh_price_buttons()


func _request_listing() -> void:
	var candidate := _find_candidate(_selected_candidate_key)
	if candidate.is_empty():
		return
	list_for_sale_requested.emit(
		StringName(candidate.get("item_kind", "")),
		StringName(candidate.get("item_id", "")),
		StringName(candidate.get("quality", "common")),
		_price_strategy,
		_selected_shelf
	)


func _request_fixture_purchase() -> void:
	var fixture_state := _sale_overview.get("fixture_state", {}) as Dictionary
	var next_fixture := fixture_state.get("next", {}) as Dictionary
	if not bool(next_fixture.get("can_purchase", false)):
		return
	market_fixture_purchase_requested.emit(StringName(next_fixture.get("id", "")))


func _open_product_context(product_index: int) -> void:
	if product_index >= 0 and product_index < _shelves.size():
		select_shelf(product_index)
	_show_context(&"stock" if String(_shelf(_selected_shelf).get("status", "empty")) == "empty" else &"shelves")


func _show_customer_comment() -> void:
	customer_speech.text = "「我會自己慢慢挑，老闆忙補貨就好。」"


func _next_occupied_shelf() -> int:
	if _shelves.is_empty():
		return -1
	for offset in _shelves.size():
		var index := (_customer_check_cursor + offset) % _shelves.size()
		if String(_shelf(index).get("status", "empty")) == "customer_ready":
			_customer_check_cursor = (index + 1) % _shelves.size()
			return index
	return -1


func _request_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_request_back()
		get_viewport().set_input_as_handled()


func _shelf(index: int) -> Dictionary:
	return _shelves[index] if index >= 0 and index < _shelves.size() else {"status": "empty"}


func _occupied_shelf_count() -> int:
	var count := 0
	for shelf in _shelves:
		if String(shelf.get("status", "empty")) != "empty":
			count += 1
	return count


func _candidate_key(candidate: Dictionary) -> String:
	return "%s:%s:%s" % [
		candidate.get("item_kind", ""),
		candidate.get("item_id", ""),
		candidate.get("quality", "common"),
	]


func _find_candidate(key: String) -> Dictionary:
	for candidate in _candidates:
		if _candidate_key(candidate) == key:
			return candidate
	return {}


func _format_number(value: int) -> String:
	var source := str(value)
	var result := ""
	while source.length() > 3:
		result = "," + source.substr(source.length() - 3, 3) + result
		source = source.substr(0, source.length() - 3)
	return source + result


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_variant in cost:
		parts.append("%s %d" % [String(resource_variant).replace("_", " ").capitalize(), int(cost[resource_variant])])
	return " / ".join(parts)
