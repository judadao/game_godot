class_name TownHallUI
extends Control

signal closed
signal opened
signal toggled(is_open: bool)
signal canceled

const BUILDING_ID := &"town_hall"
const RESOURCE_ORDER: Array[StringName] = [
	&"gold",
	&"autumn_wood",
	&"stone",
	&"magic_shard",
	&"autumn_core",
]

@onready var close_button: Button = %CloseButton
@onready var stage_name: Label = %StageName
@onready var stage_index: Label = %StageIndex
@onready var stage_progress: ProgressBar = %StageProgress
@onready var total_level_value: Label = %TotalLevelValue
@onready var record_total_level_value: Label = %RecordTotalLevelValue
@onready var current_level_value: Label = %CurrentLevelValue
@onready var record_hall_level_value: Label = %RecordHallLevelValue
@onready var next_level_value: Label = %NextLevelValue
@onready var level_progress: ProgressBar = %LevelProgress
@onready var upgrade_status: Label = %UpgradeStatus
@onready var requirement_title: Label = %RequirementTitle
@onready var requirement_hint: Label = %RequirementHint
@onready var cost_grid: GridContainer = %CostGrid
@onready var feedback_label: Label = %FeedbackLabel
@onready var upgrade_button: Button = %UpgradeButton
@onready var resource_summary: Label = %ResourceSummary
@onready var gold_value: Label = %GoldValue
@onready var wood_value: Label = %WoodValue
@onready var stone_value: Label = %StoneValue
@onready var shard_value: Label = %ShardValue
@onready var core_value: Label = %CoreValue

var _town: RefCounted
var _inventory: RefCounted
var _context_id: StringName = BUILDING_ID
var _resource_text := ""
var _resource_values: Dictionary
var _cost_amounts: Dictionary
var _cost_states: Dictionary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resource_values = {
		&"gold": gold_value,
		&"autumn_wood": wood_value,
		&"stone": stone_value,
		&"magic_shard": shard_value,
		&"autumn_core": core_value,
	}
	_cost_amounts = {
		&"gold": %GoldCostAmount,
		&"autumn_wood": %WoodCostAmount,
		&"stone": %StoneCostAmount,
		&"magic_shard": %ShardCostAmount,
		&"autumn_core": %CoreCostAmount,
	}
	_cost_states = {
		&"gold": %GoldCostState,
		&"autumn_wood": %WoodCostState,
		&"stone": %StoneCostState,
		&"magic_shard": %ShardCostState,
		&"autumn_core": %CoreCostState,
	}
	close_button.pressed.connect(close)
	upgrade_button.pressed.connect(request_upgrade)
	close_button.focus_neighbor_bottom = close_button.get_path_to(upgrade_button)
	upgrade_button.focus_neighbor_top = upgrade_button.get_path_to(close_button)
	_refresh()
	visible = false


func open() -> void:
	visible = true
	_refresh()
	if upgrade_button.disabled:
		close_button.grab_focus()
	else:
		upgrade_button.grab_focus()
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
	return 1 if upgrade_button != null else 0


func get_resource_text() -> String:
	return _resource_text


func request_upgrade() -> bool:
	if _town == null or upgrade_button.disabled:
		return false
	var upgraded := bool(_town.call("upgrade_building", BUILDING_ID))
	_refresh()
	if upgraded:
		feedback_label.text = "Town Hall upgraded successfully."
		feedback_label.add_theme_color_override("font_color", Color(0.58, 0.92, 0.62))
	else:
		feedback_label.text = "Upgrade could not begin. Review the resource requirements."
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.38))
	return upgraded


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	canceled.emit()
	close()
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not is_node_ready():
		return
	if _town == null or _inventory == null:
		_show_unavailable_state()
		return

	var resources_variant: Variant = _inventory.call("get_resources")
	var resources := (
		(resources_variant as Dictionary)
		if resources_variant is Dictionary
		else {}
	)
	_update_resources(resources)
	_update_village_stage()
	_update_upgrade(resources)


