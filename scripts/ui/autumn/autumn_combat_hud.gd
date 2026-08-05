extends Control
class_name AutumnCombatHUD

signal interaction_prompt_accepted
signal card_selected(index: int)
signal redraw_requested
signal group_changed(group_index: int)
signal auto_use_changed(enabled: bool)

const MAX_SKILL_TOASTS := 3
const MAX_VISIBLE_COMBO_SKILLS := 3
const SKILL_TOAST_LIFETIME := 1.5
const NARROW_TOP_RAIL_WIDTH := 1200.0
const NARROW_BOSS_PANEL_WIDTH := 312.0
const NARROW_BOSS_BAR_WIDTH := 280.0
const DEFAULT_BOSS_PANEL_WIDTH := 380.0
const DEFAULT_BOSS_BAR_WIDTH := 416.0
const COMBO_POPUP_DURATION := 0.95
const COMBO_POPUP_MIN_FONT_SIZE := 18
const COMBO_POPUP_MAX_FONT_SIZE := 26

@onready var hp_bar: ProgressBar = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/HPRow/HPBar
@onready var hp_value: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/HPRow/HPBar/HPValue
@onready var level_label: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/LevelLabel
@onready var class_label: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/ClassLabel
@onready var currency_value: Label = $TopRightMeta/MetaRow/CurrencyValue
@onready var area_name: Label = $TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/AreaName
@onready var quest_text: Label = $TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/ObjectiveText
@onready var quest_progress: Label = $TopLeftStack/ObjectivePanel/ObjectiveMargin/ObjectiveRows/ObjectiveProgress
@onready var interaction_panel: Control = $InteractionPanel
@onready var key_label: Label = $InteractionPanel/PromptRow/Keycap/KeyLabel
@onready var prompt_text: Label = $InteractionPanel/PromptRow/PromptText
@onready var _boss_panel: PanelContainer = $TopCenterStack/BossHealth
@onready var _boss_name: Label = $TopCenterStack/BossHealth/BossMargin/BossRows/BossName
@onready var _boss_bar: ProgressBar = $TopCenterStack/BossHealth/BossMargin/BossRows/BossBar
@onready var _toast_stack: VBoxContainer = $BottomStage/ActivityFeed/FeedMargin/FeedRows/SkillToastStack
@onready var _feed_empty_state: Label = $BottomStage/ActivityFeed/FeedMargin/FeedRows/FeedEmptyState
@onready var _combo_summary: Label = $BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboSummary
@onready var _combo_milestones: Label = $BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboMilestones
@onready var _combo_skill_rows: VBoxContainer = $BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboSkillRows/Rows
@onready var _card_hand: AutumnCardHandUI = $BottomStage/CardStage/AutumnCardHandUI
@onready var _action_points_label: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/APPanel/APRows/APHeader/APValue
@onready var _action_points_rate: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/APPanel/APRows/APHeader/APRate
@onready var _action_points_progress: ProgressBar = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/APPanel/APRows/APProgress
@onready var _experience_value: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/ExperienceHeader/XPValue
@onready var _experience_progress: ProgressBar = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/XPProgress
@onready var _auto_attack_name: Label = $BottomStage/PlayerVitals/VitalsMargin/VitalsRows/AutoAttackRow/AutoAttackName
@onready var _redraw_button: Button = $BottomStage/CardStage/ActionStrip/RedrawHand
@onready var _auto_use_toggle: CheckButton = $BottomStage/CardStage/ActionStrip/AutoUse
@onready var _group_label: Label = $BottomStage/ActivityFeed/FeedMargin/FeedRows/InputStrip/GroupBadge
@onready var _survival_timer_label: Label = $FooterRail/FooterRow/SurvivalTimerLabel
@onready var _combo_popup: Label = $ComboPopupAnchor/ComboPopup
@onready var _map_title_overlay: Control = $MapTitleOverlay
@onready var _map_title_panel: Control = $MapTitleOverlay/MapTitlePanel
@onready var _map_title: Label = $MapTitleOverlay/MapTitlePanel/MapTitleMargin/MapTitleRows/MapTitle
@onready var _mission_stack: Control = $TopLeftStack

