extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_scene: Node = load("res://scenes/game/game.tscn").instantiate()
	_expect(game_scene.has_node("HUDLayer"), "HUD has its own canvas layer")
	_expect(game_scene.has_node("MenuLayer"), "Menus have their own canvas layer")
	game_scene.free()

	var hud: HUD = load("res://scenes/ui/HUD.tscn").instantiate() as HUD
	root.add_child(hud)
	await process_frame
	_expect(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD ignores mouse input")
	_expect(
		(hud.get_node("InteractionPanel") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"HUD interaction prompt does not open menus by click"
	)
	hud.set_player_level(7)
	hud.set_player_class("Ranger")
	var status_path := "BottomHUD/HUDGrid/StatusColumn/StatusCenter/StatusProxy/HUDStatus"
	_expect((hud.get_node(status_path + "/LevelLabel") as Label).text == "Lv. 7", "HUD level updates dynamically")
	_expect((hud.get_node(status_path + "/ClassLabel") as Label).text == "RANGER", "HUD class updates dynamically")
	var hp_frame := hud.get_node(status_path + "/HPBar/Frame") as CanvasItem
	var hp_fill := hud.get_node(status_path + "/HPBar/Fill") as CanvasItem
	_expect(
		hp_frame.z_index > hp_fill.z_index or hp_frame.get_index() > hp_fill.get_index(),
		"Status frame renders above health fill"
	)
	hud.queue_free()

	var shop: ShopUI = load("res://scenes/ui/ShopUI.tscn").instantiate() as ShopUI
	root.add_child(shop)
	await process_frame
	shop.open()
	shop.set_items([
		{"name": "One", "price": 1, "stock": 5},
		{"name": "Two", "price": 2, "stock": 5},
		{"name": "Three", "price": 3, "stock": 5},
	])
	_send_action(&"ui_down")
	await process_frame
	_expect(shop.selected_index == 1, "Shop Down selects the next row")
	_send_action(&"ui_up")
	await process_frame
	_expect(shop.selected_index == 0, "Shop Up selects the previous row")
	_send_action(&"ui_right")
	await process_frame
	_expect(shop.get_viewport().gui_get_focus_owner() == shop.minus_button, "Shop Right enters quantity controls")
	_send_action(&"ui_right")
	await process_frame
	_expect(shop.get_viewport().gui_get_focus_owner() == shop.plus_button, "Shop Right selects quantity increase")
	shop.plus_button.pressed.emit()
	await process_frame
	_expect(shop.quantity == 2, "Shop quantity increase control works")
	_send_action(&"ui_left")
	await process_frame
	_expect(shop.get_viewport().gui_get_focus_owner() == shop.minus_button, "Shop Left selects quantity decrease")
	shop.minus_button.pressed.emit()
	await process_frame
	_expect(shop.quantity == 1, "Shop quantity decrease control works")
	shop.queue_free()

	var player: CharacterBody2D = load("res://scenes/player/Player.tscn").instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame
	player.set_input_enabled(false)
	_send_action(&"move_right")
	await process_frame
	_expect(player.get_move_direction() == 0.0, "Open UI lock suppresses player movement")
	_send_action(&"jump")
	await process_frame
	_expect(not player._is_action_just_pressed(&"jump"), "Open UI lock suppresses player actions")
	player.queue_free()

	var dialogue: DialogueUI = load("res://scenes/ui/DialogueUI.tscn").instantiate() as DialogueUI
	root.add_child(dialogue)
	await process_frame
	dialogue.open()
	dialogue.set_choices([
		{"text": "Continue"},
		{"text": "Goodbye", "action": "close"},
	])
	var goodbye_button := dialogue.get_node("DialoguePanel/ChoicesContainer/ChoiceTwo") as Button
	goodbye_button.emit_signal("pressed")
	await process_frame
	_expect(not dialogue.visible, "Goodbye closes the dialogue")
	dialogue.queue_free()

	var growth: CardGrowthUI = load("res://scenes/ui/CardGrowthUI.tscn").instantiate() as CardGrowthUI
	root.add_child(growth)
	await process_frame
	growth.set_growth_entry({
		"source": "exp_level",
		"allowed_pages": ["upgrade", "reward"],
		"payload": {
			"upgrade_options": [{"instance_id": 77, "card_id": "guard", "name": "Guard", "level": 2}],
			"fallback_rewards": [{"resource_id": "gold", "amount": 75}],
		},
	})
	await process_frame
	await process_frame
	_expect(growth.get_viewport().gui_get_focus_owner() == growth.upgrade_tab, "Growth modal opens with keyboard/controller focus on its active page")
	_send_action(&"ui_down")
	await process_frame
	_expect(growth.get_viewport().gui_get_focus_owner() == growth._option_buttons[0], "Growth Down enters the selectable option grid")
	_send_action(&"ui_accept")
	_send_action_release(&"ui_accept")
	await process_frame
	_expect(not growth.confirm_button.disabled, "Growth accept selects the focused option before confirmation")
	_send_action(&"ui_right")
	await process_frame
	_expect(growth.get_viewport().gui_get_focus_owner() == growth.confirm_button, "Growth Right enters the confirmation control")
	var growth_actions: Array[Dictionary] = []
	var growth_cancels: Array[bool] = []
	growth.choice_confirmed.connect(func(action: Dictionary) -> void: growth_actions.append(action.duplicate(true)))
	growth.close_requested.connect(func() -> void: growth_cancels.append(true))
	_send_action(&"ui_accept")
	_send_action_release(&"ui_accept")
	await process_frame
	_expect(growth_actions.size() == 1 and int(growth_actions[0].get("instance_id", 0)) == 77, "Growth keyboard/controller confirmation emits the selected typed intent")
	_send_action(&"ui_cancel")
	await process_frame
	_expect(growth_cancels.size() == 1 and growth.visible, "Growth cancel reports a non-consuming close request without hiding the modal")
	growth.queue_free()

	quit(1 if failed else 0)

func _send_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

func _send_action_release(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)
