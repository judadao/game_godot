class_name ExpeditionVariantSelectUI
extends Control

signal variant_selected(entry: Dictionary)
signal cancelled

@onready var heading: Label = $Center/Panel/Margin/Content/Heading
@onready var hint: Label = $Center/Panel/Margin/Content/Hint
@onready var option_list: VBoxContainer = $Center/Panel/Margin/Content/Scroll/OptionList
@onready var cancel_button: Button = $Center/Panel/Margin/Content/Cancel

var _option_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cancel_button.pressed.connect(cancelled.emit)


func configure(title: String, entries: Array) -> void:
	heading.text = title
	for button in _option_buttons:
		button.queue_free()
	_option_buttons.clear()
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 70.0)
		button.focus_mode = Control.FOCUS_ALL
		button.text = _entry_button_text(entry)
		button.tooltip_text = _entry_tooltip(entry)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(0.98, 0.90, 0.72, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78, 1.0))
		button.pressed.connect(_select_entry.bind(entry))
		option_list.add_child(button)
		_option_buttons.append(button)
	var contains_boss := false
	for entry_variant in entries:
		if entry_variant is Dictionary and bool((entry_variant as Dictionary).get("is_boss", false)):
			contains_boss = true
			break
	hint.text = (
		"通道鑰匙已完成，選擇要挑戰的 Boss 房。"
		if contains_boss
		else "同一入口保留已開放的世界；強度與掉落會依階級提高。"
	)
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus.call_deferred()


func get_option_buttons() -> Array:
	return _option_buttons.duplicate()


func _select_entry(entry: Dictionary) -> void:
	variant_selected.emit(entry.duplicate(true))


func _entry_button_text(entry: Dictionary) -> String:
	var display_name := String(entry.get("display_name", "未知戰場"))
	var tier := maxi(1, int(entry.get("power_tier", 1)))
	if bool(entry.get("is_boss", false)):
		return "%s Boss 通道    強度 %d    [鑰匙完成]" % [display_name, tier]
	var fragment_name := String(entry.get("fragment_name", "通道碎片"))
	var fragment_count := maxi(0, int(entry.get("fragment_count", 0)))
	var fragment_required := maxi(1, int(entry.get("fragment_required", 4)))
	var state := (
		"%s  %d/%d · 鑰匙完成" % [fragment_name, fragment_count, fragment_required]
		if bool(entry.get("key_ready", false))
		else "%s  %d/%d" % [fragment_name, fragment_count, fragment_required]
	)
	return "%s    強度 %d\n%s" % [display_name, tier, state]


func _entry_tooltip(entry: Dictionary) -> String:
	return "%s｜強度階級 %d｜%s" % [
		String(entry.get("display_name", "")),
		maxi(1, int(entry.get("power_tier", 1))),
		"Boss 戰" if bool(entry.get("is_boss", false)) else "6:00 戰鬥地圖",
	]
