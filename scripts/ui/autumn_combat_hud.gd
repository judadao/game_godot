@tool
class_name AutumnCombatHUD
extends Control

const MAX_VISIBLE_SKILL_TOASTS := 3
const SKILL_TOAST_DURATION_SECONDS := 1.5

@onready var _health_value: Label = $TopLeftStack/StatusPanel/StatusRows/HealthValue
@onready var _mana_value: Label = $TopLeftStack/StatusPanel/StatusRows/ManaValue
@onready var _stamina_value: Label = $TopLeftStack/StatusPanel/StatusRows/StaminaValue
@onready var _identity_value: Label = $TopLeftStack/StatusPanel/StatusRows/IdentityValue
@onready var _area_value: Label = $TopLeftStack/AreaPanel/AreaValue
@onready var _boss_stack: Control = $TopCenterStack/BossStack
@onready var _boss_name: Label = $TopCenterStack/BossStack/BossName
@onready var _boss_health: ProgressBar = $TopCenterStack/BossStack/BossHealth
@onready var _toast_stack: VBoxContainer = $TopCenterStack/SkillToastStack
@onready var _objective_value: Label = $BottomStage/ObjectivePanel/ObjectiveRows/ObjectiveValue
@onready var _objective_progress: Label = $BottomStage/ObjectivePanel/ObjectiveRows/ObjectiveProgress
@onready var _gold_value: Label = $BottomStage/BottomRightPanel/ResourceRows/GoldValue
@onready var _experience_value: Label = $BottomStage/BottomRightPanel/ResourceRows/ExperienceValue
@onready var _interaction_panel: Control = $BottomStage/InteractionPanel
@onready var _interaction_key: Label = $BottomStage/InteractionPanel/PromptRows/KeyValue
@onready var _interaction_text: Label = $BottomStage/InteractionPanel/PromptRows/PromptValue
@onready var _card_hand: AutumnCardHandUI = $BottomStage/CardHandUI


func _ready() -> void:
	_make_display_only(self)
	_boss_stack.visible = false
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


func set_objective(text: String, progress: String = "") -> void:
	_objective_value.text = text
	_objective_progress.text = progress
	_objective_progress.visible = not progress.is_empty()


func set_interaction_prompt(action_text: String, key_text: String = "F", _target: CanvasItem = null) -> void:
	_interaction_text.text = action_text
	_interaction_key.text = key_text
	_interaction_panel.visible = not action_text.is_empty()


func clear_interaction_prompt() -> void:
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
	var now := Time.get_ticks_msec()
	for toast in _toast_stack.get_children():
		if toast is Label and (toast as Control).visible and StringName(toast.get_meta("skill_id", &"")) == skill_id:
			_refresh_toast(toast as Label, skill_id, message, now)
			return
	var target: Label = null
	for toast in _toast_stack.get_children():
		if toast is Label and not (toast as Control).visible:
			target = toast as Label
			break
	if target == null:
		target = _toast_stack.get_child(0) as Label
	_refresh_toast(target, skill_id, message, now)


func _process(_delta: float) -> void:
	if not is_node_ready():
		return
	var now := Time.get_ticks_msec()
	for toast in _toast_stack.get_children():
		if toast is Label and (toast as Control).visible and now >= int(toast.get_meta("expires_at", 0)):
			(toast as Control).visible = false


func _refresh_toast(toast: Label, skill_id: StringName, message: String, now: int) -> void:
	toast.text = message
	toast.set_meta("skill_id", skill_id)
	toast.set_meta("expires_at", now + roundi(SKILL_TOAST_DURATION_SECONDS * 1000.0))
	toast.modulate = Color.WHITE
	toast.visible = true


func set_cards(cards: Array, energy: float) -> void:
	_card_hand.set_cards(cards, energy)


func set_action_points(current: float, maximum: float) -> void:
	_card_hand.set_action_points(current, maximum)


func set_combo(current: String, next_hint: String) -> void:
	_card_hand.set_combo(current, next_hint)


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
