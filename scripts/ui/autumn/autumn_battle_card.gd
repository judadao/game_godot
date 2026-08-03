@tool
class_name AutumnBattleCard
extends Button

const TYPE_COLORS := {
	"ATTACK": Color(0.31, 0.075, 0.035, 0.98),
	"COMBO": Color(0.11, 0.08, 0.20, 0.98),
	"HEALING": Color(0.025, 0.22, 0.09, 0.98),
	"UTILITY": Color(0.07, 0.12, 0.20, 0.98),
	"POWER": Color(0.27, 0.13, 0.025, 0.98),
	"SUMMON": Color(0.025, 0.17, 0.13, 0.98),
	"STATUS": Color(0.035, 0.15, 0.19, 0.98),
	"ULTIMATE": Color(0.28, 0.035, 0.10, 0.98),
	"CARD": Color(0.12, 0.075, 0.045, 0.98),
}
const TYPE_GLYPHS := {
	"ATTACK": "⚔",
	"COMBO": "◆",
	"HEALING": "✚",
	"UTILITY": "✦",
	"POWER": "♜",
	"SUMMON": "♣",
	"STATUS": "❖",
	"ULTIMATE": "★",
	"CARD": "◇",
}
const GENERATED_ICONS := {
	"healing_light": preload("res://assets/ui/autumn/cards/generated/healing_light.png"),
	"flame_imbue": preload("res://assets/ui/autumn/cards/generated/flame_imbue.png"),
	"echo_volley": preload("res://assets/ui/autumn/cards/generated/echo_volley.png"),
	"storm_charge": preload("res://assets/ui/autumn/cards/generated/storm_charge.png"),
}
const VISUAL_FAMILY_BY_ID := {
	"healing_light": "HEALING",
	"flame_imbue": "FLAME",
	"echo_volley": "VOLLEY",
	"storm_charge": "STORM",
}
const FAMILY_BACKGROUNDS := {
	"HEALING": Color(0.02, 0.16, 0.065, 0.99),
	"FLAME": Color(0.22, 0.055, 0.018, 0.99),
	"VOLLEY": Color(0.085, 0.045, 0.19, 0.99),
	"STORM": Color(0.018, 0.095, 0.16, 0.99),
	"CARD": Color(0.12, 0.075, 0.045, 0.98),
}
const FAMILY_ACCENTS := {
	"HEALING": Color(0.57, 0.70, 0.43, 1.0),
	"FLAME": Color(0.72, 0.39, 0.22, 1.0),
	"VOLLEY": Color(0.53, 0.42, 0.66, 1.0),
	"STORM": Color(0.33, 0.57, 0.62, 1.0),
	"CARD": Color(0.66, 0.50, 0.27, 1.0),
}
const FAMILY_LABELS := {
	"HEALING": "生息",
	"FLAME": "業火",
	"VOLLEY": "迴響",
	"STORM": "雷霆",
	"COMBO": "劍魂",
	"CARD": "秘儀",
}
const FAMILY_GLYPHS := {
	"HEALING": "✚",
	"FLAME": "♨",
	"VOLLEY": "➶",
	"STORM": "ϟ",
	"COMBO": "◆",
	"CARD": "◇",
}
const TYPE_DISPLAY_NAMES := {
	"ATTACK": "攻擊",
	"COMBO": "連段",
	"HEALING": "治療",
	"UTILITY": "機巧",
	"POWER": "強化",
	"SUMMON": "召喚",
	"STATUS": "狀態",
	"ULTIMATE": "終結",
	"CARD": "劍魂",
}
const FRAME_GOLD := Color(0.67, 0.52, 0.30, 1.0)
const FRAME_OLD_GOLD := Color(0.34, 0.25, 0.15, 1.0)
const FRAME_INK := Color(0.010, 0.012, 0.017, 0.995)
const CAST_FEEDBACK_DURATION := 0.34

var _card_id := ""
var _card_type := "CARD"
var _visual_family := "CARD"
var _affordable := true
var _row_active := true
var _hovered := false
var _fixed := false
var _cast_feedback_tween: Tween
var _cast_arc_tween: Tween
var _animation_phase := 0.0
var _cast_intensity := 0.0

