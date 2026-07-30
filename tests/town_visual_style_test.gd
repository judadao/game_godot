extends SceneTree

const LAYOUT_PATH := "res://data/town_modular_layout.json"
const STYLE_PATH := "res://data/town_visual_style.json"
const EXPECTED_STYLE_ID := "storybook_handdrawn_pixel_v2"
const EXPECTED_CONCEPT_PATH := (
	"res://concept/town/main_horizontal_concept/town_handdrawn_pixel_v2.png"
)
const REQUIRED_PALETTE_KEYS := {
	"ink_charcoal": true,
	"moss_shadow": true,
	"leaf_light": true,
	"bark_umber": true,
	"sandstone": true,
	"parchment": true,
	"muted_teal_sky": true,
	"terracotta": true,
	"warm_honey_light": true,
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists(STYLE_PATH), "Town hand-drawn visual style contract must exist.")
	if not FileAccess.file_exists(STYLE_PATH):
		_finish()
		return

	var style_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLE_PATH))
	_expect(style_variant is Dictionary, "Town visual style contract must be a JSON object.")
	if not style_variant is Dictionary:
		_finish()
		return
	var style := style_variant as Dictionary

	_expect(int(style.get("schema_version", 0)) == 1, "Town visual style schema must be version 1.")
	_expect(
		String(style.get("id", "")) == EXPECTED_STYLE_ID,
		"Town visual style must preserve the approved hand-drawn pixel-art identity."
	)
	_expect(
		String(style.get("concept_art", "")) == EXPECTED_CONCEPT_PATH,
		"Town visual style must reference its repository-owned concept art."
	)
	_expect(
		ResourceLoader.exists(EXPECTED_CONCEPT_PATH),
		"Town hand-drawn concept art must be importable by Godot."
	)

	var palette_variant: Variant = style.get("palette", {})
	_expect(palette_variant is Dictionary, "Town visual style must define a palette.")
	if palette_variant is Dictionary:
		var palette := palette_variant as Dictionary
		for key_variant in REQUIRED_PALETTE_KEYS:
			var key := String(key_variant)
			_expect(palette.has(key), "Town visual palette is missing %s." % key)
			var value := String(palette.get(key, ""))
			_expect(
				value.is_valid_html_color() and value.length() == 7,
				"Town visual palette value must be a six-digit HTML color: %s." % key
			)

	var rendering := style.get("rendering", {}) as Dictionary
	_expect(
		String(rendering.get("linework", "")) == "hand_inked_irregular",
		"Town visual style must retain irregular hand-inked contours."
	)
	_expect(
		String(rendering.get("surface_texture", "")) == "subtle_paper_grain",
		"Town visual style must retain subtle paper-grain texture."
	)
	_expect(
		String(rendering.get("pixel_treatment", "")) == "painterly_clustered",
		"Town visual style must use painterly pixel clusters."
	)

	var lighting := style.get("lighting", {}) as Dictionary
	_expect(
		String(lighting.get("key_direction", "")) == "upper_left",
		"Town visual lighting must use a consistent upper-left key."
	)
	_expect(
		String(lighting.get("ambient_shadow", "")) == "cool_moss_charcoal",
		"Town visual lighting must use cool moss-charcoal ambient shadows."
	)
	_expect(
		String(lighting.get("highlight", "")) == "warm_honey",
		"Town visual lighting must use warm honey highlights."
	)

	_assert_all_layout_sources_are_assigned(style)
	_finish()


func _assert_all_layout_sources_are_assigned(style: Dictionary) -> void:
	_expect(FileAccess.file_exists(LAYOUT_PATH), "Town modular layout must exist.")
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var layout_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_expect(layout_variant is Dictionary, "Town modular layout must be a JSON object.")
	if not layout_variant is Dictionary:
		return
	var layout := layout_variant as Dictionary
	_expect(
		String(layout.get("visual_style", "")) == EXPECTED_STYLE_ID,
		"Town modular layout must opt into the hand-drawn pixel-art style."
	)

	var expected_sources: Dictionary = {}
	for layer_variant in layout.get("layers", []) as Array:
		if layer_variant is Dictionary:
			expected_sources[String((layer_variant as Dictionary).get("source", ""))] = true

	var assigned_sources: Dictionary = {}
	for source_variant in style.get("asset_sources", []) as Array:
		assigned_sources[String(source_variant)] = true
	_expect(
		assigned_sources == expected_sources,
		"Town visual style must explicitly cover every modular source asset."
	)


func _finish() -> void:
	if _failures == 0:
		print("Town hand-drawn visual style contract passed.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