var _toast_by_key: Dictionary = {}
var _toast_order: Array[String] = []
var _toast_generation: Dictionary = {}
var _toast_tween_by_key: Dictionary = {}
var _combo_skills_signature := ""
var _health_potions := 0
var _mana_potions := 0
var _has_health_projection := false
var _has_level_projection := false
var _has_experience_projection := false
var _has_action_points_projection := false
var _projected_health := 0
var _projected_level := 0
var _projected_experience := 0
var _projected_experience_required := 1
var _projected_action_points := 0.0
var _last_emphasized_action_points := 0.0
var _vitals_tweens: Dictionary = {}
var _combo_popup_tween: Tween
var _map_title_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_display_only(self)
	get_viewport().size_changed.connect(_apply_top_rail_geometry)
	_apply_top_rail_geometry()
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_boss_health()
	_card_hand.card_selected.connect(card_selected.emit)
	_card_hand.redraw_requested.connect(redraw_requested.emit)
	_card_hand.group_changed.connect(_on_card_group_changed)
	_redraw_button.pressed.connect(_on_redraw_pressed)
	_auto_use_toggle.toggled.connect(auto_use_changed.emit)
	_on_card_group_changed(_card_hand.get_active_group())
	_combo_popup.visible = false
	_mission_stack.visible = false
	_map_title_overlay.visible = false


func _apply_top_rail_geometry() -> void:
	var narrow := get_viewport_rect().size.x < NARROW_TOP_RAIL_WIDTH
	_boss_panel.custom_minimum_size.x = (
		NARROW_BOSS_PANEL_WIDTH if narrow else DEFAULT_BOSS_PANEL_WIDTH
	)
	_boss_bar.custom_minimum_size.x = (
		NARROW_BOSS_BAR_WIDTH if narrow else DEFAULT_BOSS_BAR_WIDTH
	)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible


func set_health(current: int, maximum: int) -> void:
	_set_bar(hp_bar, hp_value, current, maximum)
	if _has_health_projection and current < _projected_health:
		_pulse_vital("health", hp_value, Color(1.0, 0.42, 0.30), 1.10)
	_projected_health = current
	_has_health_projection = true


func set_mana(_current: int, _maximum: int) -> void:
	pass


func set_stamina(_current: int, _maximum: int) -> void:
	pass


func set_player_level(level: int) -> void:
	var safe_level := maxi(1, level)
	level_label.text = "Lv. %d" % safe_level
	if _has_level_projection and safe_level > _projected_level:
		_pulse_vital("level", level_label, Color(1.0, 0.94, 0.58), 1.18)
	_projected_level = safe_level
	_has_level_projection = true


func set_player_class(player_class_name: String) -> void:
	var normalized := player_class_name.strip_edges()
	class_label.text = normalized.to_upper() if not normalized.is_empty() else "ADVENTURER"


func set_currency(amount: int) -> void:
	currency_value.text = _format_number(maxi(0, amount))


func set_experience(current: int, required: int) -> void:
	var safe_required := maxi(1, required)
	var safe_current := clampi(current, 0, safe_required)
	_experience_progress.max_value = safe_required
	_experience_progress.value = safe_current
	_experience_value.text = "%d / %d · NEXT %d" % [
		safe_current,
		safe_required,
		maxi(0, safe_required - safe_current),
	]
	if (
		_has_experience_projection
		and (
			safe_current != _projected_experience
			or safe_required != _projected_experience_required
		)
	):
		_pulse_vital("experience", _experience_value, Color(0.24, 0.91, 1.0), 1.10)
	_projected_experience = safe_current
	_projected_experience_required = safe_required
	_has_experience_projection = true


func set_cards(cards: Array, energy: float) -> void:
	_card_hand.set_cards(cards, energy)
	_set_action_points_projection(energy, maxf(energy, 5.0))


func show_card_cast_feedback(card_id: String) -> bool:
	if _card_hand == null or not _card_hand.has_method("show_card_cast_feedback"):
		return false
	return bool(_card_hand.call("show_card_cast_feedback", card_id))


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
	_action_points_label.text = "%.1f / %.1f" % [safe_current, safe_maximum]
	_action_points_progress.max_value = maxf(0.1, safe_maximum)
	_action_points_progress.value = safe_current
	if _has_action_points_projection:
		if safe_current < _projected_action_points:
			_last_emphasized_action_points = safe_current
		elif (
			safe_current >= _last_emphasized_action_points + 0.5
			or (
				is_equal_approx(safe_current, safe_maximum)
				and _projected_action_points < safe_maximum
			)
		):
			_pulse_vital("action_points", _action_points_label, Color(0.58, 1.0, 0.42), 1.08)
			_last_emphasized_action_points = safe_current
	else:
		_last_emphasized_action_points = safe_current
	_projected_action_points = safe_current
	_has_action_points_projection = true
	_redraw_button.disabled = false


