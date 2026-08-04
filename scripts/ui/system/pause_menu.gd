extends Control
class_name PauseMenu

signal opened
signal closed
signal toggled(is_open: bool)
signal resume_requested
signal inventory_requested
signal save_requested
signal load_requested
signal settings_requested
signal exit_combat_requested
signal dev_map_requested(scene_path: String)
signal quit_requested

@onready var continue_button: Button = $MenuPanel/Content/ButtonStack/Continue
@onready var inventory_button: Button = $MenuPanel/Content/ButtonStack/Inventory
@onready var save_button: Button = $MenuPanel/Content/ButtonStack/Save
@onready var load_button: Button = $MenuPanel/Content/ButtonStack/Load
@onready var exit_combat_button: Button = $MenuPanel/Content/ButtonStack/ExitCombat
@onready var dev_maps_button: Button = $MenuPanel/Content/ButtonStack/DevMaps
@onready var settings_button: Button = $MenuPanel/Content/ButtonStack/Settings
@onready var quit_button: Button = $MenuPanel/Content/ButtonStack/Quit
@onready var button_stack: VBoxContainer = $MenuPanel/Content/ButtonStack
@onready var settings_panel: VBoxContainer = $MenuPanel/Content/SettingsPanel
@onready var master_volume: HSlider = $MenuPanel/Content/SettingsPanel/MasterVolume
@onready var fullscreen_toggle: CheckButton = $MenuPanel/Content/SettingsPanel/Fullscreen
@onready var settings_back: Button = $MenuPanel/Content/SettingsPanel/Back
@onready var dev_map_panel: VBoxContainer = $MenuPanel/Content/DevMapPanel
@onready var map_options: OptionButton = $MenuPanel/Content/DevMapPanel/MapOptions
@onready var map_travel: Button = $MenuPanel/Content/DevMapPanel/Travel
@onready var map_back: Button = $MenuPanel/Content/DevMapPanel/Back
@onready var footer: Label = $MenuPanel/Content/Footer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_request_resume)
	inventory_button.pressed.connect(inventory_requested.emit)
	save_button.pressed.connect(save_requested.emit)
	load_button.pressed.connect(load_requested.emit)
	exit_combat_button.pressed.connect(exit_combat_requested.emit)
	dev_maps_button.pressed.connect(_open_dev_maps)
	settings_button.pressed.connect(_open_settings)
	settings_back.pressed.connect(_close_settings)
	map_travel.pressed.connect(_request_dev_map)
	map_back.pressed.connect(_close_dev_maps)
	master_volume.value_changed.connect(_set_master_volume)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	quit_button.pressed.connect(quit_requested.emit)
	_sync_settings()
	_set_open(false, false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func open() -> void:
	_set_open(true, true)

func close() -> void:
	settings_panel.visible = false
	dev_map_panel.visible = false
	button_stack.visible = true
	_set_open(false, true)

func toggle() -> void:
	if visible:
		_request_resume()
	else:
		open()

func set_footer_text(text: String) -> void:
	footer.text = text


func configure_dev_mode(enabled: bool, map_entries: Array) -> void:
	dev_maps_button.visible = enabled
	dev_maps_button.disabled = not enabled
	map_options.clear()
	if not enabled:
		dev_map_panel.visible = false
		return
	for entry_variant in map_entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var scene_path := String(entry.get("scene_path", ""))
		if scene_path.is_empty():
			continue
		map_options.add_item(String(entry.get("label", scene_path)))
		map_options.set_item_metadata(map_options.item_count - 1, scene_path)
	map_travel.disabled = map_options.item_count == 0

func set_button_enabled(button_name: String, is_enabled: bool) -> void:
	match button_name.to_lower():
		"continue", "resume":
			continue_button.disabled = not is_enabled
		"inventory":
			inventory_button.disabled = not is_enabled
		"save":
			save_button.disabled = not is_enabled
		"load":
			load_button.disabled = not is_enabled
		"exit_combat", "exit combat":
			exit_combat_button.disabled = not is_enabled
		"dev_maps", "dev maps":
			dev_maps_button.disabled = not is_enabled
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

func _open_settings() -> void:
	button_stack.visible = false
	dev_map_panel.visible = false
	settings_panel.visible = true
	_sync_settings()
	master_volume.grab_focus()
	settings_requested.emit()

func _close_settings() -> void:
	if button_stack == null or settings_panel == null:
		return
	settings_panel.visible = false
	button_stack.visible = true
	if visible:
		settings_button.grab_focus()


func _open_dev_maps() -> void:
	if dev_maps_button.disabled or not dev_maps_button.visible:
		return
	button_stack.visible = false
	settings_panel.visible = false
	dev_map_panel.visible = true
	if map_options.item_count > 0:
		map_options.grab_focus()
	else:
		map_back.grab_focus()


func _close_dev_maps() -> void:
	if button_stack == null or dev_map_panel == null:
		return
	dev_map_panel.visible = false
	button_stack.visible = true
	if visible and dev_maps_button.visible:
		dev_maps_button.grab_focus()


func _request_dev_map() -> void:
	var selected := map_options.selected
	if selected < 0 or selected >= map_options.item_count:
		return
	var scene_path := String(map_options.get_item_metadata(selected))
	if not scene_path.is_empty():
		dev_map_requested.emit(scene_path)

func _sync_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	master_volume.set_value_no_signal(
		db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * 100.0
	)
	fullscreen_toggle.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

func _set_master_volume(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value / 100.0, 0.001)))

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
