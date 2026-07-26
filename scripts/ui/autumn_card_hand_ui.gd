@tool
class_name AutumnCardHandUI
extends CardHandUI

const AUTUMN_CARD_SCENE := preload("res://scenes/ui/autumn/AutumnBattleCard.tscn")
const AUTUMN_CARD_ASPECT := 0.72
const ACTIVE_SCALE := Vector2.ONE
const INACTIVE_SCALE := Vector2(0.94, 0.94)
const ACTIVE_MODULATE := Color.WHITE
const INACTIVE_MODULATE := Color(0.43, 0.40, 0.37, 0.72)
const AUTUMN_HOVER_RISE := 9.0
const AUTUMN_HOVER_SCALE := Vector2(1.055, 1.055)


func set_cards(cards: Array, energy: float) -> void:
	super.set_cards(cards, energy)
	if is_node_ready():
		group_changed.emit(_active_group)


func set_action_points(current: float, maximum: float) -> void:
	super.set_action_points(current, maximum)
	var hud := get_parent().get_parent().get_parent()
	if hud != null and hud.has_method("_set_action_points_projection"):
		hud.call("_set_action_points_projection", current, maximum)
	if not is_node_ready():
		return
	for index in _buttons.size():
		var card := _buttons[index]
		if not card.has_method("set_row_active"):
			continue
		var global_index := int(card.get_meta("global_card_index", index))
		var affordable := (
			global_index < _cards.size()
			and float(_cards[global_index].get("cost", 0)) <= _energy
		)
		card.call("set_row_active", global_index / CARDS_PER_GROUP == _active_group, affordable)


func has_compact_combo_display() -> bool:
	return false


func set_combo(_current: String, _next_hint: String) -> void:
	pass


func set_boss_health(name_text: String, current: int, maximum: int) -> void:
	var hud := get_parent().get_parent().get_parent()
	if hud != null and hud.has_method("set_boss_health"):
		hud.call("set_boss_health", name_text, current, maximum)


func hide_boss_health() -> void:
	var hud := get_parent().get_parent().get_parent()
	if hud != null and hud.has_method("hide_boss_health"):
		hud.call("hide_boss_health")


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
	_apply_responsive_geometry()

	var group_start := _active_group * CARDS_PER_GROUP
	var group_end := mini(_cards.size(), group_start + CARDS_PER_GROUP)
	for global_index in range(group_start, group_end):
		var card := _cards[global_index]
		var local_index := global_index % CARDS_PER_GROUP
		var button := _build_card_button(card, local_index, global_index)
		_front_row.add_child(button)
		_buttons.append(button)
	_group_label.text = "GROUP %d / %d" % [_active_group + 1, get_group_count()]
	_capture_after_container_sort()


func _build_card_button(card: Dictionary, local_index: int, global_index: int) -> Button:
	var button := AUTUMN_CARD_SCENE.instantiate() as Button
	button.name = "Card_%d" % global_index
	button.custom_minimum_size = _responsive_card_size()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("global_card_index", global_index)
	button.call(
		"configure",
		card,
		get_shortcut_label(local_index),
		float(card.get("cost", 0)) <= _energy
	)
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
		var local_index := global_index % CARDS_PER_GROUP
		var is_active := global_index / CARDS_PER_GROUP == _active_group
		var affordable := (
			global_index < _cards.size()
			and float(_cards[global_index].get("cost", 0)) <= _energy
		)
		var resting := {
			"position": button.position,
			"rotation": 0.0,
			"scale": ACTIVE_SCALE if is_active else INACTIVE_SCALE,
			"z_index": (180 if is_active else 20) + local_index,
		}
		_resting_layouts.append(resting)
		button.mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if is_active else Control.FOCUS_NONE
		button.modulate = ACTIVE_MODULATE if is_active else INACTIVE_MODULATE
		if button.has_method("set_row_active"):
			button.call("set_row_active", is_active, affordable)
		_apply_card_layout(button, resting)


func _set_card_hover(index: int, hovered: bool, animate: bool = true) -> void:
	if index < 0 or index >= _buttons.size() or index >= _resting_layouts.size():
		return
	var button := _buttons[index]
	var global_index := int(button.get_meta("global_card_index", index))
	if global_index / CARDS_PER_GROUP != _active_group:
		return
	if button.has_method("set_hovered"):
		button.call("set_hovered", hovered)
	var resting := _resting_layouts[index]
	var target := resting.duplicate(true)
	if hovered:
		target["position"] = (resting["position"] as Vector2) + Vector2(0, -AUTUMN_HOVER_RISE)
		target["scale"] = AUTUMN_HOVER_SCALE
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


func _on_viewport_size_changed() -> void:
	if not is_node_ready():
		return
	_apply_responsive_geometry()
	for button in _buttons:
		button.custom_minimum_size = _responsive_card_size()
	_capture_after_container_sort()


func _apply_responsive_geometry() -> void:
	var card_size := _responsive_card_size()
	_back_row.custom_minimum_size.y = 0.0
	_front_row.custom_minimum_size.y = card_size.y
	var card_rows := _back_row.get_parent() as VBoxContainer
	card_rows.add_theme_constant_override("separation", 0)


func _responsive_card_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var safe_height := maxf(112.0, viewport_size.y * 0.28 - 45.0)
	var hand_width := maxf(360.0, viewport_size.x * 0.50 - 30.0)
	var height_from_hud := safe_height * 0.86
	var width_limit := (hand_width - 18.0) / float(CARDS_PER_GROUP)
	var height_from_width := width_limit / AUTUMN_CARD_ASPECT
	var card_height := clampf(minf(height_from_hud, height_from_width), 112.0, 170.0)
	return Vector2(roundf(card_height * AUTUMN_CARD_ASPECT), roundf(card_height))
