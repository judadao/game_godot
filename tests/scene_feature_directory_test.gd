extends SceneTree

const FEATURE_SCENES := [
	"res://scenes/dev/previews/CombatLayoutPreview.tscn",
	"res://scenes/maps/autumn_battle/editor/AutumnEditorHUDReference.tscn",
	"res://scenes/ui/hud/editor/SharedEditorHUDReference.tscn",
	"res://scenes/ui/hud/HUD.tscn",
	"res://scenes/ui/cards/CardDiscardUI.tscn",
	"res://scenes/ui/cards/CardGrowthUI.tscn",
	"res://scenes/ui/cards/CardHandUI.tscn",
	"res://scenes/ui/cards/DeckBuilderUI.tscn",
	"res://scenes/ui/cards/themes/CardGrowthTheme.tres",
	"res://scenes/ui/dialogue/DialogueUI.tscn",
	"res://scenes/ui/inventory/InventoryUI.tscn",
	"res://scenes/ui/results/RunResultUI.tscn",
	"res://scenes/ui/shop/ShopUI.tscn",
	"res://scenes/ui/system/PauseMenu.tscn",
	"res://scenes/ui/town/MaterialYardUI.tscn",
	"res://scenes/ui/town/PlayerBlacksmithUI.tscn",
	"res://scenes/ui/town/PlayerMarketUI.tscn",
	"res://scenes/ui/town/TownHallUI.tscn",
	"res://scenes/ui/town/TownResidenceUI.tscn",
	"res://tests/fixtures/scenes/AutumnSlime.tscn",
	"res://tests/fixtures/scenes/NPC.tscn",
]
const FEATURE_SCRIPTS := [
	"res://scripts/dev/previews/combat_layout_preview.gd",
	"res://scripts/ui/autumn/autumn_battle_card.gd",
	"res://scripts/ui/autumn/autumn_card_hand_ui.gd",
	"res://scripts/ui/autumn/autumn_combat_hud.gd",
	"res://scripts/ui/autumn/autumn_interaction_prompt.gd",
	"res://scripts/ui/cards/card_discard_ui.gd",
	"res://scripts/ui/cards/card_growth_ui.gd",
	"res://scripts/ui/cards/card_hand_ui.gd",
	"res://scripts/ui/cards/deck_builder_ui.gd",
	"res://scripts/ui/dialogue/dialogue_ui.gd",
	"res://scripts/ui/hud/hud.gd",
	"res://scripts/ui/inventory/inventory_codex_preview.gd",
	"res://scripts/ui/inventory/inventory_ui.gd",
	"res://scripts/ui/results/run_result_ui.gd",
	"res://scripts/ui/shop/shop_ui.gd",
	"res://scripts/ui/system/pause_menu.gd",
	"res://scripts/ui/town/material_yard_ui.gd",
	"res://scripts/ui/town/player_blacksmith_ui.gd",
	"res://scripts/ui/town/player_market_ui.gd",
	"res://scripts/ui/town/town_hall_ui.gd",
	"res://scripts/ui/town/town_residence_ui.gd",
]
const RETIRED_PATHS := [
	"res://scenes/dev/CombatLayoutPreview.tscn",
	"res://scenes/dev/AutumnEditorHUDReference.tscn",
	"res://scenes/dev/EditorHUDReference.tscn",
	"res://scenes/ui/HUD.tscn",
	"res://scenes/ui/CardDiscardUI.tscn",
	"res://scenes/ui/CardGrowthUI.tscn",
	"res://scenes/ui/CardHandUI.tscn",
	"res://scenes/ui/DeckBuilderUI.tscn",
	"res://scenes/ui/DialogueUI.tscn",
	"res://scenes/ui/InventoryUI.tscn",
	"res://scenes/ui/PauseMenu.tscn",
	"res://scenes/ui/RunResultUI.tscn",
	"res://scenes/ui/ShopUI.tscn",
	"res://scenes/ui/TownProgressUI.tscn",
	"res://scenes/ui/town/TownProgressUI.tscn",
	"res://scenes/ui/themes/CardGrowthTheme.tres",
	"res://scenes/monsters/AutumnSlime.tscn",
	"res://scenes/npc/NPC.tscn",
]
const RETIRED_SCRIPT_PATHS := [
	"res://scripts/dev/combat_layout_preview.gd",
	"res://scripts/ui/autumn_battle_card.gd",
	"res://scripts/ui/autumn_card_hand_ui.gd",
	"res://scripts/ui/autumn_combat_hud.gd",
	"res://scripts/ui/autumn_interaction_prompt.gd",
	"res://scripts/ui/card_discard_ui.gd",
	"res://scripts/ui/card_growth_ui.gd",
	"res://scripts/ui/card_hand_ui.gd",
	"res://scripts/ui/deck_builder_ui.gd",
	"res://scripts/ui/dialogue_ui.gd",
	"res://scripts/ui/hud.gd",
	"res://scripts/ui/inventory_codex_preview.gd",
	"res://scripts/ui/inventory_ui.gd",
	"res://scripts/ui/material_yard_ui.gd",
	"res://scripts/ui/pause_menu.gd",
	"res://scripts/ui/player_blacksmith_ui.gd",
	"res://scripts/ui/run_result_ui.gd",
	"res://scripts/ui/shop_ui.gd",
	"res://scripts/ui/town_hall_ui.gd",
	"res://scripts/ui/town_residence_ui.gd",
]
const STABLE_MAP_PATHS := [
	"res://scenes/maps/town.tscn",
	"res://scenes/maps/autumn_forest.tscn",
	"res://scenes/maps/crystal_caves.tscn",
	"res://scenes/maps/forbidden_graveyard.tscn",
	"res://scenes/maps/battle_portal_hub.tscn",
	"res://scenes/maps/town/TownMap.tscn",
	"res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
	"res://scenes/maps/layouts/CrystalCavesLayout.tscn",
	"res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in FEATURE_SCENES:
		_expect(ResourceLoader.exists(path), "Feature-owned scene path must exist: %s" % path)
	for path in FEATURE_SCRIPTS:
		_expect(ResourceLoader.exists(path), "Feature-owned script path must exist: %s" % path)
	for path in RETIRED_PATHS:
		_expect(not ResourceLoader.exists(path), "Loose legacy scene path must be absent: %s" % path)
	for path in RETIRED_SCRIPT_PATHS:
		_expect(not ResourceLoader.exists(path), "Loose legacy script path must be absent: %s" % path)
	for path in STABLE_MAP_PATHS:
		_expect(ResourceLoader.exists(path), "Public map/save identity must remain stable: %s" % path)
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
