extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	_expect(shop.quantity == 2, "Shop Right increases quantity")
	_send_action(&"ui_left")
	await process_frame
	_expect(shop.quantity == 1, "Shop Left decreases quantity")
	shop.queue_free()

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

	quit(1 if failed else 0)

func _send_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)
