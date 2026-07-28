class_name PlayerBlacksmithUI
extends Control

signal closed
signal blueprint_research_requested
signal opened
signal toggled(is_open: bool)
signal canceled

const VALID_SERVICES: Array[StringName] = [&"forge", &"soul_refinery"]
const RESOURCE_ORDER: Array[StringName] = [
	&"gold",
	&"autumn_wood",
	&"stone",
	&"magic_shard",
	&"autumn_core",
]
const RESOURCE_LABELS := {
	&"gold": "Gold",
	&"autumn_wood": "Wood",
	&"stone": "Stone",
	&"magic_shard": "Shards",
	&"autumn_core": "Cores",
}
const EQUIPMENT_ICON_PATHS := {
	&"iron_sword": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png",
	&"hunter_bow": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/BlueSet_0000_Weapon.png",
	&"apprentice_staff": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/StealSet_0000_Weapon.png",
	&"leather_armor": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0003_Chest.png",
	&"chain_armor": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/StealSet_0003_Chest.png",
	&"mage_robe": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/BlueSet_0003_Chest.png",
	&"swift_ring": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_05.png",
	&"vitality_charm": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_01.png",
	&"focus_amulet": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_06.png",
	&"merchant_seal": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png",
}
const SLOT_LABELS := {
	&"weapon": "Weapon",
	&"armor": "Armor",
	&"accessory": "Accessory",
}
const SLOT_SHORT_LABELS := {
	&"weapon": "WPN",
	&"armor": "ARM",
	&"accessory": "ACC",
}

@onready var close_button: Button = %CloseButton
@onready var forge_service_button: Button = %ForgeServiceButton
@onready var research_service_button: Button = %ResearchServiceButton
@onready var soul_service_button: Button = %RefineryServiceButton
@onready var stage_label: Label = %StageLabel
@onready var resource_summary: Label = %ResourceSummary
@onready var equipment_scroll: ScrollContainer = %EquipmentScroll
@onready var equipment_list: GridContainer = %EquipmentList
@onready var equipment_row_template: Button = %EquipmentRowTemplate
@onready var empty_catalog_label: Label = %EmptyCatalogLabel
@onready var forge_workspace: HBoxContainer = %ForgeWorkspace
@onready var soul_workspace: HBoxContainer = %SoulWorkspace
@onready var item_preview: TextureRect = %ItemPreview
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_slot_label: Label = %ItemSlotLabel
@onready var item_status_label: Label = %ItemStatusLabel
@onready var item_effects_label: RichTextLabel = %ItemEffectsLabel
@onready var purchase_cost_label: Label = %PurchaseCostLabel
@onready var purchase_button: Button = %PurchaseButton
@onready var equip_button: Button = %EquipButton
@onready var strengthen_button: Button = %StrengthenButton
@onready var action_feedback: Label = %ActionFeedback
@onready var forge_level_label: Label = %ForgeLevelLabel
@onready var forge_upgrade_cost_label: Label = %ForgeUpgradeCostLabel
@onready var forge_upgrade_button: Button = %UpgradeButton
@onready var soul_level_label: Label = %SoulLevelLabel
@onready var soul_capacity_label: Label = %SoulCapacityLabel
@onready var soul_upgrade_cost_label: Label = %SoulUpgradeCostLabel
@onready var soul_upgrade_button: Button = %SoulUpgradeButton

var _town: RefCounted
var _inventory: RefCounted
var _context_id: StringName = &"player_blacksmith"
var _blacksmith_service: StringName = &"forge"
var _selected_equipment: StringName
var _equipment_buttons: Array[Button] = []
var _building_buttons: Array[Button] = []
var _equipment_by_id: Dictionary = {}
var _icon_cache: Dictionary = {}
var _row_normal_style: StyleBox
var _row_selected_style: StyleBox
var _service_normal_style: StyleBox
var _service_selected_style: StyleBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cache_authored_styles()
	_connect_controls()
	visible = false
	_apply_service()
	_refresh()


func open() -> void:
	var was_visible := visible
	_blacksmith_service = &"forge"
	visible = true
	_apply_service()
	_refresh()
	_focus_current_workspace()
	if not was_visible:
		opened.emit()
		toggled.emit(true)


