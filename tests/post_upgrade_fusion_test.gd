extends SceneTree

class SuccessfulSaveService:
	extends SaveService

	func save_meta(_path: String, _data: Dictionary) -> bool:
		return true


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("save_service", SuccessfulSaveService.new())
	game.call("_begin_autumn_run", [
		"guard", "iron_skin", "flame_imbue", "frostburst_imbue",
		"battle_rhythm", "sweeping_reach", "quickened_cadence", "healing_light",
	])
	var run := game.get("run_state") as RunState
	var upgrade_target: CardInstance
	for instance in run.card_instances:
		if instance.is_fixed():
			continue
		instance.level = CardInstance.MAX_LEVEL
		if upgrade_target == null:
			upgrade_target = instance
	upgrade_target.level = CardInstance.MAX_LEVEL - 1
	run.pending_level_ups = 1
	(game.get("growth_choice_queue") as GrowthChoiceQueue).clear()
	game.call("_enqueue_experience_growth")
	await process_frame
	await process_frame

	var first_page := (game.get("growth_choice_queue") as GrowthChoiceQueue).peek()
	var upgrade_choice := (first_page.get("choices", []) as Array)[0] as Dictionary
	var growth_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(
		String(upgrade_choice.get("action", "")) == "upgrade"
			and String(upgrade_choice.get("instance_id", "")) == upgrade_target.instance_id,
		"The final Lv.2 card must be the upgrade choice."
	)
	growth_ui.call("select_choice", String(upgrade_choice.get("choice_id", "")))
	growth_ui.call("confirm_selected_choice")
	await process_frame
	await process_frame

	var fusion_queue := game.get("growth_choice_queue") as GrowthChoiceQueue
	var fusion_page := fusion_queue.peek()
	var fusion_choices := fusion_page.get("choices", []) as Array
	var offers_ascendant := false
	var ascendant_choice: Dictionary = {}
	for choice_variant in fusion_choices:
		if String((choice_variant as Dictionary).get("result_card_id", "")) == "ascendant_combo":
			offers_ascendant = true
			ascendant_choice = (choice_variant as Dictionary).duplicate(true)
			break
	_expect(upgrade_target.level == CardInstance.MAX_LEVEL, "The selected card must reach Lv.3 first.")
	_expect(
		String(fusion_page.get("source", "")) == "fusion_followup"
			and offers_ascendant,
		"Creating a second Lv.3 card must immediately offer stronger Combo synthesis."
	)
	var fusion_ui := game.get_open_ui("CardGrowthUI") as Control
	var skip_button := fusion_ui.get_node(
		"SafeMargin/ModalCenter/ModalPanel/ModalMargin/Content/Footer/SkipButton"
	) as Button
	_expect(skip_button.visible and paused, "Fusion follow-up must be pausing and optional.")
	fusion_ui.call("select_choice", String(ascendant_choice.get("choice_id", "")))
	fusion_ui.call("confirm_selected_choice")
	await process_frame
	var ascendant_instances := run.card_instances.filter(
		func(instance: CardInstance) -> bool:
			return instance.card_id == "ascendant_combo"
	)
	_expect(
		ascendant_instances.size() == 1
			and (ascendant_instances[0] as CardInstance).level == CardInstance.MIN_LEVEL
			and run.get_card_instance(String(ascendant_choice.get("left_instance_id", ""))) == null
			and run.get_card_instance(String(ascendant_choice.get("right_instance_id", ""))) == null,
		"Choosing synthesis must consume the two Lv.3 instances and create one Lv.1 Ascendant Combo."
	)
	_expect(fusion_queue.is_empty() and not paused, "Finishing fusion must resume combat.")

	game.queue_free()
	await process_frame
	paused = false
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
