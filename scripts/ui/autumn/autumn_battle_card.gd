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

var _card_id := ""
var _card_type := "CARD"
var _visual_family := "CARD"
var _affordable := true
var _row_active := true
var _hovered := false
var _fixed := false

@onready var _shortcut: Label = $CardContent/Shortcut
@onready var _card_name: Label = $CardContent/CardName
@onready var _type_label: Label = $CardContent/CardType
@onready var _icon: TextureRect = $CardContent/IconStage/Icon
@onready var _icon_frame: Panel = $CardContent/IconStage/IconFrame
@onready var _glyph: Label = $CardContent/IconStage/Glyph
@onready var _level: Label = $CardContent/Level
@onready var _cost_value: Label = $CardContent/CostRow/CostValue
@onready var _lock_badge: Label = $LockBadge


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
	var family_and_type := (
		_card_type
		if _visual_family == _card_type
		else "%s · %s" % [_visual_family, _card_type]
	)
	_type_label.text = (
		"%s ×%d" % [family_and_type, combo_stack]
		if combo_stack > 0
		else family_and_type
	)
	_level.text = "STABLE" if _fixed else "LV.%d" % maxi(1, int(card.get("level", 1)))
	_cost_value.text = str(maxi(0, int(card.get("cost", 0))))
	_lock_badge.visible = _fixed
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


func _apply_visual_state() -> void:
	var base_color := FAMILY_BACKGROUNDS.get(
		_visual_family,
		TYPE_COLORS.get(_card_type, TYPE_COLORS["CARD"])
	) as Color
	var family_accent := FAMILY_ACCENTS.get(_visual_family, FAMILY_ACCENTS["CARD"]) as Color
	var normal_border := family_accent.lerp(Color(0.95, 0.69, 0.27), 0.28 if _fixed else 0.08)
	var bright_border := family_accent.lightened(0.16)
	var inactive_border := Color(0.32, 0.27, 0.22, 0.82)
	var normal := _make_style(
		base_color if _row_active else base_color.darkened(0.48),
		normal_border if _row_active else inactive_border,
		3 if _fixed else 2,
		9 if _fixed else 4
	)
	var highlighted := _make_style(base_color.lightened(0.08), bright_border, 3, 8)
	var unavailable := _make_style(
		base_color.darkened(0.50 if _row_active else 0.62),
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
	_type_label.add_theme_color_override("font_color", family_accent.lightened(0.12))
	_cost_value.add_theme_color_override("font_color", family_accent.lightened(0.18))
	add_theme_stylebox_override("normal", highlighted if _hovered else normal)
	add_theme_stylebox_override("hover", highlighted)
	add_theme_stylebox_override("pressed", highlighted)
	add_theme_stylebox_override("focus", highlighted)
	add_theme_stylebox_override("disabled", unavailable if not _row_active or not _affordable else normal)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))


func _make_style(background: Color, border: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0.95, 0.58, 0.08, 0.55) if _fixed else Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = shadow_size
	return style


func _make_icon_frame(accent: Color, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.018, 0.025, 0.92)
	style.border_color = accent.lightened(0.18) if emphasized else accent.darkened(0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.46)
	style.shadow_size = 7 if emphasized else 4
	return style
