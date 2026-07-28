class_name MaterialYardUI
extends Control

signal opened
signal closed
signal toggled(is_open: bool)
signal canceled

const WORKSHOP_ID: StringName = &"workshop"
const RESOURCE_IDS: Array[StringName] = [
	&"gold",
	&"autumn_wood",
	&"stone",
	&"magic_shard",
	&"autumn_core",
]
const RESOURCE_NAMES := {
	&"gold": "Gold",
	&"autumn_wood": "Autumn Wood",
	&"stone": "Stone",
	&"magic_shard": "Magic Shard",
	&"autumn_core": "Autumn Core",
}

@onready var close_button: Button = %CloseButton
@onready var stage_label: Label = %StageLabel
@onready var resource_summary: Label = %ResourceSummary
@onready var current_level_label: Label = %CurrentLevelLabel
@onready var next_level_label: Label = %NextLevelLabel
@onready var level_progress: ProgressBar = %LevelProgress
@onready var level_one: Label = %LevelOne
@onready var level_two: Label = %LevelTwo
@onready var level_three: Label = %LevelThree
@onready var upgrade_status: Label = %UpgradeStatus
@onready var upgrade_button: Button = %WorkshopUpgradeButton
@onready var details_scroll: ScrollContainer = %DetailsScroll

var _town: RefCounted
var _inventory: RefCounted
var _context_id: StringName = &"material_yard"
var _resource_values: Dictionary = {}
var _cost_cards: Array[PanelContainer] = []
var _cost_names: Array[Label] = []
var _cost_values: Array[Label] = []
var _level_markers: Array[Label] = []
var _feedback := ""
var _feedback_success := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resource_values = {
		&"gold": %GoldValue,
		&"autumn_wood": %WoodValue,
		&"stone": %StoneValue,
		&"magic_shard": %ShardValue,
		&"autumn_core": %CoreValue,
	}
	_cost_cards = [%CostCardOne, %CostCardTwo, %CostCardThree, %CostCardFour, %CostCardFive]
	_cost_names = [%CostNameOne, %CostNameTwo, %CostNameThree, %CostNameFour, %CostNameFive]
	_cost_values = [%CostValueOne, %CostValueTwo, %CostValueThree, %CostValueFour, %CostValueFive]
	_level_markers = [level_one, level_two, level_three]
	close_button.pressed.connect(close)
	upgrade_button.pressed.connect(_upgrade_workshop)
	upgrade_button.focus_entered.connect(_keep_upgrade_action_visible)
	close_button.focus_neighbor_bottom = close_button.get_path_to(upgrade_button)
	upgrade_button.focus_neighbor_top = upgrade_button.get_path_to(close_button)
	upgrade_button.focus_neighbor_right = upgrade_button.get_path_to(close_button)
	_refresh()
	visible = false


func open() -> void:
	var was_visible := visible
	visible = true
	_feedback = ""
	_refresh()
	_focus_primary_action.call_deferred()
	if not was_visible:
		opened.emit()
		toggled.emit(true)


func close() -> void:
	if not visible:
		return
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
	return WORKSHOP_ID


func set_services(town: RefCounted, inventory: RefCounted) -> void:
	_town = town
	_inventory = inventory
	_feedback = ""
	if is_node_ready():
		_refresh()


func get_building_button_count() -> int:
	return 1 if is_instance_valid(upgrade_button) else 0


func get_resource_text() -> String:
	return resource_summary.text if is_instance_valid(resource_summary) else ""


func request_upgrade() -> bool:
	return _upgrade_workshop()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
		close()


