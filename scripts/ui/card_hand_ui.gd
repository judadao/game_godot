@tool
class_name CardHandUI
extends Control

signal card_selected(index: int)
signal redraw_requested
signal group_changed(group_index: int)

const CARD_SIZE := Vector2(82.0, 78.0)
const RESTING_VISIBLE_HEIGHT := CARD_SIZE.y
const BACK_ROW_SCALE := Vector2(0.92, 0.92)
const HOVER_RISE := 10.0
const HOVER_SCALE := Vector2(1.08, 1.08)
const SHORTCUT_LABELS := ["Q", "W", "E", "R"]
const CARDS_PER_GROUP := 4

var _cards: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _resting_layouts: Array[Dictionary] = []
var _card_tweens: Dictionary = {}
var _energy := 0.0
var _max_energy := 5.0
var _active_group := 0

@onready var _back_row: HBoxContainer = $CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/BackRow
@onready var _front_row: HBoxContainer = $CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/FrontRow
@onready var _energy_label: Label = $CardSafeArea/BottomMargin/BottomRow/APSlot/APControls/EnergyBadge
@onready var _combo_label: Label = find_child("ComboHint", true, false) as Label
@onready var _boss_label: Label = $BossCenter/BossStack/BossName
@onready var _boss_bar: ProgressBar = $BossCenter/BossStack/BossHealth
@onready var _redraw_button: Button = $CardSafeArea/BottomMargin/BottomRow/APSlot/APControls/RedrawHand
@onready var _group_label: Label = find_child("CardGroupBadge", true, false) as Label


func _ready() -> void:
	if Engine.is_editor_hint() and _cards.is_empty():
		_cards = _editor_sample_cards()
	if not Engine.is_editor_hint():
		_boss_label.visible = false
		_boss_bar.visible = false
	_refresh()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("card_group_1") or event.is_action_pressed("card_group_2"):
		toggle_active_group()
		get_viewport().set_input_as_handled()
		return
	var group_start := _active_group * CARDS_PER_GROUP
	var visible_count := mini(CARDS_PER_GROUP, maxi(0, _cards.size() - group_start))
	for index in visible_count:
		if event.is_action_pressed("card_slot_%d" % (index + 1)):
			select_card(group_start + index)
			get_viewport().set_input_as_handled()
			return


func set_cards(cards: Array, energy: float) -> void:
	_cards.clear()
	for card in cards:
		if card is Dictionary:
			_cards.append((card as Dictionary).duplicate(true))
	_energy = energy
	_active_group = mini(_active_group, maxi(0, get_group_count() - 1))
	if is_node_ready():
		_refresh()


func set_action_points(current: float, maximum: float) -> void:
	_energy = clampf(current, 0.0, maxf(0.0, maximum))
	_max_energy = maxf(0.0, maximum)
	if not is_node_ready():
		return
	_update_ap_display()
	for index in _buttons.size():
		var global_index := int(_buttons[index].get_meta("global_card_index", index))
		_buttons[index].disabled = global_index >= _cards.size() or float(_cards[global_index].get("cost", 0)) > _energy


