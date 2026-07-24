extends Control
class_name PauseMenu

signal opened
signal closed
signal toggled(is_open: bool)
signal resume_requested
signal inventory_requested
signal settings_requested
signal quit_requested

@onready var continue_button: Button = $MenuPanel/Content/ButtonStack/Continue
@onready var inventory_button: Button = $MenuPanel/Content/ButtonStack/Inventory
@onready var settings_button: Button = $MenuPanel/Content/ButtonStack/Settings
@onready var quit_button: Button = $MenuPanel/Content/ButtonStack/Quit
@onready var footer: Label = $MenuPanel/Content/Footer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_request_resume)
	inventory_button.pressed.connect(inventory_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	_set_open(false, false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func open() -> void:
	_set_open(true, true)

func close() -> void:
	_set_open(false, true)

func toggle() -> void:
	if visible:
		_request_resume()
	else:
		open()

func set_footer_text(text: String) -> void:
	footer.text = text

func set_button_enabled(button_name: String, is_enabled: bool) -> void:
	match button_name.to_lower():
		"continue", "resume":
			continue_button.disabled = not is_enabled
		"inventory":
			inventory_button.disabled = not is_enabled
		"settings":
			settings_button.disabled = not is_enabled
		"quit":
			quit_button.disabled = not is_enabled

func _set_open(is_open: bool, should_emit: bool) -> void:
	visible = is_open
	if is_open:
		continue_button.grab_focus()
	if not should_emit:
		return
	if is_open:
		opened.emit()
	else:
		closed.emit()
	toggled.emit(is_open)

func _request_resume() -> void:
	resume_requested.emit()
	close()