func close() -> void:
	if not visible:
		return
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and (focused == self or is_ancestor_of(focused)):
		focused.release_focus()
	closed.emit()
	toggled.emit(false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func set_context(context_id: StringName) -> void:
	_context_id = context_id
	if is_node_ready():
		_refresh()


func get_context_id() -> StringName:
	return _context_id


func get_building_id() -> StringName:
	return &"blacksmith"


func set_services(town: RefCounted, inventory: RefCounted) -> void:
	_town = town
	_inventory = inventory
	if is_node_ready():
		_refresh()


func select_blacksmith_service(service_id: StringName) -> void:
	if not VALID_SERVICES.has(service_id):
		return
	_blacksmith_service = service_id
	if not is_node_ready():
		return
	_apply_service()
	_refresh()
	_focus_current_workspace()


func select_service(service_id: StringName) -> void:
	select_blacksmith_service(service_id)


func get_blacksmith_service() -> StringName:
	return _blacksmith_service


func get_selected_service() -> StringName:
	return get_blacksmith_service()


func request_blueprint_research() -> void:
	if _context_id == &"player_blacksmith":
		blueprint_research_requested.emit()


func get_building_button_count() -> int:
	return _building_buttons.size()


func get_equipment_button_count() -> int:
	return _equipment_buttons.size()


func get_resource_text() -> String:
	return resource_summary.text if resource_summary != null else ""


func select_equipment(item_id: StringName) -> void:
	if not _equipment_by_id.has(item_id):
		return
	_selected_equipment = item_id
	_refresh_equipment_rows()
	_refresh_equipment_detail()


func purchase_selected_equipment() -> void:
	if not _can_use_inventory() or _selected_equipment.is_empty():
		return
	var succeeded := bool(_inventory.call("purchase_equipment", _selected_equipment))
	_set_feedback(
		"Equipment added to your forge inventory." if succeeded
		else "Missing materials or this equipment is already owned.",
		succeeded
	)
	_refresh()


func equip_selected_equipment() -> void:
	if not _can_use_inventory() or _selected_equipment.is_empty():
		return
	var succeeded := bool(_inventory.call("equip", _selected_equipment))
	_set_feedback(
		"Equipment is now fitted to your loadout." if succeeded
		else "Purchase this equipment before equipping it.",
		succeeded
	)
	_refresh()


func strengthen_selected_equipment() -> void:
	if not _can_use_inventory() or _selected_equipment.is_empty():
		return
	var succeeded := bool(_inventory.call("upgrade_equipment", _selected_equipment))
	_set_feedback(
		"Tempering complete. Equipment level increased." if succeeded
		else "Strengthening is locked, complete, or lacks materials.",
		succeeded
	)
	_refresh()


func upgrade_service_building() -> void:
	request_upgrade()


func request_upgrade() -> bool:
	if not _can_use_town():
		return false
	var building_id := _active_building_id()
	var succeeded := bool(_town.call("upgrade_building", building_id))
	_set_feedback(
		"Facility upgrade complete." if succeeded
		else "This facility is complete or requires more materials.",
		succeeded
	)
	_refresh()
	return succeeded


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		canceled.emit()
		close()
		get_viewport().set_input_as_handled()


func _cache_authored_styles() -> void:
	_row_normal_style = equipment_row_template.get_theme_stylebox("normal")
	_row_selected_style = equipment_row_template.get_theme_stylebox("pressed")
	_service_normal_style = soul_service_button.get_theme_stylebox("normal")
	_service_selected_style = forge_service_button.get_theme_stylebox("normal")


func _connect_controls() -> void:
	close_button.pressed.connect(close)
	forge_service_button.pressed.connect(select_blacksmith_service.bind(&"forge"))
	research_service_button.pressed.connect(request_blueprint_research)
	soul_service_button.pressed.connect(select_blacksmith_service.bind(&"soul_refinery"))
	purchase_button.pressed.connect(purchase_selected_equipment)
	equip_button.pressed.connect(equip_selected_equipment)
	strengthen_button.pressed.connect(strengthen_selected_equipment)
	forge_upgrade_button.pressed.connect(upgrade_service_building)
	soul_upgrade_button.pressed.connect(upgrade_service_building)


func _apply_service() -> void:
	var forge_selected := _blacksmith_service == &"forge"
	forge_workspace.visible = forge_selected
	soul_workspace.visible = not forge_selected
	forge_service_button.add_theme_stylebox_override(
		"normal",
		_service_selected_style if forge_selected else _service_normal_style
	)
	soul_service_button.add_theme_stylebox_override(
		"normal",
		_service_selected_style if not forge_selected else _service_normal_style
	)
	_building_buttons.clear()
	_building_buttons.append(forge_upgrade_button if forge_selected else soul_upgrade_button)


func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_resources()
	_refresh_stage()
	_refresh_equipment_catalog()
	_refresh_equipment_detail()
	_refresh_facility()


func _refresh_resources() -> void:
	var resources: Dictionary = {}
	if _can_use_inventory():
		resources = _inventory.call("get_resources") as Dictionary
	var summary_parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		var amount := int(resources.get(String(resource_id), 0))
		var amount_label := get_node_or_null(
			"%sAmount" % _resource_node_prefix(resource_id)
		) as Label
		if amount_label != null:
			amount_label.text = _format_number(amount)
		summary_parts.append("%s %s" % [RESOURCE_LABELS[resource_id], _format_number(amount)])
	resource_summary.text = "  |  ".join(summary_parts)


func _refresh_stage() -> void:
	if not _can_use_town():
		stage_label.text = "Village data unavailable"
		return
	stage_label.text = "Village Stage %d / 3  ·  %s" % [
		int(_town.call("get_village_stage")) + 1,
		String(_town.call("get_village_stage_id")).capitalize(),
	]


func _refresh_equipment_catalog() -> void:
	_clear_equipment_rows()
	_equipment_by_id.clear()
	if not _can_use_inventory():
		empty_catalog_label.visible = true
		return
	var catalog := _inventory.call("get_equipment_catalog") as Array
	for item_variant in catalog:
		if not item_variant is Dictionary:
			continue
		var item := (item_variant as Dictionary).duplicate(true)
		var item_id := StringName(item.get("id", ""))
		if item_id.is_empty():
			continue
		_equipment_by_id[item_id] = item
		var button := equipment_row_template.duplicate() as Button
		button.name = "Equipment_%s" % String(item_id)
		button.visible = true
		button.disabled = false
		button.icon = _equipment_icon(item_id)
		button.tooltip_text = "Select %s" % String(item.get("name", item_id))
		button.pressed.connect(select_equipment.bind(item_id))
		button.focus_entered.connect(_on_equipment_focused.bind(item_id, button))
		equipment_list.add_child(button)
		_equipment_buttons.append(button)
	empty_catalog_label.visible = _equipment_buttons.is_empty()
	if _selected_equipment.is_empty() or not _equipment_by_id.has(_selected_equipment):
		_selected_equipment = (
			StringName(_equipment_by_id.keys()[0]) if not _equipment_by_id.is_empty()
			else StringName()
		)
	_refresh_equipment_rows()
	_configure_focus_navigation()


func _clear_equipment_rows() -> void:
	for button in _equipment_buttons:
		if is_instance_valid(button):
			button.free()
	_equipment_buttons.clear()


func _refresh_equipment_rows() -> void:
	for button in _equipment_buttons:
		var item_id := StringName(button.name.trim_prefix("Equipment_"))
		var item := _equipment_by_id.get(item_id, {}) as Dictionary
		var level := int(_inventory.call("get_equipment_level", item_id))
		var owned := bool(_inventory.call("has_equipment", item_id))
		var slot := StringName(item.get("slot", ""))
		var equipped := owned and StringName(_inventory.call("get_equipped", slot)) == item_id
		var state := "EQUIPPED" if equipped else ("OWNED" if owned else "SALE")
		button.text = "%s\n%s  ·  L%d  ·  %s" % [
			String(item.get("name", item_id)),
			SLOT_SHORT_LABELS.get(slot, String(slot).to_upper()),
			level,
			state,
		]
		button.add_theme_stylebox_override(
			"normal",
			_row_selected_style if item_id == _selected_equipment else _row_normal_style
		)


func _refresh_equipment_detail() -> void:
	if not _can_use_inventory() or not _equipment_by_id.has(_selected_equipment):
		_show_empty_equipment_detail()
		return
	var item := _equipment_by_id[_selected_equipment] as Dictionary
	var slot := StringName(item.get("slot", ""))
	var owned := bool(_inventory.call("has_equipment", _selected_equipment))
	var level := int(_inventory.call("get_equipment_level", _selected_equipment))
	var equipped := owned and StringName(_inventory.call("get_equipped", slot)) == _selected_equipment
	var purchase_cost := item.get("purchase_cost", {}) as Dictionary
	var upgrade_cost := _inventory.call(
		"get_equipment_upgrade_cost",
		_selected_equipment
	) as Dictionary
	item_preview.texture = _equipment_icon(_selected_equipment)
	item_name_label.text = String(item.get("name", _selected_equipment))
	item_slot_label.text = "%s EQUIPMENT  ·  LEVEL %d / 3" % [
		String(SLOT_LABELS.get(slot, String(slot).capitalize())).to_upper(),
		level,
	]
	item_status_label.text = "EQUIPPED" if equipped else ("OWNED" if owned else "AVAILABLE")
	item_status_label.modulate = (
		Color(0.48, 0.94, 0.76) if equipped
		else (Color(0.94, 0.78, 0.39) if owned else Color(0.62, 0.78, 0.96))
	)
	item_effects_label.text = _format_item_effects(item)
	purchase_cost_label.text = (
		"Purchase complete" if owned
		else "Purchase  ·  %s" % _format_cost(purchase_cost)
	)
	purchase_button.visible = not owned
	purchase_button.disabled = owned or not bool(_inventory.call("can_afford", purchase_cost))
	equip_button.visible = owned
	equip_button.disabled = not owned or equipped
	equip_button.text = "Equipped" if equipped else "Equip"
	strengthen_button.visible = owned
	strengthen_button.disabled = not owned or upgrade_cost.is_empty()
	strengthen_button.text = (
		"Max Level" if owned and level >= 3
		else "Strengthen  ·  %s" % _format_cost(upgrade_cost)
	)


func _show_empty_equipment_detail() -> void:
	item_preview.texture = null
	item_name_label.text = "No Equipment Selected"
	item_slot_label.text = "FORGE CATALOG"
	item_status_label.text = "WAITING"
	item_effects_label.text = "Select an equipment icon to inspect its effects."
	purchase_cost_label.text = ""
	purchase_button.visible = true
	purchase_button.disabled = true
	equip_button.visible = false
	strengthen_button.visible = false


func _refresh_facility() -> void:
	if not _can_use_town():
		_set_facility_unavailable()
		return
	var building_id := _active_building_id()
	var level := int(_town.call("get_building_level", building_id))
	var max_level := int(_town.call("get_max_building_level", building_id))
	var cost := _town.call("get_next_upgrade_cost", building_id) as Dictionary
	var can_upgrade := bool(_town.call("can_upgrade_building", building_id))
	if building_id == &"blacksmith":
		forge_level_label.text = "Forge Facility  ·  Level %d / %d" % [level, max_level]
		forge_upgrade_cost_label.text = (
			"All forge improvements complete." if cost.is_empty()
			else "Next facility tier  ·  %s" % _format_cost(cost)
		)
		forge_upgrade_button.text = "Max Level" if cost.is_empty() else "Upgrade Forge"
		forge_upgrade_button.disabled = not can_upgrade
	else:
		soul_level_label.text = "Soul Refinery  ·  Level %d / %d" % [level, max_level]
		soul_capacity_label.text = "Memory Capacity  ·  %d skills" % int(
			_town.call("get_skill_memory_capacity")
		)
		soul_upgrade_cost_label.text = (
			"Refinery resonance is fully stabilized." if cost.is_empty()
			else "Next resonance tier  ·  %s" % _format_cost(cost)
		)
		soul_upgrade_button.text = "Max Level" if cost.is_empty() else "Upgrade Refinery"
		soul_upgrade_button.disabled = not can_upgrade


func _set_facility_unavailable() -> void:
	forge_level_label.text = "Forge facility unavailable"
	forge_upgrade_cost_label.text = ""
	forge_upgrade_button.disabled = true
	soul_level_label.text = "Soul Refinery unavailable"
	soul_capacity_label.text = "Memory Capacity unavailable"
	soul_upgrade_cost_label.text = ""
	soul_upgrade_button.disabled = true


func _configure_focus_navigation() -> void:
	forge_service_button.focus_neighbor_bottom = forge_service_button.get_path_to(
		_equipment_buttons[0] if not _equipment_buttons.is_empty() else close_button
	)
	research_service_button.focus_neighbor_bottom = research_service_button.get_path_to(close_button)
	soul_service_button.focus_neighbor_bottom = soul_service_button.get_path_to(soul_upgrade_button)
	for index in _equipment_buttons.size():
		var button := _equipment_buttons[index]
		button.focus_neighbor_top = button.get_path_to(
			forge_service_button if index == 0 else _equipment_buttons[index - 1]
		)
		button.focus_neighbor_bottom = button.get_path_to(
			purchase_button if index == _equipment_buttons.size() - 1
			else _equipment_buttons[index + 1]
		)
		button.focus_neighbor_right = button.get_path_to(purchase_button)
	purchase_button.focus_neighbor_left = purchase_button.get_path_to(
		_equipment_buttons[0] if not _equipment_buttons.is_empty() else forge_service_button
	)
	purchase_button.focus_neighbor_right = purchase_button.get_path_to(equip_button)
	equip_button.focus_neighbor_left = equip_button.get_path_to(purchase_button)
	equip_button.focus_neighbor_right = equip_button.get_path_to(strengthen_button)
	strengthen_button.focus_neighbor_left = strengthen_button.get_path_to(equip_button)
	forge_upgrade_button.focus_neighbor_top = forge_upgrade_button.get_path_to(strengthen_button)
	soul_upgrade_button.focus_neighbor_top = soul_upgrade_button.get_path_to(soul_service_button)


func _focus_current_workspace() -> void:
	if not visible:
		return
	if _blacksmith_service == &"soul_refinery":
		soul_upgrade_button.grab_focus()
	elif not _equipment_buttons.is_empty():
		var selected_button := _equipment_buttons[0]
		for button in _equipment_buttons:
			if button.name == "Equipment_%s" % String(_selected_equipment):
				selected_button = button
				break
		selected_button.grab_focus()
	else:
		forge_service_button.grab_focus()


func _on_equipment_focused(
	item_id: StringName,
	button: Button
) -> void:
	select_equipment(item_id)
	equipment_scroll.ensure_control_visible(button)


func _equipment_icon(item_id: StringName) -> Texture2D:
	if _icon_cache.has(item_id):
		return _icon_cache[item_id] as Texture2D
	var path := String(EQUIPMENT_ICON_PATHS.get(item_id, ""))
	var texture: Texture2D
	if not path.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_icon_cache[item_id] = texture
	return texture


func _format_item_effects(item: Dictionary) -> String:
	var lines: Array[String] = ["[color=#f5ca63][b]Equipment Effects[/b][/color]"]
	var effects := item.get("effects", {}) as Dictionary
	for effect_id in effects:
		lines.append("• %s  [color=#f6e4bd]%s[/color]" % [
			String(effect_id).capitalize(),
			_format_effect_value(String(effect_id), effects[effect_id]),
		])
	var ability := item.get("special_ability", {}) as Dictionary
	var description := String(ability.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append("")
		lines.append("[color=#82c9e8][b]Tempered Trait[/b][/color]")
		lines.append(description)
	return "\n".join(lines)


func _format_effect_value(effect_id: String, value: Variant) -> String:
	if effect_id.ends_with("_multiplier") or effect_id.ends_with("_chance"):
		return "%+.0f%%" % (float(value) * 100.0)
	if value is float and not is_equal_approx(float(value), roundf(float(value))):
		return "%+.2f" % float(value)
	return "%+d" % int(value)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Complete"
	var parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		if cost.has(String(resource_id)):
			parts.append("%s %s" % [
				RESOURCE_LABELS[resource_id],
				_format_number(int(cost[String(resource_id)])),
			])
	return "  ·  ".join(parts)


func _set_feedback(message: String, successful: bool) -> void:
	action_feedback.text = message
	action_feedback.modulate = Color(0.52, 0.94, 0.70) if successful else Color(1.0, 0.60, 0.46)


func _active_building_id() -> StringName:
	return &"memory_library" if _blacksmith_service == &"soul_refinery" else &"blacksmith"


func _can_use_inventory() -> bool:
	return (
		_inventory != null
		and _inventory.has_method("get_resources")
		and _inventory.has_method("get_equipment_catalog")
	)


func _can_use_town() -> bool:
	return (
		_town != null
		and _town.has_method("get_building_level")
		and _town.has_method("get_next_upgrade_cost")
	)


func _resource_node_prefix(resource_id: StringName) -> String:
	match resource_id:
		&"gold":
			return "Gold"
		&"autumn_wood":
			return "Wood"
		&"stone":
			return "Stone"
		&"magic_shard":
			return "Shard"
		&"autumn_core":
			return "Core"
	return ""


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
