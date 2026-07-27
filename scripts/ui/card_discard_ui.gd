class_name CardDiscardUI
extends Control

signal discard_confirmed(indices: Array[int])
signal skipped

var _cards: Array[Dictionary] = []
var _required_count := 0
var _title_text := "HAND OVERFLOW — CHOOSE CARDS TO DISCARD"
var _allow_skip := false
var _protected_indices: Array[int] = []
var _selected: Array[int] = []
var _buttons: Array[Button] = []
var _title_label: Label
var _status: Label
var _confirm: Button
var _skip: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()


func configure(
	cards: Array,
	required_count: int,
	protected_card_ids: Variant = [],
	title_text: String = "",
	allow_skip: bool = false
) -> void:
	_cards.clear()
	for card_variant in cards:
		if card_variant is Dictionary:
			_cards.append((card_variant as Dictionary).duplicate(true))
	_required_count = maxi(0, required_count)
	_title_text = (
		title_text.strip_edges()
		if not title_text.strip_edges().is_empty()
		else "HAND OVERFLOW — CHOOSE CARDS TO DISCARD"
	)
	_allow_skip = allow_skip
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


func is_skip_available() -> bool:
	return _skip != null and _skip.visible


func select_index(index: int) -> void:
	if index < 0 or index >= _buttons.size() or _buttons[index].disabled:
		return
	_buttons[index].set_pressed_no_signal(true)
	_toggle_card(true, index)


func confirm_selection() -> void:
	if _confirm != null and not _confirm.disabled:
		discard_confirmed.emit(_selected.duplicate())


func skip_reward() -> void:
	if _allow_skip:
		skipped.emit()


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
	_title_label = Label.new()
	_title_label.text = _title_text
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 23)
	column.add_child(_title_label)
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
	_confirm.pressed.connect(confirm_selection)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_skip = Button.new()
	_skip.text = "Skip Reward"
	_skip.custom_minimum_size = Vector2(180, 44)
	_skip.pressed.connect(skip_reward)
	footer.add_child(_skip)
	footer.add_child(_confirm)
	_rebuild_cards()


func _rebuild_cards() -> void:
	var grid := find_child("CardGrid", true, false) as GridContainer
	if grid == null:
		return
	_title_label.text = _title_text
	_skip.visible = _allow_skip
	_confirm.text = "Replace Card" if _allow_skip else "Confirm Discard"
	for child in grid.get_children():
		child.queue_free()
	_buttons.clear()
	for index in _cards.size():
		var card := _cards[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 96)
		button.toggle_mode = true
		button.text = "%s\n%s  LV.%d  AP %d" % [
			String(card.get("name", "Card")),
			"FIXED CARD" if _protected_indices.has(index) else String(card.get("type", "")).to_upper(),
			maxi(1, int(card.get("card_level", card.get("level", 1)))),
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
		_status.text = (
			"Choose one existing card to replace, or skip this reward."
			if _allow_skip
			else "Select exactly %d card(s):  %d / %d  (protected cards cannot be selected)" % [
				_required_count, _selected.size(), _required_count,
			]
		)
	if _confirm != null:
		_confirm.disabled = _selected.size() != _required_count