@onready var _shortcut: Label = $CardContent/Shortcut
@onready var _ink_wash: ColorRect = $CardContent/InkWash
@onready var _halo_layer: TextureRect = $CardContent/CelestialHalo
@onready var _header_band: Panel = $CardContent/HeaderBand
@onready var _card_name: Label = $CardContent/CardName
@onready var _name_band: Panel = $CardContent/NameBand
@onready var _category_band: Panel = $CardContent/CategoryBand
@onready var _type_label: Label = $CardContent/CardType
@onready var _icon: TextureRect = $CardContent/IconStage/Icon
@onready var _icon_frame: Panel = $CardContent/IconStage/IconFrame
@onready var _glyph: Label = $CardContent/IconStage/Glyph
@onready var _raven_layer: TextureRect = $CardContent/SpectralRavens
@onready var _vines_layer: TextureRect = $CardContent/VinesSmoke
@onready var _sun_wave: Control = $CardContent/SunWave
@onready var _tarot_frame: Control = $CardContent/TarotFrameOverlay
@onready var _level: Label = $CardContent/Level
@onready var _type_gem: Label = $CardContent/TypeGem
@onready var _cost_label: Label = $CardContent/CostRow/CostLabel
@onready var _cost_seal: Panel = $CardContent/CostRow/APSeal
@onready var _cost_inner_ring: Panel = $CardContent/CostRow/APInnerRing
@onready var _cost_value: Label = $CardContent/CostRow/CostValue
@onready var _lock_badge: Label = $LockBadge
@onready var _cast_feedback: Panel = $CastFeedback


func _ready() -> void:
	_cache_nodes()
	set_process(true)
	_sync_adaptive_layout()
	resized.connect(_sync_adaptive_layout)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var speed := 1.05 if _hovered else 0.58
	_animation_phase = fmod(_animation_phase + delta * speed, TAU)
	var breath := (sin(_animation_phase) + 1.0) * 0.5
	if _tarot_frame != null:
		_tarot_frame.scale = Vector2.ONE
		_tarot_frame.call("set_energy", 0.94 if _hovered else 0.58 + breath * 0.20)
	if _halo_layer != null:
		_halo_layer.visible = false
	if _raven_layer != null:
		_raven_layer.rotation = sin(_animation_phase * 0.72) * (0.004 if _hovered else 0.002)
		_raven_layer.position.y = sin(_animation_phase * 0.83) * (0.7 if _hovered else 0.35)
	if _vines_layer != null:
		var vines_scale := 1.0 + breath * (0.004 if _hovered else 0.002)
		_vines_layer.scale = Vector2.ONE * vines_scale
	if _sun_wave != null:
		_sun_wave.call("set_energy", 0.92 if _hovered else 0.58 + breath * 0.18)
	if _icon != null and _icon.visible:
		var art_scale := 1.0 + breath * (0.009 if _hovered else 0.004)
		_icon.scale = Vector2.ONE * art_scale
	queue_redraw()


