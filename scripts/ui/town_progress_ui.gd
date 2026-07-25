class_name TownProgressUI
extends Control

signal closed

var _town: RefCounted
var _inventory: RefCounted
var _resource_label: Label
var _stage_label: Label
var _building_list: VBoxContainer
var _equipment_list: VBoxContainer
var _detail_label: Label
var _building_buttons: Array[Button] = []
var _equipment_buttons: Array[Button] = []
var _selected_equipment: StringName


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func set_services(town: RefCounted, inventory: RefCounted) -> void:
	_town = town
	_inventory = inventory
	if is_node_ready():
		_refresh()


func get_building_button_count() -> int:
	return _building_buttons.size()


func get_equipment_button_count() -> int:
	return _equipment_buttons.size()


func get_resource_text() -> String:
	return _resource_label.text if _resource_label != null else ""


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-520, -310)
	panel.size = Vector2(1040, 620)
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.095, 0.055, 0.035, 0.98)
	style.border_color = Color(0.78, 0.52, 0.23)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	panel.add_child(main)
	var title_row := HBoxContainer.new()
	main.add_child(title_row)
	var title := Label.new()
	title.text = "TOWN DEVELOPMENT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	title_row.add_child(close_button)
	_stage_label = Label.new()
	_stage_label.add_theme_font_size_override("font_size", 18)
	main.add_child(_stage_label)
	_resource_label = Label.new()
	_resource_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.72))
	main.add_child(_resource_label)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	main.add_child(columns)
	_building_list = _make_scroll_column(columns, "BUILDINGS")
	_equipment_list = _make_scroll_column(columns, "EQUIPMENT")
	var detail_panel := VBoxContainer.new()
	detail_panel.custom_minimum_size = Vector2(250, 0)
	columns.add_child(detail_panel)
	var detail_title := Label.new()
	detail_title.text = "WORKBENCH"
	detail_title.add_theme_font_size_override("font_size", 20)
	detail_panel.add_child(detail_title)
	_detail_label = Label.new()
	_detail_label.text = "Select equipment to own, equip, and strengthen."
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_label)
	var upgrade := Button.new()
	upgrade.text = "Strengthen Selected"
	upgrade.pressed.connect(_upgrade_selected_equipment)
	detail_panel.add_child(upgrade)


func _make_scroll_column(parent: Container, title_text: String) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(350, 0)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 20)
	wrapper.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _refresh() -> void:
	if _town == null or _inventory == null or _resource_label == null:
		return
	var resources := _inventory.call("get_resources") as Dictionary
	_resource_label.text = "Gold %d   Autumn Wood %d   Stone %d   Shards %d   Cores %d" % [
		int(resources.get("gold", 0)),
		int(resources.get("autumn_wood", 0)),
		int(resources.get("stone", 0)),
		int(resources.get("magic_shard", 0)),
		int(resources.get("autumn_core", 0)),
	]
	_stage_label.text = "Village Stage %d / 3 — %s" % [
		int(_town.call("get_village_stage")) + 1,
		String(_town.call("get_village_stage_id")).capitalize(),
	]
	_rebuild_buildings()
	_rebuild_equipment()


func _rebuild_buildings() -> void:
	for child in _building_list.get_children():
		child.queue_free()
	_building_buttons.clear()
	for building_id in _town.call("get_building_ids"):
		var level := int(_town.call("get_building_level", building_id))
		var max_level := int(_town.call("get_max_building_level", building_id))
		var cost := _town.call("get_next_upgrade_cost", building_id) as Dictionary
		var button := Button.new()
		button.text = "%s  Lv.%d/%d\n%s" % [
			String(building_id).capitalize(),
			level,
			max_level,
			"MAX" if cost.is_empty() else _format_cost(cost),
		]
		button.disabled = cost.is_empty()
		button.pressed.connect(_upgrade_building.bind(building_id))
		_building_list.add_child(button)
		_building_buttons.append(button)


func _rebuild_equipment() -> void:
	for child in _equipment_list.get_children():
		child.queue_free()
	_equipment_buttons.clear()
	for item in _inventory.call("get_equipment_catalog"):
		var item_id := StringName(item.get("id", ""))
		var level := int(_inventory.call("get_equipment_level", item_id))
		var button := Button.new()
		button.text = "%s  [%s]  Lv.%d" % [
			String(item.get("name", item_id)),
			String(item.get("slot", "")),
			level,
		]
		button.pressed.connect(_select_equipment.bind(item_id))
		_equipment_list.add_child(button)
		_equipment_buttons.append(button)


func _upgrade_building(building_id: StringName) -> void:
	_town.call("upgrade_building", building_id)
	_refresh()


func _select_equipment(item_id: StringName) -> void:
	_selected_equipment = item_id
	if not bool(_inventory.call("has_equipment", item_id)):
		if not bool(_inventory.call("purchase_equipment", item_id)):
			var unavailable := _inventory.call("get_equipment", item_id) as Dictionary
			_detail_label.text = "%s\nPurchase requires: %s" % [
				String(unavailable.get("name", item_id)),
				_format_cost(unavailable.get("purchase_cost", {}) as Dictionary),
			]
			_refresh()
			return
	_inventory.call("equip", item_id)
	var item := _inventory.call("get_equipment", item_id) as Dictionary
	_detail_label.text = "%s\n%s\nUpgrade: %s" % [
		String(item.get("name", item_id)),
		JSON.stringify(item.get("effects", {})),
		_format_cost(_inventory.call("get_equipment_upgrade_cost", item_id)),
	]
	_refresh()


func _upgrade_selected_equipment() -> void:
	if _selected_equipment.is_empty():
		return
	_inventory.call("upgrade_equipment", _selected_equipment)
	_select_equipment(_selected_equipment)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "MAX"
	var parts: Array[String] = []
	for resource_id in cost:
		parts.append("%s %d" % [String(resource_id).capitalize(), int(cost[resource_id])])
	return ", ".join(parts)
