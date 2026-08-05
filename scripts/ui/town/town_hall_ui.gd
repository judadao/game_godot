class_name TownHallUI
extends Control

signal closed
signal opened
signal toggled(is_open: bool)
signal canceled
signal building_upgraded(building_id: StringName, level: int)

const BUILDING_ID := &"town_hall"
const AGENDA_OVERVIEW := &"overview"
const AGENDA_UPGRADE := &"hall_upgrade"
const RESOURCE_ORDER: Array[StringName] = [
	&"gold",
	&"autumn_wood",
	&"stone",
	&"magic_shard",
	&"autumn_core",
]
const BUILDING_SUMMARY: Array[Dictionary] = [
	{"id": &"town_hall", "name": "Town Hall", "short_name": "Hall"},
	{"id": &"blacksmith", "name": "Player Workshop", "short_name": "Forge"},
	{"id": &"workshop", "name": "Material Yard", "short_name": "Yard"},
	{"id": &"market", "name": "Market", "short_name": "Market"},
	{"id": &"memory_library", "name": "Memory Library", "short_name": "Library"},
]

@onready var close_button: Button = %CloseButton
@onready var overview_button: Button = %OverviewButton
@onready var hall_upgrade_button: Button = %HallUpgradeButton
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_title: Label = %DetailTitle
@onready var detail_subtitle: Label = %DetailSubtitle
@onready var overview_content: VBoxContainer = %OverviewContent
@onready var upgrade_content: VBoxContainer = %UpgradeContent
@onready var stage_name: Label = %StageName
@onready var stage_index: Label = %StageIndex
@onready var stage_progress: ProgressBar = %StageProgress
@onready var total_level_value: Label = %TotalLevelValue
@onready var building_summary: Label = %BuildingSummary
@onready var current_level_value: Label = %CurrentLevelValue
@onready var next_level_value: Label = %NextLevelValue
@onready var level_progress: ProgressBar = %LevelProgress
@onready var upgrade_status: Label = %UpgradeStatus
@onready var building_project_grid: GridContainer = %BuildingProjectGrid
@onready var town_hall_project_button: Button = %TownHallProjectButton
@onready var blacksmith_project_button: Button = %BlacksmithProjectButton
@onready var workshop_project_button: Button = %WorkshopProjectButton
@onready var market_project_button: Button = %MarketProjectButton
@onready var memory_library_project_button: Button = %MemoryLibraryProjectButton
@onready var upgrade_effect_description: Label = %UpgradeEffectDescription
@onready var cost_summary: Label = %CostSummary
@onready var feedback_label: Label = %FeedbackLabel
@onready var upgrade_button: Button = %UpgradeButton
@onready var resource_summary: Label = %ResourceSummary

var _town: RefCounted
var _inventory: RefCounted
var _context_id: StringName = BUILDING_ID
var _selected_agenda: StringName = AGENDA_OVERVIEW
var _resource_text := ""
var _resources: Dictionary
var _upgrade_cost: Dictionary
var _selected_upgrade_building: StringName = BUILDING_ID
var _project_buttons: Dictionary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	overview_button.pressed.connect(_select_overview)
	hall_upgrade_button.pressed.connect(_select_hall_upgrade)
	upgrade_button.pressed.connect(request_upgrade)
	_project_buttons = {
		&"town_hall": town_hall_project_button,
		&"blacksmith": blacksmith_project_button,
		&"workshop": workshop_project_button,
		&"market": market_project_button,
		&"memory_library": memory_library_project_button,
	}
	for building_id_variant in _project_buttons:
		var building_id := StringName(building_id_variant)
		var button := _project_buttons[building_id] as Button
		button.pressed.connect(select_upgrade_building.bind(building_id))
	_configure_focus()
	_refresh()
	_select_agenda(AGENDA_OVERVIEW)
	visible = false


func open() -> void:
	visible = true
	_refresh()
	_select_agenda(_selected_agenda)
	overview_button.grab_focus()
	opened.emit()
	toggled.emit(true)


func close() -> void:
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
	return BUILDING_ID


func set_services(town: RefCounted, inventory: RefCounted) -> void:
	_town = town
	_inventory = inventory
	if is_node_ready():
		_refresh()


func get_building_button_count() -> int:
	return _project_buttons.size()


func get_resource_text() -> String:
	return _resource_text


