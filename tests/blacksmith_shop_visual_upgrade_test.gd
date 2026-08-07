extends SceneTree

const BLACKSMITH_SCENE := preload("res://scenes/ui/town/PlayerBlacksmithUI.tscn")
const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")

const GENERATED_ASSETS := [
	"res://assets/ui/town/player_market/generated/blacksmith_menu_icons.png",
	"res://assets/ui/town/player_market/generated/blacksmith_interactive_objects.png",
	"res://assets/ui/town/player_market/generated/market_fixture_atlas.png",
	"res://assets/ui/town/player_market/generated/cozy_market_ambient_atlas.png",
]
const WORKSHOP_OBJECTS := [
	"ForgeObjectVisual",
	"UpgradeObjectVisual",
	"MarketObjectVisual",
]
const ICON_BUTTONS := [
	"ForgeServiceButton",
	"UpgradeServiceButton",
	"SalesServiceButton",
	"SteadyMethodButton",
	"RefineMethodButton",
	"RushMethodButton",
	"MasterworkMethodButton",
	"CraftButton",
	"EquipButton",
	"StrengthenButton",
	"UpgradeButton",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in GENERATED_ASSETS:
		_expect(ResourceLoader.exists(path), "Generated blacksmith shop asset must exist: %s." % path)

	var blacksmith := BLACKSMITH_SCENE.instantiate() as Control
	root.add_child(blacksmith)
	await process_frame
	blacksmith.call("open")
	await process_frame
	for node_name in WORKSHOP_OBJECTS:
		var visual := blacksmith.find_child(node_name, true, false) as TextureRect
		_expect(
			visual != null
				and visual.texture is AtlasTexture
				and visual.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Workshop trigger needs a non-blocking authored object cutout: %s." % node_name
		)
	for button_name in ICON_BUTTONS:
		var button := blacksmith.find_child(button_name, true, false) as Button
		_expect(
			button != null and button.icon is AtlasTexture,
			"Blacksmith menu action needs a matching generated icon: %s." % button_name
		)
	var workshop_animation := blacksmith.find_child("WorkshopAmbientAnimation", true, false) as AnimationPlayer
	_expect(
		workshop_animation != null and workshop_animation.is_playing(),
		"Workshop firelight and hanging objects need a calm looping micro-animation."
	)
	blacksmith.queue_free()
	await process_frame

	var market := MARKET_SCENE.instantiate() as Control
	root.add_child(market)
	await process_frame
	market.call("open")
	await process_frame
	var fixture_visual := market.find_child("MarketFixtureVisual", true, false) as TextureRect
	var fixture_benefit := market.find_child("MarketFixtureBenefit", true, false) as Label
	var market_animation := market.find_child("MarketAmbientAnimation", true, false) as AnimationPlayer
	_expect(
		fixture_visual != null
			and fixture_visual.texture is AtlasTexture
			and fixture_visual.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The active market counter must be projected as upgradeable authored furniture."
	)
	_expect(
		fixture_benefit != null and not fixture_benefit.text.strip_edges().is_empty(),
		"The shop must explain how its installed equipment helps transactions."
	)
	_expect(
		market_animation != null and market_animation.is_playing(),
		"The calm shop presentation needs a looping ambient micro-animation."
	)
	market.queue_free()
	await process_frame

	if _failures == 0:
		print("PASS: refined blacksmith shop art, icons, furniture benefits, and micro-animation")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
