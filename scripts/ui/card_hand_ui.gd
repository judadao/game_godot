class_name CardHandUI
extends Control

signal card_selected(index: int)
signal redraw_requested
signal group_changed(group_index: int)

const CARD_SIZE := Vector2(132.0, 168.0)
const RESTING_VISIBLE_HEIGHT := 154.0
const HOVER_RISE := 75.0
const HOVER_SCALE := Vector2(1.08, 1.08)
const MAX_HAND_SPAN := 520.0
const MAX_CARD_SPACING := 104.0
const SHORTCUT_LABELS := ["Q", "W", "E", "R"]
const CARDS_PER_GROUP := 4

var _cards: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _resting_layouts: Array[Dictionary] = []
var _card_tweens: Dictionary = {}
var _energy := 0.0
var _max_energy := 5.0
var _active_group := 0
var _hand_layer: Control
var _energy_label: Label
var _combo_label: Label
var _boss_label: Label
var _boss_bar: ProgressBar
var _redraw_button: Button
var _group_label: Label
var _safe_area_band: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("card_group_1"):
		set_active_group(0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("card_group_2"):
		set_active_group(1)
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
		var global_index := get_visible_card_global_index(index)
		_buttons[index].disabled = global_index >= _cards.size() or float(_cards[global_index].get("cost", 0)) > _energy
	if _redraw_button != null:
		_redraw_button.disabled = _energy < _max_energy


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


func get_active_group() -> int:
	return _active_group


func get_group_count() -> int:
	return maxi(1, ceili(float(_cards.size()) / float(CARDS_PER_GROUP)))


func get_visible_card_global_index(local_index: int) -> int:
	return _active_group * CARDS_PER_GROUP + local_index


func get_card_button_count() -> int:
	return _buttons.size()


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
	return {
		"position": button.position,
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


func _build_layout() -> void:
	_safe_area_band = ColorRect.new()
	_safe_area_band.name = "CardSafeArea"
	_safe_area_band.color = Color(0.015, 0.02, 0.03, 0.78)
	_safe_area_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_area_band.z_index = -20
	add_child(_safe_area_band)

	_hand_layer = Control.new()
	_hand_layer.name = "HandLayer"
	_hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)

	_energy_label = Label.new()
	_energy_label.name = "EnergyBadge"
	_energy_label.custom_minimum_size = Vector2(66, 66)
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_label.add_theme_font_size_override("font_size", 17)
	_energy_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.42))
	_energy_label.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.015))
	_energy_label.add_theme_constant_override("outline_size", 4)
	_energy_label.add_theme_stylebox_override("normal", _make_badge_style(
		Color(0.08, 0.05, 0.025, 0.90),
		Color(0.90, 0.61, 0.20, 0.95),
		30
	))
	_energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_layer.add_child(_energy_label)

	_combo_label = Label.new()
	_combo_label.name = "ComboHint"
	_combo_label.custom_minimum_size = Vector2(250, 46)
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 11)
	_combo_label.add_theme_color_override("font_color", Color(0.74, 0.91, 1.0))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.025, 0.04, 0.07))
	_combo_label.add_theme_constant_override("outline_size", 3)
	_combo_label.add_theme_stylebox_override("normal", _make_badge_style(
		Color(0.035, 0.07, 0.10, 0.74),
		Color(0.30, 0.62, 0.76, 0.72),
		8
	))
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_layer.add_child(_combo_label)

	_redraw_button = Button.new()
	_redraw_button.name = "RedrawHand"
	_redraw_button.text = "T  REDRAW\nALL AP"
	_redraw_button.custom_minimum_size = Vector2(92, 48)
	_redraw_button.tooltip_text = "Requires full AP. Discard both groups and draw eight random cards."
	_redraw_button.pressed.connect(func() -> void: redraw_requested.emit())
	_hand_layer.add_child(_redraw_button)

	_group_label = Label.new()
	_group_label.name = "CardGroupBadge"
	_group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_group_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_group_label.add_theme_font_size_override("font_size", 12)
	_group_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	_group_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.07))
	_group_label.add_theme_constant_override("outline_size", 3)
	_group_label.add_theme_stylebox_override("normal", _make_badge_style(
		Color(0.035, 0.07, 0.11, 0.88),
		Color(0.34, 0.66, 0.87, 0.86),
		8
	))
	_group_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_layer.add_child(_group_label)

	_boss_label = Label.new()
	_boss_label.name = "BossName"
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.29))
	_boss_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	_boss_label.add_theme_constant_override("outline_size", 4)
	_boss_label.add_theme_font_size_override("font_size", 18)
	_boss_label.visible = false
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_layer.add_child(_boss_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossHealth"
	_boss_bar.custom_minimum_size = Vector2(520, 18)
	_boss_bar.show_percentage = false
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_layer.add_child(_boss_bar)
	_refresh()


func _refresh() -> void:
	for tween_variant in _card_tweens.values():
		if tween_variant is Tween and (tween_variant as Tween).is_valid():
			(tween_variant as Tween).kill()
	_card_tweens.clear()
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()
	_resting_layouts.clear()
	_update_ap_display()

	var group_start := _active_group * CARDS_PER_GROUP
	var group_end := mini(_cards.size(), group_start + CARDS_PER_GROUP)
	for global_index in range(group_start, group_end):
		var card := _cards[global_index]
		var local_index := global_index - group_start
		var button := _build_card_button(card, local_index, global_index)
		_hand_layer.add_child(button)
		_buttons.append(button)
	if _group_label != null:
		_group_label.text = "A / LT  GROUP  %d / %d  S / RT" % [_active_group + 1, get_group_count()]
	_layout_cards()


func _build_card_button(card: Dictionary, local_index: int, global_index: int) -> Button:
	var button := Button.new()
	button.name = "Card_%d" % global_index
	button.size = CARD_SIZE
	button.custom_minimum_size = CARD_SIZE
	button.pivot_offset = CARD_SIZE * 0.5
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var card_type := String(card.get("type", "card")).to_upper()
	var level := maxi(1, int(card.get("level", 1)))
	button.text = "%s    %s\n%s  •  LV.%d\n\n%s\n\nCOST  %d" % [
		get_shortcut_label(local_index),
		String(card.get("name", "Card")),
		card_type,
		level,
		String(card.get("description", "")),
		int(card.get("cost", 0)),
	]
	button.tooltip_text = String(card.get("description", ""))
	button.disabled = float(card.get("cost", 0)) > _energy
	button.add_theme_font_size_override("font_size", 11)
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
	button.mouse_entered.connect(_set_card_hover.bind(local_index, true, true))
	button.mouse_exited.connect(_set_card_hover.bind(local_index, false, true))
	return button


func _layout_cards() -> void:
	if _hand_layer == null:
		return
	var viewport_size := get_viewport_rect().size
	if _safe_area_band != null:
		_safe_area_band.position = Vector2(0.0, viewport_size.y - 184.0)
		_safe_area_band.size = Vector2(viewport_size.x, 184.0)
	var count := _buttons.size()
	var spacing := 0.0
	if count > 1:
		spacing = minf(MAX_CARD_SPACING, MAX_HAND_SPAN / float(count - 1))
	_resting_layouts.clear()
	for index in count:
		var center_offset := float(index) - float(count - 1) * 0.5
		var edge_drop := absf(center_offset) * 4.0
		var resting := {
			"position": Vector2(
				viewport_size.x * 0.5 + center_offset * spacing - CARD_SIZE.x * 0.5,
				viewport_size.y - RESTING_VISIBLE_HEIGHT + edge_drop
			),
			"rotation": deg_to_rad(clampf(center_offset * 2.0, -6.0, 6.0)),
			"scale": Vector2.ONE,
			"z_index": index,
		}
		_resting_layouts.append(resting)
		_apply_card_layout(_buttons[index], resting)

	var half_span := spacing * float(maxi(0, count - 1)) * 0.5
	var hand_left := viewport_size.x * 0.5 - half_span - CARD_SIZE.x * 0.5
	var hand_right := viewport_size.x * 0.5 + half_span + CARD_SIZE.x * 0.5
	_energy_label.position = Vector2(maxf(12.0, hand_left - 80.0), viewport_size.y - 92.0)
	_energy_label.size = Vector2(66, 66)
	_combo_label.position = Vector2(
		minf(viewport_size.x - 262.0, hand_right + 14.0),
		viewport_size.y - 76.0
	)
	_combo_label.size = Vector2(250, 52)
	_redraw_button.position = Vector2(maxf(12.0, hand_left - 106.0), viewport_size.y - 148.0)
	_redraw_button.size = Vector2(92, 48)
	_group_label.position = Vector2(viewport_size.x * 0.5 - 125.0, viewport_size.y - 206.0)
	_group_label.size = Vector2(250, 30)
	_boss_label.position = Vector2(viewport_size.x * 0.5 - 260.0, 14.0)
	_boss_label.size = Vector2(520, 25)
	_boss_bar.position = Vector2(viewport_size.x * 0.5 - 260.0, 41.0)
	_boss_bar.size = Vector2(520, 18)


func _set_card_hover(index: int, hovered: bool, animate: bool = true) -> void:
	if index < 0 or index >= _buttons.size() or index >= _resting_layouts.size():
		return
	var button := _buttons[index]
	var resting := _resting_layouts[index]
	var target := resting.duplicate(true)
	if hovered:
		target["position"] = (resting["position"] as Vector2) + Vector2(0, -HOVER_RISE)
		target["rotation"] = 0.0
		target["scale"] = HOVER_SCALE
		target["z_index"] = 100 + index
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
	_layout_cards()


func _update_ap_display() -> void:
	if _energy_label != null:
		_energy_label.text = "%.1f / %.0f\nAP" % [_energy, _max_energy]
	if _redraw_button != null:
		_redraw_button.disabled = _energy < _max_energy


func _make_card_style(card_type: String, hovered: bool) -> StyleBoxFlat:
	var color_by_type := {
		"ATTACK": Color(0.26, 0.075, 0.045, 0.96),
		"DEFENSE": Color(0.055, 0.12, 0.24, 0.96),
		"SKILL": Color(0.15, 0.09, 0.24, 0.96),
		"POWER": Color(0.25, 0.15, 0.035, 0.96),
		"SUMMON": Color(0.055, 0.20, 0.17, 0.96),
		"STATUS": Color(0.10, 0.18, 0.22, 0.96),
		"ULTIMATE": Color(0.30, 0.075, 0.12, 0.97),
		"DISABLED": Color(0.07, 0.065, 0.06, 0.86),
	}
	var style := StyleBoxFlat.new()
	style.bg_color = color_by_type.get(card_type, Color(0.12, 0.075, 0.045, 0.96))
	style.border_color = Color(1.0, 0.76, 0.30, 1.0) if hovered else Color(0.69, 0.43, 0.18, 0.95)
	style.set_border_width_all(4 if hovered else 3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 9.0
	style.content_margin_top = 9.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 8 if hovered else 4
	return style


func _make_badge_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style
