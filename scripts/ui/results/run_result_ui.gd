class_name RunResultUI
extends Control

signal return_to_town_requested
signal closed

var _title: Label
var _summary: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func set_result(victory: bool, summary: Dictionary) -> void:
	if _title == null:
		return
	_title.text = "AUTUMN TREE VICTORY" if victory else "EXPEDITION ENDED"
	_title.add_theme_color_override(
		"font_color",
		Color(1.0, 0.78, 0.28) if victory else Color(0.88, 0.47, 0.38)
	)
	var materials := summary.get("materials", {}) as Dictionary
	var material_lines: Array[String] = []
	for resource_id in materials:
		material_lines.append("%s  +%d" % [String(resource_id).capitalize(), int(materials[resource_id])])
	var bonus_rate := float(summary.get("completion_bonus_rate", 0.0))
	var reward_note := (
		"Clear bonus  +%d%%" % roundi(bonus_rate * 100.0)
		if bonus_rate > 0.0
		else "All collected bags retained after defeat"
	)
	_summary.text = "[center]Enemies defeated  %d\nGold retained  +%d\n%s\n%s\n\nPermanent Town progress has been saved.[/center]" % [
		int(summary.get("defeated_enemies", 0)),
		int(summary.get("gold", 0)),
		"\n".join(material_lines),
		reward_note,
	]


func get_title_text() -> String:
	return _title.text if _title != null else ""


func get_summary_text() -> String:
	return _summary.text if _summary != null else ""


func request_return_to_town() -> void:
	return_to_town_requested.emit()


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.012, 0.008, 0.90)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -235)
	panel.size = Vector2(660, 470)
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.055, 0.032, 0.98)
	style.border_color = Color(0.80, 0.51, 0.20)
	style.set_border_width_all(5)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	content.add_child(_title)
	_summary = RichTextLabel.new()
	_summary.custom_minimum_size = Vector2(580, 260)
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.add_theme_font_size_override("normal_font_size", 18)
	content.add_child(_summary)
	var return_button := Button.new()
	return_button.text = "Return to Town"
	return_button.custom_minimum_size = Vector2(260, 52)
	return_button.pressed.connect(request_return_to_town)
	content.add_child(return_button)
