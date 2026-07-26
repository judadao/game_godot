class_name CardDiscardUI
extends Control

signal discard_confirmed(indices: Array[int])

var _cards: Array[Dictionary] = []
var _required_count := 0
var _protected_indices: Array[int] = []
var _selected: Array[int] = []
var _buttons: Array[Button] = []
var _status: Label
var _confirm: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()


func configure(cards: Array, required_count: int, protected_card_ids: Variant = []) -> void:
	_cards.clear()
	for card_variant in cards:
		if card_variant is Dictionary:
			_cards.append((card_variant as Dictionary).duplicate(true))
	_required_count = maxi(0, required_count)
	var protected_lookup: Dictionary = {}
	if protected_card_ids is String:
		protected_lookup[String(protected_card_ids)] = true
	elif protected_card_ids is Array:
		for card_id in protected_card_ids:
			protected_lookup[String(card_id)] = true
	_protected_indices.clear()
	for index in _cards.size():
		if protected_lookup.has(String(_cards[index].get("id", ""))):
			_protected_indices.append(index)
	_selected.clear()
	if is_node_ready():
		_rebuild_cards()


func get_protected_index() -> int:
	return _protected_indices[0] if not _protected_indices.is_empty() else -1


func get_protected_indices() -> Array[int]:
	return _protected_indices.duplicate()


func get_selected_indices() -> Array[int]:
	return _selected.duplicate()


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.035, 0.94)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-460, -265)
	panel.size = Vector2(920, 530)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "HAND OVERFLOW — CHOOSE CARDS TO DISCARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	var grid := GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	_confirm = Button.new()
	_confirm.text = "Confirm Discard"
	_confirm.custom_minimum_size = Vector2(220, 44)
	_confirm.pressed.connect(func() -> void: discard_confirmed.emit(_selected.duplicate()))
	column.add_child(_confirm)
	_rebuild_cards()


func _rebuild_cards() -> void:
	var grid := find_child("CardGrid", true, false) as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	_buttons.clear()
	for index in _cards.size():
		var card := _cards[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 96)
		button.toggle_mode = true
		button.text = "%s\n%s  AP %d" % [
			String(card.get("name", "Card")),
			"FIXED CARD" if _protected_indices.has(index) else String(card.get("type", "")).to_upper(),
			int(card.get("cost", 0)),
		]
		button.disabled = _protected_indices.has(index)
		button.toggled.connect(_toggle_card.bind(index))
		grid.add_child(button)
		_buttons.append(button)
	_update_status()


func _toggle_card(pressed: bool, index: int) -> void:
	if _protected_indices.has(index):
		return
	if pressed:
		if _selected.size() >= _required_count:
			_buttons[index].set_pressed_no_signal(false)
			return
		_selected.append(index)
	else:
		_selected.erase(index)
	_update_status()


func _update_status() -> void:
	if _status != null:
		_status.text = "Select exactly %d card(s):  %d / %d  (fixed cards are protected)" % [
			_required_count, _selected.size(), _required_count,
		]
	if _confirm != null:
		_confirm.disabled = _selected.size() != _required_count
