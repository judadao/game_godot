extends SceneTree

const BLACKSMITH_SCENE := preload("res://scenes/ui/town/PlayerBlacksmithUI.tscn")
const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")

const GENERATED_ASSETS := [
	"res://assets/ui/town/player_market/generated/blacksmith_menu_icons.png",
	"res://assets/ui/town/player_market/generated/blacksmith_interactive_objects.png",
	"res://assets/ui/town/player_market/generated/forge_workspace_objects.png",
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
const FORGE_WORKSPACE_OBJECTS := [
	"ForgeWorkspaceBlueprintVisual",
	"ForgeWorkspaceMethodVisual",
	"ForgeWorkspaceMaterialVisual",
	"ForgeWorkspaceAnvilVisual",
	"ForgeWorkspaceHammerVisual",
	"ForgeWorkspaceImpactVisual",
	"ForgeWorkspaceResultVisual",
]
const FORGE_WORKSPACE_HOTSPOTS := [
	"BlueprintRackButton",
	"MethodToolsButton",
	"MaterialChestButton",
	"ForgeWorkspaceActionButton",
	"FinishedRackButton",
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
	for layer_name in ["WorkshopArtBackground", "WorkshopArtMidground", "WorkshopArtForeground"]:
		var entrance_layer := blacksmith.find_child(layer_name, true, false) as Control
		_expect(
			entrance_layer != null and not entrance_layer.visible,
			"Blacksmith entry must use clean object icons instead of a busy layered room: %s."
			% layer_name
		)
	blacksmith.call("set_recipes", [{
		"id": "hunter_bow",
		"name": "Hunter Bow",
		"kind": "weapon",
		"unlocked": true,
		"visible": true,
	}])
	blacksmith.call("select_blacksmith_service", &"forge")
	await process_frame
	var forge_stage := blacksmith.find_child("ForgeInteractionStage", true, false) as Control
	_expect(
		forge_stage != null and forge_stage.is_visible_in_tree(),
		"The formal forge must be an object-led interaction stage instead of a flat form."
	)
	for node_name in FORGE_WORKSPACE_OBJECTS:
		var visual := blacksmith.find_child(node_name, true, false) as TextureRect
		_expect(
			visual != null
				and visual.texture is AtlasTexture
				and visual.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Forge workspace needs a readable authored object cutout: %s." % node_name
		)
	for button_name in FORGE_WORKSPACE_HOTSPOTS:
		var hotspot := blacksmith.find_child(button_name, true, false) as Button
		_expect(
			hotspot != null
				and hotspot.focus_mode == Control.FOCUS_ALL
				and not hotspot.tooltip_text.strip_edges().is_empty(),
			"Forge object interaction must be keyboard-focusable and self-explanatory: %s."
			% button_name
		)
	var forge_animation := blacksmith.find_child("ForgeWorkspaceAnimation", true, false) as AnimationPlayer
	_expect(
		forge_animation != null and forge_animation.is_playing(),
		"The formal forge hammer and impact need a calm authored strike animation."
	)
	var next_hint := blacksmith.find_child("ForgeNextHint", true, false) as Label
	var method_row := blacksmith.find_child("ForgeMethodRow", true, false) as Control
	var material_row := blacksmith.find_child("MaterialQualityRow", true, false) as Control
	var forge_actions := blacksmith.find_child("ForgeActions", true, false) as Control
	_expect(
		next_hint != null
			and next_hint.text.contains("下一步")
			and not next_hint.text.contains("→")
			and not next_hint.text.contains("①")
			and method_row != null and not method_row.visible
			and material_row != null and not material_row.visible
			and forge_actions != null and not forge_actions.visible,
		"Forge guidance must point at one physical object without opening a choice list early."
	)
	var method_tools := blacksmith.find_child("MethodToolsButton", true, false) as Button
	method_tools.pressed.emit()
	await process_frame
	_expect(method_row.visible, "Method choices must open only after touching the tool rack.")
	var steady_button := blacksmith.find_child("SteadyMethodButton", true, false) as Button
	steady_button.pressed.emit()
	await process_frame
	_expect(
		next_hint.text.contains("素材箱")
			and not method_row.visible
			and not material_row.visible,
		"Choosing a method must point at the material chest without opening it early."
	)
	var material_chest := blacksmith.find_child("MaterialChestButton", true, false) as Button
	material_chest.pressed.emit()
	await process_frame
	_expect(material_row.visible, "Material choices must open only after touching the chest.")
	var common_button := blacksmith.find_child("CommonMaterialButton", true, false) as Button
	common_button.pressed.emit()
	await process_frame
	_expect(
		next_hint.text.contains("鐵砧")
			and not method_row.visible
			and not material_row.visible,
		"Choosing material must collapse choices and point directly to the anvil."
	)
	var recipe_button: Button = null
	var recipe_list := blacksmith.find_child("RecipeList", true, false) as Control
	if recipe_list != null:
		for child in recipe_list.get_children():
			if child is Button and child.visible:
				recipe_button = child as Button
				break
	_expect(
		recipe_button != null
			and recipe_button.text.begins_with("Hunter Bow")
			and not recipe_button.text.contains("@Button@"),
		"Recipe rows must keep their data identity instead of leaking generated node names."
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
