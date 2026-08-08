extends SceneTree

const BLACKSMITH_SCENE := preload("res://scenes/ui/town/PlayerBlacksmithUI.tscn")
const MARKET_SCENE := preload("res://scenes/ui/town/PlayerMarketUI.tscn")

const GENERATED_ASSETS := [
	"res://assets/ui/town/player_market/generated/blacksmith_hub_background_v2.png",
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
	var workshop_canvas := blacksmith.find_child("WorkshopCanvas", true, false) as Control
	var workshop_welcome := blacksmith.find_child("WorkshopWelcome", true, false) as Label
	var workshop_hub := blacksmith.find_child("WorkshopArtBackground", true, false) as TextureRect
	_expect(
		workshop_canvas != null
			and workshop_welcome != null
			and workshop_welcome.text.contains("哪件事")
			and workshop_hub != null
			and workshop_hub.is_visible_in_tree()
			and workshop_hub.texture != null
			and workshop_hub.texture.resource_path == (
				"res://assets/ui/town/player_market/generated/blacksmith_hub_background_v2.png"
			)
			and workshop_hub.texture.get_size() == Vector2(1774.0, 887.0)
			and workshop_hub.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and workshop_hub.z_index < blacksmith.find_child(
				"ForgeObjectButton", true, false
			).z_index,
		"Blacksmith entry must read as one workshop room whose three doors lead to services."
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
	var recipe_panel := blacksmith.find_child("RecipePanel", true, false) as Control
	var blueprint_slot := blacksmith.find_child("BlueprintSlot", true, false) as Control
	var method_slot := blacksmith.find_child("MethodSlot", true, false) as Control
	var material_slot := blacksmith.find_child("MaterialSlot", true, false) as Control
	var anvil_slot := blacksmith.find_child("AnvilSlot", true, false) as Control
	var result_slot := blacksmith.find_child("ResultSlot", true, false) as Control
	var method_row := blacksmith.find_child("ForgeMethodRow", true, false) as Control
	var material_row := blacksmith.find_child("MaterialQualityRow", true, false) as Control
	var forge_actions := blacksmith.find_child("ForgeActions", true, false) as Control
	_expect(
		next_hint != null
			and next_hint.text.contains("選擇圖紙")
			and not next_hint.text.contains("→")
			and not next_hint.text.contains("①")
			and recipe_panel != null and recipe_panel.visible
			and blueprint_slot != null and blueprint_slot.is_visible_in_tree()
			and method_slot != null and not method_slot.is_visible_in_tree()
			and material_slot != null and not material_slot.is_visible_in_tree()
			and anvil_slot != null and not anvil_slot.is_visible_in_tree()
			and result_slot != null and not result_slot.is_visible_in_tree()
			and method_row != null and not method_row.visible
			and material_row != null and not material_row.visible
			and forge_actions != null and not forge_actions.visible,
		"Forge must initially reveal only the blueprint decision and its physical rack."
	)
	var recipe_button: Button = null
	var recipe_list := blacksmith.find_child("RecipeList", true, false) as Control
	if recipe_list != null:
		for child in recipe_list.get_children():
			if child is Button and child.visible:
				recipe_button = child as Button
				break
	_expect(recipe_button != null, "The blueprint decision must expose a selectable recipe.")
	if recipe_button != null:
		recipe_button.pressed.emit()
	await process_frame
	_expect(
		recipe_panel.visible
			and blueprint_slot.is_visible_in_tree()
			and not method_slot.is_visible_in_tree()
			and not material_slot.is_visible_in_tree(),
		"Choosing a blueprint must preview it without revealing later decisions."
	)
	var blueprint_cta := blacksmith.find_child("BlueprintRackButton", true, false) as Button
	_expect(
		blueprint_cta != null and blueprint_cta.text.begins_with("確認圖紙："),
		"The blueprint page needs one explicit warm primary confirmation action."
	)
	blueprint_cta.pressed.emit()
	await process_frame
	_expect(
		not recipe_panel.visible
			and method_slot.is_visible_in_tree()
			and not blueprint_slot.is_visible_in_tree()
			and root.gui_get_focus_owner() == blacksmith.find_child(
				"MethodToolsButton", true, false
			),
		"Confirming a blueprint must collapse the catalog, reveal only the tool rack, and move keyboard focus."
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
			and not material_row.visible
			and root.gui_get_focus_owner() == blacksmith.find_child(
				"MaterialChestButton", true, false
			),
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
			and not material_row.visible
			and root.gui_get_focus_owner() == blacksmith.find_child(
				"ForgeWorkspaceActionButton", true, false
			),
		"Choosing material must collapse choices and point directly to the anvil."
	)
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
