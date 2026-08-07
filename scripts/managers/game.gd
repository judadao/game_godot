extends Node

signal map_loaded(map: Node)
signal player_registered(player_node: Node)
signal ui_opened(ui_name: String, ui_node: Control)
signal ui_closed(ui_name: String, ui_node: Control)

const QUICK_SAVE_PATH := "user://saves/quick_save.json"
const QUICK_SAVE_TEMP_PATH := "user://saves/quick_save.tmp"
const QUICK_SAVE_BACKUP_PATH := "user://saves/quick_save.json.bak"
const META_SAVE_PATH := "user://saves/meta_progress.json"
const DEV_QUICK_SAVE_PATH := "user://saves/dev_quick_save.json"
const DEV_QUICK_SAVE_TEMP_PATH := "user://saves/dev_quick_save.tmp"
const DEV_QUICK_SAVE_BACKUP_PATH := "user://saves/dev_quick_save.json.bak"
const DEV_META_SAVE_PATH := "user://saves/dev_meta_progress.json"
const MAP_REGISTRY_SCRIPT := preload("res://scripts/systems/map_registry.gd")
const EXPEDITION_CATALOG_SCRIPT := preload("res://scripts/systems/expedition_region_catalog.gd")
const BATTLE_PORTAL_HUB_SCENE_PATH := "res://scenes/maps/battle_portal_hub.tscn"
const CARD_COLLECTION_SERVICE_SCRIPT := preload(
	"res://scripts/systems/card_collection_service.gd"
)
const TOWN_SCENE_PATH := MAP_REGISTRY_SCRIPT.TOWN_SCENE_PATH
const AUTUMN_SAFE_ZONE_SCENE_PATH := MAP_REGISTRY_SCRIPT.AUTUMN_SAFE_ZONE_SCENE_PATH
const AUTUMN_FOREST_SCENE_PATH := MAP_REGISTRY_SCRIPT.AUTUMN_FOREST_SCENE_PATH
const CRYSTAL_CAVES_SCENE_PATH := MAP_REGISTRY_SCRIPT.CRYSTAL_CAVES_SCENE_PATH
const FORBIDDEN_GRAVEYARD_SCENE_PATH := MAP_REGISTRY_SCRIPT.FORBIDDEN_GRAVEYARD_SCENE_PATH
const TOWN_MAIN_SCENE_PATH := MAP_REGISTRY_SCRIPT.TOWN_MAIN_SCENE_PATH
const AUTUMN_BATTLE_MAIN_SCENE_PATH := MAP_REGISTRY_SCRIPT.AUTUMN_BATTLE_MAIN_SCENE_PATH
const AUTUMN_TREE_MAIN_SCENE_PATH := MAP_REGISTRY_SCRIPT.AUTUMN_TREE_MAIN_SCENE_PATH
const CRYSTAL_CAVES_LAYOUT_SCENE_PATH := MAP_REGISTRY_SCRIPT.CRYSTAL_CAVES_LAYOUT_SCENE_PATH
const FORBIDDEN_GRAVEYARD_LAYOUT_SCENE_PATH := MAP_REGISTRY_SCRIPT.FORBIDDEN_GRAVEYARD_LAYOUT_SCENE_PATH
const MAP_MAIN_SCENE_PATHS := MAP_REGISTRY_SCRIPT.CANONICAL_TO_AUTHORITATIVE
const INVENTORY_MANAGER_SCRIPT := preload("res://scripts/systems/inventory_manager.gd")
const TOWN_MANAGER_SCRIPT := preload("res://scripts/systems/town_manager.gd")
const FORGE_CATALOG_SCRIPT := preload("res://scripts/systems/forge_catalog.gd")
const FORGE_SERVICE_SCRIPT := preload("res://scripts/systems/forge_service.gd")
const DIVINE_GIFT_MANAGER_SCRIPT := preload(
	"res://scripts/systems/divine_gift_manager.gd"
)
const COMBO_FINISHER_CATALOG_SCRIPT := preload(
	"res://scripts/systems/combo_finisher_catalog.gd"
)
const NAMED_SKILL_VFX_CATALOG_SCRIPT := preload(
	"res://scripts/systems/named_skill_vfx_catalog.gd"
)
const SKILL_SERIES_VFX_CATALOG_SCRIPT := preload(
	"res://scripts/systems/skill_series_vfx_catalog.gd"
)
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")
const BASE_AP_REGEN := 0.95
const CARD_TEMPO_DURATION := 6.0
const CARD_TEMPO_MAX_STACKS := 8
const CARD_TEMPO_REGEN_PER_STACK := 0.12
const CARD_TEMPO_ONE_AP_STACKS := 2
const CARD_TEMPO_TWO_AP_STACKS := 1
const CARD_TEMPO_ONE_AP_REFUND := 0.35
const CARD_TEMPO_TWO_AP_REFUND := 0.15
const CARD_TEMPO_POWER_CARD_COST := 3
const CARD_TEMPO_POWER_CARD_DRAIN := 4
const COMBAT_CAMERA_SAFE_OFFSET_Y := 90.0
const MAX_COMBO_ABILITIES := 8
const MAX_COMBO_LEVEL := 3
const BASE_COMBO_STACK_CAP := 10
const MAX_COMBO_STACK_CAP := 10
const COMBO_CHAIN_OPENING_DURATION := 2.0
const COMBO_CHAIN_PRESSURE_DURATION := 1.5
const COMBO_CHAIN_DURATION_STEP := 0.1
const COMBO_CHAIN_MIN_DURATION := 0.6
const DEFAULT_COMBO_DURATION := 1.5
const MAX_COMBO_EFFECT_DURATION := 2.0
const MAX_COMBO_DURATION := 2.5
const DEFAULT_AUTO_ATTACK_CARD_ID := "ember_bolt"
const DEFAULT_AUTO_ATTACK_INTERVAL := 1.0
const SURVIVAL_CHEST_EQUIPMENT: Array[StringName] = [
	&"hunter_bow", &"apprentice_staff", &"chain_armor", &"mage_robe",
	&"swift_ring", &"focus_amulet",
]
const SURVIVAL_CHEST_BLUEPRINTS: Array[StringName] = [
	&"flame_imbue_blueprint", &"frostburst_imbue_blueprint",
	&"storm_charge_blueprint", &"venom_edge_blueprint",
]
const JOURNAL_ICON_ROOT := "res://assets/ui/fantasy_icons_16x16/png/Separately/"
const JOURNAL_EQUIPMENT_ICON_ROOT := "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/"
const JOURNAL_ITEM_ICONS := {
	"travel_bread": JOURNAL_ICON_ROOT + "Icon69_1_2.png",
	"town_map": JOURNAL_ICON_ROOT + "Icon45_1_2.png",
	"iron_sword": "res://assets/ui/equipment/generated/iron_sword.png",
	"guard_boots": JOURNAL_EQUIPMENT_ICON_ROOT + "DefaultSet_0006_Boots.png",
	"soul_edge": JOURNAL_EQUIPMENT_ICON_ROOT + "StealSet_0000_Weapon.png",
	"shard_charm": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png",
}
const JOURNAL_SLOT_ICONS := {
	"weapon": JOURNAL_EQUIPMENT_ICON_ROOT + "DefaultSet_0000_Weapon.png",
	"armor": JOURNAL_EQUIPMENT_ICON_ROOT + "DefaultSet_0003_Chest.png",
	"accessory": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_03.png",
}
const JOURNAL_ENEMY_ICONS := {
	"chase": JOURNAL_ICON_ROOT + "Icon55_1_2.png",
	"leap": JOURNAL_ICON_ROOT + "Icon49_1_2.png",
	"ranged": JOURNAL_ICON_ROOT + "Icon52_1_2.png",
	"charge": JOURNAL_ICON_ROOT + "Icon58_1_2.png",
	"elite": JOURNAL_ICON_ROOT + "Icon40_1_2.png",
}
const ATTACK_GEOMETRY := preload("res://scripts/combat/attack_geometry.gd")
const AUTO_ATTACK_HIT_HALF_WIDTH := 53.0
const COMBO_FINISHER_DAMAGE := 28
const COMBO_FINISHER_RANGE := 420.0
const COMBO_FORMULA_LENGTH := 6
const AUTO_ATTACK_RETRY_INTERVAL := 0.15
const COMBO_EVOLUTIONS := [
	{
		"requires": ["flame", "frost"],
		"id": "thermal_shatter",
		"name": "Thermal Shatter",
		"effect": {
			"kind": "infusion", "infusion_id": "thermal_shatter",
			"damage_bonus": 20, "burn_damage": 6, "burn_duration": 6.0,
			"frost_ratio": 0.50, "frost_duration": 4.0, "combo_stun": 0.5,
		},
	},
	{
		"requires": ["rhythm", "stoneguard"],
		"id": "war_cadence",
		"name": "War Cadence",
		"effect": {
			"kind": "infusion", "infusion_id": "war_cadence",
			"damage_bonus": 8, "block_bonus": 14,
		},
	},
]

@export var starting_map: PackedScene = preload("res://scenes/maps/town/TownMap.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/hud/HUD.tscn")
@export var card_hand_scene: PackedScene = preload("res://scenes/ui/cards/CardHandUI.tscn")
@export var inventory_scene: PackedScene = preload("res://scenes/ui/inventory/InventoryUI.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/system/PauseMenu.tscn")
@export var dialogue_scene: PackedScene = preload("res://scenes/ui/dialogue/DialogueUI.tscn")
@export var shop_scene: PackedScene = preload("res://scenes/ui/shop/ShopUI.tscn")
@export var material_yard_scene: PackedScene = preload("res://scenes/ui/town/MaterialYardUI.tscn")
@export var player_blacksmith_scene: PackedScene = preload(
	"res://scenes/ui/town/PlayerBlacksmithUI.tscn"
)
@export var town_hall_scene: PackedScene = preload("res://scenes/ui/town/TownHallUI.tscn")
@export var town_residence_scene: PackedScene = preload("res://scenes/ui/town/TownResidenceUI.tscn")
@export var run_result_scene: PackedScene = preload("res://scenes/ui/results/RunResultUI.tscn")
@export var deck_builder_scene: PackedScene = preload("res://scenes/ui/cards/DeckBuilderUI.tscn")
@export var expedition_variant_select_scene: PackedScene = preload(
	"res://scenes/ui/expedition/ExpeditionVariantSelectUI.tscn"
)
@export var card_discard_scene: PackedScene = preload("res://scenes/ui/cards/CardDiscardUI.tscn")
@export var card_growth_scene: PackedScene = preload("res://scenes/ui/cards/CardGrowthUI.tscn")
@export var auto_attack_feedback_scene: PackedScene = preload(
	"res://scenes/combat/AutoAttackFeedback.tscn"
)
@export var evolved_background_attack_scene: PackedScene = preload(
	"res://scenes/combat/vfx/EvolvedBackgroundAttack.tscn"
)
@export var elemental_attack_aura_scene: PackedScene = preload(
	"res://scenes/combat/vfx/ElementalAttackAura.tscn"
)
@export var fire_ultimate_vfx_scene: PackedScene = preload(
	"res://scenes/combat/vfx/FireUltimateVFX.tscn"
)
@export var ice_ultimate_vfx_scene: PackedScene = preload(
	"res://scenes/combat/vfx/IceUltimateVFX.tscn"
)
@export var elemental_ground_trail_scene: PackedScene = preload(
	"res://scenes/combat/vfx/ElementalGroundTrail.tscn"
)
@export var named_skill_vfx_scene: PackedScene = preload(
	"res://scenes/combat/vfx/NamedSkillVFX.tscn"
)
@export var storm_charge_vfx_scene: PackedScene = preload(
	"res://scenes/combat/vfx/StormChargeVFX.tscn"
)

@onready var map_root: Node = $MapRoot
@onready var hud_root: CanvasLayer = $HUDLayer
@onready var ui_root: CanvasLayer = $MenuLayer
@onready var card_effect_runner: CardEffectRunner = $CardEffectRunner
@onready var skill_cast_presentation: SkillCastPresentation = $SkillCastPresentation
@onready var story_director: Node = $StoryDirector

var current_map: Node
var player: Node
var hud: Control
var card_hand_ui: Control
var ui_stack: Array[Control] = []
var current_interactive: Node
var _ui_names: Dictionary = {}
var _ui_pause_flags: Dictionary = {}
var _closing_ui: Dictionary = {}
var _interaction_candidates: Array[Node] = []
var meta_state := MetaState.new()
var run_state := RunState.new()
var save_service := SaveService.new()
var map_registry := MAP_REGISTRY_SCRIPT.new()
var expedition_catalog := EXPEDITION_CATALOG_SCRIPT.new()
var dev_mode_service := preload("res://scripts/systems/dev_mode_service.gd").new()
var card_database := CardDatabase.new()
var deck_manager := DeckManager.new(card_database)
var evolution_manager := EvolutionManager.new(card_database)
var card_collection_service: RefCounted = CARD_COLLECTION_SERVICE_SCRIPT.new(
	meta_state,
	run_state,
	deck_manager,
	card_database,
	evolution_manager
)
var skill_recipe_manager := SkillRecipeManager.new()
var growth_choice_queue := GrowthChoiceQueue.new()
var divine_gift_manager: RefCounted = DIVINE_GIFT_MANAGER_SCRIPT.new()
var combo_finisher_catalog: RefCounted = COMBO_FINISHER_CATALOG_SCRIPT.new()
var named_skill_vfx_catalog: RefCounted = NAMED_SKILL_VFX_CATALOG_SCRIPT.new()
var skill_series_vfx_catalog: RefCounted = SKILL_SERIES_VFX_CATALOG_SCRIPT.new()
var element_taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()
var inventory_manager: RefCounted = INVENTORY_MANAGER_SCRIPT.new()
var town_manager: RefCounted = TOWN_MANAGER_SCRIPT.new(inventory_manager)
var forge_catalog: RefCounted = FORGE_CATALOG_SCRIPT.new()
var forge_service: RefCounted = FORGE_SERVICE_SCRIPT.new(forge_catalog, inventory_manager)
var _pending_player_state: Dictionary = {}
var _last_combo_name := "—"
var _combo_runtime_totals := {
	"defense_bonus": 0,
	"move_speed_multiplier": 0.0,
	"ap_regen_bonus": 0.0,
	"ap_max_bonus": 0.0,
}
var _pending_reward_choice_id := ""
var _pending_reward_card_id := ""
var _pending_reward_instance_ids: Array[String] = []
var _tactical_slowdown := false
var _run_auto_attack_card_id := DEFAULT_AUTO_ATTACK_CARD_ID
var _auto_attack_remaining := 0.0
var _background_attack_remaining_by_id: Dictionary = {}
var _last_background_attack_result: Dictionary = {}
var _resolving_auto_attack_effect := false
var _auto_attack_hit_stop_generation := 0
var _named_skill_hit_stop_generation := 0
var _named_skill_vfx_catalog_loaded := false
var _skill_series_vfx_catalog_loaded := false
var _tracked_survival_boss: Node
var wallet_gold: int = 250
var player_inventory: Dictionary = {
	"travel_bread": 3,
}
var _merchant_catalogs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud_root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	card_effect_runner.process_mode = Node.PROCESS_MODE_PAUSABLE
	story_director.configure(meta_state)
	story_director.dialogue_requested.connect(_on_story_dialogue_requested)
	story_director.story_progress_changed.connect(_on_story_progress_changed)
	story_director.sequence_finished.connect(_on_story_sequence_finished)
	story_director.review_finished.connect(_on_story_review_finished)
	if not bool(divine_gift_manager.call("load_catalog")):
		push_error("Divine Gift catalog failed to load.")
	if not bool(combo_finisher_catalog.call("load_catalog")):
		push_error("Combo Finisher catalog failed to load.")
	if not _ensure_named_skill_vfx_catalog():
		push_error("Named skill VFX catalog failed to load.")
	meta_state.apply_dict(save_service.load_meta(_meta_save_path()))
	inventory_manager.call("set_progression_unlocks", {
		"dash_upgrade_unlocked": meta_state.dash_upgrade_unlocked,
	})
	if not meta_state.inventory_state.is_empty():
		inventory_manager.call("apply_dict", meta_state.inventory_state)
	elif _has_legacy_inventory_progress():
		var owned: Array[String] = []
		for slot in ["weapon", "armor", "accessory"]:
			var item_id := String(meta_state.equipment.get(slot, ""))
			if not item_id.is_empty():
				owned.append(item_id)
		inventory_manager.call("apply_dict", {
			"resources": meta_state.resources,
			"owned_equipment": owned,
			"equipment_levels": meta_state.equipment_levels,
			"equipped": meta_state.equipment,
		})
	if not meta_state.town_state.is_empty():
		town_manager.call("apply_dict", meta_state.town_state)
	elif not meta_state.building_levels.is_empty():
		town_manager.call("apply_dict", {"building_levels": meta_state.building_levels})
	card_database.load_catalog()
	meta_state.auto_attack_card_id = _resolve_auto_attack_card_id(meta_state.auto_attack_card_id)
	evolution_manager.load_recipes()
	skill_recipe_manager.load_catalog("res://data/skills.json")
	_apply_dev_mode_bootstrap()
	_refresh_forge_progression()
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	_configure_skill_loadout()
	card_effect_runner.effect_resolved.connect(_on_card_effect_resolved)
	load_current_map(starting_map)
	_sync_progression_to_meta()


func is_dev_mode_enabled() -> bool:
	return bool(dev_mode_service.call("is_enabled"))


func _meta_save_path() -> String:
	return DEV_META_SAVE_PATH if is_dev_mode_enabled() else META_SAVE_PATH


func _quick_save_path() -> String:
	return DEV_QUICK_SAVE_PATH if is_dev_mode_enabled() else QUICK_SAVE_PATH


func _quick_save_temp_path() -> String:
	return DEV_QUICK_SAVE_TEMP_PATH if is_dev_mode_enabled() else QUICK_SAVE_TEMP_PATH


func _quick_save_backup_path() -> String:
	return DEV_QUICK_SAVE_BACKUP_PATH if is_dev_mode_enabled() else QUICK_SAVE_BACKUP_PATH


func get_dev_map_entries() -> Array[Dictionary]:
	if not is_dev_mode_enabled():
		return []
	return dev_mode_service.call("get_map_entries", expedition_catalog) as Array[Dictionary]


func _apply_dev_mode_bootstrap() -> void:
	if not is_dev_mode_enabled():
		return
	dev_mode_service.call(
		"apply_runtime_unlocks",
		meta_state,
		inventory_manager,
		card_database,
		skill_recipe_manager,
		forge_catalog,
		town_manager
	)
	player_inventory["travel_bread"] = 999
	inventory_manager.call("set_progression_unlocks", {
		"dash_upgrade_unlocked": true,
	})


func _configure_skill_loadout() -> void:
	var capacity := int(town_manager.call("get_skill_memory_capacity"))
	meta_state.learned_skill_ids = meta_state.learned_skill_ids.filter(
		func(skill_id: String) -> bool: return skill_recipe_manager.has_skill(skill_id)
	)
	meta_state.active_skill_ids = meta_state.active_skill_ids.filter(
		func(skill_id: String) -> bool: return meta_state.learned_skill_ids.has(skill_id)
	)
	skill_recipe_manager.configure_loadout(
		meta_state.learned_skill_ids,
		meta_state.active_skill_ids,
		capacity
	)