func select_upgrade_building(building_id: StringName) -> void:
	if not BUILDING_SUMMARY.any(
		func(building: Dictionary) -> bool: return building["id"] == building_id
	):
		return
	_selected_upgrade_building = building_id
	for button_id_variant in _project_buttons:
		var button_id := StringName(button_id_variant)
		(_project_buttons[button_id] as Button).set_pressed_no_signal(
			button_id == _selected_upgrade_building
		)
	_refresh()
	_select_agenda(AGENDA_UPGRADE)


func get_selected_upgrade_building() -> StringName:
	return _selected_upgrade_building


func request_upgrade() -> bool:
	if _town == null or upgrade_button.disabled:
		return false
	var upgraded := bool(_town.call("upgrade_building", _selected_upgrade_building))
	_refresh()
	_select_agenda(AGENDA_UPGRADE)
	if upgraded:
		var level := int(_town.call("get_building_level", _selected_upgrade_building))
		building_upgraded.emit(_selected_upgrade_building, level)
		feedback_label.text = "Construction approved. Town records are updated."
		feedback_label.add_theme_color_override("font_color", Color(0.58, 0.92, 0.62))
	else:
		feedback_label.text = "Construction cannot begin with the current resources."
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.38))
	return upgraded


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	canceled.emit()
	close()
	get_viewport().set_input_as_handled()


func _select_overview() -> void:
	_select_agenda(AGENDA_OVERVIEW)


func _select_hall_upgrade() -> void:
	_select_agenda(AGENDA_UPGRADE)


func _select_agenda(agenda: StringName) -> void:
	_selected_agenda = agenda
	var showing_overview := agenda == AGENDA_OVERVIEW
	overview_content.visible = showing_overview
	upgrade_content.visible = not showing_overview
	overview_button.button_pressed = showing_overview
	hall_upgrade_button.button_pressed = not showing_overview
	detail_icon.texture = overview_button.icon if showing_overview else hall_upgrade_button.icon
	detail_title.text = "Village Overview" if showing_overview else "Town Development"
	detail_subtitle.text = (
		"Current stage and building readiness at a glance."
		if showing_overview
		else "Choose a building, review its benefit, and approve construction."
	)
	if showing_overview:
		overview_button.grab_focus()
	elif not upgrade_button.disabled:
		upgrade_button.grab_focus()
	else:
		hall_upgrade_button.grab_focus()


func _configure_focus() -> void:
	overview_button.focus_neighbor_bottom = overview_button.get_path_to(hall_upgrade_button)
	hall_upgrade_button.focus_neighbor_top = hall_upgrade_button.get_path_to(overview_button)
	hall_upgrade_button.focus_neighbor_right = hall_upgrade_button.get_path_to(upgrade_button)
	upgrade_button.focus_neighbor_left = upgrade_button.get_path_to(hall_upgrade_button)
	close_button.focus_neighbor_bottom = close_button.get_path_to(overview_button)
	overview_button.focus_neighbor_top = overview_button.get_path_to(close_button)


func _refresh() -> void:
	if not is_node_ready():
		return
	if _town == null or _inventory == null:
		_show_unavailable_state()
		return
	var resources_variant: Variant = _inventory.call("get_resources")
	_resources = (resources_variant as Dictionary) if resources_variant is Dictionary else {}
	_update_resources()
	_update_village_overview()
	_update_upgrade()


func _show_unavailable_state() -> void:
	_resources.clear()
	_upgrade_cost.clear()
	_resource_text = "Resources unavailable"
	resource_summary.text = _resource_text
	stage_name.text = "Village records unavailable"
	stage_index.text = "STAGE -- / 3"
	stage_progress.value = 0.0
	total_level_value.text = "--"
	building_summary.text = "Building records are not connected."
	current_level_value.text = "LEVEL --"
	next_level_value.text = "LEVEL --"
	level_progress.value = 0.0
	upgrade_status.text = "UNAVAILABLE"
	cost_summary.text = "Reconnect town services to review construction costs."
	feedback_label.text = "The mayor cannot access the council ledger."
	upgrade_button.text = "Upgrade Unavailable"
	upgrade_button.disabled = true


func _update_resources() -> void:
	var summary_parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		var amount := int(_resources.get(String(resource_id), 0))
		summary_parts.append(
			"%s %s" % [_resource_display_name(resource_id), _format_number(amount)]
		)
	_resource_text = "  |  ".join(summary_parts)
	resource_summary.text = _resource_text


