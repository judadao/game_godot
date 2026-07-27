extends SceneTree

const CARD_GROWTH_UI_SCENE := preload("res://scenes/ui/CardGrowthUI.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := CARD_GROWTH_UI_SCENE.instantiate() as Control
	root.add_child(ui)
	await process_frame

	_expect(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "Card growth UI must process while gameplay is paused.")
	_expect(ui.mouse_filter == Control.MOUSE_FILTER_STOP, "The modal root must block pointer input from reaching combat.")
	_expect(ui.has_signal("choice_confirmed"), "Card growth UI must expose the choice_confirmed intent signal.")
	_expect(ui.has_signal("reward_skipped"), "Card growth UI must expose the optional new-card Skip intent.")

	var wave_page := {
		"event_id": 11,
		"source": "wave",
		"choices": [
			{"choice_id": "wave:11:0:cleave", "action": "new_card", "card_id": "cleave", "name": "Cleave"},
			{"choice_id": "wave:11:0:cleave", "action": "new_card", "card_id": "cleave", "name": "Duplicate Cleave"},
			{"choice_id": "wave:11:1:frost_bind", "action": "new_card", "card_id": "frost_bind", "name": "Frost Bind"},
		],
	}
	ui.call("present_page", wave_page)
	await process_frame
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title") as Label).text == "CHOOSE A NEW CARD", "Wave pages must explain that the player is choosing a new card.")
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Source") as Label).text.contains("WAVE"), "Wave source must remain visible.")
	_expect(ui.call("get_choice_button_count") == 2, "Duplicate choice IDs must not create ambiguous buttons.")
	_expect(not (ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/ConfirmButton") as Button).disabled, "The first presented choice must be selected and confirmable.")
	var skip_button := ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/SkipButton") as Button
	_expect(skip_button.visible and not skip_button.disabled, "Wave new-card pages must allow players to keep a compact deck by skipping.")
	var wave_buttons := ui.call("get_choice_buttons") as Array
	_expect(
		(wave_buttons[0] as Button).get_node_or_null((wave_buttons[0] as Button).focus_neighbor_right) == wave_buttons[1],
		"Choice cards must author runtime focus neighbors for keyboard and gamepad navigation."
	)

	var emitted: Array[String] = []
	ui.connect("choice_confirmed", func(choice_id: String) -> void: emitted.append(choice_id))
	ui.call("confirm_selected_choice")
	ui.call("confirm_selected_choice")
	_expect(emitted == ["wave:11:0:cleave"], "A page must emit its selected choice exactly once.")
	_expect(ui.visible, "Confirming must not close the UI before the queue owner advances it.")

	var experience_page := {
		"event_id": 12,
		"source": "experience",
		"choices": [
			{
				"choice_id": "exp:12:upgrade:cleave-a",
				"action": "upgrade",
				"instance_id": "cleave-a",
				"card_id": "cleave",
				"name": "Cleave",
				"level": 2,
			},
			{
				"choice_id": "exp:12:upgrade:guard-a",
				"action": "upgrade",
				"instance_id": "guard-a",
				"card_id": "guard",
				"name": "Iron Will",
				"level": 1,
			},
		],
	}
	ui.call("present_page", experience_page)
	await process_frame
	_expect(not skip_button.visible, "Experience upgrades must remain mandatory and must not expose the new-card Skip action.")
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title") as Label).text == "CHOOSE AN UPGRADE", "EXP growth must identify the unfinished-card upgrade page.")
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection") as Control).visible, "EXP pages must expose individual upgrades.")
	_expect(not (ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FusionSection") as Control).visible, "EXP upgrade and fusion choices must share one compact five-card layout.")
	_expect(not (ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection") as Control).visible, "Fallback resources must stay hidden while growth exists.")
	_expect(ui.call("get_choice_button_count") == 2, "The compact upgrade layout must retain both supplied unfinished cards.")
	_expect(_all_text(ui).contains("LV.2"), "Upgrade choices must show the selected instance level.")

	var fusion_page := {
		"event_id": 14,
		"source": "experience",
		"choices": [{
			"choice_id": "exp:14:fusion:guard-a:iron-a",
			"action": "fusion",
			"left_instance_id": "guard-a",
			"right_instance_id": "iron-a",
			"left_card_id": "guard",
			"right_card_id": "iron_skin",
			"left_name": "Iron Will",
			"right_name": "Stone Form",
			"result_card_id": "fortress_stance",
			"result_name": "Unbreakable Stance",
		}],
	}
	ui.call("present_page", fusion_page)
	await process_frame
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title") as Label).text == "CHOOSE A FUSION", "Full-level fusion must use a separate page.")
	_expect(_all_text(ui).contains("LV.3  +  LV.3"), "Fusion choices must make both full-level materials explicit.")
	_expect(_all_text(ui).contains("LV.1"), "Fusion choices must show that the result returns at level one.")

	var fallback_page := {
		"event_id": 13,
		"source": "experience",
		"choices": [
			{"choice_id": "exp:13:fallback:0", "action": "fallback", "reward": {"gold": 75}},
			{"choice_id": "exp:13:fallback:1", "action": "fallback", "reward": {"autumn_wood": 12, "stone": 8}},
			{"choice_id": "exp:13:fallback:2", "action": "fallback", "reward": {"magic_shard": 4}},
		],
	}
	ui.call("present_page", fallback_page)
	await process_frame
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title") as Label).text == "CHOOSE RESOURCES", "Fallback pages must clearly identify resource rewards.")
	_expect(not (ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/UpgradeSection") as Control).visible, "Fallback pages must not show an empty upgrade section.")
	_expect(not (ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FusionSection") as Control).visible, "Fallback pages must not show an empty fusion section.")
	_expect((ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Body/ChoiceScroll/ChoiceSections/FallbackSection") as Control).visible, "Fallback pages must expose the three resource bundles.")
	_expect(_all_text(ui).contains("75 GOLD"), "Fallback must state the exact gold amount.")
	_expect(_all_text(ui).contains("12 AUTUMN WOOD  +  8 STONE"), "Fallback must state both material amounts.")
	_expect(_all_text(ui).contains("4 MAGIC SHARDS"), "Fallback must state the exact shard amount.")

	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	ui._unhandled_input(cancel)
	_expect(ui.visible, "Cancel input must not dismiss or skip a pending choice.")

	ui.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _all_text(root_node: Node) -> String:
	var parts: Array[String] = []
	for child in root_node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	for child in root_node.find_children("*", "Button", true, false):
		parts.append((child as Button).text)
	return "\n".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