func _show_unavailable_state() -> void:
	_resource_text = "Resources unavailable"
	resource_summary.text = _resource_text
	for resource_id in RESOURCE_ORDER:
		(_resource_values[resource_id] as Label).text = "--"
	stage_name.text = "Village records unavailable"
	stage_index.text = "STAGE -- / 3"
	stage_progress.value = 0.0
	total_level_value.text = "--"
	record_total_level_value.text = "--"
	current_level_value.text = "--"
	record_hall_level_value.text = "--"
	next_level_value.text = "--"
	level_progress.value = 0.0
	upgrade_status.text = "UNAVAILABLE"
	requirement_title.text = "Town services are not connected"
	requirement_hint.text = "Close this window and try the Town Hall again."
	cost_grid.visible = false
	feedback_label.text = "Upgrade data could not be loaded."
	upgrade_button.text = "Upgrade Unavailable"
	upgrade_button.disabled = true


func _update_resources(resources: Dictionary) -> void:
	var summary_parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		var amount := int(resources.get(String(resource_id), 0))
		(_resource_values[resource_id] as Label).text = _format_number(amount)
		summary_parts.append(
			"%s %s" % [_resource_display_name(resource_id), _format_number(amount)]
		)
	_resource_text = "  |  ".join(summary_parts)
	resource_summary.text = _resource_text


func _update_village_stage() -> void:
	var current_stage := clampi(int(_town.call("get_village_stage")), 0, 2)
	var stage_id := String(_town.call("get_village_stage_id"))
	stage_name.text = stage_id.capitalize()
	stage_index.text = "STAGE %d / 3" % (current_stage + 1)
	stage_progress.value = float(current_stage + 1) / 3.0 * 100.0
	var total_levels := str(int(_town.call("get_total_building_levels")))
	total_level_value.text = total_levels
	record_total_level_value.text = total_levels


func _update_upgrade(resources: Dictionary) -> void:
	var level := int(_town.call("get_building_level", BUILDING_ID))
	var max_level := int(_town.call("get_max_building_level", BUILDING_ID))
	var cost_variant: Variant = _town.call("get_next_upgrade_cost", BUILDING_ID)
	var cost := (cost_variant as Dictionary) if cost_variant is Dictionary else {}
	current_level_value.text = "LEVEL %d" % level
	record_hall_level_value.text = "Level %d / %d" % [level, max_level]
	next_level_value.text = "MAX" if cost.is_empty() else "LEVEL %d" % (level + 1)
	level_progress.max_value = maxf(1.0, float(max_level))
	level_progress.value = float(level)

	if cost.is_empty():
		_show_max_level_state(level, max_level)
		return

	var can_upgrade := bool(_town.call("can_upgrade_building", BUILDING_ID))
	upgrade_status.text = "READY" if can_upgrade else "RESOURCES NEEDED"
	upgrade_status.add_theme_color_override(
		"font_color",
		Color(0.58, 0.92, 0.62) if can_upgrade else Color(1.0, 0.66, 0.35)
	)
	requirement_title.text = "Upgrade requirements"
	requirement_hint.text = "Available resources are compared with the next level cost."
	cost_grid.visible = true
	for resource_id in RESOURCE_ORDER:
		_update_cost(resource_id, cost, resources)
	upgrade_button.disabled = not can_upgrade
	upgrade_button.text = "Upgrade to Level %d" % (level + 1)
	feedback_label.text = (
		"All requirements met. The council can begin construction."
		if can_upgrade
		else "Collect the missing materials shown below to unlock this upgrade."
	)
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.66, 0.88, 0.68) if can_upgrade else Color(0.92, 0.72, 0.48)
	)


func _show_max_level_state(level: int, max_level: int) -> void:
	upgrade_status.text = "COMPLETE"
	upgrade_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	requirement_title.text = "Town Hall fully developed"
	requirement_hint.text = "All available Town Hall construction levels are complete."
	cost_grid.visible = false
	upgrade_button.text = "Maximum Level Reached"
	upgrade_button.disabled = true
	feedback_label.text = "Town Hall Level %d / %d" % [level, max_level]
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))


func _update_cost(
	resource_id: StringName,
	cost: Dictionary,
	resources: Dictionary
) -> void:
	var required := int(cost.get(String(resource_id), 0))
	var available := int(resources.get(String(resource_id), 0))
	var amount_label := _cost_amounts[resource_id] as Label
	var state_label := _cost_states[resource_id] as Label
	var enough := available >= required
	amount_label.text = "%s / %s" % [
		_format_number(available),
		_format_number(required),
	]
	state_label.text = "READY" if enough else "NEED %s" % _format_number(required - available)
	var state_color := Color(0.58, 0.92, 0.62) if enough else Color(1.0, 0.56, 0.38)
	amount_label.add_theme_color_override("font_color", state_color)
	state_label.add_theme_color_override("font_color", state_color)


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