func _update_village_overview() -> void:
	var current_stage := clampi(int(_town.call("get_village_stage")), 0, 2)
	var stage_id := String(_town.call("get_village_stage_id"))
	stage_name.text = stage_id.capitalize()
	stage_index.text = "STAGE %d / 3" % (current_stage + 1)
	stage_progress.value = float(current_stage + 1) / 3.0 * 100.0
	total_level_value.text = str(int(_town.call("get_total_building_levels")))

	var lines: Array[String] = []
	for building in BUILDING_SUMMARY:
		var building_id := building["id"] as StringName
		var level := int(_town.call("get_building_level", building_id))
		var maximum := int(_town.call("get_max_building_level", building_id))
		lines.append("%s    Lv.%d / %d" % [building["name"], level, maximum])
	building_summary.text = "\n".join(lines)


func _update_upgrade() -> void:
	var level := int(_town.call("get_building_level", _selected_upgrade_building))
	var max_level := int(_town.call("get_max_building_level", _selected_upgrade_building))
	var building_name := String(_town.call("get_building_name", _selected_upgrade_building))
	var upgrade_variant: Variant = _town.call("get_next_upgrade", _selected_upgrade_building)
	var upgrade_data := (upgrade_variant as Dictionary) if upgrade_variant is Dictionary else {}
	var cost_variant: Variant = _town.call("get_next_upgrade_cost", _selected_upgrade_building)
	_upgrade_cost = (cost_variant as Dictionary) if cost_variant is Dictionary else {}
	for building in BUILDING_SUMMARY:
		var building_id := building["id"] as StringName
		var button := _project_buttons.get(building_id) as Button
		if button == null:
			continue
		var project_level := int(_town.call("get_building_level", building_id))
		var project_max := int(_town.call("get_max_building_level", building_id))
		button.text = "%s %d/%d" % [building["short_name"], project_level, project_max]
		button.set_pressed_no_signal(building_id == _selected_upgrade_building)
	current_level_value.text = "LEVEL %d" % level
	next_level_value.text = "MAX" if _upgrade_cost.is_empty() else "LEVEL %d" % (level + 1)
	level_progress.max_value = maxf(1.0, float(max_level))
	level_progress.value = float(level)

	if _upgrade_cost.is_empty():
		upgrade_status.text = "COMPLETE"
		upgrade_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
		cost_summary.text = "No further construction is available."
		upgrade_button.text = "Maximum Level Reached"
		upgrade_button.disabled = true
		upgrade_effect_description.text = "%s is fully developed." % building_name
		feedback_label.text = "%s Level %d / %d" % [building_name, level, max_level]
		return

	upgrade_effect_description.text = "%s — %s" % [
		String(upgrade_data.get("name", "Next Upgrade")),
		String(upgrade_data.get("description", "")),
	]
	var can_upgrade := bool(_town.call("can_upgrade_building", _selected_upgrade_building))
	upgrade_status.text = "READY" if can_upgrade else "RESOURCES NEEDED"
	upgrade_status.add_theme_color_override(
		"font_color",
		Color(0.58, 0.92, 0.62) if can_upgrade else Color(1.0, 0.66, 0.35)
	)
	cost_summary.text = _format_upgrade_cost(_upgrade_cost)
	upgrade_button.disabled = not can_upgrade
	upgrade_button.text = "Upgrade %s to Level %d" % [building_name, level + 1]
	feedback_label.text = (
		"All requirements met. Construction can begin."
		if can_upgrade
		else "Missing amounts are highlighted in the cost list."
	)
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.66, 0.88, 0.68) if can_upgrade else Color(0.92, 0.72, 0.48)
	)


func _format_upgrade_cost(cost: Dictionary) -> String:
	var lines: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		var required := int(cost.get(String(resource_id), 0))
		if required <= 0:
			continue
		var available := int(_resources.get(String(resource_id), 0))
		var state := "READY" if available >= required else "NEED %s" % _format_number(required - available)
		lines.append(
			"%s    %s / %s    %s"
			% [
				_resource_display_name(resource_id),
				_format_number(available),
				_format_number(required),
				state,
			]
		)
	return "\n".join(lines)


func _resource_display_name(resource_id: StringName) -> String:
	match resource_id:
		&"autumn_wood":
			return "Autumn Wood"
		&"magic_shard":
			return "Magic Shards"
		&"autumn_core":
			return "Autumn Cores"
		_:
			return String(resource_id).capitalize()


func _format_number(value: int) -> String:
	var text := str(maxi(0, value))
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result