func _process(delta: float) -> void:
	if not run_state.active or get_tree().paused:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	skill_recipe_manager.tick(real_delta)
	_tick_auto_attack(real_delta)
	_tick_evolved_background_attacks(real_delta)
	if _tick_combo_effects(real_delta):
		_refresh_combo_display()
	_tick_card_tempo(real_delta)
	var regen_rate := BASE_AP_REGEN
	regen_rate += float((inventory_manager.call("get_special_ability_totals") as Dictionary).get("ap_regen", 0.0))
	regen_rate += float(run_state.temporary_buffs.get("level_ap_regen", 0.0))
	regen_rate += float(_combo_runtime_totals.get("ap_regen_bonus", 0.0))
	regen_rate += _get_card_tempo_regen_bonus()
	if hud != null and hud.has_method("set_action_point_regen"):
		hud.call("set_action_point_regen", regen_rate)
	var regenerated := deck_manager.regenerate_energy(real_delta, regen_rate)
	if regenerated > 0.0:
		run_state.energy = deck_manager.energy
		card_hand_ui.call("set_action_points", deck_manager.energy, deck_manager.max_energy)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return

	if not ui_stack.is_empty():
		var top_ui := ui_stack[ui_stack.size() - 1]
		var top_name := String(_ui_names.get(top_ui, top_ui.name))
		if top_name in ["CardDiscardUI", "CardGrowthUI"]:
			return
		if event.is_action_pressed("ui_cancel"):
			if top_ui.has_signal("canceled"):
				top_ui.emit_signal("canceled")
			else:
				close_top_ui()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			close_top_ui()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("inventory") and top_name == "InventoryUI":
			close_top_ui()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		open_ui("PauseMenu", pause_menu_scene, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("card_focus") and run_state.active:
		_set_tactical_slowdown(not _tactical_slowdown)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("redraw_hand") and run_state.active:
		_redraw_current_hand()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()


func load_starting_map() -> void:
	load_current_map(starting_map)


func _resolve_main_scene_path(scene_path: String) -> String:
	return map_registry.resolve(scene_path)


func _resolve_layout_scene_path(scene_path: String) -> String:
	return _resolve_main_scene_path(scene_path)


func _canonical_map_scene_path(scene_path: String) -> String:
	return map_registry.canonical(scene_path)


func _current_map_matches(canonical_path: String) -> bool:
	return (
		current_map != null
		and map_registry.matches(current_map.scene_file_path, canonical_path)
	)


func load_current_map(map_scene: PackedScene, spawn_name: StringName = &"PlayerSpawn") -> Node:
	if player != null:
		_pending_player_state = _capture_player_state()
	for child in map_root.get_children():
		child.queue_free()

	current_map = null
	player = null
	_tracked_survival_boss = null

	if map_scene == null:
		push_error("Game entry has no map scene assigned.")
		return null

	current_map = map_scene.instantiate()
	map_root.add_child(current_map)
	_configure_expedition_map_progression()
	load_hud()
	load_card_hand()
	_register_player(spawn_name)
	_apply_transferred_player_state()
	_apply_equipment_stats()
	_wire_interactives()
	_wire_encounter_directors()
	_update_hud_area_name()
	if run_state.active:
		_refresh_card_hand()
	_update_card_hand_visibility()
	_apply_town_visual_progress()
	map_loaded.emit(current_map)
	return current_map


func _configure_expedition_map_progression() -> void:
	if current_map == null or not current_map.has_method("configure_progression"):
		return
	current_map.call(
		"configure_progression",
		meta_state.story_state,
		meta_state.region_clear_counts,
		meta_state.region_boss_fragments,
		meta_state.region_boss_keys,
		meta_state.region_boss_defeated
	)


func _current_expedition_variant_id() -> StringName:
	if current_map == null:
		return &""
	var variant_id := StringName(current_map.get_meta("expedition_variant_id", &""))
	if not variant_id.is_empty():
		return variant_id
	return expedition_catalog.get_region_id_for_scene(
		_canonical_map_scene_path(current_map.scene_file_path)
	)


func _is_current_expedition_map() -> bool:
	return not _current_expedition_variant_id().is_empty()


func _on_story_dialogue_requested(sequence_id: StringName) -> void:
	var ui_control := open_ui("DialogueUI", dialogue_scene, false)
	if ui_control == null or not story_director.start_requested_sequence(sequence_id, ui_control):
		if ui_control != null:
			close_ui(ui_control)


func _on_story_progress_changed(_story_state: Dictionary) -> void:
	save_service.save_meta(_meta_save_path(), meta_state.to_dict())


func _on_story_sequence_finished(_sequence_id: StringName) -> void:
	var dialogue_ui := get_open_ui("DialogueUI")
	if dialogue_ui != null:
		close_ui(dialogue_ui)


func _on_inventory_story_review_requested(sequence_id: StringName, inventory_ui: Control) -> void:
	if inventory_ui != null and is_instance_valid(inventory_ui):
		close_ui(inventory_ui)
	var dialogue_ui := open_ui("DialogueUI", dialogue_scene, false)
	if dialogue_ui == null or not story_director.start_review_sequence(sequence_id, dialogue_ui):
		if dialogue_ui != null:
			close_ui(dialogue_ui)
		_open_story_review_codex(sequence_id)


func _on_story_review_finished(sequence_id: StringName) -> void:
	var dialogue_ui := get_open_ui("DialogueUI")
	if dialogue_ui != null:
		close_ui(dialogue_ui)
	_open_story_review_codex(sequence_id)


func _open_story_review_codex(sequence_id: StringName = &"") -> void:
	_open_inventory()
	var inventory_ui := get_open_ui("InventoryUI")
	if inventory_ui == null:
		return
	inventory_ui.call("set_mode", &"codex")
	inventory_ui.call("set_codex_section", "story_review")
	if not sequence_id.is_empty():
		inventory_ui.call("select_codex_entry", String(sequence_id))


func load_hud() -> void:
	if hud != null:
		hud.queue_free()
		hud = null

	var hud_instance: Node = current_map.get_node_or_null("EditorHUDReference/HUD") if current_map != null else null
	if hud_instance != null:
		hud_instance.reparent(hud_root)
	elif hud_scene != null:
		hud_instance = hud_scene.instantiate()
	else:
		return

	if hud_instance is Control:
		hud = hud_instance
		if hud.get_parent() == null:
			hud_root.add_child(hud)
		if hud.has_signal("interaction_prompt_accepted"):
			hud.connect("interaction_prompt_accepted", _try_interact)
		_update_hud_area_name()
		_update_hud_player_identity()
		_update_hud_resources()
		hud.call("set_currency", wallet_gold)
		_apply_map_hud_visibility()
	else:
		push_error("HUD scene root must be a Control.")
		hud_instance.queue_free()


func _apply_map_hud_visibility() -> void:
	if hud == null or current_map == null:
		return
	var objective_panel := hud.get_node_or_null("TopLeftStack") as CanvasItem
	var meta_panel := hud.get_node_or_null("TopRightMeta") as CanvasItem
	if objective_panel != null:
		objective_panel.visible = (
			not hud.has_method("show_map_title")
			and not bool(current_map.get_meta("hide_objective_hud", false))
		)
	if meta_panel != null:
		meta_panel.visible = not bool(current_map.get_meta("hide_meta_hud", false))


func load_card_hand() -> void:
	if card_hand_ui != null:
		if hud == null or not hud.is_ancestor_of(card_hand_ui):
			card_hand_ui.queue_free()
		card_hand_ui = null

	if _current_map_matches(AUTUMN_SAFE_ZONE_SCENE_PATH):
		return

	var hand_instance: Node = current_map.get_node_or_null("EditorHUDReference/CardHandUI") if current_map != null else null
	if hand_instance == null and hud != null:
		hand_instance = hud.get_node_or_null("BottomStage/CardStage/AutumnCardHandUI")
	if hand_instance != null:
		if hand_instance.get_parent() != null and (hud == null or not hud.is_ancestor_of(hand_instance)):
			hand_instance.reparent(hud_root)
	elif card_hand_scene != null:
		hand_instance = card_hand_scene.instantiate()
	else:
		return

	if hand_instance is Control:
		card_hand_ui = hand_instance
		if card_hand_ui.get_parent() == null:
			hud_root.add_child(card_hand_ui)
		if not card_hand_ui.card_selected.is_connected(_on_card_selected):
			card_hand_ui.card_selected.connect(_on_card_selected)
		if not card_hand_ui.redraw_requested.is_connected(_redraw_current_hand):
			card_hand_ui.redraw_requested.connect(_redraw_current_hand)
	else:
		push_error("Card hand scene root must be a Control.")
		hand_instance.queue_free()


func _update_hud_area_name() -> void:
	if hud == null or current_map == null or not hud.has_method("set_area_name"):
		return

	var area_names := {
		TOWN_SCENE_PATH: "Town",
		AUTUMN_SAFE_ZONE_SCENE_PATH: "Autumn Wayfarer's Camp",
		AUTUMN_FOREST_SCENE_PATH: "Autumn Forest",
		CRYSTAL_CAVES_SCENE_PATH: "Crystal Caves",
		FORBIDDEN_GRAVEYARD_SCENE_PATH: "Forbidden Graveyard",
		"res://scenes/maps/battle_portal_hub.tscn": "戰鬥傳送大廳",
	}
	var map_path := _canonical_map_scene_path(current_map.scene_file_path)
	var variant_id := _current_expedition_variant_id()
	if not variant_id.is_empty():
		hud.call("set_area_name", expedition_catalog.get_display_name(variant_id))
	else:
		hud.call("set_area_name", area_names.get(map_path, current_map.name))


func _update_hud_player_identity() -> void:
	if hud == null or player == null:
		return
	var player_level: Variant = run_state.level if run_state.active else player.get("level")
	var player_class: Variant = player.get("character_class")
	var player_experience: Variant = run_state.experience if run_state.active else player.get("experience")
	var experience_required: Variant = run_state.experience_required if run_state.active else player.get("experience_to_next_level")
	if player_level != null and hud.has_method("set_player_level"):
		hud.call("set_player_level", int(player_level))
	if player_class != null and hud.has_method("set_player_class"):
		hud.call("set_player_class", String(player_class))
	if player_experience != null and experience_required != null and hud.has_method("set_experience"):
		hud.call("set_experience", int(player_experience), int(experience_required))


func _update_hud_resources(
	_health: int = -1,
	_max_health: int = -1,
	_mana: int = -1,
	_max_mana: int = -1
) -> void:
	if hud == null or player == null:
		return
	hud.call("set_health", int(player.get("health")), int(player.get("max_health")))
	hud.call("set_mana", int(player.get("mana")), int(player.get("max_mana")))


func open_ui(ui_name: String, ui_scene: PackedScene, pause_game: bool = false) -> Control:
	var existing_ui := get_open_ui(ui_name)
	if existing_ui != null:
		if pause_game:
			_ui_pause_flags[existing_ui] = true
			_update_pause_state()
		existing_ui.move_to_front()
		return existing_ui

	if ui_scene == null:
		push_error("Cannot open UI '%s': scene is not assigned." % ui_name)
		return null

	var ui_instance := ui_scene.instantiate()
	if not ui_instance is Control:
		push_error("Cannot open UI '%s': scene root must be a Control." % ui_name)
		ui_instance.queue_free()
		return null

	var ui_control := ui_instance as Control
	ui_control.process_mode = Node.PROCESS_MODE_ALWAYS
	_close_existing_primary_ui(ui_name)
	ui_root.add_child(ui_control)
	ui_stack.append(ui_control)
	_ui_names[ui_control] = ui_name
	_ui_pause_flags[ui_control] = pause_game
	_update_pause_state()
	_wire_common_ui_controls(ui_control)
	_wire_ui_lifecycle(ui_control)
	if ui_control.has_method("open"):
		ui_control.call("open")
	_focus_first_control(ui_control)
	ui_opened.emit(ui_name, ui_control)
	return ui_control


func close_top_ui() -> void:
	if ui_stack.is_empty():
		return

	close_ui(ui_stack[ui_stack.size() - 1])


func close_ui(ui: Variant) -> void:
	var ui_control := _resolve_open_ui(ui)
	if ui_control == null:
		return

	var ui_name := String(_ui_names.get(ui_control, ui_control.name))
	if ui_name in ["MaterialYardUI", "PlayerBlacksmithUI", "TownHallUI"]:
		_sync_progression_to_meta()
		save_service.save_meta(_meta_save_path(), meta_state.to_dict())
		_apply_town_visual_progress()
		_apply_equipment_stats()
	_closing_ui[ui_control] = true
	if ui_control.visible and ui_control.has_method("close"):
		ui_control.call("close")
	ui_stack.erase(ui_control)
	_ui_names.erase(ui_control)
	_ui_pause_flags.erase(ui_control)
	_update_pause_state()
	ui_closed.emit(ui_name, ui_control)
	ui_control.queue_free()
	_closing_ui.erase(ui_control)


func toggle_ui(ui_name: String, ui_scene: PackedScene, pause_game: bool = false) -> Control:
	var existing_ui := get_open_ui(ui_name)
	if existing_ui != null:
		close_ui(existing_ui)
		return null

	return open_ui(ui_name, ui_scene, pause_game)


func get_open_ui(ui_name: String) -> Control:
	for ui_control in ui_stack:
		if String(_ui_names.get(ui_control, ui_control.name)) == ui_name:
			return ui_control

	return null


func get_current_map() -> Node:
	return current_map


func get_player() -> Node:
	return player


func _register_player(spawn_name: StringName) -> void:
	if current_map == null:
		return

	player = current_map.find_child("Player", true, false)
	if player == null:
		return

	var spawn := current_map.find_child(String(spawn_name), true, false)
	if spawn is Node2D and player is Node2D:
		(player as Node2D).global_position = (spawn as Node2D).global_position

	_configure_player_camera()
	_apply_intrinsic_dash_upgrades()
	_update_player_input_state()
	if player.has_signal("resources_changed") and not player.is_connected(
		"resources_changed",
		_update_hud_resources
	):
		player.connect("resources_changed", _update_hud_resources)
	if player.has_signal("defeated") and not player.is_connected("defeated", _on_player_defeated):
		player.connect("defeated", _on_player_defeated)
	if player.has_signal("dash_performed") and not player.is_connected(
		"dash_performed",
		_on_player_dash_performed
	):
		player.connect("dash_performed", _on_player_dash_performed)
	var status_controller := player.get_node_or_null("CombatStatusController")
	if (
		status_controller != null
		and status_controller.has_signal("statuses_changed")
		and not status_controller.is_connected("statuses_changed", _on_player_statuses_changed)
	):
		status_controller.connect("statuses_changed", _on_player_statuses_changed)
	if player.has_method("get_combat_status_projection"):
		_on_player_statuses_changed(player.call("get_combat_status_projection") as Array)
	_update_hud_resources()
	player_registered.emit(player)


func _apply_intrinsic_dash_upgrades() -> void:
	if player == null:
		return
	var equipment_specials := {}
	if meta_state.dash_upgrade_unlocked:
		equipment_specials = inventory_manager.call("get_special_ability_totals") as Dictionary
	var air_jump_value: Variant = player.get("max_air_jumps")
	if air_jump_value != null:
		player.set("max_air_jumps", 1 if meta_state.dash_upgrade_unlocked else 0)
	var distance_value: Variant = player.get("dash_distance")
	if distance_value != null:
		if not player.has_meta("base_dash_distance"):
			player.set_meta("base_dash_distance", float(distance_value))
		player.set(
			"dash_distance",
			float(player.get_meta("base_dash_distance"))
			+ float(equipment_specials.get("dash_distance_bonus", 0.0))
		)
	var evasion_value: Variant = player.get("dash_evasion_seconds")
	if evasion_value != null:
		if not player.has_meta("base_dash_evasion_seconds"):
			player.set_meta("base_dash_evasion_seconds", float(evasion_value))
		player.set(
			"dash_evasion_seconds",
			float(player.get_meta("base_dash_evasion_seconds"))
			+ float(equipment_specials.get("dash_evasion_bonus", 0.0))
		)


func _configure_player_camera() -> void:
	if current_map == null or player == null:
		return

	var camera := player.find_child("Camera2D", true, false) as Camera2D
	if camera == null:
		return

	camera.limit_left = int(current_map.get_meta("camera_limit_left", 0))
	camera.limit_top = int(current_map.get_meta("camera_limit_top", 0))
	camera.limit_right = int(current_map.get_meta("camera_limit_right", 1280))
	camera.limit_bottom = int(current_map.get_meta("camera_limit_bottom", 720))
	camera.position_smoothing_enabled = false
	camera.position.y = COMBAT_CAMERA_SAFE_OFFSET_Y if run_state.active and _is_current_expedition_map() else 0.0
	camera.reset_smoothing()


func _wire_common_ui_controls(ui_control: Control) -> void:
	if ui_control.has_method("configure_dev_mode"):
		ui_control.call(
			"configure_dev_mode",
			is_dev_mode_enabled(),
			get_dev_map_entries()
		)
	if ui_control.has_signal("dev_map_requested"):
		ui_control.connect(
			"dev_map_requested",
			_on_dev_map_requested.bind(ui_control)
		)
	var close_button := ui_control.find_child("CloseButton", true, false)
	if close_button is BaseButton:
		(close_button as BaseButton).pressed.connect(close_ui.bind(ui_control))

	var continue_button := ui_control.find_child("Continue", true, false)
	if continue_button is BaseButton:
		(continue_button as BaseButton).pressed.connect(close_ui.bind(ui_control))

	var inventory_button := ui_control.find_child("Inventory", true, false)
	if inventory_button is BaseButton:
		(inventory_button as BaseButton).pressed.connect(_open_inventory_from_pause)

	if ui_control.has_signal("save_requested"):
		ui_control.connect("save_requested", _save_quick_slot.bind(ui_control))
	if ui_control.has_signal("load_requested"):
		ui_control.connect("load_requested", _load_quick_slot.bind(ui_control))
	if ui_control.has_signal("exit_combat_requested"):
		ui_control.connect(
			"exit_combat_requested",
			_on_pause_exit_combat_requested.bind(ui_control)
		)
	if ui_control.has_method("set_button_enabled"):
		ui_control.call("set_button_enabled", "load", FileAccess.file_exists(_quick_save_path()))
		ui_control.call("set_button_enabled", "exit_combat", _can_exit_active_combat())

	var quit_button := ui_control.find_child("Quit", true, false)
	if quit_button is BaseButton:
		(quit_button as BaseButton).pressed.connect(get_tree().quit)


func _can_exit_active_combat() -> bool:
	return (
		run_state.active
		and _is_current_expedition_map()
	)


func _on_pause_exit_combat_requested(pause_ui: Control) -> void:
	if not _can_exit_active_combat():
		return
	close_ui(pause_ui)
	_finish_run(false, RunState.OUTCOME_ABANDON)
	_pending_player_state.clear()
	player = null
	load_current_map(
		load(_resolve_main_scene_path(TOWN_SCENE_PATH)) as PackedScene
	)


func _on_dev_map_requested(scene_path: String, pause_ui: Control) -> void:
	if not is_dev_mode_enabled():
		return
	var resolved_path := _resolve_main_scene_path(scene_path)
	if scene_path.is_empty() or not ResourceLoader.exists(resolved_path):
		_set_menu_footer(pause_ui, "DEV map unavailable: %s" % scene_path)
		return
	close_ui(pause_ui)
	if run_state.active:
		run_state.finish_run(false, RunState.OUTCOME_ABANDON)
		growth_choice_queue.clear()
		skill_recipe_manager.reset_runtime()
		_auto_attack_remaining = 0.0
		_set_tactical_slowdown(false)
	var variant_id := expedition_catalog.get_region_id_for_scene(scene_path)
	if variant_id.is_empty():
		variant_id = expedition_catalog.get_region_id_for_scene(resolved_path)
	if not variant_id.is_empty():
		_begin_expedition_run(
			[],
			variant_id,
			expedition_catalog.is_boss_scene(scene_path)
		)
	_pending_player_state.clear()
	player = null
	load_current_map(load(resolved_path) as PackedScene)


func _wire_ui_lifecycle(ui_control: Control) -> void:
	if ui_control.has_signal("closed"):
		ui_control.connect("closed", _on_ui_self_closed.bind(ui_control))
	if ui_control.has_signal("canceled"):
		ui_control.connect("canceled", close_ui.bind(ui_control))


func _focus_first_control(ui_control: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(ui_control) or not ui_control.visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and ui_control.is_ancestor_of(focused):
		return
	var first_button := ui_control.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool:
			return node is Button and (node as Button).visible and not (node as Button).disabled
	)
	if not first_button.is_empty():
		(first_button[0] as Button).grab_focus()


func _wire_interactives() -> void:
	_interaction_candidates.clear()
	current_interactive = null
	_update_interaction_prompt()
	if current_map == null:
		return

	for node in current_map.find_children("*", "", true, false):
		if not (node is Node):
			continue
		var interactive := node as Node
		if not interactive.is_in_group("Interactives"):
			continue
		_connect_if_present(interactive, &"interaction_available", &"_on_interaction_available")
		_connect_if_present(interactive, &"interaction_unavailable", &"_on_interaction_unavailable")
		_connect_if_present(interactive, &"dialogue_requested", &"_on_dialogue_requested")
		_connect_if_present(interactive, &"shop_requested", &"_on_shop_requested")
		_connect_if_present(
			interactive,
			&"building_ui_requested",
			&"_on_building_ui_requested"
		)
		_connect_if_present(interactive, &"portal_entered", &"_on_portal_entered")
		_connect_if_present(interactive, &"chest_opened", &"_on_chest_opened")


func _wire_encounter_directors() -> void:
	if current_map == null:
		return
	for director in current_map.get_tree().get_nodes_in_group("EncounterDirectors"):
		if not current_map.is_ancestor_of(director):
			continue
		if run_state.active and director.has_method("configure_difficulty_tier"):
			director.call(
				"configure_difficulty_tier",
				maxi(1, run_state.expedition_power_tier)
			)
		var is_survival_timeline := director.has_signal("survival_time_changed")
		if not is_survival_timeline:
			_connect_if_present(director, &"wave_started", &"_on_run_wave_started")
			_connect_if_present(director, &"progress_changed", &"_on_run_progress_changed")
			_connect_if_present(director, &"encounter_cleared", &"_on_run_encounter_cleared")
		_connect_if_present(director, &"combat_engaged", &"_on_combat_engaged")
		_connect_if_present(director, &"disengage_warning", &"_on_disengage_warning")
		_connect_if_present(director, &"disengage_cancelled", &"_on_disengage_cancelled")
		_connect_if_present(director, &"combat_reset", &"_on_combat_reset")
		_connect_if_present(director, &"experience_gem_spawned", &"_on_experience_gem_spawned")
		_connect_if_present(director, &"survival_time_changed", &"_on_survival_time_changed")
		_connect_if_present(director, &"boss_spawned", &"_on_survival_boss_spawned")
		_connect_if_present(director, &"boss_defeated", &"_on_survival_boss_defeated")
		_connect_if_present(director, &"boss_stage_completed", &"_on_boss_stage_completed")
		_connect_if_present(director, &"elite_defeated", &"_on_elite_defeated")
		_connect_if_present(director, &"reward_bag_collected", &"_on_reward_bag_collected")
		if director.has_method("start_encounter") and not bool(director.get("_running")):
			director.call_deferred("start_encounter")


func _on_run_wave_started(wave_number: int, total_waves: int, enemy_count: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call(
			"set_objective",
			"Autumn Tree — Wave %d / %d" % [wave_number, total_waves],
			"Enemies: %d" % enemy_count
		)
	if wave_number == total_waves:
		call_deferred("_wire_boss_hud")


func _on_run_progress_changed(remaining: int, total: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "Autumn Tree Expedition", "Enemies remaining: %d / %d" % [remaining, total])


func _on_survival_time_changed(
	remaining: float,
	total: float,
	alive: int,
	cap: int,
	final_rush: bool
) -> void:
	if hud != null and hud.has_method("set_objective"):
		var objective := (
			"SURVIVED — REACH THE EXIT PORTAL"
			if remaining <= 0.0
			else ("FINAL RUSH — SURVIVE" if final_rush else "SURVIVE UNTIL DAWN")
		)
		hud.call(
			"set_objective",
			objective,
			"THREAT %d / %d" % [alive, cap]
		)
	if hud != null and hud.has_method("set_survival_timer"):
		hud.call("set_survival_timer", remaining, total, final_rush)


func _on_survival_boss_spawned(
	_boss: Node,
	_completion_boss: bool,
	_remaining: float
) -> void:
	_wire_boss_hud()


func _on_survival_boss_defeated(
	_world_position: Vector2,
	_completion_boss: bool
) -> void:
	if not run_state.active:
		return
	call_deferred("_show_combat_blessing_choices", "boss")


func _on_reward_bag_collected(kind: StringName, reward: Dictionary) -> void:
	if not run_state.active:
		return
	for resource_variant in reward:
		var resource_id := String(resource_variant)
		var base_amount := int(reward[resource_variant])
		var amount := base_amount * maxi(1, run_state.expedition_power_tier)
		if amount > 0:
			var quality := &"common"
			if kind == &"material" and base_amount >= 3:
				quality = &"exceptional"
			elif kind == &"material" and base_amount >= 2:
				quality = &"rare"
			run_state.add_reward(resource_id, amount, quality)


func _on_boss_stage_completed() -> void:
	if not run_state.active:
		return
	_tracked_survival_boss = null
	if card_hand_ui != null and card_hand_ui.has_method("hide_boss_health"):
		card_hand_ui.call("hide_boss_health")
	run_state.boss_defeated = true
	meta_state.boss_defeated = true
	meta_state.dash_upgrade_unlocked = true
	inventory_manager.call("set_progression_unlocks", {"dash_upgrade_unlocked": true})
	var tier := maxi(1, run_state.expedition_power_tier)
	run_state.add_reward("gold", 240 * tier)
	run_state.add_reward("autumn_wood", 30 * tier)
	run_state.add_reward("stone", 24 * tier)
	run_state.add_reward("magic_shard", 18 * tier)
	run_state.add_reward("autumn_core", 3 * tier)
	run_state.temporary_buffs["completion_chest_reward"] = _select_survival_chest_reward()
	meta_state.shortcuts["expedition_power_tier"] = maxi(
		int(meta_state.shortcuts.get("expedition_power_tier", 1)),
		tier
	)
	if current_map != null:
		for portal_name in ["EastSafePortal", "EastReturnPortal", "ExitPortal"]:
			var exit_portal := current_map.get_node_or_null(portal_name)
			if exit_portal != null and exit_portal.has_method("set_locked"):
				exit_portal.call("set_locked", false, "")
	if hud != null and hud.has_method("set_objective"):
		hud.call(
			"set_objective",
			"BOSS DEFEATED — EXPEDITION COMPLETE",
			"The portal seal is broken. Tier %d rewards secured." % tier
		)


func _on_experience_gem_spawned(gem: Node, _value: int) -> void:
	if gem != null and gem.has_signal("collected"):
		gem.connect("collected", _on_experience_collected, CONNECT_ONE_SHOT)


func _on_experience_collected(value: int) -> void:
	var queued_levels := run_state.add_experience(value)
	_update_hud_player_identity()
	if queued_levels > 0:
		call_deferred("_enqueue_experience_growth")


func _on_elite_defeated(_world_position: Vector2) -> void:
	if not run_state.active:
		return
	var rewarded_variant: Variant = run_state.temporary_buffs.get(
		"divine_rewarded_stages",
		{}
	)
	var rewarded: Dictionary = (
		rewarded_variant if rewarded_variant is Dictionary else {}
	)
	var stage_key := _current_divine_stage_key()
	if rewarded.has(stage_key):
		return
	rewarded[stage_key] = true
	run_state.temporary_buffs["divine_rewarded_stages"] = rewarded
	run_state.elite_defeated = true
	call_deferred("_show_combat_blessing_choices", "elite")


func _current_divine_stage_key() -> String:
	var map_path := current_map.scene_file_path if current_map != null else "run"
	var event_number := 0
	if current_map != null:
		var directors := get_tree().get_nodes_in_group("EncounterDirectors")
		if directors.is_empty():
			var compatibility_director := current_map.get_node_or_null("AutumnRunDirector")
			if compatibility_director != null:
				directors.append(compatibility_director)
		for director in directors:
			if not current_map.is_ancestor_of(director):
				continue
			if director.has_method("get_elite_defeat_count"):
				event_number = int(director.call("get_elite_defeat_count"))
			elif director.has_method("get_wave_number"):
				event_number = int(director.call("get_wave_number"))
			break
	return "%s:%d" % [map_path, event_number]


func _sync_divine_fusion_equipment_context() -> void:
	var equipped_ids: Array[String] = []
	for slot in [&"weapon", &"armor", &"accessory"]:
		var item_id := String(inventory_manager.call("get_equipped", slot))
		if not item_id.is_empty():
			equipped_ids.append(item_id)
	divine_gift_manager.call("set_equipped_item_ids", equipped_ids)


func _show_combat_blessing_choices(source: String) -> void:
	if not run_state.active:
		return
	_sync_divine_fusion_equipment_context()
	var upgrades := divine_gift_manager.call("get_upgrade_choices", 3) as Array
	var fusions := divine_gift_manager.call("get_fusion_choices", 3) as Array
	if growth_choice_queue.call(
		"enqueue_combat_blessing_reward",
		source,
		upgrades,
		fusions
	):
		call_deferred("_open_next_growth_choice")


func _enqueue_experience_growth() -> void:
	if run_state.pending_level_ups <= 0 or not growth_choice_queue.is_empty():
		return
	var blessings := divine_gift_manager.call("get_reward_choices", 3) as Array
	if not growth_choice_queue.call("enqueue_experience_blessings", blessings):
		return
	call_deferred("_open_next_growth_choice")


func _get_run_deck_size() -> int:
	return int(card_collection_service.call("get_deck_size"))


func _open_next_growth_choice() -> void:
	if growth_choice_queue.is_empty() or get_open_ui("CardGrowthUI") != null:
		return
	var page := _refresh_front_divine_growth_page()
	if page.is_empty():
		return
	var ui_control := open_ui("CardGrowthUI", card_growth_scene, true)
	if ui_control == null:
		return
	ui_control.call("present_page", page)
	ui_control.connect(
		"choice_confirmed",
		_on_growth_choice_confirmed.bind(ui_control)
	)
	ui_control.connect(
		"reward_skipped",
		_on_growth_reward_skipped.bind(ui_control)
	)


func _on_growth_choice_confirmed(choice_id: String, ui_control: Control) -> void:
	var page := growth_choice_queue.peek()
	var selected: Dictionary = {}
	for choice_variant in page.get("choices", []) as Array:
		var choice := choice_variant as Dictionary
		if String(choice.get("choice_id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return
	if (
		String(selected.get("action", "")) == "new_card"
		and _get_run_deck_size() >= CardCollectionService.MAX_EXPEDITION_CARDS
	):
		close_ui(ui_control)
		_open_reward_replacement(
			choice_id,
			String(selected.get("card_id", ""))
		)
		return
	if not _apply_growth_resolution(selected):
		var refreshed_page := _refresh_front_divine_growth_page()
		if not refreshed_page.is_empty():
			ui_control.call("present_page", refreshed_page)
		return
	if growth_choice_queue.resolve(choice_id).is_empty():
		return
	if String(page.get("source", "")) == "experience":
		run_state.consume_pending_level()
	close_ui(ui_control)
	_refresh_card_hand()
	_update_hud_player_identity()
	if not growth_choice_queue.is_empty():
		call_deferred("_open_next_growth_choice")
	elif run_state.pending_level_ups > 0:
		call_deferred("_enqueue_experience_growth")


func _refresh_front_divine_growth_page() -> Dictionary:
	var page := growth_choice_queue.peek()
	var source := String(page.get("source", "")).to_lower()
	if source not in ["experience", "elite", "boss", "divine"]:
		return page
	_sync_divine_fusion_equipment_context()
	var rewards: Array[Dictionary] = []
	var fusions: Array[Dictionary] = []
	if source == "experience" or source == "divine":
		rewards = divine_gift_manager.call("get_reward_choices", 3) as Array
	else:
		rewards = divine_gift_manager.call("get_upgrade_choices", 3) as Array
	if source in ["elite", "boss", "divine"]:
		fusions = divine_gift_manager.call("get_fusion_choices", 3) as Array
	return growth_choice_queue.call(
		"refresh_front_divine_choices",
		rewards,
		fusions
	) as Dictionary


func _on_growth_reward_skipped(ui_control: Control) -> void:
	if growth_choice_queue.skip_optional_reward().is_empty():
		return
	close_ui(ui_control)
	if not growth_choice_queue.is_empty():
		call_deferred("_open_next_growth_choice")


func _open_reward_replacement(choice_id: String, card_id: String) -> void:
	if (
		choice_id.is_empty()
		or not _is_combat_hand_card(card_database.get_card(card_id))
		or get_open_ui("CardDiscardUI") != null
	):
		return
	var cards: Array[Dictionary] = []
	_pending_reward_instance_ids.clear()
	for instance in deck_manager.get_all_instances():
		var card := _card_for_cast(instance)
		card["instance_id"] = instance.instance_id
		cards.append(card)
		_pending_reward_instance_ids.append(instance.instance_id)
	_pending_reward_choice_id = choice_id
	_pending_reward_card_id = card_id
	var ui_control := open_ui("CardDiscardUI", card_discard_scene, true)
	if ui_control == null:
		_clear_pending_reward_replacement()
		call_deferred("_open_next_growth_choice")
		return
	ui_control.call(
		"configure",
		cards,
		1,
		[],
		"DECK FULL — REPLACE ONE CARD?",
		true
	)
	ui_control.connect(
		"discard_confirmed",
		_on_reward_replacement_confirmed.bind(ui_control)
	)
	ui_control.connect(
		"skipped",
		_on_reward_replacement_skipped.bind(ui_control)
	)


func _on_reward_replacement_confirmed(indices: Array[int], ui_control: Control) -> void:
	if (
		indices.size() != 1
		or _pending_reward_choice_id.is_empty()
		or _pending_reward_card_id.is_empty()
	):
		return
	var index := indices[0]
	if index < 0 or index >= _pending_reward_instance_ids.size():
		return
	var snapshot := _capture_growth_transaction()
	var replaced := (
		_remove_card_instance(_pending_reward_instance_ids[index])
		and _add_persistent_run_card(_pending_reward_card_id)
	)
	if replaced:
		_sync_progression_to_meta()
	if not replaced or not save_service.save_meta(_meta_save_path(), meta_state.to_dict()):
		_restore_growth_transaction(snapshot)
		return
	_finish_reward_replacement(ui_control)


func _on_reward_replacement_skipped(ui_control: Control) -> void:
	if _pending_reward_choice_id.is_empty():
		return
	_finish_reward_replacement(ui_control)


func _finish_reward_replacement(ui_control: Control) -> void:
	var choice_id := _pending_reward_choice_id
	if growth_choice_queue.resolve(choice_id).is_empty():
		return
	_clear_pending_reward_replacement()
	close_ui(ui_control)
	_refresh_card_hand()
	if not growth_choice_queue.is_empty():
		call_deferred("_open_next_growth_choice")


func _clear_pending_reward_replacement() -> void:
	_pending_reward_choice_id = ""
	_pending_reward_card_id = ""
	_pending_reward_instance_ids.clear()


func _apply_growth_resolution(choice: Dictionary) -> bool:
	if String(choice.get("action", "")).begins_with("divine_"):
		return _apply_growth_resolution_uncommitted(choice)
	var snapshot := _capture_growth_transaction()
	var applied := _apply_growth_resolution_uncommitted(choice)
	if applied:
		_sync_progression_to_meta()
	if not applied or not save_service.save_meta(_meta_save_path(), meta_state.to_dict()):
		_restore_growth_transaction(snapshot)
		return false
	return true


func _apply_growth_resolution_uncommitted(choice: Dictionary) -> bool:
	match String(choice.get("action", "")):
		"new_card":
			return _add_persistent_run_card(String(choice.get("card_id", "")))
		"upgrade":
			return meta_state.upgrade_card_instance(String(choice.get("instance_id", "")))
		"fusion":
			return _apply_card_fusion(choice)
		"divine_gift":
			var applied := bool(divine_gift_manager.call(
				"add_or_upgrade",
				String(choice.get("gift_id", ""))
			))
			if applied:
				_refresh_combo_display()
			return applied
		"divine_fusion":
			_sync_divine_fusion_equipment_context()
			var evolved := divine_gift_manager.call(
				"fuse_max_level",
				String(choice.get("left_gift_id", "")),
				String(choice.get("right_gift_id", ""))
			) as Dictionary
			if not evolved.is_empty():
				_refresh_combo_display()
			return not evolved.is_empty()
		"fallback":
			var reward_variant: Variant = choice.get("reward", {})
			if not reward_variant is Dictionary:
				return false
			for resource_id in reward_variant:
				var amount := int(reward_variant[resource_id])
				if amount <= 0 or not meta_state.add_resource(String(resource_id), amount):
					return false
				inventory_manager.call("add_resource", StringName(resource_id), amount)
			wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
			if hud != null and hud.has_method("set_currency"):
				hud.call("set_currency", wallet_gold)
			return true
	return false


func _capture_growth_transaction() -> Dictionary:
	return {
		"meta": meta_state.to_dict(),
		"collection": card_collection_service.call("capture_state"),
		"inventory": inventory_manager.call("to_dict"),
		"wallet_gold": wallet_gold,
	}


func _restore_growth_transaction(snapshot: Dictionary) -> void:
	meta_state.apply_dict(snapshot.get("meta", {}) as Dictionary)
	card_collection_service.call(
		"restore_state",
		snapshot.get("collection", {}) as Dictionary
	)
	inventory_manager.call("apply_dict", snapshot.get("inventory", {}) as Dictionary)
	wallet_gold = int(snapshot.get("wallet_gold", 0))
	_refresh_card_hand()
	_update_hud_resources()


func _on_combat_engaged() -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "COMBAT ENGAGED", "Dodge attacks or escape beyond the arena.")


func _on_disengage_warning(seconds: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call(
			"set_objective",
			"DISENGAGING — RETURN TO COMBAT",
			"Enemies reset in %d" % maxi(1, seconds)
		)


func _on_disengage_cancelled() -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "COMBAT REJOINED", "Enemy reset cancelled.")


func _on_combat_reset() -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "COMBAT DISENGAGED", "Living enemies returned and restored to full health.")


func _wire_boss_hud() -> void:
	if current_map == null:
		return
	var selected_boss: Node
	for boss in get_tree().get_nodes_in_group("Bosses"):
		if not current_map.is_ancestor_of(boss):
			continue
		var health := int(boss.get("health"))
		if health <= 0:
			continue
		var health_callback := _on_survival_boss_health_changed.bind(boss)
		if boss.has_signal("health_changed") and not boss.is_connected(
			"health_changed",
			health_callback
		):
			boss.connect("health_changed", health_callback)
		var defeated_callback := _on_survival_boss_removed.bind(boss)
		if boss.has_signal("defeated") and not boss.is_connected(
			"defeated",
			defeated_callback
		):
			boss.connect("defeated", defeated_callback)
		if (
			selected_boss == null
			or bool(boss.get_meta("completion_boss", false))
		):
			selected_boss = boss
	if selected_boss == null:
		_tracked_survival_boss = null
		if card_hand_ui != null and card_hand_ui.has_method("hide_boss_health"):
			card_hand_ui.call("hide_boss_health")
		return
	_tracked_survival_boss = selected_boss
	var maximum := 1
	var archetype: Variant = selected_boss.get("archetype")
	if archetype is Resource:
		maximum = int(archetype.get("max_health"))
	var name_text := String(selected_boss.get_meta("boss_variant_id", "heartwood_harbinger"))
	name_text = name_text.replace("_", " ").to_upper()
	card_hand_ui.call(
		"set_boss_health",
		name_text,
		int(selected_boss.get("health")),
		maximum
	)


func _on_survival_boss_health_changed(
	current: int,
	maximum: int,
	boss: Node
) -> void:
	if boss != _tracked_survival_boss or card_hand_ui == null:
		return
	var name_text := String(boss.get_meta("boss_variant_id", "heartwood_harbinger"))
	name_text = name_text.replace("_", " ").to_upper()
	card_hand_ui.call("set_boss_health", name_text, current, maximum)


func _on_survival_boss_removed(
	_enemy: Node,
	_experience: int,
	_gold_reward: int,
	boss: Node
) -> void:
	if boss == _tracked_survival_boss:
		call_deferred("_wire_boss_hud")


func _on_run_encounter_cleared(experience_reward: int, gold_reward: int) -> void:
	if not run_state.active:
		return
	run_state.add_reward("gold", gold_reward)
	run_state.add_reward("autumn_wood", 18)
	run_state.add_reward("magic_shard", 7)
	run_state.boss_defeated = true
	meta_state.dash_upgrade_unlocked = true
	inventory_manager.call("set_progression_unlocks", {"dash_upgrade_unlocked": true})
	_discover_equipment_reward()
	meta_state.add_resource("autumn_core", 1)
	inventory_manager.call("add_resource", &"autumn_core", 1)
	if player != null:
		player.experience += maxi(0, experience_reward)
	var summary := _finish_run(true)
	_show_run_result(true, summary)
	if hud != null and hud.has_method("set_objective"):
		hud.call(
			"set_objective",
			"HEARTWOOD GUARDIAN DEFEATED",
			"+%d Gold  +18 Autumn Wood  +7 Shards  +1 Autumn Core" % int(summary.get("gold", 0))
		)


func _on_player_defeated() -> void:
	if player == null or current_map == null:
		return
	player.call("set_input_enabled", false)
	var summary := _finish_run(false, RunState.OUTCOME_DEATH)
	await get_tree().create_timer(0.8).timeout
	_pending_player_state.clear()
	player = null
	load_current_map(load(_resolve_main_scene_path(TOWN_SCENE_PATH)) as PackedScene)
	_show_run_result(false, summary)


func _begin_autumn_run(deck_override: Array = []) -> void:
	_begin_expedition_run(deck_override, &"autumn", false)


func _begin_expedition_run(
	deck_override: Array = [],
	variant_id: StringName = &"autumn",
	boss_run: bool = false
) -> void:
	if run_state.active:
		return
	# Starting an expedition always owns input and time. If the player departs while
	# the optional Town opening is still visible, cancel that dialogue cleanly so
	# combat cannot inherit a paused SceneTree or a stale modal stack.
	var dialogue_ui := get_open_ui("DialogueUI")
	if dialogue_ui != null:
		close_ui(dialogue_ui)
	var fallback_deck: Array[String] = [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	]
	var selected: Array = deck_override if not deck_override.is_empty() else meta_state.selected_deck
	var normalized := _ensure_fixed_combo_loadout(
		_normalize_expedition_deck(selected)
	)
	if normalized.size() != deck_manager.hand_size:
		normalized = fallback_deck.duplicate()
	meta_state.set_selected_deck(normalized)
	var valid_ids: Array[String] = []
	for card in card_database.get_all_cards():
		valid_ids.append(String(card.get("id", "")))
	meta_state.normalize_selected_deck(valid_ids)
	run_state.begin_run(
		meta_state.selected_card_instances,
		variant_id,
		expedition_catalog.get_power_tier(variant_id),
		boss_run
	)
	divine_gift_manager.call("reset_run")
	deck_manager.set_protected_cards([])
	deck_manager.call(
		"start_fixed_hand",
		run_state.card_instances,
		run_state.max_energy
	)
	_run_auto_attack_card_id = _resolve_auto_attack_card_id(meta_state.auto_attack_card_id)
	_auto_attack_remaining = 0.0
	_background_attack_remaining_by_id.clear()
	_last_background_attack_result.clear()
	_configure_skill_loadout()
	_last_combo_name = "—"
	run_state.temporary_buffs["persistent_combo_stacks"] = {}
	run_state.temporary_buffs["combo_formula_history"] = []
	run_state.temporary_buffs["finisher_queue"] = []
	run_state.temporary_buffs["finisher_pending"] = false
	run_state.temporary_buffs["divine_rewarded_stages"] = {}
	_refresh_card_hand()
	_update_player_input_state()


func _show_card_reward_choices(wave_number: int) -> void:
	if not run_state.active:
		return
	var choices_by_wave := {
		2: ["echo_volley", "giant_arc", "battle_rhythm", "healing_light"],
		3: ["sweeping_reach", "quickened_cadence", "deep_reservoir", "storm_charge"],
	}
	var card_ids: Array = choices_by_wave.get(wave_number, ["guard", "renewal", "frostburst_imbue"])
	var choices: Array[Dictionary] = []
	for card_id in card_ids:
		var card := card_database.get_card(String(card_id))
		var localized_name := _localized_text(card, "name")
		var localized_description := _localized_text(card, "description")
		choices.append({
			"text": "%s — %s" % [localized_name, localized_description],
			"card_id": String(card_id),
			"name": localized_name,
			"description": localized_description,
			"type": String(card.get("type", "")),
			"cost": int(card.get("cost", 0)),
			"icon_path": String(card.get("icon_path", "")),
			"card_color": String(card.get("card_color", "")),
		})
	if growth_choice_queue.enqueue_wave_blessing(choices):
		call_deferred("_open_next_growth_choice")


func _add_persistent_run_card(card_id: String) -> bool:
	if not _is_combat_hand_card(card_database.get_card(card_id)):
		return false
	var instance: CardInstance = card_collection_service.call(
		"add_persistent_card",
		card_id
	)
	if instance == null:
		return false
	_refresh_card_hand()
	return true


func _apply_card_fusion(choice: Dictionary) -> bool:
	return card_collection_service.call("fuse", choice) != null


func _get_card_copy_count(card_id: String) -> int:
	return int(card_collection_service.call("get_copy_count", card_id))


func _finish_run(victory: bool, outcome: StringName = &"") -> Dictionary:
	if not run_state.active:
		return {}
	var summary := run_state.finish_run(victory, outcome)
	victory = bool(summary.get("victory", false))
	_auto_attack_remaining = 0.0
	_background_attack_remaining_by_id.clear()
	_last_background_attack_result.clear()
	_refresh_combo_runtime_modifiers()
	_update_player_input_state()
	_set_tactical_slowdown(false)
	card_hand_ui.visible = false
	card_hand_ui.call("hide_boss_health")
	meta_state.apply_run_summary(summary)
	var completed_variant := StringName(summary.get("expedition_variant_id", ""))
	if victory and not completed_variant.is_empty():
		if bool(summary.get("is_boss_run", false)):
			meta_state.mark_region_boss_defeated(completed_variant)
		else:
			meta_state.record_region_clear(completed_variant)
		meta_state.shortcuts["expedition_power_tier"] = maxi(
			int(meta_state.shortcuts.get("expedition_power_tier", 1)),
			int(summary.get("expedition_power_tier", 1))
		)
	inventory_manager.call("add_resource", &"gold", maxi(0, int(summary.get("gold", 0))))
	var materials: Variant = summary.get("materials", {})
	var material_qualities := summary.get("material_qualities", {}) as Dictionary
	if not material_qualities.is_empty():
		for resource_id in material_qualities:
			var quality_counts := material_qualities[resource_id] as Dictionary
			for quality_variant in quality_counts:
				inventory_manager.call(
					"add_resource",
					StringName(resource_id),
					maxi(0, int(quality_counts[quality_variant])),
					StringName(quality_variant)
				)
	elif materials is Dictionary:
		for resource_id in materials:
			inventory_manager.call(
				"add_resource",
				StringName(resource_id),
				maxi(0, int(materials[resource_id]))
			)
	_apply_completion_chest_reward(summary.get("chest_reward", {}) as Dictionary)
	_sync_progression_to_meta()
	save_service.save_meta(_meta_save_path(), meta_state.to_dict())
	if hud != null and hud.has_method("set_currency"):
		hud.call("set_currency", wallet_gold)
	return summary


func _select_survival_chest_reward() -> Dictionary:
	var available_blueprints: Array[StringName] = []
	for blueprint_id in SURVIVAL_CHEST_BLUEPRINTS:
		if not bool(inventory_manager.call("owns_blueprint", blueprint_id)):
			available_blueprints.append(blueprint_id)
	if run_state.defeated_enemies % 2 == 0 and not available_blueprints.is_empty():
		var blueprint_index := run_state.defeated_enemies % available_blueprints.size()
		return {
			"kind": "sword_soul_blueprint",
			"item_id": String(available_blueprints[blueprint_index]),
		}
	var equipment_index := run_state.defeated_enemies % SURVIVAL_CHEST_EQUIPMENT.size()
	return {
		"kind": "equipment",
		"item_id": String(SURVIVAL_CHEST_EQUIPMENT[equipment_index]),
	}


func _apply_completion_chest_reward(reward: Dictionary) -> bool:
	var item_id := StringName(reward.get("item_id", ""))
	if item_id.is_empty():
		return false
	match StringName(reward.get("kind", "")):
		&"sword_soul_blueprint":
			return bool(inventory_manager.call("grant_blueprint", item_id))
		&"equipment":
			if bool(inventory_manager.call("has_equipment", item_id)):
				inventory_manager.call("add_resource", &"gold", 120)
				return true
			return bool(inventory_manager.call("add_equipment", item_id))
	return false


func _on_card_selected(index: int) -> void:
	if not run_state.active or player == null or not ui_stack.is_empty():
		return
	if index < 0 or index >= deck_manager.hand_instances.size():
		return
	var instance := deck_manager.hand_instances[index]
	var projected_card := _card_for_cast(instance)
	if (
		String(projected_card.get("type", "")) == "combo"
		and not _can_resolve_combo_card(projected_card)
	):
		_show_combo_stack_limit_feedback(projected_card)
		return
	var card := deck_manager.play_from_hand(
		index,
		int(projected_card.get("cost", 0)),
		"discard"
	)
	if card.is_empty():
		_refresh_card_hand()
		return
	for identity_key in ["instance_id", "card_level", "card_instance"]:
		projected_card[identity_key] = card.get(identity_key)
	card = projected_card
	_apply_card_tempo(card)
	_record_combo_formula(card)
	if String(card.get("type", "")) == "combo":
		_resolve_combo_card(card)
	else:
		card = _apply_combo_infusions_to_card(card)
	_set_tactical_slowdown(false)
	_play_combat_vfx(card)
	var targets := _get_combat_targets()
	card_effect_runner.cast(card, player, targets)
	var gift_effects := divine_gift_manager.call("get_global_effects") as Dictionary
	var ap_refund := maxf(0.0, float(gift_effects.get("combo_ap_refund", 0.0)))
	if ap_refund > 0.0:
		deck_manager.energy = minf(deck_manager.max_energy, deck_manager.energy + ap_refund)
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) == "gain_energy":
		_resolve_energy_cycle(card)
	_resolve_skill_triggers(skill_recipe_manager.record_card(card))
	run_state.energy = deck_manager.energy
	_refresh_card_hand()
	if hud != null and hud.has_method("show_card_cast_feedback"):
		hud.call("show_card_cast_feedback", String(card.get("id", "")))
	_refresh_combo_display()


func _apply_card_tempo(card: Dictionary) -> float:
	var card_type := String(card.get("type", ""))
	if card_type != "combo" and card_type != "healing":
		return 0.0
	var catalog_card := card_database.get_card(String(card.get("id", "")))
	var catalog_cost := int(catalog_card.get("cost", card.get("cost", 0)))
	var stacks := clampi(
		int(run_state.temporary_buffs.get("card_tempo_stacks", 0)),
		0,
		CARD_TEMPO_MAX_STACKS
	)
	var refund := 0.0
	if catalog_cost >= CARD_TEMPO_POWER_CARD_COST:
		if catalog_cost == CARD_TEMPO_POWER_CARD_COST:
			stacks = maxi(0, stacks - CARD_TEMPO_POWER_CARD_DRAIN)
		else:
			stacks = 0
	elif catalog_cost == 2:
		stacks = mini(CARD_TEMPO_MAX_STACKS, stacks + CARD_TEMPO_TWO_AP_STACKS)
		refund = CARD_TEMPO_TWO_AP_REFUND
	elif catalog_cost == 1:
		stacks = mini(CARD_TEMPO_MAX_STACKS, stacks + CARD_TEMPO_ONE_AP_STACKS)
		refund = CARD_TEMPO_ONE_AP_REFUND
	else:
		return 0.0
	run_state.temporary_buffs["card_tempo_stacks"] = stacks
	run_state.temporary_buffs["card_tempo_remaining"] = (
		CARD_TEMPO_DURATION if stacks > 0 else 0.0
	)
	if refund > 0.0:
		deck_manager.energy = minf(deck_manager.max_energy, deck_manager.energy + refund)
		run_state.energy = deck_manager.energy
	return refund


func _tick_card_tempo(delta: float) -> bool:
	if delta <= 0.0:
		return false
	var remaining := float(run_state.temporary_buffs.get("card_tempo_remaining", 0.0))
	if remaining <= 0.0:
		return false
	remaining = maxf(0.0, remaining - delta)
	run_state.temporary_buffs["card_tempo_remaining"] = remaining
	if remaining > 0.0:
		return false
	run_state.temporary_buffs["card_tempo_stacks"] = 0
	return true


func _get_card_tempo_regen_bonus() -> float:
	return (
		float(run_state.temporary_buffs.get("card_tempo_stacks", 0))
		* CARD_TEMPO_REGEN_PER_STACK
	)


func _resolve_energy_cycle(card: Dictionary) -> float:
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) != "gain_energy":
		return 0.0
	var previous := deck_manager.energy
	deck_manager.energy = minf(
		deck_manager.max_energy,
		deck_manager.energy + maxf(0.0, float(effect.get("amount", 0.0)))
	)
	run_state.energy = deck_manager.energy
	return deck_manager.energy - previous


