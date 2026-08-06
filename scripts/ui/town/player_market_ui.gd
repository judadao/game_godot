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
@onready var context_content: VBoxContainer = %Content
@onready var context_dock: PanelContainer = %ContextDock
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var shelves_panel: PanelContainer = %ShelvesPanel
@onready var rumor_panel: PanelContainer = %RumorPanel
@onready var store_interior: PanelContainer = %StoreInterior
@onready var interior_canvas: Control = $SafeMargin/PlayerMarketWindow/WindowMargin/MarketLayout/StoreInterior/InteriorCanvas
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
var _visitor_states: Array[Dictionary] = []
var _visitor_textures: Array[Texture2D] = []

const VISITOR_SIZE := Vector2(118.0, 118.0)
const VISITOR_ROUTES := [
	[
		Vector2(0.93, 0.98),
		Vector2(0.82, 0.98),
		Vector2(0.58, 0.97),
		Vector2(0.26, 0.96),
		Vector2(0.48, 0.98),
		Vector2(0.78, 0.98),
		Vector2(0.93, 0.98),
	],
	[
		Vector2(0.93, 0.96),
		Vector2(0.88, 0.96),
		Vector2(0.66, 0.95),
		Vector2(0.34, 0.94),
		Vector2(0.72, 0.98),
		Vector2(0.93, 0.96),
	],
]


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
	_configure_scene_focus_navigation()
	visible = false
	call_deferred("_apply_viewport_scale")


func open() -> void:
	visible = true
	_apply_viewport_scale()
	_ambient_origins.clear()
	call_deferred("_capture_ambient_origins")
	_customer_check_elapsed = 0.0
	_customer_check_pending = false
	_hide_context(false)
	_refresh()
	product_interact_buttons[mini(_selected_shelf, product_interact_buttons.size() - 1)].grab_focus.call_deferred()


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
	_hide_context(false)
	_visitor_states.clear()


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
		button.focus_mode = Control.FOCUS_ALL
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
	context_dock.visible = true
	context_bar.visible = true
	context_content.visible = true
	inventory_panel.visible = context_id == &"stock"
	shelves_panel.visible = context_id == &"shelves"
	rumor_panel.visible = context_id == &"rumor"
	context_title.text = {
		&"stock": "櫃台補貨  ·  貨架 %d" % (_selected_shelf + 1),
		&"shelves": "展示架  ·  選擇要檢查的貨架",
		&"rumor": "店內傳聞  ·  符合流言的商品更容易高價售出",
	}.get(context_id, "店內互動")
	var focus_target: Control = _candidate_buttons[0] if not _candidate_buttons.is_empty() else quick_button
	if context_id == &"shelves":
		focus_target = shelf_buttons[_selected_shelf]
	elif context_id == &"rumor":
		focus_target = context_close_button
	if focus_target != null:
		focus_target.grab_focus()


func _hide_context(restore_focus: bool = true) -> void:
	if not is_node_ready():
		return
	context_dock.visible = false
	context_bar.visible = false
	context_content.visible = false
	inventory_panel.visible = false
	shelves_panel.visible = false
	rumor_panel.visible = false
	if restore_focus and product_interact_buttons.size() > 0:
		product_interact_buttons[mini(_selected_shelf, product_interact_buttons.size() - 1)].grab_focus.call_deferred()


func _capture_ambient_origins() -> void:
	_ambient_origins = {
		"protagonist": protagonist_visual.position,
		"counter_customer": counter_customer_npc.position,
		"browsing_customer": browsing_customer_npc.position,
		"queue_customer": queue_customer_npc.position,
	}
	_setup_visitors()


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
	_advance_visitors(delta)
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


func get_active_visitor_count() -> int:
	var count := 0
	for state in _visitor_states:
		var node := state.get("node") as TextureRect
		if node != null and node.visible:
			count += 1
	return count


func get_visitor_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for state in _visitor_states:
		var node := state.get("node") as TextureRect
		if node != null:
			positions.append(node.position)
	return positions


func debug_advance_visitors(seconds: float) -> void:
	var remaining := maxf(0.0, seconds)
	while remaining > 0.0:
		var step := minf(0.1, remaining)
		_advance_visitors(step)
		remaining -= step


