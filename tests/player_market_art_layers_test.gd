extends SceneTree

const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")
const LAYER_PATHS := {
	"ShopBackground": "res://assets/ui/town/player_market/generated/blacksmith_shop_background.png",
	"ShopMidground": "res://assets/ui/town/player_market/generated/blacksmith_shop_midground.png",
	"ShopForeground": "res://assets/ui/town/player_market/generated/blacksmith_shop_foreground.png",
}
const DECOR_NODES := [
	"DecorBell",
	"DecorTools",
	"DecorBanner",
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
		print("PASS: Player Market uses layered blacksmith-shop art without blocking interactions")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