func select_card(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	card_selected.emit(index)


func set_active_group(group_index: int) -> void:
	var next_group := clampi(group_index, 0, maxi(0, get_group_count() - 1))
	if next_group == _active_group:
		return
	_active_group = next_group
	if is_node_ready():
		_refresh()
	group_changed.emit(_active_group)


func toggle_active_group() -> void:
	if get_group_count() <= 1:
		return
	set_active_group((_active_group + 1) % get_group_count())


func get_active_group() -> int:
	return _active_group


func get_group_count() -> int:
	return maxi(1, ceili(float(_cards.size()) / float(CARDS_PER_GROUP)))


func get_visible_card_global_index(local_index: int) -> int:
	return _active_group * CARDS_PER_GROUP + local_index


func get_card_button_count() -> int:
	return _buttons.size()


func get_card_button(index: int) -> Button:
	return _buttons[index] if index >= 0 and index < _buttons.size() else null


func get_shortcut_label(index: int) -> String:
	return SHORTCUT_LABELS[index] if index >= 0 and index < SHORTCUT_LABELS.size() else ""


func get_hand_panel_count() -> int:
	return find_children("*", "PanelContainer", true, false).size()


func get_resting_visible_height() -> float:
	return RESTING_VISIBLE_HEIGHT


func get_card_layout(index: int) -> Dictionary:
	if index < 0 or index >= _buttons.size():
		return {}
	var button := _buttons[index]
	var parent_item := button.get_parent() as CanvasItem
	var layout_position := get_global_transform_with_canvas().affine_inverse() * (
		parent_item.get_global_transform_with_canvas() * button.position
	)
	return {
		"position": layout_position,
		"scale": button.scale,
		"rotation": button.rotation,
		"z_index": button.z_index,
		"size": button.size,
	}


func preview_card_hover(index: int, hovered: bool) -> void:
	_set_card_hover(index, hovered, false)


func has_compact_energy_display() -> bool:
	return _energy_label != null and is_instance_valid(_energy_label)


func has_compact_combo_display() -> bool:
	return _combo_label != null and is_instance_valid(_combo_label)


func set_combo(current: String, next_hint: String) -> void:
	if _combo_label == null:
		return
	_combo_label.text = "COMBO  %s\nNEXT  %s" % [current, next_hint]


func set_boss_health(name_text: String, current: int, maximum: int) -> void:
	if _boss_bar == null:
		return
	_boss_label.text = name_text
	_boss_bar.max_value = maxi(1, maximum)
	_boss_bar.value = clampi(current, 0, maximum)
	_boss_label.visible = true
	_boss_bar.visible = true


func hide_boss_health() -> void:
	if _boss_bar != null:
		_boss_label.visible = false
		_boss_bar.visible = false


func _on_redraw_hand_pressed() -> void:
	redraw_requested.emit()


func _refresh() -> void:
	for tween_variant in _card_tweens.values():
		if tween_variant is Tween and (tween_variant as Tween).is_valid():
			(tween_variant as Tween).kill()
	_card_tweens.clear()
	for button in _buttons:
		if is_instance_valid(button):
			var parent := button.get_parent()
			if parent != null:
				parent.remove_child(button)
			button.queue_free()
	_buttons.clear()
	_resting_layouts.clear()
	_update_ap_display()

	var visible_card_count := mini(_cards.size(), CARDS_PER_GROUP * 2)
	for global_index in visible_card_count:
		var card := _cards[global_index]
		var local_index := global_index % CARDS_PER_GROUP
		var button := _build_card_button(card, local_index, global_index)
		var group_index := global_index / CARDS_PER_GROUP
		var target_row := _front_row if group_index == _active_group else _back_row
		target_row.add_child(button)
		_buttons.append(button)
	_group_label.text = "A / S / LT / RT  TOGGLE  %d / %d" % [_active_group + 1, get_group_count()]
	_capture_after_container_sort()


func _build_card_button(card: Dictionary, local_index: int, global_index: int) -> Button:
	var button := Button.new()
	button.name = "Card_%d" % global_index
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = 1.0
	button.pivot_offset = CARD_SIZE * 0.5
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("global_card_index", global_index)
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var card_type := String(card.get("type", "card")).to_upper()
	var level := maxi(1, int(card.get("level", 1)))
	button.text = "%s  %s\n%s · LV.%d · AP %d" % [
		get_shortcut_label(local_index),
		String(card.get("name", "Card")),
		card_type,
		level,
		int(card.get("cost", 0)),
	]
	button.tooltip_text = String(card.get("description", ""))
	button.disabled = float(card.get("cost", 0)) > _energy
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color(0.96, 0.90, 0.75))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.55, 0.51, 0.72))
	button.add_theme_stylebox_override("normal", _make_card_style(card_type, false))
	button.add_theme_stylebox_override("hover", _make_card_style(card_type, true))
	button.add_theme_stylebox_override("pressed", _make_card_style(card_type, true))
	button.add_theme_stylebox_override("focus", _make_card_style(card_type, true))
	button.add_theme_stylebox_override("disabled", _make_card_style("DISABLED", false))
	var icon_path := String(card.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
	button.pressed.connect(select_card.bind(global_index))
	button.mouse_entered.connect(_set_card_hover.bind(global_index, true, true))
	button.mouse_exited.connect(_set_card_hover.bind(global_index, false, true))
	button.resized.connect(_center_card_pivot.bind(button))
	return button


func _capture_resting_layouts() -> void:
	if not is_inside_tree():
		return
	_resting_layouts.clear()
	for index in _buttons.size():
		var button := _buttons[index]
		var global_index := int(button.get_meta("global_card_index", index))
		var group_index := floori(float(global_index) / float(CARDS_PER_GROUP))
		var local_index := global_index % CARDS_PER_GROUP
		var is_active := group_index == _active_group
		var resting := {
			"position": button.position,
			"rotation": 0.0,
			"scale": Vector2.ONE if is_active else BACK_ROW_SCALE,
			"z_index": 100 + local_index if is_active else local_index,
		}
		_resting_layouts.append(resting)
		button.mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if is_active else Control.FOCUS_NONE
		_apply_card_layout(button, resting)


func _capture_after_container_sort() -> void:
	await get_tree().process_frame
	_capture_resting_layouts()


func _center_card_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _set_card_hover(index: int, hovered: bool, animate: bool = true) -> void:
	if index < 0 or index >= _buttons.size() or index >= _resting_layouts.size():
		return
	var button := _buttons[index]
	var resting := _resting_layouts[index]
	var global_index := int(button.get_meta("global_card_index", index))
	if floori(float(global_index) / float(CARDS_PER_GROUP)) != _active_group:
		return
	var target := resting.duplicate(true)
	if hovered:
		target["position"] = (resting["position"] as Vector2) + Vector2(0, -HOVER_RISE)
		target["rotation"] = 0.0
		target["scale"] = HOVER_SCALE
		target["z_index"] = 300 + index
	var instance_id := button.get_instance_id()
	var existing: Variant = _card_tweens.get(instance_id)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()
	button.z_index = int(target["z_index"])
	if not animate:
		_apply_card_layout(button, target)
		return
	var tween := button.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position", target["position"], 0.12)
	tween.tween_property(button, "scale", target["scale"], 0.12)
	tween.tween_property(button, "rotation", target["rotation"], 0.12)
	_card_tweens[instance_id] = tween


func _apply_card_layout(button: Button, layout: Dictionary) -> void:
	button.position = layout["position"] as Vector2
	button.scale = layout["scale"] as Vector2
	button.rotation = float(layout["rotation"])
	button.z_index = int(layout["z_index"])


func _on_viewport_size_changed() -> void:
	_capture_after_container_sort()


func _update_ap_display() -> void:
	_energy_label.text = "%.1f / %.0f\nAP" % [_energy, _max_energy]
	_redraw_button.disabled = _energy < _max_energy


func _make_card_style(card_type: String, hovered: bool) -> StyleBoxFlat:
	var color_by_type := {
		"ATTACK": Color(0.26, 0.075, 0.045, 0.96),
		"COMBO": Color(0.055, 0.12, 0.24, 0.96),
		"UTILITY": Color(0.15, 0.09, 0.24, 0.96),
		"HEALING": Color(0.025, 0.16, 0.09, 0.98),
		"POWER": Color(0.25, 0.15, 0.035, 0.96),
		"SUMMON": Color(0.055, 0.20, 0.17, 0.96),
		"STATUS": Color(0.10, 0.18, 0.22, 0.96),
		"ULTIMATE": Color(0.30, 0.075, 0.12, 0.97),
		"DISABLED": Color(0.07, 0.065, 0.06, 0.86),
	}
	var style := StyleBoxFlat.new()
	style.bg_color = color_by_type.get(card_type, Color(0.12, 0.075, 0.045, 0.96))
	if card_type == "HEALING":
		style.border_color = Color(0.55, 1.0, 0.55, 1.0) if hovered else Color(0.28, 0.82, 0.42, 0.98)
	else:
		style.border_color = Color(1.0, 0.76, 0.30, 1.0) if hovered else Color(0.69, 0.43, 0.18, 0.95)
	style.set_border_width_all(3 if hovered else 2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 4 if hovered else 2
	return style


func _editor_sample_cards() -> Array[Dictionary]:
	return [
		{"id": "ember_bolt", "name": "Ember Bolt", "type": "attack", "description": "Deal 12 damage and apply burn.", "cost": 1, "level": 1, "fixed": true},
		{"id": "quickstep", "name": "Quickstep", "type": "utility", "description": "Dash through danger.", "cost": 1, "level": 1, "fixed": true},
		{"id": "guard", "name": "Iron Will", "type": "combo", "description": "Gain brief super armor.", "cost": 1, "level": 1},
		{"id": "cleave", "name": "Cleave", "type": "attack", "description": "Strike enemies in an arc.", "cost": 2, "level": 1},
		{"id": "flame_infusion", "name": "Flame Infusion", "type": "power", "description": "Future attacks gain flame.", "cost": 2, "level": 1},
		{"id": "frost_burst", "name": "Frost Burst", "type": "power", "description": "Future attacks gain frost.", "cost": 2, "level": 1},
		{"id": "healing_light", "name": "Healing Light", "type": "healing", "description": "Restore health.", "cost": 1, "level": 1},
		{"id": "meteor", "name": "Meteor", "type": "ultimate", "description": "Call down a devastating meteor.", "cost": 5, "level": 1},
	]