func _setup_visitors() -> void:
	_visitor_textures = [
		browsing_customer_npc.texture,
		queue_customer_npc.texture,
		counter_customer_npc.texture,
	]
	_visitor_states.clear()
	var visitor_nodes: Array[TextureRect] = [browsing_customer_npc, queue_customer_npc]
	for index in visitor_nodes.size():
		var node := visitor_nodes[index]
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.size = VISITOR_SIZE
		node.visible = true
		_visitor_states.append({
			"node": node,
			"route": VISITOR_ROUTES[index],
			"segment": index,
			"progress": 0.16 + float(index) * 0.28,
			"speed": 72.0 + float(index) * 11.0,
			"pause": 0.0,
			"laps": index,
		})
	_advance_visitors(0.0)


func _advance_visitors(delta: float) -> void:
	if interior_canvas == null or interior_canvas.size.x <= 1.0:
		return
	for state_index in _visitor_states.size():
		var state := _visitor_states[state_index]
		var node := state.get("node") as TextureRect
		var route := state.get("route", []) as Array
		if node == null or route.size() < 2:
			continue
		var pause := maxf(0.0, float(state.get("pause", 0.0)) - delta)
		state["pause"] = pause
		if pause > 0.0:
			_apply_visitor_position(state)
			_visitor_states[state_index] = state
			continue
		var segment := clampi(int(state.get("segment", 0)), 0, route.size() - 2)
		var from := (route[segment] as Vector2) * interior_canvas.size
		var to := (route[segment + 1] as Vector2) * interior_canvas.size
		var distance := maxf(1.0, from.distance_to(to))
		var progress := float(state.get("progress", 0.0)) + float(state.get("speed", 72.0)) * delta / distance
		while progress >= 1.0:
			progress -= 1.0
			segment += 1
			if segment >= route.size() - 1:
				segment = 0
				var laps := int(state.get("laps", 0)) + 1
				state["laps"] = laps
				node.texture = _visitor_textures[(laps + state_index) % _visitor_textures.size()]
			if segment in [1, 2, 3]:
				state["pause"] = 0.55 + float((segment + state_index) % 3) * 0.28
				break
		state["segment"] = segment
		state["progress"] = progress
		_visitor_states[state_index] = state
		_apply_visitor_position(state)


func _apply_visitor_position(state: Dictionary) -> void:
	var node := state.get("node") as TextureRect
	var route := state.get("route", []) as Array
	var segment := clampi(int(state.get("segment", 0)), 0, route.size() - 2)
	var progress := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	var from := (route[segment] as Vector2) * interior_canvas.size
	var to := (route[segment + 1] as Vector2) * interior_canvas.size
	var foot_position := from.lerp(to, progress)
	node.position = foot_position - Vector2(VISITOR_SIZE.x * 0.5, VISITOR_SIZE.y)
	node.position.y += sin(_ambient_time * 5.0 + float(segment)) * 1.5
	var entrance_fade := 1.0
	if segment == 0:
		entrance_fade = smoothstep(0.0, 0.72, progress)
	elif segment == route.size() - 2:
		entrance_fade = smoothstep(1.0, 0.28, progress)
	node.modulate.a = entrance_fade
	node.z_index = 3 + clampi(roundi(foot_position.y / 120.0), 0, 3)
	if node == browsing_customer_npc:
		customer_interact_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		customer_interact_button.position = node.position
		customer_interact_button.size = VISITOR_SIZE


func _configure_scene_focus_navigation() -> void:
	for index in product_interact_buttons.size():
		var button := product_interact_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		if index > 0:
			button.focus_neighbor_left = button.get_path_to(product_interact_buttons[index - 1])
		if index < product_interact_buttons.size() - 1:
			button.focus_neighbor_right = button.get_path_to(product_interact_buttons[index + 1])
	product_interact_buttons[0].focus_neighbor_left = product_interact_buttons[0].get_path_to(shelf_interact_button)
	product_interact_buttons[-1].focus_neighbor_right = product_interact_buttons[-1].get_path_to(bell_interact_button)
	shelf_interact_button.focus_neighbor_right = shelf_interact_button.get_path_to(product_interact_buttons[0])
	bell_interact_button.focus_neighbor_left = bell_interact_button.get_path_to(product_interact_buttons[-1])
	bell_interact_button.focus_neighbor_right = bell_interact_button.get_path_to(door_interact_button)
	door_interact_button.focus_neighbor_left = door_interact_button.get_path_to(bell_interact_button)


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
