class_name ElementTaxonomy
extends RefCounted

const ELEMENTS: Array[String] = [
	"water",
	"fire",
	"wind",
	"lightning",
	"ice",
	"poison",
	"light",
	"dark",
	"normal",
]
const ALIASES := {
	"water": "water",
	"fire": "fire",
	"flame": "fire",
	"wind": "wind",
	"earth": "wind",
	"lightning": "lightning",
	"storm": "lightning",
	"thunder": "lightning",
	"wood": "lightning",
	"ice": "ice",
	"frost": "ice",
	"poison": "poison",
	"venom": "poison",
	"light": "light",
	"holy": "light",
	"celestial": "light",
	"dark": "dark",
	"shadow": "dark",
	"echo": "dark",
	"normal": "normal",
	"neutral": "normal",
	"physical": "normal",
}


func get_all() -> Array[String]:
	return ELEMENTS.duplicate()


func normalize(value: String, fallback: String = "") -> String:
	var candidate := value.strip_edges().to_lower()
	if ALIASES.has(candidate):
		return String(ALIASES[candidate])
	return fallback if fallback in ELEMENTS else ""


func is_valid(value: String) -> bool:
	return value in ELEMENTS


func get_color(value: String) -> Color:
	match normalize(value, "normal"):
		"water":
			return Color("#36b8ff")
		"fire":
			return Color("#ff5a24")
		"wind":
			return Color("#76efcf")
		"lightning":
			return Color("#a986ff")
		"ice":
			return Color("#8eeaff")
		"poison":
			return Color("#85dc3f")
		"light":
			return Color("#ffe991")
		"dark":
			return Color("#9b69d9")
		_:
			return Color("#dce9f2")