func _tick_basic_attack_cooldown(delta: float) -> void:
	if delta <= 0.0:
		return
	_auto_attack_remaining = maxf(0.0, _auto_attack_remaining - delta)


func _tick_auto_attack(delta: float) -> void:
	_tick_basic_attack_cooldown(delta)
	if _auto_attack_remaining > 0.0:
		return
	if not _try_basic_attack():
		_auto_attack_remaining = AUTO_ATTACK_RETRY_INTERVAL


func _tick_evolved_background_attacks(delta: float) -> void:
	if player == null or current_map == null:
		return
	var profiles := divine_gift_manager.call("get_background_attack_profiles") as Array
	var active_ids: Dictionary = {}
	for profile_variant in profiles:
		if not profile_variant is Dictionary:
			continue
		var profile := _runtime_background_attack_profile(profile_variant as Dictionary)
		var profile_id := String(profile.get("id", "")).strip_edges()
		if profile_id.is_empty():
			continue
		active_ids[profile_id] = true
		var remaining := maxf(
			0.0,
			float(_background_attack_remaining_by_id.get(profile_id, 0.0))
				- maxf(0.0, delta)
		)
		if remaining > 0.0:
			_background_attack_remaining_by_id[profile_id] = remaining
			continue
		if _cast_evolved_background_attack(profile):
			_background_attack_remaining_by_id[profile_id] = maxf(
				0.2,
				float(profile.get("interval", 3.0))
			)
		else:
			_background_attack_remaining_by_id[profile_id] = AUTO_ATTACK_RETRY_INTERVAL
	for profile_id_variant in _background_attack_remaining_by_id.keys():
		if not active_ids.has(String(profile_id_variant)):
			_background_attack_remaining_by_id.erase(profile_id_variant)


func _runtime_background_attack_profile(profile: Dictionary) -> Dictionary:
	var amplified := profile.duplicate(true)
	var combo_chain := maxi(0, int(run_state.temporary_buffs.get("combo_chain_count", 0)))
	var inventory := divine_gift_manager.call("get_inventory") as Array
	var total_levels := 0
	for gift_variant in inventory:
		if gift_variant is Dictionary:
			total_levels += maxi(1, int((gift_variant as Dictionary).get("level", 1)))
	var support_count := inventory.size()
	var growth_points := (
		combo_chain
		+ maxi(0, total_levels - support_count)
		+ maxi(0, support_count - 1) * 2
	)
	var size_scale := clampf(0.72 + float(growth_points) * 0.13, 0.72, 4.2)
	var instance_count := clampi(1 + floori(float(growth_points) / 3.0), 1, 12)
	var rhythm_speed := clampf(1.0 + float(growth_points) * 0.09, 1.0, 3.5)
	amplified["size_scale"] = size_scale
	amplified["instance_count"] = instance_count
	amplified["rhythm_speed"] = rhythm_speed
	amplified["destruction_tier"] = clampi(floori(float(growth_points) / 5.0), 0, 4)
	amplified["combo_chain"] = combo_chain
	amplified["supporting_blessing_count"] = support_count
	amplified["target_count"] = maxi(1, int(profile.get("target_count", 1)) + instance_count - 1)
	amplified["damage_scale"] = float(profile.get("damage_scale", 1.0)) * (
		1.0 + float(growth_points) * 0.08
	)
	amplified["interval"] = maxf(0.35, float(profile.get("interval", 3.0)) / rhythm_speed)
	return amplified


func _cast_evolved_background_attack(profile: Dictionary) -> bool:
	var targets := _get_combat_targets().filter(func(target: Variant) -> bool:
		return (
			target is Node2D
			and is_instance_valid(target)
			and (player as Node2D).global_position.distance_to(
				(target as Node2D).global_position
			) <= maxf(80.0, float(profile.get("range", 480.0)))
		)
	)
	if targets.is_empty():
		return false
	var target_count := maxi(1, int(profile.get("target_count", 1)))
	var selected := _nearest_combat_targets(targets, target_count)
	var card := _build_background_attack_card(profile)
	if card.is_empty():
		return false
	var result := card_effect_runner.cast(card, player, selected)
	result["profile_id"] = String(profile.get("id", ""))
	result["profile_name"] = String(profile.get("name", ""))
	result["inherits_sword_soul"] = true
	_last_background_attack_result = result.duplicate(true)
	_spawn_evolved_background_attack_vfx(profile, selected)
	return int(result.get("affected", 0)) > 0


func _build_background_attack_card(profile: Dictionary) -> Dictionary:
	var base_card := _get_auto_attack_card()
	if base_card.is_empty():
		return {}
	var base_effect := base_card.get("effect", {}) as Dictionary
	var target_count := maxi(1, int(profile.get("target_count", 1)))
	var effect := {
		"kind": "damage",
		"amount": maxi(1, roundi(
			float(base_effect.get("amount", 1))
				* maxf(0.1, float(profile.get("damage_scale", 1.0)))
		)),
		"target_count": target_count,
		"projectile_count": target_count,
		"direction_count": target_count,
		"elements": (profile.get("elements", []) as Array).duplicate(),
		"knockback_multiplier": 0.35,
	}
	match String(profile.get("pattern", "")):
		"chain_barrage":
			effect["burn_damage"] = 2
			effect["burn_duration"] = 2.5
			effect["combo_stun"] = 0.08
		"abyss_nova":
			effect["frost_ratio"] = 0.35
			effect["frost_duration"] = 2.2
		"venom_gale":
			effect["poison_damage"] = 2
			effect["poison_duration"] = 4.0
		"prismatic_orbit":
			effect["combo_stun"] = 0.12
	var attack := {
		"id": "background_%s" % String(profile.get("id", "evolved")),
		"name": String(profile.get("name", "昇華背景攻擊")),
		"type": "attack",
		"cost": 0,
		"effect": effect,
		"background_attack": true,
		"inherits_sword_soul": true,
	}
	return _apply_combo_infusions_to_card(attack)


func _spawn_evolved_background_attack_vfx(
	profile: Dictionary,
	targets: Array[Node2D]
) -> void:
	if evolved_background_attack_scene == null or current_map == null or not player is Node2D:
		return
	var visual := evolved_background_attack_scene.instantiate()
	current_map.add_child(visual)
	if visual is Node2D:
		(visual as Node2D).global_position = (player as Node2D).global_position
	var points: Array[Vector2] = []
	for target in targets:
		if target != null and is_instance_valid(target):
			points.append(target.global_position)
	if visual.has_method("play"):
		visual.call("play", profile, points)


func _try_basic_attack() -> bool:
	if (
		_auto_attack_remaining > 0.0
		or player == null
		or current_map == null
		or not ui_stack.is_empty()
		or get_tree().paused
	):
		return false
	var card := _get_auto_attack_card()
	if card.is_empty():
		return false
	var base_card := card_database.get_card(String(card.get("id", "")))
	card = _apply_combo_infusions_to_card(card)
	var finisher_queue := run_state.temporary_buffs.get(
		"finisher_queue",
		[]
	) as Array
	var is_finisher := not finisher_queue.is_empty()
	if is_finisher:
		card = _build_formula_finisher(
			card,
			finisher_queue[0] as Dictionary
		)
	var targets := _get_combat_targets()
	var attack_range := maxf(1.0, float(card.get("auto_attack_range", 220.0)))
	var hit_half_width := _get_auto_attack_hit_half_width(card)
	targets = targets.filter(func(target: Variant) -> bool:
		return (
			target is Node2D
			and is_instance_valid(target)
			and _is_target_in_auto_attack_shape(
				target as Node2D,
				card,
				attack_range,
				hit_half_width
			)
		)
	)
	if targets.is_empty():
		return false
	if player.has_method("play_attack_animation"):
		player.call("play_attack_animation")
	if is_finisher:
		_play_combat_vfx(card)
	var effect := card.get("effect", {}) as Dictionary
	var direction_count := maxi(1, int(effect.get("direction_count", 1)))
	var spread_degrees := clampf(float(effect.get("spread_degrees", 0.0)), 0.0, 360.0)
	var directional_attack := String(effect.get("kind", "")) == "damage"
	var direction_assignments: Array = []
	var cast_targets := targets
	if directional_attack:
		direction_assignments = _match_targets_to_attack_directions(
			targets,
			direction_count,
			spread_degrees,
			attack_range,
			hit_half_width
		)
		cast_targets = targets
		var corridor_effect := (card.get("effect", {}) as Dictionary).duplicate(true)
		corridor_effect["damage_mode"] = "directional_sweep_once"
		card["effect"] = corridor_effect
	else:
		direction_assignments = _nearest_combat_targets(
			targets,
			maxi(1, int(effect.get("target_count", 1)))
		)
	var health_before: Dictionary = {}
	for assigned_target in direction_assignments:
		if assigned_target is Node2D and is_instance_valid(assigned_target):
			health_before[assigned_target.get_instance_id()] = _read_health(assigned_target)
	card["cost"] = 0
	var result := _cast_auto_attack_effect(card, cast_targets)
	if is_finisher:
		var finisher_effect := card.get("effect", {}) as Dictionary
		var finisher_heal := maxi(0, int(finisher_effect.get("finisher_heal", 0)))
		if finisher_heal > 0 and player.has_method("restore_health"):
			player.call("restore_health", finisher_heal)
		var finisher_guard := maxi(0, int(finisher_effect.get("finisher_guard", 0)))
		if finisher_guard > 0 and player.has_method("add_block"):
			player.call("add_block", finisher_guard)
		var finisher_energy := maxf(
			0.0,
			float(finisher_effect.get("finisher_energy", 0.0))
		)
		if finisher_energy > 0.0:
			deck_manager.energy = minf(
				deck_manager.max_energy,
				deck_manager.energy + finisher_energy
			)
		_apply_finisher_support_statuses(card, finisher_effect)
		var echo_count := maxi(0, int(finisher_effect.get("finisher_echoes", 0)))
		for _echo in echo_count:
			var echo_result := _cast_auto_attack_effect(card, cast_targets)
			result["total"] = int(result.get("total", 0)) + int(echo_result.get("total", 0))
			result["affected"] = maxi(
				int(result.get("affected", 0)),
				int(echo_result.get("affected", 0))
			)
	if directional_attack or int(result.get("affected", 0)) > 0:
		for projectile_index in direction_count:
			var direction_index := projectile_index
			var feedback_target: Node2D = null
			if not direction_assignments.is_empty():
				var assigned_variant: Variant = direction_assignments[
					direction_index % direction_assignments.size()
				]
				if assigned_variant is Node2D and is_instance_valid(assigned_variant):
					feedback_target = assigned_variant as Node2D
			var damage := 0
			if feedback_target != null:
				damage = maxi(
					0,
					int(health_before.get(feedback_target.get_instance_id(), 0))
					- _read_health(feedback_target)
				)
			var visual_endpoint := _auto_attack_direction_endpoint(
				direction_index,
				direction_count,
				spread_degrees,
				attack_range
			)
			if feedback_target != null:
				visual_endpoint = _auto_attack_target_endpoint(
					feedback_target,
					direction_index,
					direction_count,
					spread_degrees,
					attack_range
				)
			var feedback_card := card.duplicate(true)
			var visual_profile := (
				feedback_card.get("combo_visual_profile", {}) as Dictionary
			).duplicate(true)
			visual_profile["direction_index"] = direction_index
			visual_profile["direction_count"] = direction_count
			visual_profile["spread_degrees"] = spread_degrees
			feedback_card["combo_visual_profile"] = visual_profile
			_spawn_auto_attack_feedback(
				feedback_card,
				base_card,
				feedback_target,
				damage,
				result,
				visual_endpoint
			)
	if is_finisher:
		_consume_finisher_formula()
	_auto_attack_remaining = maxf(
		0.1,
		float(card.get("auto_attack_interval", DEFAULT_AUTO_ATTACK_INTERVAL))
	)
	return true


func _apply_finisher_support_statuses(finisher: Dictionary, effect: Dictionary) -> void:
	if player == null:
		return
	var controller := player.get_node_or_null("CombatStatusController")
	if controller == null:
		return
	var source_id := String(finisher.get("id", "combo_finisher"))
	var display_name := String(finisher.get("name", "終結技"))
	var duration := maxf(0.1, float(effect.get("status_duration", 2.5)))
	var armor_tier := maxi(0, int(effect.get("super_armor_tier", 0)))
	if armor_tier > 0 and controller.has_method("apply_super_armor"):
		controller.call("apply_super_armor", source_id, armor_tier, duration, display_name)
	var reduction := clampf(float(effect.get("damage_reduction", 0.0)), 0.0, 0.9)
	if reduction > 0.0 and controller.has_method("apply_damage_reduction"):
		controller.call("apply_damage_reduction", source_id, reduction, duration, display_name)


func _nearest_combat_targets(targets: Array, count: int) -> Array[Node2D]:
	if not player is Node2D:
		return []
	var candidates: Array[Node2D] = []
	for target_variant in targets:
		if not target_variant is Node2D or not is_instance_valid(target_variant):
			continue
		candidates.append(target_variant as Node2D)
	candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return (player as Node2D).global_position.distance_squared_to(
			left.global_position
		) < (player as Node2D).global_position.distance_squared_to(
			right.global_position
		)
	)
	return candidates.slice(0, mini(maxi(0, count), candidates.size()))


func _match_targets_to_attack_directions(
	targets: Array,
	direction_count: int,
	spread_degrees: float,
	attack_range: float,
	hit_half_width: float = AUTO_ATTACK_HIT_HALF_WIDTH
) -> Array:
	var resolved_count := maxi(1, direction_count)
	var assignments: Array = []
	assignments.resize(resolved_count)
	if not player is Node2D:
		return assignments
	var candidates: Array[Node2D] = []
	for target_variant in targets:
		if (
			target_variant is Node2D
			and is_instance_valid(target_variant)
		):
			candidates.append(target_variant as Node2D)
	var attack_origin := _auto_attack_origin()
	var possible_matches: Array[Dictionary] = []
	for direction_index in resolved_count:
		var direction := _auto_attack_direction_vector(
			direction_index,
			resolved_count,
			spread_degrees
		)
		for candidate in candidates:
			var offset := _combat_target_aim_position(candidate) - attack_origin
			if offset.is_zero_approx():
				continue
			var travel_distance := offset.dot(direction)
			if not _is_target_in_directional_sweep(
				candidate,
				attack_range,
				hit_half_width,
				direction
			):
				continue
			var distance_from_ray := absf(offset.cross(direction))
			possible_matches.append({
				"direction_index": direction_index,
				"target": candidate,
				"score": distance_from_ray * attack_range - travel_distance,
			})
	possible_matches.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left["score"]) < float(right["score"])
	)
	var used_target_ids := {}
	for match_data in possible_matches:
		var direction_index := int(match_data["direction_index"])
		var target := match_data["target"] as Node2D
		if assignments[direction_index] != null or used_target_ids.has(target.get_instance_id()):
			continue
		assignments[direction_index] = target
		used_target_ids[target.get_instance_id()] = true
	return assignments


func _auto_attack_direction_endpoint(
	direction_index: int,
	direction_count: int,
	spread_degrees: float,
	attack_range: float
) -> Vector2:
	if not player is Node2D:
		return Vector2.ZERO
	return (
		_auto_attack_origin()
		+ _auto_attack_direction_vector(
			direction_index,
			direction_count,
			spread_degrees
		) * maxf(0.0, attack_range)
	)


func _auto_attack_target_endpoint(
	target: Node2D,
	direction_index: int,
	direction_count: int,
	spread_degrees: float,
	attack_range: float
) -> Vector2:
	if target == null or not is_instance_valid(target):
		return _auto_attack_direction_endpoint(
			direction_index,
			direction_count,
			spread_degrees,
			attack_range
		)
	var origin := _auto_attack_origin()
	var direction := _auto_attack_direction_vector(
		direction_index,
		direction_count,
		spread_degrees
	)
	var target_offset := _combat_target_aim_position(target) - origin
	var travel_distance := clampf(target_offset.dot(direction), 0.0, attack_range)
	return origin + direction * travel_distance


func _auto_attack_direction_vector(
	_direction_index: int,
	_direction_count: int,
	_spread_degrees: float
) -> Vector2:
	var facing := 1
	if player != null:
		facing = signi(int(player.get("facing_direction")))
		if facing == 0:
			facing = 1
	return Vector2(float(facing), 0.0)


func _attack_direction_angle_degrees(
	direction_index: int,
	direction_count: int,
	spread_degrees: float
) -> float:
	var resolved_count := maxi(1, direction_count)
	if resolved_count <= 1 or spread_degrees <= 0.0:
		return 0.0
	var clamped_index := clampi(direction_index, 0, resolved_count - 1)
	if spread_degrees >= 359.5:
		return -180.0 + 360.0 * float(clamped_index) / float(resolved_count)
	return lerpf(
		-spread_degrees * 0.5,
		spread_degrees * 0.5,
		float(clamped_index) / float(resolved_count - 1)
	)


func _auto_attack_origin() -> Vector2:
	if not player is Node2D:
		return Vector2.ZERO
	return (player as Node2D).global_position + Vector2(0.0, -42.0)


func _combat_target_aim_position(target: Node2D) -> Vector2:
	return ATTACK_GEOMETRY.target_center(target)


func _is_target_in_forward_corridor(
	target: Node2D,
	attack_range: float,
	half_height: float
) -> bool:
	if not player is Node2D or target == null or not is_instance_valid(target):
		return false
	return _is_target_in_directional_sweep(
		target,
		attack_range,
		half_height,
		_auto_attack_direction_vector(0, 1, 0.0)
	)


func _is_target_in_auto_attack_shape(
	target: Node2D,
	card: Dictionary,
	attack_range: float,
	blade_half_height: float
) -> bool:
	if not player is Node2D or target == null or not is_instance_valid(target):
		return false
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) == "area_damage":
		return ATTACK_GEOMETRY.radial_contains(
			(player as Node2D).global_position,
			_combat_target_aim_position(target),
			_combat_target_hit_radius(target),
			float(effect.get("radius", attack_range))
		)
	return _is_target_in_forward_corridor(
		target,
		attack_range,
		blade_half_height
	)


func _is_target_in_directional_sweep(
	target: Node2D,
	attack_range: float,
	blade_half_height: float,
	direction: Vector2
) -> bool:
	if not player is Node2D or target == null or not is_instance_valid(target):
		return false
	var origin := _auto_attack_origin()
	var endpoint := origin + direction.normalized() * maxf(0.0, attack_range)
	return ATTACK_GEOMETRY.directional_sweep_contains(
		origin,
		endpoint,
		_combat_target_aim_position(target),
		_combat_target_hit_radius(target),
		blade_half_height
	)


func _combat_target_hit_radius(target: Node2D) -> float:
	return ATTACK_GEOMETRY.target_radius(target)


func _get_auto_attack_hit_half_width(card: Dictionary) -> float:
	var visual_profile := card.get("combo_visual_profile", {}) as Dictionary
	var resolved_scale := ATTACK_GEOMETRY.resolve_size_scale(
		float(card.get("attack_size_multiplier", 1.0)),
		int(visual_profile.get("stack_count", 0))
	)
	var combo_count := int(run_state.temporary_buffs.get("combo_chain_count", 0))
	return (
		ATTACK_GEOMETRY.ENERGY_BLADE_HALF_HEIGHT
		* resolved_scale
		* ATTACK_GEOMETRY.resolve_combo_spectacle_scale(combo_count)
	)


func _read_health(target: Node) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	var health: Variant = target.get("health")
	return int(health) if health != null else 0


func _spawn_auto_attack_feedback(
	card: Dictionary,
	base_card: Dictionary,
	target: Node2D,
	damage: int,
	result: Dictionary,
	visual_target_position: Vector2
) -> void:
	if (
		auto_attack_feedback_scene == null
		or current_map == null
		or not player is Node2D
		or (target != null and not is_instance_valid(target))
	):
		return
	var feedback := auto_attack_feedback_scene.instantiate()
	current_map.add_child(feedback)
	if not feedback.has_method("play"):
		feedback.queue_free()
		return
	if feedback.has_signal("impact_reached"):
		feedback.connect(
			"impact_reached",
			_on_auto_attack_impact_reached,
			CONNECT_ONE_SHOT
		)
	var effect := card.get("effect", {}) as Dictionary
	var base_effect := base_card.get("effect", {}) as Dictionary
	var power_bonus := maxi(
		0,
		int(effect.get("amount", 0)) - int(base_effect.get("amount", 0))
	)
	var visual_profile := (
		card.get("combo_visual_profile", {}) as Dictionary
	).duplicate(true)
	visual_profile["blessing_attack_profiles"] = divine_gift_manager.call(
		"get_basic_attack_visual_profiles"
	) as Array
	feedback.call(
		"play",
		_auto_attack_origin(),
		visual_target_position,
		damage,
		int(run_state.temporary_buffs.get("combo_chain_count", 0)),
		power_bonus,
		bool(result.get("critical", false)),
		float(card.get("projectile_speed_multiplier", 1.0)),
		float(card.get("attack_size_multiplier", 1.0)),
		visual_profile
	)


func _cast_auto_attack_effect(card: Dictionary, targets: Array) -> Dictionary:
	_resolving_auto_attack_effect = true
	var result := card_effect_runner.cast(card, player, targets)
	_resolving_auto_attack_effect = false
	return result


func _on_auto_attack_impact_reached(did_hit: bool, combo_tier: int) -> void:
	if not did_hit:
		return
	var camera := (
		player.find_child("Camera2D", true, false) as Camera2D
		if player != null
		else null
	)
	if camera != null and float(meta_state.settings.get("camera_shake", 0.65)) > 0.0:
		var shake_scale := float(meta_state.settings.get("camera_shake", 0.65))
		var strength := (4.5 + float(combo_tier) * 1.5) * shake_scale
		camera.offset = Vector2(strength, -strength * 0.55)
		camera.create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.10)
	if (
		skill_cast_presentation != null
		and skill_cast_presentation.is_cast_active()
	):
		return
	_auto_attack_hit_stop_generation += 1
	var generation := _auto_attack_hit_stop_generation
	Engine.time_scale = minf(Engine.time_scale, 0.08)
	await get_tree().create_timer(0.030, true, false, true).timeout
	if generation != _auto_attack_hit_stop_generation:
		return
	if (
		skill_cast_presentation != null
		and skill_cast_presentation.is_cast_active()
	):
		return
	Engine.time_scale = 0.22 if _tactical_slowdown else 1.0


func _get_auto_attack_card() -> Dictionary:
	var card := card_database.get_card(_run_auto_attack_card_id)
	if card.is_empty() or String(card.get("type", "")) != "attack":
		return {}
	var best_instance: CardInstance
	for instance in meta_state.selected_card_instances:
		if instance.card_id != _run_auto_attack_card_id:
			continue
		if best_instance == null or instance.level > best_instance.level:
			best_instance = instance
	return _card_for_cast(best_instance) if best_instance != null else card


func _resolve_auto_attack_card_id(candidate: String) -> String:
	var normalized := candidate.strip_edges()
	if (
		meta_state.unlocked_cards.has(normalized)
		and String(card_database.get_card(normalized).get("type", "")) == "attack"
	):
		return normalized
	if (
		meta_state.unlocked_cards.has(DEFAULT_AUTO_ATTACK_CARD_ID)
		and card_database.has_card(DEFAULT_AUTO_ATTACK_CARD_ID)
	):
		return DEFAULT_AUTO_ATTACK_CARD_ID
	for card_id in meta_state.unlocked_cards:
		if String(card_database.get_card(card_id).get("type", "")) == "attack":
			return card_id
	return ""


func _get_combat_targets() -> Array:
	var targets: Array = []
	if current_map == null:
		return targets
	for director in get_tree().get_nodes_in_group("EncounterDirectors"):
		if current_map.is_ancestor_of(director) and director.has_method("get_active_enemies"):
			targets.append_array(director.call("get_active_enemies") as Array)
	if targets.is_empty():
		for enemy in get_tree().get_nodes_in_group("Enemies"):
			if current_map.is_ancestor_of(enemy) and is_instance_valid(enemy):
				targets.append(enemy)
	return targets


func _resolve_skill_triggers(triggered: Array[Dictionary]) -> void:
	for skill in triggered:
		var skill_id := String(skill.get("id", ""))
		var skill_name := String(skill.get("name", skill_id.capitalize()))
		var effect := skill.get("effect", {}) as Dictionary
		match String(effect.get("kind", "")):
			"combat_status", "regeneration", "healing_pulses":
				if player != null and player.has_method("apply_combat_status"):
					player.call("apply_combat_status", skill_id, skill_name, effect)
			"action_points":
				deck_manager.energy = minf(
					deck_manager.max_energy,
					deck_manager.energy + maxf(0.0, float(effect.get("amount", 0.0)))
				)
				run_state.energy = deck_manager.energy
		run_state.combo_count += 1
		if hud != null and hud.has_method("show_skill_toast"):
			hud.call("show_skill_toast", skill_id, skill_name)
		if skill_cast_presentation != null:
			skill_cast_presentation.play_cast(skill_name, &"neutral", 0.8)
		var vfx_profile := _resolve_combat_vfx_profile(skill)
		_spawn_named_skill_vfx(
			String(vfx_profile.get("named_vfx_id", "")),
			1.0,
			int(vfx_profile.get("evolution_level", 1)),
			int(vfx_profile.get("buff_stacks", 0)),
			vfx_profile.get("blessing_overlays", []) as Array
		)


func _open_hand_overflow_discard(required_count: int) -> void:
	if required_count <= 0 or get_open_ui("CardDiscardUI") != null:
		return
	var cards: Array[Dictionary] = []
	for instance in deck_manager.hand_instances:
		var card := _card_for_cast(instance)
		card["fixed"] = deck_manager.is_card_protected(instance)
		cards.append(card)
	var ui_control := open_ui("CardDiscardUI", card_discard_scene, true)
	if ui_control == null:
		return
	ui_control.call("configure", cards, required_count, deck_manager.protected_card_ids)
	ui_control.connect("discard_confirmed", _on_hand_overflow_confirmed.bind(ui_control), CONNECT_ONE_SHOT)


func _on_hand_overflow_confirmed(indices: Array[int], ui_control: Control) -> void:
	var required_count := maxi(0, deck_manager.hand_instances.size() - deck_manager.hand_size)
	if indices.size() != required_count:
		return
	for index in indices:
		if (
			index < 0
			or index >= deck_manager.hand_instances.size()
			or deck_manager.is_card_protected(deck_manager.hand_instances[index])
		):
			return
	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	for index in sorted_indices:
		if index < 0 or index >= deck_manager.hand_instances.size():
			continue
		var instance := deck_manager.hand_instances[index]
		if deck_manager.is_card_protected(instance):
			continue
		if deck_manager.remove_instances([instance.instance_id]):
			deck_manager.add_existing_instance(instance)
	close_ui(ui_control)
	_refresh_card_hand()


func _resolve_combo_card(card: Dictionary) -> bool:
	if card.is_empty() or String(card.get("type", "")) != "combo":
		return false
	if not _can_resolve_combo_card(card):
		_show_combo_stack_limit_feedback(card)
		return false
	_record_combo_chain(card)
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) != "infusion":
		return false
	var infusion_id := String(effect.get("infusion_id", ""))
	if infusion_id.is_empty():
		return false
	var active_variant: Variant = run_state.temporary_buffs.get("active_infusions", [])
	var active: Array = active_variant if active_variant is Array else []
	if not active.has(infusion_id) and active.size() >= MAX_COMBO_ABILITIES:
		return false
	if not active.has(infusion_id):
		active.append(infusion_id)
	run_state.temporary_buffs["active_infusions"] = active
	var levels_variant: Variant = run_state.temporary_buffs.get("combo_levels", {})
	var levels: Dictionary = levels_variant if levels_variant is Dictionary else {}
	var current_level := int(levels.get(infusion_id, 0))
	if current_level >= _get_combo_stack_cap():
		return false
	levels[infusion_id] = current_level + 1
	run_state.temporary_buffs["combo_levels"] = levels
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	var effects: Array = effects_variant if effects_variant is Array else []
	var timed_effect := effect.duplicate(true)
	var equipment_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
	timed_effect["remaining_seconds"] = _combo_effect_duration(
		float(effect.get("combo_duration", DEFAULT_COMBO_DURATION)),
		float(equipment_specials.get("combo_duration_bonus", 0.0))
	)
	timed_effect["persistent"] = false
	effects.append(timed_effect)
	run_state.temporary_buffs["infusion_effects"] = effects
	_try_evolve_combo_abilities()
	_refresh_combo_runtime_modifiers()
	return true


func _combo_effect_duration(base_duration: float, bonus_duration: float = 0.0) -> float:
	return maxf(
		0.1,
		minf(MAX_COMBO_EFFECT_DURATION, base_duration + bonus_duration)
	)


func _combo_chain_duration_for_count(
	total_combo: int,
	bonus_duration: float = 0.0
) -> float:
	var normalized_combo := maxi(1, total_combo)
	var base_duration := COMBO_CHAIN_OPENING_DURATION
	if normalized_combo > 3:
		base_duration = maxf(
			COMBO_CHAIN_MIN_DURATION,
			COMBO_CHAIN_PRESSURE_DURATION
			- COMBO_CHAIN_DURATION_STEP * float(normalized_combo - 4)
		)
	return minf(
		MAX_COMBO_DURATION,
		base_duration + maxf(0.0, bonus_duration)
	)


func _can_resolve_combo_card(card: Dictionary) -> bool:
	if card.is_empty() or String(card.get("type", "")) != "combo":
		return false
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) != "infusion":
		return true
	var infusion_id := String(effect.get("infusion_id", ""))
	if infusion_id.is_empty():
		return false
	var active_variant: Variant = run_state.temporary_buffs.get("active_infusions", [])
	var active: Array = active_variant if active_variant is Array else []
	if not active.has(infusion_id) and active.size() >= MAX_COMBO_ABILITIES:
		return false
	var levels_variant: Variant = run_state.temporary_buffs.get("combo_levels", {})
	var levels: Dictionary = levels_variant if levels_variant is Dictionary else {}
	return int(levels.get(infusion_id, 0)) < _get_combo_stack_cap()


func _show_combo_stack_limit_feedback(card: Dictionary) -> void:
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) != "infusion":
		return
	var infusion_id := String(effect.get("infusion_id", ""))
	var levels := run_state.temporary_buffs.get("combo_levels", {}) as Dictionary
	var stack_cap := _get_combo_stack_cap()
	if infusion_id.is_empty() or int(levels.get(infusion_id, 0)) < stack_cap:
		return
	var skill_name := _localized_text(card, "name")
	if skill_name.is_empty():
		skill_name = String(card.get("id", "劍魂"))
	if hud != null and hud.has_method("show_combo_popup"):
		hud.call("show_combo_popup", skill_name, stack_cap)