func configure(card: Dictionary, shortcut: String, affordable: bool) -> void:
	_cache_nodes()
	_card_id = String(card.get("id", ""))
	_card_type = String(card.get("type", "card")).to_upper()
	if not TYPE_COLORS.has(_card_type):
		_card_type = "CARD"
	_visual_family = String(VISUAL_FAMILY_BY_ID.get(_card_id, _card_type))
	_affordable = affordable
	_fixed = bool(card.get("fixed", false))
	var display_name := String(card.get("name", "Card"))
	var description := String(card.get("description", ""))
	tooltip_text = display_name if description.is_empty() else "%s\n%s" % [display_name, description]
	_shortcut.text = shortcut
	_card_name.text = display_name
	_sync_adaptive_layout()
	var combo_stack := maxi(0, int(card.get("combo_stack", 0)))
	var family_label := String(FAMILY_LABELS.get(
		_visual_family,
		FAMILY_LABELS.get(_card_type, FAMILY_LABELS["CARD"])
	))
	var family_and_type := "%s%s" % [
		family_label,
		String(TYPE_DISPLAY_NAMES.get(_card_type, TYPE_DISPLAY_NAMES["CARD"])),
	]
	_type_label.text = family_and_type
	_level.text = str(combo_stack)
	_level.visible = false
	_type_gem.text = String(FAMILY_GLYPHS.get(_visual_family, FAMILY_GLYPHS["CARD"]))
	_type_gem.visible = true
	_cost_value.text = str(maxi(0, int(card.get("cost", 0))))
	_lock_badge.visible = false
	_lock_badge.text = "契印"
	if _sun_wave != null:
		_sun_wave.call("set_phase_offset", float(abs(_card_id.hash()) % 1000) / 1000.0 * TAU)
	_finish_cast_feedback()
	var icon_path := String(card.get("icon_path", ""))
	var generated_icon := GENERATED_ICONS.get(_card_id) as Texture2D
	var has_icon := generated_icon != null or (
		not icon_path.is_empty() and ResourceLoader.exists(icon_path)
	)
	_icon.visible = has_icon
	_glyph.visible = not has_icon
	_glyph.text = String(TYPE_GLYPHS.get(_card_type, TYPE_GLYPHS["CARD"]))
	if has_icon:
		_icon.texture = (
			generated_icon
			if generated_icon != null
			else load(icon_path) as Texture2D
		)
		_icon.texture_filter = (
			CanvasItem.TEXTURE_FILTER_LINEAR
			if generated_icon != null
			else CanvasItem.TEXTURE_FILTER_NEAREST
		)
	set_row_active(true, affordable)
	queue_redraw()


func _cache_nodes() -> void:
	if _shortcut != null:
		return
	_shortcut = get_node("CardContent/Shortcut") as Label
	_ink_wash = get_node("CardContent/InkWash") as ColorRect
	_halo_layer = get_node("CardContent/CelestialHalo") as TextureRect
	_header_band = get_node("CardContent/HeaderBand") as Panel
	_card_name = get_node("CardContent/CardName") as Label
	_name_band = get_node("CardContent/NameBand") as Panel
	_category_band = get_node("CardContent/CategoryBand") as Panel
	_type_label = get_node("CardContent/CardType") as Label
	_icon = get_node("CardContent/IconStage/Icon") as TextureRect
	_icon_frame = get_node("CardContent/IconStage/IconFrame") as Panel
	_glyph = get_node("CardContent/IconStage/Glyph") as Label
	_raven_layer = get_node("CardContent/SpectralRavens") as TextureRect
	_vines_layer = get_node("CardContent/VinesSmoke") as TextureRect
	_sun_wave = get_node("CardContent/SunWave") as Control
	_tarot_frame = get_node("CardContent/TarotFrameOverlay") as Control
	_level = get_node("CardContent/Level") as Label
	_type_gem = get_node("CardContent/TypeGem") as Label
	_cost_label = get_node("CardContent/CostRow/CostLabel") as Label
	_cost_seal = get_node("CardContent/CostRow/APSeal") as Panel
	_cost_inner_ring = get_node("CardContent/CostRow/APInnerRing") as Panel
	_cost_value = get_node("CardContent/CostRow/CostValue") as Label
	_lock_badge = get_node("LockBadge") as Label
	_cast_feedback = get_node("CastFeedback") as Panel
	_sync_adaptive_layout()


func _sync_adaptive_layout() -> void:
	_sync_motion_pivots()
	_layout_name_cartouche()


func _layout_name_cartouche() -> void:
	if _name_band == null or _card_name == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var name_left := size.x * 0.13
	var cost_left := size.x * 0.82 - 19.0
	var name_right := maxf(name_left + 24.0, cost_left - 3.0)
	var name_top := size.y * 0.805
	var name_bottom := size.y * 0.96
	_name_band.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_name_band.position = Vector2(name_left, name_top)
	_name_band.size = Vector2(name_right - name_left, name_bottom - name_top)
	_card_name.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card_name.position = _name_band.position + Vector2(3.0, 1.0)
	_card_name.size = Vector2(
		maxf(18.0, _name_band.size.x - 6.0),
		maxf(16.0, _name_band.size.y - 2.0)
	)
	_fit_card_name()


