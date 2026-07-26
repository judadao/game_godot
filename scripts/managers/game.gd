extends Node

signal map_loaded(map: Node)
signal player_registered(player_node: Node)
signal ui_opened(ui_name: String, ui_node: Control)
signal ui_closed(ui_name: String, ui_node: Control)

const QUICK_SAVE_PATH := "user://saves/quick_save.json"
const QUICK_SAVE_TEMP_PATH := "user://saves/quick_save.tmp"
const QUICK_SAVE_BACKUP_PATH := "user://saves/quick_save.json.bak"
const META_SAVE_PATH := "user://saves/meta_progress.json"
const MAP_REGISTRY_SCRIPT := preload("res://scripts/systems/map_registry.gd")
const TOWN_SCENE_PATH := MAP_REGISTRY_SCRIPT.TOWN_SCENE_PATH
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
const BASE_AP_REGEN := 0.65
const WISP_AP_REGEN := 0.35
const WISP_DURATION := 6.0
const COMBAT_CAMERA_SAFE_OFFSET_Y := 90.0
const MAX_COMBO_ABILITIES := 4
const MAX_COMBO_LEVEL := 3
const DEFAULT_COMBO_DURATION := 6.0
const FIXED_CARD_IDS: Array[String] = ["ember_bolt", "quickstep"]
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
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
@export var card_hand_scene: PackedScene = preload("res://scenes/ui/CardHandUI.tscn")
@export var inventory_scene: PackedScene = preload("res://scenes/ui/InventoryUI.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")
@export var dialogue_scene: PackedScene = preload("res://scenes/ui/DialogueUI.tscn")
@export var shop_scene: PackedScene = preload("res://scenes/ui/ShopUI.tscn")
@export var town_progress_scene: PackedScene = preload("res://scenes/ui/TownProgressUI.tscn")
@export var run_result_scene: PackedScene = preload("res://scenes/ui/RunResultUI.tscn")
@export var deck_builder_scene: PackedScene = preload("res://scenes/ui/DeckBuilderUI.tscn")
@export var card_discard_scene: PackedScene = preload("res://scenes/ui/CardDiscardUI.tscn")
@export var card_growth_scene: PackedScene = preload("res://scenes/ui/CardGrowthUI.tscn")

@onready var map_root: Node = $MapRoot
@onready var hud_root: CanvasLayer = $HUDLayer
@onready var ui_root: CanvasLayer = $MenuLayer
@onready var card_effect_runner: CardEffectRunner = $CardEffectRunner

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
var card_database := CardDatabase.new()
var deck_manager := DeckManager.new(card_database)
var evolution_manager := EvolutionManager.new(card_database)
var skill_recipe_manager := SkillRecipeManager.new()
var growth_choice_queue := GrowthChoiceQueue.new()
var inventory_manager: RefCounted = INVENTORY_MANAGER_SCRIPT.new()
var town_manager: RefCounted = TOWN_MANAGER_SCRIPT.new(inventory_manager)
var _pending_player_state: Dictionary = {}
var _last_combo_name := "—"
var _tactical_slowdown := false
var wallet_gold: int = 250
var player_inventory: Dictionary = {
	"travel_bread": 3,
}
var _merchant_catalogs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	meta_state.apply_dict(save_service.load_meta(META_SAVE_PATH))
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
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	card_database.load_catalog()
	evolution_manager.load_recipes()
	skill_recipe_manager.load_catalog("res://data/skills.json")
	_configure_skill_loadout()
	card_effect_runner.effect_resolved.connect(_on_card_effect_resolved)
	load_current_map(starting_map)
	_sync_progression_to_meta()


func _configure_skill_loadout() -> void:
	var capacity := int(town_manager.call("get_skill_memory_capacity"))
	if skill_recipe_manager.configure_loadout(
		meta_state.learned_skill_ids,
		meta_state.active_skill_ids,
		capacity
	):
		return
	meta_state.learned_skill_ids = ["iron_momentum"]
	meta_state.active_skill_ids = ["iron_momentum"]
	skill_recipe_manager.configure_loadout(
		meta_state.learned_skill_ids,
		meta_state.active_skill_ids,
		capacity
	)


func _process(delta: float) -> void:
	if not run_state.active or get_tree().paused:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	deck_manager.tick_cooldowns(real_delta)
	skill_recipe_manager.tick(real_delta)
	_refresh_cooldown_display()
	if _tick_combo_effects(real_delta):
		_refresh_combo_display()
	var regen_rate := BASE_AP_REGEN
	regen_rate += float((inventory_manager.call("get_special_ability_totals") as Dictionary).get("ap_regen", 0.0))
	regen_rate += float(run_state.temporary_buffs.get("level_ap_regen", 0.0))
	var wisp_seconds := float(run_state.temporary_buffs.get("ap_wisp_seconds", 0.0))
	if wisp_seconds > 0.0:
		regen_rate += float(run_state.temporary_buffs.get("ap_wisp_rate", WISP_AP_REGEN))
		run_state.temporary_buffs["ap_wisp_seconds"] = maxf(0.0, wisp_seconds - delta)
	var regenerated := deck_manager.regenerate_energy(delta, regen_rate)
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
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
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

	if map_scene == null:
		push_error("Game entry has no map scene assigned.")
		return null

	current_map = map_scene.instantiate()
	map_root.add_child(current_map)
	load_hud()
	load_card_hand()
	_register_player(spawn_name)
	_apply_transferred_player_state()
	_apply_shortcut_spawn()
	_apply_equipment_stats()
	_wire_interactives()
	_wire_combat_zones()
	_update_hud_area_name()
	if run_state.active:
		_refresh_card_hand()
	_update_card_hand_visibility()
	_apply_town_visual_progress()
	map_loaded.emit(current_map)
	return current_map


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
	else:
		push_error("HUD scene root must be a Control.")
		hud_instance.queue_free()