func _record_combo_formula(card: Dictionary) -> Dictionary:
	if (
		card.is_empty()
		or not meta_state.unlocked_cards.has(String(card.get("id", "")))
		or not combo_finisher_catalog.call(
			"is_skill_eligible",
			String(card.get("id", ""))
		)
	):
		return {}
	var gift_effects := divine_gift_manager.call("get_global_effects") as Dictionary
	var stack_gain := 1 + maxi(0, int(gift_effects.get("combo_stack_bonus", 0)))
	var stacks_variant: Variant = run_state.temporary_buffs.get(
		"persistent_combo_stacks",
		{}
	)
	var stacks: Dictionary = stacks_variant if stacks_variant is Dictionary else {}
	var tags_variant: Variant = card.get("combo_tags", card.get("tags", []))
	var tags: Array = tags_variant if tags_variant is Array else []
	var meaningful_tags: Array[String] = []
	for tag_variant in tags:
		var tag := String(tag_variant).strip_edges()
		if tag.is_empty() or tag in ["combo", "support"]:
			continue
		if not meaningful_tags.has(tag):
			meaningful_tags.append(tag)
	if meaningful_tags.is_empty():
		meaningful_tags.append(String(card.get("id", "combo")))
	var stack_cap := _get_combo_stack_cap()
	for tag in meaningful_tags:
		stacks[tag] = mini(stack_cap, int(stacks.get(tag, 0)) + stack_gain)
	run_state.temporary_buffs["persistent_combo_stacks"] = stacks

	var history_variant: Variant = run_state.temporary_buffs.get(
		"combo_formula_history",
		[]
	)
	var history: Array = history_variant if history_variant is Array else []
	history.append(card.duplicate(true))
	while history.size() > COMBO_FORMULA_LENGTH:
		history.pop_front()
	run_state.temporary_buffs["combo_formula_history"] = history
	var queued_recipe: Dictionary = {}
	var sequence: Array[String] = []
	for formula_card_variant in history:
		sequence.append(String((formula_card_variant as Dictionary).get("id", "")))
	var matched_skills := skill_recipe_manager.match_active_combo_routes(sequence)
	var triggered_variant: Variant = run_state.temporary_buffs.get(
		"combo_triggered_skill_ids",
		[]
	)
	var triggered_ids: Array = triggered_variant if triggered_variant is Array else []
	var queue_variant: Variant = run_state.temporary_buffs.get("finisher_queue", [])
	var finisher_queue: Array = queue_variant if queue_variant is Array else []
	for skill_variant in matched_skills:
		var skill := skill_variant as Dictionary
		var skill_id := String(skill.get("id", ""))
		if skill_id.is_empty() or triggered_ids.has(skill_id):
			continue
		var legacy_recipe := combo_finisher_catalog.call(
			"get_recipe",
			String(skill.get("legacy_vfx_id", ""))
		) as Dictionary
		if legacy_recipe.is_empty():
			continue
		var route_length := 3 if String(skill.get("tier", "")) == "basic" else (4 if String(skill.get("tier", "")) == "advanced" else 6)
		queued_recipe = legacy_recipe.duplicate(true)
		queued_recipe["id"] = skill_id
		queued_recipe["name"] = String(skill.get("name", skill_id))
		queued_recipe["recipe_id"] = skill_id
		queued_recipe["legacy_vfx_id"] = String(skill.get("legacy_vfx_id", ""))
		queued_recipe["series_id"] = String(skill.get("series_id", ""))
		queued_recipe["gameplay_family"] = String(skill.get("gameplay_family", ""))
		queued_recipe["tier"] = String(skill.get("tier", ""))
		queued_recipe["tier_rank"] = int(skill.get("tier_rank", 1))
		queued_recipe["gameplay_effect"] = (skill.get("gameplay_effect", {}) as Dictionary).duplicate(true)
		queued_recipe["formula_cards"] = history.slice(history.size() - route_length).duplicate(true)
		finisher_queue.append(queued_recipe)
		triggered_ids.append(skill_id)
	run_state.temporary_buffs["finisher_queue"] = finisher_queue
	run_state.temporary_buffs["combo_triggered_skill_ids"] = triggered_ids
	var pending_queue := run_state.temporary_buffs.get(
		"finisher_queue",
		[]
	) as Array
	run_state.temporary_buffs["finisher_pending"] = not pending_queue.is_empty()
	return {
		"history": history.duplicate(true),
		"stacks": stacks.duplicate(true),
		"finisher_pending": not pending_queue.is_empty(),
		"queued_recipe": queued_recipe,
	}


func _get_combo_stack_cap() -> int:
	var equipment_specials := inventory_manager.call(
		"get_special_ability_totals"
	) as Dictionary
	var gift_effects := divine_gift_manager.call("get_global_effects") as Dictionary
	var bonus := (
		maxi(0, int(equipment_specials.get("combo_stack_cap_bonus", 0)))
		+ maxi(0, int(gift_effects.get("combo_stack_cap_bonus", 0)))
	)
	return clampi(
		BASE_COMBO_STACK_CAP + bonus,
		BASE_COMBO_STACK_CAP,
		MAX_COMBO_STACK_CAP
	)


func _is_finisher_recipe_learned(recipe: Dictionary) -> bool:
	var required_variant: Variant = recipe.get(
		"required_skills",
		recipe.get("sequence", [])
	)
	if not required_variant is Array:
		return false
	for skill_id_variant in required_variant as Array:
		if not meta_state.unlocked_cards.has(String(skill_id_variant)):
			return false
	return true


func _combo_stack_for_card(card: Dictionary) -> int:
	var stacks := run_state.temporary_buffs.get(
		"persistent_combo_stacks",
		{}
	) as Dictionary
	var tags_variant: Variant = card.get("combo_tags", card.get("tags", []))
	if not tags_variant is Array:
		return 0
	var maximum := 0
	for tag_variant in tags_variant as Array:
		var tag := String(tag_variant)
		if tag in ["combo", "support"]:
			continue
		maximum = maxi(maximum, int(stacks.get(tag, 0)))
	return maximum


func _combo_chain_stack_for_card(card: Dictionary) -> int:
	var skill_name := _localized_text(card, "name")
	if skill_name.is_empty():
		skill_name = String(card.get("id", ""))
	var skills := run_state.temporary_buffs.get(
		"combo_chain_skills",
		{}
	) as Dictionary
	return clampi(
		int(skills.get(skill_name, 0)),
		0,
		_get_combo_stack_cap()
	)


func _build_formula_finisher(
	base_attack: Dictionary,
	finisher_entry: Dictionary = {}
) -> Dictionary:
	var finisher := base_attack.duplicate(true)
	var effect := (finisher.get("effect", {}) as Dictionary).duplicate(true)
	var gift_effects := divine_gift_manager.call("get_global_effects") as Dictionary
	var recipe := finisher_entry
	if recipe.is_empty():
		var pending_queue := run_state.temporary_buffs.get(
			"finisher_queue",
			[]
		) as Array
		if not pending_queue.is_empty():
			recipe = pending_queue[0] as Dictionary
	var formula_variant: Variant = recipe.get(
		"formula_cards",
		run_state.temporary_buffs.get("combo_formula_history", [])
	)
	var formula: Array = (
		formula_variant if formula_variant is Array else []
	)
	var recipe_effect := recipe.get("base_effect", {}) as Dictionary
	var combo_multiplier := maxf(
		1.0,
		float(gift_effects.get("combo_effect_multiplier", 1.0))
	)
	var bonus_damage := int(
		recipe_effect.get("damage_bonus", COMBO_FINISHER_DAMAGE)
	)
	var projectile_bonus := maxi(
		0,
		int(recipe_effect.get("projectile_bonus", 0))
	)
	var finisher_heal := maxi(
		0,
		int(recipe_effect.get("finisher_heal", 0))
		+ int(gift_effects.get("finisher_heal", 0))
	)
	var finisher_guard := maxi(0, int(recipe_effect.get("finisher_guard", 0)))
	var finisher_energy := maxf(0.0, float(recipe_effect.get("finisher_energy", 0.0)))
	var elements: Array[String] = []
	for status_key in [
		"burn_damage", "burn_duration", "frost_ratio",
		"frost_duration", "poison_damage", "poison_duration",
		"combo_stun", "damage_reduction", "status_duration",
		"super_armor_tier", "defense_bonus", "cleanse",
	]:
		if recipe_effect.has(status_key):
			effect[status_key] = recipe_effect[status_key]
	for formula_card_variant in formula:
		if not formula_card_variant is Dictionary:
			continue
		var formula_card := formula_card_variant as Dictionary
		var formula_effect := formula_card.get("effect", {}) as Dictionary
		match String(formula_effect.get("kind", "")):
			"infusion":
				bonus_damage += roundi(
					float(formula_effect.get("damage_bonus", 0)) * combo_multiplier
				)
				projectile_bonus += maxi(
					0,
					roundi(
						float(formula_effect.get("projectile_bonus", 0))
						* combo_multiplier
					)
				)
				for key in [
					"burn_damage", "burn_duration", "frost_ratio",
					"frost_duration", "poison_damage", "poison_duration",
					"combo_stun",
				]:
					if formula_effect.has(key):
						effect[key] = maxf(
							float(effect.get(key, 0.0)),
							float(formula_effect[key]) * combo_multiplier
						)
				var infusion_id := String(formula_effect.get("infusion_id", ""))
				if infusion_id in ["flame", "frost", "storm", "venom"]:
					_append_vfx_element(elements, infusion_id)
				finisher_guard += maxi(0, int(formula_effect.get("defense_bonus", 0)))
				finisher_energy += maxf(
					0.0,
					float(formula_effect.get("ap_regen_bonus", 0.0))
					+ float(formula_effect.get("ap_max_bonus", 0.0))
				)
			"heal", "regeneration", "healing_pulses":
				var healing_amount := float(formula_effect.get(
					"amount",
					formula_effect.get("heal", 8)
				))
				finisher_heal += maxi(
					1,
					roundi(healing_amount * 0.35)
				)
			"combat_status":
				finisher_guard += 4
				var lifesteal_ratio := clampf(
					float(formula_effect.get("lifesteal_ratio", 0.0)),
					0.0,
					1.0
				)
				finisher_heal += roundi(
					float(effect.get("amount", 0)) * lifesteal_ratio
				)
				for status_variant in formula_effect.get("statuses", []) as Array:
					if not status_variant is Dictionary:
						continue
					var status := status_variant as Dictionary
					var duration := maxf(
						float(effect.get("status_duration", 0.0)),
						float(status.get("duration", 0.0))
					)
					effect["status_duration"] = duration
					match String(status.get("status_id", "")):
						"super_armor":
							effect["super_armor_tier"] = maxi(
								int(effect.get("super_armor_tier", 0)),
								int(status.get("tier", 1))
							)
						"damage_reduction":
							effect["damage_reduction"] = maxf(
								float(effect.get("damage_reduction", 0.0)),
								float(status.get("ratio", 0.0))
							)
			"gain_energy":
				finisher_energy += maxf(
					0.0,
					float(formula_effect.get("amount", 0.0)) * 0.25
				)
	var stacks := run_state.temporary_buffs.get(
		"persistent_combo_stacks",
		{}
	) as Dictionary
	var total_stacks := 0
	for stack_value in stacks.values():
		total_stacks += maxi(0, int(stack_value))
	bonus_damage += floori(float(total_stacks) * 0.75 * combo_multiplier)
	bonus_damage += maxi(0, int(gift_effects.get("finisher_element_damage", 0)))
	var damage_scale := clampf(float(recipe_effect.get("damage_scale", 1.0)), 0.0, 4.0)
	effect["amount"] = roundi(damage_scale * float(
		float(int(effect.get("amount", 0)) + bonus_damage)
		* maxf(
			1.0,
			float(gift_effects.get("finisher_damage_multiplier", 1.0))
		)
	))
	effect["projectile_count"] = maxi(
		1,
		int(effect.get("projectile_count", 1)) + projectile_bonus
	)
	effect["direction_count"] = int(effect["projectile_count"])
	effect["target_count"] = int(effect["projectile_count"])
	effect["spread_degrees"] = 0.0
	effect["finisher_heal"] = finisher_heal
	effect["finisher_guard"] = finisher_guard
	effect["finisher_energy"] = finisher_energy
	effect["finisher_echoes"] = maxi(
		0,
		int(gift_effects.get("finisher_echoes", 0))
	)
	var series_family := String(recipe.get("gameplay_family", ""))
	var series_effect := recipe.get("gameplay_effect", {}) as Dictionary
	if not series_family.is_empty():
		effect["series_gameplay_family"] = series_family
		effect["tier_rank"] = clampi(
			int(series_effect.get("tier_rank", recipe.get("tier_rank", 1))),
			1,
			3
		)
		var series_projectiles := maxi(0, int(series_effect.get("projectiles", 0)))
		if series_projectiles > 0:
			effect["projectile_count"] = maxi(series_projectiles, int(effect.get("projectile_count", 1)))
			effect["direction_count"] = int(effect["projectile_count"])
			effect["target_count"] = maxi(int(effect.get("target_count", 1)), series_projectiles)
		var series_damage_multiplier := maxf(1.0, float(series_effect.get("damage_multiplier", 1.0)))
		if series_damage_multiplier > 1.0 and int(effect.get("amount", 0)) > 0:
			effect["amount"] = roundi(float(effect["amount"]) * series_damage_multiplier)
		for numeric_key in ["burn_damage", "burn_duration", "poison_damage", "poison_duration", "combo_stun", "pull_strength", "knockback_multiplier", "lifesteal_ratio", "heal_on_hit_ratio"]:
			if series_effect.has(numeric_key):
				effect[numeric_key] = maxf(float(effect.get(numeric_key, 0.0)), float(series_effect[numeric_key]))
		for flag_key in ["final_burst", "chain_lightning", "death_spread", "piercing"]:
			if bool(series_effect.get(flag_key, false)):
				effect[flag_key] = true
		if bool(series_effect.get("returning", false)):
			effect["returning_projectiles"] = true
		effect["finisher_guard"] = maxi(int(effect.get("finisher_guard", 0)), int(series_effect.get("guard", 0)))
		effect["finisher_heal"] = maxi(int(effect.get("finisher_heal", 0)), int(series_effect.get("heal", 0)))
		effect["finisher_echoes"] = maxi(int(effect.get("finisher_echoes", 0)), int(series_effect.get("echoes", 0)))
		if series_effect.has("range_multiplier"):
			finisher["auto_attack_range"] = float(finisher.get("auto_attack_range", COMBO_FINISHER_RANGE)) * float(series_effect["range_multiplier"])
	if String(recipe.get("series_id", "")) == "ancient_wood":
		var wood_effect := recipe.get("gameplay_effect", {}) as Dictionary
		var relay_count := maxi(1, int(wood_effect.get("relay_count", 1)))
		var base_amount := int((base_attack.get("effect", {}) as Dictionary).get("amount", COMBO_FINISHER_DAMAGE))
		effect["amount"] = maxi(
			int(effect.get("amount", 0)),
			roundi(float(base_amount + COMBO_FINISHER_DAMAGE) * float(wood_effect.get("damage_multiplier", 1.0)))
		)
		effect["projectile_count"] = relay_count
		effect["direction_count"] = relay_count
		effect["target_count"] = maxi(relay_count, int(effect.get("target_count", 1)))
		effect["piercing"] = true
		effect["sword_aura_gate_chain"] = true
		effect["gate_count"] = maxi(2, int(wood_effect.get("gate_count", 2)))
		finisher["auto_attack_range"] = maxf(
			COMBO_FINISHER_RANGE,
			float(finisher.get("auto_attack_range", COMBO_FINISHER_RANGE))
			* float(wood_effect.get("range_multiplier", 1.0))
		)
		finisher["attack_size_multiplier"] = (
			float(finisher.get("attack_size_multiplier", 1.0))
			* float(wood_effect.get("size_multiplier", 1.0))
		)
	var mutations := divine_gift_manager.call(
		"get_finisher_mutations"
	) as Dictionary
	for mutation_key in [
		"burn_damage", "burn_duration", "frost_ratio",
		"frost_duration", "poison_damage", "poison_duration",
		"combo_stun",
	]:
		if mutations.has(mutation_key):
			effect[mutation_key] = maxf(
				float(effect.get(mutation_key, 0.0)),
				float(mutations[mutation_key])
			)
	for flag_key in [
		"shatter", "final_burst", "death_spread",
		"chain_lightning", "piercing", "returning_projectiles",
	]:
		if bool(recipe_effect.get(flag_key, false)):
			effect[flag_key] = true
		if bool(mutations.get(flag_key, false)):
			effect[flag_key] = true
	effect["finisher_echoes"] = maxi(
		int(effect.get("finisher_echoes", 0)),
		int(mutations.get("finisher_echoes", 0))
	)
	if bool(effect.get("piercing", false)):
		effect["target_count"] = maxi(6, int(effect.get("target_count", 1)))
	var blessing_overlays := _build_finisher_blessing_overlays()
	for blessing_overlay_variant in blessing_overlays:
		var blessing_overlay := blessing_overlay_variant as Dictionary
		for gift_element_variant in blessing_overlay.get("elements", []) as Array:
			_append_vfx_element(elements, String(gift_element_variant))
	var recipe_name := String(recipe.get("name", "Finisher"))
	var epithet := String(divine_gift_manager.call("get_epithet_prefix"))
	finisher["id"] = String(recipe.get("id", "divine_finale"))
	finisher["name"] = "%s%s" % [epithet, recipe_name]
	finisher["effect"] = effect
	finisher["auto_attack_range"] = maxf(
		COMBO_FINISHER_RANGE,
		float(finisher.get("auto_attack_range", 0.0))
	)
	if bool(effect.get("piercing", false)):
		finisher["auto_attack_range"] = float(finisher["auto_attack_range"]) * 1.25
	finisher["attack_size_multiplier"] = (
		float(finisher.get("attack_size_multiplier", 1.0))
		* maxf(1.0, float(recipe_effect.get("size_multiplier", 2.0)))
		* maxf(
			1.0,
			float(gift_effects.get("finisher_size_multiplier", 1.0))
		)
	)
	finisher["combo_visual_profile"] = {
		"finisher": true,
		"finisher_name": String(finisher["name"]),
		"stack_count": total_stacks,
		"elements": elements,
		"blessing_overlays": blessing_overlays,
	}
	return finisher


func _build_finisher_blessing_overlays(maximum: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if maximum <= 0:
		return result
	var seen_ids: Dictionary = {}
	var gift_inventory := divine_gift_manager.call("get_inventory") as Array
	for gift_variant in gift_inventory:
		if not gift_variant is Dictionary:
			continue
		var gift := gift_variant as Dictionary
		var gift_id := String(gift.get("id", "")).strip_edges()
		if gift_id.is_empty() or seen_ids.has(gift_id):
			continue
		var gift_elements: Array[String] = []
		var element_values := gift.get(
			"elements",
			[gift.get("element", "normal")]
		) as Array
		for element_variant in element_values:
			_append_vfx_element(gift_elements, String(element_variant))
		if gift_elements.is_empty():
			_append_vfx_element(gift_elements, String(gift.get("element", "normal")))
		var kind := String(gift.get("kind", "base"))
		result.append({
			"id": gift_id,
			"name": String(gift.get("name", gift_id)),
			"kind": kind,
			"evolved": kind == "evolved",
			"level": clampi(int(gift.get("level", 1)), 1, 3),
			"max_level": clampi(int(gift.get("max_level", 3)), 1, 3),
			"element": gift_elements[0] if not gift_elements.is_empty() else "normal",
			"elements": gift_elements,
			"components": (gift.get("components", []) as Array).duplicate(),
			"accent_color": String(gift.get("accent_color", "")),
			"acquisition_index": result.size(),
		})
		seen_ids[gift_id] = true
		if result.size() >= maximum:
			break
	return result


func _consume_finisher_formula() -> void:
	var queue := run_state.temporary_buffs.get(
		"finisher_queue",
		[]
	) as Array
	if not queue.is_empty():
		queue.pop_front()
	run_state.temporary_buffs["finisher_queue"] = queue
	run_state.temporary_buffs["finisher_pending"] = not queue.is_empty()
	_refresh_combo_display()


func _record_combo_chain(card: Dictionary) -> void:
	var equipment_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
	var stack_cap := _get_combo_stack_cap()
	_last_combo_name = _localized_text(card, "name")
	if _last_combo_name.is_empty():
		_last_combo_name = String(card.get("id", "劍魂"))
	var skills_variant: Variant = run_state.temporary_buffs.get("combo_chain_skills", {})
	var skills: Dictionary = skills_variant if skills_variant is Dictionary else {}
	if (
		int(run_state.temporary_buffs.get("combo_chain_count", 0)) <= 0
		or float(run_state.temporary_buffs.get("combo_chain_remaining", 0.0)) <= 0.0
	):
		skills = {}
		run_state.temporary_buffs["combo_chain_order"] = []
	var current_skill_count := maxi(0, int(skills.get(_last_combo_name, 0)))
	var next_skill_count := mini(stack_cap, current_skill_count + 1)
	if next_skill_count > current_skill_count:
		skills[_last_combo_name] = next_skill_count
		run_state.temporary_buffs["combo_chain_skills"] = skills
	if hud != null and hud.has_method("show_combo_popup"):
		hud.call("show_combo_popup", _last_combo_name, next_skill_count)
	var total := 0
	for count_variant in skills.values():
		total += clampi(int(count_variant), 0, stack_cap)
	run_state.temporary_buffs["combo_chain_count"] = total
	run_state.temporary_buffs["combo_chain_remaining"] = _combo_chain_duration_for_count(
		total,
		float(equipment_specials.get("combo_duration_bonus", 0.0))
	)
	var order_variant: Variant = run_state.temporary_buffs.get("combo_chain_order", [])
	var order: Array = order_variant if order_variant is Array else []
	order.erase(_last_combo_name)
	order.push_front(_last_combo_name)
	run_state.temporary_buffs["combo_chain_order"] = order


func _try_evolve_combo_abilities() -> bool:
	var active_variant: Variant = run_state.temporary_buffs.get("active_infusions", [])
	var levels_variant: Variant = run_state.temporary_buffs.get("combo_levels", {})
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not active_variant is Array or not levels_variant is Dictionary or not effects_variant is Array:
		return false
	var active := active_variant as Array
	var levels := levels_variant as Dictionary
	var effects := effects_variant as Array
	for recipe in COMBO_EVOLUTIONS:
		var required := recipe["requires"] as Array
		if required.any(func(combo_id: Variant) -> bool:
			return int(levels.get(String(combo_id), 0)) < MAX_COMBO_LEVEL
		):
			continue
		var evolved_remaining := 0.0
		for combo_id in required:
			active.erase(String(combo_id))
			levels.erase(String(combo_id))
			var retained_effects: Array = []
			for effect_variant in effects:
				if not effect_variant is Dictionary:
					continue
				var timed_effect := effect_variant as Dictionary
				if String(timed_effect.get("infusion_id", "")) == String(combo_id):
					evolved_remaining = maxf(evolved_remaining, float(timed_effect.get("remaining_seconds", 0.0)))
				else:
					retained_effects.append(effect_variant)
			effects = retained_effects
		var evolution_id := String(recipe["id"])
		active.append(evolution_id)
		levels[evolution_id] = 1
		var evolved_effect := (recipe["effect"] as Dictionary).duplicate(true)
		evolved_effect["remaining_seconds"] = maxf(0.1, evolved_remaining)
		evolved_effect["persistent"] = false
		effects.append(evolved_effect)
		run_state.temporary_buffs["active_infusions"] = active
		run_state.temporary_buffs["combo_levels"] = levels
		run_state.temporary_buffs["infusion_effects"] = effects
		_last_combo_name = String(recipe["name"])
		return true
	return false


func _tick_combo_effects(delta: float) -> bool:
	if delta <= 0.0:
		return false
	var changed := false
	var chain_remaining := maxf(
		0.0,
		float(run_state.temporary_buffs.get("combo_chain_remaining", 0.0)) - delta
	)
	if float(run_state.temporary_buffs.get("combo_chain_remaining", 0.0)) > 0.0:
		changed = true
		run_state.temporary_buffs["combo_chain_remaining"] = chain_remaining
		if is_zero_approx(chain_remaining):
			run_state.temporary_buffs["combo_chain_count"] = 0
			run_state.temporary_buffs["combo_chain_skills"] = {}
			run_state.temporary_buffs["combo_chain_order"] = []
			run_state.temporary_buffs["combo_formula_history"] = []
			run_state.temporary_buffs["combo_triggered_skill_ids"] = []
			_refresh_card_hand()
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not effects_variant is Array:
		return changed
	var effects := effects_variant as Array
	if effects.is_empty():
		return changed
	var retained: Array = []
	for effect_variant in effects:
		if not effect_variant is Dictionary:
			changed = true
			continue
		var timed_effect := (effect_variant as Dictionary).duplicate(true)
		if bool(timed_effect.get("persistent", false)):
			retained.append(timed_effect)
			continue
		if int(timed_effect.get("remaining_attacks", 0)) > 0:
			retained.append(timed_effect)
			continue
		var remaining := float(timed_effect.get(
			"remaining_seconds",
			_combo_effect_duration(
				float(timed_effect.get("combo_duration", DEFAULT_COMBO_DURATION))
			)
		)) - delta
		if remaining <= 0.0:
			changed = true
			continue
		timed_effect["remaining_seconds"] = remaining
		retained.append(timed_effect)
		changed = true
	run_state.temporary_buffs["infusion_effects"] = retained
	_rebuild_combo_state_from_effects(retained)
	if (
		retained.is_empty()
		and int(run_state.temporary_buffs.get("combo_chain_count", 0)) <= 0
	):
		_last_combo_name = "—"
	return changed


func _consume_combo_attack_charges() -> void:
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not effects_variant is Array:
		return
	var retained: Array = []
	for effect_variant in effects_variant:
		if not effect_variant is Dictionary:
			continue
		var effect := (effect_variant as Dictionary).duplicate(true)
		if String(effect.get("target_action", "")).strip_edges() == "dash":
			retained.append(effect)
			continue
		if not effect.has("remaining_attacks"):
			retained.append(effect)
			continue
		var charges := maxi(0, int(effect.get("remaining_attacks", 0)) - 1)
		if charges > 0:
			effect["remaining_attacks"] = charges
			retained.append(effect)
	run_state.temporary_buffs["infusion_effects"] = retained
	_rebuild_combo_state_from_effects(retained)
	_refresh_combo_display()


func _rebuild_combo_state_from_effects(effects: Array) -> void:
	var previous_variant: Variant = run_state.temporary_buffs.get("active_infusions", [])
	var previous: Array = previous_variant if previous_variant is Array else []
	var levels: Dictionary = {}
	for effect_variant in effects:
		if not effect_variant is Dictionary:
			continue
		var infusion_id := String((effect_variant as Dictionary).get("infusion_id", ""))
		if infusion_id.is_empty():
			continue
		levels[infusion_id] = mini(
			_get_combo_stack_cap(),
			int(levels.get(infusion_id, 0)) + 1
		)
	var active: Array = []
	for infusion_id_variant in previous:
		var infusion_id := String(infusion_id_variant)
		if levels.has(infusion_id) and not active.has(infusion_id):
			active.append(infusion_id)
	for infusion_id_variant in levels:
		var infusion_id := String(infusion_id_variant)
		if not active.has(infusion_id):
			active.append(infusion_id)
	run_state.temporary_buffs["active_infusions"] = active
	run_state.temporary_buffs["combo_levels"] = levels
	_refresh_combo_runtime_modifiers()


func _refresh_combo_runtime_modifiers() -> void:
	_combo_runtime_totals = {
		"defense_bonus": 0,
		"move_speed_multiplier": 0.0,
		"ap_regen_bonus": 0.0,
		"ap_max_bonus": 0.0,
	}
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if effects_variant is Array:
		for effect_variant in effects_variant:
			if not effect_variant is Dictionary:
				continue
			var effect := effect_variant as Dictionary
			_combo_runtime_totals["defense_bonus"] = (
				int(_combo_runtime_totals["defense_bonus"])
				+ int(effect.get("defense_bonus", 0))
			)
			_combo_runtime_totals["move_speed_multiplier"] = (
				float(_combo_runtime_totals["move_speed_multiplier"])
				+ float(effect.get("move_speed_multiplier", 0.0))
			)
			_combo_runtime_totals["ap_regen_bonus"] = (
				float(_combo_runtime_totals["ap_regen_bonus"])
				+ float(effect.get("ap_regen_bonus", 0.0))
			)
			_combo_runtime_totals["ap_max_bonus"] = (
				float(_combo_runtime_totals["ap_max_bonus"])
				+ float(effect.get("ap_max_bonus", 0.0))
			)
	_combo_runtime_totals["defense_bonus"] = mini(20, int(_combo_runtime_totals["defense_bonus"]))
	_combo_runtime_totals["move_speed_multiplier"] = minf(
		0.75,
		float(_combo_runtime_totals["move_speed_multiplier"])
	)
	_combo_runtime_totals["ap_regen_bonus"] = minf(3.0, float(_combo_runtime_totals["ap_regen_bonus"]))
	_combo_runtime_totals["ap_max_bonus"] = minf(6.0, float(_combo_runtime_totals["ap_max_bonus"]))
	if player != null:
		var base_defense := int(player.get_meta("equipment_defense", player.defense))
		var base_speed := float(player.get_meta("equipment_speed", player.speed))
		player.defense = base_defense + int(_combo_runtime_totals["defense_bonus"])
		player.speed = base_speed * (1.0 + float(_combo_runtime_totals["move_speed_multiplier"]))
	if run_state.active:
		deck_manager.max_energy = run_state.max_energy + float(_combo_runtime_totals["ap_max_bonus"])
		deck_manager.energy = minf(deck_manager.energy, deck_manager.max_energy)
		run_state.energy = deck_manager.energy


func _get_combo_time_remaining() -> float:
	var maximum := 0.0
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if effects_variant is Array:
		for effect_variant in effects_variant:
			if effect_variant is Dictionary:
				maximum = maxf(maximum, float((effect_variant as Dictionary).get("remaining_seconds", 0.0)))
	return maximum


func _apply_combo_infusions_to_card(card: Dictionary) -> Dictionary:
	var infused := card.duplicate(true)
	var effect := (infused.get("effect", {}) as Dictionary).duplicate(true)
	var visual_elements: Array[String] = []
	if _effect_deals_damage(effect):
		visual_elements = _active_attack_elements()
	var equipment_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
	var gift_effects := divine_gift_manager.call("get_global_effects") as Dictionary
	var gift_combo_multiplier := maxf(
		1.0,
		float(gift_effects.get("combo_effect_multiplier", 1.0))
	)
	match String(infused.get("type", "")):
		"attack":
			effect["amount"] = int(effect.get("amount", 0)) + int(equipment_specials.get("card_damage_bonus", 0))
		"defense":
			effect["amount"] = int(effect.get("amount", 0)) + int(equipment_specials.get("card_block_bonus", 0))
		"skill":
			if String(effect.get("kind", "")) == "heal":
				effect["amount"] = int(effect.get("amount", 0)) + int(equipment_specials.get("card_heal_bonus", 0))
	var combo_chain := int(run_state.temporary_buffs.get("combo_chain_count", 0))
	if String(infused.get("type", "")) == "attack":
		var combo_power_tiers := floori(float(combo_chain) / 3.0)
		var combo_power_per_tier := maxi(
			4,
			ceili(float(effect.get("amount", 0)) * 0.35)
		)
		effect["amount"] = (
			int(effect.get("amount", 0))
			+ combo_power_tiers * combo_power_per_tier
		)
		if combo_power_tiers > 0:
			infused["auto_attack_range"] = (
				float(infused.get("auto_attack_range", 220.0))
				+ 45.0 * float(combo_power_tiers)
			)
			infused["attack_size_multiplier"] = (
				float(infused.get("attack_size_multiplier", 1.0))
				* (1.0 + 0.25 * float(combo_power_tiers))
			)
		if combo_chain >= 6:
			effect["lifesteal_ratio"] = float(effect.get("lifesteal_ratio", 0.0)) + 0.05
		if combo_chain >= 9:
			effect["combo_stun"] = maxf(float(effect.get("combo_stun", 0.0)), 0.15)
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not effects_variant is Array:
		effects_variant = []
	var effects := effects_variant as Array
	var has_flame := false
	var has_frost := false
	var visual_stack_count := 0
	var visual_lifesteal := false
	for infusion_variant in effects:
		if not infusion_variant is Dictionary:
			continue
		var infusion := infusion_variant as Dictionary
		var infusion_id := String(infusion.get("infusion_id", ""))
		if String(infusion.get("target_action", "")).strip_edges() == "dash":
			continue
		visual_stack_count += 1
		var target_card_id := String(infusion.get("target_card_id", ""))
		if not target_card_id.is_empty() and String(infused.get("id", "")) != target_card_id:
			continue
		if String(infused.get("type", "")) == "attack":
			effect["amount"] = (
				int(effect.get("amount", 0))
				+ roundi(
					float(infusion.get("damage_bonus", 0))
					* gift_combo_multiplier
				)
			)
			infused["auto_attack_range"] = (
				float(infused.get("auto_attack_range", 220.0))
				+ float(infusion.get("attack_range_bonus", 0.0))
					* gift_combo_multiplier
			)
			infused["auto_attack_interval"] = maxf(
				0.1,
				float(infused.get("auto_attack_interval", DEFAULT_AUTO_ATTACK_INTERVAL))
				* float(infusion.get("attack_interval_multiplier", 1.0))
			)
			infused["projectile_speed_multiplier"] = (
				float(infused.get("projectile_speed_multiplier", 1.0))
				* float(infusion.get("projectile_speed_multiplier", 1.0))
			)
			var size_multiplier := float(infusion.get("attack_size_multiplier", 1.0))
			infused["attack_size_multiplier"] = (
				float(infused.get("attack_size_multiplier", 1.0))
				* size_multiplier
			)
			if effect.has("radius"):
				effect["radius"] = float(effect["radius"]) * size_multiplier
			effect["critical_chance"] = clampf(
				float(effect.get("critical_chance", 0.0))
				+ float(infusion.get("critical_chance", 0.0)),
				0.0,
				1.0
			)
			effect["critical_multiplier"] = maxf(
				float(effect.get("critical_multiplier", 1.5)),
				float(infusion.get("critical_multiplier", 1.5))
			)
			if float(infusion.get("lifesteal_ratio", 0.0)) > 0.0:
				effect["lifesteal_ratio"] = float(effect.get("lifesteal_ratio", 0.0)) + float(infusion["lifesteal_ratio"])
			var projectile_bonus := maxi(
				0,
				roundi(
					float(infusion.get("projectile_bonus", 0))
					* gift_combo_multiplier
				)
			)
			if projectile_bonus > 0:
				effect["projectile_count"] = mini(
					8,
					maxi(1, int(effect.get("projectile_count", 1))) + projectile_bonus
				)
				effect["direction_count"] = int(effect["projectile_count"])
				effect["spread_degrees"] = maxf(
					float(effect.get("spread_degrees", 0.0)),
					float(infusion.get("spread_degrees", 0.0))
				)
		elif String(infused.get("type", "")) == "defense":
			effect["amount"] = int(effect.get("amount", 0)) + int(infusion.get("block_bonus", 0))
		if infusion_id == "flame":
			has_flame = true
			if not visual_elements.has("flame"):
				visual_elements.append("flame")
			effect["burn_damage"] = int(infusion.get("burn_damage", 1))
			effect["burn_duration"] = float(effect.get("burn_duration", 0.0)) + float(infusion.get("burn_duration", 0.0))
		elif infusion_id == "frost":
			has_frost = true
			if not visual_elements.has("frost"):
				visual_elements.append("frost")
			effect["frost_ratio"] = float(infusion.get("frost_ratio", 0.25))
			effect["frost_duration"] = float(effect.get("frost_duration", 0.0)) + float(infusion.get("frost_duration", 0.0))
		elif infusion_id == "venom":
			if not visual_elements.has("venom"):
				visual_elements.append("venom")
			effect["poison_damage"] = int(infusion.get("poison_damage", 1))
			effect["poison_duration"] = (
				float(effect.get("poison_duration", 0.0))
				+ float(infusion.get("poison_duration", 0.0))
			)
		elif infusion_id == "ascendant":
			has_flame = true
			has_frost = true
			for element_id in ["flame", "frost", "storm", "venom"]:
				if not visual_elements.has(element_id):
					visual_elements.append(element_id)
			effect["burn_damage"] = int(infusion.get("burn_damage", 2))
			effect["burn_duration"] = float(infusion.get("burn_duration", 3.0))
			effect["frost_ratio"] = float(infusion.get("frost_ratio", 0.20))
			effect["frost_duration"] = float(infusion.get("frost_duration", 2.0))
			effect["poison_damage"] = int(infusion.get("poison_damage", 2))
			effect["poison_duration"] = float(infusion.get("poison_duration", 3.0))
			effect["combo_stun"] = maxf(
				float(effect.get("combo_stun", 0.0)),
				float(infusion.get("combo_stun", 0.10))
			)
		elif infusion_id == "thermal_shatter":
			has_flame = true
			has_frost = true
			for element_id in ["flame", "frost"]:
				if not visual_elements.has(element_id):
					visual_elements.append(element_id)
			effect["burn_damage"] = int(infusion.get("burn_damage", 1))
			effect["burn_duration"] = float(infusion.get("burn_duration", 0.0))
			effect["frost_ratio"] = float(infusion.get("frost_ratio", 0.25))
			effect["frost_duration"] = float(infusion.get("frost_duration", 0.0))
			effect["combo_stun"] = float(infusion.get("combo_stun", 0.5))
		elif float(infusion.get("combo_stun", 0.0)) > 0.0:
			if not visual_elements.has("storm"):
				visual_elements.append("storm")
			effect["combo_stun"] = maxf(
				float(effect.get("combo_stun", 0.0)),
				float(infusion.get("combo_stun", 0.0))
			)
		if float(infusion.get("lifesteal_ratio", 0.0)) > 0.0:
			visual_lifesteal = true
	if String(infused.get("type", "")) == "attack" and has_flame and has_frost:
		effect["amount"] = int(effect.get("amount", 0)) + 2
		effect["combo_stun"] = 0.25
	if _effect_deals_damage(effect):
		effect["elements"] = visual_elements.duplicate()
		if visual_elements.has("water"):
			var water_profile := element_taxonomy.call(
				"get_effect_profile", "water"
			) as Dictionary
			infused["attack_size_multiplier"] = (
				float(infused.get("attack_size_multiplier", 1.0))
				* float(water_profile.get("sweep_width_multiplier", 1.0))
			)
	if String(infused.get("type", "")) == "attack":
		effect["amount"] = (
			int(effect.get("amount", 0))
			+ maxi(0, int(gift_effects.get("combo_element_bonus", 0)))
				* visual_stack_count
		)
		infused["auto_attack_interval"] = maxf(
			0.1,
			float(infused.get("auto_attack_interval", DEFAULT_AUTO_ATTACK_INTERVAL))
				* maxf(
					0.35,
					1.0 - maxf(0.0, float(gift_effects.get("combo_speed_bonus", 0.0)))
			)
		)
		effect["target_count"] = maxi(
			int(effect.get("target_count", 1)),
			int(effect.get("direction_count", 1))
		)
	infused["combo_visual_profile"] = {
		"stack_count": visual_stack_count,
		"elements": visual_elements,
		"lifesteal": visual_lifesteal or float(effect.get("lifesteal_ratio", 0.0)) > 0.0,
		"direction_count": int(effect.get("direction_count", 1)),
		"spread_degrees": float(effect.get("spread_degrees", 0.0)),
	}
	infused["effect"] = effect
	return infused


func _effect_deals_damage(effect: Dictionary) -> bool:
	var kind := String(effect.get("kind", ""))
	return (
		kind in ["damage", "area_damage", "dash_impact", "damage_aura"]
		or (kind == "area_slow" and int(effect.get("amount", 0)) > 0)
	)


func _active_attack_elements() -> Array[String]:
	var elements: Array[String] = []
	_append_vfx_element(
		elements,
		String(inventory_manager.call("get_equipped_weapon_element"))
	)
	for gift_variant in divine_gift_manager.call("get_inventory") as Array:
		if not gift_variant is Dictionary:
			continue
		var gift := gift_variant as Dictionary
		var gift_elements := gift.get(
			"elements", [gift.get("element", "normal")]
		) as Array
		for element_variant in gift_elements:
			_append_vfx_element(elements, String(element_variant))
	return elements


func _on_player_dash_performed(_start_position: Vector2, _end_position: Vector2) -> void:
	if not run_state.active or player == null or current_map == null:
		return
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not effects_variant is Array:
		return
	var amount := 0
	var pull_strength := 0.0
	var infusion_ids: Array[String] = []
	for infusion_variant in effects_variant:
		if not infusion_variant is Dictionary:
			continue
		var infusion := infusion_variant as Dictionary
		if String(infusion.get("target_action", "")).strip_edges() != "dash":
			continue
		amount += int(infusion.get("damage_bonus", 0))
		amount += int(infusion.get("trail_damage", 0))
		amount += int(infusion.get("return_damage", 0))
		pull_strength = maxf(pull_strength, float(infusion.get("pull_strength", 0.0)))
		var infusion_id := String(infusion.get("infusion_id", "")).strip_edges()
		if not infusion_id.is_empty():
			infusion_ids.append(infusion_id)
	if amount <= 0 and pull_strength <= 0.0:
		return
	var targets := _get_combat_targets().filter(func(target: Variant) -> bool:
		if not target is Node2D or not is_instance_valid(target):
			return false
		return ATTACK_GEOMETRY.directional_sweep_contains(
			_start_position,
			_end_position,
			ATTACK_GEOMETRY.target_center(target as Node2D),
			ATTACK_GEOMETRY.target_radius(target as Node2D),
			80.0
		)
	)
	if targets.is_empty():
		return
	card_effect_runner.cast({
		"id": "intrinsic_dash_combo",
		"name": "Dash Combo",
		"type": "combo",
		"cost": 0,
		"effect": {
			"kind": "dash_impact",
			"amount": amount,
			"radius": _start_position.distance_to(_end_position) + 80.0,
			"pull_strength": pull_strength,
			"infusion_ids": infusion_ids,
		},
	}, player, targets)


func _redraw_current_hand() -> bool:
	if not run_state.active or not ui_stack.is_empty():
		return false
	if not deck_manager.discard_and_redraw_hand():
		return false
	run_state.energy = deck_manager.energy
	_refresh_card_hand()
	return true


func _resolve_combat_vfx_profile(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var card_id := String(card.get("id", ""))
	var special_vfx_id := "storm_charge" if card_id == "storm_charge" else ""
	var named_vfx_id := (
		card_id
		if _ensure_named_skill_vfx_catalog()
			and bool(named_skill_vfx_catalog.call("has_profile", card_id))
		else ""
	)
	var series_vfx_id := _resolve_skill_series_vfx_id(card, named_vfx_id)
	if not series_vfx_id.is_empty():
		named_vfx_id = "series:%s" % series_vfx_id
	var elements: Array[String] = []
	var visual_profile := card.get("combo_visual_profile", {}) as Dictionary
	for element_variant in visual_profile.get("elements", []) as Array:
		_append_vfx_element(elements, String(element_variant))
	for tag_variant in card.get("tags", []) as Array:
		_append_vfx_element(elements, String(tag_variant))
	var effect := card.get("effect", {}) as Dictionary
	var infusion_id := String(effect.get("infusion_id", ""))
	_append_vfx_element(elements, infusion_id)
	if effect.has("burn_duration") or effect.has("burn_damage"):
		_append_vfx_element(elements, "flame")
	if effect.has("frost_duration") or effect.has("frost_ratio"):
		_append_vfx_element(elements, "frost")

	var effect_kind := String(effect.get("kind", ""))
	var card_type := String(card.get("type", ""))
	var primary_element := elements[0] if not elements.is_empty() else ""
	var is_area := effect_kind in ["area_damage", "area_slow", "damage_aura"]
	var is_finisher := bool(visual_profile.get("finisher", false))
	var is_elemental_skill := (
		primary_element in ["fire", "ice"]
		and (card_type in ["skill", "ultimate"] or is_finisher)
		and is_area
	)
	if String(card.get("id", "")) == "inferno_orb":
		is_elemental_skill = true
	var progression := _named_skill_vfx_progression(card)
	var ground_trail_profile := ""
	if is_elemental_skill or is_finisher:
		match primary_element:
			"fire":
				ground_trail_profile = "fire_path"
			"ice":
				ground_trail_profile = "ice_path"
			"poison":
				ground_trail_profile = "poison_pool"
	var blessing_overlays := (
		visual_profile.get("blessing_overlays", []) as Array
	).duplicate(true)
	if blessing_overlays.is_empty() and not series_vfx_id.is_empty():
		blessing_overlays = _build_finisher_blessing_overlays(4)
	return {
		"element": primary_element,
		"elements": elements,
		"slow_motion": card_type in ["skill", "ultimate"] or is_finisher,
		"screen_title": card_type in ["skill", "ultimate"] or is_finisher,
		"attack_aura": (
			card_type == "combo"
			and effect_kind == "infusion"
			and not elements.is_empty()
		),
		"ultimate": is_elemental_skill and named_vfx_id.is_empty(),
		"named_vfx_id": named_vfx_id,
		"series_vfx_id": series_vfx_id,
		"special_vfx_id": special_vfx_id,
		"ground_trail_profile": ground_trail_profile,
		"radius": maxf(96.0, float(effect.get("radius", 180.0))),
		"intensity": clampi(
			1
			+ int(card.get("card_level", card.get("level", 1)))
			+ int(visual_profile.get("stack_count", 0)) / 3,
			1,
			5
		),
		"importance": 1.45 if is_elemental_skill or is_finisher else 0.85,
		"evolution_level": int(progression.get("evolution_level", 1)),
		"buff_stacks": int(progression.get("buff_stacks", 0)),
		"blessing_overlays": blessing_overlays,
	}


func _named_skill_vfx_progression(card: Dictionary) -> Dictionary:
	var configured_skill := _configured_skill_for_legacy_recipe(
		String(card.get("id", ""))
	)
	var evolution_level := clampi(
		int(card.get(
			"tier_rank",
			configured_skill.get(
				"tier_rank",
				card.get("card_level", card.get("level", 1))
			)
		)),
		1,
		3
	)
	var progression_tags: Array = []
	var tags_variant: Variant = card.get("combo_tags", card.get("tags", []))
	if tags_variant is Array:
		progression_tags.append_array(tags_variant as Array)
	for card_id_variant in card.get("sequence", []) as Array:
		var source_id := String(card_id_variant)
		var source_card := card_database.get_card(source_id)
		if source_card.is_empty():
			continue
		var source_tags: Variant = source_card.get(
			"combo_tags",
			source_card.get("tags", [])
		)
		if source_tags is Array:
			progression_tags.append_array(source_tags as Array)
		evolution_level = maxi(
			evolution_level,
			int(_sword_soul_progress(StringName(source_id)).get("level", 0))
		)
	return {
		"evolution_level": clampi(evolution_level, 1, 3),
		"buff_stacks": maxi(0, _combo_stack_for_card({
			"combo_tags": progression_tags,
		})),
	}


func _append_vfx_element(elements: Array[String], candidate: String) -> void:
	var normalized := String(element_taxonomy.call("normalize", candidate))
	if normalized.is_empty():
		return
	if not elements.has(normalized):
		elements.append(normalized)


func _play_combat_vfx(card: Dictionary) -> void:
	if card.is_empty() or player == null:
		return
	var profile := _resolve_combat_vfx_profile(card)
	var element := String(profile.get("element", ""))
	var presentation_element := (
		&"fire" if element == "fire"
		else (&"ice" if element == "ice" else &"neutral")
	)
	var cast_name := String(card.get("name", card.get("id", "Skill")))
	if bool(profile.get("screen_title", false)) and skill_cast_presentation != null:
		skill_cast_presentation.play_cast(
			cast_name,
			presentation_element,
			float(profile.get("importance", 0.85)),
			bool(profile.get("slow_motion", false))
		)
	elif not cast_name.is_empty():
		_show_compact_cast_label(cast_name, presentation_element)
	if String(profile.get("special_vfx_id", "")) == "storm_charge":
		_spawn_storm_charge_vfx(profile)
	elif bool(profile.get("ultimate", false)):
		_spawn_elemental_ultimate(profile)
	elif not String(profile.get("named_vfx_id", "")).is_empty():
		_spawn_named_skill_vfx(
			String(profile.get("named_vfx_id", "")),
			clampf(float(profile.get("intensity", 1)) * 0.24 + 0.84, 0.9, 1.45),
			int(profile.get("evolution_level", 1)),
			int(profile.get("buff_stacks", 0)),
			profile.get("blessing_overlays", []) as Array
		)
	if not String(profile.get("ground_trail_profile", "")).is_empty():
		_spawn_ultimate_ground_trails(profile)


func _show_compact_cast_label(cast_name: String, element: StringName) -> void:
	if current_map == null or not player is Node2D:
		return
	var label := Label.new()
	label.name = "CompactCastLabel"
	label.add_to_group("ComboCastLabels")
	label.text = cast_name
	label.custom_minimum_size = Vector2(180.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = (player as Node2D).global_position + Vector2(-90.0, -104.0)
	label.z_index = 110
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05, 0.95))
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.52, 0.22) if element == &"fire"
		else (Color(0.42, 0.86, 1.0) if element == &"ice" else Color(1.0, 0.9, 0.55))
	)
	current_map.add_child(label)
	var tween := label.create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.30).set_delay(0.30)
	tween.chain().tween_callback(label.queue_free)


