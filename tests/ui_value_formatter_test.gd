extends SceneTree

const UI_VALUE_FORMATTER := preload("res://scripts/ui/ui_value_formatter.gd")

var _failures := 0


func _init() -> void:
	_expect(UI_VALUE_FORMATTER.format_integer(0) == "0", "Zero must remain readable.")
	_expect(UI_VALUE_FORMATTER.format_integer(999) == "999", "Three-digit values must not gain a separator.")
	_expect(UI_VALUE_FORMATTER.format_integer(1234567) == "1,234,567", "Large UI values must use stable thousands separators.")
	_expect(UI_VALUE_FORMATTER.format_integer(-1234) == "-1,234", "Signed UI values must preserve their sign.")
	_expect(UI_VALUE_FORMATTER.format_integer(-12, true) == "0", "Resource projections may explicitly clamp negative values.")
	if _failures == 0:
		print("PASS: shared UI integer formatting preserves all existing display policies")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