func load_card_hand() -> void:
	if card_hand_ui != null:
		if hud == null or not hud.is_ancestor_of(card_hand_ui):
			card_hand_ui.queue_free()
		card_hand_ui = null

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
		AUTUMN_FOREST_SCENE_PATH: "Autumn Forest",
		CRYSTAL_CAVES_SCENE_PATH: "Crystal Caves",
		FORBIDDEN_GRAVEYARD_SCENE_PATH: "Forbidden Graveyard",
	}
	var map_path := _canonical_map_scene_path(current_map.scene_file_path)
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
	_wire_common_ui_controls(ui_control)
	_wire_ui_lifecycle(ui_control)
	if ui_control.has_method("open"):
		ui_control.call("open")
	_focus_first_control(ui_control)
	_update_pause_state()
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
	if ui_name == "TownProgressUI":
		_sync_progression_to_meta()
		save_service.save_meta(META_SAVE_PATH, meta_state.to_dict())
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
	_update_player_input_state()
	if player.has_signal("resources_changed") and not player.is_connected(
		"resources_changed",
		_update_hud_resources
	):
		player.connect("resources_changed", _update_hud_resources)
	if player.has_signal("defeated") and not player.is_connected("defeated", _on_player_defeated):
		player.connect("defeated", _on_player_defeated)
	var status_controller := player.get_node_or_null("CombatStatusController")
	if (
		status_controller != null
		and status_controller.has_signal("statuses_changed")
		and not status_controller.is_connected("statuses_changed", _on_player_statuses_changed)
	):
		status_controller.connect("statuses_changed", _on_player_statuses_changed)
		_on_player_statuses_changed(player.call("get_combat_status_projection") as Array)
	_update_hud_resources()
	player_registered.emit(player)


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
	camera.position.y = COMBAT_CAMERA_SAFE_OFFSET_Y if run_state.active and _current_map_matches(AUTUMN_FOREST_SCENE_PATH) else 0.0
	camera.reset_smoothing()


func _wire_common_ui_controls(ui_control: Control) -> void:
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
	if ui_control.has_method("set_button_enabled"):
		ui_control.call("set_button_enabled", "load", FileAccess.file_exists(QUICK_SAVE_PATH))

	var quit_button := ui_control.find_child("Quit", true, false)
	if quit_button is BaseButton:
		(quit_button as BaseButton).pressed.connect(get_tree().quit)


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
		_connect_if_present(interactive, &"portal_entered", &"_on_portal_entered")
		_connect_if_present(interactive, &"chest_opened", &"_on_chest_opened")


func _wire_combat_zones() -> void:
	if current_map == null:
		return
	for zone in current_map.get_tree().get_nodes_in_group("CombatZones"):
		if not current_map.is_ancestor_of(zone):
			continue
		_connect_if_present(zone, &"progress_changed", &"_on_combat_progress_changed")
		_connect_if_present(zone, &"zone_cleared", &"_on_combat_zone_cleared")
	for director in current_map.get_tree().get_nodes_in_group("EncounterDirectors"):
		if not current_map.is_ancestor_of(director):
			continue
		_connect_if_present(director, &"wave_started", &"_on_run_wave_started")
		_connect_if_present(director, &"progress_changed", &"_on_run_progress_changed")
		_connect_if_present(director, &"encounter_cleared", &"_on_run_encounter_cleared")
		_connect_if_present(director, &"combat_engaged", &"_on_combat_engaged")
		_connect_if_present(director, &"disengage_warning", &"_on_disengage_warning")
		_connect_if_present(director, &"disengage_cancelled", &"_on_disengage_cancelled")
		_connect_if_present(director, &"combat_reset", &"_on_combat_reset")
		_connect_if_present(director, &"experience_gem_spawned", &"_on_experience_gem_spawned")
		_connect_if_present(director, &"phase_time_changed", &"_on_survival_phase_time_changed")
		_connect_if_present(director, &"boss_stage_completed", &"_on_boss_stage_completed")
		if director.has_method("start_encounter") and not bool(director.get("_running")):
			director.call_deferred("start_encounter")


