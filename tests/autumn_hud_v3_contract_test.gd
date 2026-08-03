extends SceneTree

const AUTUMN_MAP_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const TOWN_MAP_PATH := "res://scenes/maps/town/TownMap.tscn"
const TOWN_HUD_PATH := "res://scenes/ui/town/TownEternalForgeHUD.tscn"
const AUTUMN_HUD_PATH := "res://scenes/ui/autumn/AutumnHUD.tscn"
const AUTUMN_CARD_PATH := "res://scenes/ui/autumn/AutumnCardHandUI.tscn"
const AUTUMN_PROMPT_PATH := "res://scenes/ui/autumn/AutumnInteractionPrompt.tscn"
const AUTUMN_REFERENCE_PATH := "res://scenes/maps/autumn_battle/editor/AutumnEditorHUDReference.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for required_path in [
		AUTUMN_HUD_PATH,
		AUTUMN_CARD_PATH,
		AUTUMN_PROMPT_PATH,
		AUTUMN_REFERENCE_PATH,
	]:
		_expect(ResourceLoader.exists(required_path), "%s must exist." % required_path)
	if _failures > 0:
		quit(1)
		return

	var town := (load(TOWN_MAP_PATH) as PackedScene).instantiate()
	var autumn := (load(AUTUMN_MAP_PATH) as PackedScene).instantiate()
	root.add_child(town)
	root.add_child(autumn)
	await process_frame

	var town_hud := town.get_node_or_null("EditorHUDReference/HUD") as Control
	var autumn_hud := autumn.get_node_or_null("EditorHUDReference/HUD") as Control
	var autumn_card := autumn.get_node_or_null(
		"EditorHUDReference/HUD/BottomStage/CardStage/AutumnCardHandUI"
	) as Control
	_expect(town_hud != null, "Town must expose its dedicated Eternal Forge HUD.")
	_expect(autumn_hud != null, "Autumn must expose its dedicated HUD.")
	_expect(autumn_card != null, "Autumn HUD must embed its dedicated card hand renderer.")
	_expect(
		autumn.get_node_or_null("EditorHUDReference/CardHandUI") == null,
		"Autumn map must not retain a second card-hand HUD authority."
	)
	if town_hud != null:
		_expect(town_hud.scene_file_path == TOWN_HUD_PATH, "Town must use its dedicated Eternal Forge HUD scene.")
	if autumn_hud != null:
		_expect(autumn_hud.scene_file_path == AUTUMN_HUD_PATH, "Autumn must use AutumnHUD.")
		_expect(autumn_hud.name == "HUD", "Autumn map must retain the exact HUD adoption path.")
		for node_path in [
			"TopLeftStack/ObjectivePanel",
			"TopRightMeta",
			"TopCenterStack/BossHealth",
			"BottomStage/PlayerVitals",
			"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/ExperienceHeader",
			"BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/XPProgress",
			"BottomStage/CardStage/ActionStrip/RedrawHand",
			"BottomStage/CardStage/AutumnCardHandUI",
			"BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboSkillRows",
			"BottomStage/ActivityFeed/FeedMargin/FeedRows/SkillToastStack",
			"FooterRail",
			"FooterRail/FooterRow/SurvivalTimerLabel",
			"FooterRail/FooterRow/DashHint",
		]:
			_expect(
				autumn_hud.has_node(node_path),
				"AutumnHUD must author the approved semantic region %s." % node_path
			)
		for method_name in [
			"set_active_statuses",
			"set_boss_health",
			"hide_boss_health",
			"show_skill_toast",
			"show_card_cast_feedback",
			"set_combo_chain",
			"set_material_count",
			"set_survival_timer",
			"set_experience",
		]:
			_expect(
				autumn_hud.has_method(method_name),
				"AutumnHUD must expose the %s projection API." % method_name
			)
		_expect(
			not autumn_hud.has_node("BottomStage/CardStage/ActionStrip/CooldownStrip"),
			"AutumnHUD must use AP instead of a card cooldown strip."
		)
		_expect(
			not (autumn_hud.get_node("BottomStage/CardStage/ActionStrip") as Control).visible,
			"The obsolete upper action strip must stay hidden so combat cards can expand upward."
		)
		_expect(autumn_hud.has_node("InteractionPanel"), "AutumnHUD must contain its interaction prompt.")
		var prompt := autumn_hud.get_node_or_null("InteractionPanel")
		_expect(
			prompt != null and prompt.scene_file_path == AUTUMN_PROMPT_PATH,
			"AutumnHUD must instance AutumnInteractionPrompt."
		)
	if autumn_card != null:
		_expect(autumn_card.scene_file_path == AUTUMN_CARD_PATH, "Autumn must use AutumnCardHandUI.")

	town.queue_free()
	autumn.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
