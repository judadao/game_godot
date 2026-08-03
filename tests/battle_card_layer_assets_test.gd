extends SceneTree

const EXPECTED_SIZE := Vector2i(1173, 1341)
const LAYER_PATHS := [
	"res://assets/ui/autumn/cards/layers/battle_card_celestial_halo_v1.png",
	"res://assets/ui/autumn/cards/layers/battle_card_spectral_ravens_v1.png",
	"res://assets/ui/autumn/cards/layers/battle_card_vines_smoke_v1.png",
]

var _failures := 0


func _initialize() -> void:
	for path in LAYER_PATHS:
		_verify_layer(String(path))
	if _failures == 0:
		print("PASS: Battle card transparent ornament layer asset contract")
	quit(1 if _failures > 0 else 0)


func _verify_layer(path: String) -> void:
	_expect(ResourceLoader.exists(path), "Battle card layer must be importable: %s" % path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(not image.is_empty(), "Battle card layer source must load: %s" % path)
	if image.is_empty():
		return
	_expect(image.get_size() == EXPECTED_SIZE, "Battle card layers must share the approved 7:8 canvas: %s" % path)
	_expect(image.detect_alpha() != Image.ALPHA_NONE, "Battle card layer must retain transparency: %s" % path)
	var transparent_samples := 0
	var visible_samples := 0
	for y in range(0, image.get_height(), 23):
		for x in range(0, image.get_width(), 23):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.05:
				transparent_samples += 1
			elif alpha >= 0.35:
				visible_samples += 1
	_expect(transparent_samples >= 100, "Layer must leave room for the sword-soul artwork and labels: %s" % path)
	_expect(visible_samples >= 40, "Layer must contain usable authored ornament: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