func _fit_card_name() -> void:
	if _card_name == null or _card_name.size.x <= 1.0:
		return
	var font := _card_name.get_theme_font("font")
	var max_size := clampi(int(roundf(size.y * 0.068)), 14, 18)
	var chosen_size := max_size
	if font != null:
		for candidate_size in range(max_size, 11, -1):
			var measured := font.get_string_size(
				_card_name.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				candidate_size
			)
			chosen_size = candidate_size
			var fits_one_line := measured.x <= _card_name.size.x - 2.0
			var fits_two_lines := (
				measured.x <= (_card_name.size.x - 2.0) * 1.86
				and font.get_height(candidate_size) * 2.0 <= _card_name.size.y
			)
			if fits_one_line or fits_two_lines:
				break
	_card_name.add_theme_font_size_override("font_size", chosen_size)
	_card_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_card_name.max_lines_visible = 2
	_card_name.clip_text = true
	_card_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _sync_motion_pivots() -> void:
	if _tarot_frame != null:
		_tarot_frame.pivot_offset = _tarot_frame.size * 0.5
	if _halo_layer != null:
		_halo_layer.pivot_offset = _halo_layer.size * 0.5
	if _raven_layer != null:
		_raven_layer.pivot_offset = _raven_layer.size * 0.5
	if _vines_layer != null:
		_vines_layer.pivot_offset = _vines_layer.size * 0.5
	if _icon != null:
		_icon.pivot_offset = _icon.size * 0.5


func set_row_active(active: bool, affordable: bool) -> void:
	_row_active = active
	_affordable = affordable
	disabled = not _row_active or not _affordable
	_apply_visual_state()


func set_affordable(affordable: bool) -> void:
	set_row_active(_row_active, affordable)


func set_hovered(hovered: bool) -> void:
	_hovered = hovered and _row_active and _affordable
	_apply_visual_state()


func is_row_active() -> bool:
	return _row_active


func is_affordable() -> bool:
	return _affordable


func is_fixed() -> bool:
	return _fixed


func get_visual_family() -> String:
	return _visual_family


func play_cast_feedback() -> void:
	_cache_nodes()
	if _cast_feedback_tween != null and _cast_feedback_tween.is_valid():
		_cast_feedback_tween.kill()
	if _cast_arc_tween != null and _cast_arc_tween.is_valid():
		_cast_arc_tween.kill()
	var accent := FAMILY_ACCENTS.get(
		_visual_family,
		FAMILY_ACCENTS["CARD"]
	) as Color
	_cast_feedback.add_theme_stylebox_override(
		"panel",
		_make_cast_feedback_style(accent)
	)
	_cast_feedback.visible = true
	_cast_feedback.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_cast_feedback.scale = Vector2(0.96, 0.96)
	_cast_feedback.pivot_offset = size * 0.5
	_cast_intensity = 1.0
	_cast_arc_tween = create_tween()
	_cast_arc_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cast_arc_tween.set_trans(Tween.TRANS_QUAD)
	_cast_arc_tween.set_ease(Tween.EASE_OUT)
	_cast_arc_tween.tween_method(
		_set_cast_intensity,
		1.0,
		0.0,
		CAST_FEEDBACK_DURATION
	)
	_cast_feedback_tween = create_tween()
	_cast_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cast_feedback_tween.set_trans(Tween.TRANS_QUAD)
	_cast_feedback_tween.set_ease(Tween.EASE_OUT)
	_cast_feedback_tween.tween_property(
		_cast_feedback,
		"modulate:a",
		1.0,
		0.08
	)
	_cast_feedback_tween.parallel().tween_property(
		_cast_feedback,
		"scale",
		Vector2(1.025, 1.025),
		0.08
	)
	_cast_feedback_tween.tween_property(
		_cast_feedback,
		"modulate:a",
		0.0,
		CAST_FEEDBACK_DURATION - 0.08
	)
	_cast_feedback_tween.parallel().tween_property(
		_cast_feedback,
		"scale",
		Vector2.ONE,
		CAST_FEEDBACK_DURATION - 0.08
	)
	_cast_feedback_tween.tween_callback(_finish_cast_feedback)