func _refresh() -> void:
	if not is_node_ready():
		return
	var resources: Dictionary = {}
	if _inventory != null and _inventory.has_method("get_resources"):
		resources = _inventory.call("get_resources") as Dictionary
	_update_resources(resources)

	if _town == null:
		stage_label.text = "Town services unavailable"
		current_level_label.text = "WORKSHOP  --"
		next_level_label.text = "Connect town services to review upgrades."
		level_progress.value = 0.0
		upgrade_status.text = "The workshop ledger is not available."
		upgrade_button.disabled = true
		upgrade_button.text = "UPGRADE UNAVAILABLE"
		_set_costs({})
		_update_level_markers(0)
		return

	var level := int(_town.call("get_building_level", WORKSHOP_ID))
	var max_level := int(_town.call("get_max_building_level", WORKSHOP_ID))
	var cost := _town.call("get_next_upgrade_cost", WORKSHOP_ID) as Dictionary
	var can_upgrade := (
		not cost.is_empty()
		and _town.has_method("can_upgrade_building")
		and bool(_town.call("can_upgrade_building", WORKSHOP_ID))
	)
	var stage_number := int(_town.call("get_village_stage")) + 1
	var stage_name := String(_town.call("get_village_stage_id")).replace("_", " ").capitalize()

	stage_label.text = "TOWN STAGE %d / 3   •   %s" % [stage_number, stage_name]
	current_level_label.text = "WORKSHOP  LV.%d / %d" % [level, max_level]
	level_progress.max_value = maxf(1.0, float(max_level))
	level_progress.value = float(level)
	_update_level_markers(level)
	_set_costs(cost)

	if cost.is_empty():
		next_level_label.text = "MASTERWORK MATERIAL YARD"
		upgrade_status.text = "All workshop reinforcement tiers are complete."
		upgrade_button.text = "MAXIMUM LEVEL"
		upgrade_button.disabled = true
	elif can_upgrade:
		next_level_label.text = "NEXT: WORKSHOP LV.%d" % (level + 1)
		upgrade_status.text = (
			_feedback
			if not _feedback.is_empty()
			else "Materials ready. Reinforce the workshop to unlock its next town tier."
		)
		upgrade_button.text = "REINFORCE WORKSHOP"
		upgrade_button.disabled = false
	else:
		next_level_label.text = "NEXT: WORKSHOP LV.%d" % (level + 1)
		upgrade_status.text = (
			_feedback
			if not _feedback.is_empty()
			else "Gather the highlighted materials before reinforcing the workshop."
		)
		upgrade_button.text = "MATERIALS REQUIRED"
		upgrade_button.disabled = true

	upgrade_status.add_theme_color_override(
		"font_color",
		Color(0.72, 0.94, 0.70)
		if not _feedback.is_empty() and _feedback_success
		else Color(0.95, 0.78, 0.44),
	)


func _update_resources(resources: Dictionary) -> void:
	var summary_parts: Array[String] = []
	for resource_id in RESOURCE_IDS:
		var amount := int(resources.get(String(resource_id), 0))
		var value_label := _resource_values.get(resource_id) as Label
		if value_label != null:
			value_label.text = _format_number(amount)
		summary_parts.append("%s %s" % [RESOURCE_NAMES[resource_id], _format_number(amount)])
	resource_summary.text = "   •   ".join(summary_parts)


func _set_costs(cost: Dictionary) -> void:
	var cost_ids: Array[StringName] = []
	for resource_id in RESOURCE_IDS:
		if cost.has(String(resource_id)) or cost.has(resource_id):
			cost_ids.append(resource_id)

	for index in _cost_cards.size():
		var card := _cost_cards[index]
		card.visible = index < cost_ids.size()
		if index >= cost_ids.size():
			continue
		var resource_id := cost_ids[index]
		var required := int(cost.get(String(resource_id), cost.get(resource_id, 0)))
		var available := 0
		if _inventory != null and _inventory.has_method("get_resource_amount"):
			available = int(_inventory.call("get_resource_amount", resource_id))
		_cost_names[index].text = String(RESOURCE_NAMES[resource_id]).to_upper()
		_cost_values[index].text = "%s / %s" % [
			_format_number(available),
			_format_number(required),
		]
		_cost_values[index].add_theme_color_override(
			"font_color",
			Color(0.73, 0.94, 0.69) if available >= required else Color(1.0, 0.49, 0.34),
		)


func _update_level_markers(level: int) -> void:
	for index in _level_markers.size():
		var marker := _level_markers[index]
		var reached := index < level
		marker.text = "◆" if reached else "◇"
		marker.add_theme_color_override(
			"font_color",
			Color(1.0, 0.72, 0.28) if reached else Color(0.40, 0.34, 0.28),
		)


func _upgrade_workshop() -> bool:
	if _town == null or not _town.has_method("upgrade_building"):
		return false
	var upgraded := bool(_town.call("upgrade_building", WORKSHOP_ID))
	_feedback_success = upgraded
	_feedback = (
		"Workshop reinforcement complete."
		if upgraded
		else "Upgrade failed. Review the required material amounts."
	)
	_refresh()
	_focus_primary_action.call_deferred()
	return upgraded


func _focus_primary_action() -> void:
	if not visible:
		return
	if upgrade_button.disabled:
		close_button.grab_focus()
	else:
		upgrade_button.grab_focus()


func _keep_upgrade_action_visible() -> void:
	details_scroll.ensure_control_visible(upgrade_button)


func _format_number(value: int) -> String:
	var text := str(maxi(0, value))
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
