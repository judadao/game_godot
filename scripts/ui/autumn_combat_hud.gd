extends Control
class_name AutumnCombatHUD

signal interaction_prompt_accepted
signal card_selected(index: int)
signal redraw_requested
signal group_changed(group_index: int)

const MAX_SKILL_TOASTS := 3
const SKILL_TOAST_LIFETIME := 1.5

@onready var hp_fill: ColorRect = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/HPBar/Fill
@onready var hp_value: Label = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/HPBar/Value
@onready var mp_fill: ColorRect = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/MPBar/Fill
@onready var mp_value: Label = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/MPBar/Value
@onready var stamina_fill: ColorRect = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/StaminaBar/Fill
@onready var stamina_value: Label = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/StaminaBar/Value
@onready var level_label: Label = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/LevelLabel
@onready var class_label: Label = $BottomStage/PlayerVitals/VitalsCenter/VitalsProxy/HUDStatus/ClassLabel
@onready var currency_value: Label = $BottomStage/PersonalResources/ResourceMargin/ResourceRows/GoldRow/CurrencyValue
@onready var experience_value: Label = $BottomStage/PersonalResources/ResourceMargin/ResourceRows/ExperienceRow/ExperienceValue
@onready var area_name: Label = $TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/AreaName
@onready var quest_text: Label = $TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/ObjectiveText
@onready var quest_progress: Label = $TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/ObjectiveProgress
@onready var interaction_panel: Control = $InteractionPanel
@onready var key_label: Label = $InteractionPanel/PromptRow/Keycap/KeyLabel
@onready var prompt_text: Label = $InteractionPanel/PromptRow/PromptText
@onready var _status_rows: VBoxContainer = $TopLeftStack/ActiveStatusList/StatusMargin/StatusRows
@onready var _boss_panel: PanelContainer = $TopCenterStack/BossHealth
@onready var _boss_name: Label = $TopCenterStack/BossHealth/BossMargin/BossRows/BossName
@onready var _boss_bar: ProgressBar = $TopCenterStack/BossHealth/BossMargin/BossRows/BossBar
@onready var _toast_stack: VBoxContainer = $TopCenterStack/SkillToastStack
@onready var _cooldown_rows: HBoxContainer = $BottomStage/CardStage/CooldownStrip/CooldownMargin/CooldownRows
@onready var _card_hand: AutumnCardHandUI = $BottomStage/CardStage/AutumnCardHandUI
@onready var _action_points_label: Label = $BottomStage/ActionPoints/EnergyBadge
@onready var _redraw_button: Button = $BottomStage/ActionPoints/RedrawHand
@onready var _group_label: Label = $BottomStage/InputGlyphHints/GroupBadge

var _status_empty_label: Label
var _toast_by_key: Dictionary = {}
var _toast_order: Array[String] = []
var _toast_generation: Dictionary = {}
var _toast_tween_by_key: Dictionary = {}
var _health_potions := 0
var _mana_potions := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_display_only(self)
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_empty_label = _status_rows.get_node("EmptyState") as Label
	hide_boss_health()
	_card_hand.card_selected.connect(card_selected.emit)
	_card_hand.redraw_requested.connect(redraw_requested.emit)
	_card_hand.group_changed.connect(_on_card_group_changed)
	_redraw_button.pressed.connect(_on_redraw_pressed)
	_on_card_group_changed(_card_hand.get_active_group())


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible


func set_health(current: int, maximum: int) -> void:
	_set_bar(hp_fill, hp_value, current, maximum)


func set_mana(current: int, maximum: int) -> void:
	_set_bar(mp_fill, mp_value, current, maximum)


func set_stamina(current: int, maximum: int) -> void:
	_set_bar(stamina_fill, stamina_value, current, maximum)


func set_player_level(level: int) -> void:
	level_label.text = "Lv. %d" % maxi(1, level)


func set_player_class(player_class_name: String) -> void:
	var normalized := player_class_name.strip_edges()
	class_label.text = normalized.to_upper() if not normalized.is_empty() else "ADVENTURER"


func set_currency(amount: int) -> void:
	currency_value.text = _format_number(maxi(0, amount))


