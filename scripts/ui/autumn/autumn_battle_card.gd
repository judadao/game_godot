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
	"HEALING": Color(0.48, 1.0, 0.50, 1.0),
	"FLAME": Color(1.0, 0.45, 0.11, 1.0),
	"VOLLEY": Color(0.72, 0.40, 1.0, 1.0),
	"STORM": Color(0.16, 0.82, 1.0, 1.0),
	"CARD": Color(0.92, 0.67, 0.25, 1.0),
}
const FAMILY_LABELS := {
	"HEALING": "生息",
	"FLAME": "業火",
	"VOLLEY": "迴響",
	"STORM": "雷霆",
	"COMBO": "劍魂",
	"CARD": "秘儀",
}
const FRAME_GOLD := Color(0.86, 0.67, 0.31, 1.0)
const FRAME_OLD_GOLD := Color(0.47, 0.33, 0.16, 1.0)
const FRAME_INK := Color(0.012, 0.016, 0.026, 0.99)
const CAST_FEEDBACK_DURATION := 0.34

var _card_id := ""
var _card_type := "CARD"
var _visual_family := "CARD"
var _affordable := true
var _row_active := true
var _hovered := false
var _fixed := false
var _cast_feedback_tween: Tween

@onready var _shortcut: Label = $CardContent/Shortcut
@onready var _card_name: Label = $CardContent/CardName
@onready var _type_label: Label = $CardContent/CardType
@onready var _icon: TextureRect = $CardContent/IconStage/Icon
@onready var _icon_frame: Panel = $CardContent/IconStage/IconFrame
@onready var _glyph: Label = $CardContent/IconStage/Glyph
@onready var _level: Label = $CardContent/Level
@onready var _cost_value: Label = $CardContent/CostRow/CostValue
@onready var _lock_badge: Label = $LockBadge
@onready var _cast_feedback: Panel = $CastFeedback


func configure(card: Dictionary, shortcut: String, affordable: bool) -> void:
	_cache_nodes()
	_card_id = String(card.get("id", ""))
	_card_type = String(card.get("type", "card")).to_upper()
	if not TYPE_COLORS.has(_card_type):
		_card_type = "CARD"
	_visual_family = String(VISUAL_FAMILY_BY_ID.get(_card_id, _card_type))
	_affordable = affordable
	_fixed = bool(card.get("fixed", false))
	tooltip_text = String(card.get("description", ""))
	_shortcut.text = shortcut
	_card_name.text = String(card.get("name", "Card"))
	var combo_stack := maxi(0, int(card.get("combo_stack", 0)))
	var family_label := String(FAMILY_LABELS.get(
		_visual_family,
		FAMILY_LABELS.get(_card_type, FAMILY_LABELS["CARD"])
	))
	var family_and_type := "%s · %s" % [family_label, _card_type]
	_type_label.text = (
		"%s ×%d" % [family_and_type, combo_stack]
		if combo_stack > 0
		else family_and_type
	)
	_level.text = "固定契印" if _fixed else "等級 %d" % maxi(1, int(card.get("level", 1)))
	_cost_value.text = str(maxi(0, int(card.get("cost", 0))))
	_lock_badge.visible = _fixed
	_lock_badge.text = "契印"
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
	_card_name = get_node("CardContent/CardName") as Label
	_type_label = get_node("CardContent/CardType") as Label
	_icon = get_node("CardContent/IconStage/Icon") as TextureRect
	_icon_frame = get_node("CardContent/IconStage/IconFrame") as Panel
	_glyph = get_node("CardContent/IconStage/Glyph") as Label
	_level = get_node("CardContent/Level") as Label
	_cost_value = get_node("CardContent/CostRow/CostValue") as Label
	_lock_badge = get_node("LockBadge") as Label
	_cast_feedback = get_node("CastFeedback") as Panel


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


func get_frame_design_state() -> Dictionary:
	return {
		"frame_layers": 3,
		"ritual_rings": 3,
		"corner_marks": 4,
		"name_plate": true,
		"visual_family": _visual_family,
		"accent": FAMILY_ACCENTS.get(_visual_family, FAMILY_ACCENTS["CARD"]),
	}


func _finish_cast_feedback() -> void:
	if _cast_feedback == null:
		return
	_cast_feedback.visible = false
	_cast_feedback.modulate = Color.WHITE
	_cast_feedback.scale = Vector2.ONE