func is_cast_feedback_active() -> bool:
	return _cast_feedback != null and _cast_feedback.visible


func get_cast_feedback_duration() -> float:
	return CAST_FEEDBACK_DURATION


func get_motion_state() -> Dictionary:
	return {
		"idle_breathing": is_processing(),
		"halo_breathing": is_processing(),
		"raven_drift": is_processing(),
		"vines_breathing": is_processing(),
		"sun_wave_visualizer": _sun_wave != null and _sun_wave.is_processing(),
		"gold_charge_flow": _tarot_frame != null
			and _tarot_frame.has_method("get_geometry_state")
			and bool((_tarot_frame.call("get_geometry_state") as Dictionary).get("animated_charge", false)),
		"frame_shimmer": is_processing(),
		"hover_acceleration": true,
		"cast_arc": true,
	}


func get_frame_design_state() -> Dictionary:
	return {
		"frame_layers": 4,
		"shared_frame_asset": false,
		"shared_frame_geometry": true,
		"code_native_geometry": true,
		"aligned_transparent_layers": true,
		"seven_by_eight": true,
		"name_plate": true,
		"full_artwork": true,
		"monochrome_gold": true,
		"shortcut_key_seal": true,
		"ap_medallion": true,
		"category_tab": true,
		"stack_seal": false,
		"type_gem": true,
		"category_gem": false,
		"dedicated_name_band": true,
		"organic_tarot_overlay": true,
		"no_table_grid": true,
		"motion_layers": 4,
		"audio_wave_rays": true,
		"gold_charge_flow": true,
		"visual_family": _visual_family,
		"accent": FAMILY_ACCENTS.get(_visual_family, FAMILY_ACCENTS["CARD"]),
	}


func _finish_cast_feedback() -> void:
	if _cast_feedback == null:
		return
	_cast_feedback.visible = false
	_cast_feedback.modulate = Color.WHITE
	_cast_feedback.scale = Vector2.ONE
	_cast_intensity = 0.0
	queue_redraw()


func _set_cast_intensity(value: float) -> void:
	_cast_intensity = clampf(value, 0.0, 1.0)
	queue_redraw()