func set_experience(current: int, required: int) -> void:
	var safe_required := maxi(1, required)
	experience_value.text = "%s / %s" % [
		_format_number(maxi(0, current)),
		_format_number(safe_required),
	]


func set_cards(cards: Array, energy: float) -> void:
	_card_hand.set_cards(cards, energy)
	_set_action_points_projection(energy, maxf(energy, 5.0))


func set_action_points(current: float, maximum: float) -> void:
	_card_hand.set_action_points(current, maximum)
	_set_action_points_projection(current, maximum)


func set_active_group(group_index: int) -> void:
	_card_hand.set_active_group(group_index)


func toggle_active_group() -> void:
	_card_hand.toggle_active_group()


func get_active_group() -> int:
	return _card_hand.get_active_group()


func get_group_count() -> int:
	return _card_hand.get_group_count()


func _set_action_points_projection(current: float, maximum: float) -> void:
	var safe_maximum := maxf(0.0, maximum)
	var safe_current := clampf(current, 0.0, safe_maximum)
	_action_points_label.text = "%.1f / %.0f\nAP" % [safe_current, safe_maximum]
	_redraw_button.disabled = safe_current < safe_maximum


func _on_redraw_pressed() -> void:
	redraw_requested.emit()


func _on_card_group_changed(group_index: int) -> void:
	_group_label.text = "A / S · LT / RT\nGROUP %d / %d" % [
		group_index + 1,
		_card_hand.get_group_count(),
	]
	group_changed.emit(group_index)


func set_potion_counts(health_count: int, mana_count: int) -> void:
	_health_potions = maxi(0, health_count)
	_mana_potions = maxi(0, mana_count)


func show_potion_feedback(message: String, successful: bool = true) -> void:
	show_skill_toast(
		"potion_feedback",
		message,
		Color(0.54, 0.95, 0.62, 1.0) if successful else Color(1.0, 0.48, 0.38, 1.0)
	)


func set_area_name(value: String) -> void:
	var normalized := value.strip_edges()
	area_name.text = normalized.to_upper() if not normalized.is_empty() else "UNKNOWN AREA"


func set_objective(text: String, progress: String = "") -> void:
	quest_text.text = text
	quest_progress.text = progress
	quest_progress.visible = not progress.is_empty()


func set_active_statuses(statuses: Array) -> void:
	for child in _status_rows.get_children():
		if child != _status_empty_label:
			_status_rows.remove_child(child)
			child.queue_free()
	_status_empty_label.visible = statuses.is_empty()
	for status_variant in statuses:
		if not status_variant is Dictionary:
			continue
		var status := status_variant as Dictionary
		var row := HBoxContainer.new()
		row.name = "Status_%s" % _safe_node_name(String(status.get("id", status.get("name", "effect"))))
		row.add_theme_constant_override("separation", 8)
		var icon := Label.new()
		icon.custom_minimum_size.x = 20.0
		icon.text = String(status.get("icon", "◆"))
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_color_override("font_color", Color(0.65, 0.9, 0.72, 1.0))
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = String(status.get("name", "Effect"))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var remaining := Label.new()
		remaining.custom_minimum_size.x = 48.0
		remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		remaining.text = "%.1fs" % maxf(
			0.0,
			float(status.get("remaining_seconds", status.get("remaining", 0.0)))
		)
		row.add_child(icon)
		row.add_child(label)
		row.add_child(remaining)
		_status_rows.add_child(row)


func set_boss_health(name_text: String, current: int, maximum: int) -> void:
	var safe_maximum := maxi(1, maximum)
	_boss_name.text = name_text
	_boss_bar.max_value = safe_maximum
	_boss_bar.value = clampi(current, 0, safe_maximum)
	_boss_panel.visible = true


func hide_boss_health() -> void:
	_boss_panel.visible = false


