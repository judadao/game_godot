extends SceneTree

const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")
const LAYER_PATHS := {
	"ShopBackground": "res://assets/ui/town/player_market/generated/medieval_armory_market_background.png",
	"ShopMidground": "res://assets/ui/town/player_market/generated/medieval_armory_market_midground.png",
	"ShopForeground": "res://assets/ui/town/player_market/generated/medieval_armory_market_foreground.png",
}
const ATLAS_PATHS := [
	"res://assets/ui/town/player_market/generated/medieval_armory_market_decor_atlas.png",
	"res://assets/ui/town/player_market/generated/medieval_armory_market_fixture_atlas.png",
	"res://assets/ui/town/player_market/generated/medieval_armory_market_ambient_atlas.png",
]
const DECOR_NODES := [
	"DecorBell",
	"DecorTools",
	"DecorWhetstone",
	"DecorIngots",
	"DecorBottles",
	"DecorShield",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for layer_name in LAYER_PATHS:
		var path := String(LAYER_PATHS[layer_name])
		_expect(ResourceLoader.exists(path), "Player Market art layer must load: %s." % path)
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture != null else Image.new()
		_expect(not image.is_empty(), "Player Market art layer must decode: %s." % path)
		_expect(image.get_width() >= 1500 and image.get_height() >= 700, "Shop layers need native review detail.")
		if layer_name != "ShopBackground":
			_expect(image.detect_alpha() != Image.ALPHA_NONE, "%s must preserve transparent compositing." % layer_name)
	for path in ATLAS_PATHS:
		_expect(ResourceLoader.exists(path), "Player Market armory atlas must load: %s." % path)
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture != null else Image.new()
		_expect(not image.is_empty() and image.detect_alpha() != Image.ALPHA_NONE, "Armory atlas needs true alpha: %s." % path)

	var market := MARKET_SCENE.instantiate()
	root.add_child(market)
	await process_frame
	market.open()
	await process_frame
	for layer_name in LAYER_PATHS:
		var layer := market.find_child(layer_name, true, false) as TextureRect
		_expect(
			layer != null and layer.texture != null and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Player Market needs a non-blocking authored %s layer." % layer_name
		)
	for node_name in DECOR_NODES:
		var decor := market.find_child(node_name, true, false) as TextureRect
		_expect(decor != null and decor.texture is AtlasTexture, "Shop decoration must be a swappable atlas cutout: %s." % node_name)
	var context_dock := market.find_child("ContextDock", true, false) as Control
	var interior_canvas := market.find_child("InteriorCanvas", true, false) as Control
	var tone_grade := market.find_child("InteriorToneGrade", true, false) as ColorRect
	var ambient_lamp := market.find_child("AmbientLamp", true, false) as TextureRect
	var ambient_banner := market.find_child("AmbientBanner", true, false) as TextureRect
	_expect(
		context_dock != null and context_dock.get_parent() == interior_canvas,
		"Player Market management controls must live in a side dock over the full shop view."
	)
	_expect(
		context_dock != null
			and context_dock.anchor_left >= 0.62
			and context_dock.anchor_right >= 0.97,
		"Player Market management must use a narrow right-side dock instead of covering the shop floor."
	)
	_expect(
		tone_grade != null
			and tone_grade.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and tone_grade.color.a > 0.0,
		"The armory interior needs a non-blocking restrained-value grade over generated art."
	)
	_expect(
		ambient_banner != null
			and ambient_banner.visible
			and ambient_banner.texture is AtlasTexture
			and (ambient_banner.texture as AtlasTexture).region == Rect2(0, 627, 627, 627),
		"The shop must show exactly the ambient atlas brand banner, not the brazier cell."
	)
	_expect(
		ambient_lamp != null
			and ambient_lamp.visible
			and ambient_lamp.anchor_left <= 0.40
			and ambient_lamp.anchor_right <= 0.48,
		"The ambient oil lamp must sit on the authored window ledge instead of floating on bare stone."
	)
	for button_name in [
		"ShelfInteractButton",
		"Product1InteractButton",
		"CustomerInteractButton",
		"BellInteractButton",
		"DoorInteractButton",
	]:
		var button := market.find_child(button_name, true, false) as Button
		_expect(button != null and button.is_visible_in_tree(), "Layered art must preserve object interaction: %s." % button_name)
	market.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Player Market uses layered cozy-shop art without blocking interactions")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