func _apply_visual_state() -> void:
	var base_color := FAMILY_BACKGROUNDS.get(
		_visual_family,
		TYPE_COLORS.get(_card_type, TYPE_COLORS["CARD"])
	) as Color
	var family_accent := FAMILY_ACCENTS.get(_visual_family, FAMILY_ACCENTS["CARD"]) as Color
	var card_ink := FRAME_INK.lerp(base_color.darkened(0.34), 0.62)
	var normal_border := FRAME_GOLD.lerp(family_accent, 0.28 if _fixed else 0.18)
	var bright_border := family_accent.lightened(0.16)
	var inactive_border := FRAME_OLD_GOLD.darkened(0.28)
	var normal := _make_style(
		card_ink if _row_active else card_ink.darkened(0.48),
		normal_border if _row_active else inactive_border,
		4 if _fixed else 3,
		10 if _fixed else 7
	)
	var highlighted := _make_style(card_ink.lightened(0.055), bright_border, 4, 11)
	var unavailable := _make_style(
		card_ink.darkened(0.50 if _row_active else 0.62),
		Color(0.34, 0.30, 0.26, 0.86),
		2,
		2
	)
	if _fixed and not _row_active:
		unavailable.border_color = Color(0.72, 0.52, 0.20, 0.92)
		unavailable.shadow_color = Color(0.95, 0.58, 0.08, 0.40)
		unavailable.shadow_size = 6
	if _icon_frame != null:
		_icon_frame.add_theme_stylebox_override(
			"panel",
			_make_icon_frame(family_accent, _hovered)
		)
	_shortcut.add_theme_stylebox_override("normal", _make_shortcut_seal(family_accent))
	_shortcut.add_theme_color_override("font_color", FRAME_GOLD.lightened(0.18))
	_card_name.add_theme_color_override(
		"font_color",
		Color(1.0, 0.92, 0.73, 1.0)
	)
	_type_label.add_theme_color_override("font_color", family_accent.lightened(0.12))
	_cost_value.add_theme_color_override("font_color", family_accent.lightened(0.18))
	_lock_badge.add_theme_color_override("font_color", FRAME_GOLD.lightened(0.16))
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
	style.set_corner_radius_all(4)
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0.80, 0.53, 0.18, 0.48) if _fixed else Color(0.0, 0.0, 0.0, 0.82)
	style.shadow_size = shadow_size
	return style


func _make_icon_frame(accent: Color, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.009, 0.016, 0.96)
	style.border_color = accent.lightened(0.20) if emphasized else FRAME_GOLD.lerp(accent, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.shadow_size = 9 if emphasized else 6
	return style


func _make_shortcut_seal(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_INK.lightened(0.025)
	style.border_color = FRAME_GOLD.lerp(accent, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.34)
	style.shadow_size = 3
	return style


func _make_cast_feedback_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	style.border_color = accent.lightened(0.22)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.72)
	style.shadow_size = 9
	return style


func _draw() -> void:
	if size.x < 20.0 or size.y < 30.0:
		return
	var accent := FAMILY_ACCENTS.get(
		_visual_family,
		FAMILY_ACCENTS["CARD"]
	) as Color
	var energy_alpha := 0.44 if _hovered else 0.28
	var frame_alpha := 0.92 if _row_active else 0.42
	var inner_rect := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
	var ritual_rect := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
	draw_rect(inner_rect, Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, frame_alpha), false, 1.0)
	draw_rect(ritual_rect, Color(accent.r, accent.g, accent.b, energy_alpha), false, 1.0)

	var center := Vector2(size.x * 0.5, size.y * 0.36)
	var outer_radius := minf(size.x * 0.34, size.y * 0.22)
	for ring_index in 3:
		var ring_radius := outer_radius * (0.55 + float(ring_index) * 0.22)
		var ring_color := Color(
			accent.r,
			accent.g,
			accent.b,
			energy_alpha * (0.92 - float(ring_index) * 0.18)
		)
		draw_arc(center, ring_radius, 0.0, TAU, 32, ring_color, 1.0, true)
	for spoke_index in 8:
		var angle := TAU * float(spoke_index) / 8.0
		var direction := Vector2.from_angle(angle)
		draw_line(
			center + direction * outer_radius * 0.78,
			center + direction * outer_radius * 1.10,
			Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, energy_alpha * 0.72),
			1.0,
			true
		)
	draw_circle(center, 2.0, Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, frame_alpha))

	var corner_length := clampf(size.x * 0.12, 9.0, 15.0)
	var corner_color := Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, frame_alpha)
	_draw_corner_mark(Vector2(3.0, 3.0), Vector2.RIGHT, Vector2.DOWN, corner_length, corner_color)
	_draw_corner_mark(Vector2(size.x - 3.0, 3.0), Vector2.LEFT, Vector2.DOWN, corner_length, corner_color)
	_draw_corner_mark(Vector2(3.0, size.y - 3.0), Vector2.RIGHT, Vector2.UP, corner_length, corner_color)
	_draw_corner_mark(Vector2(size.x - 3.0, size.y - 3.0), Vector2.LEFT, Vector2.UP, corner_length, corner_color)

	var name_top := size.y * 0.56
	if _card_name != null and is_instance_valid(_card_name):
		name_top = _card_name.get_global_transform_with_canvas().origin.y - get_global_transform_with_canvas().origin.y - 1.0
	var name_height := 30.0
	var name_plate := Rect2(Vector2(7.0, name_top), Vector2(size.x - 14.0, name_height))
	draw_rect(name_plate, Color(0.006, 0.009, 0.016, 0.78), true)
	draw_line(name_plate.position, name_plate.position + Vector2(name_plate.size.x, 0.0), corner_color, 1.0)
	draw_line(name_plate.end - Vector2(name_plate.size.x, 0.0), name_plate.end, Color(accent.r, accent.g, accent.b, energy_alpha), 1.0)


func _draw_corner_mark(
	origin: Vector2,
	horizontal: Vector2,
	vertical: Vector2,
	length: float,
	color: Color
) -> void:
	draw_line(origin, origin + horizontal * length, color, 2.0, true)
	draw_line(origin, origin + vertical * length, color, 2.0, true)
	var notch := origin + (horizontal + vertical) * 4.0
	draw_circle(notch, 1.5, color)