func _pulse_vital(
	key: String,
	control: Control,
	accent: Color,
	peak_scale: float
) -> void:
	var existing := _vitals_tweens.get(key) as Tween
	if existing != null and existing.is_valid():
		existing.kill()
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * peak_scale
	control.modulate = accent
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.38)
	tween.tween_property(control, "modulate", Color.WHITE, 0.38)
	_vitals_tweens[key] = tween


func set_action_point_regen(rate: float) -> void:
	_action_points_rate.text = "AP  +%.1f / sec" % maxf(0.0, rate)


func set_auto_attack(display_name: String) -> void:
	var normalized := display_name.strip_edges()
	_auto_attack_name.text = "AUTO · HORIZONTAL\n%s" % (
		normalized if not normalized.is_empty() else "NONE"
	)


func set_auto_use_enabled(enabled: bool) -> void:
	_auto_use_toggle.set_pressed_no_signal(enabled)


func _on_redraw_pressed() -> void:
	redraw_requested.emit()


func _on_card_group_changed(group_index: int) -> void:
	_group_label.text = "Q / W / E / R   COMBO + HEALING"
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
	var display_name := normalized if not normalized.is_empty() else "UNKNOWN AREA"
	area_name.text = display_name.to_upper()
	show_map_title(display_name)


func show_map_title(value: String) -> void:
	if _map_title_overlay == null or _map_title == null:
		return
	if _map_title_tween != null and _map_title_tween.is_valid():
		_map_title_tween.kill()
	_map_title.text = value.strip_edges().to_upper()
	_map_title_overlay.visible = true
	_map_title_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_map_title_panel.scale = Vector2(0.96, 0.96)
	_map_title_panel.pivot_offset = _map_title_panel.size * 0.5
	_map_title_tween = create_tween()
	_map_title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_map_title_tween.set_trans(Tween.TRANS_QUAD)
	_map_title_tween.set_ease(Tween.EASE_OUT)
	_map_title_tween.set_parallel(true)
	_map_title_tween.tween_property(_map_title_overlay, "modulate:a", 1.0, 0.24)
	_map_title_tween.tween_property(_map_title_panel, "scale", Vector2.ONE, 0.32)
	_map_title_tween.chain().set_parallel(false)
	_map_title_tween.tween_interval(1.45)
	_map_title_tween.tween_property(_map_title_overlay, "modulate:a", 0.0, 0.5)
	_map_title_tween.tween_callback(func() -> void: _map_title_overlay.visible = false)


func set_objective(text: String, progress: String = "") -> void:
	quest_text.text = text
	quest_progress.text = progress
	quest_progress.visible = not progress.is_empty()


func set_survival_timer(remaining: float, _total: float, final_rush: bool) -> void:
	var seconds := maxi(0, int(ceil(remaining)))
	var time_text := "%02d:%02d" % [seconds / 60, seconds % 60]
	var state_text := (
		"SURVIVED"
		if remaining <= 0.0
		else ("FINAL RUSH" if final_rush else "SURVIVE")
	)
	_survival_timer_label.text = "%s  %s" % [time_text, state_text]
	_survival_timer_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.38, 0.24, 1.0)
		if final_rush or remaining <= 0.0
		else Color(0.96, 0.87, 0.68, 1.0)
	)