func _spawn_elemental_aura(host: Node2D, elements: Array, intensity: int) -> void:
	if elemental_attack_aura_scene == null or elements.is_empty():
		return
	var aura := elemental_attack_aura_scene.instantiate() as Node2D
	if aura == null:
		return
	host.add_child(aura)
	if aura.has_method("set_lifetime"):
		aura.call("set_lifetime", 0.72)
	if aura.has_method("configure"):
		aura.call("configure", elements, clampi(intensity, 1, 5))
	var cleanup := aura.create_tween()
	cleanup.set_ignore_time_scale(true)
	cleanup.tween_interval(1.1)
	cleanup.tween_callback(aura.queue_free)


func _spawn_storm_charge_vfx(profile: Dictionary) -> void:
	if current_map == null or not player is Node2D or storm_charge_vfx_scene == null:
		return
	var effect := storm_charge_vfx_scene.instantiate() as Node2D
	if effect == null:
		return
	current_map.add_child(effect)
	effect.global_position = (player as Node2D).global_position
	if effect.has_method("configure"):
		effect.call("configure", clampi(int(profile.get("evolution_level", 1)), 1, 3))
	if effect.has_method("play"):
		effect.call("play")


func _spawn_elemental_ultimate(profile: Dictionary) -> void:
	if current_map == null or not player is Node2D:
		return
	var element := String(profile.get("element", ""))
	var effect_scene := (
		fire_ultimate_vfx_scene if element == "fire"
		else ice_ultimate_vfx_scene
	)
	if effect_scene == null:
		return
	var effect := effect_scene.instantiate() as Node2D
	if effect == null:
		return
	current_map.add_child(effect)
	effect.global_position = (player as Node2D).global_position
	effect.set("radius", float(profile.get("radius", 180.0)))
	effect.set(
		"intensity",
		(
			clampf(float(profile.get("intensity", 1)) * 0.42, 0.35, 2.5)
			if element == "fire"
			else clampf(float(profile.get("intensity", 1)) * 0.25, 0.1, 1.0)
		)
	)
	if effect.has_method("play"):
		if element == "fire":
			effect.call("play", player)
		else:
			effect.call("play")


func _spawn_ultimate_ground_trails(profile: Dictionary) -> void:
	if (
		current_map == null
		or not player is Node2D
		or elemental_ground_trail_scene == null
	):
		return
	var profile_id := String(profile.get("ground_trail_profile", ""))
	if profile_id.is_empty():
		return
	var direction := Vector2(
		-1.0 if int(player.get("facing_direction")) < 0 else 1.0,
		0.0
	)
	var paths := _build_ultimate_ground_paths(
		String(profile.get("element", "normal")),
		float(profile.get("radius", 180.0)),
		direction
	)
	var trail_intensity := clampf(
		0.78 + float(profile.get("intensity", 1)) * 0.12,
		0.9,
		1.45
	)
	for local_path_variant in paths:
		var local_path := local_path_variant as PackedVector2Array
		if local_path.size() < 2:
			continue
		var trail := elemental_ground_trail_scene.instantiate() as Node2D
		if trail == null:
			continue
		current_map.add_child(trail)
		trail.global_position = (player as Node2D).global_position
		trail.z_index = -2
		if not bool(trail.call(
			"play_path",
			profile_id,
			local_path,
			trail_intensity,
			0.72
		)):
			trail.queue_free()


func _build_ultimate_ground_paths(
	element: String,
	requested_radius: float,
	direction: Vector2
) -> Array[PackedVector2Array]:
	var radius := maxf(96.0, requested_radius)
	var forward := direction.normalized()
	if forward.is_zero_approx():
		forward = Vector2.RIGHT
	var side := forward.orthogonal()
	var paths: Array[PackedVector2Array] = []
	match element:
		"fire":
			paths.append(PackedVector2Array([
				forward * radius * 0.02,
				forward * radius * 0.18 - side * radius * 0.10,
				forward * radius * 0.40 - side * radius * 0.18,
				forward * radius * 0.66 - side * radius * 0.13,
				forward * radius * 0.88 - side * radius * 0.04,
				forward * radius,
			]))
			paths.append(PackedVector2Array([
				forward * radius * 0.04,
				forward * radius * 0.20 + side * radius * 0.09,
				forward * radius * 0.44 + side * radius * 0.17,
				forward * radius * 0.70 + side * radius * 0.12,
				forward * radius * 0.94 + side * radius * 0.03,
			]))
		"ice":
			var fork_origin := forward * radius * 0.38 - side * radius * 0.03
			paths.append(PackedVector2Array([
				Vector2.ZERO,
				forward * radius * 0.22 + side * radius * 0.03,
				fork_origin,
				forward * radius * 0.62 + side * radius * 0.05,
				forward * radius * 0.82 - side * radius * 0.04,
				forward * radius,
			]))
			paths.append(PackedVector2Array([
				fork_origin,
				forward * radius * 0.62 - side * radius * 0.18,
				forward * radius * 0.88 - side * radius * 0.34,
			]))
			paths.append(PackedVector2Array([
				forward * radius * 0.52 + side * radius * 0.02,
				forward * radius * 0.72 + side * radius * 0.19,
				forward * radius * 0.96 + side * radius * 0.38,
			]))
		"poison":
			paths.append(PackedVector2Array([
				Vector2.ZERO,
				forward * radius * 0.24 + side * radius * 0.10,
				forward * radius * 0.48 - side * radius * 0.08,
				forward * radius * 0.72 + side * radius * 0.14,
				forward * radius * 0.94,
			]))
			paths.append(PackedVector2Array([
				forward * radius * 0.18 - side * radius * 0.16,
				forward * radius * 0.44 - side * radius * 0.25,
				forward * radius * 0.72 - side * radius * 0.18,
			]))
	return paths


func _ensure_named_skill_vfx_catalog() -> bool:
	if _named_skill_vfx_catalog_loaded:
		return true
	_named_skill_vfx_catalog_loaded = bool(named_skill_vfx_catalog.call("load_catalog"))
	return _named_skill_vfx_catalog_loaded


func _ensure_skill_series_vfx_catalog() -> bool:
	if _skill_series_vfx_catalog_loaded:
		return true
	_skill_series_vfx_catalog_loaded = bool(skill_series_vfx_catalog.call("load_catalog"))
	return _skill_series_vfx_catalog_loaded


func _resolve_skill_series_vfx_id(card: Dictionary, legacy_profile_id: String = "") -> String:
	if not _ensure_skill_series_vfx_catalog():
		return ""
	for field in ["series_vfx_id", "skill_series_id", "series_id"]:
		var direct_id := String(card.get(field, "")).strip_edges()
		if bool(skill_series_vfx_catalog.call("has_profile", direct_id)):
			return direct_id
	# A legacy Finisher ID can collide with a current formal skill ID. When the
	# caller already identified an old named profile, the configured formal
	# skill must disambiguate that recipe before the stable-ID lookup below.
	if not legacy_profile_id.is_empty():
		var configured_skill := _configured_skill_for_legacy_recipe(legacy_profile_id)
		if not configured_skill.is_empty():
			return String(configured_skill.get(
				"series_vfx_id",
				configured_skill.get("series_id", "")
			))
	var card_id := String(card.get("id", ""))
	var skill := skill_recipe_manager.get_skill(card_id)
	if not skill.is_empty():
		return String(skill.get("series_vfx_id", skill.get("series_id", "")))
	var display_name := String(card.get("name", ""))
	if not display_name.is_empty():
		for skill_variant in skill_recipe_manager.get_all_skills():
			var named_skill := skill_variant as Dictionary
			if String(named_skill.get("name", "")) == display_name:
				return String(named_skill.get("series_vfx_id", named_skill.get("series_id", "")))
	var recipe_id := legacy_profile_id if not legacy_profile_id.is_empty() else card_id
	var configured_skill := _configured_skill_for_legacy_recipe(recipe_id)
	if not configured_skill.is_empty():
		return String(configured_skill.get(
			"series_vfx_id",
			configured_skill.get("series_id", "")
		))
	return String(skill_series_vfx_catalog.call("get_series_for_legacy_recipe", recipe_id))


func _configured_skill_for_legacy_recipe(recipe_id: String) -> Dictionary:
	if recipe_id.is_empty():
		return {}
	var matches: Array[Dictionary] = []
	for skill_id in skill_recipe_manager.get_active_ids():
		var skill := skill_recipe_manager.get_skill(skill_id)
		if String(skill.get("legacy_vfx_id", "")) == recipe_id:
			matches.append(skill)
	if matches.is_empty():
		return {}
	# A formula can only present one series. If a compatibility save contains
	# multiple formal skills for the same legacy recipe, the most recently
	# configured entry wins deterministically.
	return matches[-1].duplicate(true)


func _series_id_from_vfx_profile(profile_id: String) -> String:
	return profile_id.trim_prefix("series:") if profile_id.begins_with("series:") else ""


func _spawn_named_skill_vfx(
	profile_id: String,
	intensity: float = 1.0,
	evolution_level: int = 1,
	buff_stacks: int = 0,
	blessing_overlays: Array = []
) -> void:
	var series_id := _series_id_from_vfx_profile(profile_id)
	var has_series_profile := (
		not series_id.is_empty()
		and _ensure_skill_series_vfx_catalog()
		and bool(skill_series_vfx_catalog.call("has_profile", series_id))
	)
	if (
		profile_id.is_empty()
		or current_map == null
		or not player is Node2D
		or named_skill_vfx_scene == null
		or (
			not has_series_profile
			and (
				not _ensure_named_skill_vfx_catalog()
				or not bool(named_skill_vfx_catalog.call("has_profile", profile_id))
			)
		)
	):
		return
	var effect := named_skill_vfx_scene.instantiate() as Node2D
	if effect == null:
		return
	current_map.add_child(effect)
	effect.set_meta(
		"finisher_blessing_overlays",
		blessing_overlays.duplicate(true)
	)
	effect.global_position = (player as Node2D).global_position
	var direction := int(player.get("facing_direction"))
	if direction == 0:
		direction = 1
	if effect.has_signal("impact"):
		effect.connect("impact", _on_named_skill_vfx_impact)
	if has_series_profile:
		effect.call_deferred(
			"play_series",
			series_id,
			clampi(evolution_level, 1, 3),
			direction,
			false,
			intensity
		)
	else:
		effect.call_deferred(
			"play",
			profile_id,
			direction,
			intensity,
			false,
			clampi(evolution_level, 1, 3),
			maxi(0, buff_stacks)
		)


func _on_named_skill_vfx_impact(
	_profile_id: String,
	shake_strength: float,
	hit_stop: float
) -> void:
	var camera := (
		player.find_child("Camera2D", true, false) as Camera2D
		if player != null
		else null
	)
	var shake_scale := float(meta_state.settings.get("camera_shake", 0.65))
	if camera != null and shake_scale > 0.0 and shake_strength > 0.0:
		var strength := shake_strength * shake_scale
		camera.offset = Vector2(strength, -strength * 0.48)
		var shake_tween := camera.create_tween()
		shake_tween.set_ignore_time_scale(true)
		shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.12)
	if hit_stop <= 0.0:
		return
	_named_skill_hit_stop_generation += 1
	var generation := _named_skill_hit_stop_generation
	var restore_scale := Engine.time_scale
	Engine.time_scale = minf(Engine.time_scale, 0.045)
	await get_tree().create_timer(hit_stop, true, false, true).timeout
	if generation == _named_skill_hit_stop_generation and Engine.time_scale <= 0.046:
		Engine.time_scale = restore_scale


func _on_card_effect_resolved(_card_id: String, result: Dictionary) -> void:
	if _resolving_auto_attack_effect:
		return
	var total := int(result.get("total", 0))
	if total > 0 and current_map != null and player is Node2D:
		var number := Label.new()
		number.text = str(total)
		number.position = (player as Node2D).global_position + Vector2(28, -130)
		number.add_theme_font_size_override("font_size", 24)
		number.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 5)
		current_map.add_child(number)
		var number_tween := number.create_tween()
		number_tween.set_parallel(true)
		number_tween.tween_property(number, "position:y", number.position.y - 42.0, 0.55)
		number_tween.tween_property(number, "modulate:a", 0.0, 0.55)
		number_tween.chain().tween_callback(number.queue_free)
	var camera := player.find_child("Camera2D", true, false) as Camera2D if player != null else null
	if camera != null and float(meta_state.settings.get("camera_shake", 0.65)) > 0.0:
		var strength := 4.0 * float(meta_state.settings.get("camera_shake", 0.65))
		camera.offset = Vector2(strength, -strength * 0.5)
		camera.create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.12)
	if (
		total <= 0
		or (
			skill_cast_presentation != null
			and skill_cast_presentation.is_cast_active()
		)
	):
		return
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.035, true, false, true).timeout
	Engine.time_scale = 0.22 if _tactical_slowdown else 1.0


func _card_for_cast(card_or_instance: Variant) -> Dictionary:
	var instance: CardInstance = card_or_instance as CardInstance if card_or_instance is CardInstance else null
	var card_id := instance.card_id if instance != null else String(card_or_instance)
	var card := card_database.get_card(card_id)
	if card.is_empty():
		return {}
	var growth_locked := (
		bool(card.get("growth_locked", false))
		or (instance != null and instance.is_growth_locked())
	)
	var current_level := (
		CardInstance.MIN_LEVEL
		if growth_locked or deck_manager.is_card_protected(instance if instance != null else card_id)
		else clampi(instance.level if instance != null else CardInstance.MIN_LEVEL, CardInstance.MIN_LEVEL, CardInstance.MAX_LEVEL)
	)
	var effect := (card.get("effect", {}) as Dictionary).duplicate(true)
	var upgrades := card.get("upgrade_effects", []) as Array
	for upgrade_variant in upgrades:
		if not upgrade_variant is Dictionary:
			continue
		var upgrade := upgrade_variant as Dictionary
		if int(upgrade.get("level", 99)) > current_level:
			continue
		var upgraded_effect := upgrade.get("effect", {}) as Dictionary
		for key in upgraded_effect:
			effect[key] = upgraded_effect[key]
		if upgrade.has("mechanic_change"):
			card["mechanic_change"] = upgrade["mechanic_change"]
	card["effect"] = effect
	card["level"] = current_level
	card["card_level"] = current_level
	card["name"] = _localized_text(card, "name")
	card["description"] = _localized_text(card, "description")
	card["growth_locked"] = growth_locked
	card["fixed"] = growth_locked
	if card_id == "energy_surge":
		var energy_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
		effect["amount"] = (
			int(effect.get("amount", 2))
			+ int(town_manager.call("get_building_level", &"memory_library"))
			+ int(energy_specials.get("energy_card_bonus", 0.0))
		)
		card["effect"] = effect
		card["description"] = "消耗 1 AP，回復 %d AP。穩定卡無法升級或融合。" % int(effect["amount"])
	if instance != null:
		card["instance_id"] = instance.instance_id
		card["card_instance"] = instance
	if String(card.get("type", "")) == "combo":
		var equipment_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
		card["cost"] = maxi(
			1,
			int(card.get("cost", 0)) - int(equipment_specials.get("combo_cost_reduction", 0))
		)
	return card


func _has_affordable_card() -> bool:
	for instance in deck_manager.hand_instances:
		if int(_card_for_cast(instance).get("cost", 0)) <= deck_manager.energy:
			return true
	return false


func _advance_card_turn() -> void:
	deck_manager.end_turn()


func _refresh_card_hand() -> void:
	if card_hand_ui == null or card_database.get_all_cards().is_empty():
		return
	var cards: Array[Dictionary] = []
	for instance in deck_manager.hand_instances:
		var card := _card_for_cast(instance)
		card["combo_stack"] = _combo_chain_stack_for_card(card)
		card["combo_stack_cap"] = _get_combo_stack_cap()
		card["fixed"] = (
			deck_manager.fixed_hand_mode
			or bool(card.get("growth_locked", false))
			or deck_manager.is_card_protected(instance)
		)
		cards.append(card)
	card_hand_ui.call("set_cards", cards, deck_manager.energy)
	card_hand_ui.call("set_action_points", deck_manager.energy, deck_manager.max_energy)
	if hud != null and hud.has_method("set_auto_attack"):
		var auto_attack := _get_auto_attack_card()
		hud.call("set_auto_attack", String(auto_attack.get("name", "Auto Attack")))


func _on_player_statuses_changed(statuses: Array) -> void:
	if hud != null and hud.has_method("set_active_statuses"):
		hud.call("set_active_statuses", statuses)


func _refresh_combo_display() -> void:
	if hud == null or not hud.has_method("set_combo_formula"):
		return
	var history := run_state.temporary_buffs.get("combo_formula_history", []) as Array
	var formula: Array[Dictionary] = []
	for card_variant in history.slice(
		maxi(0, history.size() - COMBO_FORMULA_LENGTH)
	):
		if not card_variant is Dictionary:
			continue
		var card := card_variant as Dictionary
		formula.append({
			"name": String(card.get("name", card.get("id", "Combo"))),
			"type": String(card.get("type", "combo")),
		})
	var finisher_queue := run_state.temporary_buffs.get(
		"finisher_queue",
		[]
	) as Array
	var projected_finishers: Array[Dictionary] = []
	var possible_finishers: Array[Dictionary] = []
	var epithet := String(divine_gift_manager.call("get_epithet_prefix"))
	for entry_variant in finisher_queue:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var finisher_name := String(entry.get("name", "Finisher"))
		projected_finishers.append({
			"recipe_id": String(entry.get("id", "")),
			"name": finisher_name,
			"epithet": epithet,
			"display_name": "%s%s" % [epithet, finisher_name],
		})
	if not history.is_empty() and history.size() < COMBO_FORMULA_LENGTH:
		var prefix: Array[String] = []
		for card_variant in history:
			if card_variant is Dictionary:
				prefix.append(String((card_variant as Dictionary).get("id", "")))
		for recipe_variant in combo_finisher_catalog.call("get_possible_recipes", prefix) as Array:
			if not recipe_variant is Dictionary:
				continue
			var recipe := recipe_variant as Dictionary
			if not _is_finisher_recipe_learned(recipe):
				continue
			var finisher_name := String(recipe.get("name", "終結技"))
			possible_finishers.append({
				"recipe_id": String(recipe.get("id", "")),
				"name": finisher_name,
				"epithet": epithet,
				"display_name": "%s%s" % [epithet, finisher_name],
			})
	var gift_inventory := divine_gift_manager.call("get_inventory") as Array
	var primary_gift := divine_gift_manager.call("get_primary_gift") as Dictionary
	var primary_gift_id := String(primary_gift.get("id", ""))
	for gift_variant in gift_inventory:
		if gift_variant is Dictionary:
			(gift_variant as Dictionary)["primary"] = (
				String((gift_variant as Dictionary).get("id", ""))
				== primary_gift_id
			)
	hud.call(
		"set_combo_formula",
		formula,
		run_state.temporary_buffs.get("persistent_combo_stacks", {}) as Dictionary,
		not finisher_queue.is_empty(),
		gift_inventory,
		projected_finishers,
		possible_finishers
	)


func _update_card_hand_visibility() -> void:
	if card_hand_ui == null or current_map == null:
		return
	card_hand_ui.visible = _is_current_expedition_map() and run_state.active


func _set_tactical_slowdown(enabled: bool) -> void:
	_tactical_slowdown = enabled and run_state.active
	Engine.time_scale = 0.22 if _tactical_slowdown else 1.0
	if card_hand_ui != null:
		card_hand_ui.modulate = Color(1.12, 1.08, 0.92, 1.0) if _tactical_slowdown else Color.WHITE


func _show_run_result(victory: bool, summary: Dictionary) -> void:
	var result_ui := open_ui("RunResultUI", run_result_scene, true)
	if result_ui == null:
		return
	result_ui.call("set_result", victory, summary)
	result_ui.connect("return_to_town_requested", _on_result_return_to_town.bind(result_ui), CONNECT_ONE_SHOT)


func _on_result_return_to_town(result_ui: Control) -> void:
	close_ui(result_ui)
	if _current_map_matches(TOWN_SCENE_PATH):
		return
	_pending_player_state.clear()
	player = null
	load_current_map(load(_resolve_main_scene_path(TOWN_SCENE_PATH)) as PackedScene)


func _capture_player_state() -> Dictionary:
	var snapshot: Dictionary = {}
	if player == null:
		return snapshot
	for property_name in [
		"level", "character_class", "experience", "experience_to_next_level",
		"health", "max_health", "mana", "max_mana",
	]:
		var value: Variant = player.get(property_name)
		if value != null:
			snapshot[property_name] = value
	return snapshot