func _on_combat_progress_changed(remaining: int, total: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call(
			"set_objective",
			"Defeat the forest slimes",
			"Enemies remaining: %d / %d" % [remaining, total]
		)


func _on_combat_zone_cleared(experience_reward: int, gold_reward: int) -> void:
	inventory_manager.call("add_resource", &"gold", maxi(0, gold_reward))
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	if player != null:
		player.experience += maxi(0, experience_reward)
		while player.experience >= player.experience_to_next_level:
			player.experience -= player.experience_to_next_level
			player.level += 1
			player.experience_to_next_level = int(round(player.experience_to_next_level * 1.25))
			player.max_health += 10
			player.max_mana += 5
			player.restore_health(player.max_health)
			player.restore_mana(player.max_mana)
	if hud != null:
		if hud.has_method("set_currency"):
			hud.call("set_currency", wallet_gold)
		if hud.has_method("set_objective"):
			hud.call("set_objective", "Autumn Forest secured", "+%d EXP   +%d Gold" % [experience_reward, gold_reward])
	_update_hud_player_identity()


func _on_run_wave_started(wave_number: int, total_waves: int, enemy_count: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call(
			"set_objective",
			"Autumn Tree — Wave %d / %d" % [wave_number, total_waves],
			"Enemies: %d" % enemy_count
		)
	if run_state.active and wave_number > 1 and wave_number < total_waves:
		call_deferred("_show_card_reward_choices", wave_number)
	if run_state.active and wave_number == 3:
		_discover_equipment_reward()
	if wave_number == total_waves:
		call_deferred("_wire_boss_hud")


func _on_run_progress_changed(remaining: int, total: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "Autumn Tree Expedition", "Enemies remaining: %d / %d" % [remaining, total])


func _on_survival_phase_time_changed(phase: int, remaining: float, alive: int, cap: int) -> void:
	if hud != null and hud.has_method("set_objective"):
		var time_text := "BOSS" if remaining < 0.0 else "%ds" % int(ceil(remaining))
		hud.call("set_objective", "SURVIVAL PHASE %d" % phase, "%s   Enemies %d / %d" % [time_text, alive, cap])


func _on_boss_stage_completed() -> void:
	if not run_state.active:
		return
	run_state.boss_defeated = true
	meta_state.boss_defeated = true
	meta_state.dash_upgrade_unlocked = true
	inventory_manager.call("set_progression_unlocks", {"dash_upgrade_unlocked": true})
	run_state.add_reward("autumn_wood", 18)
	run_state.add_reward("magic_shard", 7)
	meta_state.add_resource("autumn_core", 1)
	inventory_manager.call("add_resource", &"autumn_core", 1)
	meta_state.shortcuts["autumn_route_cleared"] = true
	_discover_equipment_reward()
	if current_map != null:
		var forward_portal := current_map.get_node_or_null("ForwardPortal")
		if forward_portal != null and forward_portal.has_method("set_locked"):
			forward_portal.call("set_locked", false, "")
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "BOSS DEFEATED — ROUTE OPEN", "The forward portal now leads to the next region.")


func _on_experience_gem_spawned(gem: Node, _value: int) -> void:
	if gem != null and gem.has_signal("collected"):
		gem.connect("collected", _on_experience_collected, CONNECT_ONE_SHOT)


func _on_experience_collected(value: int) -> void:
	if run_state.add_experience(value) > 0:
		_enqueue_experience_growth()
	_update_hud_player_identity()


func _enqueue_experience_growth() -> void:
	if run_state.pending_level_ups <= 0 or not growth_choice_queue.is_empty():
		return
	var upgrades: Array[Dictionary] = []
	for instance in run_state.card_instances:
		if instance.is_fixed() or instance.level >= CardInstance.MAX_LEVEL:
			continue
		upgrades.append({
			"instance_id": instance.instance_id,
			"card_id": instance.card_id,
			"name": _card_name(instance.card_id),
			"level": instance.level,
		})
	var fusions := evolution_manager.find_available_fusions(run_state.card_instances)
	for fusion in fusions:
		fusion["left_name"] = _card_name(String(fusion.get("left_card_id", "")))
		fusion["right_name"] = _card_name(String(fusion.get("right_card_id", "")))
		fusion["result_name"] = _card_name(String(fusion.get("result_card_id", "")))
	if not growth_choice_queue.enqueue_experience_growth(upgrades, fusions):
		return
	call_deferred("_open_next_growth_choice")


func _get_run_deck_size() -> int:
	return deck_manager.get_all_instances().size()


func _open_next_growth_choice() -> void:
	if growth_choice_queue.is_empty() or get_open_ui("CardGrowthUI") != null:
		return
	var ui_control := open_ui("CardGrowthUI", card_growth_scene, true)
	if ui_control == null:
		return
	ui_control.call("present_page", growth_choice_queue.peek())
	ui_control.connect(
		"choice_confirmed",
		_on_growth_choice_confirmed.bind(ui_control)
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
	if not _apply_growth_resolution(selected):
		ui_control.call("present_page", page)
		return
	if growth_choice_queue.resolve(choice_id).is_empty():
		return
	if String(page.get("source", "")) == "experience":
		run_state.consume_pending_level()
	close_ui(ui_control)
	_refresh_card_hand()
	_update_hud_player_identity()
	if run_state.pending_level_ups > 0 and growth_choice_queue.is_empty():
		_enqueue_experience_growth()
	elif not growth_choice_queue.is_empty():
		call_deferred("_open_next_growth_choice")


func _apply_growth_resolution(choice: Dictionary) -> bool:
	var snapshot := _capture_growth_transaction()
	var applied := _apply_growth_resolution_uncommitted(choice)
	if not applied or not save_service.save_meta(META_SAVE_PATH, meta_state.to_dict()):
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
	var instance_levels: Dictionary = {}
	for instance in meta_state.selected_card_instances + run_state.card_instances + deck_manager.get_all_instances():
		instance_levels[instance.instance_id] = instance.level
	var cooldown_snapshot: Array[Dictionary] = []
	for entry in deck_manager.cooldown_pile:
		cooldown_snapshot.append(entry.duplicate())
	return {
		"meta": meta_state.to_dict(),
		"meta_instances": meta_state.selected_card_instances.duplicate(),
		"run_instances": run_state.card_instances.duplicate(),
		"run_card_levels": run_state.card_levels.duplicate(true),
		"run_temporary_cards": run_state.temporary_cards.duplicate(),
		"deck_hand": deck_manager.hand_instances.duplicate(),
		"deck_draw": deck_manager.draw_instances.duplicate(),
		"deck_discard": deck_manager.discard_instances.duplicate(),
		"deck_exhaust": deck_manager.exhaust_instances.duplicate(),
		"deck_cooldown": cooldown_snapshot,
		"instance_levels": instance_levels,
		"inventory": inventory_manager.call("to_dict"),
		"wallet_gold": wallet_gold,
	}


func _restore_growth_transaction(snapshot: Dictionary) -> void:
	var instance_levels := snapshot.get("instance_levels", {}) as Dictionary
	for instance in (
		(snapshot.get("meta_instances", []) as Array)
		+ (snapshot.get("run_instances", []) as Array)
		+ (snapshot.get("deck_hand", []) as Array)
		+ (snapshot.get("deck_draw", []) as Array)
		+ (snapshot.get("deck_discard", []) as Array)
		+ (snapshot.get("deck_exhaust", []) as Array)
	):
		if instance is CardInstance and instance_levels.has(instance.instance_id):
			instance.level = int(instance_levels[instance.instance_id])
	meta_state.apply_dict(snapshot.get("meta", {}) as Dictionary)
	meta_state.selected_card_instances.assign(snapshot.get("meta_instances", []) as Array)
	meta_state.selected_deck = meta_state.get_selected_card_ids()
	run_state.card_instances.assign(snapshot.get("run_instances", []) as Array)
	run_state.card_levels = (snapshot.get("run_card_levels", {}) as Dictionary).duplicate(true)
	run_state.temporary_cards.assign(snapshot.get("run_temporary_cards", []) as Array)
	deck_manager.hand_instances.assign(snapshot.get("deck_hand", []) as Array)
	deck_manager.draw_instances.assign(snapshot.get("deck_draw", []) as Array)
	deck_manager.discard_instances.assign(snapshot.get("deck_discard", []) as Array)
	deck_manager.exhaust_instances.assign(snapshot.get("deck_exhaust", []) as Array)
	deck_manager.cooldown_pile.assign(snapshot.get("deck_cooldown", []) as Array)
	deck_manager.call("_sync_id_views")
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
	for boss in get_tree().get_nodes_in_group("Bosses"):
		if not current_map.is_ancestor_of(boss):
			continue
		if boss.has_signal("health_changed") and not boss.is_connected("health_changed", _on_boss_health_changed):
			boss.connect("health_changed", _on_boss_health_changed)
		var maximum := 1
		var archetype: Variant = boss.get("archetype")
		if archetype is Resource:
			maximum = int(archetype.get("max_health"))
		card_hand_ui.call("set_boss_health", "HEARTWOOD GUARDIAN", int(boss.get("health")), maximum)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	card_hand_ui.call("set_boss_health", "HEARTWOOD GUARDIAN", current, maximum)


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
	var summary := _finish_run(false)
	await get_tree().create_timer(0.8).timeout
	_pending_player_state.clear()
	player = null
	load_current_map(load(_resolve_main_scene_path(TOWN_SCENE_PATH)) as PackedScene)
	_show_run_result(false, summary)


func _begin_autumn_run(deck_override: Array = []) -> void:
	if run_state.active:
		return
	var fallback_deck := [
		"ember_bolt", "quickstep", "cleave", "cleave",
		"guard", "guard", "cleave", "dash_strike",
		"healing_light", "frost_bind", "energy_surge", "iron_skin",
		"flame_imbue", "frostburst_imbue", "battle_rhythm", "stoneguard_combo",
	]
	var selected: Array = deck_override if deck_override.size() > 0 and deck_override.size() <= 16 else meta_state.selected_deck
	var normalized := _normalize_expedition_deck(selected if selected.size() > 0 and selected.size() <= 16 else fallback_deck)
	meta_state.selected_deck = normalized.duplicate()
	var valid_ids: Array[String] = []
	for card in card_database.get_all_cards():
		valid_ids.append(String(card.get("id", "")))
	meta_state.normalize_selected_deck(valid_ids)
	run_state.begin_run(meta_state.selected_card_instances)
	deck_manager.set_protected_cards(FIXED_CARD_IDS)
	deck_manager.start(run_state.card_instances, run_state.max_energy, true)
	_configure_skill_loadout()
	_last_combo_name = "—"
	_refresh_card_hand()


func _show_card_reward_choices(wave_number: int) -> void:
	if not run_state.active:
		return
	var choices_by_wave := {
		2: ["guard", "dash_strike", "cleave"],
		3: ["frost_bind", "healing_light", "battle_focus"],
	}
	var card_ids: Array = choices_by_wave.get(wave_number, ["cleave", "iron_skin", "energy_surge"])
	var choices: Array[Dictionary] = []
	for card_id in card_ids:
		var card := card_database.get_card(String(card_id))
		choices.append({
			"text": "%s — %s" % [String(card.get("name", card_id)), String(card.get("description", ""))],
			"card_id": String(card_id),
		})
	if growth_choice_queue.enqueue_wave_blessing(choices):
		call_deferred("_open_next_growth_choice")


func _add_persistent_run_card(card_id: String) -> bool:
	if (
		not run_state.active
		or deck_manager.is_card_protected(card_id)
		or not card_database.has_card(card_id)
	):
		return false
	var instance := meta_state.add_card_instance(card_id, CardInstance.MIN_LEVEL)
	if instance == null:
		return false
	if not run_state.add_existing_card_instance(instance):
		meta_state.remove_card_instances([instance.instance_id])
		return false
	if not deck_manager.add_existing_instance(instance):
		run_state.remove_card_instances([instance.instance_id])
		meta_state.remove_card_instances([instance.instance_id])
		return false
	if not meta_state.unlocked_cards.has(card_id):
		meta_state.unlocked_cards.append(card_id)
	run_state.temporary_cards.append(card_id)
	_refresh_card_hand()
	return true


func _apply_card_fusion(choice: Dictionary) -> bool:
	var left_id := String(choice.get("left_instance_id", ""))
	var right_id := String(choice.get("right_instance_id", ""))
	var result_id := String(choice.get("result_card_id", ""))
	if left_id.is_empty() or right_id.is_empty() or left_id == right_id:
		return false
	var selected_recipe: Dictionary = {}
	for fusion in evolution_manager.find_available_fusions(run_state.card_instances):
		if (
			String(fusion.get("left_instance_id", "")) == left_id
			and String(fusion.get("right_instance_id", "")) == right_id
			and String(fusion.get("result_card_id", "")) == result_id
		):
			selected_recipe = fusion
			break
	if selected_recipe.is_empty() or not card_database.has_card(result_id):
		return false
	var consumed_ids: Array[String] = [left_id, right_id]
	if (
		not deck_manager.remove_instances(consumed_ids)
		or not run_state.remove_card_instances(consumed_ids)
		or not meta_state.remove_card_instances(consumed_ids)
	):
		return false
	var result := meta_state.add_card_instance(result_id, CardInstance.MIN_LEVEL)
	if result == null:
		return false
	if (
		not run_state.add_existing_card_instance(result)
		or not deck_manager.add_existing_instance(result)
	):
		return false
	var recipe_id := String(selected_recipe.get("id", selected_recipe.get("recipe_id", "")))
	if not recipe_id.is_empty() and not meta_state.unlocked_evolutions.has(recipe_id):
		meta_state.unlocked_evolutions.append(recipe_id)
	if not meta_state.unlocked_cards.has(result_id):
		meta_state.unlocked_cards.append(result_id)
	return true


func _get_card_copy_count(card_id: String) -> int:
	var count := 0
	for instance in deck_manager.get_all_instances():
		if instance.card_id == card_id:
			count += 1
	return count


func _finish_run(victory: bool) -> Dictionary:
	if not run_state.active:
		return {}
	var summary := run_state.finish_run(victory)
	_set_tactical_slowdown(false)
	card_hand_ui.visible = false
	card_hand_ui.call("hide_boss_health")
	meta_state.apply_run_summary(summary)
	inventory_manager.call("add_resource", &"gold", maxi(0, int(summary.get("gold", 0))))
	var materials: Variant = summary.get("materials", {})
	if materials is Dictionary:
		for resource_id in materials:
			inventory_manager.call(
				"add_resource",
				StringName(resource_id),
				maxi(0, int(materials[resource_id]))
			)
	_sync_progression_to_meta()
	save_service.save_meta(META_SAVE_PATH, meta_state.to_dict())
	if hud != null and hud.has_method("set_currency"):
		hud.call("set_currency", wallet_gold)
	return summary


func _on_card_selected(index: int) -> void:
	if not run_state.active or player == null or not ui_stack.is_empty():
		return
	if index < 0 or index >= deck_manager.hand_instances.size():
		return
	var instance := deck_manager.hand_instances[index]
	var projected_card := _card_for_cast(instance)
	var card := deck_manager.play_from_hand(index, int(projected_card.get("cost", 0)))
	if card.is_empty():
		_refresh_card_hand()
		return
	for identity_key in ["instance_id", "card_level", "card_instance"]:
		projected_card[identity_key] = card.get(identity_key)
	card = projected_card
	if String(card.get("type", "")) == "combo":
		_resolve_combo_card(card)
	else:
		card = _apply_combo_infusions_to_card(card)
	var targets: Array = []
	if current_map != null:
		for director in get_tree().get_nodes_in_group("EncounterDirectors"):
			if current_map.is_ancestor_of(director) and director.has_method("get_active_enemies"):
				targets.append_array(director.call("get_active_enemies") as Array)
		if targets.is_empty():
			for enemy in get_tree().get_nodes_in_group("Enemies"):
				if current_map.is_ancestor_of(enemy) and is_instance_valid(enemy):
					targets.append(enemy)
	card_effect_runner.cast(card, player, targets)
	_resolve_skill_triggers(skill_recipe_manager.record_card(card))
	var effect := card.get("effect", {}) as Dictionary
	if String(effect.get("kind", "")) == "summon" and String(effect.get("unit_id", "")) == "energy_wisp":
		run_state.temporary_buffs["ap_wisp_seconds"] = maxf(
			float(run_state.temporary_buffs.get("ap_wisp_seconds", 0.0)),
			WISP_DURATION
		)
		run_state.temporary_buffs["ap_wisp_rate"] = WISP_AP_REGEN
	var draw_count := maxi(0, int(effect.get("draw_cards", 0)))
	if not deck_manager.last_play_retained:
		draw_count += 1
	deck_manager.draw_cards(draw_count)
	run_state.energy = deck_manager.energy
	_set_tactical_slowdown(false)
	_refresh_card_hand()
	var overflow := maxi(0, deck_manager.hand_instances.size() - deck_manager.hand_size)
	if overflow > 0:
		call_deferred("_open_hand_overflow_discard", overflow)


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
	if current_level >= MAX_COMBO_LEVEL:
		return false
	levels[infusion_id] = current_level + 1
	run_state.temporary_buffs["combo_levels"] = levels
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	var effects: Array = effects_variant if effects_variant is Array else []
	var timed_effect := effect.duplicate(true)
	var equipment_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
	timed_effect["remaining_seconds"] = maxf(
		0.1,
		float(effect.get("combo_duration", DEFAULT_COMBO_DURATION))
		+ float(equipment_specials.get("combo_duration_bonus", 0.0))
	)
	effects.append(timed_effect)
	run_state.temporary_buffs["infusion_effects"] = effects
	_try_evolve_combo_abilities()
	return true


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
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not effects_variant is Array:
		return false
	var effects := effects_variant as Array
	if effects.is_empty():
		return false
	var retained: Array = []
	var changed := false
	for effect_variant in effects:
		if not effect_variant is Dictionary:
			changed = true
			continue
		var timed_effect := (effect_variant as Dictionary).duplicate(true)
		var remaining := float(timed_effect.get(
			"remaining_seconds",
			timed_effect.get("combo_duration", DEFAULT_COMBO_DURATION)
		)) - delta
		if remaining <= 0.0:
			changed = true
			continue
		timed_effect["remaining_seconds"] = remaining
		retained.append(timed_effect)
		changed = true
	run_state.temporary_buffs["infusion_effects"] = retained
	_rebuild_combo_state_from_effects(retained)
	if retained.is_empty():
		_last_combo_name = "—"
	return changed


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
		levels[infusion_id] = mini(MAX_COMBO_LEVEL, int(levels.get(infusion_id, 0)) + 1)
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
	var equipment_specials := inventory_manager.call("get_special_ability_totals") as Dictionary
	match String(infused.get("type", "")):
		"attack":
			effect["amount"] = int(effect.get("amount", 0)) + int(equipment_specials.get("card_damage_bonus", 0))
		"defense":
			effect["amount"] = int(effect.get("amount", 0)) + int(equipment_specials.get("card_block_bonus", 0))
		"skill":
			if String(effect.get("kind", "")) == "heal":
				effect["amount"] = int(effect.get("amount", 0)) + int(equipment_specials.get("card_heal_bonus", 0))
	if String(infused.get("id", "")) == "quickstep" and meta_state.dash_upgrade_unlocked:
		effect["distance"] = float(effect.get("distance", 0.0)) + float(equipment_specials.get("dash_distance_bonus", 0.0))
		effect["evasion_seconds"] = float(effect.get("evasion_seconds", 0.0)) + float(equipment_specials.get("dash_evasion_bonus", 0.0))
	var effects_variant: Variant = run_state.temporary_buffs.get("infusion_effects", [])
	if not effects_variant is Array:
		return infused
	var effects := effects_variant as Array
	var has_flame := false
	var has_frost := false
	for infusion_variant in effects:
		if not infusion_variant is Dictionary:
			continue
		var infusion := infusion_variant as Dictionary
		var infusion_id := String(infusion.get("infusion_id", ""))
		if String(infused.get("type", "")) == "attack":
			effect["amount"] = int(effect.get("amount", 0)) + int(infusion.get("damage_bonus", 0))
			if float(infusion.get("lifesteal_ratio", 0.0)) > 0.0:
				effect["lifesteal_ratio"] = float(effect.get("lifesteal_ratio", 0.0)) + float(infusion["lifesteal_ratio"])
		elif String(infused.get("type", "")) == "defense":
			effect["amount"] = int(effect.get("amount", 0)) + int(infusion.get("block_bonus", 0))
		if infusion_id == "flame":
			has_flame = true
			effect["burn_damage"] = int(infusion.get("burn_damage", 1))
			effect["burn_duration"] = float(effect.get("burn_duration", 0.0)) + float(infusion.get("burn_duration", 0.0))
		elif infusion_id == "frost":
			has_frost = true
			effect["frost_ratio"] = float(infusion.get("frost_ratio", 0.25))
			effect["frost_duration"] = float(effect.get("frost_duration", 0.0)) + float(infusion.get("frost_duration", 0.0))
		elif infusion_id == "thermal_shatter":
			has_flame = true
			has_frost = true
			effect["burn_damage"] = int(infusion.get("burn_damage", 1))
			effect["burn_duration"] = float(infusion.get("burn_duration", 0.0))
			effect["frost_ratio"] = float(infusion.get("frost_ratio", 0.25))
			effect["frost_duration"] = float(infusion.get("frost_duration", 0.0))
			effect["combo_stun"] = float(infusion.get("combo_stun", 0.5))
	if String(infused.get("type", "")) == "attack" and has_flame and has_frost:
		effect["amount"] = int(effect.get("amount", 0)) + 2
		effect["combo_stun"] = 0.25
	infused["effect"] = effect
	return infused


func _redraw_current_hand() -> bool:
	if not run_state.active or not ui_stack.is_empty():
		return false
	if not deck_manager.redraw_hand_for_all_energy():
		return false
	run_state.energy = deck_manager.energy
	_refresh_card_hand()
	return true


func _on_card_effect_resolved(_card_id: String, result: Dictionary) -> void:
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
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.035, true, false, true).timeout
	Engine.time_scale = 0.22 if _tactical_slowdown else 1.0


func _card_for_cast(card_or_instance: Variant) -> Dictionary:
	var instance: CardInstance = card_or_instance as CardInstance if card_or_instance is CardInstance else null
	var card_id := instance.card_id if instance != null else String(card_or_instance)
	var card := card_database.get_card(card_id)
	if card.is_empty():
		return {}
	var current_level := (
		CardInstance.MIN_LEVEL
		if deck_manager.is_card_protected(instance if instance != null else card_id)
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
	var wisp_turns := int(run_state.temporary_buffs.get("energy_wisp_turns", 0))
	if wisp_turns > 0:
		deck_manager.energy += maxi(1, int(run_state.temporary_buffs.get("energy_wisp_amount", 1)))
		run_state.temporary_buffs["energy_wisp_turns"] = wisp_turns - 1


func _refresh_card_hand() -> void:
	if card_hand_ui == null or card_database.get_all_cards().is_empty():
		return
	var cards: Array[Dictionary] = []
	for instance in deck_manager.hand_instances:
		var card := _card_for_cast(instance)
		card["fixed"] = deck_manager.is_card_protected(instance)
		cards.append(card)
	card_hand_ui.call("set_cards", cards, deck_manager.energy)
	card_hand_ui.call("set_action_points", deck_manager.energy, deck_manager.max_energy)
	_refresh_cooldown_display()


func _refresh_cooldown_display() -> void:
	if hud == null or not hud.has_method("set_cooldown_cards"):
		return
	var projection: Array[Dictionary] = []
	for entry in deck_manager.cooldown_pile:
		var instance := entry.get("instance") as CardInstance
		if instance == null:
			continue
		projection.append({
			"instance_id": instance.instance_id,
			"card_id": instance.card_id,
			"name": _card_name(instance.card_id),
			"remaining_seconds": float(entry.get("remaining_seconds", 0.0)),
		})
	hud.call("set_cooldown_cards", projection)


func _on_player_statuses_changed(statuses: Array) -> void:
	if hud != null and hud.has_method("set_active_statuses"):
		hud.call("set_active_statuses", statuses)


func _refresh_combo_display() -> void:
	if card_hand_ui == null:
		return
	var combo_kinds_variant: Variant = run_state.temporary_buffs.get("active_infusions", [])
	var combo_count := (combo_kinds_variant as Array).size() if combo_kinds_variant is Array else 0
	var seconds := _get_combo_time_remaining()
	card_hand_ui.call(
		"set_combo",
		"%s  [%d/%d]  %.1fs" % [_last_combo_name, combo_count, MAX_COMBO_ABILITIES, seconds],
		"Fast play stacks / equipment lowers AP and extends time"
	)


func _update_card_hand_visibility() -> void:
	if card_hand_ui == null or current_map == null:
		return
	card_hand_ui.visible = _current_map_matches(AUTUMN_FOREST_SCENE_PATH) and run_state.active


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


func _apply_shortcut_spawn() -> void:
	if (
		player is Node2D
		and current_map != null
		and _current_map_matches(AUTUMN_FOREST_SCENE_PATH)
		and bool(meta_state.shortcuts.get("forest_gate", false))
	):
		var shortcut_spawn := current_map.get_node_or_null("ForestShortcutSpawn") as Node2D
		if shortcut_spawn != null:
			(player as Node2D).global_position = shortcut_spawn.global_position


func _connect_if_present(node: Node, signal_name: StringName, method_name: StringName) -> void:
	if not node.has_signal(signal_name):
		return
	var callable := Callable(self, method_name)
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


func _inventory_projection() -> Array[Dictionary]:
	var definitions := {
		"travel_bread": {"name": "Travel Bread", "description": "Simple food for long roads.", "category": "items", "stats": "A basic provision."},
		"town_map": {"name": "Town Map", "description": "Marks roads around town.", "category": "quest", "stats": "Quest item"},
		"iron_sword": {"name": "Iron Sword", "description": "A reliable starter blade.", "category": "gear", "stats": "Attack +8"},
		"guard_boots": {"name": "Guard Boots", "description": "Light boots for long roads.", "category": "gear", "stats": "Defense +2"},
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
	return projection


func _save_quick_slot(menu: Control) -> void:
	var payload := _build_quick_save_payload()
	var save_directory := ProjectSettings.globalize_path("user://saves")
	var create_error := DirAccess.make_dir_recursive_absolute(save_directory)
	if create_error != OK:
		_set_menu_footer(menu, "Save failed: cannot create save folder.")
		return

	var temp_file := FileAccess.open(QUICK_SAVE_TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		_set_menu_footer(menu, "Save failed: cannot write temporary file.")
		return
	temp_file.store_string(JSON.stringify(payload, "\t"))
	temp_file.flush()
	temp_file = null

	var check_file := FileAccess.open(QUICK_SAVE_TEMP_PATH, FileAccess.READ)
	if check_file == null or JSON.parse_string(check_file.get_as_text()) == null:
		_remove_file_if_present(QUICK_SAVE_TEMP_PATH)
		_set_menu_footer(menu, "Save failed: validation error.")
		return

	if FileAccess.file_exists(QUICK_SAVE_PATH):
		_copy_file(QUICK_SAVE_PATH, QUICK_SAVE_BACKUP_PATH)
		_remove_file_if_present(QUICK_SAVE_PATH)

	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(QUICK_SAVE_TEMP_PATH),
		ProjectSettings.globalize_path(QUICK_SAVE_PATH)
	)
	if rename_error != OK:
		_set_menu_footer(menu, "Save failed while replacing quick save.")
		return

	if menu.has_method("set_button_enabled"):
		menu.call("set_button_enabled", "load", true)
	_set_menu_footer(menu, "Game saved.")


func _load_quick_slot(menu: Control) -> void:
	var save_file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.READ)
	if save_file == null:
		_set_menu_footer(menu, "No quick save found.")
		return
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if not parsed is Dictionary:
		_set_menu_footer(menu, "Load failed: save data is corrupted.")
		return

	var payload := parsed as Dictionary
	var map_path := String(payload.get("map_path", ""))
	if map_path.is_empty() or not ResourceLoader.exists(map_path):
		_set_menu_footer(menu, "Load failed: saved map is unavailable.")
		return
	var map_scene := load(map_path) as PackedScene
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
		"map_path": current_map.scene_file_path if current_map != null else "",
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
	current_interactive = interactive
	_update_interaction_prompt()


func _on_interaction_unavailable(interactive: Node, interactor: Node) -> void:
	if interactor != player:
		return
	_interaction_candidates.erase(interactive)
	current_interactive = _interaction_candidates[_interaction_candidates.size() - 1] if not _interaction_candidates.is_empty() else null
	_update_interaction_prompt()


func _try_interact() -> void:
	if current_interactive == null or not current_interactive.has_method("interact"):
		return
	current_interactive.call("interact", player)


func _on_dialogue_requested(npc: Node, dialogue_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	if dialogue_id == &"town_mayor":
		var town_ui := open_ui("TownProgressUI", town_progress_scene, true)
		if town_ui != null:
			town_ui.call("set_services", town_manager, inventory_manager)
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


func _sync_progression_to_meta() -> void:
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
	var stage := int(town_manager.call("get_village_stage"))
	var buildings := current_map.get_node_or_null("Buildings")
	if buildings == null:
		return
	var market := buildings.get_node_or_null("MarketStall") as CanvasItem
	var residence := buildings.get_node_or_null("EmptyResidence") as CanvasItem
	var tower := buildings.get_node_or_null("EmptyTowerHouse") as CanvasItem
	var blacksmith := buildings.get_node_or_null("Blacksmith") as CanvasItem
	if market != null:
		market.modulate = Color.WHITE if stage >= 1 else Color(0.58, 0.52, 0.46, 1.0)
	if residence != null:
		residence.modulate = Color.WHITE if stage >= 2 else Color(0.60, 0.54, 0.48, 1.0)
	if tower != null:
		tower.modulate = Color(1.08, 0.96, 0.80, 1.0) if stage >= 2 else Color(0.56, 0.52, 0.50, 1.0)
	if blacksmith != null:
		var smith_level := int(town_manager.call("get_building_level", &"blacksmith"))
		blacksmith.modulate = Color(1.0, 0.86 + 0.04 * smith_level, 0.76 + 0.06 * smith_level, 1.0)
	_apply_equipment_stats()


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
	player.health = mini(player.health, player.max_health)
	player.mana = mini(player.mana, player.max_mana)
	_update_hud_resources()


func _on_shop_requested(merchant: Node, shop_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	if shop_id == &"wandering_cards":
		_open_wandering_card_merchant(merchant)
		return

	var ui_control := open_ui("ShopUI", shop_scene)
	if ui_control == null:
		return

	var raw_display_name: Variant = merchant.get("display_name")
	var display_name := String(raw_display_name) if raw_display_name != null else "Merchant"
	ui_control.call("set_merchant_name", display_name)
	ui_control.call("set_wallet", wallet_gold)
	if ui_control.has_signal("mode_changed"):
		ui_control.connect("mode_changed", _on_shop_mode_changed.bind(ui_control, shop_id))
	if ui_control.has_signal("confirmed"):
		ui_control.connect("confirmed", _on_shop_transaction_confirmed.bind(ui_control, shop_id))
	_refresh_shop_projection(ui_control, shop_id, "buy")


func _open_wandering_card_merchant(merchant: Node) -> void:
	if not run_state.active:
		return
	var ui_control := open_ui("WanderingCardMerchant", dialogue_scene, true)
	if ui_control == null:
		return
	var display_name := String(merchant.get("display_name")) if merchant != null else "Wandering Cardwright"
	ui_control.call("set_speaker_name", display_name)
	ui_control.call("set_dialogue_text", "Supplies affect this expedition only. Run gold: %d" % run_state.gold_earned)
	var choices: Array[Dictionary] = []
	for offer in _build_wandering_stock():
		var choice := offer.duplicate(true)
		choice["text"] = "%s — %d gold" % [String(offer.get("name", "Offer")), int(offer.get("price", 0))]
		choice["merchant_action"] = "purchase"
		choices.append(choice)
	choices.append({"text": "Leave", "merchant_action": "leave", "action": "close"})
	ui_control.call("set_choices", choices)
	ui_control.connect("choice_selected", _on_wandering_card_choice.bind(ui_control))


func _on_wandering_card_choice(_index: int, _text: String, metadata: Dictionary, ui_control: Control) -> void:
	if not is_instance_valid(ui_control):
		return
	match String(metadata.get("merchant_action", "")):
		"purchase":
			var success := _purchase_wandering_offer(metadata)
			ui_control.call("set_dialogue_text", "Purchase complete. Run gold: %d" % run_state.gold_earned if success else "That purchase is not available.")
			_refresh_card_hand()


func _build_wandering_stock() -> Array[Dictionary]:
	var saved: Variant = run_state.temporary_buffs.get("wandering_stock", [])
	if saved is Array and not (saved as Array).is_empty():
		return (saved as Array).duplicate(true)
	var ordinary_id := ""
	var rare_id := ""
	for card_id in meta_state.unlocked_cards:
		var card := card_database.get_card(card_id)
		if card.is_empty():
			continue
		if ordinary_id.is_empty() and String(card.get("rarity", "")) in ["common", "uncommon"] and String(card.get("type", "")) != "combo":
			ordinary_id = card_id
		if rare_id.is_empty() and (String(card.get("rarity", "")) in ["rare", "legendary"] or String(card.get("type", "")) == "combo"):
			rare_id = card_id
	if ordinary_id.is_empty():
		ordinary_id = "guard"
	if rare_id.is_empty():
		rare_id = "flame_imbue"
	var removable: CardInstance
	for instance in deck_manager.get_all_instances():
		if not instance.is_fixed():
			removable = instance
			break
	var stock: Array[Dictionary] = [
		{"kind": "health_potion", "name": "Health Potion (+40 HP)", "price": 25},
		{"kind": "mana_potion", "name": "Mana Potion (+30 MP)", "price": 20},
		{"kind": "card", "name": _card_name(ordinary_id), "price": 35, "card_id": ordinary_id},
		{"kind": "card", "name": _card_name(rare_id), "price": 70, "card_id": rare_id},
		{
			"kind": "purge",
			"name": "Purge %s" % _card_name(removable.card_id if removable != null else ""),
			"price": 45,
			"card_id": removable.card_id if removable != null else "",
			"instance_id": removable.instance_id if removable != null else "",
		},
	]
	run_state.temporary_buffs["wandering_stock"] = stock.duplicate(true)
	return stock


func _purchase_wandering_offer(offer: Dictionary) -> bool:
	if not run_state.active or player == null:
		return false
	var kind := String(offer.get("kind", ""))
	var prices := {"health_potion": 25, "mana_potion": 20, "card": int(offer.get("price", 35)), "purge": 45}
	if not prices.has(kind):
		return false
	var price := int(prices[kind])
	if run_state.gold_earned < price:
		return false
	match kind:
		"health_potion":
			if int(player.get("health")) >= int(player.get("max_health")):
				return false
			player.call("restore_health", 40)
		"mana_potion":
			if int(player.get("mana")) >= int(player.get("max_mana")):
				return false
			player.call("restore_mana", 30)
		"card":
			var card_id := String(offer.get("card_id", ""))
			if not card_database.has_card(card_id) or _get_run_deck_size() >= 16:
				return false
			if not _add_persistent_run_card(card_id):
				return false
		"purge":
			var instance_id := String(offer.get("instance_id", ""))
			if not _remove_card_instance(instance_id):
				return false
	run_state.gold_earned -= price
	return true


func _remove_card_instance(instance_id: String) -> bool:
	var deck_instance := deck_manager.find_instance(instance_id)
	var run_instance := run_state.get_card_instance(instance_id)
	var meta_instance := meta_state.get_card_instance(instance_id)
	if (
		deck_instance == null
		or run_instance == null
		or meta_instance == null
		or deck_instance != run_instance
		or run_instance != meta_instance
		or deck_instance.is_fixed()
	):
		return false
	var instance_ids: Array[String] = [instance_id]
	return (
		deck_manager.remove_instances(instance_ids)
		and run_state.remove_card_instances(instance_ids)
		and meta_state.remove_card_instances(instance_ids)
	)


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
				hud.call("set_objective", "EQUIPMENT DISCOVERED: %s" % String(item.get("name", item_id)), String(ability.get("description", "New equipment discovered.")))
			return String(item_id)
	return ""


func _on_portal_entered(_portal: Node, target_scene_path: String, target_spawn_name: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	var canonical_target := _canonical_map_scene_path(target_scene_path)
	var resolved_target := _resolve_main_scene_path(canonical_target)
	if target_scene_path.is_empty() or not ResourceLoader.exists(resolved_target):
		push_warning("Portal target scene is not available: %s" % target_scene_path)
		return

	if canonical_target == AUTUMN_FOREST_SCENE_PATH:
		_open_deck_builder(canonical_target, target_spawn_name)
		return
	elif canonical_target == TOWN_SCENE_PATH and run_state.active:
		_finish_run(false)
		_pending_player_state.clear()
		player = null
	elif run_state.active and run_state.boss_defeated:
		_finish_run(true)
	var packed := load(resolved_target) as PackedScene
	load_current_map(packed, target_spawn_name)


func _open_deck_builder(target_scene_path: String, target_spawn_name: StringName) -> void:
	if get_open_ui("DeckBuilderUI") != null:
		return
	var ui_control := open_ui("DeckBuilderUI", deck_builder_scene, true)
	if ui_control == null:
		return
	var discovered: Array[Dictionary] = []
	var valid_ids: Array[String] = []
	for card in card_database.get_all_cards():
		valid_ids.append(String(card.get("id", "")))
	meta_state.normalize_selected_deck(valid_ids)
	for card_id in meta_state.unlocked_cards:
		var card := card_database.get_card(card_id)
		if not card.is_empty():
			discovered.append(card)
	ui_control.call("configure", discovered, meta_state.selected_deck)
	ui_control.connect("deck_confirmed", _on_deck_confirmed.bind(ui_control, target_scene_path, target_spawn_name), CONNECT_ONE_SHOT)


func _on_deck_confirmed(deck_ids: Array[String], ui_control: Control, target_scene_path: String, target_spawn_name: StringName) -> void:
	var normalized := _normalize_expedition_deck(deck_ids)
	meta_state.selected_deck = normalized.duplicate()
	save_service.save_meta(META_SAVE_PATH, meta_state.to_dict())
	close_ui(ui_control)
	_begin_autumn_run(normalized)
	load_current_map(load(_resolve_main_scene_path(target_scene_path)) as PackedScene, target_spawn_name)


func _normalize_expedition_deck(deck_ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	for fixed_id in FIXED_CARD_IDS:
		if card_database.has_card(fixed_id):
			normalized.append(fixed_id)
	for card_id_variant in deck_ids:
		if normalized.size() >= 16:
			break
		var card_id := String(card_id_variant)
		if card_database.has_card(card_id) and not FIXED_CARD_IDS.has(card_id):
			normalized.append(card_id)
	return normalized


func _on_chest_opened(_chest: Node, loot_table_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	if loot_table_id == &"forest_rest":
		_open_campfire_menu()
		return
	var message := "You found supplies from %s." % String(loot_table_id)
	match loot_table_id:
		&"forest_hidden_cache":
			if run_state.active:
				run_state.add_reward("gold", 45)
				run_state.add_reward("autumn_wood", 12)
			message = "Hidden cache found: +45 Gold and +12 Autumn Wood retained for this run."
		&"forest_shortcut":
			meta_state.shortcuts["forest_gate"] = true
			save_service.save_meta(META_SAVE_PATH, meta_state.to_dict())
			message = "Forest shortcut unlocked permanently."

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
	if not run_state.active or bool(run_state.temporary_buffs.get("campfire_used", false)) or player == null:
		return false
	player.call("restore_health", int(player.get("max_health")))
	player.call("restore_mana", int(player.get("max_mana")))
	run_state.temporary_buffs["campfire_used"] = true
	return true


func _show_campfire_result(ui_control: Control, message: String) -> void:
	ui_control.call("set_dialogue_text", message)
	ui_control.call("set_choices", [{"text": "Leave", "campfire_action": "leave", "action": "close"}])


func _card_name(card_id: String) -> String:
	var card := card_database.get_card(card_id)
	return String(card.get("name", card_id.capitalize()))


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
	if raw_display_name != null:
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
			{"id": "iron_sword", "name": "Iron Sword", "price": 120, "sell_price": 60, "description": "A reliable starter blade.", "stock": 2},
			{"id": "guard_boots", "name": "Guard Boots", "price": 85, "sell_price": 42, "description": "Light boots made for long roads.", "stock": 3},
		]

	return [
		{"id": "travel_bread", "name": "Travel Bread", "price": 12, "sell_price": 6, "description": "Simple food for the road.", "stock": 12},
		{"id": "town_map", "name": "Town Map", "price": 45, "sell_price": 22, "description": "Marks roads around the prototype town.", "stock": 1},
	]


func _catalog_for_shop(shop_id: StringName) -> Array[Dictionary]:
	var key := String(shop_id)
	if not _merchant_catalogs.has(key):
		_merchant_catalogs[key] = _shop_items_for(shop_id)
	return _merchant_catalogs[key] as Array[Dictionary]


func _on_shop_mode_changed(mode: String, ui_control: Control, shop_id: StringName) -> void:
	_refresh_shop_projection(ui_control, shop_id, mode)


func _refresh_shop_projection(ui_control: Control, shop_id: StringName, mode: String) -> void:
	if not is_instance_valid(ui_control):
		return
	var projection: Array[Dictionary] = []
	for raw_item in _catalog_for_shop(shop_id):
		var item := raw_item.duplicate(true)
		var item_id := String(item.get("id", ""))
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
