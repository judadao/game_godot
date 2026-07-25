class_name LevelUpUI
extends Control

signal choice_selected(choice: Dictionary)

var _choices: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _selected := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()


func set_choices(choices: Array) -> void:
	_choices.clear()
	for choice_variant in choices:
		if choice_variant is Dictionary and _choices.size() < 3:
			_choices.append((choice_variant as Dictionary).duplicate(true))
	_selected = false
	_refresh()


func get_choice_button_count() -> int:
	return _buttons.size()


func select_choice(index: int) -> void:
	if _selected or index < 0 or index >= _choices.size():
		return
	_selected = true
	for button in _buttons:
		button.disabled = true
	choice_selected.emit(_choices[index].duplicate(true))


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.04, 0.94)
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-380, -230)
	column.size = Vector2(760, 460)
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var title := Label.new()
	title.text = "LEVEL UP — CHOOSE ONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	for index in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(720, 105)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(select_choice.bind(index))
		column.add_child(button)
		_buttons.append(button)
	_refresh()


func _refresh() -> void:
	if _buttons.is_empty():
		return
	for index in 3:
		var available := index < _choices.size()
		_buttons[index].visible = available
		_buttons[index].disabled = not available or _selected
		if available:
			_buttons[index].text = String(_choices[index].get("text", "Upgrade"))
