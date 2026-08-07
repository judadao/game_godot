class_name UIValueFormatter
extends RefCounted


static func format_integer(value: int, clamp_non_negative: bool = false) -> String:
	var normalized := maxi(0, value) if clamp_non_negative else value
	var sign_prefix := "-" if normalized < 0 else ""
	var digits := str(absi(normalized))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return sign_prefix + digits + grouped