func _apply_transferred_player_state() -> void:
	if player == null or _pending_player_state.is_empty():
		return
	for property_name in _pending_player_state:
		player.set(property_name, _pending_player_state[property_name])
	_pending_player_state.clear()
	_update_hud_player_identity()
	_update_hud_resources()


func _connect_if_present(node: Node, signal_name: StringName, method_name: StringName) -> void:
	if not node.has_signal(signal_name):
		return
	var callable := Callable(self, method_name)
	if not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)


func _connect_with_source_if_present(
	node: Node,
	signal_name: StringName,
	method_name: StringName
) -> void:
	if not node.has_signal(signal_name):
		return
	var callable := Callable(self, method_name).bind(node)
	if not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)


func _open_inventory_from_pause() -> void:
	_open_inventory()


func _toggle_inventory() -> void:
	var existing := get_open_ui("InventoryUI")
	if existing != null:
		close_ui(existing)
	else:
		_open_inventory()


func _open_inventory() -> void:
	var inventory_ui := open_ui("InventoryUI", inventory_scene)
	if inventory_ui == null:
		return
	inventory_ui.call("set_gold", wallet_gold)
	inventory_ui.call("set_items", _inventory_projection())
	inventory_ui.call("set_player_status", _inventory_status_projection())
	inventory_ui.call("set_equipment_entries", _inventory_equipment_projection())
	inventory_ui.call("set_sword_souls", _inventory_sword_soul_projection())
	inventory_ui.call("set_codex_entries", _inventory_compendium_projection())
	_connect_with_source_if_present(inventory_ui, &"equip_requested", &"_on_inventory_equip_requested")
	_connect_with_source_if_present(inventory_ui, &"story_review_requested", &"_on_inventory_story_review_requested")


func _inventory_projection() -> Array[Dictionary]:
	var definitions := {
		"travel_bread": {"name": "旅人麵包", "description": "適合長途跋涉的樸實乾糧。", "category": "items", "stats": "基礎補給品。", "icon_path": JOURNAL_ITEM_ICONS["travel_bread"]},
		"town_map": {"name": "城鎮地圖", "description": "標記城鎮周圍的道路。", "category": "quest", "stats": "關鍵道具・無法消耗。", "icon_path": JOURNAL_ITEM_ICONS["town_map"]},
		"iron_sword": {"name": "鐵劍", "description": "可靠的入門長劍。", "category": "gear", "stats": "攻擊 +8", "icon_path": JOURNAL_ITEM_ICONS["iron_sword"]},
		"guard_boots": {"name": "守衛長靴", "description": "適合長途行走的輕便長靴。", "category": "gear", "stats": "防禦 +2", "icon_path": JOURNAL_ITEM_ICONS["guard_boots"]},
		"soul_edge": {"name": "魂刃", "description": "能與劍魂共鳴的刀刃。", "category": "gear", "stats": "攻擊 +12", "icon_path": JOURNAL_ITEM_ICONS["soul_edge"]},
		"shard_charm": {"name": "碎晶護符", "description": "穩定隨身攜帶的魔法碎晶。", "category": "gear", "stats": "提升魔力穩定性", "icon_path": JOURNAL_ITEM_ICONS["shard_charm"]},
	}
	var projection: Array[Dictionary] = []
	for item_id in player_inventory.keys():
		var count := int(player_inventory[item_id])
		if count <= 0:
			continue
		var fallback := {"name": String(item_id).capitalize(), "description": "", "category": "items", "stats": ""}
		var item := (definitions.get(String(item_id), fallback) as Dictionary).duplicate(true)
		item["id"] = String(item_id)
		item["quantity"] = count
		projection.append(item)
	var resource_labels := {
		"autumn_wood": ["秋木", "自秋色樹冠下採集的木材。", "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Wood_Planks.png"],
		"stone": ["石材", "用於建造鍛造設施與裝備的堅硬石材。", "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Stone.png"],
		"magic_shard": ["魔法碎晶", "用於高階鍛造的結晶魔力。", "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png"],
		"autumn_core": ["秋之核心", "凝聚森林力量的稀有核心。", "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_07.png"],
	}
	for resource_id in inventory_manager.call("get_resource_ids") as Array:
		var key := String(resource_id)
		if key == "gold":
			continue
		var quantity := int(inventory_manager.call("get_resource_amount", StringName(key)))
		if quantity <= 0:
			continue
		var label_data: Array = resource_labels.get(key, [key.capitalize(), "鍛造素材。", ""])
		projection.append({
			"id": key,
			"name": label_data[0],
			"description": label_data[1],
			"category": "materials",
			"kind_label": "鍛造素材",
			"stats": "品質庫存：%s" % _forge_quality_stack_summary(
				inventory_manager.call(
					"get_resource_quality_counts", StringName(key)
				) as Dictionary
			),
			"quantity": quantity,
			"icon_path": label_data[2],
		})
	for equipment_variant in inventory_manager.call("get_equipment_catalog") as Array:
		var equipment := equipment_variant as Dictionary
		var equipment_id := String(equipment.get("id", ""))
		if equipment_id.is_empty() or not bool(inventory_manager.call("has_equipment", StringName(equipment_id))):
			continue
		var owned := equipment.duplicate(true)
		owned["name"] = _localized_text(equipment, "name")
		owned["description"] = _localized_text(equipment, "description")
		owned["category"] = "gear"
		owned["kind_label"] = _equipment_slot_label(StringName(equipment.get("slot", "")))
		owned["quantity"] = int(inventory_manager.call("get_equipment_count", StringName(equipment_id)))
		owned["stats"] = "鍛造等級 %d / %d\n%s" % [
			int(inventory_manager.call("get_equipment_level", StringName(equipment_id))),
			int(inventory_manager.call("get_max_equipment_level")),
			_equipment_effect_summary(equipment),
		]
		owned["stats"] += "\n品質庫存：%s" % _forge_quality_stack_summary(
			inventory_manager.call(
				"get_equipment_quality_counts", StringName(equipment_id)
			) as Dictionary
		)
		owned["icon_path"] = _journal_equipment_icon(equipment)
		owned["equipped"] = StringName(inventory_manager.call("get_equipped", StringName(equipment.get("slot", "")))) == StringName(equipment_id)
		projection.append(owned)
	return projection


func _on_inventory_equip_requested(item_id: StringName, ui_control: Control) -> void:
	if ui_control == null or not is_instance_valid(ui_control):
		return
	if not bool(inventory_manager.call("equip", item_id)):
		return
	_apply_equipment_stats()
	_sync_progression_to_meta()
	save_service.save_meta(_meta_save_path(), meta_state.to_dict())
	ui_control.call("set_items", _inventory_projection())
	ui_control.call("set_player_status", _inventory_status_projection())
	ui_control.call("set_equipment_entries", _inventory_equipment_projection())
	ui_control.call("set_codex_entries", _inventory_compendium_projection())


func _inventory_status_projection() -> Dictionary:
	if player == null:
		return {
			"level": 1,
			"character_class": "Adventurer",
			"experience": 0,
			"experience_required": 1,
			"health": 0,
			"max_health": 0,
			"mana": 0,
			"max_mana": 0,
			"attack": 0,
			"defense": 0,
			"speed": 0.0,
		}
	return {
		"level": run_state.level if run_state.active else int(player.get("level")),
		"character_class": String(player.get("character_class")),
		"experience": run_state.experience if run_state.active else int(player.get("experience")),
		"experience_required": run_state.experience_required if run_state.active else int(player.get("experience_to_next_level")),
		"health": int(player.get("health")),
		"max_health": int(player.get("max_health")),
		"mana": int(player.get("mana")),
		"max_mana": int(player.get("max_mana")),
		"attack": int(player.get("attack_power")),
		"defense": int(player.get("defense")),
		"speed": float(player.get("speed")),
	}


func _inventory_equipment_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in [&"weapon", &"armor", &"accessory"]:
		var item_id := StringName(inventory_manager.call("get_equipped", slot))
		if item_id.is_empty():
			result.append({
				"slot": String(slot),
				"id": "",
				"name": "未裝備",
				"level": 0,
				"stats": "此欄位目前沒有裝備。",
				"icon_path": JOURNAL_SLOT_ICONS[String(slot)],
			})
			continue
		var item := inventory_manager.call("get_equipment", item_id) as Dictionary
		var equipped_quality := StringName(inventory_manager.call("get_equipped_quality", slot))
		result.append({
			"slot": String(slot),
			"id": String(item_id),
			"name": "%s · %s" % [
				_localized_text(item, "name"),
				_forge_quality_label(equipped_quality),
			],
			"quality": String(equipped_quality),
			"quality_label": _forge_quality_label(equipped_quality),
			"level": int(inventory_manager.call("get_equipment_level", item_id)),
			"stats": _equipment_effect_summary(item),
			"icon_path": _journal_equipment_icon(item),
		})
	return result


func _inventory_sword_soul_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in meta_state.selected_card_instances:
		if instance == null:
			continue
		var card := card_database.get_card(instance.card_id)
		if card.is_empty():
			continue
		var bonus_type := _sword_soul_bonus_type(card)
		result.append({
			"instance_id": instance.instance_id,
			"card_id": instance.card_id,
			"id": instance.instance_id,
			"name": _localized_text(card, "name"),
			"kind_label": "現有劍魂",
			"bonus_type": String(bonus_type),
			"bonus_type_label": _sword_soul_bonus_type_label(bonus_type),
			"level": instance.level,
			"description": _card_level_description(card, instance.level),
			"effect_summary": _card_effect_summary(card.get("effect", {}) as Dictionary),
			"ability_summary": _sword_soul_ability_summary(card),
			"icon_path": String(card.get("icon_path", JOURNAL_ICON_ROOT + "Icon41_1_2.png")),
		})
	result.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return "%s:%s" % [left.get("name", ""), left.get("instance_id", "")] < "%s:%s" % [right.get("name", ""), right.get("instance_id", "")]
	)
	return result


func _sword_soul_bonus_type(card: Dictionary) -> StringName:
	var effect := card.get("effect", {}) as Dictionary
	var effect_kind := String(effect.get("kind", ""))
	var card_type := String(card.get("type", ""))
	var tags := card.get("tags", []) as Array
	var has_element_tag := false
	for tag_variant in tags:
		if String(tag_variant) in [
			"water", "fire", "wind", "lightning", "ice", "poison", "light", "dark",
		]:
			has_element_tag = true
			break
	if (
		String(effect.get("target_action", "")) == "dash"
		or tags.has("mobility")
		or effect.has("move_speed_multiplier")
	):
		return &"mobility"
	if (
		effect_kind in ["gain_energy", "action_points"]
		or effect.has("ap_regen_bonus")
		or effect.has("ap_max_bonus")
	):
		return &"ap"
	if (
		card_type == "healing"
		or tags.has("healing")
		or effect_kind in ["heal", "healing_pulses", "regeneration"]
	):
		return &"healing"
	if (
		effect_kind == "infusion"
		or has_element_tag
	):
		return &"element"
	if (
		effect_kind == "combat_status"
		or tags.has("defense")
		or effect.has("defense_bonus")
		or not (effect.get("statuses", []) as Array).is_empty()
	):
		return &"defense"
	return &"attack"


func _sword_soul_bonus_type_label(bonus_type: StringName) -> String:
	return {
		&"attack": "攻擊",
		&"defense": "防禦",
		&"healing": "治療",
		&"element": "元素",
		&"mobility": "機動",
		&"ap": "AP",
	}.get(bonus_type, "攻擊")


func _sword_soul_ability_summary(card: Dictionary) -> String:
	var summary := _card_effect_summary(card.get("effect", {}) as Dictionary).strip_edges()
	return summary if not summary.is_empty() else "依劍魂等級提供戰鬥加乘。"


func _inventory_compendium_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for technique_variant in _inventory_codex_projection():
		var technique := technique_variant.duplicate(true)
		technique["section"] = "techniques"
		if String(technique.get("icon_path", "")).is_empty():
			technique["icon_path"] = JOURNAL_ICON_ROOT + "Icon41_1_2.png"
		result.append(technique)
	result.append_array(_inventory_enemy_codex_projection())
	result.append_array(_inventory_sword_soul_codex_projection())
	result.append_array(_inventory_equipment_codex_projection())
	result.append_array(_inventory_blessing_codex_projection())
	result.append_array(story_director.get_review_entries())
	return result


func _inventory_enemy_codex_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog := EnemyArchetype.autumn_catalog()
	var enemy_names := {
		"sprout": "秋芽獸",
		"hopper": "躍葉獸",
		"moth_swarm": "琥珀蛾群",
		"thornling": "棘生靈",
		"charger": "樹皮衝鋒獸",
		"grove_shaman": "林地薩滿",
		"elite": "緋紅林地菁英",
	}
	var behavior_names := {
		"chase": "追擊",
		"leap": "跳躍突襲",
		"ranged": "遠距攻擊",
		"charge": "蓄力衝鋒",
		"elite": "菁英複合行動",
	}
	var pattern_names := {
		"jab": "近身刺擊",
		"leap": "跳躍攻擊",
		"thorn_volley": "荊棘齊射",
		"rush": "直線衝撞",
		"cleave": "橫掃",
		"shockwave": "震波",
	}
	var ids := catalog.keys()
	ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for id_variant in ids:
		var archetype := catalog[id_variant] as EnemyArchetype
		var patterns := PackedStringArray()
		for pattern in archetype.attack_patterns:
			patterns.append(String(pattern_names.get(String(pattern), "特殊攻擊")))
		var archetype_id := String(archetype.archetype_id)
		result.append({
			"section": "enemies",
			"id": archetype_id,
			"name": String(enemy_names.get(archetype_id, "未知敵人")),
			"kind_label": "秋境敵人圖鑑",
			"description": "記錄於秋境的敵人原型；此頁為戰鬥參考資料，不代表發現進度。",
			"effect_summary": "生命 %d · 攻擊 %d · 防禦 %d · 速度 %d" % [archetype.max_health, archetype.attack_damage, archetype.defense, roundi(archetype.speed)],
			"trigger_summary": "行動：%s · 招式：%s" % [String(behavior_names.get(String(archetype.behavior), "特殊行動")), "、".join(patterns)],
			"meta_summary": "攻擊距離 %d · 獎勵 %d 經驗 / %d 金幣" % [roundi(archetype.attack_range), archetype.experience_reward, archetype.gold_reward],
			"icon_path": JOURNAL_ENEMY_ICONS.get(String(archetype.behavior), JOURNAL_ICON_ROOT + "Icon40_1_2.png"),
		})
	return result


func _inventory_sword_soul_codex_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var forge_recipes_by_card_id: Dictionary = {}
	for recipe_variant in forge_catalog.call("get_all_recipes") as Array:
		var recipe := recipe_variant as Dictionary
		if StringName(recipe.get("result_kind", "")) != &"sword_soul":
			continue
		forge_recipes_by_card_id[String(recipe.get("result_id", ""))] = recipe
	for card_variant in card_database.get_all_cards():
		var card := card_variant as Dictionary
		var card_id := StringName(card.get("id", ""))
		var progress := _sword_soul_progress(card_id)
		var unlocked := meta_state.unlocked_cards.has(String(card_id))
		var forge_recipe := forge_recipes_by_card_id.get(String(card_id), {}) as Dictionary
		var acquisition_summary := (
			"取得方式：鍛造圖紙 · 鐵匠鋪等級 %d"
				% int(forge_recipe.get("required_blacksmith_level", 1))
			if not forge_recipe.is_empty()
			else (
				"取得狀態：已解鎖，可在劍魂選擇中使用。"
				if unlocked
				else "取得狀態：尚未解鎖。"
			)
		)
		result.append({
			"section": "sword_souls",
			"id": String(card_id),
			"name": _localized_text(card, "name"),
			"kind_label": "已解鎖劍魂" if unlocked else "未解鎖劍魂",
			"description": _localized_text(card, "description"),
			"effect_summary": _card_effect_summary(card.get("effect", {}) as Dictionary),
			"trigger_summary": acquisition_summary,
			"meta_summary": "解鎖 %s · 持有 %s · 等級 %d / 3" % [
				"是" if unlocked else "否",
				"是" if bool(progress.get("owned", false)) else "否",
				int(progress.get("level", 0)),
			],
			"icon_path": String(card.get("icon_path", JOURNAL_ICON_ROOT + "Icon41_1_2.png")),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("name", "")) < String(right.get("name", "")))
	return result


func _inventory_equipment_codex_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_variant in inventory_manager.call("get_equipment_catalog") as Array:
		var item := item_variant as Dictionary
		var item_id := StringName(item.get("id", ""))
		var slot := StringName(item.get("slot", ""))
		var owned := bool(inventory_manager.call("has_equipment", item_id))
		var equipped := StringName(inventory_manager.call("get_equipped", slot)) == item_id
		result.append({
			"section": "equipment",
			"id": String(item_id),
			"name": _localized_text(item, "name"),
			"kind_label": _equipment_slot_label(slot),
			"description": "%s\n\n【固有能力】%s" % [
				_localized_text(item, "description"),
				_localized_text(item.get("special_ability", {}) as Dictionary, "description"),
			],
			"effect_summary": _equipment_effect_summary(item),
			"trigger_summary": "永久裝備圖鑑 · 正式上限 Lv.%d · 現行效果實作至 Lv.%d" % [
				int(inventory_manager.call("get_max_equipment_level")),
				int(inventory_manager.call("get_implemented_effect_level_cap", item_id)),
			],
			"meta_summary": "持有 %s  ·  裝備中 %s  ·  等級 %d / %d" % [
				"是" if owned else "否",
				"是" if equipped else "否",
				int(inventory_manager.call("get_equipment_level", item_id)),
				int(inventory_manager.call("get_max_equipment_level")),
			],
			"icon_path": _journal_equipment_icon(item),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return "%s:%s" % [left.get("kind_label", ""), left.get("name", "")] < "%s:%s" % [right.get("kind_label", ""), right.get("name", "")])
	return result


func _inventory_blessing_codex_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var base_catalog := divine_gift_manager.call("get_catalog_gifts") as Array
	var fusion_catalog := divine_gift_manager.call("get_fusion_catalog") as Array
	var inventory := divine_gift_manager.call("get_inventory") as Array
	var ascended_ids := divine_gift_manager.call("get_ascended_base_ids") as Array
	var owned_base_by_id: Dictionary = {}
	for owned_variant in inventory:
		var owned := owned_variant as Dictionary
		if String(owned.get("kind", "base")) == "base":
			owned_base_by_id[String(owned.get("id", ""))] = owned

	for gift_variant in base_catalog:
		var gift := gift_variant as Dictionary
		var gift_id := String(gift.get("id", ""))
		var owned := owned_base_by_id.get(gift_id, {}) as Dictionary
		var routes := PackedStringArray()
		for fusion_variant in fusion_catalog:
			var fusion := fusion_variant as Dictionary
			var left_id := String(fusion.get("left", ""))
			var right_id := String(fusion.get("right", ""))
			if gift_id != left_id and gift_id != right_id:
				continue
			var partner_name := String(
				fusion.get("right_name" if gift_id == left_id else "left_name", "另一神賜")
			)
			var route := "「%s」→ %s" % [partner_name, String(fusion.get("name", "神賜昇華"))]
			var equipment_name := String(fusion.get("required_equipment_name", "")).strip_edges()
			if not equipment_name.is_empty():
				route += "（需裝備%s）" % equipment_name
			routes.append(route)
		var level_lines := PackedStringArray()
		var effects_by_level := gift.get("effects_by_level", []) as Array
		for level_index in effects_by_level.size():
			level_lines.append("Lv.%d　%s" % [
				level_index + 1,
				_blessing_effect_dictionary_summary(effects_by_level[level_index] as Dictionary),
			])
		var status_text := _blessing_status_name(
			gift.get("basic_attack_statuses", []) as Array
		)
		var ownership := "未持有"
		if not owned.is_empty():
			ownership = "本 Run 持有 Lv.%d / 3" % int(owned.get("level", 1))
		elif ascended_ids.has(gift_id):
			ownership = "本 Run 已用於昇華"
		result.append({
			"section": "blessings",
			"id": "blessing:%s" % gift_id,
			"catalog_kind": "blessing_base",
			"name": String(gift.get("name", gift_id)),
			"kind_label": "基本神賜 · %s" % _element_display_name(String(gift.get("element", "normal"))),
			"description": String(gift.get("description", "尚無說明。")),
			"effect_summary": "普通攻擊質變：%s\n滿級能力：%s" % [
				status_text,
				_blessing_effect_dictionary_summary(
					effects_by_level.back() as Dictionary if not effects_by_level.is_empty() else {}
				),
			],
			"trigger_summary": "指定融合路線\n%s" % "\n".join(routes),
			"meta_summary": "%s · 三級上限" % ownership,
			"growth_summary": "普通攻擊：%s\n等級成長\n%s" % [
				status_text,
				"\n".join(level_lines),
			],
			"icon_path": String(gift.get("attack_vfx_asset_path", "")),
		})

	for fusion_variant in fusion_catalog:
		var fusion := fusion_variant as Dictionary
		var left_id := String(fusion.get("left", ""))
		var right_id := String(fusion.get("right", ""))
		var owned_evolved := _owned_evolved_blessing(inventory, left_id, right_id)
		var background_attack := fusion.get("background_attack", {}) as Dictionary
		var element_labels := PackedStringArray()
		for element_variant in fusion.get("elements", []) as Array:
			element_labels.append(_element_display_name(String(element_variant)))
		var equipment_name := String(fusion.get("required_equipment_name", "")).strip_edges()
		var requirement := "無裝備門檻" if equipment_name.is_empty() else "另需裝備：%s" % equipment_name
		var ownership := (
			"本 Run 持有 Lv.%d / 3" % int(owned_evolved.get("level", 1))
			if not owned_evolved.is_empty()
			else "尚未於本 Run 完成"
		)
		result.append({
			"section": "blessings",
			"id": "blessing_evolved:%s" % String(fusion.get("id", "")),
			"catalog_kind": "blessing_evolved",
			"name": String(fusion.get("name", "神賜昇華")),
			"kind_label": "進化神賜 · %s" % "＋".join(element_labels),
			"description": "融合「%s」與「%s」，保留雙方普通攻擊狀態，並取得專屬背景自動攻擊。" % [
				String(fusion.get("left_name", left_id)),
				String(fusion.get("right_name", right_id)),
			],
			"effect_summary": "專屬背景自動攻擊：%s\n普通攻擊質變：%s" % [
				String(background_attack.get("name", fusion.get("attack_suffix", "專屬攻擊"))),
				_blessing_status_name(fusion.get("basic_attack_statuses", []) as Array),
			],
			"trigger_summary": "融合配方：%s Lv.3 ＋ %s Lv.3\n%s" % [
				String(fusion.get("left_name", left_id)),
				String(fusion.get("right_name", right_id)),
				requirement,
			],
			"meta_summary": "%s · %s 秒自動施放 · 三級上限" % [
				ownership,
				"%.1f" % float(background_attack.get("interval", 0.0)),
			],
			"growth_summary": "背景自動攻擊：%s\n普通攻擊：%s\nLv.1　啟動雙源主體\nLv.2　提高繼承效果與攻擊壓力\nLv.3　完成超越並擴大毀滅規模" % [
				String(background_attack.get("name", fusion.get("attack_suffix", "專屬攻擊"))),
				_blessing_status_name(fusion.get("basic_attack_statuses", []) as Array),
			],
			"icon_path": String(fusion.get("subject_asset_path", "")),
		})
	return result


func _owned_evolved_blessing(inventory: Array, left_id: String, right_id: String) -> Dictionary:
	for owned_variant in inventory:
		var owned := owned_variant as Dictionary
		var components := owned.get("components", []) as Array
		if (
			String(owned.get("kind", "")) == "evolved"
			and components.size() == 2
			and components.has(left_id)
			and components.has(right_id)
		):
			return owned
	return {}


func _blessing_status_name(statuses: Array) -> String:
	var names := PackedStringArray()
	for status_variant in statuses:
		var status := status_variant as Dictionary
		var status_name := String(status.get("name", "元素附著")).strip_edges()
		if not status_name.is_empty() and not names.has(status_name):
			names.append(status_name)
	return "＋".join(names) if not names.is_empty() else "繼承神賜元素狀態"


func _blessing_effect_dictionary_summary(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	var labels := {
		"combo_stack_bonus": "連段疊層",
		"combo_effect_multiplier": "連段效果",
		"combo_ap_refund": "連段 AP 返還",
		"combo_element_bonus": "連段元素加值",
		"combo_speed_bonus": "連段速度",
		"combo_stack_cap_bonus": "連段上限",
		"finisher_damage_multiplier": "終結技傷害",
		"finisher_heal": "終結技回復",
		"finisher_element_damage": "終結技元素傷害",
		"finisher_size_multiplier": "終結技範圍",
		"finisher_history_bonus": "額外公式段數",
	}
	for key_variant in labels:
		var key := String(key_variant)
		if not effects.has(key):
			continue
		var value: Variant = effects[key]
		var formatted := "%+d" % int(value)
		if key.ends_with("_multiplier"):
			formatted = "%+d%%" % roundi((float(value) - 1.0) * 100.0)
		elif key == "combo_speed_bonus":
			formatted = "%+d%%" % roundi(float(value) * 100.0)
		elif key == "combo_ap_refund":
			formatted = "+%.2f" % float(value)
		parts.append("%s %s" % [String(labels[key]), formatted])
	return " · ".join(parts) if not parts.is_empty() else "強化普通攻擊、招式與背景攻擊"


func _journal_equipment_icon(item: Dictionary) -> String:
	var icon_path := String(item.get("icon_path", "")).strip_edges()
	if not icon_path.is_empty():
		return icon_path
	var item_id := String(item.get("id", ""))
	if JOURNAL_ITEM_ICONS.has(item_id):
		return String(JOURNAL_ITEM_ICONS[item_id])
	return String(JOURNAL_SLOT_ICONS.get(String(item.get("slot", "accessory")), JOURNAL_SLOT_ICONS["accessory"]))


func _equipment_effect_summary(item: Dictionary) -> String:
	var labels := {
		"attack": "攻擊",
		"defense": "防禦",
		"magic_power": "魔力",
		"max_health": "生命上限",
		"max_mana": "法力上限",
		"critical_chance": "暴擊率",
		"move_speed_multiplier": "移動速度",
		"shop_discount": "商店折扣",
	}
	var parts := PackedStringArray()
	var effects := item.get("effects", {}) as Dictionary
	for key in [
		"attack", "defense", "magic_power", "max_health", "max_mana",
		"critical_chance", "move_speed_multiplier", "shop_discount",
	]:
		if not effects.has(key):
			continue
		var value := float(effects[key])
		parts.append(
			"%s %s" % [
				labels[key],
				(
					"%+.0f%%" % (value * 100.0)
					if key in ["critical_chance", "move_speed_multiplier", "shop_discount"]
					else "%+d" % int(value)
				),
			]
			)
	if StringName(item.get("slot", "")) == &"weapon":
		var primal_element := String(item.get("primal_element", "normal"))
		var element_summary := String(element_taxonomy.call(
			"get_effect_summary", primal_element
		))
		parts.append("%s屬性 · %s" % [
			_element_display_name(primal_element),
			element_summary,
		])
	return " · ".join(parts) if not parts.is_empty() else "沒有面板屬性修正"


func _inventory_codex_projection() -> Array[Dictionary]:
	var projection: Array[Dictionary] = []
	var series_ranks: Dictionary = {}
	var ordered_series := skill_recipe_manager.get_all_series()
	for series_index in ordered_series.size():
		var series_entry := ordered_series[series_index] as Dictionary
		series_ranks[String(series_entry.get("id", ""))] = series_index
	for skill_variant in skill_recipe_manager.get_all_skills():
		var skill := skill_variant as Dictionary
		var tier_rank := clampi(int(skill.get("tier_rank", 1)), 1, 3)
		var tier_id := String(skill.get("tier", "basic"))
		var tier_label := skill_recipe_manager.get_tier_label(tier_id)
		var series_name := String(skill.get("series_name", "未分類"))
		var elements := (skill.get("combat_elements", []) as Array).duplicate()
		var legacy_vfx_id := String(skill.get("legacy_vfx_id", ""))
		var combo_recipe := combo_finisher_catalog.call("get_recipe", legacy_vfx_id) as Dictionary
		var series_id := String(skill.get("series_id", ""))
		var series_vfx_id := String(skill.get("series_vfx_id", series_id))
		var series_profile_id := "series:%s" % series_vfx_id
		projection.append({
			"id": String(skill.get("id", "")),
			"name": String(skill.get("name", "未知招式")),
			"catalog_kind": "skill_series",
			"category": "skills",
			"skill_series_id": series_id,
			"skill_series_name": series_name,
			"skill_series_rank": int(series_ranks.get(series_id, 999)),
			"tier": tier_id,
			"tier_label": tier_label,
			"tier_rank": tier_rank,
			"kind_label": "%s系列 · %s招式" % [series_name, tier_label],
			"description": "玩法：%s\n\n%s" % [String(skill.get("gameplay_summary", "")), String(skill.get("description", ""))],
			"recipe_summary": _inventory_skill_recipe_summary(combo_recipe),
			"icon_path": (
				String(skill.get("icon_path", ""))
				if not String(skill.get("icon_path", "")).is_empty()
				else JOURNAL_ICON_ROOT + "Icon41_1_2.png"
			),
			"preview_kind": "finisher",
			"series_vfx_id": series_vfx_id,
			"named_vfx_id": series_profile_id,
			"combat_vfx_id": series_profile_id,
			"legacy_vfx": false,
			"element": String(elements[0]) if not elements.is_empty() else "normal",
			"elements": elements,
			"intensity": [2, 3, 5][tier_rank - 1],
			"attack_size_multiplier": [1.0, 1.25, 1.6][tier_rank - 1],
			"stack_count": (tier_rank - 1) * 3,
			"level": tier_rank,
			"combo_stack": (tier_rank - 1) * 3,
		})
	return projection


func _inventory_skill_recipe_summary(recipe: Dictionary) -> String:
	var names: Array[String] = []
	for card_id_variant in recipe.get("sequence", []) as Array:
		var card_id := String(card_id_variant)
		var card := card_database.get_card(card_id)
		if card.is_empty():
			continue
		names.append(_localized_text(card, "name"))
	return " → ".join(names) if not names.is_empty() else "尚未設定"


func _inventory_legacy_codex_projection() -> Array[Dictionary]:
	var projection: Array[Dictionary] = []
	for card_id in _current_codex_card_ids():
		var card := _current_codex_card(card_id)
		if card.is_empty():
			continue
		var profile := _resolve_combat_vfx_profile(card)
		var progression := _named_skill_vfx_progression(card)
		var effect := card.get("effect", {}) as Dictionary
		var category := _codex_category_for_card(card)
		var preview_kind := _codex_preview_kind_for_card(card, profile)
		var preview_elements: Array = (
			[] if category == "attacks"
			else (profile.get("elements", []) as Array).duplicate()
		)
		var element := (
			"" if category == "attacks"
			else String(profile.get("element", ""))
		)
		var named_vfx_id := String(profile.get("named_vfx_id", ""))
		var special_vfx_id := String(profile.get("special_vfx_id", ""))
		projection.append({
			"id": card_id,
			"name": _localized_text(card, "name"),
			"category": category,
			"kind_label": "目前配置 · %s" % _codex_kind_label_for_card(card, profile),
			"description": _localized_text(card, "description"),
			"effect_summary": (
				"%s、攻擊範圍 %d" % [
					_card_effect_summary(effect),
					int(card.get("auto_attack_range", 220)),
				]
				if category == "attacks"
				else _card_effect_summary(effect)
			),
			"trigger_summary": _codex_trigger_summary_for_card(card),
			"icon_path": String(card.get("icon_path", "")),
			"preview_kind": preview_kind,
			"named_vfx_id": named_vfx_id,
			"special_vfx_id": special_vfx_id,
			"combat_vfx_id": (
				special_vfx_id
				if not special_vfx_id.is_empty()
				else (named_vfx_id if not named_vfx_id.is_empty() else preview_kind)
			),
			"visual_family": _codex_visual_family_for_card(card),
			"element": element,
			"elements": preview_elements,
			"intensity": int(profile.get("intensity", 2)),
			"radius": float(profile.get("radius", 180.0)),
			"direction_count": 1 + maxi(0, int(effect.get("projectile_bonus", 0))),
			"spread_degrees": float(effect.get("spread_degrees", 0.0)),
			"stack_count": maxi(0, int(effect.get("projectile_bonus", 0))),
			"level": int(progression.get("evolution_level", 1)),
			"combo_stack": int(progression.get("buff_stacks", 0)),
		})
	for skill_id in meta_state.active_skill_ids:
		var recipe := skill_recipe_manager.get_recipe(skill_id)
		if recipe.is_empty():
			continue
		var progression := _named_skill_vfx_progression(recipe)
		var skill_entry := {
			"id": skill_id,
			"name": _localized_text(recipe, "name"),
			"category": "skills",
			"kind_label": "已學會戰鬥招式",
			"description": _skill_recipe_description(recipe),
			"effect_summary": _card_effect_summary(recipe.get("effect", {}) as Dictionary),
			"trigger_summary": _skill_trigger_summary(recipe),
			"icon_path": String(recipe.get("icon_path", "")),
			"preview_kind": "passive_skill",
			"named_vfx_id": skill_id,
			"visual_family": _codex_visual_family_for_effect(
				recipe.get("effect", {}) as Dictionary,
				"passive"
			),
			"level": int(progression.get("evolution_level", 1)),
			"combo_stack": int(progression.get("buff_stacks", 0)),
		}
		skill_entry.merge(_named_skill_codex_metadata(skill_id), true)
		projection.append(skill_entry)
	for recipe_variant in combo_finisher_catalog.call("get_all_recipes") as Array:
		var recipe := recipe_variant as Dictionary
		var elements: Array[String] = []
		var icon_path := String(recipe.get("icon_path", ""))
		var sequence_names: Array[String] = []
		for card_id_variant in recipe.get("sequence", []) as Array:
			var card := card_database.get_card(String(card_id_variant))
			if card.is_empty():
				continue
			if icon_path.is_empty():
				icon_path = String(card.get("icon_path", ""))
			sequence_names.append(_localized_text(card, "name"))
			for tag_variant in card.get("tags", []) as Array:
				_append_vfx_element(elements, String(tag_variant))
		var base_effect := recipe.get("base_effect", {}) as Dictionary
		var finisher_effect_summary := _card_effect_summary(base_effect)
		if finisher_effect_summary.strip_edges().is_empty():
			finisher_effect_summary = "效果會讀取三張配方卡的目前等級、裝備與祝福後動態推導。"
		var progression := _named_skill_vfx_progression(recipe)
		var finisher_id := String(recipe.get("id", ""))
		var finisher_entry := {
			"id": finisher_id,
			"name": String(recipe.get("name", "終結技")),
			"category": "finishers",
			"kind_label": "具名終結技",
			"description": String(recipe.get("description", "")),
			"effect_summary": finisher_effect_summary,
			"trigger_summary": "配方：%s" % " → ".join(sequence_names),
			"icon_path": icon_path,
			"preview_kind": "finisher",
			"named_vfx_id": finisher_id,
			"elements": elements,
			"intensity": 5,
			"attack_size_multiplier": float(base_effect.get("size_multiplier", 1.8)),
			"stack_count": maxi(3, int(base_effect.get("projectile_bonus", 0))),
			"level": int(progression.get("evolution_level", 1)),
			"combo_stack": int(progression.get("buff_stacks", 0)),
		}
		finisher_entry.merge(_named_skill_codex_metadata(finisher_id), true)
		projection.append(finisher_entry)
	projection.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_key := "%s:%s" % [left.get("category", ""), left.get("name", "")]
			var right_key := "%s:%s" % [right.get("category", ""), right.get("name", "")]
			return left_key < right_key
	)
	return projection


func _current_codex_card_ids() -> Array[String]:
	var result: Array[String] = []
	var auto_attack_id := (
		_run_auto_attack_card_id
		if run_state.active
		else _resolve_auto_attack_card_id(meta_state.auto_attack_card_id)
	)
	if not auto_attack_id.is_empty():
		result.append(auto_attack_id)
	for card_id_variant in meta_state.selected_deck:
		var card_id := String(card_id_variant)
		if card_id.is_empty() or result.has(card_id):
			continue
		var card := card_database.get_card(card_id)
		if not _is_combat_hand_card(card):
			continue
		result.append(card_id)
	return result


func _current_codex_card(card_id: String) -> Dictionary:
	for instance in meta_state.selected_card_instances:
		if instance.card_id == card_id:
			return _card_for_cast(instance)
	return _card_for_cast(card_id)


func _named_skill_codex_metadata(profile_id: String) -> Dictionary:
	if (
		profile_id.is_empty()
		or not _ensure_named_skill_vfx_catalog()
		or not bool(named_skill_vfx_catalog.call("has_profile", profile_id))
	):
		return {}
	var profile := named_skill_vfx_catalog.call("get_profile", profile_id) as Dictionary
	return {
		"element": String(profile.get("element", "normal")),
		"archetype": String(profile.get("archetype", "")),
		"evolution_layers": (profile.get("evolution_layers", []) as Array).duplicate(),
		"stack_milestones": (profile.get("stack_milestones", []) as Array).duplicate(),
		"stack_traits": (profile.get("stack_traits", []) as Array).duplicate(),
	}


func _codex_category_for_card(card: Dictionary) -> String:
	if String(card.get("type", "")) == "attack":
		return "attacks"
	var effect := card.get("effect", {}) as Dictionary
	return "infusions" if String(effect.get("kind", "")) == "infusion" else "skills"


func _codex_preview_kind_for_card(card: Dictionary, profile: Dictionary) -> String:
	if String(profile.get("special_vfx_id", "")) == "storm_charge":
		return "storm_charge"
	var category := _codex_category_for_card(card)
	if category == "attacks":
		return "basic_attack"
	if category == "infusions":
		return "attack_aura"
	if bool(profile.get("ultimate", false)):
		return "ice_ultimate" if String(profile.get("element", "")) == "ice" else "fire_ultimate"
	return "technique"


func _codex_kind_label_for_card(card: Dictionary, profile: Dictionary) -> String:
	var category := _codex_category_for_card(card)
	if category == "attacks":
		return "基礎攻擊"
	var effect := card.get("effect", {}) as Dictionary
	var card_type := String(card.get("type", ""))
	if category == "infusions":
		var element := _element_display_name(String(profile.get("element", "")))
		if String(effect.get("target_action", "")) == "dash":
			return "衝刺附魔"
		return "%s攻擊附魔" % element if not element.is_empty() else "攻擊附魔"
	match card_type:
		"healing":
			return "治療招式"
		"status":
			return "控制招式"
		"power":
			return "強化招式"
		"ultimate":
			return "終極招式"
		"combo":
			return "連段招式"
		"skill":
			return "範圍招式" if float(effect.get("radius", 0.0)) > 0.0 else "戰鬥招式"
	return "戰鬥招式"


func _codex_trigger_summary_for_card(card: Dictionary) -> String:
	var category := _codex_category_for_card(card)
	var effect := card.get("effect", {}) as Dictionary
	if category == "attacks":
		return "偵測到角色前方的敵人時自動發射。"
	if category == "infusions":
		var target_action := "衝刺" if String(effect.get("target_action", "")) == "dash" else "攻擊"
		return "打出後使%s獲得 %.1f 秒附魔。" % [
			target_action,
			float(effect.get("combo_duration", 0.0)),
		]
	var cost := int(card.get("cost", 0))
	return "從戰鬥手牌打出，消耗 %d AP，效果立即生效。" % cost


func _codex_visual_family_for_card(card: Dictionary) -> String:
	var card_type := String(card.get("type", ""))
	var effect := card.get("effect", {}) as Dictionary
	var tags := card.get("tags", []) as Array
	if card_type == "healing" or tags.has("healing"):
		return "healing"
	if tags.has("mobility") or String(effect.get("target_action", "")) == "dash":
		return "mobility"
	if String(effect.get("kind", "")) in ["stun", "area_slow"]:
		return "control"
	if String(effect.get("kind", "")) in ["gain_energy", "action_points"]:
		return "energy"
	if String(effect.get("kind", "")) in ["combat_status", "regeneration"]:
		return "defense"
	if card_type in ["power", "ultimate"] or String(effect.get("kind", "")) in [
		"attack_power",
		"damage_aura",
		"overdrive",
	]:
		return "power"
	return _codex_visual_family_for_effect(effect, "attack")


func _codex_visual_family_for_effect(effect: Dictionary, fallback: String) -> String:
	var effect_kind := String(effect.get("kind", ""))
	if effect_kind in ["heal", "healing_pulses", "regeneration"]:
		return "healing"
	if effect_kind in ["stun", "area_slow"]:
		return "control"
	if effect_kind in ["gain_energy", "action_points"]:
		return "energy"
	if effect_kind == "combat_status":
		return "defense"
	if effect_kind in ["damage_bonus", "attack_power", "damage_aura", "overdrive"]:
		return "power"
	return fallback


func _card_effect_summary(effect: Dictionary) -> String:
	var parts: Array[String] = []
	var effect_kind := String(effect.get("kind", ""))
	if effect.has("amount"):
		var amount_label := "效果"
		if effect_kind in ["heal", "regeneration"]:
			amount_label = "生命"
		elif effect_kind in ["gain_energy", "action_points"]:
			amount_label = "AP"
		elif effect_kind in ["damage", "area_damage", "damage_bonus"]:
			amount_label = "傷害"
		parts.append("%s %d" % [amount_label, int(effect["amount"])])
	if effect.has("heal"):
		parts.append("每次恢復 %d 生命" % int(effect["heal"]))
	if effect.has("pulses"):
		parts.append("生效 %d 次" % int(effect["pulses"]))
	if effect.has("interval"):
		parts.append("間隔 %.1f 秒" % float(effect["interval"]))
	if effect.has("damage_bonus"):
		parts.append("攻擊傷害 +%d" % int(effect["damage_bonus"]))
	if effect.has("radius"):
		parts.append("範圍 %d" % int(effect["radius"]))
	if effect.has("burn_damage"):
		parts.append("燃燒傷害 %d" % int(effect["burn_damage"]))
	if effect.has("frost_ratio"):
		parts.append("緩速 %d%%" % roundi(float(effect["frost_ratio"]) * 100.0))
	if effect.has("duration"):
		parts.append("持續 %.1f 秒" % float(effect["duration"]))
	if effect.has("status_id"):
		parts.append(_status_display_name(String(effect["status_id"])))
	for status_variant in effect.get("statuses", []) as Array:
		var status := status_variant as Dictionary
		var status_parts: Array[String] = [
			_status_display_name(String(status.get("status_id", "status")))
		]
		if status.has("tier"):
			status_parts.append("階級 %d" % int(status["tier"]))
		if status.has("ratio"):
			status_parts.append("%d%%" % roundi(float(status["ratio"]) * 100.0))
		if status.has("amount"):
			status_parts.append("效果 %d" % int(status["amount"]))
		if status.has("duration"):
			status_parts.append("%.1f 秒" % float(status["duration"]))
		parts.append(" ".join(status_parts))
	if effect.has("projectile_bonus"):
		parts.append("劍氣波 +%d" % int(effect["projectile_bonus"]))
	if effect.has("spread_degrees"):
		parts.append("散射角度 %.0f 度" % float(effect["spread_degrees"]))
	if effect.has("combo_stun"):
		parts.append("暈眩 %.2f 秒" % float(effect["combo_stun"]))
	if effect.has("size_multiplier"):
		parts.append("效果尺寸 ×%.2f" % float(effect["size_multiplier"]))
	if effect.has("attack_range_bonus"):
		parts.append("攻擊範圍 +%d" % roundi(float(effect["attack_range_bonus"])))
	if effect.has("attack_interval_multiplier"):
		parts.append(
			"攻擊速度 +%d%%"
				% roundi((1.0 - float(effect["attack_interval_multiplier"])) * 100.0)
		)
	if effect.has("projectile_speed_multiplier"):
		parts.append(
			"彈體速度 +%d%%"
				% roundi((float(effect["projectile_speed_multiplier"]) - 1.0) * 100.0)
		)
	if effect.has("attack_size_multiplier"):
		parts.append(
			"攻擊尺寸 +%d%%"
				% roundi((float(effect["attack_size_multiplier"]) - 1.0) * 100.0)
		)
	if effect.has("defense_bonus"):
		parts.append("防禦 +%d" % int(effect["defense_bonus"]))
	if effect.has("move_speed_multiplier"):
		parts.append("移動速度 +%d%%" % roundi(float(effect["move_speed_multiplier"]) * 100.0))
	if effect.has("ap_regen_bonus"):
		parts.append("AP 回復 +%.2f" % float(effect["ap_regen_bonus"]))
	if effect.has("ap_max_bonus"):
		parts.append("AP 上限 +%.0f" % float(effect["ap_max_bonus"]))
	if effect.has("poison_damage"):
		parts.append("中毒傷害 %d" % int(effect["poison_damage"]))
	if effect.has("poison_duration"):
		parts.append("中毒持續 %.1f 秒" % float(effect["poison_duration"]))
	if effect.has("critical_chance"):
		parts.append("暴擊率 +%d%%" % roundi(float(effect["critical_chance"]) * 100.0))
	if effect.has("critical_multiplier"):
		parts.append("暴擊傷害 ×%.2f" % float(effect["critical_multiplier"]))
	if effect.has("lifesteal_ratio"):
		parts.append("生命竊取 %d%%" % roundi(float(effect["lifesteal_ratio"]) * 100.0))
	if effect.has("combo_duration"):
		parts.append("附魔 %.1f 秒" % float(effect["combo_duration"]))
	return (
		"、".join(parts)
		if not parts.is_empty()
		else _effect_kind_display_name(effect_kind)
	)


func _status_display_name(status_id: String) -> String:
	return {
		"super_armor": "霸體",
		"damage_reduction": "傷害減免",
		"regeneration": "持續恢復",
		"lifesteal": "生命竊取",
		"stun": "暈眩",
		"slow": "緩速",
	}.get(status_id, "特殊狀態")


func _effect_kind_display_name(effect_kind: String) -> String:
	return {
		"damage": "造成傷害",
		"area_damage": "造成範圍傷害",
		"heal": "恢復生命",
		"healing_pulses": "持續恢復生命",
		"regeneration": "持續恢復",
		"gain_energy": "恢復 AP",
		"action_points": "調整 AP",
		"combat_status": "獲得戰鬥狀態",
		"infusion": "獲得附魔",
	}.get(effect_kind, "依招式內容動態計算")


func _element_display_name(element: String) -> String:
	return {
		"water": "水",
		"fire": "火",
		"wind": "風",
		"lightning": "雷",
		"ice": "冰",
		"poison": "毒",
		"light": "光",
		"dark": "暗",
		"normal": "普通",
	}.get(element, "")


func _skill_recipe_description(recipe: Dictionary) -> String:
	return "已學會的招式，佔用 %d 點記憶容量；在戰鬥中完成條件後自動發動。" % int(recipe.get("memory_cost", 0))


func _skill_trigger_summary(recipe: Dictionary) -> String:
	if String(recipe.get("match_mode", "")) == "sequence":
		var names: Array[String] = []
		for card_id in recipe.get("sequence", []) as Array:
			var card := card_database.get_card(String(card_id))
			names.append(_localized_text(card, "name"))
		return "順序：%s；冷卻 %.0f 秒。" % [" → ".join(names), float(recipe.get("cooldown_seconds", 0.0))]
	return "在 %.0f 秒內命中 %d 次；冷卻 %.0f 秒。" % [
		float(recipe.get("window_seconds", 0.0)),
		int(recipe.get("attack_count", 0)),
		float(recipe.get("cooldown_seconds", 0.0)),
	]


func _save_quick_slot(menu: Control) -> void:
	var payload := _build_quick_save_payload()
	var save_directory := ProjectSettings.globalize_path("user://saves")
	var create_error := DirAccess.make_dir_recursive_absolute(save_directory)
	if create_error != OK:
		_set_menu_footer(menu, "Save failed: cannot create save folder.")
		return

	var temp_path := _quick_save_temp_path()
	var save_path := _quick_save_path()
	var backup_path := _quick_save_backup_path()
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		_set_menu_footer(menu, "Save failed: cannot write temporary file.")
		return
	temp_file.store_string(JSON.stringify(payload, "\t"))
	temp_file.flush()
	temp_file = null

	var check_file := FileAccess.open(temp_path, FileAccess.READ)
	if check_file == null or JSON.parse_string(check_file.get_as_text()) == null:
		_remove_file_if_present(temp_path)
		_set_menu_footer(menu, "Save failed: validation error.")
		return

	if FileAccess.file_exists(save_path):
		_copy_file(save_path, backup_path)
		_remove_file_if_present(save_path)

	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(save_path)
	)
	if rename_error != OK:
		_set_menu_footer(menu, "Save failed while replacing quick save.")
		return

	if menu.has_method("set_button_enabled"):
		menu.call("set_button_enabled", "load", true)
	_set_menu_footer(menu, "Game saved.")


