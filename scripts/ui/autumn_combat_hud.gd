@tool
class_name AutumnCombatHUD
extends Control

const MAX_VISIBLE_SKILL_TOASTS := 3
const SKILL_TOAST_DURATION_SECONDS := 1.5

@onready var _health_value: Label = $BottomStage/PlayerVitals/VitalsRows/HealthValue
@onready var _mana_value: Label = $BottomStage/PlayerVitals/VitalsRows/ManaValue
@onready var _stamina_value: Label = $BottomStage/PlayerVitals/VitalsRows/StaminaValue
@onready var _identity_value: Label = $BottomStage/PlayerVitals/VitalsRows/IdentityValue
@onready var _area_value: Label = $TopLeftStack/AreaPanel/AreaValue
@onready var _status_rows: VBoxContainer = $TopLeftStack/ActiveStatusList/StatusRows
@onready var _boss_stack: Control = $TopCenterStack/BossStack
@onready var _boss_name: Label = $TopCenterStack/BossStack/BossName
@onready var _boss_health: ProgressBar = $TopCenterStack/BossStack/BossHealth
@onready var _toast_stack: VBoxContainer = $TopCenterStack/SkillToastStack
@onready var _objective_value: Label = $TopLeftStack/ObjectivePanel/ObjectiveRows/ObjectiveValue
@onready var _objective_progress: Label = $TopLeftStack/ObjectivePanel/ObjectiveRows/ObjectiveProgress
@onready var _gold_value: Label = $BottomStage/BottomRightPanel/ResourceRows/GoldValue
@onready var _experience_value: Label = $BottomStage/BottomRightPanel/ResourceRows/ExperienceValue
@onready var _interaction_panel: Control = $BottomStage/InteractionPanel
@onready var _interaction_key: Label = $BottomStage/InteractionPanel/PromptRow/Keycap/KeyLabel
@onready var _interaction_text: Label = $BottomStage/InteractionPanel/PromptRow/PromptText
@onready var _card_hand: AutumnCardHandUI = $BottomStage/CardHandUI

var _toast_tweens: Dictionary = {}


func _ready() -> void:
	_make_display_only(self)
	_boss_stack.visible = false
	set_active_statuses(["ARMOR  3.0s", "REGENERATION  5.0s"] if Engine.is_editor_hint() else [])
	for toast in _toast_stack.get_children():
		if toast is Control:
			(toast as Control).visible = false
	_interaction_panel.visible = false


func set_health(current: int, maximum: int) -> void:
	_health_value.text = "HP  %d / %d" % [clampi(current, 0, maxi(1, maximum)), maxi(1, maximum)]


func set_mana(current: int, maximum: int) -> void:
	_mana_value.text = "MP  %d / %d" % [clampi(current, 0, maxi(1, maximum)), maxi(1, maximum)]


func set_stamina(current: int, maximum: int) -> void:
	_stamina_value.text = "STA  %d / %d" % [clampi(current, 0, maxi(1, maximum)), maxi(1, maximum)]


func set_player_level(level: int) -> void:
	_identity_value.text = "LV.%d  ADVENTURER" % maxi(1, level)


func set_player_class(player_class_name: String) -> void:
	var existing_level := _identity_value.text.get_slice("  ", 0)
	var label := player_class_name.strip_edges().to_upper()
	_identity_value.text = "%s  %s" % [existing_level, label if not label.is_empty() else "ADVENTURER"]


func set_currency(amount: int) -> void:
	_gold_value.text = "GOLD  %s" % _format_number(maxi(0, amount))


func set_experience(current: int, required: int) -> void:
	_experience_value.text = "EXP  %s / %s" % [_format_number(maxi(0, current)), _format_number(maxi(1, required))]


func set_area_name(value: String) -> void:
	_area_value.text = value.strip_edges() if not value.strip_edges().is_empty() else "AUTUMN FOREST"


func set_active_statuses(statuses: Array) -> void:
	for index in _status_rows.get_child_count():
		var row := _status_rows.get_child(index) as Label
		var has_status := index < statuses.size()
		row.visible = has_status
		if has_status:
			row.text = String(statuses[index])


func set_objective(text: String, progress: String = "") -> void:
	_objective_value.text = text
	_objective_progress.text = progress
	_objective_progress.visible = not progress.is_empty()


func set_interaction_prompt(action_text: String, key_text: String = "F", target: CanvasItem = null) -> void:
	_interaction_text.text = action_text
	_interaction_key.text = key_text
	_interaction_panel.visible = not action_text.is_empty()
	if _interaction_panel.has_method("set_target"):
		_interaction_panel.call("set_target", target)


func clear_interaction_prompt() -> void:
	if _interaction_panel.has_method("clear_target"):
		_interaction_panel.call("clear_target")
	_interaction_panel.visible = false


func set_interaction_visible(is_visible: bool) -> void:
	_interaction_panel.visible = is_visible


func set_boss_health(name_text: String, current: int, maximum: int) -> void:
	_boss_name.text = name_text
	_boss_health.max_value = maxi(1, maximum)
	_boss_health.value = clampi(current, 0, maximum)
	_boss_stack.visible = true


func hide_boss_health() -> void:
	_boss_stack.visible = false


func show_skill_toast(skill_id: StringName, message: String) -> void:
	for toast in _toast_stack.get_children():
		if toast is Label and (toast as Control).visible and StringName(toast.get_meta("skill_id", &"")) == skill_id:
			_refresh_toast(toast as Label, skill_id, message)
			return
	var target: Label = null
	for toast in _toast_stack.get_children():
		if toast is Label and not (toast as Control).visible:
			target = toast as Label
			break
	if target == null:
		target = _toast_stack.get_child(0) as Label
	_refresh_toast(target, skill_id, message)


func _refresh_toast(toast: Label, skill_id: StringName, message: String) -> void:
	var toast_key := toast.get_instance_id()
	var existing: Variant = _toast_tweens.get(toast_key)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()
	toast.text = message
	toast.set_meta("skill_id", skill_id)
	toast.modulate = Color.WHITE
	toast.visible = true
	var tween := toast.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "modulate:a", 0.0, SKILL_TOAST_DURATION_SECONDS)
	tween.tween_callback(_recycle_toast.bind(toast, skill_id))
	_toast_tweens[toast_key] = tween


func _recycle_toast(toast: Label, skill_id: StringName) -> void:
	if not is_instance_valid(toast) or StringName(toast.get_meta("skill_id", &"")) != skill_id:
		return
	toast.visible = false
	toast.modulate = Color.WHITE
	toast.set_meta("skill_id", &"")
	_toast_tweens.erase(toast.get_instance_id())


func set_cards(cards: Array, energy: float) -> void:
	_card_hand.set_cards(cards, energy)


func set_action_points(current: float, maximum: float) -> void:
	_card_hand.set_action_points(current, maximum)


func _make_display_only(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child != _card_hand:
			_make_display_only(child)


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
