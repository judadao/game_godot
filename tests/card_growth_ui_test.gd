extends SceneTree

const CARD_GROWTH_UI_SCENE := preload("res://scenes/ui/cards/CardGrowthUI.tscn")

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
			{"choice_id": "wave:11:0:cleave", "action": "new_card", "card_id": "cleave", "name": "Cleave", "description": "Deal damage to nearby enemies. Increase the attack arc.", "type": "attack", "cost": 2, "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png"},
			{"choice_id": "wave:11:0:cleave", "action": "new_card", "card_id": "cleave", "name": "Duplicate Cleave", "description": "Duplicate.", "type": "attack", "cost": 2},
			{"choice_id": "wave:11:1:frost_bind", "action": "new_card", "card_id": "frost_bind", "name": "Frost Bind", "description": "Slow enemies in a wide area.", "type": "status", "cost": 2},
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
		(wave_buttons[0] as Button).text.contains("Deal damage to nearby enemies.")
			and (wave_buttons[0] as Button).text.contains("AP 2"),
		"New-card choices must explain the card effect and AP cost without relying on a tooltip."
	)
	_expect(
		(wave_buttons[0] as Button).icon != null
			and (wave_buttons[0] as Button).has_meta("semantic_color")
			and (wave_buttons[0] as Button).text.count("•") >= 2,
		"Growth choices must use an icon, semantic color, and bullets for multiple effects."
	)
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
				"type": "combo",
				"cost": 2,
				"icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png",
				"description": "Deal damage to nearby enemies.",
				"upgrade_description": "The swing becomes a full visible circle.",
			},
			{
				"choice_id": "exp:12:upgrade:guard-a",
				"action": "upgrade",
				"instance_id": "guard-a",
				"card_id": "guard",
				"name": "Iron Will",
				"level": 1,
				"type": "combo",
				"cost": 1,
				"icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/BlueSet_0001_Shield.png",
				"description": "Gain weak super armor.",
				"upgrade_description": "Super armor lasts longer.",
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
	var upgrade_button := (ui.call("get_choice_buttons") as Array)[0] as Button
	var upgrade_lines := upgrade_button.text.split("\n")
	_expect(
		_all_text(ui).contains("Deal damage to nearby enemies.")
			and _all_text(ui).contains("The swing becomes a full visible circle."),
		"Upgrade choices must show both the current card effect and the exact next-level change."
	)
	_expect(
		upgrade_button.icon != null
			and upgrade_lines.size() == 4
			and String(upgrade_lines[2]).begins_with("• NOW")
			and String(upgrade_lines[3]).begins_with("• NEXT"),
		"Upgrade cards must use one icon and exactly two scannable NOW/NEXT bullet points."
	)

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
	_expect(_all_text(ui).contains("LV.3 + LV.3"), "Fusion choices must make both full-level materials explicit.")
	_expect(_all_text(ui).contains("LV.1"), "Fusion choices must show that the result returns at level one.")
	fusion_page["source"] = "fusion_followup"
	ui.call("present_page", fusion_page)
	await process_frame
	_expect(
		(ui.get_node("SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Header/Title") as Label).text
			== "EVOLVE COMBO?",
		"A newly completed Lv.3 pair must explain the optional Combo evolution."
	)
	_expect(skip_button.visible and not skip_button.disabled, "Post-upgrade fusion must be skippable.")

	var divine_page := {
		"event_id": 15,
		"source": "divine",
		"choices": [
			{
				"choice_id": "divine:15:gift:celestial_momentum",
				"action": "divine_gift",
				"gift_id": "celestial_momentum",
				"name": "天穹疾勢",
				"description": "每次連段都會加快戰鬥節奏，使具名終結技更大、更快。",
				"icon": "»",
				"element": "wind",
				"level": 0,
				"next_level": 1,
				"next_effects": {"combo_speed_bonus": 0.04, "finisher_size_multiplier": 1.10},
				"finisher_mutations": {"piercing": true, "speed_multiplier": 1.5},
				"type": "divine",
				"card_color": "gold",
			},
			{
				"choice_id": "divine:15:gift:echoing_will",
				"action": "divine_gift",
				"gift_id": "echoing_will",
				"name": "迴響意志",
				"description": "強化每次連段，並使具名終結技追加一次迴響。",
				"icon": "↻",
				"element": "dark",
				"level": 0,
				"next_level": 1,
				"next_effects": {"combo_effect_multiplier": 1.08, "finisher_damage_multiplier": 1.08},
				"finisher_mutations": {"finisher_echoes": 1, "echo_decay": 0.7},
				"type": "divine",
				"card_color": "gold",
			},
			{
				"choice_id": "divine:15:gift:boundless_font",
				"action": "divine_gift",
				"gift_id": "boundless_font",
				"name": "萬毒源泉",
				"description": "每次連段返還 AP，具名終結技則會恢復生命。",
				"icon": "◆",
				"element": "poison",
				"level": 0,
				"next_level": 1,
				"next_effects": {"combo_ap_refund": 0.10, "finisher_heal": 2},
				"finisher_mutations": {"poison_damage": 3, "poison_duration": 5.0},
				"type": "divine",
				"card_color": "gold",
			},
		],
	}
	ui.call("present_page", divine_page)
	await process_frame
	var divine_buttons := ui.call("get_choice_buttons") as Array
	_expect(divine_buttons.size() == 3, "Divine Gift pages must project three direct choices.")
	for button_variant in divine_buttons:
		var gift_button := button_variant as Button
		var gift_name := gift_button.get_node("CardContent/Header/Identity/Name") as Label
		_expect(
			gift_button.has_method("get_effect_bullet_count")
				and int(gift_button.call("get_effect_bullet_count")) >= 2,
			"Each Divine Gift card must expose at least two scannable effect bullets."
		)
		_expect(
			gift_button.get_node_or_null("CardContent/Header/GiftIcon") is Label
				and (gift_button.get_node("CardContent/Header/GiftIcon") as Label).custom_minimum_size.x >= 84.0
				and (gift_button.get_node("CardContent/Header/GiftIcon") as Label).get_theme_font_size("font_size") >= 48
				and gift_button.custom_minimum_size.y >= 264.0,
			"Each Divine Gift card must use a large authored icon and ornate tall presentation."
		)
		_expect(
			gift_name.is_visible_in_tree()
				and gift_name.size.y >= 32.0
				and not gift_name.text.strip_edges().is_empty(),
			"Each Divine Gift name must stay visibly readable before selection."
		)
	var selected_gift := divine_buttons[0] as Button
	var selected_style := selected_gift.get_theme_stylebox("pressed") as StyleBoxFlat
	_expect(
		(selected_gift.get_node("SelectedBadge") as Label).visible
			and selected_style != null
			and selected_style.border_width_left >= 4
			and selected_style.shadow_size >= 10,
		"The selected Divine Gift must stay visibly stronger than hover or keyboard focus."
	)
	var selection_summary := ui.get_node_or_null(
		"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/SelectionSummary"
	) as Label
	_expect(
		selection_summary != null,
		"Divine Gift pages must author a selected-effect summary."
	)
	if selection_summary != null:
		_expect(
			selection_summary.text.contains("已選")
			and selection_summary.text.contains("天穹疾勢")
			and selection_summary.text.contains("連段"),
			"The selected Divine Gift must project its name and concrete effect beside confirmation."
		)
	ui.call("select_choice", "divine:15:gift:echoing_will")
	await process_frame
	if selection_summary != null:
		_expect(
			selection_summary.text.contains("迴響意志"),
			"Changing Divine Gift selection must immediately update the selected-effect summary."
		)

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