func set_active_statuses(_statuses: Array) -> void:
	# Persistent effect lists were intentionally removed from this HUD.
	pass


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
		label.custom_minimum_size = Vector2(0.0, 34.0)
		_configure_clipped_feed_label(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
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
	label.tooltip_text = label.text
	label.modulate = accent
	_feed_empty_state.visible = false
	_toast_generation[key] = int(_toast_generation.get(key, 0)) + 1
	var generation := int(_toast_generation[key])
	_expire_toast(key, generation)


func set_combo_formula(
	formula: Array,
	stacks: Dictionary,
	finisher_pending: bool,
	gifts: Array,
	finisher_queue: Array = [],
	possible_finishers: Array = []
) -> void:
	var formula_names: Array[String] = []
	for card_variant in formula:
		if card_variant is Dictionary:
			formula_names.append(String(
				(card_variant as Dictionary).get("name", "Combo")
			))
	var next_finisher_name := ""
	var next_finisher_epithet := ""
	var next_finisher_full_name := ""
	if not finisher_queue.is_empty() and finisher_queue[0] is Dictionary:
		var next_finisher := finisher_queue[0] as Dictionary
		next_finisher_name = String(next_finisher.get(
			"name", next_finisher.get("display_name", "")
		)).strip_edges()
		next_finisher_epithet = String(next_finisher.get("epithet", "")).strip_edges()
		next_finisher_full_name = String(next_finisher.get(
			"display_name", "%s%s" % [next_finisher_epithet, next_finisher_name]
		)).strip_edges()
	var possible_names: Array[String] = []
	for candidate_variant in possible_finishers:
		if candidate_variant is Dictionary:
			var candidate := candidate_variant as Dictionary
			var candidate_name := String(candidate.get(
				"name", candidate.get("display_name", "")
			)).strip_edges()
			if not candidate_name.is_empty() and not possible_names.has(candidate_name):
				possible_names.append(candidate_name)
	_combo_summary.text = (
		"%s · 下一次自動攻擊" % (
			next_finisher_name
			if not next_finisher_name.is_empty()
			else "終結技已就緒"
		)
		if finisher_pending
		else "配方  %d / 3%s" % [
			formula_names.size(),
			(" · 可能：%s" % "／".join(possible_names.slice(0, 3)))
			if not possible_names.is_empty()
			else "",
		]
	)
	_combo_milestones.text = (
		"祝福冠名 · %s" % next_finisher_epithet
		if finisher_pending and not next_finisher_epithet.is_empty()
		else "無祝福冠名"
		if finisher_pending
		else " → ".join(formula_names)
		if not formula_names.is_empty()
		else "依序打出三張已學會的 Combo／治療招式"
	)
	_combo_summary.tooltip_text = (
		next_finisher_full_name
		if finisher_pending and not next_finisher_full_name.is_empty()
		else _combo_summary.text
	)
	_combo_milestones.tooltip_text = (
		"完整招式名 · %s" % next_finisher_full_name
		if finisher_pending and not next_finisher_full_name.is_empty()
		else _combo_milestones.text
	)
	var signature := "%s|%s|%s" % [
		",".join(formula_names),
		str(stacks),
		"%s|%s|%s" % [str(gifts), str(finisher_queue), str(possible_finishers)],
	]
	if signature == _combo_skills_signature:
		return
	_combo_skills_signature = signature
	for child in _combo_skill_rows.get_children():
		_combo_skill_rows.remove_child(child)
		child.queue_free()
	var stack_pairs: Array[String] = []
	for stack_key_variant in stacks:
		stack_pairs.append("%s %d" % [
			String(stack_key_variant).to_upper(),
			int(stacks[stack_key_variant]),
		])
	stack_pairs.sort()
	var stack_row := Label.new()
	stack_row.text = (
		"STACKS  " + " · ".join(stack_pairs.slice(0, 4))
		if not stack_pairs.is_empty()
		else "STACKS  —"
	)
	_configure_clipped_feed_label(stack_row)
	stack_row.add_theme_font_size_override("font_size", 10)
	stack_row.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0, 1.0))
	_combo_skill_rows.add_child(stack_row)
	for gift_variant in gifts.slice(0, 4):
		if not gift_variant is Dictionary:
			continue
		var gift := gift_variant as Dictionary
		var row := Label.new()
		row.text = "%s%s %s  等級 %d" % [
			"主神賜 · " if bool(gift.get("primary", false)) else "",
			String(gift.get("icon", "✦")),
			String(gift.get("name", "神賜")),
			int(gift.get("level", 1)),
		]
		_configure_clipped_feed_label(row)
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
		_combo_skill_rows.add_child(row)


