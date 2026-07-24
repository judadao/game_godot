extends Control
class_name DialogueUI

signal opened
signal closed
signal toggled(is_open: bool)
signal advanced
signal choice_selected(index: int, text: String, metadata: Dictionary)
signal canceled

@onready var speaker_name: Label = $DialoguePanel/SpeakerNamePlate/SpeakerName
@onready var portrait_initial: Label = $DialoguePanel/PortraitFrame/PortraitPlaceholder/PortraitInitial
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueText
@onready var choices_container: VBoxContainer = $DialoguePanel/ChoicesContainer
@onready var next_arrow: TextureRect = $DialoguePanel/NextArrowIndicator

var choices: Array[Dictionary] = []
var _choice_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cache_choice_buttons()
	next_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	next_arrow.gui_input.connect(_on_next_arrow_input)
	_bootstrap_placeholder_choices()
	_set_open(false, false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		advanced.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		canceled.emit()
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	_set_open(true, true)

func close() -> void:
	_set_open(false, true)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func set_speaker_name(display_name: String) -> void:
	speaker_name.text = display_name
	if not display_name.is_empty():
		portrait_initial.text = display_name.substr(0, 1).to_upper()

func set_dialogue_text(text: String) -> void:
	dialogue_text.text = text

func set_choices(new_choices: Array) -> void:
	choices = _to_dictionary_array(new_choices)
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		button.visible = index < choices.size()
		button.disabled = index >= choices.size()
		if index < choices.size():
			button.text = str(choices[index].get("text", "Choice %d" % (index + 1)))
			button.tooltip_text = str(choices[index].get("tooltip", ""))

func set_portrait_initial(initial: String) -> void:
	portrait_initial.text = initial.substr(0, 1).to_upper() if not initial.is_empty() else "?"

func _cache_choice_buttons() -> void:
	_choice_buttons.clear()
	for child in choices_container.get_children():
		if child is Button:
			var button := child as Button
			_choice_buttons.append(button)
			var index := _choice_buttons.size() - 1
			button.pressed.connect(func() -> void:
				_emit_choice(index)
			)

func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if not should_emit:
		return
	if is_open:
		opened.emit()
	else:
		closed.emit()
	toggled.emit(is_open)

func _bootstrap_placeholder_choices() -> void:
	if not choices.is_empty():
		return
	for button in _choice_buttons:
		choices.append({"text": button.text})

func _emit_choice(index: int) -> void:
	if index < 0 or index >= choices.size():
		return
	var choice := choices[index]
	choice_selected.emit(index, str(choice.get("text", "")), choice)

func _to_dictionary_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result

func _on_next_arrow_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advanced.emit()
