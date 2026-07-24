extends Control
class_name HUD

signal interaction_prompt_accepted

@onready var hp_fill: ColorRect = $StatusPanel/StatusRows/HPRow/HPBar/Fill
@onready var hp_value: Label = $StatusPanel/StatusRows/HPRow/HPBar/Value
@onready var mp_fill: ColorRect = $StatusPanel/StatusRows/MPRow/MPBar/Fill
@onready var mp_value: Label = $StatusPanel/StatusRows/MPRow/MPBar/Value
@onready var currency_value: Label = $CurrencyPanel/CurrencyRow/CurrencyValue
@onready var quest_text: Label = $QuestPanel/QuestRows/QuestText
@onready var quest_progress: Label = $QuestPanel/QuestRows/QuestProgress
@onready var interaction_panel: PanelContainer = $InteractionPanel
@onready var key_label: Label = $InteractionPanel/PromptRow/Keycap/KeyLabel
@onready var prompt_text: Label = $InteractionPanel/PromptRow/PromptText

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction_panel.gui_input.connect(_on_interaction_panel_input)

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

func set_currency(amount: int) -> void:
	currency_value.text = _format_number(amount)

func set_objective(text: String, progress: String = "") -> void:
	quest_text.text = text
	quest_progress.text = progress
	quest_progress.visible = not progress.is_empty()

func set_interaction_prompt(action_text: String, key_text: String = "E") -> void:
	prompt_text.text = action_text
	key_label.text = key_text
	interaction_panel.visible = not action_text.is_empty()

func clear_interaction_prompt() -> void:
	interaction_panel.visible = false

func set_interaction_visible(is_visible: bool) -> void:
	interaction_panel.visible = is_visible

func _set_bar(fill: ColorRect, value_label: Label, current: int, maximum: int) -> void:
	var safe_maximum: int = maxi(1, maximum)
	var safe_current: int = clampi(current, 0, safe_maximum)
	fill.anchor_right = float(safe_current) / float(safe_maximum)
	value_label.text = "%d / %d" % [safe_current, safe_maximum]

func _on_interaction_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interaction_prompt_accepted.emit()

func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