func set_combo_chain(
	skills: Array,
	total: int = 0,
	_remaining: float = 0.0,
	flow_count: int = -1,
	flow_role: String = "",
	finisher_ready: bool = false
) -> void:
	var projected_total := maxi(0, total)
	var signature_parts: Array[String] = []
	if projected_total == 0:
		for skill_variant in skills:
			if skill_variant is Dictionary:
				projected_total += maxi(0, int((skill_variant as Dictionary).get("count", 0)))
	if flow_count < 0:
		flow_count = mini(2, projected_total)
		flow_role = "LINK" if flow_count > 0 else ""
		finisher_ready = flow_count >= 2
	for skill_variant in skills:
		if skill_variant is Dictionary:
			var skill := skill_variant as Dictionary
			signature_parts.append("%s:%d" % [
				String(skill.get("name", "Combo")),
				maxi(1, int(skill.get("count", 1))),
			])
	var skills_signature := "|".join(signature_parts)
	var rebuild_rows := skills_signature != _combo_skills_signature
	if rebuild_rows:
		_combo_skills_signature = skills_signature
		for child in _combo_skill_rows.get_children():
			_combo_skill_rows.remove_child(child)
			child.queue_free()
	if flow_count <= 0 and not finisher_ready:
		_combo_summary.text = "COMBO  ▶ START"
		_combo_milestones.text = "▶ START  →  ＋ LINK  →  ★ FINISH"
		_combo_summary.tooltip_text = _combo_summary.text
		_combo_milestones.tooltip_text = _combo_milestones.text
		if rebuild_rows:
			var empty := Label.new()
			empty.text = "REACTION CARDS KEEP YOUR ROUTE"
			_configure_clipped_feed_label(empty)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_font_size_override("font_size", 10)
			empty.add_theme_color_override("font_color", Color(0.34, 0.44, 0.46, 1.0))
			_combo_skill_rows.add_child(empty)
		return
	_combo_summary.text = (
		"COMBO READY  ★ FINISH"
		if finisher_ready
		else "COMBO  %s  %d/2" % [flow_role, maxi(0, flow_count)]
	)
	_combo_milestones.text = (
		"PLAY A FINISHER · FORWARD SHOCKWAVE"
		if finisher_ready
		else "NEXT  ＋ LINK"
	)
	_combo_summary.tooltip_text = _combo_summary.text
	_combo_milestones.tooltip_text = _combo_milestones.text
	if not rebuild_rows:
		return
	for skill_variant in skills.slice(0, MAX_VISIBLE_COMBO_SKILLS):
		if not skill_variant is Dictionary:
			continue
		var skill := skill_variant as Dictionary
		var row := Label.new()
		row.text = "◆  %s   ×%d" % [
			String(skill.get("name", "Combo")),
			maxi(1, int(skill.get("count", 1))),
		]
		_configure_clipped_feed_label(row)
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0, 1.0))
		_combo_skill_rows.add_child(row)


func show_combo_popup(skill_name: String, combo_count: int) -> void:
	var safe_count := maxi(0, combo_count)
	var safe_name := skill_name.strip_edges()
	if _combo_popup_tween != null and _combo_popup_tween.is_valid():
		_combo_popup_tween.kill()
	if safe_count <= 0 or safe_name.is_empty():
		_combo_popup.visible = false
		return
	_combo_popup.text = "%s  ×%d" % [safe_name, safe_count]
	_combo_popup.add_theme_font_size_override(
		"font_size",
		_get_combo_popup_font_size(safe_count)
	)
	_combo_popup.tooltip_text = _combo_popup.text
	_combo_popup.visible = true
	_render_combo_popup_progress(0.0)
	_combo_popup_tween = create_tween()
	_combo_popup_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_combo_popup_tween.set_trans(Tween.TRANS_QUAD)
	_combo_popup_tween.set_ease(Tween.EASE_OUT)
	_combo_popup_tween.tween_method(
		_render_combo_popup_progress,
		0.0,
		1.0,
		COMBO_POPUP_DURATION
	)
	_combo_popup_tween.tween_callback(func() -> void:
		_combo_popup.visible = false
		_combo_popup.position = Vector2.ZERO
		_combo_popup.scale = Vector2.ONE
	)


func _get_combo_popup_font_size(combo_count: int) -> int:
	var growth := roundi(sqrt(float(maxi(0, combo_count - 1))) * 2.0)
	return clampi(
		COMBO_POPUP_MIN_FONT_SIZE + growth,
		COMBO_POPUP_MIN_FONT_SIZE,
		COMBO_POPUP_MAX_FONT_SIZE
	)


func _render_combo_popup_progress(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	var punch_progress := minf(1.0, safe_progress / 0.22)
	var settle_progress := clampf((safe_progress - 0.22) / 0.20, 0.0, 1.0)
	var punch_scale := lerpf(0.96, 1.03, punch_progress)
	var settled_scale := lerpf(punch_scale, 1.0, settle_progress)
	var fade_progress := clampf((safe_progress - 0.52) / 0.48, 0.0, 1.0)
	_combo_popup.position = Vector2(0.0, lerpf(4.0, -6.0, safe_progress))
	_combo_popup.scale = Vector2.ONE * settled_scale
	_combo_popup.modulate = Color(1.0, 0.78, 0.30, 1.0 - fade_progress)


func _configure_clipped_feed_label(label: Label) -> void:
	label.custom_minimum_size.x = 0.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label.text


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
	_feed_empty_state.visible = _toast_order.is_empty()


func _set_bar(bar: ProgressBar, value_label: Label, current: int, maximum: int) -> void:
	var safe_maximum := maxi(1, maximum)
	var safe_current := clampi(current, 0, safe_maximum)
	bar.max_value = safe_maximum
	bar.value = safe_current
	value_label.text = "%d / %d" % [safe_current, safe_maximum]


func _make_display_only(node: Node) -> void:
	if node == _redraw_button or node == _auto_use_toggle:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		return
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
