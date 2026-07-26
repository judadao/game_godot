class_name DeckBuilderUI
extends Control

signal deck_confirmed(deck_ids: Array[String])
signal canceled

const REQUIRED_DECK_SIZE := 16
const FIXED_CARD_IDS: Array[String] = ["ember_bolt", "quickstep"]

var _catalog: Array[Dictionary] = []
var _counts: Dictionary = {}
var _rows: Dictionary = {}
var _count_label: Label
var _confirm_button: Button
var _card_list: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()


func configure(cards: Array, current_deck: Array) -> void:
	_catalog.clear()
	_counts.clear()
	for card_variant in cards:
		if card_variant is Dictionary:
			var card := (card_variant as Dictionary).duplicate(true)
			_catalog.append(card)
			_counts[String(card.get("id", ""))] = 0
	for card_id_variant in current_deck:
		var card_id := String(card_id_variant)
		if _counts.has(card_id):
			_counts[card_id] = int(_counts[card_id]) + 1
	for fixed_id in FIXED_CARD_IDS:
		if _counts.has(fixed_id):
			_counts[fixed_id] = 1
	if is_node_ready():
		_rebuild_cards()


func get_selected_deck() -> Array[String]:
	var result: Array[String] = []
	for card in _catalog:
		var card_id := String(card.get("id", ""))
		for _copy in int(_counts.get(card_id, 0)):
			result.append(card_id)
	return result


func get_selected_count() -> int:
	return get_selected_deck().size()


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430, -310)
	panel.size = Vector2(860, 620)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "AUTUMN EXPEDITION — BUILD A DECK (MAX 16)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Ember Bolt and Quickstep are fixed. Bring up to 14 more cards. Normal: 3 copies; rare Combo: 1."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_card_list)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	column.add_child(footer)
	_count_label = Label.new()
	_count_label.custom_minimum_size = Vector2(180, 42)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_count_label)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(130, 42)
	cancel_button.pressed.connect(func() -> void: canceled.emit())
	footer.add_child(cancel_button)
	_confirm_button = Button.new()
	_confirm_button.text = "Enter Forest"
	_confirm_button.custom_minimum_size = Vector2(180, 42)
	_confirm_button.pressed.connect(func() -> void: deck_confirmed.emit(get_selected_deck()))
	footer.add_child(_confirm_button)
	_rebuild_cards()


func _rebuild_cards() -> void:
	if _card_list == null:
		return
	for child in _card_list.get_children():
		child.queue_free()
	_rows.clear()
	for card in _catalog:
		var card_id := String(card.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_card_list.add_child(row)
		var info := Label.new()
		info.text = "%s  [%s / %s]  AP %d\n%s" % [
			String(card.get("name", card_id)),
			String(card.get("type", "")).to_upper(),
			String(card.get("rarity", "")).to_upper(),
			int(card.get("cost", 0)),
			String(card.get("description", "")),
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.custom_minimum_size = Vector2(560, 52)
		row.add_child(info)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(42, 42)
		minus.pressed.connect(_change_count.bind(card_id, -1))
		row.add_child(minus)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.custom_minimum_size = Vector2(42, 42)
		row.add_child(count)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(42, 42)
		plus.pressed.connect(_change_count.bind(card_id, 1))
		row.add_child(plus)
		_rows[card_id] = {"count": count, "minus": minus, "plus": plus, "card": card}
	_update_controls()


func _change_count(card_id: String, amount: int) -> void:
	if not _rows.has(card_id):
		return
	var card := (_rows[card_id] as Dictionary)["card"] as Dictionary
	var max_copies := 1 if String(card.get("type", "")) == "combo" or FIXED_CARD_IDS.has(card_id) else 3
	var min_copies := 1 if FIXED_CARD_IDS.has(card_id) else 0
	var current := int(_counts.get(card_id, 0))
	if amount > 0 and get_selected_count() >= REQUIRED_DECK_SIZE:
		return
	_counts[card_id] = clampi(current + amount, min_copies, max_copies)
	_update_controls()


func _update_controls() -> void:
	var total := get_selected_count()
	for card_id in _rows:
		var row := _rows[card_id] as Dictionary
		var card := row["card"] as Dictionary
		var current := int(_counts.get(card_id, 0))
		var max_copies := 1 if String(card.get("type", "")) == "combo" or FIXED_CARD_IDS.has(card_id) else 3
		var min_copies := 1 if FIXED_CARD_IDS.has(card_id) else 0
		(row["count"] as Label).text = "%d/%d" % [current, max_copies]
		(row["minus"] as Button).disabled = current <= min_copies
		(row["plus"] as Button).disabled = current >= max_copies or total >= REQUIRED_DECK_SIZE
	if _count_label != null:
		_count_label.text = "BACKPACK  %d / %d MAX" % [total, REQUIRED_DECK_SIZE]
		_count_label.modulate = Color(0.55, 1.0, 0.65) if total > 0 else Color(1.0, 0.72, 0.35)
	if _confirm_button != null:
		_confirm_button.disabled = total <= 0 or total > REQUIRED_DECK_SIZE