func _load_quick_slot(menu: Control) -> void:
	var save_file := FileAccess.open(_quick_save_path(), FileAccess.READ)
	if save_file == null:
		_set_menu_footer(menu, "No quick save found.")
		return
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if not parsed is Dictionary:
		_set_menu_footer(menu, "Load failed: save data is corrupted.")
		return

	var payload := parsed as Dictionary
	var map_path := String(payload.get("map_path", ""))
	var resolved_map_path := _resolve_main_scene_path(map_path)
	if map_path.is_empty() or not ResourceLoader.exists(resolved_map_path):
		_set_menu_footer(menu, "Load failed: saved map is unavailable.")
		return
	var map_scene := load(resolved_map_path) as PackedScene
	if map_scene == null:
		_set_menu_footer(menu, "Load failed: saved map cannot be loaded.")
		return

	close_ui(menu)
	load_current_map(map_scene)
	_apply_quick_save_payload(payload)


func _build_quick_save_payload() -> Dictionary:
	var player_payload: Dictionary = {}
	if player != null:
		if player is Node2D:
			var position := (player as Node2D).global_position
			player_payload["position"] = {"x": position.x, "y": position.y}
		for property_name in [
			"level", "character_class", "experience", "experience_to_next_level",
			"health", "max_health", "mana", "max_mana",
		]:
			var value: Variant = player.get(property_name)
			if value != null:
				player_payload[property_name] = value

	return {
		"schema_version": 1,
		"saved_at": Time.get_datetime_string_from_system(true),
		"map_path": (
			_canonical_map_scene_path(current_map.scene_file_path)
			if current_map != null
			else ""
		),
		"player": player_payload,
		"wallet_gold": wallet_gold,
		"inventory": player_inventory.duplicate(true),
		"merchant_catalogs": _merchant_catalogs.duplicate(true),
	}


func _apply_quick_save_payload(payload: Dictionary) -> bool:
	wallet_gold = maxi(0, int(payload.get("wallet_gold", wallet_gold)))
	inventory_manager.call("set_resource_amount", &"gold", wallet_gold)
	var saved_inventory: Variant = payload.get("inventory", {})
	if saved_inventory is Dictionary:
		player_inventory = (saved_inventory as Dictionary).duplicate(true)
		player_inventory.erase("potion")
		player_inventory.erase("hp_potion")
		player_inventory.erase("mp_potion")
	var saved_catalogs: Variant = payload.get("merchant_catalogs", {})
	if saved_catalogs is Dictionary:
		_merchant_catalogs.clear()
		for shop_key in (saved_catalogs as Dictionary).keys():
			var restored_entries: Array[Dictionary] = []
			var raw_entries: Variant = (saved_catalogs as Dictionary)[shop_key]
			if raw_entries is Array:
				for raw_entry in raw_entries:
					if raw_entry is Dictionary:
						restored_entries.append((raw_entry as Dictionary).duplicate(true))
			_merchant_catalogs[String(shop_key)] = restored_entries
	if hud != null and hud.has_method("set_currency"):
		hud.call("set_currency", wallet_gold)
	if player == null:
		return true
	var raw_player_payload: Variant = payload.get("player", {})
	var player_payload: Dictionary = (
		(raw_player_payload as Dictionary) if raw_player_payload is Dictionary else {}
	)
	for property_name in [
		"level", "character_class", "experience", "experience_to_next_level",
		"health", "max_health", "mana", "max_mana",
	]:
		if player_payload.has(property_name):
			player.set(property_name, player_payload[property_name])
	var raw_position_payload: Variant = player_payload.get("position", {})
	var position_payload: Dictionary = (
		(raw_position_payload as Dictionary) if raw_position_payload is Dictionary else {}
	)
	if player is Node2D and position_payload.has("x") and position_payload.has("y"):
		(player as Node2D).global_position = Vector2(
			float(position_payload["x"]),
			float(position_payload["y"])
		)
	_update_hud_player_identity()
	_update_hud_resources()
	return true


func _set_menu_footer(menu: Control, text: String) -> void:
	if is_instance_valid(menu) and menu.has_method("set_footer_text"):
		menu.call("set_footer_text", text)


