extends Control
class_name HUD

signal interaction_prompt_accepted

const AREA_PANEL_MIN_WIDTH := 220.0
const AREA_PANEL_MAX_WIDTH := 520.0
const AREA_TEXT_HORIZONTAL_PADDING := 88.0
const INTERACTION_PANEL_MIN_WIDTH := 180.0
const INTERACTION_PANEL_MAX_WIDTH := 420.0
const INTERACTION_TEXT_HORIZONTAL_PADDING := 138.0

@onready var hp_fill: ColorRect = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/HPBar/Fill
@onready var hp_value: Label = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/HPBar/Value
@onready var mp_fill: ColorRect = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/MPBar/Fill
@onready var mp_value: Label = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/MPBar/Value
@onready var stamina_fill: ColorRect = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/StaminaBar/Fill
@onready var stamina_value: Label = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/StaminaBar/Value
@onready var level_label: Label = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/LevelLabel
@onready var class_label: Label = $BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus/ClassLabel
@onready var currency_value: Label = $BottomHUD/HUDGrid/ProgressColumn/ProgressCenter/ProgressProxy/HUDProgressPanel/Rows/GoldRow/CurrencyValue
@onready var experience_value: Label = $BottomHUD/HUDGrid/ProgressColumn/ProgressCenter/ProgressProxy/HUDProgressPanel/Rows/ExperienceRow/ExperienceValue
@onready var area_name: Label = $AreaPanel/AreaRows/AreaName
@onready var area_heading: Label = $AreaPanel/AreaRows/AreaHeading
@onready var area_panel: Control = $AreaPanel
@onready var quest_text: Label = $BottomHUD/HUDGrid/InfoColumn/QuestCenter/QuestProxy/HUDQuestTracker/QuestRows/QuestText
@onready var quest_progress: Label = $BottomHUD/HUDGrid/InfoColumn/QuestCenter/QuestProxy/HUDQuestTracker/QuestRows/QuestProgress
@onready var interaction_panel: Control = $InteractionPanel
@onready var key_label: Label = $InteractionPanel/PromptRow/Keycap/KeyLabel
@onready var prompt_text: Label = $InteractionPanel/PromptRow/PromptText
@onready var hp_potion_count: Label = $HUDHotbar/Icons/Health/Count
@onready var mp_potion_count: Label = $HUDHotbar/Icons/Mana/Count
@onready var potion_feedback: Label = $HUDHotbar/PotionFeedback

var _feedback_generation: int = 0

func _ready() -> void:
	_make_display_only(self)
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_area_panel_width()
	_update_interaction_panel_width()

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
	currency_value.text = _format_number(amount)

func set_experience(current: int, required: int) -> void:
	var safe_required := maxi(1, required)
	experience_value.text = "%s / %s" % [_format_number(maxi(0, current)), _format_number(safe_required)]

func set_potion_counts(health_count: int, mana_count: int) -> void:
	hp_potion_count.text = str(maxi(0, health_count))
	mp_potion_count.text = str(maxi(0, mana_count))

func show_potion_feedback(message: String, successful: bool = true) -> void:
	_feedback_generation += 1
	var generation := _feedback_generation
	potion_feedback.text = message
	potion_feedback.modulate = Color.WHITE if successful else Color(1.0, 0.48, 0.38, 1.0)
	potion_feedback.visible = true
	await get_tree().create_timer(1.8, true, false, true).timeout
	if generation == _feedback_generation:
		potion_feedback.visible = false

func set_area_name(value: String) -> void:
	area_name.text = value.strip_edges() if not value.strip_edges().is_empty() else "Unknown Area"
	_update_area_panel_width()


func _update_area_panel_width() -> void:
	if area_panel == null or area_heading == null or area_name == null:
		return
	var content_width := maxf(
		_measure_label_text_width(area_heading),
		_measure_label_text_width(area_name)
	)
	var panel_width := clampf(
		ceilf(content_width + AREA_TEXT_HORIZONTAL_PADDING),
		AREA_PANEL_MIN_WIDTH,
		AREA_PANEL_MAX_WIDTH
	)
	area_panel.offset_left = -panel_width * 0.5
	area_panel.offset_right = panel_width * 0.5


func _measure_label_text_width(label: Label) -> float:
	var settings := label.label_settings
	var font := settings.font if settings != null and settings.font != null else label.get_theme_font("font")
	var font_size := (
		settings.font_size
		if settings != null and settings.font_size > 0
		else label.get_theme_font_size("font_size")
	)
	var outline_width := settings.outline_size * 2.0 if settings != null else 0.0
	return font.get_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x + outline_width

func set_objective(text: String, progress: String = "") -> void:
	quest_text.text = text
	quest_progress.text = progress
	quest_progress.visible = not progress.is_empty()

func set_interaction_prompt(
	action_text: String,
	key_text: String = "F",
	target: CanvasItem = null
) -> void:
	prompt_text.text = action_text
	key_label.text = key_text
	_update_interaction_panel_width()
	interaction_panel.visible = not action_text.is_empty()
	if interaction_panel.has_method("set_target"):
		interaction_panel.call("set_target", target)

func clear_interaction_prompt() -> void:
	if interaction_panel.has_method("clear_target"):
		interaction_panel.call("clear_target")
	interaction_panel.visible = false


func _update_interaction_panel_width() -> void:
	if not bool(get_meta("interaction_prompt_adaptive_width", false)):
		return
	var panel_width := clampf(
		ceilf(_measure_label_text_width(prompt_text) + INTERACTION_TEXT_HORIZONTAL_PADDING),
		INTERACTION_PANEL_MIN_WIDTH,
		INTERACTION_PANEL_MAX_WIDTH
	)
	interaction_panel.offset_left = -panel_width * 0.5
	interaction_panel.offset_right = panel_width * 0.5

func set_interaction_visible(is_visible: bool) -> void:
	interaction_panel.visible = is_visible

func _set_bar(fill: ColorRect, value_label: Label, current: int, maximum: int) -> void:
	var safe_maximum: int = maxi(1, maximum)
	var safe_current: int = clampi(current, 0, safe_maximum)
	var ratio := float(safe_current) / float(safe_maximum)
	fill.position = Vector2(14.0, 5.0)
	fill.size = Vector2(231.0 * ratio, 12.0)
	value_label.text = "%d / %d" % [safe_current, safe_maximum]

func _make_display_only(node: Node) -> void:
	if node is Control:
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