func show_skill_toast(
	skill_id: String,
	display_name: String = "",
	accent: Color = Color(0.96, 0.74, 0.34, 1.0)
) -> void:
	var key := skill_id.strip_edges()
	if key.is_empty():
		return
	var label := _toast_by_key.get(key) as Label
	if label == null or not is_instance_valid(label):
		if _toast_order.size() >= MAX_SKILL_TOASTS:
			_remove_toast(_toast_order[0])
		label = Label.new()
		label.name = "SkillToast_%s" % _safe_node_name(key)
		label.custom_minimum_size = Vector2(300.0, 30.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		_toast_stack.add_child(label)
		_toast_by_key[key] = label
		_toast_order.append(key)
	else:
		_toast_order.erase(key)
		_toast_order.append(key)
	var existing_tween := _toast_tween_by_key.get(key) as Tween
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	_toast_tween_by_key.erase(key)
	label.text = display_name if not display_name.strip_edges().is_empty() else skill_id
	label.modulate = accent
	_toast_generation[key] = int(_toast_generation.get(key, 0)) + 1
	var generation := int(_toast_generation[key])
	_expire_toast(key, generation)


func set_cooldown_cards(cards: Array) -> void:
	for child in _cooldown_rows.get_children():
		_cooldown_rows.remove_child(child)
		child.queue_free()
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "COOLDOWN  —"
		empty.add_theme_color_override("font_color", Color(0.54, 0.51, 0.46, 1.0))
		_cooldown_rows.add_child(empty)
		return
	for card_variant in cards.slice(0, 4):
		if not card_variant is Dictionary:
			continue
		var card := card_variant as Dictionary
		var chip := Label.new()
		chip.text = "%s  %.1fs" % [
			String(card.get("name", card.get("card_id", "Card"))),
			maxf(0.0, float(card.get("remaining_seconds", card.get("remaining", 0.0)))),
		]
		chip.add_theme_color_override("font_color", Color(0.86, 0.76, 0.56, 1.0))
		_cooldown_rows.add_child(chip)


func set_interaction_prompt(
	action_text: String,
	key_text: String = "F",
	target: CanvasItem = null
) -> void:
	prompt_text.text = action_text
	key_label.text = key_text
	interaction_panel.visible = not action_text.is_empty()
	if interaction_panel.has_method("set_target"):
		interaction_panel.call("set_target", target)


func clear_interaction_prompt() -> void:
	if interaction_panel.has_method("clear_target"):
		interaction_panel.call("clear_target")
	interaction_panel.visible = false


func set_interaction_visible(is_visible: bool) -> void:
	interaction_panel.visible = is_visible


func _expire_toast(key: String, generation: int) -> void:
	await get_tree().create_timer(SKILL_TOAST_LIFETIME - 0.3, true, false, true).timeout
	if int(_toast_generation.get(key, -1)) != generation:
		return
	var label := _toast_by_key.get(key) as Label
	if label == null or not is_instance_valid(label):
		return
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	_toast_tween_by_key[key] = tween
	tween.finished.connect(_finish_toast.bind(key, generation), CONNECT_ONE_SHOT)


func _finish_toast(key: String, generation: int) -> void:
	if int(_toast_generation.get(key, -1)) == generation:
		_remove_toast(key)


func _remove_toast(key: String) -> void:
	var tween := _toast_tween_by_key.get(key) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	var label := _toast_by_key.get(key) as Label
	if label != null and is_instance_valid(label):
		var parent := label.get_parent()
		if parent != null:
			parent.remove_child(label)
		label.queue_free()
	_toast_by_key.erase(key)
	_toast_order.erase(key)
	_toast_generation.erase(key)
	_toast_tween_by_key.erase(key)


func _set_bar(fill: ColorRect, value_label: Label, current: int, maximum: int) -> void:
	var safe_maximum := maxi(1, maximum)
	var safe_current := clampi(current, 0, safe_maximum)
	fill.position = Vector2(14.0, 5.0)
	fill.size = Vector2(231.0 * float(safe_current) / float(safe_maximum), 12.0)
	value_label.text = "%d / %d" % [safe_current, safe_maximum]


func _make_display_only(node: Node) -> void:
	if node is Control and node != interaction_panel:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_display_only(child)


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result


func _safe_node_name(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.is_valid_identifier() or character.is_valid_int() else "_"
	return result if not result.is_empty() else "entry"
