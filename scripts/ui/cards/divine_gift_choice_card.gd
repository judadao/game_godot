@tool
class_name DivineGiftChoiceCard
extends Button

const INK := Color(0.018, 0.014, 0.020, 0.99)
const GOLD := Color(0.94, 0.70, 0.25, 1.0)
const OLD_GOLD := Color(0.48, 0.32, 0.13, 1.0)

var _accent := GOLD
var _selected := false
var _effect_lines: Array[String] = []


func configure(choice: Dictionary, effect_lines: Array[String]) -> void:
	var icon_label := get_node("CardContent/Header/GiftIcon") as Label
	var name_label := get_node("CardContent/Header/Identity/Name") as Label
	var level_label := get_node("CardContent/Header/Identity/Level") as Label
	var class_label := get_node("CardContent/Header/Identity/EffectClass") as Label
	var description_label := get_node("CardContent/Description") as Label
	var effect_list := get_node("CardContent/EffectList") as VBoxContainer
	_accent = Color.from_string(
		String(choice.get("accent_color", "")),
		_element_accent(String(choice.get("element", "normal")))
	)
	_effect_lines = effect_lines.duplicate()
	icon_label.text = String(choice.get("icon", "✦"))
	icon_label.add_theme_color_override("font_color", _accent.lightened(0.24))
	name_label.text = String(choice.get("name", "神賜"))
	var current_level := maxi(0, int(choice.get("level", 0)))
	var next_level := maxi(current_level + 1, int(choice.get("next_level", current_level + 1)))
	level_label.text = (
		"滿級神賜融合"
		if String(choice.get("action", "")) == "divine_fusion"
		else "等級 %d  →  %d" % [current_level, next_level]
	)
	class_label.text = _effect_class_text(choice)
	class_label.add_theme_color_override("font_color", _accent.lightened(0.20))
	description_label.text = String(choice.get(
		"description",
		"改變連段招式與具名終結技。"
	))
	for child in effect_list.get_children():
		(child as Label).visible = false
	for index in mini(_effect_lines.size(), effect_list.get_child_count()):
		var effect_label := effect_list.get_child(index) as Label
		effect_label.text = _effect_lines[index]
		effect_label.visible = true
	tooltip_text = "%s\n\n%s\n\n%s" % [
		name_label.text,
		description_label.text,
		"\n".join(_effect_lines),
	]
	set_selected_state(false)


func set_selected_state(selected: bool) -> void:
	_selected = selected
	button_pressed = selected
	(get_node("SelectedBadge") as Label).visible = selected
	_apply_styles()
	queue_redraw()


func get_effect_bullet_count() -> int:
	return _effect_lines.size()


func get_effect_lines() -> Array[String]:
	return _effect_lines.duplicate()


func _apply_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = INK.lerp(Color(_accent.r * 0.12, _accent.g * 0.10, _accent.b * 0.08, 1.0), 0.18)
	normal.border_color = OLD_GOLD.lightened(0.18)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	normal.shadow_size = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = INK.lightened(0.045)
	hover.border_color = GOLD.lightened(0.28)
	hover.set_border_width_all(3)
	hover.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
	hover.shadow_size = 9
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = INK.lightened(0.055)
	selected.border_color = GOLD.lightened(0.34)
	selected.set_border_width_all(4)
	selected.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.66)
	selected.shadow_size = 12
	add_theme_stylebox_override("normal", selected if _selected else normal)
	add_theme_stylebox_override("hover", selected if _selected else hover)
	add_theme_stylebox_override("pressed", selected)
	add_theme_stylebox_override("focus", selected if _selected else hover)
	add_theme_stylebox_override("disabled", normal)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = GOLD.lightened(0.18)
	badge_style.border_color = Color(0.12, 0.06, 0.01, 1.0)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(2)
	(get_node("SelectedBadge") as Label).add_theme_stylebox_override("normal", badge_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)


func _draw() -> void:
	if size.x < 80.0 or size.y < 120.0:
		return
	var frame_color := Color(GOLD.r, GOLD.g, GOLD.b, 0.96 if _selected else 0.70)
	draw_rect(Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0)), frame_color, false, 1.0)
	draw_rect(Rect2(Vector2(10.0, 10.0), size - Vector2(20.0, 20.0)), Color(_accent.r, _accent.g, _accent.b, 0.34), false, 1.0)
	var halo_center := Vector2(58.0, 58.0)
	for ring_index in 3:
		draw_arc(
			halo_center,
			25.0 + float(ring_index) * 6.0,
			0.0,
			TAU,
			32,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.42 - float(ring_index) * 0.09),
			1.0,
			true
		)
	for spoke_index in 12:
		var direction := Vector2.from_angle(TAU * float(spoke_index) / 12.0)
		draw_line(
			halo_center + direction * 29.0,
			halo_center + direction * 35.0,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.46),
			1.0,
			true
		)
	var corner_length := 16.0
	_draw_corner(Vector2(4.0, 4.0), Vector2.RIGHT, Vector2.DOWN, corner_length, frame_color)
	_draw_corner(Vector2(size.x - 4.0, 4.0), Vector2.LEFT, Vector2.DOWN, corner_length, frame_color)
	_draw_corner(Vector2(4.0, size.y - 4.0), Vector2.RIGHT, Vector2.UP, corner_length, frame_color)
	_draw_corner(Vector2(size.x - 4.0, size.y - 4.0), Vector2.LEFT, Vector2.UP, corner_length, frame_color)


func _draw_corner(origin: Vector2, horizontal: Vector2, vertical: Vector2, length: float, color: Color) -> void:
	draw_line(origin, origin + horizontal * length, color, 2.0, true)
	draw_line(origin, origin + vertical * length, color, 2.0, true)


func _effect_class_text(choice: Dictionary) -> String:
	if String(choice.get("action", "")) == "divine_fusion":
		return "昇華 · 雙神賜融合"
	var element_labels := {
		"fire": "業火 · 連段／終結技",
		"dark": "迴響 · 連段／終結技",
		"poison": "萬毒 · AP／治療",
		"lightning": "雷霆 · 元素／擴散",
		"wind": "天穹 · 速度／範圍",
		"ice": "零度 · 疊層／公式",
	}
	return String(element_labels.get(String(choice.get("element", "normal")), "神賜 · 連段／終結技"))


func _element_accent(element: String) -> Color:
	var accents := {
		"fire": Color(1.0, 0.48, 0.16, 1.0),
		"dark": Color(0.70, 0.50, 1.0, 1.0),
		"poison": Color(0.56, 0.94, 0.38, 1.0),
		"lightning": Color(0.30, 0.84, 1.0, 1.0),
		"wind": Color(0.55, 0.95, 0.76, 1.0),
		"ice": Color(0.56, 0.82, 1.0, 1.0),
	}
	return accents.get(element, GOLD) as Color
