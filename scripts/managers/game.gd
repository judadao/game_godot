extends Node

signal map_loaded(map: Node)
signal player_registered(player_node: Node)
signal ui_opened(ui_name: String, ui_node: Control)
signal ui_closed(ui_name: String, ui_node: Control)

const QUICK_SAVE_PATH := "user://saves/quick_save.json"
const QUICK_SAVE_TEMP_PATH := "user://saves/quick_save.tmp"
const QUICK_SAVE_BACKUP_PATH := "user://saves/quick_save.json.bak"

@export var starting_map: PackedScene = preload("res://scenes/maps/town.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
@export var inventory_scene: PackedScene = preload("res://scenes/ui/InventoryUI.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")
@export var dialogue_scene: PackedScene = preload("res://scenes/ui/DialogueUI.tscn")
@export var shop_scene: PackedScene = preload("res://scenes/ui/ShopUI.tscn")

@onready var map_root: Node = $MapRoot
@onready var hud_root: CanvasLayer = $HUDLayer
@onready var ui_root: CanvasLayer = $MenuLayer

var current_map: Node
var player: Node
var hud: Control
var ui_stack: Array[Control] = []
var current_interactive: Node
var _ui_names: Dictionary = {}
var _ui_pause_flags: Dictionary = {}
var _closing_ui: Dictionary = {}
var _interaction_candidates: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	load_current_map(starting_map)
	load_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return

	if not ui_stack.is_empty():
		var top_ui := ui_stack[ui_stack.size() - 1]
		var top_name := String(_ui_names.get(top_ui, top_ui.name))
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			close_top_ui()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("inventory") and top_name == "InventoryUI":
			close_top_ui()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inventory"):
		toggle_ui("InventoryUI", inventory_scene)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		open_ui("PauseMenu", pause_menu_scene, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()


func load_starting_map() -> void:
	load_current_map(starting_map)


func load_current_map(map_scene: PackedScene, spawn_name: StringName = &"PlayerSpawn") -> Node:
	for child in map_root.get_children():
		child.queue_free()

	current_map = null
	player = null

	if map_scene == null:
		push_error("Game entry has no map scene assigned.")
		return null

	current_map = map_scene.instantiate()
	map_root.add_child(current_map)
	_register_player(spawn_name)
	_wire_interactives()
	_update_hud_area_name()
	map_loaded.emit(current_map)
	return current_map


func load_hud() -> void:
	if hud != null:
		hud.queue_free()
		hud = null

	if hud_scene == null:
		return

	var hud_instance := hud_scene.instantiate()
	if hud_instance is Control:
		hud = hud_instance
		hud_root.add_child(hud)
		if hud.has_signal("interaction_prompt_accepted"):
			hud.connect("interaction_prompt_accepted", _try_interact)
		_update_hud_area_name()
		_update_hud_player_identity()
	else:
		push_error("HUD scene root must be a Control.")
		hud_instance.queue_free()


func _update_hud_area_name() -> void:
	if hud == null or current_map == null or not hud.has_method("set_area_name"):
		return

	var area_names := {
		"res://scenes/maps/town.tscn": "Town",
		"res://scenes/maps/autumn_forest.tscn": "Autumn Forest",
		"res://scenes/maps/crystal_caves.tscn": "Crystal Caves",
		"res://scenes/maps/forbidden_graveyard.tscn": "Forbidden Graveyard",
	}
	var map_path := current_map.scene_file_path
	hud.call("set_area_name", area_names.get(map_path, current_map.name))


func _update_hud_player_identity() -> void:
	if hud == null or player == null:
		return
	var player_level: Variant = player.get("level")
	var player_class: Variant = player.get("character_class")
	var player_experience: Variant = player.get("experience")
	var experience_required: Variant = player.get("experience_to_next_level")
	if player_level != null and hud.has_method("set_player_level"):
		hud.call("set_player_level", int(player_level))
	if player_class != null and hud.has_method("set_player_class"):
		hud.call("set_player_class", String(player_class))
	if player_experience != null and experience_required != null and hud.has_method("set_experience"):
		hud.call("set_experience", int(player_experience), int(experience_required))


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

	_update_player_input_state()
	player_registered.emit(player)


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


func _connect_if_present(node: Node, signal_name: StringName, method_name: StringName) -> void:
	if not node.has_signal(signal_name):
		return
	var callable := Callable(self, method_name)
	if not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)


func _open_inventory_from_pause() -> void:
	open_ui("InventoryUI", inventory_scene)


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
		for property_name in ["level", "character_class", "experience", "experience_to_next_level"]:
			var value: Variant = player.get(property_name)
			if value != null:
				player_payload[property_name] = value

	return {
		"schema_version": 1,
		"saved_at": Time.get_datetime_string_from_system(true),
		"map_path": current_map.scene_file_path if current_map != null else "",
		"player": player_payload,
	}


func _apply_quick_save_payload(payload: Dictionary) -> void:
	if player == null:
		return
	var player_payload := payload.get("player", {}) as Dictionary
	for property_name in ["level", "character_class", "experience", "experience_to_next_level"]:
		if player_payload.has(property_name):
			player.set(property_name, player_payload[property_name])
	var position_payload := player_payload.get("position", {}) as Dictionary
	if player is Node2D and position_payload.has("x") and position_payload.has("y"):
		(player as Node2D).global_position = Vector2(
			float(position_payload["x"]),
			float(position_payload["y"])
		)
	_update_hud_player_identity()


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


func _on_shop_requested(merchant: Node, shop_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return

	var ui_control := open_ui("ShopUI", shop_scene)
	if ui_control == null:
		return

	var raw_display_name: Variant = merchant.get("display_name")
	var display_name := String(raw_display_name) if raw_display_name != null else "Merchant"
	ui_control.call("set_merchant_name", display_name)
	ui_control.call("set_wallet", 250)
	ui_control.call("set_items", _shop_items_for(shop_id))


func _on_portal_entered(_portal: Node, target_scene_path: String, target_spawn_name: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return
	if target_scene_path.is_empty() or not ResourceLoader.exists(target_scene_path):
		push_warning("Portal target scene is not available: %s" % target_scene_path)
		return

	var packed := load(target_scene_path) as PackedScene
	load_current_map(packed, target_spawn_name)


func _on_chest_opened(_chest: Node, loot_table_id: StringName, interactor: Node) -> void:
	if interactor != null and interactor != player:
		return

	var ui_control := open_ui("DialogueUI", dialogue_scene)
	if ui_control == null:
		return
	ui_control.call("set_speaker_name", "Chest")
	ui_control.call("set_dialogue_text", "You found supplies from %s." % String(loot_table_id))
	ui_control.call("set_choices", [{"text": "Take all"}])


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
		hud.call("set_interaction_prompt", prompt, "F")


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
			{"name": "Iron Sword", "price": 120, "description": "A reliable starter blade.", "stock": 2, "icon": "S"},
			{"name": "Guard Boots", "price": 85, "description": "Light boots made for long roads.", "stock": 3, "icon": "B"},
		]

	return [
		{"name": "Potion", "price": 25, "description": "Restores a small amount of health.", "stock": 8, "icon": "P"},
		{"name": "Travel Bread", "price": 12, "description": "Simple food for the road.", "stock": 12, "icon": "B"},
		{"name": "Town Map", "price": 45, "description": "Marks roads around the prototype town.", "stock": 1, "icon": "M"},
	]