func _copy_file(source_path: String, target_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(source.get_buffer(source.get_length()))
	target.flush()
	return true


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _resolve_open_ui(ui: Variant) -> Control:
	if ui is Control:
		return ui if ui_stack.has(ui) else null

	if ui is String or ui is StringName:
		return get_open_ui(String(ui))

	return null


func _update_pause_state() -> void:
	var should_pause := false
	for ui_control in ui_stack:
		if bool(_ui_pause_flags.get(ui_control, false)):
			should_pause = true
			break

	get_tree().paused = should_pause
	_update_player_input_state()


func _update_player_input_state() -> void:
	if player == null or not player.has_method("set_input_enabled"):
		return
	player.call("set_input_enabled", ui_stack.is_empty())


func _close_existing_primary_ui(next_ui_name: String) -> void:
	for ui_control in ui_stack.duplicate():
		var ui_name := String(_ui_names.get(ui_control, ui_control.name))
		if ui_name != next_ui_name:
			close_ui(ui_control)


func _on_ui_self_closed(ui_control: Control) -> void:
	if bool(_closing_ui.get(ui_control, false)):
		return
	close_ui(ui_control)


func _on_interaction_available(interactive: Node, interactor: Node) -> void:
	if interactor != player:
		return
	if not _interaction_candidates.has(interactive):
		_interaction_candidates.append(interactive)
	current_interactive = _nearest_interaction_candidate()
	_update_interaction_prompt()


func _on_interaction_unavailable(interactive: Node, interactor: Node) -> void:
	if interactor != player:
		return
	_interaction_candidates.erase(interactive)
	current_interactive = _nearest_interaction_candidate()
	_update_interaction_prompt()


func _try_interact() -> void:
	current_interactive = _nearest_interaction_candidate()
	if current_interactive == null or not current_interactive.has_method("interact"):
		return
	current_interactive.call("interact", player)


func _nearest_interaction_candidate() -> Node:
	if player == null:
		return null
	var reference_position := _interaction_reference_position(player)
	var nearest: Node
	var nearest_distance := INF
	for candidate in _interaction_candidates:
		if not is_instance_valid(candidate):
			continue
		var distance := reference_position.distance_squared_to(
			_interaction_reference_position(candidate)
		)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _interaction_reference_position(node: Node) -> Vector2:
	for collision_path in [
		"CollisionShape2D",
		"InteractionArea/InteractionCollision",
		"InteractionArea/CollisionShape2D",
	]:
		var collision := node.get_node_or_null(collision_path) as Node2D
		if collision != null:
			return collision.global_position
	return (node as Node2D).global_position if node is Node2D else Vector2.ZERO


func _on_dialogue_requested(npc: Node, dialogue_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return

	var ui_control := open_ui("DialogueUI", dialogue_scene)
	if ui_control == null:
		return

	var raw_display_name: Variant = npc.get("display_name")
	var display_name := String(raw_display_name) if raw_display_name != null else "Town Resident"
	ui_control.call("set_speaker_name", display_name)
	ui_control.call("set_dialogue_text", _dialogue_text_for(dialogue_id, display_name))
	ui_control.call("set_choices", [
		{"text": "Continue"},
		{"text": "Goodbye", "action": "close"},
	])


func _on_building_ui_requested(
	entrance: Node,
	_building_id: StringName,
	ui_route: StringName,
	service_id: StringName,
	interactor: Node
) -> void:
	if interactor != null and interactor != player:
		return
	match ui_route:
		&"town_service":
			_open_town_service_ui(service_id)
		&"shop":
			_on_shop_requested(entrance, service_id, interactor)
		&"deck_builder":
			_open_deck_builder("", &"")
			var deck_ui := get_open_ui("DeckBuilderUI")
			if deck_ui != null:
				deck_ui.call("set_context", service_id)
		&"residence":
			var residence_ui := open_ui("TownResidenceUI", town_residence_scene, true)
			if residence_ui != null:
				residence_ui.call("set_context", service_id)
		_:
			push_warning("Unknown Town building UI route: %s" % ui_route)


func _open_town_service_ui(service_id: StringName) -> void:
	var ui_name := ""
	var ui_scene: PackedScene
	match service_id:
		&"material_yard":
			ui_name = "MaterialYardUI"
			ui_scene = material_yard_scene
		&"player_blacksmith":
			ui_name = "PlayerBlacksmithUI"
			ui_scene = player_blacksmith_scene
		&"town_hall":
			ui_name = "TownHallUI"
			ui_scene = town_hall_scene
		_:
			push_warning("Unknown Town service UI: %s" % service_id)
			return
	var town_ui := open_ui(ui_name, ui_scene, true)
	if town_ui == null:
		return
	town_ui.call("set_context", service_id)
	_refresh_forge_progression()
	if service_id == &"town_hall":
		town_ui.call("set_services", town_manager, inventory_manager)
		_connect_with_source_if_present(
			town_ui,
			&"building_upgraded",
			&"_on_town_building_upgraded"
		)
	else:
		town_ui.call("set_services", town_manager, inventory_manager, forge_service)
	if service_id == &"material_yard":
		town_ui.call("set_offers", _material_store_offer_projection())
		_connect_with_source_if_present(
			town_ui,
			&"purchase_requested",
			&"_on_material_offer_requested"
		)
	if service_id == &"player_blacksmith":
		town_ui.call("set_recipes", _forge_recipe_projection())
		town_ui.call("set_sale_state", _player_sale_projection())
		_connect_with_source_if_present(
			town_ui,
			&"craft_with_method_requested",
			&"_on_blacksmith_craft_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"list_for_sale_with_strategy_requested",
			&"_on_blacksmith_list_for_sale_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"resolve_sale_requested",
			&"_on_blacksmith_resolve_sale_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"cancel_sale_requested",
			&"_on_blacksmith_cancel_sale_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"customer_purchase_check_requested",
			&"_on_market_customer_purchase_check_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"market_fixture_purchase_requested",
			&"_on_market_fixture_purchase_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"upgrade_sword_soul_requested",
			&"_on_blacksmith_upgrade_sword_soul_requested"
		)
		_connect_with_source_if_present(
			town_ui,
			&"workshop_upgraded",
			&"_on_blacksmith_workshop_upgraded"
		)


func _material_store_offer_projection() -> Array[Dictionary]:
	return forge_service.call(
		"get_shop_offers", &"material_store", true
	) as Array[Dictionary]


func _forge_recipe_projection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_variant in forge_service.call("get_available_recipes") as Array:
		var recipe := (recipe_variant as Dictionary).duplicate(true)
		var result_id := StringName(recipe.get("result_id", ""))
		var result_kind := StringName(recipe.get("result_kind", ""))
		var source: Dictionary
		if result_kind == &"equipment":
			source = inventory_manager.call("get_equipment", result_id) as Dictionary
			recipe["kind"] = source.get("slot", "equipment")
			recipe["name"] = source.get("name", result_id)
			recipe["description"] = _equipment_forge_description(source)
			recipe["tier"] = recipe.get("required_blacksmith_level", 1)
			recipe["quality_label"] = source.get("quality_label_zh", "普通")
			recipe["sale_value"] = source.get("base_sale_value", 0)
		else:
			source = card_database.get_card(String(result_id))
			recipe["kind"] = "sword_soul"
			recipe["name"] = source.get("name", result_id)
			recipe["description"] = source.get(
				"description",
				"Forge this Sword Soul from its permanent design."
			)
			recipe["tier"] = recipe.get("required_blacksmith_level", 1)
			recipe["quality_label"] = _forge_quality_label(StringName(recipe.get("quality", "common")))
			var sword_soul_progress := _sword_soul_progress(result_id)
			recipe["owned"] = bool(sword_soul_progress.get("owned", false))
			recipe["level"] = int(sword_soul_progress.get("level", 0))
		recipe["icon_path"] = _forge_blueprint_icon(
			StringName(recipe.get("blueprint_id", ""))
		)
		recipe["unlocked"] = true
		result.append(recipe)
	return result


func _equipment_forge_description(item: Dictionary) -> String:
	var slot := String(item.get("slot", "equipment")).capitalize()
	var effects := item.get("effects", {}) as Dictionary
	if effects.is_empty():
		return "A crafted %s design for the Player Blacksmith workshop." % slot
	var effect_parts: Array[String] = []
	for effect_variant in effects:
		effect_parts.append(
			"%s +%s" % [
				String(effect_variant).replace("_", " ").capitalize(),
				str(effects[effect_variant]),
			]
		)
	return "%s. %s." % [slot, ", ".join(effect_parts)]


func _forge_quality_label(quality: StringName) -> String:
	match quality:
		&"legendary":
			return "傳奇"
		&"rare":
			return "稀有"
		&"exceptional":
			return "罕見"
		_:
			return "普通"


func _forge_quality_stack_summary(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for quality in [&"common", &"rare", &"exceptional", &"legendary"]:
		var count := int(counts.get(String(quality), 0))
		if count > 0:
			parts.append("%s ×%d" % [_forge_quality_label(quality), count])
	return "、".join(parts) if not parts.is_empty() else "無"


func _forge_outcome_summary(counts: Dictionary) -> String:
	var labels := {
		"success": "成品",
		"flawed": "瑕疵品",
		"prototype": "試作品",
		"scrap": "回收廢料",
		"accidental_masterpiece": "意外神作",
	}
	var parts: Array[String] = []
	for outcome_id in ["success", "flawed", "prototype", "scrap", "accidental_masterpiece"]:
		var count := int(counts.get(outcome_id, 0))
		if count > 0:
			parts.append("%s ×%d" % [labels[outcome_id], count])
	return "、".join(parts) if not parts.is_empty() else "火候未形成成品"


func _forge_blueprint_icon(blueprint_id: StringName) -> String:
	for offer_variant in forge_catalog.call("get_all_offers") as Array:
		var offer := offer_variant as Dictionary
		if StringName(offer.get("product_id", "")) == blueprint_id:
			return String(offer.get("icon_path", ""))
	return ""


func _sword_soul_progress(card_id: StringName) -> Dictionary:
	var highest_level := 0
	for instance in meta_state.selected_card_instances:
		if StringName(instance.card_id) == card_id:
			highest_level = maxi(highest_level, int(instance.level))
	return {
		"owned": highest_level > 0,
		"level": highest_level,
	}


func _player_sale_projection() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for candidate_variant in forge_service.call("get_sale_candidates") as Array:
		var candidate := (candidate_variant as Dictionary).duplicate(true)
		var item_kind := StringName(candidate.get("item_kind", ""))
		var item_id := StringName(candidate.get("item_id", ""))
		candidate["item_name"] = (
			_localized_text(
				inventory_manager.call("get_equipment", item_id) as Dictionary,
				"name"
			)
			if item_kind == &"equipment"
			else _forge_material_name(item_id)
		)
		candidate["quality_label"] = _forge_quality_label(
			StringName(candidate.get("quality", "common"))
		)
		candidates.append(candidate)
	var capacity := int(forge_service.call("get_sale_shelf_capacity"))
	var shelves: Array[Dictionary] = []
	for shelf_index in capacity:
		var slot := inventory_manager.call(
			"get_sale_slot", shelf_index
		) as Dictionary
		shelves.append(_project_sale_shelf(slot, shelf_index))
	return {
		"status": "multi_shelf",
		"capacity": capacity,
		"shelves": shelves,
		"candidates": candidates,
		"fixture_state": forge_service.call("get_market_fixture_state") as Dictionary,
		"equipment_sales_unlocked": int(town_manager.call(
			"get_building_level", &"market"
		)) >= 1,
	}


func _project_sale_shelf(slot: Dictionary, shelf_index: int) -> Dictionary:
	if slot.is_empty():
		return {"shelf_index": shelf_index, "status": "empty"}
	var item_id := StringName(slot.get("item_id", ""))
	var item_kind := StringName(slot.get("item_kind", "equipment"))
	var quality := StringName(slot.get("quality", "common"))
	var item_name := (
		_localized_text(
			inventory_manager.call("get_equipment", item_id) as Dictionary,
			"name"
		)
		if item_kind == &"equipment"
		else _forge_material_name(item_id)
	)
	var customer_state := StringName(slot.get("customer_state", "ready"))
	var sale_status := "customer_declined" if customer_state == &"declined" else "customer_ready"
	var strategy_name: String = {
		"quick": "親民定價",
		"fair": "公道定價",
		"luxury": "精品標價",
	}.get(String(slot.get("price_strategy", "fair")), "公道定價")
	return {
		"shelf_index": shelf_index,
		"item_kind": String(item_kind),
		"item_id": String(item_id),
		"item_name": "%s · %s" % [item_name, _forge_quality_label(quality)],
		"quality": String(quality),
		"crafted_count": int(slot.get("quantity", 0)),
		"status": sale_status,
		"table_label": "%s 已以「%s」陳列於販售桌。" % [
			item_name,
			strategy_name,
		],
		"customer_label": (
			"先前顧客沒有購買；商品仍留在架上等待下一位客人。"
			if customer_state == &"declined" else "顧客會自行評估 %d 金幣的售價。" % (
				int(slot.get("quantity", 0)) * int(slot.get("unit_price", 0))
			)
		),
		"rumor_id": slot.get("rumor_id", ""),
		"rumor_title": slot.get("rumor_title", ""),
		"customer_name": slot.get("customer_name", "Town Customer"),
		"rumor_multiplier": slot.get("rumor_multiplier", 1.0),
		"price_strategy": slot.get("price_strategy", "fair"),
		"sale_chance": slot.get("sale_chance", 1.0),
	}


func _forge_material_name(resource_id: StringName) -> String:
	match resource_id:
		&"autumn_wood":
			return "秋木"
		&"stone":
			return "石材"
		&"magic_shard":
			return "魔力碎片"
		&"autumn_core":
			return "秋核"
		_:
			return String(resource_id).replace("_", " ").capitalize()


func _on_material_offer_requested(
	offer_id: StringName,
	quantity: int,
	ui_control: Control
) -> void:
	var result := forge_service.call("purchase_offer", offer_id, quantity) as Dictionary
	var success := bool(result.get("ok", false))
	_persist_forge_progress()
	ui_control.call("set_offers", _material_store_offer_projection())
	ui_control.call(
		"set_transaction_feedback",
		"素材已送達你的工坊。"
		if success else _forge_result_message(StringName(result.get("code", ""))),
		success
	)


func _on_blacksmith_craft_requested(
	recipe_id: StringName,
	method_or_ui: Variant = &"steady",
	quality_or_ui: Variant = &"common",
	ui_control: Control = null
) -> void:
	var method_id: StringName = &"steady"
	var material_quality: StringName = &"common"
	if method_or_ui is Control:
		ui_control = method_or_ui as Control
	else:
		method_id = StringName(method_or_ui)
	if quality_or_ui is Control:
		ui_control = quality_or_ui as Control
	else:
		material_quality = StringName(quality_or_ui)
	var result := forge_service.call(
		"craft", recipe_id, 1, method_id, material_quality
	) as Dictionary
	var success := bool(result.get("ok", false))
	if (
		success
		and int(result.get("quantity", 0)) > 0
		and String(result.get("intent", "")) == "grant_sword_soul"
	):
		for _index in maxi(0, int(result.get("quantity", 0))):
			meta_state.add_card_instance(String(result.get("result_id", "")), 1)
		var card_id := String(result.get("result_id", ""))
		if not meta_state.unlocked_cards.has(card_id):
			meta_state.unlocked_cards.append(card_id)
	var outcome_counts := result.get("outcome_counts", {}) as Dictionary
	var outcome_text := _forge_outcome_summary(outcome_counts)
	result["message"] = (
		(
			"主角完成了圖紙改良：圖紙已覺醒，今後可鍛造出傳奇品質。"
			if bool(result.get("blueprint_awakened_now", false))
			else (
				"鍛造完成：%s。圖紙熟練度已提升。" % outcome_text
				if bool(result.get("proficiency_advanced", int(result.get("quantity", 0)) > 0))
				else "鍛造未形成成品：%s。圖紙熟練度未提升。" % outcome_text
			)
		)
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	_persist_forge_progress()
	if is_instance_valid(ui_control):
		ui_control.call("set_recipes", _forge_recipe_projection())
		ui_control.call("set_sale_state", _player_sale_projection())
		ui_control.call("show_action_result", result)


func _on_blacksmith_list_for_sale_requested(
	item_kind: StringName,
	item_id: StringName,
	quality: StringName,
	strategy_or_ui: Variant = &"fair",
	shelf_or_ui: Variant = -1,
	ui_control: Control = null
) -> void:
	var price_strategy: StringName = &"fair"
	var shelf_index := -1
	if strategy_or_ui is Control:
		ui_control = strategy_or_ui as Control
	else:
		price_strategy = StringName(strategy_or_ui)
	if shelf_or_ui is Control:
		ui_control = shelf_or_ui as Control
	else:
		shelf_index = int(shelf_or_ui)
	var result := forge_service.call(
		"list_for_sale",
		item_kind,
		item_id,
		quality,
		1,
		price_strategy,
		shelf_index
	) as Dictionary
	var success := bool(result.get("ok", false))
	result["message"] = (
		"商品已放上販售桌；符合流言時，特別顧客會以高價來訪。"
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	_persist_forge_progress()
	if is_instance_valid(ui_control):
		ui_control.call("set_sale_state", _player_sale_projection())
		ui_control.call("show_action_result", result)


func _on_blacksmith_resolve_sale_requested(
	shelf_or_ui: Variant = 0,
	ui_control: Control = null
) -> void:
	var shelf_index := 0
	if shelf_or_ui is Control:
		ui_control = shelf_or_ui as Control
	else:
		shelf_index = int(shelf_or_ui)
	var result := forge_service.call("resolve_sale", shelf_index) as Dictionary
	var success := bool(result.get("ok", false))
	result["message"] = (
		"顧客已完成購買。"
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	_persist_forge_progress()
	result["sale_state"] = _player_sale_projection()
	if is_instance_valid(ui_control):
		ui_control.call("show_sale_result", result)
		ui_control.call("set_sale_state", result["sale_state"])


func _on_blacksmith_cancel_sale_requested(
	shelf_or_ui: Variant = 0,
	ui_control: Control = null
) -> void:
	var shelf_index := 0
	if shelf_or_ui is Control:
		ui_control = shelf_or_ui as Control
	else:
		shelf_index = int(shelf_or_ui)
	var result := forge_service.call("cancel_sale", shelf_index) as Dictionary
	var success := bool(result.get("ok", false))
	result["message"] = (
		"商品已撤下，可重新選擇定價。"
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	_persist_forge_progress()
	if is_instance_valid(ui_control):
		ui_control.call("show_sale_result", result)
		ui_control.call("set_sale_state", _player_sale_projection())


func _on_market_customer_purchase_check_requested(
	shelf_or_ui: Variant = 0,
	ui_control: Control = null
) -> void:
	var shelf_index := 0
	if shelf_or_ui is Control:
		ui_control = shelf_or_ui as Control
	else:
		shelf_index = int(shelf_or_ui)
	var result := forge_service.call("try_customer_purchase", shelf_index) as Dictionary
	var success := bool(result.get("ok", false))
	result["message"] = (
		"顧客完成購買，貨架已空出等待補貨。"
		if success else (
			"顧客覺得價格太高，逛了一圈後離開。"
			if StringName(result.get("code", "")) == &"customer_passed"
			else _forge_result_message(StringName(result.get("code", "")))
		)
	)
	if success:
		_persist_forge_progress()
	result["sale_state"] = _player_sale_projection()
	if is_instance_valid(ui_control):
		ui_control.call("set_sale_state", result["sale_state"])
		ui_control.call("show_sale_result", result)


func _on_market_fixture_purchase_requested(
	fixture_id: StringName,
	ui_control: Control
) -> void:
	var result := forge_service.call("purchase_market_fixture", fixture_id) as Dictionary
	var success := bool(result.get("ok", false))
	result["message"] = (
		"新櫃台已安裝，可用交易位置增加。"
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	if success:
		_persist_forge_progress()
	if is_instance_valid(ui_control):
		ui_control.call("set_sale_state", _player_sale_projection())
		ui_control.call("show_action_result", result)


func _on_blacksmith_upgrade_sword_soul_requested(
	card_id: StringName,
	ui_control: Control
) -> void:
	var target_instance: CardInstance
	for instance in meta_state.selected_card_instances:
		if StringName(instance.card_id) != card_id or int(instance.level) >= 3:
			continue
		if target_instance == null or int(instance.level) > int(target_instance.level):
			target_instance = instance
	var success := false
	var code: StringName = &"sword_soul_not_owned"
	if target_instance != null:
		var upgrade_cost := {
			&"gold": 30 * int(target_instance.level),
			&"magic_shard": 3 * int(target_instance.level),
		}
		if inventory_manager.call("spend_resources", upgrade_cost):
			success = meta_state.upgrade_card_instance(target_instance.instance_id)
			code = &"upgraded" if success else &"upgrade_rejected"
			if not success:
				for resource_variant in upgrade_cost:
					inventory_manager.call(
						"add_resource",
						StringName(resource_variant),
						int(upgrade_cost[resource_variant])
					)
		else:
			code = &"insufficient_resources"
	var result := {
		"ok": success,
		"code": String(code),
		"message": (
			"劍魂已提升至等級 %d。" % int(target_instance.level)
			if success else _forge_result_message(code)
		),
	}
	_persist_forge_progress()
	ui_control.call("set_recipes", _forge_recipe_projection())
	ui_control.call("show_action_result", result)


func _on_blacksmith_workshop_upgraded(ui_control: Control) -> void:
	_refresh_forge_progression()
	_persist_forge_progress()
	ui_control.call("set_recipes", _forge_recipe_projection())
	ui_control.call("set_sale_state", _player_sale_projection())


func _on_town_building_upgraded(
	_building_id: StringName,
	_level: int,
	_ui_control: Control
) -> void:
	_refresh_forge_progression()
	_persist_forge_progress()
	_apply_town_visual_progress()


func _persist_forge_progress() -> void:
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	_sync_progression_to_meta()
	save_service.save_meta(_meta_save_path(), meta_state.to_dict())
	if hud != null and hud.has_method("set_currency"):
		hud.call("set_currency", wallet_gold)
	_apply_equipment_stats()


func _sync_progression_to_meta() -> void:
	_refresh_forge_progression()
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	meta_state.inventory_state = inventory_manager.call("to_dict") as Dictionary
	meta_state.town_state = town_manager.call("to_dict") as Dictionary
	meta_state.resources = (
		meta_state.inventory_state.get("resources", {}) as Dictionary
	).duplicate(true)
	meta_state.building_levels = (
		meta_state.town_state.get("building_levels", {}) as Dictionary
	).duplicate(true)
	meta_state.village_level = clampi(int(town_manager.call("get_village_stage")) + 1, 1, 3)


func _refresh_forge_progression() -> void:
	var expedition_unlock_tier := maxi(
		0,
		int(meta_state.shortcuts.get("expedition_power_tier", 1)) - 1
	)
	forge_service.call(
		"set_progression_levels",
		maxi(
			maxi(
				0,
				int(town_manager.call("get_effect_value", &"material_store_tier"))
			),
			expedition_unlock_tier
		),
		int(town_manager.call("get_building_level", &"blacksmith")),
		int(town_manager.call("get_building_level", &"market"))
	)
	forge_service.call(
		"set_economy_modifiers",
		float(town_manager.call("get_effect_value", &"market_purchase_discount")),
		1.0 + float(town_manager.call("get_effect_value", &"market_sale_bonus")),
		float(town_manager.call("get_effect_value", &"forge_processing_fee_discount")),
		1.0 + float(town_manager.call("get_effect_value", &"material_bundle_bonus")),
		float(town_manager.call("get_effect_value", &"forge_quality_bonus")),
		float(town_manager.call("get_effect_value", &"market_customer_interest_bonus"))
			+ float((inventory_manager.call("get_special_ability_totals") as Dictionary).get(
				"market_customer_interest_bonus", 0.0
			))
	)


func _has_legacy_inventory_progress() -> bool:
	for amount in meta_state.resources.values():
		if int(amount) > 0:
			return true
	for item_id in meta_state.equipment.values():
		if not String(item_id).is_empty():
			return true
	return false


func _apply_town_visual_progress() -> void:
	if not _current_map_matches(TOWN_SCENE_PATH):
		return
	var modular_visuals := current_map.get_node_or_null(
		"ParallaxBackground/ModularVisuals"
	)
	if modular_visuals == null:
		return
	var building_by_object_id := {
		"material_yard": &"workshop",
		"player_blacksmith": &"blacksmith",
		"town_hall": &"town_hall",
		"sword_soul_shop": &"memory_library",
		"equipment_blueprint_shop": &"market",
	}
	for child in modular_visuals.get_children():
		_apply_upgrade_visual_to_branch(child, building_by_object_id)
	_apply_equipment_stats()


func _apply_upgrade_visual_to_branch(node: Node, building_by_object_id: Dictionary) -> void:
	if node.has_meta("object_id"):
		var object_id := String(node.get_meta("object_id", ""))
		if building_by_object_id.has(object_id) and node is CanvasItem:
			var building_id := building_by_object_id[object_id] as StringName
			var level := int(town_manager.call("get_building_level", building_id))
			var maximum := maxi(1, int(town_manager.call("get_max_building_level", building_id)))
			var progress := float(level) / float(maximum)
			(node as CanvasItem).self_modulate = Color(
				1.0 + 0.08 * progress,
				1.0 + 0.045 * progress,
				1.0 + 0.015 * progress,
				1.0
			)
			node.set_meta("town_upgrade_building_id", String(building_id))
			node.set_meta("town_upgrade_level", level)
	for child in node.get_children():
		_apply_upgrade_visual_to_branch(child, building_by_object_id)


func _apply_equipment_stats() -> void:
	if player == null:
		return
	var effects := inventory_manager.call("get_effect_totals") as Dictionary
	player.attack_power = 16 + int(effects.get("attack", 0))
	player.defense = 3 + int(effects.get("defense", 0))
	var equipment_health := 100 + int(effects.get("max_health", 0))
	var equipment_mana := 50 + int(effects.get("max_mana", 0))
	player.max_health = maxi(player.max_health, equipment_health) if run_state.active else equipment_health
	player.max_mana = maxi(player.max_mana, equipment_mana) if run_state.active else equipment_mana
	player.speed = 260.0 * (1.0 + float(effects.get("move_speed_multiplier", 0.0)))
	player.set_meta("equipment_defense", player.defense)
	player.set_meta("equipment_speed", player.speed)
	_apply_intrinsic_dash_upgrades()
	_refresh_combo_runtime_modifiers()
	player.health = mini(player.health, player.max_health)
	player.mana = mini(player.mana, player.max_mana)
	_update_hud_resources()


func _on_shop_requested(merchant: Node, shop_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	var ui_control := open_ui("ShopUI", shop_scene)
	if ui_control == null:
		return

	var raw_display_name: Variant = merchant.get("display_name")
	var display_name := String(raw_display_name) if raw_display_name != null else "Merchant"
	ui_control.call("set_merchant_name", display_name)
	if ui_control.has_method("set_shop_context"):
		ui_control.call("set_shop_context", shop_id)
	ui_control.call("set_wallet", wallet_gold)
	if ui_control.has_signal("mode_changed"):
		ui_control.connect("mode_changed", _on_shop_mode_changed.bind(ui_control, shop_id))
	if ui_control.has_signal("confirmed"):
		ui_control.connect("confirmed", _on_shop_transaction_confirmed.bind(ui_control, shop_id))
	if ui_control.has_signal("blueprint_school_change_requested"):
		ui_control.connect(
			"blueprint_school_change_requested",
			_on_blueprint_school_change_requested.bind(ui_control, shop_id)
		)
	_refresh_shop_projection(ui_control, shop_id, "buy")


func _remove_card_instance(instance_id: String) -> bool:
	return bool(card_collection_service.call("remove_instance", instance_id))


func _discover_equipment_reward() -> String:
	for equipment in inventory_manager.call("get_equipment_catalog") as Array:
		var item := equipment as Dictionary
		var item_id := StringName(item.get("id", ""))
		if item_id.is_empty() or bool(inventory_manager.call("has_equipment", item_id)):
			continue
		if bool(inventory_manager.call("add_equipment", item_id)):
			meta_state.inventory_state = inventory_manager.call("to_dict")
			if hud != null and hud.has_method("set_objective"):
				var ability := item.get("special_ability", {}) as Dictionary
				hud.call(
					"set_objective",
					"發現裝備：%s" % _localized_text(item, "name"),
					_localized_text(ability, "description")
				)
			return String(item_id)
	return ""


func _on_portal_entered(_portal: Node, target_scene_path: String, target_spawn_name: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	if not run_state.active and _portal != null:
		var option_variant: Variant = _portal.get_meta("expedition_variant_options", [])
		if option_variant is Array and (option_variant as Array).size() > 1:
			_open_expedition_variant_selector(
				option_variant as Array,
				target_spawn_name
			)
			return
	var canonical_target := _canonical_map_scene_path(target_scene_path)
	var resolved_target := _resolve_main_scene_path(canonical_target)
	if target_scene_path.is_empty() or not ResourceLoader.exists(resolved_target):
		push_warning("Portal target scene is not available: %s" % target_scene_path)
		return

	var expedition_variant := StringName(
		_portal.get_meta("expedition_variant_id", &"") if _portal != null else &""
	)
	if expedition_variant.is_empty():
		expedition_variant = expedition_catalog.get_region_id_for_scene(canonical_target)
	if not expedition_variant.is_empty() and not run_state.active:
		_open_deck_builder(canonical_target, target_spawn_name)
		return
	elif canonical_target == BATTLE_PORTAL_HUB_SCENE_PATH and run_state.active:
		var victory := run_state.boss_defeated
		var summary := _finish_run(
			victory,
			RunState.OUTCOME_VICTORY if victory else RunState.OUTCOME_SAFE_RETREAT
		)
		_pending_player_state.clear()
		player = null
		load_current_map(load(resolved_target) as PackedScene, target_spawn_name)
		_show_run_result(victory, summary)
		return
	elif canonical_target == AUTUMN_SAFE_ZONE_SCENE_PATH and run_state.active:
		var victory := run_state.boss_defeated
		var summary := _finish_run(
			victory,
			RunState.OUTCOME_VICTORY if victory else RunState.OUTCOME_SAFE_RETREAT
		)
		_pending_player_state.clear()
		player = null
		load_current_map(load(resolved_target) as PackedScene, target_spawn_name)
		_show_run_result(victory, summary)
		return
	elif canonical_target == TOWN_SCENE_PATH and run_state.active:
		_finish_run(false, RunState.OUTCOME_SAFE_RETREAT)
		_pending_player_state.clear()
		player = null
	elif run_state.active and run_state.boss_defeated:
		_finish_run(true)
	var packed := load(resolved_target) as PackedScene
	load_current_map(packed, target_spawn_name)


func _open_expedition_variant_selector(entries: Array, target_spawn_name: StringName) -> void:
	if get_open_ui("ExpeditionVariantSelectUI") != null:
		return
	var ui_control := open_ui(
		"ExpeditionVariantSelectUI",
		expedition_variant_select_scene,
		true
	)
	if ui_control == null:
		return
	ui_control.call("configure", "選擇戰鬥世界", entries)
	ui_control.connect(
		"variant_selected",
		_on_expedition_variant_selected.bind(ui_control, target_spawn_name),
		CONNECT_ONE_SHOT
	)
	ui_control.connect(
		"cancelled",
		close_ui.bind(ui_control),
		CONNECT_ONE_SHOT
	)


func _on_expedition_variant_selected(
	entry: Dictionary,
	ui_control: Control,
	target_spawn_name: StringName
) -> void:
	var target_scene_path := String(entry.get("target_scene_path", ""))
	var resolved_target := _resolve_main_scene_path(target_scene_path)
	if target_scene_path.is_empty() or not ResourceLoader.exists(resolved_target):
		push_warning("Selected expedition scene is not available: %s" % target_scene_path)
		return
	close_ui(ui_control)
	_open_deck_builder(target_scene_path, target_spawn_name)


func _open_deck_builder(target_scene_path: String, target_spawn_name: StringName) -> void:
	if get_open_ui("DeckBuilderUI") != null:
		return
	var ui_control := open_ui("DeckBuilderUI", deck_builder_scene, true)
	if ui_control == null:
		return
	ui_control.set_meta("expedition_target_scene_path", target_scene_path)
	var discovered: Array[Dictionary] = []
	var valid_ids: Array[String] = []
	for card in card_database.get_all_cards():
		valid_ids.append(String(card.get("id", "")))
	meta_state.normalize_selected_deck(valid_ids)
	for card_id in meta_state.unlocked_cards:
		var card := card_database.get_card(card_id)
		if not card.is_empty():
			discovered.append(card)
	ui_control.call(
		"configure",
		discovered,
		meta_state.selected_deck,
		meta_state.auto_attack_card_id
	)
	ui_control.connect(
		"loadout_confirmed",
		_on_loadout_confirmed.bind(ui_control, target_scene_path, target_spawn_name),
		CONNECT_ONE_SHOT
	)
	ui_control.connect(
		"deck_confirmed",
		_on_deck_confirmed.bind(ui_control, target_scene_path, target_spawn_name),
		CONNECT_ONE_SHOT
	)


func _on_deck_confirmed(deck_ids: Array[String], ui_control: Control, target_scene_path: String, target_spawn_name: StringName) -> void:
	_on_loadout_confirmed(
		deck_ids,
		meta_state.auto_attack_card_id,
		ui_control,
		target_scene_path,
		target_spawn_name
	)


func _on_loadout_confirmed(
	deck_ids: Array[String],
	auto_attack_card_id: String,
	ui_control: Control,
	target_scene_path: String,
	target_spawn_name: StringName
	) -> void:
	if run_state.active:
		return
	var normalized := _ensure_fixed_combo_loadout(
		_normalize_expedition_deck(deck_ids)
	)
	var previous_meta := meta_state.to_dict()
	meta_state.set_selected_deck(normalized)
	meta_state.auto_attack_card_id = _resolve_auto_attack_card_id(auto_attack_card_id)
	if not save_service.save_meta(_meta_save_path(), meta_state.to_dict()):
		meta_state.apply_dict(previous_meta)
		return
	close_ui(ui_control)
	if target_scene_path.is_empty():
		return
	var variant_id := expedition_catalog.get_region_id_for_scene(target_scene_path)
	if variant_id.is_empty():
		variant_id = expedition_catalog.get_region_id_for_scene(
			_canonical_map_scene_path(target_scene_path)
		)
	_begin_expedition_run(
		normalized,
		variant_id if not variant_id.is_empty() else &"autumn",
		expedition_catalog.is_boss_scene(target_scene_path)
	)
	load_current_map(load(_resolve_main_scene_path(target_scene_path)) as PackedScene, target_spawn_name)


func _normalize_expedition_deck(deck_ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	for card_id_variant in deck_ids:
		if normalized.size() >= deck_manager.hand_size:
			break
		var card_id := String(card_id_variant)
		if not card_database.has_card(card_id):
			continue
		var card := card_database.get_card(card_id)
		if not _is_combat_hand_card(card):
			continue
		if normalized.has(card_id):
			continue
		normalized.append(card_id)
	return normalized


func _is_combat_hand_card(card: Dictionary) -> bool:
	return (
		String(card.get("type", "")) in ["combo", "healing"]
		and bool(card.get("combat_hand", true))
		and bool(combo_finisher_catalog.call("is_skill_eligible", String(card.get("id", ""))))
	)


func _ensure_fixed_combo_loadout(deck_ids: Array[String]) -> Array[String]:
	var fixed_loadout: Array[String] = []
	var fixed_healing := ""
	for card_id in deck_ids:
		var candidate := card_database.get_card(card_id)
		if (
			_is_combat_hand_card(candidate)
			and String(candidate.get("type", "")) == "healing"
		):
			fixed_healing = card_id
			break
	if fixed_healing.is_empty():
		fixed_healing = "healing_light"
	fixed_loadout.append(fixed_healing)
	for card_id in deck_ids:
		if fixed_loadout.size() >= deck_manager.hand_size:
			break
		var card := card_database.get_card(card_id)
		if not _is_combat_hand_card(card) or fixed_loadout.has(card_id):
			continue
		fixed_loadout.append(card_id)
	for fallback_id in [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		"battle_rhythm", "guard", "renewal", "verdant_renewal",
	]:
		if fixed_loadout.size() >= deck_manager.hand_size:
			break
		if fixed_loadout.has(fallback_id):
			continue
		fixed_loadout.append(fallback_id)
	return fixed_loadout


func _on_chest_opened(_chest: Node, loot_table_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	if loot_table_id == &"forest_rest":
		_open_campfire_menu()
		return
	var message := "You found supplies from %s." % String(loot_table_id)

	var ui_control := open_ui("DialogueUI", dialogue_scene)
	if ui_control == null:
		return
	ui_control.call("set_speaker_name", "Chest")
	ui_control.call("set_dialogue_text", message)
	ui_control.call("set_choices", [{"text": "Take all"}])


func _open_campfire_menu() -> void:
	var ui_control := open_ui("CampfireUI", dialogue_scene, true)
	if ui_control == null:
		return
	_render_campfire_root(ui_control)
	ui_control.connect("choice_selected", _on_campfire_choice.bind(ui_control))


func _render_campfire_root(ui_control: Control) -> void:
	ui_control.call("set_speaker_name", "Forest Campfire")
	if bool(run_state.temporary_buffs.get("campfire_used", false)):
		ui_control.call("set_dialogue_text", "Only cold embers remain. This campfire has already aided your run.")
		ui_control.call("set_choices", [{"text": "Leave", "action": "close"}])
	else:
		ui_control.call("set_dialogue_text", "Rest beside the fire to restore health and mana.")
		ui_control.call("set_choices", [
			{"text": "Rest — restore HP and MP", "campfire_action": "rest"},
			{"text": "Leave", "campfire_action": "leave", "action": "close"},
		])


func _on_campfire_choice(_index: int, _text: String, metadata: Dictionary, ui_control: Control) -> void:
	if not is_instance_valid(ui_control):
		return
	var action := String(metadata.get("campfire_action", ""))
	match action:
		"rest":
			if _rest_at_campfire():
				_show_campfire_result(ui_control, "You rest until your health and mana are fully restored.")
		"back":
			_render_campfire_root(ui_control)
		"leave":
			close_ui(ui_control)


func _rest_at_campfire() -> bool:
	if player == null:
		return false
	if run_state.active and bool(run_state.temporary_buffs.get("campfire_used", false)):
		return false
	player.call("restore_health", int(player.get("max_health")))
	player.call("restore_mana", int(player.get("max_mana")))
	if run_state.active:
		run_state.temporary_buffs["campfire_used"] = true
	return true


func _show_campfire_result(ui_control: Control, message: String) -> void:
	ui_control.call("set_dialogue_text", message)
	ui_control.call("set_choices", [{"text": "Leave", "campfire_action": "leave", "action": "close"}])


func _card_name(card_id: String) -> String:
	var card := card_database.get_card(card_id)
	var localized := _localized_text(card, "name")
	return localized if not localized.is_empty() else card_id.capitalize()


func _localized_text(source: Dictionary, field: String) -> String:
	var localized := String(source.get("%s_zh" % field, "")).strip_edges()
	if not localized.is_empty():
		return localized
	return String(source.get(field, "")).strip_edges()


func _equipment_slot_label(slot: StringName) -> String:
	return {
		&"weapon": "武器裝備",
		&"armor": "防具裝備",
		&"accessory": "飾品裝備",
	}.get(slot, "裝備")


func _card_upgrade_description(card: Dictionary, target_level: int) -> String:
	for upgrade_variant in card.get("upgrade_effects", []) as Array:
		if not upgrade_variant is Dictionary:
			continue
		var upgrade := upgrade_variant as Dictionary
		if int(upgrade.get("level", 0)) == target_level:
			return _localized_text(upgrade, "description")
	return ""


func _card_level_description(card: Dictionary, level: int) -> String:
	if level <= CardInstance.MIN_LEVEL:
		return _localized_text(card, "description")
	var upgraded_description := _card_upgrade_description(card, level)
	return (
		upgraded_description
		if not upgraded_description.is_empty()
		else _localized_text(card, "description")
	)


func _update_interaction_prompt() -> void:
	if hud == null:
		return
	if current_interactive == null:
		if hud.has_method("clear_interaction_prompt"):
			hud.call("clear_interaction_prompt")
		return

	var prompt := "Interact"
	if current_interactive.has_method("get_interaction_prompt"):
		prompt = String(current_interactive.call("get_interaction_prompt"))
	var raw_display_name: Variant = current_interactive.get("display_name")
	var show_target_name := not bool(
		hud.get_meta("interaction_prompt_action_only", false)
	)
	if show_target_name and raw_display_name != null:
		var display_name := String(raw_display_name).strip_edges()
		if not display_name.is_empty():
			prompt = "%s — %s" % [prompt, display_name]
	if hud.has_method("set_interaction_prompt"):
		hud.call("set_interaction_prompt", prompt, "F", current_interactive)


func _dialogue_text_for(dialogue_id: StringName, display_name: String) -> String:
	match dialogue_id:
		&"item_merchant_greeting":
			return "Welcome. I have practical goods for travelers."
		&"blacksmith_greeting":
			return "Keep your blade sharp and your boots ready."
		&"town_mayor":
			return "The road is open, but stay alert beyond town."
		_:
			return "%s is ready to talk." % display_name


func _shop_items_for(shop_id: StringName) -> Array[Dictionary]:
	if shop_id == &"blacksmith":
		return [
			{"id": "iron_sword", "name": "鐵劍", "price": 120, "sell_price": 60, "description": "可靠的入門長劍。", "stock": 2},
			{"id": "guard_boots", "name": "守衛長靴", "price": 85, "sell_price": 42, "description": "適合長途行走的輕便長靴。", "stock": 3},
		]
	return [
		{"id": "travel_bread", "name": "旅人麵包", "price": 12, "sell_price": 6, "description": "適合旅途攜帶的樸實乾糧。", "stock": 12},
		{"id": "town_map", "name": "城鎮地圖", "price": 45, "sell_price": 22, "description": "標記城鎮周圍的道路。", "stock": 1},
	]


func _catalog_for_shop(shop_id: StringName) -> Array[Dictionary]:
	if _is_forge_shop(shop_id):
		return _forge_shop_items(shop_id)
	var key := String(shop_id)
	if not _merchant_catalogs.has(key):
		_merchant_catalogs[key] = _shop_items_for(shop_id)
	return _merchant_catalogs[key] as Array[Dictionary]


func _is_forge_shop(shop_id: StringName) -> bool:
	return shop_id in [&"sword_soul_shop", &"equipment_blueprint_shop"]


func _forge_shop_items(shop_id: StringName) -> Array[Dictionary]:
	_refresh_forge_progression()
	var result: Array[Dictionary] = []
	for offer_variant in forge_service.call("get_shop_offers", shop_id) as Array:
		var offer := (offer_variant as Dictionary).duplicate(true)
		var owned_variant: Variant = offer.get("owned", false)
		var owned_count := int(owned_variant) if owned_variant is int else int(bool(owned_variant))
		var product_kind := String(offer.get("product_kind", ""))
		var icon_path := String(offer.get("icon_path", ""))
		var blueprint_id := StringName(offer.get("product_id", ""))
		var proficiency: Dictionary = {}
		if product_kind == "blueprint":
			proficiency = inventory_manager.call(
				"get_blueprint_proficiency", blueprint_id
			) as Dictionary
		result.append({
			"id": String(offer.get("id", "")),
			"name": String(offer.get("name", "Blueprint")),
			"description": String(
				offer.get(
					"description",
					"Permanent design for your Player Blacksmith workshop."
				)
			),
			"price": int(offer.get("price", 0)),
			"stock": 99 if product_kind == "equipment" else (0 if owned_count > 0 else 1),
			"owned_count": owned_count,
			"product_kind": product_kind,
			"product_id": String(offer.get("product_id", "")),
			"target_kind": String(offer.get("target_kind", "")),
			"target_id": String(offer.get("target_id", "")),
			"required_flame_tier": int(offer.get("required_flame_tier", 0)),
			"blueprint_awakened": bool(proficiency.get("awakened", false)),
			"blueprint_school": String(proficiency.get("school", "balanced")),
			"blueprint_schools": forge_service.call("get_blueprint_schools") as Array,
			"blueprint_rework_cost": forge_service.call(
				"get_blueprint_rework_cost", blueprint_id
			) as Dictionary,
			"texture": load(icon_path) as Texture2D if not icon_path.is_empty() else null,
		})
	return result


func _on_shop_mode_changed(mode: String, ui_control: Control, shop_id: StringName) -> void:
	_refresh_shop_projection(ui_control, shop_id, mode)


func _refresh_shop_projection(ui_control: Control, shop_id: StringName, mode: String) -> void:
	if not is_instance_valid(ui_control):
		return
	var projection: Array[Dictionary] = []
	for raw_item in _catalog_for_shop(shop_id):
		var item := raw_item.duplicate(true)
		var item_id := String(item.get("id", ""))
		if not _is_forge_shop(shop_id):
			item["owned_count"] = int(player_inventory.get(item_id, 0))
		if mode == "sell" and int(item["owned_count"]) <= 0:
			continue
		projection.append(item)
	ui_control.call("set_wallet", wallet_gold)
	ui_control.call("set_items", projection)


func _on_shop_transaction_confirmed(
	item: Dictionary,
	quantity: int,
	mode: String,
	ui_control: Control,
	shop_id: StringName
) -> void:
	if _is_forge_shop(shop_id):
		_purchase_forge_shop_offer(item, quantity, mode, ui_control, shop_id)
		return
	var safe_quantity := maxi(1, quantity)
	var item_id := String(item.get("id", ""))
	var catalog := _catalog_for_shop(shop_id)
	var catalog_item: Dictionary = {}
	for entry in catalog:
		if String(entry.get("id", "")) == item_id:
			catalog_item = entry
			break
	if catalog_item.is_empty():
		ui_control.call("set_transaction_feedback", "This item is unavailable.", false)
		return

	var success := false
	var message := ""
	if mode == "sell":
		var owned := int(player_inventory.get(item_id, 0))
		var unit_price := int(catalog_item.get("sell_price", maxi(1, int(catalog_item.get("price", 0)) / 2)))
		if owned < safe_quantity:
			message = "You do not own enough of this item."
		else:
			player_inventory[item_id] = owned - safe_quantity
			wallet_gold += unit_price * safe_quantity
			catalog_item["stock"] = int(catalog_item.get("stock", 0)) + safe_quantity
			success = true
			message = "Sold %s x%d for %d gold." % [
				String(catalog_item.get("name", item_id)),
				safe_quantity,
				unit_price * safe_quantity,
			]
	else:
		var stock := int(catalog_item.get("stock", 0))
		var unit_price := int(catalog_item.get("price", 0))
		var total := unit_price * safe_quantity
		if stock < safe_quantity:
			message = "The merchant does not have enough stock."
		elif wallet_gold < total:
			message = "You do not have enough gold."
		else:
			wallet_gold -= total
			catalog_item["stock"] = stock - safe_quantity
			player_inventory[item_id] = int(player_inventory.get(item_id, 0)) + safe_quantity
			success = true
			message = "Bought %s x%d for %d gold." % [
				String(catalog_item.get("name", item_id)),
				safe_quantity,
				total,
			]

	if hud != null and hud.has_method("set_currency"):
		hud.call("set_currency", wallet_gold)
	inventory_manager.call("set_resource_amount", &"gold", wallet_gold)
	_sync_progression_to_meta()
	_refresh_shop_projection(ui_control, shop_id, mode)
	ui_control.call("set_transaction_feedback", message, success)


func _purchase_forge_shop_offer(
	item: Dictionary,
	quantity: int,
	mode: String,
	ui_control: Control,
	shop_id: StringName
) -> void:
	if mode != "buy":
		ui_control.call("set_transaction_feedback", "This merchant only sells equipment and designs.", false)
		return
	var offer_id := StringName(item.get("id", ""))
	var result := forge_service.call("purchase_offer", offer_id, quantity) as Dictionary
	var success := bool(result.get("ok", false))
	var product_kind := String(item.get("product_kind", ""))
	var message := (
		("Basic equipment added to your inventory."
		if product_kind == "equipment"
		else "Blueprint added to your Player Blacksmith workshop.")
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	_sync_progression_to_meta()
	save_service.save_meta(_meta_save_path(), meta_state.to_dict())
	if hud != null and hud.has_method("set_currency"):
		hud.call("set_currency", wallet_gold)
	_refresh_shop_projection(ui_control, shop_id, "buy")
	ui_control.call("set_transaction_feedback", message, success)


func _on_blueprint_school_change_requested(
	blueprint_id: StringName,
	school_id: StringName,
	ui_control: Control,
	shop_id: StringName
) -> void:
	if not _is_forge_shop(shop_id):
		return
	var result := forge_service.call(
		"rework_blueprint_school", blueprint_id, school_id
	) as Dictionary
	var success := bool(result.get("ok", false))
	var school_name := String(school_id).replace("_", " ").capitalize()
	var message := (
		"覺醒圖紙已改造為 %s；熟練度完整保留。" % school_name
		if success else _forge_result_message(StringName(result.get("code", "")))
	)
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	_persist_forge_progress()
	_refresh_shop_projection(ui_control, shop_id, "buy")
	ui_control.call("set_transaction_feedback", message, success)


func _forge_result_message(code: StringName) -> String:
	match code:
		&"insufficient_gold":
			return "金幣不足。"
		&"already_owned":
			return "工坊已擁有這份永久圖紙。"
		&"offer_locked", &"blacksmith_level_locked":
			return "提升永恆之火或工坊等級後才能解鎖此圖紙。"
		&"tool_required":
			return "請先在素材行購買所需的鍛造工具。"
		&"blueprint_required":
			return "請先取得圖紙再進行鍛造。"
		&"insufficient_resources":
			return "工坊缺少所需素材。"
		&"listing_rejected":
			return "販售桌目前已占用，或此物品無法上架。"
		&"equipment_sales_locked":
			return "先擴建市場，才會有願意購買裝備的顧客。"
		&"forge_method_locked":
			return "名匠鍛造只對 Lv.5 覺醒圖紙開放。"
		&"unknown_forge_method":
			return "找不到所選的鍛造工法。"
		&"customer_passed":
			return "這位顧客沒有購買；商品會留在架上等待下一位客人。"
		&"market_building_too_low":
			return "先升級商店建築，才能購買這個階級的櫃台。"
		&"previous_market_fixture_required":
			return "櫃台家具必須依階級逐步升級。"
		&"market_fixture_owned":
			return "這座櫃台已經安裝。"
		&"blueprint_not_awakened":
			return "圖紙熟練度達 Lv.5 覺醒後才能改換流派。"
		&"blueprint_school_unchanged":
			return "這張圖紙已經是所選流派。"
		&"unknown_blueprint_school", &"blueprint_rework_failed":
			return "圖紙流派改造無法完成。"
		&"no_active_listing":
			return "請先把已鍛造的裝備放上販售桌。"
		&"sword_soul_not_owned":
			return "請先鍛造這枚劍魂再進行升級。"
		&"upgrade_rejected":
			return "這枚劍魂已達目前升級上限。"
		_:
			return "交易無法完成。"