func _apply_visual_state() -> void:
	var family_accent := FAMILY_ACCENTS.get(_visual_family, FAMILY_ACCENTS["CARD"]) as Color
	var normal_border := FRAME_GOLD.lightened(0.03 if _fixed else 0.0)
	var bright_border := FRAME_GOLD.lightened(0.12)
	var inactive_border := FRAME_OLD_GOLD.darkened(0.28)
	var normal := _make_style(
		Color(0.0, 0.0, 0.0, 0.0),
		normal_border if _row_active else inactive_border,
		0,
		0
	)
	var highlighted := _make_style(Color(0.0, 0.0, 0.0, 0.0), bright_border, 0, 2)
	var unavailable := _make_style(
		Color(0.004, 0.005, 0.008, 0.42),
		Color(0.34, 0.30, 0.26, 0.86),
		0,
		1
	)
	if _fixed and not _row_active:
		unavailable.border_color = Color(0.72, 0.52, 0.20, 0.92)
		unavailable.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
		unavailable.shadow_size = 2
	if _icon_frame != null:
		_icon_frame.add_theme_stylebox_override(
			"panel",
			_make_icon_frame(family_accent, _hovered)
		)
	if _ink_wash != null:
		_ink_wash.color = Color(0.0, 0.0, 0.0, 0.0)
	if _halo_layer != null:
		_halo_layer.visible = false
	if _raven_layer != null:
		_raven_layer.visible = _visual_family == "VOLLEY"
		_raven_layer.self_modulate = Color(
			family_accent.r,
			family_accent.g,
			family_accent.b,
			0.58
		)
	if _vines_layer != null:
		_vines_layer.visible = _visual_family == "HEALING"
		var vines_tint := FRAME_GOLD.lerp(family_accent, 0.32)
		_vines_layer.self_modulate = Color(vines_tint.r, vines_tint.g, vines_tint.b, 0.52)
	if _tarot_frame != null:
		_tarot_frame.call("set_accent", family_accent)
	_shortcut.add_theme_stylebox_override("normal", _make_shortcut_seal(family_accent))
	_shortcut.add_theme_color_override("font_color", Color(0.86, 0.77, 0.59, 1.0))
	_header_band.add_theme_stylebox_override("panel", _make_header_band())
	_name_band.add_theme_stylebox_override("panel", _make_name_band())
	_category_band.add_theme_stylebox_override("panel", _make_category_band(family_accent))
	_card_name.add_theme_color_override(
		"font_color",
		Color(0.92, 0.86, 0.72, 1.0)
	)
	_type_label.add_theme_color_override("font_color", family_accent.lightened(0.05))
	_cost_label.add_theme_color_override("font_color", Color(0.66, 0.57, 0.41, 1.0))
	_cost_label.visible = false
	_cost_seal.visible = false
	_cost_inner_ring.visible = false
	_cost_seal.add_theme_stylebox_override("panel", _make_cost_seal(family_accent))
	_cost_inner_ring.add_theme_stylebox_override("panel", _make_cost_inner_ring(family_accent))
	_cost_value.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66, 1.0))
	_cost_value.remove_theme_stylebox_override("normal")
	_lock_badge.visible = false
	_level.visible = false
	_type_gem.visible = true
	_type_gem.add_theme_color_override("font_color", family_accent.lightened(0.12))
	add_theme_stylebox_override("normal", highlighted if _hovered else normal)
	add_theme_stylebox_override("hover", highlighted)
	add_theme_stylebox_override("pressed", highlighted)
	add_theme_stylebox_override("focus", highlighted)
	add_theme_stylebox_override("disabled", unavailable if not _row_active or not _affordable else normal)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))
	queue_redraw()


func _make_style(background: Color, border: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	style.shadow_size = shadow_size
	return style


func _make_icon_frame(_accent: Color, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.009, 0.016, 0.18 if emphasized else 0.08)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	return style


func _make_shortcut_seal(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.010, 0.012, 0.92)
	style.border_color = FRAME_GOLD.lerp(accent, 0.18).lightened(0.06)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.68)
	style.shadow_size = 2
	return style


func _make_header_band() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.014, 0.018, 0.98)
	style.border_color = FRAME_OLD_GOLD.lightened(0.05)
	style.border_width_bottom = 1
	return style


func _make_name_band() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.052, 0.026, 0.46)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(3)
	return style


func _make_category_band(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.016, 0.86)
	style.border_color = FRAME_GOLD.lerp(accent, 0.16).lightened(0.04)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	return style


func _make_cost_seal(_accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.011, 0.017, 0.985)
	style.border_color = FRAME_GOLD.lightened(0.04)
	style.set_border_width_all(1)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.76)
	style.shadow_size = 2
	return style


func _make_cost_inner_ring(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = FRAME_OLD_GOLD.lerp(accent, 0.16).lightened(0.04)
	style.set_border_width_all(1)
	style.set_corner_radius_all(19)
	return style


func _make_cast_feedback_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.015)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	return style


func _draw() -> void:
	if size.x < 20.0 or size.y < 30.0 or _cast_intensity <= 0.001:
		return
	var accent := FAMILY_ACCENTS.get(
		_visual_family,
		FAMILY_ACCENTS["CARD"]
	) as Color
	var center := Vector2(size.x * 0.5, size.y * 0.49)
	var radius := minf(size.x * 0.34, size.y * 0.22)
	var start_angle := -PI * 0.72 + (1.0 - _cast_intensity) * PI * 0.28
	draw_arc(
		center,
		radius,
		start_angle,
		start_angle + PI * 1.44,
		40,
		Color(accent.r, accent.g, accent.b, _cast_intensity * 0.72),
		1.5,
		true
	)
